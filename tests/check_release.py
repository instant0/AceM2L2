#!/usr/bin/env python3
"""Validate the AceM2L2 release zip against the workspace.

Checks:
- version derived from AceM2L2.toc
- one top-level AceM2L2/ directory
- exact packaged allowlist and exclusions
- every entry byte-identical to the workspace
- every expected workspace file present
- TOC and packaged README.txt versions match
- optional dist/ and /mnt/r/ SHA-256 match
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT_FILES = (
    "AceM2L2.toc",
    "ACEM2L2.lua",
    "Bindings.lua",
    "embeds.xml",
    "README.txt",
    "LICENSE",
)
TREES = ("Core", "KillHistory", "Libs", "Textures")
FORBIDDEN_PREFIXES = ("dev/", "dist/", "tests/", ".git/")
FORBIDDEN_SUFFIXES = (".pyc", ".pyo", ".log", ".bak", ".swp")
FORBIDDEN_NAMES = {".DS_Store", "Thumbs.db", "luac.out", "README.md", ".gitignore"}
VERSION_RE = re.compile(r"^## Version:\s*(\S+)\s*$", re.MULTILINE)
README_VERSION_RE = re.compile(r"^Version:\s*(\S+)\s*$", re.MULTILINE)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_files(root: Path) -> set[str]:
    files = {f"AceM2L2/{name}" for name in ROOT_FILES}
    for tree in TREES:
        base = root / tree
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(root).as_posix()
            if relative.startswith("Libs/LibStub/tests/"):
                continue
            files.add(f"AceM2L2/{relative}")
    return files


def validate_zip(root: Path, zip_path: Path, expected_version: str) -> list[str]:
    errors: list[str] = []
    if not zip_path.is_file():
        return [f"missing release zip: {zip_path}"]

    expect = expected_files(root)
    with zipfile.ZipFile(zip_path) as archive:
        bad_member = archive.testzip()
        if bad_member:
            errors.append(f"{zip_path.name}: corrupt entry {bad_member}")

        names = [info.filename for info in archive.infolist() if not info.is_dir()]
        top_levels = {name.split("/", 1)[0] for name in names}
        if top_levels != {"AceM2L2"}:
            errors.append(f"{zip_path.name}: expected one top-level AceM2L2/, got {sorted(top_levels)}")

        for name in names:
            inner = name.split("/", 1)[1] if "/" in name else ""
            if not inner:
                errors.append(f"{zip_path.name}: unexpected root entry {name}")
                continue
            if inner.startswith(FORBIDDEN_PREFIXES):
                errors.append(f"{zip_path.name}: forbidden entry {name}")
            if inner.endswith(FORBIDDEN_SUFFIXES) or inner.rsplit("/", 1)[-1] in FORBIDDEN_NAMES:
                errors.append(f"{zip_path.name}: forbidden file {name}")
            if inner.startswith("Libs/LibStub/tests/"):
                errors.append(f"{zip_path.name}: bundled LibStub tests {name}")

        missing = sorted(expect - set(names))
        extra = sorted(set(names) - expect)
        for name in missing:
            errors.append(f"{zip_path.name}: missing expected entry {name}")
        for name in extra:
            errors.append(f"{zip_path.name}: unexpected entry {name}")

        for name in sorted(set(names) & expect):
            workspace = root / name.split("/", 1)[1]
            if not workspace.is_file():
                errors.append(f"workspace file missing for packaged entry: {name}")
                continue
            if archive.read(name) != workspace.read_bytes():
                errors.append(f"{zip_path.name}: entry differs from workspace: {name}")

        try:
            toc_text = archive.read("AceM2L2/AceM2L2.toc").decode("utf-8")
            match = VERSION_RE.search(toc_text)
            if not match or match.group(1) != expected_version:
                errors.append(f"{zip_path.name}: TOC version mismatch")
        except KeyError:
            errors.append(f"{zip_path.name}: missing AceM2L2/AceM2L2.toc")

        try:
            readme_text = archive.read("AceM2L2/README.txt").decode("utf-8")
            match = README_VERSION_RE.search(readme_text)
            if not match or match.group(1) != expected_version:
                errors.append(f"{zip_path.name}: README.txt version mismatch")
        except KeyError:
            errors.append(f"{zip_path.name}: missing AceM2L2/README.txt")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--zip", type=Path, default=None)
    args = parser.parse_args()

    root = args.root.resolve()
    toc = root / "AceM2L2.toc"
    if not toc.is_file():
        print("missing AceM2L2.toc")
        return 1
    match = VERSION_RE.search(toc.read_text(encoding="utf-8"))
    if not match:
        print("missing ## Version in AceM2L2.toc")
        return 1
    version = match.group(1)

    zip_paths = []
    if args.zip:
        zip_paths.append(args.zip)
    else:
        zip_paths.append(root / "dist" / f"AceM2L2-{version}.zip")
        mnt = Path("/mnt/r") / f"AceM2L2-{version}.zip"
        if mnt.is_file():
            zip_paths.append(mnt)

    errors: list[str] = []
    hashes: list[tuple[Path, str]] = []
    for path in zip_paths:
        errors.extend(validate_zip(root, path, version))
        if path.is_file():
            hashes.append((path, sha256(path)))

    if len(hashes) > 1:
        first = hashes[0][1]
        for path, digest in hashes[1:]:
            if digest != first:
                errors.append(f"SHA mismatch: {hashes[0][0]} vs {path}")

    print(f"Version: {version}")
    for path, digest in hashes:
        print(f"SHA-256 {path}: {digest}")
    for error in errors:
        print(f"ERROR: {error}")

    if errors:
        print("Release check failed.")
        return 1
    print("Release check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
