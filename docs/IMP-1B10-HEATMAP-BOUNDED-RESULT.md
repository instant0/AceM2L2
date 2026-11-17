# IMP-1B10 — Heatmap UI bounded query result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/JourneyStorage.lua`,
`KillHistory/JourneyQueries.lua`, `KillHistory/Heatmap.lua`,
`KillHistory/UI/Heatmap.lua`  
**Test:** `tests/heatmap_bounded.lua`; `tests/journey_storage.lua`;
`./tests/run_all.sh`  
**Scope:** per-zone heatmap cells in Journey blocks and selected-zone UI reads.
No global cold scan and no new runtime flag.

## 1. Task premise corrected

The task assumed Journey blocks already contained heatmap cells. They did not:
blocks contained only mob records. This slice adds sparse heatmap cells to the
zone block, then uses the existing lazy block cache for selected-zone reads.

## 2. Block schema

- Storage schema is now **2**.
- Schema 2 block layout:
  - zone key;
  - mob record count and records;
  - cell count and sparse cell records:
    - cell index;
    - kills;
    - XP;
    - presence seconds;
    - engaged seconds.
- Schema 1 blocks still decode, with an empty cell table.
- Old blocks are not force-rebuilt. They upgrade when their zone is dirtied or
  when blocks are first built.
- `blockIndex` now carries:
  - `cellCount`;
  - `heatmapKills`;
  - `lastSeen`.

`RecordHeatmapKill` marks the zone dirty, so heatmap changes participate in the
normal dirty-block flush. There is still no per-kill save.

## 3. Queries

- `GetJourneyHeatmapZones()` — metadata-only zone list from `blockIndex`; **0
  block decodes**.
- `GetJourneyHeatmapCells(mapID)` — selected zone; **1 block decode**, then
  cached.
- `GetHeatmapTopCells()` — uses Journey cells when available, otherwise legacy
  cells.
- `GetHeatmapZones()` — keeps the legacy zone list, but marks zones that have a
  Journey block source. Legacy cells remain as the fallback.

## 4. UI behavior

`UI/Heatmap.lua` now:

- reads the zone list from the existing normalized heatmap list;
- marks Journey-backed zones;
- fetches **only the selected zone’s cells** from the block;
- falls back to legacy cells if the block is missing or has no cells;
- reuses the block cache on repeated refreshes.

Cell values may be numeric or table records; the UI reads `kills` from either
form.

## 5. Tests

`tests/heatmap_bounded.lua` verifies:

- zone metadata does not decode a block;
- selected-zone read decodes once;
- repeated read uses the cache;
- top-cell query uses the block and caches;
- heatmap UI refresh decodes one block;
- missing block falls back to legacy without a decode;
- rollback uses legacy cells and decodes zero blocks.

`tests/journey_storage.lua` now verifies:

- schema 2;
- cell counts and kill totals in `blockIndex`;
- cell encoding/decoding;
- one decode for the selected zone;
- cache reuse.

Passing output:

```text
Journey block storage passed
Heatmap bounded query passed
```

`./tests/run_all.sh` passes.

## 6. Rollback

No new flag was added. `journey.indexViews = false` restores legacy heatmap
cells and zone handling.

The selected-zone query is bounded even with the flag enabled:

- no global cold scan;
- one selected block decode per refresh at most;
- cache hit decodes zero additional blocks.

## 7. Limitations

- Old schema 1 blocks remain without cells until their zone is rewritten.
- The heatmap zone list still merges legacy zone metadata so older blocks do not
  disappear.
- No full block migration/rebuild is forced at login.
- The heatmap UI still uses legacy cells as its fallback.
- No account Knowledge/merge.

## 8. Next

**IMP-1B12 — Remaining area/level summary reads.**

- move Overview, footer, minimap, Detail, and `PrintStats` area/level reads to
  `GetAreaRows`/`GetLevelRows`;
- then run V-2;
- then remove rollback flags in IMP-1B11.

## Artifacts

- `KillHistory/JourneyStorage.lua`
- `KillHistory/JourneyQueries.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/UI/Heatmap.lua`
- `tests/heatmap_bounded.lua`
- `tests/journey_storage.lua`
- `tests/run_all.sh`
- `docs/tasks/IMP-1B10-HEATMAP-UI-BOUNDED-QUERY.md`
- `docs/tasks/IMP-1B11-ROLLBACK-RETIREMENT.md`
