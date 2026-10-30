"""ROM-free checks for the installable artifact."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


class PackageTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("package_mod", ROOT / "tools/package.py")
        assert spec is not None and spec.loader is not None
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def test_runtime_only_zip_with_one_mod_root(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = self.module.build(ROOT, Path(directory))
            self.assertEqual(archive.name, "crystal_time_change-1.0.0.zip")
            with zipfile.ZipFile(archive) as zipped:
                self.assertIsNone(zipped.testzip())
                expected = {"manifest.json", "main.lua", "mod.card", "README.md", "LICENSE"}
                self.assertEqual(set(zipped.namelist()), expected)
                for name in expected:
                    self.assertEqual(zipped.read(name), (ROOT / name).read_bytes())
                manifest = json.loads(zipped.read("manifest.json"))
                self.assertEqual(manifest["games"], ["crystal"])
                self.assertEqual(manifest["permissions"], ["engine_internals"])
    def test_release_version_is_stamped_without_editing_source_and_checksum_matches(self):
        source = (ROOT / "manifest.json").read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            archive = self.module.build(ROOT, Path(directory), version="2.3.4")
            self.assertEqual(archive.name, "crystal_time_change-2.3.4.zip")
            with zipfile.ZipFile(archive) as zipped:
                self.assertEqual(json.loads(zipped.read("manifest.json"))["version"], "2.3.4")
                self.assertEqual(zipped.read("main.lua"), (ROOT / "main.lua").read_bytes())
            import hashlib
            checksum = archive.with_suffix(".zip.sha256").read_text()
            self.assertEqual(checksum, f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")
        self.assertEqual((ROOT / "manifest.json").read_bytes(), source)
    def test_invalid_release_versions_are_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            for version in ("../escape", "v1.2.3", "01.2.3", "1.2", "1.2.3;exit", "1.2.3-beta.1"):
                with self.subTest(version=version), self.assertRaises(ValueError):
                    self.module.build(ROOT, Path(directory), version=version)
            self.assertEqual(list(Path(directory).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
