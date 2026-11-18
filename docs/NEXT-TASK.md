# Next task

## DS-17.11 — S2A mutation parity and cleanup

**Status:** next; implementation  
**Task document:** `docs/tasks/DS-17-11-S2A-MUTATION-PARITY.md`  
**Depends on:** DS-17.10  
**Blocks:** S2B contexts

### Why this is next

- DS-17.10 writes and reads `journey.mobs` canonical for kills and migration.
- Legacy merge/delete/prune paths can still change mob data without syncing v2.
- That drift must be closed before contexts or further owner migration.

### Work

1. Add v2 mob merge/delete/prune helpers.
2. Hook `MergeMobEntries`, delete/unknown cleanup, and cap/prune paths.
3. Preserve NPC-ID-first identity and the existing name-only rule.
4. Keep `db.mobs` as a compatibility projection until S3.
5. Add mutation parity tests.

### Output

- non-drifting v2 mob owner;
- `tests/s2a_mutation_parity.lua`;
- result document.

### Not required

- S2B contexts;
- zone/level/instance migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
