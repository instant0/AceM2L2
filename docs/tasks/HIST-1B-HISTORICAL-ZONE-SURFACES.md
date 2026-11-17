# HIST-1B — Historical zone surfaces

**Status:** next; non-live design/prototype  
**Depends on:** HIST-1A, IMP-1B10, UI-3  
**Blocks:** HIST-1C

## Scope

Add a historical view for a zone/character:

- historic heatmap presence;
- notable deaths;
- rare/elite mobs;
- top mobs/kill counts;
- journey/quest anchors where available;
- no XP advice in historical mode.

## Work

1. Add a zone-history view or bounded panel.
2. Use existing heatmap zones/cells, deaths, classifications, and journey
   summaries.
3. Show recent/notable deaths with map/coordinates.
4. Filter to rare/rareelite/worldboss.
5. Show top mobs by kills.
6. Show quest anchors only from existing `db.quests`; no new log yet.
7. No per-kill timestamps.
8. No schema change in HIST-1B.

## Acceptance

- Historical zone view uses existing data.
- No stale XP claims.
- Deaths/rares/top mobs visible.
- Empty/missing states explicit.
- No new capture format.

## Not required

- quest-anchor history log;
- account Knowledge;
- live client test.
