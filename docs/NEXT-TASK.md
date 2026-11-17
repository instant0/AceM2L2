# Next task

## SC-5 — Migration, pruning, and cap tests

**Status:** next; non-live  
**Task document:** `docs/tasks/SC-5-MIGRATION-PRUNING-TESTS.md`  
**Related:** `docs/SC-4-CONTEXT-CAP-RESULT.md`

### Why this is next

- Adaptive mob/quest limits, respawn 4,000, heatmap 64, and context 12 are now
  selected.
- The remaining work is making migration/pruning/downgrade behavior explicit and
  tested.
- This closes the limit work before V-2 and rollback retirement.

### Work

1. Add boundary tests for every changed cap.
2. Verify deterministic recency pruning.
3. Verify normalization/idempotence.
4. Document downgrade/reset behavior.
5. Confirm cold top-8+other is documented as future schema readiness.
6. Feed V-2.

### Output

- cap-boundary test suite;
- migration/pruning/downgrade document;
- V-2 handoff.

### Not required

- live memory;
- new UI;
- account Knowledge/merge.
