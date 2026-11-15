# Next task

## DS-3B — Massive synthetic store validation

**Status:** next; safe offline validation; no production code  
**Task document:** `docs/tasks/DS-3B-MASSIVE-SYNTHETIC-VALIDATION.md`  
**Inputs:** `docs/PERFORMANCE-REVIEW.md`,
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`, `docs/DS-3-STORAGE-SANITY-RESULT.md`,
`docs/HC-5-DIAGNOSTICS-BASELINE.md`, `tests/storage_sanity.lua`

### Why this is next

- The 11–14 MB and 18–25 MB figures are structural estimates.
- DS-3's 10× case had zero contexts and only 1,930 cells.
- HC-5's 2.1 MB extreme is truncated.
- We should validate the actual huge file before finalizing hot/cold boundaries.

### Work

1. Generate one offline worst-case profile:
   - 2,000 mobs;
   - 12 contexts/mob = 24,000 contexts;
   - 40 zones × 4,096 cells = 163,840 cells;
   - 100 instances;
   - quests/deaths/respawns/rates/level history at caps.
2. Normalize with `EnsureDB`.
3. Record actual serialized bytes and Lua heap.
4. Save, reload in a fresh process, and verify totals, areas, levels, instances,
   and heatmaps.
5. Record load/normalize/save/reload time.
6. Compare with the capacity range and correct it if necessary.
7. Optional only if cheap: 200 zones × 1,000 cells, 200 instances.

### Output

- `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`;
- actual bytes, Lua heap, timings, invariant result;
- corrected capacity range if needed.

### Not required

- live client test;
- exact content census;
- six-layout matrix;
- schema change;
- companion packaging;
- production code.

### After this

1. DS-17.1 hot/cold boundary and required keys.
2. DS-1-F2 in-memory indexes as the first safe code task.
3. DS-17.2/17.3 and DS-4P.
