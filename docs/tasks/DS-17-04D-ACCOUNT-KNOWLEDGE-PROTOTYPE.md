# DS-17.4D — Account Knowledge derivation prototype

**Status:** future; after DS-17.5  
**Depends on:** DS-17.4A/B/C, DS-17.5  
**Blocks:** future ALT features, DS-11 validation

## Why

Account-wide Knowledge is a future derived target. The per-character Journey is
always available in SavedVariables, so the merge can be implemented later.

This task proves the schema can produce useful account-wide Knowledge from
character data without copying raw history.

## Scope

- Read one or more character SavedVariables in an offline prototype.
- Derive account Knowledge:
  - stable mob metadata;
  - danger by combat context;
  - XP by XP context;
  - zone/instance/level XP/hour;
  - heatmap cell aggregates;
  - respawn summaries;
  - quest XP summaries;
  - confidence/sample/recency.
- Multiple characters, overlapping mobs/zones.
- Project/interface/level-cap/mode separation.
- Idempotence.
- Size/load/save.
- Rebuild from surviving character data.
- No raw character identity or session timeline.
- No production writes yet.

## Test profiles

- 1/3/5 synthetic characters with overlap;
- local `/mnt/r/AceM2L2.lua`;
- sparse/dense zones;
- different classes/levels/groups/buffs;
- level-cap generations;
- source character missing/deleted.

Measure:

- Knowledge size/heap;
- derivation time;
- query latency;
- confidence/coverage;
- idempotence;
- no raw history leakage.

## Acceptance

- Knowledge is derived from Journey data.
- No raw history/identity copied.
- Overlap counts are additive and deduplicated.
- Project/interface/level-cap separation works.
- Rebuild is possible.
- DS-11 can decide whether to ship ALT features.

## Not required

- production merge;
- UI;
- route recommendation;
- live client test.
