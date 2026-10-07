"""Authored exported-image fixtures exercise hidden layers and tar metadata."""
import importlib.util
import io
import json
import pathlib
import shutil
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("image_scanner", ROOT / "bin/verify-deployment-images.py")
SCANNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SCANNER)


class ImageLayerScannerTest(unittest.TestCase):
    sentinel = b"synthetic-scanner-proof-unique-29f6ad53"
    identity = "sha256:" + "f" * 64

    def scan(self, layers, environment=None):
        with tempfile.TemporaryDirectory(prefix="image-scanner-spec-") as scratch:
            directory = pathlib.Path(scratch)
            archive = directory / "image.tar"
            with tarfile.open(archive, "w") as saved:
                names = []
                for index, (entries, compressed) in enumerate(layers):
                    name = f"layer-{index}.tar"
                    names.append(name)
                    data = io.BytesIO()
                    with tarfile.open(fileobj=data, mode="w:gz" if compressed else "w",
                                      format=tarfile.PAX_FORMAT) as layer:
                        for entry, content in entries:
                            entry.size = len(content) if entry.isfile() else 0
                            layer.addfile(entry, io.BytesIO(content) if entry.isfile() else None)
                    self.add_file(saved, name, data.getvalue())
                self.add_file(saved, "manifest.json", json.dumps([{"Layers": names}]).encode())
            inspection = [{"Id": self.identity, "Architecture": "authored-fixture",
                           "Config": {"Env": environment or []}}]
            report = directory / "report.json"
            with patch.object(SCANNER, "output", return_value=json.dumps(inspection)), patch.object(
                    SCANNER, "run", side_effect=lambda *args: shutil.copyfile(
                        archive, args[args.index("--output") + 1])):
                try:
                    SCANNER.inspect_layers("authored-image", self.sentinel, report)
                    rejected = False
                except RuntimeError:
                    rejected = True
            return rejected, json.loads(report.read_text())

    @staticmethod
    def add_file(archive, name, content):
        entry = tarfile.TarInfo(name)
        entry.size = len(content)
        archive.addfile(entry, io.BytesIO(content))

    def assert_rejected(self, entries, compressed=False):
        rejected, report = self.scan([(entries, compressed)])
        self.assertTrue(rejected)
        self.assertTrue(report["findings"])

    def test_clean_layer_is_allowed(self):
        rejected, report = self.scan([([(tarfile.TarInfo("rails/ordinary.txt"), b"safe")], False)])
        self.assertFalse(rejected)
        self.assertEqual(report["image_id"], self.identity)
        self.assertEqual(report["findings"], [])

    def test_regular_file_content_is_rejected(self):
        self.assert_rejected([(tarfile.TarInfo("rails/ordinary.txt"), self.sentinel)])

    def test_file_name_is_rejected(self):
        self.assert_rejected([(tarfile.TarInfo("rails/" + self.sentinel.decode()), b"safe")])

    def test_symlink_target_is_rejected(self):
        entry = tarfile.TarInfo("rails/ordinary-link")
        entry.type = tarfile.SYMTYPE
        entry.linkname = self.sentinel.decode()
        self.assert_rejected([(entry, b"")])

    def test_hardlink_target_is_rejected(self):
        entry = tarfile.TarInfo("rails/ordinary-link")
        entry.type = tarfile.LNKTYPE
        entry.linkname = self.sentinel.decode()
        self.assert_rejected([(entry, b"")])

    def test_compressed_layer_pax_metadata_is_rejected(self):
        entry = tarfile.TarInfo("rails/ordinary.txt")
        entry.pax_headers = {"comment": self.sentinel.decode()}
        self.assert_rejected([(entry, b"safe")], compressed=True)

    def test_credential_path_is_rejected_without_the_sentinel(self):
        self.assert_rejected([(tarfile.TarInfo("rails/aws_credentials"), b"other-value")])

    def test_later_whiteout_does_not_hide_lower_layer_content(self):
        rejected, report = self.scan([
            ([(tarfile.TarInfo("rails/deleted.txt"), self.sentinel)], False),
            ([(tarfile.TarInfo("rails/.wh.deleted.txt"), b"")], False)])
        self.assertTrue(rejected)
        self.assertTrue(report["findings"])
        self.assertEqual(len(report["layers"]), 2)

    def test_aws_image_environment_is_rejected(self):
        rejected, report = self.scan([([], False)], environment=["AWS_ACCESS_KEY_ID=synthetic"])
        self.assertTrue(rejected)
        self.assertTrue(report["findings"])


if __name__ == "__main__":
    unittest.main()
