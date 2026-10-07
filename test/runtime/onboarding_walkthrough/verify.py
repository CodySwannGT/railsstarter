#!/usr/bin/env python3
"""Fresh Ubuntu acceptance for the literal numbered README commands.

No provider identity is invented. Candidate and published-main are distinct
qualifications. Output artifacts contain statuses/hashes, never command output,
dotenv keys, credentials or a claimed provider-hook verdict.
"""
import argparse
import hashlib
import json
import os
import re
import secrets
import shlex
import stat
import subprocess
import time
import urllib.request
from pathlib import Path

from walkthrough import (assert_free_ports, commands, configure_private_env,
                         rename_application, rename_local_metadata,
                         require_revision, validate_schemas, allocate_clone,
                         remove_clone, supervised_command as script)

REPOSITORY = "https://github.com/CodySwannGT/railsstarter.git"


def native(args, cwd, timeout=30):
    result = subprocess.run(args, cwd=cwd, check=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout)
    if len(result.stdout) > 16 * 1024 * 1024:
        raise ValueError("Native output exceeds the existing smoke capture ceiling")
    return result.stdout.decode("utf-8", errors="strict").strip()


def census(cwd):
    return {kind: set(native(["docker", *args], cwd).splitlines()) for kind, args in (
        ("containers", ["ps", "-aq", "--no-trunc"]),
        ("networks", ["network", "ls", "-q", "--no-trunc"]),
        ("volumes", ["volume", "ls", "-q"]),
        ("images", ["image", "ls", "-q", "--no-trunc"]))}


def phase(root, name, project):
    if root.resolve() != Path.cwd().resolve() or root.name != "acme-portal":
        raise ValueError("Phase must run in its explicitly supplied consumer checkout")
    if not (root / ".git").is_dir() or (root / ".git").is_symlink():
        raise ValueError("Walkthrough requires its own standalone .git")
    if native(["git", "remote", "get-url", "origin"], root) != REPOSITORY:
        raise ValueError("Phase repository is not the actual starter clone")
    if name == "rename":
        rename_application(root)
        rename_local_metadata(root)
        config = json.loads((root / ".lisa.config.json").read_text())
        if config.get("github", {}).get("repo") != "railsstarter" or config.get("github", {}).get("org") != "CodySwannGT":
            raise ValueError("Actual starter tracker identity must remain unchanged")
    elif name == "env":
        configure_private_env(root, project, secrets.token_hex(64))
    else:
        raise ValueError("Unknown walkthrough phase")


def inspect_acceptance(root):
    hooks = Path(native(["git", "rev-parse", "--path-format=absolute", "--git-path", "hooks"], root))
    if not hooks.resolve().is_relative_to((root / ".git").resolve()):
        raise ValueError("Hooks resolve outside this standalone repository")
    identities = {}
    for name in ("pre-commit", "prepare-commit-msg", "commit-msg", "pre-push"):
        path = hooks / name
        if path.is_symlink() or not path.is_file() or not os.access(path, os.X_OK):
            raise ValueError("Required executable hook is missing")
        identities[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    suffixes = ("", "_queue", "_cache", "_cable", "_test", "_queue_test", "_cache_test", "_cable_test")
    names = ",".join("'acme_portal" + suffix + "'" for suffix in suffixes)
    query = "SELECT schema_name,default_character_set_name,default_collation_name FROM information_schema.schemata WHERE schema_name IN (" + names + ")"
    rows = native(["docker", "compose", "exec", "-T", "db", "mysql", "--user=root", "--batch", "--skip-column-names", "--execute", query], root)
    statuses = {}
    for endpoint in ("/", "/up"):
        with urllib.request.urlopen("http://127.0.0.1:3000" + endpoint, timeout=10) as response:
            body = response.read(1024 * 1024 + 1)
            if len(body) > 1024 * 1024 or response.status != 200:
                raise ValueError("HTTP qualification failed")
            if endpoint == "/" and b"Acme Portal" not in body:
                raise ValueError("Home does not display the manually chosen name")
            statuses[endpoint] = {"status": response.status, "sha256": hashlib.sha256(body).hexdigest()}
    return {"schemas": validate_schemas(rows), "executable_hook_hashes": identities,
            "http": statuses, "provider_hook_execution": "separate real contribution required"}


def image_diagnostics(image):
    """Project only bounded image identity fields, never Config.Env or other labels."""
    def selected(value):
        if value is None:
            return None
        if isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_.:/@-]{1,512}", value):
            return value
        return {"invalid_type_or_shape": True}

    config = image.get("Config")
    labels = config.get("Labels") if isinstance(config, dict) else None
    labels = labels if isinstance(labels, dict) else {}
    tags = image.get("RepoTags")
    return {"id": selected(image.get("Id")),
            "repo_tags": [selected(tag) for tag in tags] if isinstance(tags, list) and len(tags) <= 16 else {"invalid_inventory": True},
            "project": selected(labels.get("com.docker.compose.project")),
            "service": selected(labels.get("com.docker.compose.service"))}


