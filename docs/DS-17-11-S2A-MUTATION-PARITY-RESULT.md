# DS-17.11 — S2A mutation parity result

**Status:** executed 2026-11-18  
**Scope:** v2 mob synchronization on legacy merge/delete/prune/load consolidation.  
**Test:** `tests/s2a_mutation_parity.lua`; full suite passes.

## 1. Implementation

Added to `JourneyModel`:

- `SyncModelMobFromLegacy(mobKey)` — rebuild one v2 mob from the final legacy
  record, or remove it when legacy is absent.
- `SyncModelMobsFromLegacy()` — bulk rebuild from the final legacy set.

This avoids duplicating merge/dedupe arithmetic. v2 always follows the final
legacy state.

Hooks:

| Path | Action |
|---|---|
| `MergeMobEntries` promotion | Sync `fromKey` (remove) and `toKey` |
| `MergeMobEntries` additive | Same |
| `MergeMobEntries` historical dedupe | Same; final legacy counts are authoritative |
| `RemoveMobEntry` | Remove v2 key |
| `DeleteMobEntry` / unknown cleanup | Covered through `RemoveMobEntry` |
| `Events.lua` prune/cap | Covered through `RemoveMobEntry` |
| `EnsureDB` after `ConsolidateNameOnlyMobs` | Bulk sync |

## 2. Tests

`tests/s2a_mutation_parity.lua` verifies:

- additive merge equals final legacy counts;
- historical/dedupe merge uses max counts, not a second sum;
- promotion moves the v2 key;
- delete removes v2;
- zero-kill/cap prune removes v2 and keeps survivors;
- load consolidation matches final legacy;
- bulk sync is idempotent;
- v2-only reads still work after `db.mobs` is removed.

Passing output:

```text
S2A mutation parity passed
...
All offline checks passed.
```

## 3. Limits

- Contexts remain keyed maps; array/top-8 is S2B.
- Block payload and UI readers remain legacy.
- No legacy retirement.
- No live client test.

## 4. Next

**DS-17.12 — S2B context shape migration.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/Data.lua`
- `tests/s2a_mutation_parity.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-11-S2A-MUTATION-PARITY.md`
