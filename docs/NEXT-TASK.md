# Next task

## IMP-1 — Journey schema and retrieval integration

**Status:** next; ready; CAP-1 complete  
**Task document:** `docs/tasks/IMP-1-JOURNEY-SCHEMA-RETRIEVAL.md`  
**Decision record:** `docs/DS-11-DECISION-RECORD.md`  
**Inputs:** `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`,
`docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`,
`docs/DS-16-SAVE-CHECKPOINT-RESULT.md`,
`docs/DS-14-OVERSIZE-GUARD-RESULT.md`,
`docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`

### Why this is next

- The v2 schema, save/guard, retrieval, and capture fields are defined.
- Production integration must now connect:
  - schema/migration;
  - capture fields;
  - dirty-block save;
  - selected-block lazy decode;
  - tooltip/danger/best-zone/heatmap queries;
  - safe missing/corrupt fallback.

### Work

1. Implement v2 Journey schema/migration.
2. Connect capture fields from CAP-1.
3. Dirty-block/incremental save and oversize guard.
4. Per-block base64/checksum.
5. Selected-block lazy decode + LRU.
6. Tooltip current Journey/metadata/fallback.
7. Danger query by combat context.
8. Best-zone XP/hour query.
9. Heatmap top-N queries.
10. Missing/corrupt fallback.
11. Tests/fixtures; no UI, no merge, no account writes.

### Output

- production integration;
- regression/migration tests;
- retrieval latency/fallback evidence;
- V-2 handoff list.

### Not required

- UI redesign;
- merge/account Knowledge;
- LoadOnDemand companion;
- live client test;
- route recommendation.
