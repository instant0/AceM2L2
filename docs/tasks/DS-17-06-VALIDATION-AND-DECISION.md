# DS-17.6 — Validation, measurement, and decision

**Status:** research/validation task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-17.1..DS-17.5, SC-1, SC-2  
**Blocks:** DS-11

## Scope

Measure the proposed model and produce the evidence DS-11 needs.

## Profiles

- Player scenarios: level 1, level 20, max-level/endgame, first alt with a 1–60
  archive, 10-year veteran with multiple alts/archives.
- Entry-capacity tiers: 100 / 1,000 / 10,000 / 100,000; 350,000 as an external
  AllTheThings-scale reference only.
- 1–60 leveling life with 250 kills/level; 1–90 Midnight variant.
- 30, 50, and 100 instances.
- Sparse/medium/dense heatmaps.
- 1:1, 4:1, 1:4, and irregular zones with occupied/empty-cell counts.
- 1, 3, and 5 alts.
- Leveling + endgame archive.
- Endgame state where AceM2L2's visible value is reputation/non-XP history, not
  XP detail.
- Shared knowledge with 1/3/5 source characters.

## Measurements

- bytes per profile and per tier;
- table/entry/cell counts;
- load, normalize, prune, compress, decode, and save time;
- UI list/heatmap latency;
- archive downsample error, including empty-cell and aspect-ratio effects;
- shared-knowledge confidence/error;
- route recommendation prediction error against a held-out character;
- route confidence calibration for 1/3/5 source characters;
- migration/backup time;
- downgrade/corruption behavior.

## Work items

- Reuse DS-2/DS-3/SC harnesses.
- Add lifecycle and alt profiles.
- Record both estimate and actual serialized bytes.
- Test no per-kill log is present.
- Verify 64×64 or the chosen grid.
- Backtest the route recommendation and its insufficient-data fallback.
- Verify 40-zone/100-instance replacement budgets.
- Produce acceptance table.
- Write DS-11 recommendation.

## Deliverables

- Measurement report.
- Acceptance table.
- DS-11 recommendation.
- Residual risks.

## Acceptance criteria

- 12k–25k kills are represented without per-kill rows.
- The full 1–60/1–max life has a measured budget.
- Hot/warm/cold + shared knowledge stay within agreed quotas.
- Migration/backup/downgrade tests pass.
- DS-11 has enough evidence to choose a schema.
- No live client is required; V-2 handles runtime validation.

## Risks

- Synthetic profiles may not match real class/route diversity.
- Compression/decode timing offline may differ from the client.
- Shared data may be too sparse to be useful in small samples.
