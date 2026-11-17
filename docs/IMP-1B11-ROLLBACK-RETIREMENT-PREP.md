# IMP-1B11 — Rollback retirement preparation result

**Status:** prepared 2026-11-16; final removal gated by V-2  
**Test:** `tests/rollback_inventory.lua`; `./tests/run_all.sh`  
**Scope:** inventory and removal plan only. No flag removed yet.

## 1. Remaining flags

Only two runtime rollout flags exist:

| Flag | Role | Files |
|---|---|---|
| `journey.indexViews` | list/Overview/commands/Areas/Levels/heatmap legacy branch | `JourneyIndex.lua` |
| `journey.blockReadFallback` | tooltip/Detail legacy-first branch | `JourneyStorage.lua`, `Tooltip.lua`, `UI/Detail.lua` |

`UseJourneyIndexViews()` call sites:

| File | Calls |
|---|---:|
| `Commands.lua` | 5 |
| `Heatmap.lua` | 2 |
| `JourneyQueries.lua` | 5 |
| `UI/List.lua` | 3 |
| `UI/Detail.lua` | 1 |
| `UI/Overview.lua` | 1 |
| `JourneyIndex.lua` definition | 1 |

The static test locks this inventory and rejects any new
`journey.*Fallback` flag.

## 2. Removal order

1. **Keep one-path snapshots first.**
   - Convert flag-parity tests to fixed expected snapshots.
   - Keep empty/corrupt/missing-block coverage.
2. **Remove `journey.indexViews` branches.**
   - Use the Journey index/rows path unconditionally.
   - Delete the inline legacy scans in:
     - `Commands.PrintKills`, `PrintAreas`, `PrintLevels`, `PrintStats`,
       `PrintDump`;
     - `UI/List` mobs/areas/levels;
     - `UI/Overview` top mobs;
     - `JourneyQueries` area/level summaries and heatmap top cells;
     - `Heatmap` zone-list overlay.
3. **Remove `journey.blockReadFallback`.**
   - Tooltip and Detail call `GetJourneyMob` directly.
   - Keep `GetJourneyMob`’s internal legacy-data fallback until the data
     backfill/retirement decision.
4. **Remove flag initialization/defaults.**
   - `JourneyIndex.UseJourneyIndexViews`;
   - `JourneyStorage` flag default.
5. **Update inventory test.**
   - Change it to assert zero flag references after removal.
6. **Run the full suite.**
   - One authoritative output path;
   - no stale dual-path assertions.

## 3. Tests to convert

These currently exercise rollback/parity and must be converted rather than
deleted:

- `tests/area_level_summaries.lua`
- `tests/areas_levels_parity.lua`
- `tests/commands_index.lua`
- `tests/heatmap_bounded.lua`
- `tests/list_overview_index.lua`
- `tests/tooltip_fallback.lua`

Keep:

- corrupted/missing block tests;
- legacy-data fallback inside `GetJourneyMob`;
- save/guard/reset tests;
- empty-state tests.

## 4. What stays after removal

Legacy **data** remains until a separate backfill decision:

- `db.mobs`, `db.areas`, `db.levels`, `db.instances`, `db.heatmaps`;
- `GetAreaRows`/`GetLevelRows` legacy-canonical counts;
- `GetJourneyMob` legacy fallback for missing blocks;
- migration/normalization paths.

Emergency rollback becomes a normal release/version rollback, not a runtime
branch.

## 5. Gate

Final removal waits for the live-only V-2 residual checks:

- real combat attribution;
- live API values;
- SavedVariables timing/size;
- Midnight secret behavior;
- visual/frame behavior.

## 6. Artifacts

- `tests/rollback_inventory.lua`
- `tests/run_all.sh`
- `docs/tasks/IMP-1B11-ROLLBACK-RETIREMENT.md`
