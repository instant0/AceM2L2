#!/usr/bin/env python3
"""Validate AceM2L2 TOC/XML references, metadata, and exact filename case.

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
import xml.etree.ElementTree as ET
from pathlib import Path


TOC_NAME = "AceM2L2.toc"
XML_REF_RE = re.compile(
    r"""(?ix)
    \b(?:file|include)\s*=\s*
    (["'])(?P<path>[^"']+)\1
    """
)
TOC_META_RE = re.compile(r"^##\s*([^:]+):\s*(.*)$")
REQUIRED_META = {
    "Version": None,
    "Interface": ("120105", "120107", "16001"),
    "SavedVariables": ("AceM2L2DB",),
    "SavedVariablesPerCharacter": ("AceM2L2CharDB",),
    "AddonCompartmentFunc": ("AceM2L2_OnCompartmentClick",),
}


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


def read_toc(root: Path, errors: list[str]) -> tuple[list[tuple[str, int]], dict[str, str]]:
    toc = root / TOC_NAME
    if not toc.is_file():
        errors.append(f"missing TOC: {TOC_NAME}")
        return [], {}

    references: list[tuple[str, int]] = []
    metadata: dict[str, str] = {}
    seen: set[str] = set()
    for line_number, raw_line in enumerate(
        toc.read_text(encoding="utf-8").splitlines(), start=1
    ):
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("##"):
            match = TOC_META_RE.match(line)
            if match:
                metadata[match.group(1).strip()] = match.group(2).strip()
            continue
        if line.startswith("#"):
            continue
        if line in seen:
            errors.append(f"{TOC_NAME}:{line_number}: duplicate TOC entry: {line}")
            continue
        seen.add(line)
        references.append((line, line_number))
    return references, metadata


def validate_metadata(metadata: dict[str, str], errors: list[str]) -> None:
    for key, expected in REQUIRED_META.items():
        value = metadata.get(key, "")
        if not value:
            errors.append(f"{TOC_NAME}: missing metadata {key}")
            continue
        if expected:
            parts = [part.strip() for part in value.split(",")]
            for required in expected:
                if required not in parts:
                    errors.append(
                        f"{TOC_NAME}: {key} must contain {required!r}, got {value!r}"
                    )


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

        try:
            ET.fromstring(text)
        except ET.ParseError as error:
            errors.append(f"{xml_path.name}: malformed XML: {error}")

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


def validate_lua_files(
    root: Path,
    resolved: set[Path],
    errors: list[str],
) -> None:
    """Every shipped Lua file must be loaded by the TOC."""
    for lua_file in sorted(root.rglob("*.lua")):
        parts = set(lua_file.relative_to(root).parts)
        if parts & {"Libs", "dev", "tests"}:
            continue
        if lua_file.resolve() not in resolved:
            errors.append(
                f"Lua file is not referenced by {TOC_NAME}: "
                f"{lua_file.relative_to(root)}"
            )


LOAD_ORDER_RULES = (
    ("Core/Defaults.lua", "KillHistory/Client.lua"),
    ("Core/Defaults.lua", "KillHistory/Clients/Forever.lua"),
    ("Core/Defaults.lua", "KillHistory/Clients/Midnight.lua"),
    ("Core/Defaults.lua", "KillHistory/Util.lua"),
    ("KillHistory/Module.lua", "KillHistory/Client.lua"),
    ("KillHistory/Client.lua", "KillHistory/Clients/Forever.lua"),
    ("KillHistory/Client.lua", "KillHistory/Clients/Midnight.lua"),
    ("KillHistory/Util.lua", "KillHistory/Data.lua"),
    ("KillHistory/Util.lua", "KillHistory/Calibration.lua"),
    ("KillHistory/Util.lua", "KillHistory/Tracking.lua"),
    ("KillHistory/Util.lua", "KillHistory/Tooltip.lua"),
    ("KillHistory/Util.lua", "KillHistory/UI/Theme.lua"),
    ("KillHistory/Util.lua", "KillHistory/UI/Window.lua"),
    ("KillHistory/Util.lua", "KillHistory/Commands.lua"),
    ("KillHistory/Util.lua", "KillHistory/Events.lua"),
    ("KillHistory/Formula.lua", "KillHistory/Calibration.lua"),
    ("KillHistory/Formula.lua", "KillHistory/Tracking.lua"),
    ("KillHistory/Formula.lua", "KillHistory/Tooltip.lua"),
    ("KillHistory/UI/Widgets.lua", "KillHistory/UI/Window.lua"),
    ("KillHistory/Util.lua", "KillHistory/World.lua"),
    ("KillHistory/Util.lua", "KillHistory/Heatmap.lua"),
    ("KillHistory/UI/Theme.lua", "KillHistory/UI/Heatmap.lua"),
    ("KillHistory/UI/Widgets.lua", "KillHistory/UI/Heatmap.lua"),
    ("KillHistory/UI/Overview.lua", "KillHistory/UI/Window.lua"),
    ("KillHistory/Heatmap.lua", "KillHistory/UI/Window.lua"),
)


def validate_load_order(
    references: list[tuple[str, int]],
    errors: list[str],
) -> int:
    positions: dict[str, int] = {}
    for index, (reference, _line_number) in enumerate(references):
        positions[reference.replace("\\", "/")] = index

    checked = 0
    for before, after in LOAD_ORDER_RULES:
        if before not in positions or after not in positions:
            continue
        checked += 1
        if positions[before] > positions[after]:
            errors.append(
                f"{TOC_NAME}: load order: {before} must load before {after}"
            )

    module_position = positions.get("KillHistory/Module.lua")
    if module_position is not None:
        for reference, position in positions.items():
            if reference.startswith("KillHistory/") and reference != "KillHistory/Module.lua":
                checked += 1
                if module_position > position:
                    errors.append(
                        f"{TOC_NAME}: load order: KillHistory/Module.lua must load before {reference}"
                    )
    return checked


def validate_bindings(root: Path, resolved: set[Path], errors: list[str]) -> None:
    bindings_xml = root / "Bindings.xml"
    bindings_lua = root / "Bindings.lua"
    if bindings_xml.is_file():
        errors.append("Bindings.xml should not exist; the toggle keybinding was removed")
    if not bindings_lua.is_file():
        errors.append("Bindings.lua is required for the addon-compartment entry point")
        return
    text = bindings_lua.read_text(encoding="utf-8", errors="replace")
    if "function AceM2L2_OnCompartmentClick" not in text:
        errors.append("Bindings.lua missing function AceM2L2_OnCompartmentClick")
    if "AceM2L2_ToggleXPTooltip" in text:
        errors.append("Bindings.lua still defines the removed keybinding function")


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

    references, metadata = read_toc(root, errors)
    validate_metadata(metadata, errors)
    load_order_checked = validate_load_order(references, errors)
    resolved = validate_references(root, references, errors)
    validate_lua_files(root, resolved, errors)
    validate_bindings(root, resolved, errors)

    if "embeds.xml" not in {reference for reference, _ in references}:
        errors.append(f"{TOC_NAME} must load embeds.xml")

    print(f"Addon root: {root}")
    print(f"TOC: {TOC_NAME}")
    print(f"TOC references checked: {len(references)}")
    print(f"Load-order rules checked: {load_order_checked}")
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
