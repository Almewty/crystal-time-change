"""Build a deterministic, single-mod Gen1Recomp installation ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

RUNTIME_FILES = ("LICENSE", "README.md", "main.lua", "manifest.json", "mod.card")


def build(root: Path, output: Path, version: str | None = None) -> Path:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    if version is not None:
        manifest["version"] = version
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", manifest["version"]):
        raise ValueError("Expected a stable semantic version, e.g. 1.2.3 (without v)")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"{manifest['id']}-{manifest['version']}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zipped:
        for name in RUNTIME_FILES:
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            body = (root / name).read_bytes()
            if name == "manifest.json" and version is not None:
                body = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
            zipped.writestr(info, body)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", help="semantic-release version to stamp into the archive only")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    print(build(project, project / "dist", version=args.version))
