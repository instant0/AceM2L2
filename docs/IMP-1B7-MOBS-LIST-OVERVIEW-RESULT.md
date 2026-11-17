# IMP-1B7 — Mobs list/Overview index switch result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/JourneyIndex.lua`,
`KillHistory/UI/List.lua`, `KillHistory/UI/Overview.lua`,
`KillHistory/Data.lua`, `KillHistory/Tracking.lua`, `KillHistory/Events.lua`  
**Test:** `tests/list_overview_index.lua`; `./tests/run_all.sh`  
**Scope:** index-backed Mobs list and Overview top mobs with legacy rollback.
No Areas/Levels/commands/heatmap switch, no migration, no UI redesign.

## 1. Rollout flag

`char.journey.indexViews` controls the switch:

| Value | Behavior |
|---|---|
| missing / `true` | Mobs list and Overview use the Journey mob index |
| `false` | Both views use the original legacy scans |

The index itself is derived from the current authoritative mob data. It is not
saved and does not replace legacy storage.

## 2. Mobs list

The mob branch of `BuildList()` now:

- asks `GetJourneyMobsForFilter(filter, search)` for matching rows;
- renders the same row fields as before:
  - key, name, kills;
  - optional average base XP;
  - last-seen, classification, bar;
- applies the same name/last-seen/kills sorting.

The legacy scan remains intact behind the rollback flag. Search, filter, sort,
row bars, selection, and Detail behavior are unchanged.

## 3. Overview

The “Most killed” panel now uses `GetJourneyTopMobs(8)` when index views are
enabled. Legacy “Most killed” scanning remains as the rollback path.

The index top list sorts by kills and then name for a deterministic tie-break.
The rest of the Overview panel still uses the existing totals, session, area,
level, quest, XP, and economy reads.

## 4. Rebuild budget

- The index is built lazily after invalidation.
- Repeated list refreshes and Overview refreshes reuse the cached rows.
- A data change invalidates the cache; the next view rebuilds once.
- `journeyMobIndexBuilds` is an in-memory counter used by tests and diagnostics.

Test evidence:

| Case | Index builds |
|---|---:|
| First list refresh after invalidation | **1** |
| Repeated list + Overview refresh | **0 additional** |
| Mutation + next list refresh | **1 additional** |
| Rollback flag | **0** |

## 5. Invalidation

`InvalidateMobIndex()` now also invalidates the Journey mob index, so existing
mutation paths such as reset, merge, removal, and database normalization are
covered centrally. Explicit invalidation was added for:

- kill/quest Journey updates;
- late-arriving kill XP (`lastSeen` changes);
- prune/normalization.

## 6. Test result

`tests/list_overview_index.lua` verifies:

- parity with legacy for:
  - kills/name/last-seen sorting;
  - level/session/elite filters;
  - name search;
- Overview top-mob parity;
- one build for repeated refreshes;
- one rebuild after a mutation;
- rollback flag builds zero indexes.

Passing output:

```text
Mobs list/Overview index switch passed
```

`./tests/run_all.sh` passes.

## 7. Limitations

- The index still builds from legacy `db.mobs`; it is not a persisted Journey
  store.
- Areas, Levels, commands, and heatmap UI still read legacy data.
- The index excludes zero-kill entries, which matches the list/Overview paths
  but not every command/statistics count.
- No block-only migration or duplication removal yet.
- No account Knowledge/merge.

## 8. Next

**IMP-1B8 — Remaining legacy read audit and safe command switch.**

- audit the remaining `db.mobs`/`db.areas`/`db.levels`/`db.heatmaps` reads;
- switch safe command/list reads to the Journey index;
- keep Areas/Levels on legacy until Journey/legacy parity or backfill is proven;
- keep heatmap UI on legacy until a bounded block-cell query exists;
- preserve rollback and parity tests;
- no account Knowledge/merge or UI redesign.

## Artifacts

- `KillHistory/JourneyIndex.lua`
- `KillHistory/UI/List.lua`
- `KillHistory/UI/Overview.lua`
- `KillHistory/Data.lua`
- `KillHistory/Tracking.lua`
- `KillHistory/Events.lua`
- `tests/list_overview_index.lua`
- `tests/run_all.sh`
- `docs/tasks/IMP-1B7-MOBS-LIST-OVERVIEW-SWITCH.md`
