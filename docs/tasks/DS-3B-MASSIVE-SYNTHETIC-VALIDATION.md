# DS-3B — Massive synthetic store validation

**Status:** next; ready; offline validation  
**Purpose:** replace the structural capacity estimate with one actual
worst-case synthetic SavedVariables file. No live client and no schema change.

## Why

The 11–14 MB and 18–25 MB figures are structural estimates. They are useful for
direction, but not enough to drive a schema decision. DS-3's 10× test had zero
contexts and only 1,930 cells, so it did not exercise the real growth drivers.

## Profile

One mandatory worst-case profile:

- 2,000 mobs;
- 12 contexts per mob = 24,000 contexts;
- 40 zones × 4,096 cells = 163,840 heatmap cells;
- 100 instance records;
- 200 quests;
- 100 deaths;
- 300 respawn NPCs × 20 interval samples;
- 200 level-history records;
- 240 rate samples;
- all normal mob fields, per-level/map/instance counters, and derived summaries.

Optional second profile only if cheap:

- 200 zones × 1,000 cells = 200,000 cells;
- 200 instance records;
- same mobs/contexts.

Do not build a six-layout matrix.

## Method

- Generate the profile offline with the existing fixtures/serializer or an
  equivalent deterministic builder.
- Normalize with `EnsureDB`.
- Record actual serialized bytes and Lua heap.
- Save, reload in a fresh process, and verify the aggregate invariants.
- Record load/normalize/save/reload time.
- Compare with `docs/DS-17-1-CAPACITY-AND-STRATEGY.md`.

## Pass criteria

- Save/reload preserves totals, mobs, areas, levels, instances, and heatmaps.
- No double counting or invented data.
- Actual bytes and timing are recorded without claiming client performance.
- If actual size is materially above the model range, update the strategy before
  DS-17.1 finalizes hot/cold boundaries.
- If actual size is below the range, do not use that as proof that the global
  caps are sufficient; record it.

## Output

- `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`;
- actual bytes, Lua heap, timings, and invariant result;
- corrected capacity range if needed;
- no production code or schema change.

## Not required

- live client test;
- exact content census;
- multi-layout matrix;
- schema implementation;
- companion packaging.

## Execution order

DS-3B -> DS-17.1 hot/cold and required keys -> DS-1-F2 indexes.
