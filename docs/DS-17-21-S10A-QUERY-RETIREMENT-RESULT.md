# DS-17.21 — S10A query read retirement result

**Status:** executed 2026-11-18  
**Scope:** Journey query layer reads v2 roots; writes and UI fallbacks unchanged.  
**Test:** `tests/s10_query_retirement.lua`; full suite passes.

## 1. Why S10 was split

Full legacy retirement is live-gated by V-2. S10A removes legacy reads from the
query layer without pretending the write/fallback removal or live validation has
happened.

- S10A: query reads.
- S10B: UI list/detail reads.
- S10C: live-gated dual-write and rollback removal.

## 2. Query ownership

`JourneyQueries.lua` now reads only v2 roots for:

- zone and level stats;
- area/instance rows;
- level rows;
- top-area and level summaries;
- area/level kill counts;
- heatmap top cells;
- mob journey summaries;
- quest anchors and quest summaries.

`UseJourneyIndexViews` no longer selects a legacy path for these queries.
`GetHeatmapTopCells` reads `journey.heatmaps` through the model and no longer
decodes blocks or reads `db.heatmaps`.

Quest names still resolve through the quest ledger because the v2 quest record
does not duplicate quest text. This ledger is retired only when S10C provides a
replacement name source.

## 3. Status counts

`PrintStats` uses v2 mob rows, v2 area/instance rows, and v2 level rows. It no
longer counts `db.mobs`, `db.areas`, `db.instances`, or `db.levels`.

## 4. Tests

- zone/level stats with legacy aggregates absent;
- area/instance and level rows;
- top-area and level summaries;
- area/level kill counts;
- heatmap top cells from the v2 model;
- mob summary from `journey.mobs`;
- quest anchors with ledger names and fallback names;
- no `UseJourneyIndexViews` legacy path;
- updated parity/status/rollback tests.

Passing output:

```text
S10 query retirement passed
...
All offline checks passed.
```

## 5. Remaining legacy reads

S10B still owns direct UI reads, including:

- quest list rows;
- respawn history rows;
- some Detail context and instance fields;
- legacy fallbacks when `journey.indexViews` is false.

## 6. Remaining retirement

S10C still owns:

- stopping dual writes;
- removing normalizers and sync calls;
- removing block/index fallbacks;
- removing IMP-1B11 rollback insurance;
- live V-2 evidence.

## 7. Next

**DS-17.22 — S10B UI read retirement.**

## Artifacts

- `KillHistory/JourneyQueries.lua`
- `KillHistory/Commands.lua`
- `tests/s10_query_retirement.lua`
- `tests/journey_queries.lua`
- `tests/areas_levels_parity.lua`
- `tests/area_level_summaries.lua`
- `tests/heatmap_bounded.lua`
- `tests/historical_zone.lua`
- `tests/journey_storage.lua`
- `tests/rollback_inventory.lua`
- `tests/run_all.sh`
