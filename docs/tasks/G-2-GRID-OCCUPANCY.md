# G-2 — 64 vs 96/128 occupancy study

**Status:** next; non-live study  
**Depends on:** H64-9-F5, SC-1, SC-2, DS-17.4C  
**Blocks:** G-3

## Why

64×64 is the current durable grid. H64-9-F5 found near-square real spans and no
justification for an occupied mask yet. G-2 must compare 96/128 and
aspect-aware alternatives before G-3 decides.

## Scope

- Export/measure real heatmap occupancy from the local store.
- Compare 64/96/128 for:
  - occupied/empty cells;
  - effective east-west/north-south resolution;
  - wide/tall/irregular map shapes;
  - storage and render cost envelopes;
  - top-hotspot overlap after downsample.
- Evaluate:
  - square 64;
  - square 96/128;
  - aspect-aware/rectangular display;
  - occupied mask.
- Keep stored grid unchanged until G-3.
- No live visual/frame claim; feed V-1/V-5.

## Acceptance

- Occupancy/aspect table for real + synthetic data.
- Cost table for 64/96/128 and alternatives.
- Recommendation for G-3.
- No storage change in this task.

## Not required

- live visual/frame test;
- schema change;
- account Knowledge/merge.
