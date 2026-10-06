"""Runtime receipt boundaries; actual Docker execution runs in the image job."""
import copy
import importlib.util
import pathlib
import stat
import subprocess
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("runtime_images", ROOT / "bin/verify-runtime-images.py")
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class RuntimeReceiptTest(unittest.TestCase):
    def test_final_images_normalize_source_access_before_dropping_privileges(self):
        for name in ('Dockerfile', 'worker.Dockerfile'):
            with self.subTest(name=name):
                final = (ROOT / name).read_text().rsplit('FROM base', 1)[1]
                copied = final.index('COPY --from=build /rails /rails')
                normalized = final.index('chmod -R a+rX /rails')
                unprivileged = final.index('USER rails:rails')
                self.assertLess(copied, normalized)
                self.assertLess(normalized, unprivileged)
                self.assertIn('chown -R rails:rails db log storage tmp', final)

    def test_image_access_normalization_preserves_executable_bits_without_granting_write(self):
        with tempfile.TemporaryDirectory(prefix='runtime-source-access-') as directory:
            root = pathlib.Path(directory)
            folder = root / 'bin'
            folder.mkdir(mode=0o700)
            script, data = folder / 'entrypoint', folder / 'ordinary'
            script.write_text('#!/bin/sh\nexit 0\n')
            data.write_text('ordinary application source\n')
            script.chmod(0o700)
            data.chmod(0o600)
            subprocess.run(['chmod', '-R', 'a+rX', str(root)], check=True, timeout=10)
            self.assertEqual(stat.S_IMODE(folder.stat().st_mode), 0o755)
            self.assertEqual(stat.S_IMODE(script.stat().st_mode), 0o755)
            self.assertEqual(stat.S_IMODE(data.stat().st_mode), 0o644)
            for path in (root, folder, script, data):
                self.assertEqual(stat.S_IMODE(path.stat().st_mode) & 0o022, 0)

    def receipt(self):
        return {"boot": "production", "image_mode": True, "eager_load": True,
                "runtime": {"ruby": "3.4.11", "patchlevel": 137, "platform": "x86_64-linux",
                            "extensions": {name: {"path": f"/bundle/{name}/{name}.so",
                                                   "sha256": "a" * 64}
                                           for name in ("mysql2", "bootsnap")}},
                "versions": {"rails": "8.1.4", "json": "2.21.2"},
                "requests": [{"path": "/", "status": 200}, {"path": "/up", "status": 200}],
                "aws_requests": {"ssm.get_parameters_by_path": 1, "cloudformation.list_exports": 1,
                                 "secretsmanager.list_secrets": 1, "secretsmanager.get_secret_value": 1},
                "databases": [{"name": name} for name in ("primary", "queue", "cache", "cable")]}

    def validate(self, receipt):
        VERIFIER.validate_receipt(receipt, {"version": "3.4.11", "patchlevel": 137},
                                  {"rails": "8.1.4", "json": "2.21.2"},
                                  ["primary", "queue", "cache", "cable"])

    def test_complete_runtime_receipt(self):
        self.validate(self.receipt())

    def test_refuses_unbooted_or_different_runtime(self):
        for path, value in (("boot", "test"), ("eager_load", False), ("image_mode", False)):
            with self.subTest(path=path):
                receipt = self.receipt()
                receipt[path] = value
                with self.assertRaises(RuntimeError):
                    self.validate(receipt)
        for key, value in (("ruby", "3.4.8"), ("patchlevel", 0), ("platform", "aarch64-linux")):
            receipt = self.receipt()
            receipt["runtime"][key] = value
            with self.assertRaises(RuntimeError):
                self.validate(receipt)

    def test_refuses_missing_native_identity_or_old_gem(self):
        for mutate in (lambda value: value["runtime"]["extensions"].pop("mysql2"),
                       lambda value: value["runtime"]["extensions"]["bootsnap"].update(sha256=""),
                       lambda value: value["versions"].update(rails="8.1.3")):
            receipt = self.receipt()
            mutate(receipt)
            with self.assertRaises(RuntimeError):
                self.validate(receipt)

    def test_refuses_http_failure_extra_aws_call_or_wrong_schema(self):
        for mutate in (lambda value: value["requests"][0].update(status=500),
                       lambda value: value["aws_requests"].update({"s3.put_object": 1}),
                       lambda value: value["databases"][0].update(name="foreign")):
            receipt = copy.deepcopy(self.receipt())
            mutate(receipt)
            with self.assertRaises(RuntimeError):
                self.validate(receipt)


