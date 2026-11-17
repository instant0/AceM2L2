# IMP-1B9 — Areas/Levels parity and switch

**Status:** executed 2026-11-16  
**Result:** `docs/IMP-1B9-AREAS-LEVELS-RESULT.md`  
**Harness:** `tests/areas_levels_parity.lua`  
**Depends on:** IMP-1B8, IMP-1B, IMP-1B2, CAP-1  
**Blocks:** IMP-1B10, IMP-1B11, V-2

## Why

The Areas and Levels tabs still read `db.areas` and `db.levels`, while Journey
has `journey.zones` and `journey.levels`. Switching without parity would hide
legacy history recorded before Journey capture or lost during schema changes.

## Scope

- Measure legacy vs Journey totals for areas, instances, and levels.
- Define one of:
  - dual-read totals (legacy + Journey) with overlap protection;
  - a one-time legacy-to-Journey backfill;
  - a documented partial-data switch.
- Preserve instance rows and names.
- Switch Areas and Levels behind `journey.indexViews` or a dedicated flag.
- Keep legacy fallback/rollback.
- Add parity tests for counts, XP split, and empty states.
- No heatmap UI switch.
- No account Knowledge/merge or UI redesign.

## Tests

- Area total/kill parity.
- Instance rows and names.
- Level total/kill/XP parity.
- Empty and partial data.
- Rollback flag.
- One-time backfill idempotence, if used.

## Acceptance

- No hidden loss of pre-Journey history.
- Areas/Levels output matches the chosen parity model.
- Rollback works.
- Heatmap UI remains on its current data.
- No account Knowledge/merge or UI redesign.

## Not required

- live client test;
- heatmap UI;
- account Knowledge/merge;
- UI redesign.
