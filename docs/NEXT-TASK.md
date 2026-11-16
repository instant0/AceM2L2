# Next task

## DS-17.4A — Journey/Knowledge model validation

**Status:** next; ready  
**Task document:** `docs/tasks/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL.md`  
**Full plan:** `docs/DATA-MODEL-PLAN.md`  
**Model record:** `docs/DATA-MODEL-AND-TEST-MATRIX.md`  
**Inputs:** `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`,
`docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`, `docs/DS-17-1-AGGREGATION-DECISION.md`,
`docs/DS-17-3-RETENTION-DECISION.md`, local `/mnt/r/AceM2L2.lua`

### Why this is next

- The per-character Journey is the primary asset and must not be shrunk to the
  current caps.
- Account-wide Knowledge is a future derived target; merge is not implemented
  now.
- Danger and best-zone XP/hour need context/time/outcome fields that the current
  schema does not fully expose.
- DS-15 retrieval should not proceed until the model and context trade-offs are
  measured.

### Work

1. Inventory the local Journey fields and missing dimensions.
2. Measure combat/XP context cardinality and top-N/collapse trade-offs.
3. Prototype danger outcomes by context.
4. Prototype best-zone XP/hour ranking.
5. Prototype heatmap best-cell ranking.
6. Verify retention preserves aggregation inputs.
7. Compare nested, parallel-array, and packed schema shapes.
8. Define the account Knowledge target only; do not merge.

### Output

- `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`
- measured tables and recommended schema
- V-2 data/API gaps
- revised inputs for DS-17.4/DS-17.5/DS-15/DS-16

### Not required

- merge implementation;
- account-wide writes;
- UI work;
- live client test;
- route recommendation;
- online verification.