class CleanupBoundaryTest(unittest.TestCase):
    def test_malformed_allocation_retains_owned_name_for_cleanup(self):
        owner = VERIFIER.RuntimeImages(pathlib.Path('/unused-unit-report'))
        with patch.object(owner, 'command', return_value=SimpleNamespace(stdout='')):
            with self.assertRaisesRegex(RuntimeError, 'no valid container identity'):
                owner.provision()
        self.assertEqual(owner.cid, owner.name)
        self.assertIn(owner.name, owner.pending)

    def owner(self, failed=None, pending=False, absent=False):
        owner = SimpleNamespace(children={'child-one': 'immutable-one', 'child-two': 'immutable-two'},
                                cid='owned-mysql', name='owned-mysql', volume='owned-volume',
                                volume_created=True, nonce='nonce', report={},
                                pending={'child-one'} if pending else set(), calls=[])
        existing = set() if absent else {'child-one', 'child-two', 'owned-mysql', 'owned-volume'}

        def command(*args):
            owner.calls.append(args)
            if args[:2] in (('container', 'ls'), ('volume', 'ls')):
                target = args[args.index('--filter') + 1].split('=', 1)[1].strip('^/$')
                target = target.replace('\\-', '-')
                if target == failed:
                    raise RuntimeError('Docker daemon query failed')
                return SimpleNamespace(stdout=target if target in existing else '')
            if args[:2] == ('rm', '-f'):
                existing.remove(args[2])
            elif args[:2] == ('volume', 'rm'):
                existing.remove(args[2])
            return SimpleNamespace(stdout='')

        owner.command = command
        owner.owned_child = lambda name: owner.calls.append(('validate-child', name))
        owner.owned_database = lambda: owner.calls.append(('validate-mysql',))
        owner.inspect = lambda *args: [{'Labels': {'runtime-image.nonce': 'nonce'}}]
        return owner

    def test_recovers_reserved_allocation_with_positive_ownership(self):
        owner = self.owner(pending=True)
        VERIFIER.cleanup_resources(owner)
        self.assertEqual(owner.pending, set())
        self.assertTrue(owner.report['cleanup']['verified'])
        self.assertIn(('validate-child', 'child-one'), owner.calls)
        self.assertIn(('rm', '-f', 'child-one'), owner.calls)

    def test_unresolved_allocation_never_claims_cleanup(self):
        owner = self.owner(pending=True, absent=True)
        with self.assertRaises(RuntimeError):
            VERIFIER.cleanup_resources(owner)
        self.assertNotIn('verified', owner.report['cleanup'])
        self.assertEqual(owner.report['cleanup']['pending_allocations'], ['child-one'])

    def test_query_error_is_not_absence_and_other_resources_are_attempted(self):
        owner = self.owner(failed='child-one')
        with self.assertRaises(RuntimeError):
            VERIFIER.cleanup_resources(owner)
        self.assertEqual(owner.report['cleanup']['resources']['child-one'], 'unverified')
        self.assertIn(('rm', '-f', 'child-two'), owner.calls)
        self.assertIn(('rm', '-f', 'owned-mysql'), owner.calls)
        self.assertIn(('volume', 'rm', 'owned-volume'), owner.calls)
        self.assertNotIn('verified', owner.report['cleanup'])


if __name__ == "__main__":
    unittest.main()
