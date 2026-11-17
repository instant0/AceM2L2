# IMP-1B7 — Mobs list/Overview switch to Journey index

**Status:** executed 2026-11-16  
**Result:** `docs/IMP-1B7-MOBS-LIST-OVERVIEW-RESULT.md`  
**Harness:** `tests/list_overview_index.lua`  
**Depends on:** IMP-1B6, IMP-1B5, DS-15  
**Blocks:** IMP-1B8, V-2, UI

## Why

The Journey mob index exists but list/overview still scan legacy `db.mobs` on
every refresh. Switch the Mobs list and Overview top mobs first.

## Scope

- Switch Mobs list to `GetJourneyMobRows`/filters behind a flag.
- Switch Overview top mobs to `GetJourneyTopMobs`.
- Keep search/filter/sort behavior identical.
- Keep legacy fallback/rollback.
- Ensure one index rebuild after a data change, not per refresh.
- Do **not** switch Areas/Levels, commands, or heatmap UI yet.
- No account Knowledge/merge or UI redesign.

## Tests

- Row counts/kills/names match legacy.
- Search/filter/sort match legacy.
- One index build for repeated refreshes.
- Index invalidation after a kill rebuilds once.
- Rollback flag restores legacy reads.
- Existing smoke/query/storage/index tests green.

## Acceptance

- Mobs list and Overview parity.
- No per-refresh full scan.
- Rollback works.
- Areas/Levels/commands/heatmap remain legacy.
- No account Knowledge/merge or UI redesign.
