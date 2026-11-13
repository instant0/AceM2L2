#!/usr/bin/env python3
"""Build the AceM2L2 release zip from the workspace allowlist."""

from __future__ import annotations

import argparse
import re
import zipfile
from pathlib import Path

ROOT_FILES = (
    "AceM2L2.toc",
    "ACEM2L2.lua",
    "Bindings.lua",
    "Bindings.xml",
    "embeds.xml",
    "README.txt",
    "LICENSE",
)
TREES = ("Core", "KillHistory", "Libs")
VERSION_RE = re.compile(r"^## Version:\s*(\S+)\s*$", re.MULTILINE)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()

    root = args.root.resolve()
    toc = root / "AceM2L2.toc"
    match = VERSION_RE.search(toc.read_text(encoding="utf-8"))
    if not match:
        print("missing ## Version in AceM2L2.toc")
        return 1
    version = match.group(1)
    out = args.out or (root / "dist" / f"AceM2L2-{version}.zip")
    out.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in ROOT_FILES:
            path = root / name
            if not path.is_file():
                print(f"missing required file: {name}")
                return 1
            archive.write(path, f"AceM2L2/{name}")
        for tree in TREES:
            base = root / tree
            if not base.is_dir():
                continue
            for path in sorted(base.rglob("*")):
                if not path.is_file():
                    continue
                relative = path.relative_to(root).as_posix()
                if relative.startswith("Libs/LibStub/tests/"):
                    continue
                archive.write(path, f"AceM2L2/{relative}")

    print(f"built {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
