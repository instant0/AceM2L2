# H64-9.0 — Offline dense-zone benchmark: overview

**Status:** executed; report and follow-ups complete  
**Parent:** H64-9  
**Owner:** offline performance/benchmark engineer  
**Reviewers:** heatmap/UI owner; storage/DS owner  
**Type:** static/offline benchmark; no WoW client required  
**Related:** H64-8 (audit), HC-5 (diagnostics baseline), SC-2, DS-3, G-2, G-3,
R-4, V-1

## Objective

Measure the current 64×64 heatmap data and UI paths under sparse, dense, wide,
tall, and irregular zones. Produce a reusable harness and a report that answers:

- how the full-rebuild, rescale, and incremental paths scale;
- how much memory and how many UI operations dense zones need;
- how map-cap pruning behaves at 40/41 maps;
- how much the grid is occupied versus empty for real map shapes;
- whether any concrete optimization or follow-up task is justified.

**This task does not change gameplay or claim live frame rate.** Live frame cost
remains in V-1.

## Task documents

| Task | File | Purpose |
|---|---|---|
| H64-9.1 | `docs/tasks/H64-9-01-HARNESS-AND-DATA.md` | Build the harness, fixtures, profile data, instrumentation |
| H64-9.2 | `docs/tasks/H64-9-02-SCENARIO-MATRIX.md` | Define and generate all benchmark scenarios |
| H64-9.3 | `docs/tasks/H64-9-03-MEASUREMENTS-AND-REPORT.md` | Run protocol, metrics, report template |
| H64-9.4 | `docs/tasks/H64-9-04-FOLLOWUP-DECISIONS.md` | Decision gates and follow-up task creation |

## Inputs

Code and tests:

- `KillHistory/Heatmap.lua`
- `KillHistory/UI/Heatmap.lua`
- `KillHistory/MapOverlayData.lua`
- `KillHistory/UI/Theme.lua`
- `tests/fixtures.lua`
- `tests/smoke.lua`
- `tests/measure_diagnostics.lua`
- `docs/HC-5-DIAGNOSTICS-BASELINE.md`

Reference data:

- `/mnt/r/AceM2L2.lua` for real sparse-zone shape (85 mobs, 2 heatmap zones,
  193 cells).
- Official zone/instance counts in DS-17.
- Map overlay data build `12.1.5.69848` / `1.60.1.69913`.

## Outputs

- `tests/bench_heatmap.lua` — reusable harness (done).
- `docs/H64-9-BENCHMARK-REPORT.md` — results and interpretation (done).
- Follow-ups in `docs/tasks/H64-9-05-FOLLOWUP-WORK.md` (done).
- `PLAN.md` status and follow-up entries.

## Sequencing

1. H64-9.1: harness/instrumentation.
2. H64-9.2: scenario matrix and data generation.
3. H64-9.3: run and report.
4. H64-9.4: decide follow-ups.
5. Feed SC-2/DS-3/G-2/G-3/V-1.

## Acceptance criteria

- The harness runs offline with `lua tests/bench_heatmap.lua`.
- It covers sparse/medium/dense zones, 1:1/4:1/1:4/irregular shapes, 1/40/41
  maps, first render, rescale, map switch, resize, collection-off, and art
  on/off. **Done; see the report.**
- It reports timing, memory, cell/table counts, occupied/empty cells, and UI
  operation counts.
- It does not require a WoW client.
- The report has enough evidence to accept 64×64, optimize a path, or create a
  follow-up task.
- No production behavior changes unless a defect is found and separately
  approved.

## Non-goals

- Live FPS/frame-time measurement (V-1).
- Changing the grid size (G-2/G-3).
- Storage lifecycle work (DS-17).
- Map-overlay art audit (R-4).
- Journey/inspector implementation (DS-11 gate).

## Definition of done

- Harness committed and runnable.
- Report written with raw results and interpretation.
- Follow-up decisions recorded.
- PLAN status updated from “benchmark open” to the measured outcome.
- SC-2/DS-3 can reuse the harness without rewriting it.
