# IMP-1B12 — Remaining area/level summary reads result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/JourneyQueries.lua`,
`KillHistory/UI/Overview.lua`, `KillHistory/UI/Window.lua`,
`KillHistory/UI/Minimap.lua`, `KillHistory/UI/Detail.lua`,
`KillHistory/Commands.lua`  
**Test:** `tests/area_level_summaries.lua`; `./tests/run_all.sh`  
**Scope:** remaining area/level view surfaces on shared rows. No new flag, no
data deletion, no heatmap change.

## 1. Shared summary APIs

Added:

- `GetTopAreaSummary()` — world-area top row, honor rollback flag;
- `GetLevelSummary()` — min/max/top level and top kills, honor rollback flag;
- `GetAreaKillCount(areaKey)` — area Detail count;
- `GetLevelKillCount(levelKey)` — level Detail count.

The legacy branches live inside these helpers, so every UI caller uses one
surface and the rollback switch still works.

## 2. Switched surfaces

- Overview:
  - top-area card;
  - level range / most-kills lines.
- Footer:
  - top area;
  - level range.
- Minimap tooltip:
  - top area.
- Detail:
  - area kill count;
  - level kill count;
  - area/level/instance top-mob field scans use the Journey all-rows index.
- `PrintStats`:
  - mob count;
  - area/instance counts;
  - level count;
  - top area.

## 3. Remaining legacy area/level reads

After this slice, remaining `db.areas`/`db.levels` reads are intentional:

- rollback branches in list/commands/queries;
- capture and normalization in `Tracking.lua`/`Data.lua`;
- subtraction/migration helpers.

There are no remaining direct area/level **view** reads outside the shared
helpers.

## 4. Tests

`tests/area_level_summaries.lua` verifies parity for:

- Overview top area and level summary;
- footer;
- minimap tooltip;
- area Detail;
- level Detail;
- `PrintStats`;
- empty states.

Each is compared with `journey.indexViews = false` and `true`.

Passing output:

```text
Area/Level summaries passed
```

`./tests/run_all.sh` passes.

## 5. Rollback policy

No new flag was added. The two existing flags remain:

- `journey.indexViews`;
- `journey.blockReadFallback`.

All offline view switches are now complete. The next gate is live verification,
then IMP-1B11 removes the runtime flags and duplicate legacy read branches.

## 6. Next

**V-2 — live verification.**

Check:

- killer attribution;
- health/buffs/group/rested capture;
- event-driven presence/engaged time;
- XP events and unattributed group XP;
- list/Overview/commands/Areas/Levels/heatmap behavior;
- block save size/timing;
- oversize guard and reset.

Then **IMP-1B11 — rollback retirement.**

## Artifacts

- `KillHistory/JourneyQueries.lua`
- `KillHistory/UI/Overview.lua`
- `KillHistory/UI/Window.lua`
- `KillHistory/UI/Minimap.lua`
- `KillHistory/UI/Detail.lua`
- `KillHistory/Commands.lua`
- `tests/area_level_summaries.lua`
- `tests/run_all.sh`
- `docs/tasks/IMP-1B12-REMAINING-AREA-LEVEL-SUMMARIES.md`
- `docs/tasks/IMP-1B11-ROLLBACK-RETIREMENT.md`
