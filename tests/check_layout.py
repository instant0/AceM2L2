#!/usr/bin/env python3
"""Validate AceM2L2 TOC/XML references and exact filename case.

This catches the class of bugs that only appear on case-sensitive filesystems:
a file exists as `Readme.txt` while a reference says `README.txt`, or a TOC
entry points at a file that was renamed.

Usage:
    python3 tests/check_layout.py
    python3 tests/check_layout.py --strict-root
    python3 tests/check_layout.py --root /path/to/AceM2L2

Exit codes:
    0  all references are valid (warnings may still be printed)
    1  one or more hard errors, or --strict-root was requested and the checkout
       folder name does not match the TOC name
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


TOC_NAME = "AceM2L2.toc"
XML_REF_RE = re.compile(
    r"""(?ix)
    \b(?:file|include)\s*=\s*
    (["'])(?P<path>[^"']+)\1
    """
)


def exact_exists(root: Path, reference: str) -> tuple[bool, str]:
    """Resolve a WoW-style path while checking every segment's exact case."""
    normalized = reference.replace("\\", "/").strip()
    if not normalized:
        return False, "empty path"
    if normalized.startswith("/"):
        return False, "absolute paths are not allowed"

    parts = [part for part in normalized.split("/") if part not in ("", ".")]
    if not parts:
        return False, "empty path"
    if any(part == ".." for part in parts):
        return False, "parent-directory references are not allowed"

    current = root
    for part in parts:
        try:
            names = {entry.name for entry in current.iterdir()}
        except OSError as error:
            return False, f"cannot list {current}: {error}"
        if part not in names:
            return False, f"missing or case-mismatched segment: {part}"
        current = current / part

    return True, ""


def read_toc(root: Path, errors: list[str]) -> list[tuple[str, int]]:
    toc = root / TOC_NAME
    if not toc.is_file():
        errors.append(f"missing TOC: {TOC_NAME}")
        return []

    references: list[tuple[str, int]] = []
    for line_number, raw_line in enumerate(
        toc.read_text(encoding="utf-8").splitlines(), start=1
    ):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        references.append((line, line_number))
    return references


def validate_references(
    root: Path,
    references: list[tuple[str, int]],
    errors: list[str],
) -> set[Path]:
    resolved: set[Path] = set()
    xml_queue: list[Path] = []

    for reference, line_number in references:
        ok, reason = exact_exists(root, reference)
        if not ok:
            errors.append(f"{TOC_NAME}:{line_number}: {reference}: {reason}")
            continue
        path = (root / reference.replace("\\", "/")).resolve()
        resolved.add(path)
        if path.suffix.lower() == ".xml":
            xml_queue.append(path)

    visited_xml: set[Path] = set()
    while xml_queue:
        xml_path = xml_queue.pop(0)
        if xml_path in visited_xml:
            continue
        visited_xml.add(xml_path)

        try:
            text = xml_path.read_text(encoding="utf-8")
        except OSError as error:
            errors.append(f"cannot read {xml_path}: {error}")
            continue

        for match in XML_REF_RE.finditer(text):
            reference = match.group("path")
            ok, reason = exact_exists(xml_path.parent, reference)
            if not ok:
                errors.append(f"{xml_path.name}: {reference}: {reason}")
                continue
            path = (xml_path.parent / reference.replace("\\", "/")).resolve()
            resolved.add(path)
            if path.suffix.lower() == ".xml":
                xml_queue.append(path)

    return resolved


def validate_root_lua_files(
    root: Path,
    resolved: set[Path],
    errors: list[str],
) -> None:
    """Every shipped root Lua file must be loaded by the TOC."""
    for lua_file in sorted(root.glob("*.lua")):
        if lua_file.resolve() not in resolved:
            errors.append(
                f"root Lua file is not referenced by {TOC_NAME}: {lua_file.name}"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="addon root containing AceM2L2.toc",
    )
    parser.add_argument(
        "--strict-root",
        action="store_true",
        help="fail if the checkout folder name does not match the TOC basename",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    errors: list[str] = []
    warnings: list[str] = []

    toc_path = root / TOC_NAME
    expected_root_name = toc_path.stem
    if root.name != expected_root_name:
        message = (
            f"checkout folder is {root.name!r}, but TOC basename is "
            f"{expected_root_name!r}; release archives must use {expected_root_name}/"
        )
        if args.strict_root:
            errors.append(message)
        else:
            warnings.append(message)

    references = read_toc(root, errors)
    resolved = validate_references(root, references, errors)
    validate_root_lua_files(root, resolved, errors)

    bindings_xml = root / "Bindings.xml"
    if bindings_xml.is_file() and bindings_xml.resolve() not in resolved:
        errors.append("Bindings.xml exists but is not loaded by the TOC")

    print(f"Addon root: {root}")
    print(f"TOC: {TOC_NAME}")
    print(f"TOC references checked: {len(references)}")
    print(f"Resolved files/XML paths: {len(resolved)}")

    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}")

    if errors:
        print("Layout check failed.")
        return 1

    print("Layout check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
