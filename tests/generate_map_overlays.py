#!/usr/bin/env python3
"""Generate KillHistory/MapOverlayData.lua from official client DB2 exports.

The full fog-clear overlay set is not exposed by a runtime "get all overlays"
API. It lives in the client's WorldMapOverlay / WorldMapOverlayTile tables.
This script downloads those tables from wago.tools and emits our own Lua data;
it does not copy Mapster/Leatrix tables.

Usage:
  python3 tests/generate_map_overlays.py
  python3 tests/generate_map_overlays.py --source-dir /tmp/opencode
"""

from __future__ import annotations

import argparse
import collections
import csv
import io
import urllib.request
from pathlib import Path

BUILDS = {
    1: ("Midnight 12.1.5", "12.1.5.69848"),   # WOW_PROJECT_MAINLINE
    18: ("Forever 1.60.1", "1.60.1.69913"),   # WOW_PROJECT_CAMELOT
}
TABLES = ("WorldMapOverlay", "WorldMapOverlayTile")
OUT = Path(__file__).resolve().parent.parent / "KillHistory" / "MapOverlayData.lua"


def download(table: str, build: str) -> str:
    url = f"https://wago.tools/db2/{table}/csv?build={build}"
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read().decode("utf-8")


def load_table(table: str, build: str, source_dir: Path | None) -> list[dict[str, str]]:
    if source_dir:
        exact = source_dir / f"{table}-{build}.csv"
        short = source_dir / f"{table}-{build.split('.')[-1]}.csv"
        path = exact if exact.exists() else short
        if path.exists():
            return list(csv.DictReader(path.open("r", encoding="utf-8", newline="")))
    return list(csv.DictReader(io.StringIO(download(table, build))))


def number(value: str | None) -> int:
    try:
        return int(value or 0)
    except ValueError:
        return 0


def build_project(project_id: int, build: str, source_dir: Path | None) -> dict[int, list[tuple]]:
    overlays = load_table("WorldMapOverlay", build, source_dir)
    tiles = load_table("WorldMapOverlayTile", build, source_dir)

    by_overlay: dict[str, list[dict[str, str]]] = collections.defaultdict(list)
    for row in tiles:
        by_overlay[row["WorldMapOverlayID"]].append(row)
    for rows in by_overlay.values():
        rows.sort(key=lambda row: (
            number(row["RowIndex"]),
            number(row["ColIndex"]),
            number(row["LayerIndex"]),
        ))

    result: dict[int, list[tuple]] = collections.defaultdict(list)
    for row in overlays:
        overlay_id = row["ID"]
        art_id = number(row["UiMapArtID"])
        width = number(row["TextureWidth"])
        height = number(row["TextureHeight"])
        offset_x = number(row["OffsetX"])
        offset_y = number(row["OffsetY"])
        if art_id <= 0 or width <= 0 or height <= 0:
            continue
        file_ids = [number(tile["FileDataID"]) for tile in by_overlay.get(overlay_id, [])]
        file_ids = [file_id for file_id in file_ids if file_id > 0]
        if not file_ids:
            continue
        result[art_id].append((
            width,
            height,
            offset_x,
            offset_y,
            ",".join(str(file_id) for file_id in file_ids),
        ))

    for entries in result.values():
        entries.sort(key=lambda entry: entry[:4])
    return dict(result)


def emit(projects: dict[int, tuple[str, dict[int, list[tuple]]]]) -> str:
    lines = [
        "--[[---------------------------------------------------------------------------------",
        "  KillHistory/MapOverlayData.lua",
        "  GENERATED FILE - do not edit by hand.",
        "  Source: official WorldMapOverlay / WorldMapOverlayTile client DB2 tables.",
        "  Regenerate with: python3 tests/generate_map_overlays.py",
        "------------------------------------------------------------------------------------]]",
        "",
        "local AceM2L2 = AceM2L2",
        "local XPTooltip = AceM2L2.KillHistory",
        "",
        "-- [projectID][uiMapArtID] = { {width, height, offsetX, offsetY, \"fileDataID,...\"}, ... }",
        "XPTooltip.MapOverlayData = {",
    ]
    for project_id in sorted(projects):
        label, data = projects[project_id]
        lines.append(f"  [{project_id}] = {{ -- {label}")
        for art_id in sorted(data):
            lines.append(f"    [{art_id}] = {{")
            for width, height, offset_x, offset_y, files in data[art_id]:
                lines.append(
                    f'      {{{width},{height},{offset_x},{offset_y},"{files}"}},'
                )
            lines.append("    },")
        lines.append("  },")
    lines.extend([
        "}",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-dir",
        type=Path,
        help="Optional directory containing WorldMapOverlay-<build>.csv and "
             "WorldMapOverlayTile-<build>.csv files.",
    )
    args = parser.parse_args()

    projects: dict[int, tuple[str, dict[int, list[tuple]]]] = {}
    for project_id, (label, build) in BUILDS.items():
        data = build_project(project_id, build, args.source_dir)
        projects[project_id] = (f"{label}, build {build}", data)
        overlays = sum(len(entries) for entries in data.values())
        tiles = sum(
            len(files.split(","))
            for entries in data.values()
            for *_, files in entries
        )
        print(f"{label}: {len(data)} art IDs, {overlays} overlays, {tiles} tiles")

    OUT.write_text(emit(projects), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
