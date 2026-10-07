"""Literal README command selection and explicit disposable-consumer edits.

This route intentionally does not use SmokeConsumer's automatic rename or ports.
Only a newly cloned, caller-owned standalone repository may be passed to edits.
"""
import json
import hashlib
import os
import re
import secrets
import selectors
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path


def group_rows(group):
    result = subprocess.run(["ps", "-axo", "pid=,pgid=,uid=,lstart="],
                            capture_output=True, text=True, timeout=2, check=True)
    if len(result.stdout) > 16 * 1024 * 1024:
        raise RuntimeError("Process inventory exceeds its bound")
    rows = {}
    for line in result.stdout.splitlines():
        fields = line.split(None, 3)
        if len(fields) != 4 or not all(value.isdecimal() for value in fields[:3]):
            raise RuntimeError("Malformed native process inventory")
        if int(fields[1]) == group:
            rows[int(fields[0])] = (int(fields[2]), fields[3])
    return rows


def exited_without_reaping(process):
    # Required on the actual Linux runner; absence of this API refuses execution.
    return os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)


def finish_group(process, identity):
    def observed():
        rows = group_rows(process.pid)
        if rows.get(process.pid) != identity or any(uid != os.getuid() for uid, _ in rows.values()):
            raise RuntimeError("Pinned command group ownership is unresolved")
        return rows

    rows = observed()
    residual = len(rows) > 1
    if exited_without_reaping(process) is None or residual:
        os.killpg(process.pid, signal.SIGTERM)
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            rows = observed()
            if len(rows) == 1 and exited_without_reaping(process) is not None:
                break
            time.sleep(0.02)
        else:
            observed()
            os.killpg(process.pid, signal.SIGKILL)
        deadline = time.monotonic() + 10
        while len(observed()) != 1 or exited_without_reaping(process) is None:
            if time.monotonic() >= deadline:
                raise RuntimeError("Command group remains after bounded cleanup")
            time.sleep(0.02)
    status = process.wait(timeout=10)
    if group_rows(process.pid):
        raise RuntimeError("Command group absence is not established")
    return status, residual


def capture_until_exit(process, output, deadline, timeout):
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired("README command", timeout)
            for key, _ in selector.select(min(0.02, remaining)):
                data = os.read(key.fileobj.fileno(), 65536)
                accepted = data[:max(0, 16 * 1024 * 1024 - output.tell())]
                output.write(accepted)
                if accepted != data:
                    raise ValueError("Command output exceeds the smoke capture ceiling")
                if not data:
                    selector.unregister(key.fileobj)
            if exited_without_reaping(process) is not None:
                return


def drain_available(process, output):
    """After positive group cleanup, retain available bytes without waiting for EOF."""
    os.set_blocking(process.stdout.fileno(), False)
    while True:
        try:
            data = os.read(process.stdout.fileno(), 65536)
        except BlockingIOError:
            return
        if not data:
            return
        accepted = data[:max(0, 16 * 1024 * 1024 - output.tell())]
        output.write(accepted)
        if accepted != data:
            raise ValueError("Command output exceeds the smoke capture ceiling")


