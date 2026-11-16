# DS-17.4C — Retention and aggregation compatibility

**Status:** executed 2026-11-16  
**Result:** `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`  
**Harness:** `tests/ds17_4c_retention.lua`  
**Depends on:** DS-17.4A, DS-17.4B, DS-17.3, DS-7/DS-12  
**Blocks:** DS-17.5, DS-9, DS-11

## Why

The per-character Journey is the primary asset. Cold retention must not shrink it
so aggressively that future danger/best-zone/account analysis loses the required
dimensions.

Retention is about movement and packing, not deleting useful inputs.

## Scope

- Define which fields must survive hot → warm → cold:
  - byLevel/byMap/byInstance kills/XP/deaths/time;
  - combat and XP context aggregates;
  - active time;
  - heatmap cells;
  - respawn summaries;
  - quest XP/count;
  - death records/attribution;
  - sample/confidence counts.
- Measure cold archive quality:
  - full vs top-N contexts;
  - 64→32→16 heatmap;
  - level-band aggregation;
  - mob/zone/instance dictionaries.
- Verify future Knowledge aggregation is possible from cold data.
- Define what can be summarised/dropped without losing query ability.
- Define backup/restore and downgrade rules for packed archives.
- No merge implementation.

## Test profiles

- 10k/100k/350k mob records;
- 200 zones/200 instances;
- contexts 4/8/12 with top-N collapse;
- 64/32/16 grids;
- sparse/dense zones;
- level/endgame/archive generations;
- local sample.

Measure:

- cold bytes/heap;
- selected-block decode;
- aggregation inputs before/after retention;
- danger/best-zone/heatmap quality loss;
- backup/restore;
- load/save cost.

## Acceptance

- Retention preserves all aggregation inputs.
- Downsampling has measured error, not silent loss.
- Future Knowledge can be derived from cold data.
- Backup/restore is defined.
- No arbitrary global cap.
- DS-17.5/DS-9 can proceed.

## Not required

- merge implementation;
- account-wide writes;
- UI;
- live client test;
- route recommendation.
