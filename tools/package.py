"""Build a deterministic, single-mod Gen1Recomp installation ZIP."""
import json
from pathlib import Path
import zipfile

RUNTIME_FILES = ("LICENSE", "README.md", "main.lua", "manifest.json", "mod.card")


def build(root: Path, output: Path) -> Path:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"crystal-time-change-{manifest['version']}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zipped:
        for name in RUNTIME_FILES:
            info = zipfile.ZipInfo(f"{manifest['id']}/{name}", date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zipped.writestr(info, (root / name).read_bytes())
    return archive


if __name__ == "__main__":
    project = Path(__file__).resolve().parents[1]
    print(build(project, project / "dist"))
