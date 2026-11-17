# SC-1 — Real-store measurement

**Status:** executed 2026-11-16  
**Result:** `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md`  
**Harness:** `tests/measure_real_store.lua`  
**Depends on:** DS-2, DS-3, H64-9-F5  
**Blocks:** SC-2, SC-3, G-2/G-3

## Why

The next limits/grid decisions should use the actual saved-store shape, not only
synthetic profiles. H64-9-F5 measured aspect/occupancy; SC-1 measures the rest of
the real store.

## Scope

Measure the local real store (for example `/mnt/r/AceM2L2.lua`):

- per-project and per-character counts:
  - mobs, kills, XP, quests;
  - deaths, respawn NPCs/samples;
  - instances and kills;
  - heatmap zones/cells and occupancy;
  - contexts and calibration entries;
- serialized bytes and estimated bytes;
- bytes by major section;
- zone/instance/level distributions;
- mobs per zone, cells per zone, contexts per mob;
- largest zones/mobs;
- sparse/medium/dense classification;
- comparison with DS-2/DS-3B synthetic profiles.

## Constraints

- Read-only; do not edit the saved file.
- Do not include private/account data in committed docs beyond aggregate counts.
- No schema/storage change.
- If the sample is small, label findings as observational, not general proof.

## Acceptance

- Measurement report with actual counts/bytes and per-section shares.
- Real vs synthetic shape comparison.
- Inputs for SC-2/SC-3/G-2/G-3.
- No live client required.

## Not required

- live memory sample;
- schema change;
- data deletion;
- account Knowledge/merge.
