# DS-17.4B — Danger and XP/hour prototypes

**Status:** ready; after DS-17.4A  
**Depends on:** DS-17.4A, DS-17.1, DS-17.3  
**Blocks:** DS-17.4C, DS-17.5, DS-15

## Why

The Journey schema must support two future queries without a per-kill log:

1. **Danger:** has this mob killed a player under similar circumstances, or do
   players normally slaughter it?
2. **Best zone:** where is the highest XP/hour at the current level?

Both need measured context and confidence rules before schema/migration.

## Scope

### Danger

Use synthetic and local data to test:

- combat context:
  - player level;
  - mob level;
  - health band;
  - buff signature;
  - group size;
  - classification;
  - instance difficulty.
- outcomes:
  - kills;
  - deaths;
  - health lost;
  - time-to-kill;
  - samples.
- death rate and slaughter rate;
- confidence and “not enough data”;
- killer attribution requirement;
- sparse contexts and top-N/collapse.

Quest state is excluded.

### Best zone XP/hour

Test:

- per-zone/level `xp` and `activeSeconds`;
- session-derived active time;
- group, rested, buffs, deaths;
- ranking at current level;
- confidence and stale/low-sample fallback;
- comparison against kills/hour;
- no raw kill count as the sole metric.

### Heatmap best part

Test:

- per-cell kills, XP, active time;
- top-N cells;
- raw count vs kills/hour vs XP/hour;
- downsampling 64→32→16.

## Test profiles

- local `/mnt/r/AceM2L2.lua` observed data;
- synthetic contexts 1k/10k/100k observations;
- sparse/dense context tables;
- solo/group, rested/not, buff/no-buff;
- low/high death-rate mobs;
- multiple zones/levels with different active times;
- 64/32/16 grids.

Measure:

- context cardinality per mob;
- storage bytes/heap;
- lookup/query latency;
- danger confidence;
- XP/hour ranking stability;
- no full scan;
- retention impact.

## Acceptance

- Danger tooltip inputs are computable from Journey data.
- Best-zone ranking uses XP/hour, not raw kills.
- Heatmap best-cell ranking uses density/XP/hour.
- Sparse data yields “not enough data,” not false confidence.
- Context top-N/collapse rules are measured.
- Quest state is not part of combat/XP context.
- No production code changed.

## Not required

- UI;
- merge implementation;
- account-wide writes;
- live client test;
- route recommendation.
