# Next task

## DS-17.1 — Aggregation and 64×64 sufficiency

**Status:** next; safe design task; capacity and DS-3B validation complete  
**Task document:** `docs/tasks/DS-17-01-AGGREGATION-AND-GRID.md`  
**Inputs:** `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`,
`docs/DS-3C-LONG-TERM-GROWTH.md`,
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`, `docs/STORAGE-STRATEGY.md`,
`docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`,
`docs/tasks/DS-1-CONSUMER-CONTRACT.md`

### Why this is next

- DS-3B validated the current-hot profile: 8.69 MB compact / 9.94 MB client
  estimate, 23 MB stable / 27–37 MB transient. That is a current-cap synthetic,
  not a long-term state.
- DS-3C shows the current caps are too small: 2h/day reaches the 2,000-mob cap in
  ~3 months and the 240-rate-sample buffer turns over in 2.4h.
- DS-4/DS-5 settled the hot representation and loading constraints.
- Remaining: feature-to-data matrix, hot/warm/cold boundary, required keys, and
  the explicit 64×64 decision.

### Work

1. Build the feature-to-data matrix:
   scope, required fields, hot/warm/cold unit, query/index, fallback, retention.
2. Confirm minimum durable units for heatmap, mob, level, zone, instance,
   context, and session.
3. Define hot/warm/cold boundaries and replace the 2,000-mob/40-zone/100-instance
   global caps with per-zone/per-block retention. Design for long-term growth,
   not the current cap profile.
4. Define required hot-index fields and cold-block fields.
5. Use DS-3B actuals to decide the efficient context/zone policy. No fixed MB or
   element target; compare retrieval value against measured memory/IO.
6. Run the 64×64 vs 96/128/aspect-ratio decision using the existing H64-9/DS-3
   harness. No new matrix.
7. Prove no per-kill event log is needed; name a feature and cost if one is.
8. Produce DS-4P input: hot index, cold blocks, retention, indexes.

### Output

- aggregation decision note;
- feature-to-data matrix;
- unique-cardinality table per player profile;
- hot/warm/cold boundary and cap-retention policy;
- 64×64 sufficiency recommendation;
- required keys for hot index and cold blocks;
- DS-4P hybrid prototype inputs.

### Not required

- exact WoW content census;
- live-client test;
- schema implementation;
- repeating DS-2/DS-3/DS-3B/DS-5;
- reopening settled DS-4/DS-5 choices;
- treating the current small-store caps as the massive design.

### Safe first code task after this

**DS-1-F2 — in-memory identity/zone/instance indexes.** No schema or persistence
change; removes full mob scans from tooltip/name and zone-list retrieval.
