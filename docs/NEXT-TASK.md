# Next task

## HIST-1B — Historical zone surfaces

**Status:** next; non-live design/prototype  
**Task document:** `docs/tasks/HIST-1B-HISTORICAL-ZONE-SURFACES.md`  
**Related:** `docs/HIST-1A-HISTORICAL-RELEVANCE-RESULT.md`

### Why this is next

- HIST-1A added historical tooltip/Detail behavior.
- Outleveled characters need a zone-level history surface:
  - heatmap;
  - deaths;
  - rares;
  - top mobs;
  - journey anchors.
- Existing data covers most of this without a schema change.

### Work

1. Add a historical zone view/panel.
2. Reuse heatmap, deaths, classifications, and journey summaries.
3. Filter rare/elite mobs.
4. Show top mobs and notable deaths.
5. Use existing quest anchors only; no capture change yet.
6. Hide XP advice in historical mode.
7. Preserve active behavior.

### Output

- historical zone surface;
- empty/unavailable states;
- tests for historical/active behavior.

### Not required

- quest-anchor log;
- account Knowledge;
- live client test.
