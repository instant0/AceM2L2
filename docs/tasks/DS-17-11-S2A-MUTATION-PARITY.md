# DS-17.11 — S2A mutation parity and cleanup

**Status:** next; implementation.  
**Depends on:** DS-17.10  
**Blocks:** S2B contexts  
**Source:** `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md`

## Why

`journey.mobs` is now written on kills and backfilled from `db.mobs`, but legacy
mutation paths can still change mob identity/counts without updating v2:

- `MergeMobEntries` when a name-only record resolves to an NPC key;
- `DeleteMobEntry` / unknown cleanup;
- prune/trim caps;
- load normalization that merges/removes mobs.

Without this task, v2 can drift from the compatibility projection.

## Scope

- Add a v2 synchronization helper for mob mutations:
  - merge two v2 records;
  - delete a v2 record;
  - prune v2 with the same cap/order as legacy.
- Hook the existing legacy mutation points:
  - `KillHistory/Data.lua` `MergeMobEntries`;
  - `DeleteMobEntry` / unknown cleanup;
  - mob cap/prune paths.
- Preserve identity rules:
  - NPC ID wins;
  - name-only merges only by the existing legacy rule;
  - no blind name merge.
- Keep `db.mobs` as the compatibility projection until S3.
- Do not change contexts, blocks, UI readers, or retire legacy.

## Tests

`tests/s2a_mutation_parity.lua`:

- name-only -> NPC merge updates v2 totals and leaves no duplicate;
- delete removes the v2 record;
- prune/cap trims the same identities as legacy;
- v2 totals match legacy after each mutation;
- no double counting;
- `GetModelMob` v2-only still works;
- idempotent re-run.

## Acceptance

- Every mob mutation path updates v2.
- Legacy and v2 identity/count parity holds after merge/delete/prune.
- No contexts/block/UI/retirement changes.
- Full suite passes.
- S2B can start from a non-drifting mob owner.

## Not required

- contexts array/top-8;
- zone/level/instance migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
