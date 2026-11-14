# Next task

## DS-2 — Real-store baseline

**Status:** next; ready; consolidation task  
**Task:** `PLAN.md` DS-2  
**Inputs:** `docs/DS-3-STORAGE-SANITY-RESULT.md`,
`docs/HC-5-DIAGNOSTICS-BASELINE.md`, `docs/tasks/MEM-1-MEMORY-BUDGET.md`,
`docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`,
`docs/tasks/DS-17-01-AGGREGATION-AND-GRID.md`

### Why this is next

- DS-3 measured the real 762-kill save and a 10× synthetic copy.
- DS-5 closed the loading/scope questions.
- DS-2 is the last input DS-17.1 needs: one baseline with counts, bytes, and
  clearly labeled projections.
- No new test is required; consolidate existing measurements.

### Work

1. Record the real 762-kill save:
   - 70,661 file bytes; 82,614 diagnostic estimate;
   - 85 mobs, 762 kills, 617 open-world, 145 instance;
   - 2 heatmap zones, 193 cells, 1 instance;
   - contexts, rates, calibration, level records.
2. Record the 389-kill / 25-mob sample separately:
   - it is a **memory sample**, not a saved file;
   - 3.2 MB with UI open.
3. Record scope:
   - account `AceM2L2DB` loads for every character;
   - per-character `AceM2L2CharDB` loads only for the active character;
   - no per-zone SavedVariables files.
4. Derive ratios that the real save actually supports:
   - unique mobs per kill: `85 / 762`;
   - instance share: `145 / 762`;
   - kills per unique mob: `762 / 85`;
   - contexts per mob: real sample is 0; use the configured cap only as a
     planning bound.
5. **Do not label kills/hour as measured.** The current save does not contain
   playtime. If a time dimension is useful, show a clearly labeled planning
   range and keep storage size independent of it.
6. Project storage at DS-17.1 tiers, not an arbitrary matrix:
   - 1,000 / 10,000 / 22,500 kills;
   - mobs saturating at the 2,000 cap;
   - instance share at the measured 19%;
   - sparse, 1k, and 4k cells per zone;
   - contexts at 0, 4, 8, 12 per mob.
7. Name the largest growth drivers and the cap/retention implications.
8. Keep the `/mnt/r` reference corpus as shape/size comparison only.

### Output

- `docs/DS-2-REAL-STORE-BASELINE.md`;
- one real baseline table;
- one projection table with assumptions;
- a short growth-driver and cap summary;
- no production code change.

### Not required

- long-lived multi-zone save;
- exact WoW content census;
- new storage tests;
- new schema;
- repeating DS-3 or DS-5;
- claiming measured kills/hour without playtime data;
- a full external-corpus analysis.
