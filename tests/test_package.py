"""ROM-free checks for the installable artifact."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


class PackageTest(unittest.TestCase):
    def test_runtime_only_zip_with_one_mod_root(self):
        spec = importlib.util.spec_from_file_location("package_mod", ROOT / "tools/package.py")
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            archive = module.build(ROOT, Path(directory))
            self.assertEqual(archive.name, "crystal-time-change-1.0.0.zip")
            with zipfile.ZipFile(archive) as zipped:
                self.assertIsNone(zipped.testzip())
                expected = {"manifest.json", "main.lua", "mod.card", "README.md", "LICENSE"}
                self.assertEqual(set(zipped.namelist()), {f"crystal_time_change/{p}" for p in expected})
                for name in expected:
                    self.assertEqual(zipped.read(f"crystal_time_change/{name}"), (ROOT / name).read_bytes())
                manifest = json.loads(zipped.read("crystal_time_change/manifest.json"))
                self.assertEqual(manifest["games"], ["crystal"])
                self.assertEqual(manifest["permissions"], ["engine_internals"])


if __name__ == "__main__":
    unittest.main()
