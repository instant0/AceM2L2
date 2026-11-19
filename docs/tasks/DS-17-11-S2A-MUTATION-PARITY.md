# DS-17.11 — S2A mutation parity and cleanup

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-11-S2A-MUTATION-PARITY-RESULT.md`  
**Depends on:** DS-17.10  
**Blocks:** S2B contexts  
**Source:** `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md`

## Why

`journey.mobs` is written on kills and backfilled from `db.mobs`, but legacy
mutation paths can still change mob identity/counts without updating v2:

- `MergeMobEntries` (promotion and merge branches);
- `RemoveMobEntry` / `DeleteMobEntry` / `DeleteUnknownEntries`;
- mob cap/prune (`Events.lua` `SchedulePrune` and `EnsureMob` capacity trigger);
- load consolidation (`ConsolidateNameOnlyMobs`).

Without this task, v2 can drift from the compatibility projection.

## Implementation rule

Do **not** reimplement merge/dedupe arithmetic for v2.

After a legacy mutation, sync the affected v2 record from the **final legacy
record**:

- add `JourneyModel:SyncModelMobFromLegacy(mobKey)`;
- add `JourneyModel:SyncModelMobsFromLegacy()` for bulk/load sync;
- rebuild the v2 record with the existing migration shape;
- remove the v2 key when the legacy key is removed;
- if a bulk sync runs, it must be idempotent.

This guarantees v2 parity with the final legacy state, including the historical
dedupe branch (`historical=true`) and promotion branch.

## Exact hooks

| Path | Function | Required v2 action |
|---|---|---|
| Merge promotion | `Data.lua:MergeMobEntries` when `to` is absent | Remove `fromKey`, sync `toKey` from final legacy record |
| Merge additive | `Data.lua:MergeMobEntries` normal branch | Remove `fromKey`, sync `toKey` from final legacy record |
| Merge dedupe | `Data.lua:MergeMobEntries(..., true)` | Same; final legacy counts already deduped |
| Delete single | `Data.lua:RemoveMobEntry` | Remove v2 key before/after legacy removal |
| Delete unknown | `Commands.lua:DeleteUnknownEntries` / `DeleteMobEntry` | Covered through `RemoveMobEntry` |
| Prune zero-kill | `Events.lua:SchedulePrune` | Covered through `RemoveMobEntry` |
| Prune cap | `Events.lua:SchedulePrune` | Covered through `RemoveMobEntry` |
| Load consolidation | `Data.lua:ConsolidateNameOnlyMobs` | Sync affected keys via `MergeMobEntries` hooks |
| Bulk/load | after normalization | `SyncModelMobsFromLegacy()` if migration flag is stale |

## Identity rules

- NPC ID wins.
- Name-only records merge only by the existing legacy rule.
- No blind name merge.
- `db.mobs` remains the compatibility projection until S3.
- Do not change contexts, blocks, UI readers, or retire legacy.

## Tests

`tests/s2a_mutation_parity.lua`:

- name-only -> NPC promotion moves the v2 key;
- name-only + NPC additive merge equals final legacy counts;
- historical/dedupe merge uses final legacy max counts, not a second sum;
- delete removes the v2 record;
- unknown deletion removes the v2 record;
- zero-kill prune removes the v2 record;
- cap prune removes the same identities as legacy;
- load consolidation leaves v2 matching legacy;
- bulk sync is idempotent;
- `GetModelMob` v2-only still works;
- no double counting.

## Acceptance

- Every mob mutation path updates v2.
- Legacy and v2 identity/count parity holds after merge/delete/prune.
- Merge arithmetic is not duplicated; v2 is rebuilt from final legacy state.
- No contexts/block/UI/retirement changes.
- Full suite passes.
- S2B can start from a non-drifting mob owner.

## Not required

- contexts array/top-8;
- zone/level/instance migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
