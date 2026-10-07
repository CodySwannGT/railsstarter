"""Behavioral controls for the fresh README walkthrough's trust boundaries."""
import socket
import json
import os
import secrets
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from contextlib import contextmanager
from types import SimpleNamespace
from pathlib import Path

from walkthrough import (assert_free_ports, commands, configure_private_env, rename_application,
                         require_revision, validate_schemas, allocate_clone, remove_clone,
                         exited_without_reaping, finish_group, group_rows, drain_available)
from verify import cleanup, inspect_image, script


def process_identity(pid):
    result = subprocess.run(["ps", "-p", str(pid), "-o", "pid=,pgid=,uid=,lstart="],
                            text=True, capture_output=True, timeout=2)
    if result.returncode == 1 and not result.stdout.strip():
        return None
    if result.returncode != 0:
        raise RuntimeError("Native process observation failed")
    return result.stdout.strip()


def owned_child_body(root, ending):
    ready = root / "child-ready.json"
    token = secrets.token_hex(16)
    payload = "\n".join(("import json,os,signal,subprocess,time", "from pathlib import Path",
        "signal.signal(signal.SIGTERM,signal.SIG_IGN)",
        "identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,pgid=,uid=,lstart='],text=True).strip()",
        "Path(" + repr(str(ready)) + ").write_text(json.dumps({'pid':os.getpid(),'identity':identity,'token':" + repr(token) + "}))",
        "time.sleep(30)"))
    body = shlex.quote(sys.executable) + " -c " + shlex.quote(payload) + " &\n"
    body += "while test ! -s " + shlex.quote(str(ready)) + "; do sleep 0.01; done\n" + ending
    return body, ready, token


def remove_exact_test_child(ready, token):
    if not ready.exists():
        return
    record = json.loads(ready.read_text())
    if record["token"] != token:
        raise RuntimeError("Synthetic child token mismatch")
    current = process_identity(record["pid"])
    if current is not None:
        if current != record["identity"]:
            raise RuntimeError("Synthetic child birth/group identity changed")
        os.kill(record["pid"], signal.SIGKILL)
        deadline = time.monotonic() + 2
        while process_identity(record["pid"]) is not None and time.monotonic() < deadline:
            time.sleep(0.01)
        if process_identity(record["pid"]) is not None:
            raise RuntimeError("Owned synthetic child remains")