def supervised_command(body, cwd, events, label, timeout):
    if not all(hasattr(os, name) for name in ("waitid", "WNOWAIT", "WEXITED", "WNOHANG")):
        raise RuntimeError("Native non-reaping child observation is unavailable")
    started = time.monotonic()
    evidence = cwd.parent / ("command-evidence-" + secrets.token_hex(16))
    evidence.mkdir(mode=0o700)
    capture = evidence / "output.bin"
    fault = evidence / "failure-location"
    os.close(os.open(fault, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))
    process, identity, failure = None, None, None
    event = {"stage": label, "exit": None, "group_absent": False,
             "command_sha256": hashlib.sha256(body.encode()).hexdigest(), "capture_path": str(capture),
             "platform": sys.platform, "waitid_qualified": False, "process_started": False}
    fd = os.open(capture, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    try:
        with os.fdopen(fd, "wb") as output:
            try:
                fingerprint = "import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())"
                handler = 'status=$? line=$LINENO failed_command=$BASH_COMMAND; if test "$status" -ne 0; then printf "%s %s " "$status" "$line" > ' + shlex.quote(str(fault))
                handler += '; printf "%s" "$failed_command" | ' + shlex.quote(sys.executable) + " -c " + shlex.quote(fingerprint) + " >> " + shlex.quote(str(fault))
                handler += "; fi"
                # EXIT also observes a final external command; ERR alone allows
                # Bash's last-command exec optimization to bypass the callback.
                diagnostic = "trap " + shlex.quote(handler) + " EXIT\n"
                process = subprocess.Popen(["bash", "-euo", "pipefail", "-c", diagnostic + body], cwd=cwd,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
                event["process_started"] = True
                event["leader_pid"] = process.pid
                identity = group_rows(process.pid).get(process.pid)
                if identity is None or identity[0] != os.getuid():
                    raise RuntimeError("Native command leader identity is unresolved")
                exited_without_reaping(process)
                event["waitid_qualified"] = True
                event["leader_identity"] = {"pid": process.pid, "uid": identity[0], "birth": identity[1]}
                capture_until_exit(process, output, started + timeout, timeout)
            except BaseException as error:
                failure = error
            finally:
                if process is not None and identity is not None:
                    try:
                        event["exit"], residual = finish_group(process, identity)
                        event["group_absent"] = True
                        drain_available(process, output)
                        if failure is None and (event["exit"] != 0 or residual):
                            failure = ValueError("Command failed or left unmanaged descendants")
                    except BaseException as error:
                        event["cleanup_error_class"] = type(error).__name__
                        failure = failure or error
                if process is not None and process.stdout is not None:
                    process.stdout.close()
    except BaseException as error:
        failure = failure or error
    finally:
        event["seconds"] = time.monotonic() - started
        try:
            event["output_sha256"] = hashlib.sha256(capture.read_bytes()).hexdigest()
            fields = fault.read_text().split()
            if len(fields) == 3 and all(value.isdecimal() for value in fields[:2]) and re.fullmatch(r"[0-9a-f]{64}", fields[2]):
                event["failure_location"] = {"native_bash_line": int(fields[1]), "reported_status": int(fields[0]),
                    "native_command_sha256": fields[2]}
        except BaseException as error:
            event["capture_read_error_class"] = type(error).__name__
            failure = failure or error
        if failure is not None:
            event["error_class"] = type(failure).__name__
        events.append(event)
    if failure is not None:
        raise failure
    capture.unlink()
    fault.unlink()
    evidence.rmdir()
    event.pop("capture_path")


def allocate_clone(root):
    root.mkdir(mode=0o700)
    info = root.stat()
    return info.st_dev, info.st_ino, info.st_uid


def remove_clone(root, identity):
    info = root.lstat()
    if root.is_symlink() or (info.st_dev, info.st_ino, info.st_uid) != identity:
        raise ValueError("Owned checkout identity changed before cleanup")
    shutil.rmtree(root)
    if root.exists() or root.is_symlink():
        raise ValueError("Owned checkout remains after cleanup")


def require_revision(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("A complete lowercase Git commit identity is required")
    return value


def commands(readme, number):
    sections = re.split(r"(?m)^### ([1-8])\. .*\n", readme)
    selected = [sections[i + 1] for i in range(1, len(sections), 2) if sections[i] == str(number)]
    if len(selected) != 1:
        raise ValueError("README numbered section is missing or ambiguous")
    blocks = re.findall(r"(?ms)^```sh\n(.*?)^```\s*$", selected[0])
    if not blocks:
        raise ValueError("README section has no shell commands")
    return "\n".join(block.rstrip() for block in blocks) + "\n"


def assert_free_ports(ports=(3000, 3306)):
    reservations = []
    try:
        for port in ports:
            reservation = socket.socket()
            reservations.append(reservation)
            reservation.bind(("0.0.0.0", port))
    finally:
        for reservation in reservations:
            reservation.close()


def rewrite_json(path, edit):
    original = json.loads(path.read_text())
    edit(original)
    path.write_text(json.dumps(original, indent=2) + "\n")


def rename_application(root):
    application = root / "config/application.rb"
    text = application.read_text()
    if text.count("module App\n") != 1:
        raise ValueError("Application module requires explicit updated rename instructions")
    application.write_text(text.replace("module App\n", "module AcmePortal\n").replace("Your Project", "Acme Portal"))
    for name in ("home/index.html.erb", "layouts/application.html.erb", "pwa/manifest.json.erb"):
        path = root / "app/views" / name
        original = path.read_text()
        if "Your Project" not in original:
            raise ValueError("Display rename instructions have changed")
        path.write_text(original.replace("Your Project", "Acme Portal"))
    rewrite_json(root / "package.json", lambda data: data.update(name="acme-portal"))

    def lock_identity(data):
        data["name"] = "acme-portal"
        data["packages"][""]["name"] = "acme-portal"

    rewrite_json(root / "package-lock.json", lock_identity)
    bun_lock = root / "bun.lock"
    if bun_lock.exists():
        pattern = r'("workspaces"\s*:\s*\{\s*""\s*:\s*\{\s*"name"\s*:\s*)"your-project"'
        updated, count = re.subn(pattern, r'\1"acme-portal"', bun_lock.read_text())
        if count != 1:
            raise ValueError("Bun root identity requires explicit updated instructions")
        bun_lock.write_text(updated)
    elif (root / "bun.lockb").exists():
        raise ValueError("Binary Bun lock requires supported native identity editing")


def rename_local_metadata(root):
    caller = root / ".github/workflows/ci.yml"
    original = caller.read_text()
    if original.count("database_name: railsdb") != 1:
        raise ValueError("CI database rename instructions have changed")
    caller.write_text(original.replace("database_name: railsdb", "database_name: acme_portal"))
    # This is a validation clone of the actual starter repository, not a newly
    # invented consumer repository. Keep its real configured tracker unchanged.
    rewrite_json(root / "wiki/lisa-wiki.config.json", lambda data: data.update(
        displayName="Acme Portal Walkthrough Wiki",
        purpose="Disposable Acme Portal onboarding validation of the actual Railsstarter repository."))


def configure_private_env(root, project, key):
    path = root / ".env"
    if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
        raise ValueError("README must create a private regular dotenv file")
    text = path.read_text()
    replacements = {"DATABASE_NAME=railsdb": "DATABASE_NAME=acme_portal",
                    "SECRET_KEY_BASE=secret_key_base": "SECRET_KEY_BASE=" + key}
    for original, replacement in replacements.items():
        if text.count(original) != 1:
            raise ValueError("Private input instructions have changed")
        text = text.replace(original, replacement)
    path.write_text(text + "\nCOMPOSE_PROJECT_NAME=" + project + "\nAWS_BOOTSTRAP_ENABLED=false\n")


def validate_schemas(rows):
    expected = {"acme_portal" + suffix for suffix in (
        "", "_queue", "_cache", "_cable", "_test", "_queue_test", "_cache_test", "_cable_test")}
    observed = {}
    for row in rows.splitlines():
        name, encoding, collation = row.split("\t")
        if name in observed or name not in expected:
            raise ValueError("Unexpected or repeated schema identity")
        observed[name] = (encoding, collation)
    if set(observed) != expected or any(value != ("utf8mb4", "utf8mb4_0900_ai_ci") for value in observed.values()):
        raise ValueError("Native eight-schema identity/encoding/collation qualification failed")
    return sorted(observed)
