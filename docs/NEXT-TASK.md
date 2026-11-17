# Next task

## HIST-1A — Relevance classifier and historical tooltip/Detail

**Status:** next; non-live design/prototype  
**Task document:** `docs/tasks/HIST-1-HISTORICAL-RELEVANCE.md`  
**Related:** `docs/SC-4-CONTEXT-CAP-RESULT.md`,
`docs/SC-5-MIGRATION-PRUNING-RESULT.md`

### Why this is next

- Context expiry removes stale XP calibration, not history.
- Outleveled characters need place/history value:
  - heatmap;
  - kill counts;
  - deaths;
  - rares;
  - quest journey.
- They should not be shown stale XP estimates or kills-to-level.
- This is the first phase of the HIST-1 proposal.

### Work

1. Define active vs historical relevance from player level vs content level and
   recency.
2. Add historical tooltip mode:
   - kills, classification, rare flag, first/last seen, zones;
   - omit XP estimate, kills-to-level, context XP.
3. Add historical Detail sections:
   - top zones;
   - deaths;
   - rares;
   - quest anchors when available.
4. Keep active-level behavior unchanged.
5. No false zero and no fake XP.
6. Do not add per-kill timestamps.
7. No schema change in HIST-1A.

### Output

- relevance classifier;
- historical tooltip/Detail;
- smoke tests for active/historical modes.

### Not required

- quest-anchor capture;
- heatmap time dimension;
- account Knowledge;
- live client test.