class WalkthroughContracts(unittest.TestCase):
    def test_final_nonblocking_drain_keeps_the_complete_capture_ceiling(self):
        reader_fd, writer_fd = os.pipe()
        try:
            os.write(writer_fd, b"tail" * 32)
            with os.fdopen(reader_fd, "rb") as reader, tempfile.TemporaryFile("w+b") as output:
                output.write(b"prefix" * ((16 * 1024 * 1024 - 16) // 6))
                with self.assertRaises(ValueError):
                    drain_available(SimpleNamespace(stdout=reader), output)
                self.assertEqual(output.tell(), 16 * 1024 * 1024)
        finally:
            os.close(writer_fd)

    def test_timeout_preserves_output_written_before_delayed_identity_observation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ready = root / "output-ready"
            token = secrets.token_hex(16)
            original = group_rows
            delayed = False

            def observe(group):
                nonlocal delayed
                rows = original(group)
                if not delayed:
                    deadline = time.monotonic() + 2
                    while not ready.exists() and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertEqual(ready.read_text(), token)
                    delayed = True
                    time.sleep(0.15)
                return rows

            body = "printf synthetic-timeout >&2; printf %s " + shlex.quote(token)
            body += " > " + shlex.quote(str(ready)) + "; sleep 30"
            events = []
            with patch("walkthrough.group_rows", side_effect=observe):
                with self.assertRaises(subprocess.TimeoutExpired):
                    script(body, root, events, "delayed-identity", 0.1)
            self.assertTrue(events[0]["group_absent"])
            self.assertEqual(Path(events[0]["capture_path"]).read_text(), "synthetic-timeout")

    def test_real_waitid_keeps_native_leader_pinned_until_cleanup(self):
        process = subprocess.Popen([sys.executable, "-c", "raise SystemExit(17)"], start_new_session=True)
        deadline = time.monotonic() + 2
        try:
            identity = group_rows(process.pid)[process.pid]
            outcome = exited_without_reaping(process)
            while outcome is None and time.monotonic() < deadline:
                time.sleep(0.01)
                outcome = exited_without_reaping(process)
            self.assertIsNotNone(outcome)
            self.assertEqual(outcome.si_status, 17)
            self.assertEqual(group_rows(process.pid)[process.pid], identity)
            status, _ = finish_group(process, identity)
            self.assertEqual(status, 17)
            self.assertEqual(group_rows(process.pid), {})
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=2)

    def test_output_ceiling_preserves_bounded_failure_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = "import sys; sys.stdout.buffer.write(b'x'*(17*1024*1024))"
            body = shlex.quote(sys.executable) + " -c " + shlex.quote(payload)
            events = []
            with self.assertRaises(ValueError):
                script(body, root, events, "output-ceiling", 3)
            self.assertTrue(events[0]["group_absent"])
            self.assertEqual(Path(events[0]["capture_path"]).stat().st_size, 16 * 1024 * 1024)

    def test_failed_native_clone_cleans_pinned_partial_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / "acme-portal"
            identity = allocate_clone(root)
            self.assertEqual(root.stat().st_mode & 0o777, 0o700)
            events = []
            try:
                body = "touch acme-portal/partial\ngit clone " + shlex.quote(str(parent / "missing-source")) + " acme-portal\n"
                with self.assertRaises(ValueError):
                    script(body, parent, events, "failed-clone", 3)
                self.assertEqual(events[0]["exit"], 128)
                self.assertTrue((root / "partial").is_file())
                self.assertEqual(events[0]["failure_location"]["reported_status"], 128)
            finally:
                remove_clone(root, identity)
            self.assertFalse(root.exists())

    def test_checkout_cleanup_refuses_replacement_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            root = parent / "acme-portal"
            identity = allocate_clone(root)
            root.rmdir()
            foreign = parent / "foreign"
            foreign.mkdir()
            sentinel = foreign / "sentinel"
            sentinel.write_text("foreign")
            root.symlink_to(foreign, target_is_directory=True)
            with self.assertRaises(ValueError):
                remove_clone(root, identity)
            self.assertEqual(sentinel.read_text(), "foreign")

    def test_timeout_retains_failure_event_and_private_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            events = []
            with self.assertRaises(subprocess.TimeoutExpired):
                script("printf synthetic-timeout >&2; sleep 30", root, events, "timeout", 0.1)
            self.assertEqual(len(events), 1)
            self.assertEqual(events[0]["error_class"], "TimeoutExpired")
            self.assertTrue(events[0]["waitid_qualified"])
            self.assertEqual(events[0]["platform"], sys.platform)
            capture = Path(events[0]["capture_path"])
            self.assertEqual(capture.stat().st_mode & 0o777, 0o600)
            self.assertEqual(capture.read_text(), "synthetic-timeout")

    def test_early_leader_failure_removes_term_ignoring_group_member(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            body, ready, token = owned_child_body(root, "exit 17\n")
            events = []
            try:
                with self.assertRaises(ValueError):
                    script(body, root, events, "early-leader", 3)
                record = json.loads(ready.read_text())
                self.assertIsNone(process_identity(record["pid"]))
                self.assertEqual(events[0]["exit"], 17)
                self.assertTrue(events[0]["group_absent"])
            finally:
                remove_exact_test_child(ready, token)

    def test_timeout_removes_group_member_after_leader_exits_on_term(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            body, ready, token = owned_child_body(root, "sleep 30\n")
            events = []
            try:
                with self.assertRaises(subprocess.TimeoutExpired):
                    script(body, root, events, "timeout-child", 1)
                record = json.loads(ready.read_text())
                self.assertIsNone(process_identity(record["pid"]))
                self.assertTrue(events[0]["group_absent"])
            finally:
                remove_exact_test_child(ready, token)

    def test_rejects_revision_options_and_abbreviations(self):
        for value in ("HEAD", "--upload-pack=x", "a" * 39, "A" * 40, "a" * 40 + "\n"):
            with self.assertRaises(ValueError):
                require_revision(value)
        self.assertEqual(require_revision("a" * 40), "a" * 40)

    def test_commands_come_from_the_named_numbered_section(self):
        text = "### 2. Tools\n```sh\necho first\n```\n```sh\necho second\n```\n### 3. Rename\n```sh\necho other\n```\n"
        self.assertEqual(commands(text, 2), "echo first\necho second\n")
        with self.assertRaises(ValueError):
            commands(text, 5)

    def test_occupied_port_refuses_without_stopping_its_owner(self):
        with socket.socket() as foreign:
            foreign.bind(("127.0.0.1", 0))
            foreign.listen()
            with self.assertRaises(OSError):
                assert_free_ports([foreign.getsockname()[1]])
            self.assertGreater(foreign.fileno(), -1)

    def test_manual_rename_preserves_dependency_resolutions(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("config", "app/views/home", "app/views/layouts", "app/views/pwa"):
                (root / name).mkdir(parents=True, exist_ok=True)
            (root / "config/application.rb").write_text("module App\nend\n")
            for name in ("home/index.html.erb", "layouts/application.html.erb", "pwa/manifest.json.erb"):
                (root / "app/views" / name).write_text("Your Project")
            (root / "package.json").write_text('{"name":"your-project","dependencies":{"x":"1"}}')
            lock = {"name": "your-project", "packages": {"": {"name": "your-project"}, "node_modules/x": {"integrity": "unchanged"}}}
            (root / "package-lock.json").write_text(json.dumps(lock))
            bun_bytes = '{"workspaces":{"":{"name":"your-project",}},"packages":{"x":"unchanged"}}'
            (root / "bun.lock").write_text(bun_bytes)
            rename_application(root)
            self.assertIn("module AcmePortal", (root / "config/application.rb").read_text())
            updated = json.loads((root / "package-lock.json").read_text())
            self.assertEqual(updated["packages"]["node_modules/x"], lock["packages"]["node_modules/x"])
            self.assertEqual(updated["packages"][""]["name"], "acme-portal")
            self.assertEqual((root / "bun.lock").read_text(), bun_bytes.replace('"name":"your-project"', '"name":"acme-portal"'))

    def test_schema_qualification_requires_all_eight_native_identities(self):
        suffixes = ("", "_queue", "_cache", "_cable", "_test", "_queue_test", "_cache_test", "_cable_test")
        rows = ["acme_portal" + suffix + "\tutf8mb4\tutf8mb4_0900_ai_ci" for suffix in suffixes]
        self.assertEqual(len(validate_schemas("\n".join(rows))), 8)
        for corrupt in (rows[:-1], rows + rows[:1], [row.replace("utf8mb4_0900_ai_ci", "latin1_swedish_ci") for row in rows]):
            with self.assertRaises(ValueError):
                validate_schemas("\n".join(corrupt))

    def test_private_input_refuses_symlink_and_preserves_its_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "foreign.env"
            target.write_text("foreign")
            (root / ".env").symlink_to(target)
            with self.assertRaises(ValueError):
                configure_private_env(root, "owned", "synthetic-key")
            self.assertEqual(target.read_text(), "foreign")


class ImageCleanupContracts(unittest.TestCase):
    """Synthetic Docker protocol controls, never native image qualification."""

    @contextmanager
    def protocol(self, mutate=None, residual=None, removal_error=False):
        project = "onboarding-" + "a" * 32
        tag = project + "-app:local"
        identifier = "sha256:" + "b" * 64
        image = {"Id": identifier, "RepoTags": [tag], "RepoDigests": [],
                 "Config": {"Labels": {"com.docker.compose.project": project}}}
        if mutate:
            mutate(image)
        removed = []

        def native_fixture(args, _cwd, _timeout=30):
            if args[:3] == ["docker", "image", "rm"]:
                self.assertEqual(_timeout, 30)
                removed.append(args)
                if removal_error:
                    raise subprocess.CalledProcessError(17, args)
            if args[:3] == ["docker", "image", "ls"] and not removed:
                return identifier
            if "--format" in args:
                return identifier + "|" + project
            return ""

        def inspect_fixture(args, **_options):
            self.assertEqual(_options["timeout"], 30)
            target = args[-1]
            if removed and residual == "unknown":
                return subprocess.CompletedProcess(args, 1, b"", b"daemon unavailable\n")
            if not removed or (residual == "id" and target == identifier):
                return subprocess.CompletedProcess(args, 0, json.dumps([image]).encode(), b"")
            return subprocess.CompletedProcess(args, 1, b"[]\n",
                ("Error response from daemon: No such image: " + target + "\n").encode())

        with patch("verify.native", side_effect=native_fixture), patch("verify.subprocess.run", side_effect=inspect_fixture):
            yield lambda: cleanup(Path("/synthetic-owned"), project,
                                  {kind: set() for kind in ("containers", "networks", "volumes", "images")}), removed, identifier

    def test_removal_uses_full_id_without_parent_pruning_or_force(self):
        with self.protocol() as (perform, removed, identifier):
            self.assertTrue(perform()["owned_runtime_absent"])
            self.assertEqual(removed, [["docker", "image", "rm", "--no-prune", identifier]])

    def test_foreign_or_duplicate_aliases_are_refused_before_removal(self):
        corruptions = (lambda image: image.update(RepoTags=[*image["RepoTags"], "foreign:local"]),
            lambda image: image.update(RepoDigests=["foreign@sha256:" + "c" * 64]),
            lambda image: image.update(RepoDigests=[image["RepoTags"][0][:-6] + "@sha256:" + "c" * 64] * 2),
            lambda image: image.update(RepoDigests=None))
        for mutate in corruptions:
            with self.subTest(mutate=mutate), self.protocol(mutate) as (perform, removed, _identifier):
                with self.assertRaises(ValueError):
                    perform()
                self.assertEqual(removed, [])

    def test_noncanonical_id_or_wrong_project_are_refused(self):
        corruptions = (lambda image: image.update(Id="short-id"),
            lambda image: image.update(Config={"Labels": {"com.docker.compose.project": "foreign"}}))
        for mutate in corruptions:
            with self.subTest(mutate=mutate), self.protocol(mutate) as (perform, removed, _identifier):
                with self.assertRaises(ValueError):
                    perform()
                self.assertEqual(removed, [])

    def test_tag_absence_does_not_hide_remaining_immutable_id(self):
        with self.protocol(residual="id") as (perform, _removed, _identifier):
            with self.assertRaises(ValueError):
                perform()

    def test_unknown_postremoval_inventory_is_not_absence(self):
        with self.protocol(residual="unknown") as (perform, _removed, _identifier):
            with self.assertRaises(ValueError):
                perform()

    def test_unique_owned_digest_is_supported(self):
        def with_digest(image):
            image["RepoDigests"] = [image["RepoTags"][0][:-6] + "@sha256:" + "c" * 64]
        with self.protocol(with_digest) as (perform, removed, _identifier):
            self.assertTrue(perform()["owned_runtime_absent"])
            self.assertEqual(len(removed), 1)

    def test_failed_native_removal_remains_failure(self):
        with self.protocol(removal_error=True) as (perform, removed, _identifier):
            with self.assertRaises(subprocess.CalledProcessError) as failure:
                perform()
            self.assertEqual(failure.exception.returncode, 17)
            self.assertEqual(len(removed), 1)

    def test_malformed_or_unrelated_native_inventory_never_means_absence(self):
        target = "synthetic-app:local"
        responses = ((0, b"{}", b""), (0, b"[]", b""),
            (0, b"[{},{}]", b""), (0, b"null", b""), (0, b"not-json", b""),
            (1, b"[]\n", b"Error response from daemon: No such image: foreign:local\n"),
            (1, b"[]\n", ("Error response from daemon: No such image: " + target + "\ndaemon unavailable\n").encode()),
            (-15, b"[]\n", ("Error response from daemon: No such image: " + target + "\n").encode()))
        for code, output, error in responses:
            result = subprocess.CompletedProcess(["docker"], code, output, error)
            with self.subTest(code=code, output=output), patch("verify.subprocess.run", return_value=result):
                with self.assertRaises(ValueError):
                    inspect_image(Path("/synthetic-owned"), target)


if __name__ == "__main__":
    unittest.main()
