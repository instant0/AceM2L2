# DS-17.18 — S7 heatmap ownership and top-N result

**Status:** executed 2026-11-18  
**Scope:** canonical heatmap cells/total/lastSeen/top-10; cell XP/time unavailable.  
**Test:** `tests/s7_heatmap_ownership.lua`; full suite passes.

## 1. Ownership

`journey.heatmaps["<mapID>"]` is canonical for:

- map ID and grid size;
- per-cell kill counts;
- total kills and last seen;
- deterministic top-10 cell summaries.

`db.heatmaps` remains a compatibility projection. It still feeds block
construction until S8; S7 does not change block payloads.

## 2. Record shape

```text
journey.heatmaps["<mapID>"] = {
  mapID, gridSize,
  cells = { [cell] = { kills = n } },
  total, lastSeen,
  top10 = { { cell = n, count = n }, ... },
  killsCoverage = "exact",
  cellXpCoverage = "unavailable",
  cellTimeCoverage = "unavailable",
}
```

- Per-cell `xp`, `presenceSeconds`, and `engagedSeconds` are absent. No zeroes or
  invented values are stored.
- `total` is summed from retained cells.
- Top-10 sorts by kills descending, then cell ascending.
- `total` is never incremented from the summary.

## 3. Sync behavior

- `EnsureModelHeatmaps` backfills from `db.heatmaps`.
- `SyncModelHeatmapFromLegacy` rebuilds one map.
- `SyncModelHeatmapsFromLegacy` rebuilds all maps and removes stale model maps.
- `UpdateModelHeatmapKill` updates the affected cell and top-10 on the kill path
  without rebuilding every cell.
- Load, clear, cap eviction, prune, and settings normalization sync the model.
- The 64-map cap and per-cell kill ceiling are preserved.
- `GetModelHeatmap` is v2-only with no implicit legacy fallback.

## 4. Tests

- cell/total/lastSeen parity;
- grid size and coverage flags;
- absent per-cell XP/time;
- top-10 ordering and deterministic ties;
- production kill updates both stores with no double counting;
- bulk sync idempotence;
- deleted maps removed;
- clear empties both stores;
- cap/prune parity at 64 maps;
- v2-only reads after `db.heatmaps` is removed.

Passing output:

```text
S7 heatmap ownership passed
...
All offline checks passed.
```

## 5. Limits

- Cell XP/presence/engaged capture remains V-2 work.
- The 32/16 cold tier and block payload completeness remain S8.
- UI readers still use legacy cells and blocks.
- No legacy retirement.

## 6. Next

**DS-17.19 — S8 block payload v2 completeness.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/Data.lua`
- `KillHistory/Events.lua`
- `tests/s7_heatmap_ownership.lua`
- `tests/s1_model_helpers.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-18-S7-HEATMAP-OWNERSHIP.md`