def command_diagnostics(events):
    """Classify private captures using fixed indicators; no raw text is exported."""
    indicators = {"permission_denied": b"permission denied", "read_only_filesystem": b"read-only file system",
        "database_access_denied": b"access denied for user", "unknown_database": b"unknown database",
        "mysql_connection_failed": b"can't connect to mysql", "bundler_missing_gem": b"could not find gem",
        "ruby_load_error": b"loaderror", "missing_file": b"no such file or directory"}
    summaries = []
    for event in events:
        if "capture_path" not in event:
            continue
        capture = Path(event["capture_path"])
        fd = os.open(capture, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, "rb") as source:
            info = os.fstat(source.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or info.st_size > 16 * 1024 * 1024:
                raise ValueError("Private command capture identity differs")
            payload = source.read(16 * 1024 * 1024 + 1)
        if len(payload) > 16 * 1024 * 1024 or hashlib.sha256(payload).hexdigest() != event["output_sha256"]:
            raise ValueError("Private command capture bytes differ")
        lowered = payload.lower()
        permission_lines = [line for line in lowered.splitlines() if b"permission denied" in line]
        summaries.append({"output_sha256": event["output_sha256"], "bytes": len(payload),
            "indicators": [name for name, token in indicators.items() if token in lowered],
            "permission_targets": [name for name in ("tmp", "log", "db", "storage", "bin", "config")
                if any(("/rails/" + name + "/").encode() in line for line in permission_lines)]})
    return summaries


def inspect_image(root, target, records=None):
    """Accept one native object, or exact target-specific completed absence."""
    record = {"target": target, "exit": None}
    if records is not None:
        records.append(record)
    try:
        result = subprocess.run(["docker", "image", "inspect", target], cwd=root,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    except Exception as error:
        record["error_class"] = type(error).__name__
        raise
    record.update(exit=result.returncode, stdout_bytes=len(result.stdout), stderr_bytes=len(result.stderr))
    if len(result.stdout) + len(result.stderr) > 16 * 1024 * 1024:
        raise ValueError("Image inventory exceeds the existing capture ceiling")
    output = result.stdout.decode("utf-8", errors="strict")
    error = result.stderr.decode("utf-8", errors="strict")
    if result.returncode == 1 and output.strip() == "[]" and error.strip() == "Error response from daemon: No such image: " + target:
        return None
    if result.returncode != 0 or error:
        raise ValueError("Image inventory is unavailable")
    objects = json.loads(output)
    if not isinstance(objects, list) or len(objects) != 1 or not isinstance(objects[0], dict):
        raise ValueError("Image inventory must contain exactly one object")
    record["image"] = image_diagnostics(objects[0])
    return objects[0]


def owned_image_id(image, tag, project):
    """Authorize the immutable image and its complete exclusive alias inventory."""
    identifier = image.get("Id")
    if not isinstance(identifier, str) or not re.fullmatch(r"sha256:[a-f0-9]{64}", identifier):
        raise ValueError("Owned image ID is not canonical")
    config = image.get("Config")
    labels = config.get("Labels") if isinstance(config, dict) else None
    if not isinstance(labels, dict) or labels.get("com.docker.compose.project") != project:
        raise ValueError("Owned image project label differs")
    digests = image.get("RepoDigests")
    pattern = re.escape(tag.removesuffix(":local")) + r"@sha256:[a-f0-9]{64}"
    if image.get("RepoTags") != [tag] or not isinstance(digests, list):
        raise ValueError("Image aliases are not exclusively owned")
    if any(not isinstance(value, str) or not re.fullmatch(pattern, value) for value in digests) or len(set(digests)) != len(digests):
        raise ValueError("Image digest aliases are malformed, foreign or duplicate")
    return identifier


def cleanup(root, project, before, image_records=None):
    # Unique project was reserved before any Compose allocation. Never prune.
    tag = project + "-app:local"
    native(["docker", "compose", "--project-name", project, "down", "--volumes", "--remove-orphans"], root, 120)
    image = inspect_image(root, tag, image_records)
    if image is not None:
        identifier = owned_image_id(image, tag, project)
        native(["docker", "image", "rm", "--no-prune", identifier], root, 30)
        if inspect_image(root, tag, image_records) is not None or inspect_image(root, identifier, image_records) is not None:
            raise ValueError("Owned image tag or immutable ID remains")
    for args in (["ps", "-aq", "--filter", "label=com.docker.compose.project=" + project],
                 ["network", "ls", "-q", "--filter", "label=com.docker.compose.project=" + project],
                 ["volume", "ls", "-q", "--filter", "label=com.docker.compose.project=" + project],
                 ["image", "ls", "-q", "--filter", "reference=" + tag]):
        if native(["docker", *args], root):
            raise ValueError("Owned runtime resource remains")
    after = census(root)
    if any(not ids.issubset(after[kind]) for kind, ids in before.items()):
        raise ValueError("Foreign resource preservation is not established")
    return {"owned_runtime_absent": True, "foreign_baseline_preserved": True,
            "foreign_counts": {kind: len(ids) for kind, ids in before.items()}}


def numbered_script(readme, controller, root, project):
    helper = shlex.quote(str(controller))
    common = " --phase-root " + shlex.quote(str(root)) + " --project " + project
    body = commands(readme, 2)
    body += "python3 " + helper + " --phase rename" + common + "\n"
    block = commands(readme, 4)
    # README explicitly calls for private edits between dotenv creation/exports.
    if block.count("export DATABASE_NAME=") != 1:
        raise ValueError("Private-input command structure changed")
    created, exports = block.split("export DATABASE_NAME=", 1)
    body += created + "python3 " + helper + " --phase env" + common + "\n"
    body += "export DATABASE_NAME=" + exports + commands(readme, 5)
    renderer = "node_modules/@codyswann/lisa/plugins/lisa-wiki/scripts/render-contract.mjs"
    body += 'mise exec ruby@3.4.11 "node@$NODE_VERSION" "bun@$BUN_VERSION" -- node ' + renderer + " wiki/lisa-wiki.config.json\n"
    return body + commands(readme, 6)


def main(args):
    revision = require_revision(args.source_sha)
    source = Path.cwd().resolve()
    controller = Path(__file__).resolve()
    if source != Path(args.source_root).resolve() or controller.parents[3] != source:
        raise ValueError("Actual cwd must equal the explicit verifier source checkout")
    destination = Path(args.destination).absolute()
    if destination.exists() or destination.is_symlink():
        raise ValueError("Destination must be a new owned directory")
    destination.mkdir(mode=0o700)
    readme = source / "README.md"
    report = {"source_sha": revision, "qualification": args.qualification, "events": [],
              "success": False, "optional_deployment": "disabled; no AWS or deployment qualification",
              "steps_7_8": "separate automatic smoke and real contribution evidence required"}
    report["verifier_sha256"] = hashlib.sha256(controller.read_bytes()).hexdigest()
    report["verifier_commit"] = native(["git", "rev-parse", "HEAD"], source)
    root = destination / "acme-portal"
    project = "onboarding-" + secrets.token_hex(16)
    before = None
    root_identity = None
    failure = None
    try:
        assert_free_ports()
        before = census(destination)
        root_identity = allocate_clone(root)
        script(commands(readme.read_text(), 1), destination, report["events"], "step-1-literal-clone", 120)
        if native(["git", "branch", "--show-current"], root) != "main":
            raise ValueError("Literal clone does not select the documented main branch")
        if args.qualification == "candidate":
            reference = revision
            if args.pull_request:
                if not args.pull_request.isascii() or not args.pull_request.isdecimal() or int(args.pull_request) <= 0:
                    raise ValueError("Invalid pull request reference")
                reference = "refs/pull/" + args.pull_request + "/head"
            native(["git", "fetch", "origin", reference], root, 120)
            native(["git", "checkout", "--detach", revision], root, 30)
        if native(["git", "rev-parse", "HEAD"], root) != revision:
            raise ValueError("Literal published-main clone or candidate identity differs")
        for name in ("verify.py", "walkthrough.py"):
            selected = root / "test/runtime/onboarding_walkthrough" / name
            if selected.read_bytes() != (controller.parent / name).read_bytes():
                raise ValueError("Executing verifier differs from the exact cloned candidate")
        candidate_readme = (root / "README.md").read_text()
        if commands(candidate_readme, 1) != commands(readme.read_text(), 1):
            raise ValueError("Clone instructions differ from the executing verifier")
        report["readme_sha256"] = hashlib.sha256((root / "README.md").read_bytes()).hexdigest()
        body = numbered_script(candidate_readme, controller, root, project)
        script(body, root, report["events"], "steps-2-through-6-literal-commands-and-explicit-edits", 1800)
        report["acceptance"] = inspect_acceptance(root)
    except Exception as error:
        report["failure_class"] = type(error).__name__
        failure = error
    finally:
        try:
            if any(event.get("process_started") and not event["group_absent"] for event in report["events"]):
                raise RuntimeError("Command cleanup is unresolved; preserve the owned checkout")
            if before is not None and (root / ".env").is_file():
                report["image_diagnostics"] = []
                report["cleanup"] = cleanup(root, project, before, report["image_diagnostics"])
            if root_identity is not None:
                remove_clone(root, root_identity)
                report["owned_checkout_absent"] = True
            report["success"] = "failure_class" not in report and report.get("cleanup", {}).get("owned_runtime_absent", False)
        except Exception as error:
            report["success"] = False
            report["cleanup_failure_class"] = type(error).__name__
            if isinstance(error, subprocess.CalledProcessError):
                report["cleanup_native_exit"] = error.returncode
            if failure is None:
                failure = error
        finally:
            try:
                report["command_diagnostics"] = command_diagnostics(report["events"])
            except Exception as error:
                report["diagnostic_failure_class"] = type(error).__name__
                if failure is None:
                    failure = error
                report["success"] = False
            report_path = Path(args.report)
            fd = os.open(report_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            with os.fdopen(fd, "w") as output:
                json.dump(report, output, indent=2)
                output.write("\n")
    if failure is not None:
        raise failure


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=("rename", "env"))
    parser.add_argument("--phase-root")
    parser.add_argument("--project")
    parser.add_argument("--source-sha")
    parser.add_argument("--source-root")
    parser.add_argument("--pull-request", default="")
    parser.add_argument("--qualification", choices=("candidate", "published-main"), default="candidate")
    parser.add_argument("--destination")
    parser.add_argument("--report")
    options = parser.parse_args()
    if options.phase:
        phase(Path(options.phase_root), options.phase, options.project)
    else:
        main(options)
