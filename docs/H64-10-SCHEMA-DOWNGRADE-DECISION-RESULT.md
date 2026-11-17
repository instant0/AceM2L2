# H64-10 — Schema/downgrade decision result

**Status:** decided 2026-11-16; non-live  
**Test:** `tests/schema_decision.lua`; `./tests/run_all.sh`  
**Scope:** per-client data schema and legacy heatmap-grid inference. No storage
format change.

## Decision

**Keep the per-client data schema at `1`.**

Do not bump it for 64×64 heatmaps.

## Rationale

- 64×64 is expressed by each heatmap entry’s `gridSize = 64`.
- Saves written since 2.2.0 already carry `gridSize`, so their shape is
  unambiguous.
- Bumping the per-client schema would block older builds from reading new saves
  without changing the data shape or fixing a live defect.
- A forced migration would add save/backup risk with no storage benefit.
- The remaining ambiguity is a pre-2.2.0 32×32 save with no `gridSize` and all
  cell indices `<= 256`. It is inferred as 16×16.
- That ambiguity is documented and tested. Totals are preserved; only geometry
  is coarser for that narrow legacy case.

## Retained behavior

1. No `gridSize`, max cell `<= 256` → inferred 16×16, upgraded to 64×64.
2. `gridSize = 32` → migrated as 32×32.
3. `gridSize = 64` → passed through unchanged.
4. Per-client data schema remains `1`.
5. Storage schema remains `2`; Journey block schema is separate.

## Test evidence

`tests/schema_decision.lua` verifies:

- ambiguous legacy cells preserve total and split into 4×4 blocks;
- explicit 32×32 migration remains correct;
- modern 64×64 data is unchanged;
- persisted client data schema remains `1`.

Passing output:

```text
Schema decision passed
```

`./tests/run_all.sh` passes.

## Future trigger

Revisit only if:

- the durable heatmap grid changes again;
- heatmap fields require a new per-client shape;
- a migration is needed for another reason.

Emergency downgrade remains protected by the existing schema guards.

## Artifacts

- `tests/schema_decision.lua`
- `tests/run_all.sh`
- `README.md`
- `docs/tasks/H64-10-SCHEMA-DOWNGRADE-DECISION.md`
