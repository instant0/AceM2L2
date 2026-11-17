# IMP-1B6 — Global Journey mob index result

**Status:** index core executed 2026-11-16  
**Module:** `KillHistory/JourneyIndex.lua`  
**Test:** `tests/journey_index.lua`; `./tests/run_all.sh`  
**Scope:** compact in-memory global mob index. List/overview UI switch is the
next slice.

## 1. Implemented

- `EnsureJourneyMobIndex()`:
  - lazily builds rows from the current authoritative `db.mobs`;
  - caches rows and a key lookup;
  - invalidated on kill, quest, and `EnsureDB`.
- `GetJourneyMobRows()`
- `GetJourneyMobRow(mobKey)`
- `GetJourneyMobCount()`
- `GetJourneyTopMobs(limit)`
- `GetJourneyMobsForFilter(filter, searchText)`

Index row fields:

```text
key, mob reference, npcID, name, classification
kills, sessionKills, killsAtLevel, xp, lastSeen
killsByMap, killsByInstance
```

The index is not persisted; it is derived from current data.

## 2. Test result

`tests/journey_index.lua` verifies:

- count/rows;
- row lookup fields;
- top mobs ordering;
- elite filter;
- session filter;
- name search;
- invalidation and rebuild after a kill change.

Passing output:

```text
Journey mob index passed
```

`./tests/run_all.sh` passes.

## 3. What this enables

- O(index) list/overview queries instead of re-scanning `db.mobs` on every
  refresh.
- One rebuild per data change, not per UI refresh.
- A path to switch:
  - Mobs list;
  - Overview top mobs;
  - future filtered lists.

## 4. Limitations

- Index build is a one-time scan of current `db.mobs` on first use after
  invalidation.
- It references legacy mob tables; it is not a persisted Journey mob store.
- Mobs/Areas/Levels list, Overview, commands, and heatmap UI still read legacy
  data directly.
- No block-only migration yet.
- No account Knowledge/merge.

## 5. Next

**IMP-1B7 — Mobs list/Overview switch to Journey index.**

- switch Mobs list and Overview top mobs behind a flag;
- compare output/rows against legacy;
- keep legacy rollback;
- ensure one index rebuild per change, not per refresh;
- preserve search/filter/sort behavior;
- no Areas/Levels/commands switch yet.

## Artifacts

- `KillHistory/JourneyIndex.lua`
- `KillHistory/Journey.lua`
- `KillHistory/Data.lua`
- `AceM2L2.toc`
- `tests/journey_index.lua`
- `tests/run_all.sh`
