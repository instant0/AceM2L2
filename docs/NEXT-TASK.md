# Next task

## DS-17.1 — Aggregation and 64×64 sufficiency

**Status:** next; capacity math complete; massive hybrid decision required  
**Task document:** `docs/tasks/DS-17-01-AGGREGATION-AND-GRID.md`  
**Inputs:** `docs/STORAGE-STRATEGY.md`,
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`,
`docs/tasks/DS-2-REAL-STORE-BASELINE.md`, `docs/DS-3-STORAGE-SANITY-RESULT.md`,
`docs/STORAGE-DIRECTION.md`, `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`,
`docs/tasks/DS-1-CONSUMER-CONTRACT.md`

### Why this is next

- DS-1..DS-5 are complete, but the current capped hot-only store is **not**
  massive-ready.
- The capacity math is done: 250 kills/level, 15k–32.5k kills, 40/100/200 zones,
  50/100/200 instances, 2,000 mobs. Contexts and dense heatmaps dominate.
- Remaining: feature-to-data matrix, cardinality table, hot/warm/cold boundary,
  no-global-cap policy, and explicit 64×64 decision.

### Work

1. Build the feature-to-data matrix from DS-1.
2. Confirm the minimum durable units for heatmap, mob, level, zone, instance,
   session, and shared knowledge.
3. Use the capacity strategy to define hot, warm, cold, and archive units.
   Replace the 2,000-mob/40-zone/100-instance global caps with per-zone/per-block
   retention; do not just raise the caps.
4. Test whether 64×64 cells are sufficient for heatmap, route, and cell-inspector
   meaning; include wide/tall/irregular zones and sparse/dense occupancy.
5. Record cardinality for level 1, level 20, max-level, first-alt, and
   10-year-veteran profiles using the capacity tiers.
6. Prove that no per-kill event log is required; name a feature and cost if one
   is needed.
7. Confirm the required keys for the final schema (DS-17.5).
8. Apply DS-5 constraints: normal SavedVariables load together, active-character
   scope only for per-character data, no per-zone files, companion timing is
   V-2.

### Output

- aggregation decision note;
- feature-to-data matrix;
- unique-cardinality table;
- hot/warm/cold boundary and cap-retention policy;
- 64×64 sufficiency recommendation;
- required keys for the hot index and cold blocks;
- DS-4P hybrid prototype inputs;
- named follow-ups.

### Not required

- exact WoW content census;
- new live-client test;
- schema implementation;
- repeating DS-2/DS-3/DS-5;
- a per-kill event log unless a feature explicitly requires it;
- treating the current small-store caps as the massive-scale design.
