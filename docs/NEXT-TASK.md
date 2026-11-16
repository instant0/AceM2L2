# Next task

## IMP-1B5 — Tooltip/UI retirement and rollback

**Status:** next; ready; IMP-1B4 save/guard complete  
**Task document:** `docs/tasks/IMP-1B5-TOOLTIP-UI-RETIREMENT.md`  
**Decision record:** `docs/DS-11-DECISION-RECORD.md`  
**Inputs:** `docs/IMP-1B4-SAVE-GUARD-RESULT.md`,
`docs/IMP-1B3-BLOCK-RETRIEVAL-RESULT.md`,
`docs/IMP-1B2-JOURNEY-BLOCK-STORAGE-RESULT.md`,
`docs/IMP-1B-JOURNEY-QUERY-RESULT.md`,
`docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`

### Why this is next

- Block storage/retrieval/backup/save-blocking work.
- Tooltip/UI still read legacy data and duplicate blocks.
- A controlled switchover and rollback is required.

### Work

1. Switch safe tooltip/UI reads to Journey/block queries.
2. Keep legacy fallback during migration.
3. Define retirement/rollback order.
4. Remove duplication only after tests/backup.
5. Preserve smoke/query/storage/save-guard tests.
6. No account Knowledge/merge/UI redesign.

### Output

- tooltip/UI block-backed reads;
- rollback/retirement evidence;
- tests;
- V-2 handoff.

### Not required

- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- live client test;
- route recommendation.
