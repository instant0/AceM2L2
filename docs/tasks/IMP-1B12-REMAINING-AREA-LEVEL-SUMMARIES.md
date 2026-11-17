# IMP-1B12 — Remaining area/level summary reads

**Status:** executed 2026-11-16  
**Result:** `docs/IMP-1B12-AREA-LEVEL-SUMMARIES-RESULT.md`  
**Harness:** `tests/area_level_summaries.lua`  
**Depends on:** IMP-1B9, IMP-1B10  
**Blocks:** V-2, IMP-1B11

## Why

The Areas and Levels tabs and their commands now use overlap-safe shared rows,
but several summary surfaces still read `db.areas`/`db.levels` directly:

- Overview cards and top-area/level text;
- footer top area and level range;
- minimap top area;
- area/level Detail;
- `PrintStats` area/level counts and top area.

These are the last area/level view reads before rollback retirement.

## Scope

- Move remaining area/level summary reads to `GetAreaRows()`/`GetLevelRows()`.
- Preserve labels, counts, percentages, and empty states.
- Keep legacy fallback through `journey.indexViews`.
- Add parity tests for Overview, footer, minimap, Detail, and `PrintStats`.
- Do not add another runtime flag.
- Do not change heatmap behavior.
- No account Knowledge/merge or UI redesign.

## Tests

- Overview top-area and level-range parity.
- Footer parity.
- Minimap top-area parity.
- Area/level Detail parity.
- `PrintStats` count/top-area parity.
- Empty state and rollback parity.
- Existing tests stay green.

## Acceptance

- Remaining area/level view reads use the shared rows.
- Output matches the legacy path.
- Rollback works.
- No heatmap or account merge changes.
- V-2 and IMP-1B11 are unblocked.

## Not required

- live client test;
- legacy data deletion;
- account Knowledge/merge;
- UI redesign.
