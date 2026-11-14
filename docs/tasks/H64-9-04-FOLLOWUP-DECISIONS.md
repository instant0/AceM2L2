# H64-9.4 — Decision gates and follow-up tasks

**Status:** executed; follow-ups defined  
**Parent:** H64-9  
**Owner:** heatmap/UI owner with benchmark engineer  
**Depends on:** H64-9.3  
**Outputs:** PLAN updates and, if needed, new tasks

## Decision gates

Use the measured report to answer each gate.

### Gate 1 — Keep 64×64?

- If dense render/rescale/incremental costs and memory are acceptable, keep 64×64.
- If wide/tall zones waste too much effective resolution, create a G-2 follow-up.
- Do not change the grid based on offline timing alone; G-2/G-3 and V-1 remain.

### Gate 2 — Full rebuild vs rescale vs incremental

- Verify a new maximum uses the rescale path, not a full rebuild.
- If rescale is still expensive, create a focused optimization task.
- If full rebuild dominates zone/theme/resize changes, evaluate split keys,
  batched updates, or cached layouts.

### Gate 3 — Memory/cell count

- Use `MEM-1` real-client memory first.
- AllTheThings is ~51 MB loaded / ~65 MB opened (~several hundred MB on
  Midnight); ForeverLevelingGuide is ~48 MB. Real 2.5.2 samples: Hunter 389 kills / 25 mobs, UI open = **3.2 MB**; Priest
  762 kills / 85 mobs with heatmap open = **3.85 MB**. The 20 MB fixture process
  is not a real-client budget.
- If the real client footprint is material, create a display-detail or cap
  follow-up (for example `heatmapDetail=32` for display only).
- Separate data memory from UI texture memory.

### Gate 4 — Map cap

- If 41-map pruning behaves deterministically and drops the oldest/lowest-value
  zone as intended, no change.
- If pruning causes unexpected data loss, create a DS-17/SC retention task.

### Gate 5 — Aspect ratio / empty cells

- If empty cells cost no storage, record that.
- If they materially reduce effective resolution or make the heatmap misleading,
  create a G-2/G-3 aspect-aware/occupied-mask follow-up.
- Do not count empty cells in storage estimates.

### Gate 6 — Collection-off

- If any heatmap/cell/art work happens while `heatmapEnabled=false`, create a
  bug task immediately.
- Verify event registration is also off.

### Gate 7 — Art cost

- If art tiles/overlays dominate, feed R-4/V-5 rather than changing the data
  grid.
- Keep data and art findings separate.

### Gate 8 — Storage

- Feed heatmap cell/zone measurements to SC-2 and DS-3.
- Feed occupancy/aspect findings to DS-17.1.
- Do not change storage caps from this benchmark alone.

## Actual outcomes

- Rescale is ~6–12 ms on dense/40/41 profiles, not incremental-cheap.
- Disabled refreshes still hide ~4,100 cells.
- 40/41 dense-map normalization is ~91–93 ms.
- First render is ~9–12 ms dense; wide/tall ~2 ms.
- Incremental is ~0.75–1.3 ms.
- Memory/pool results are fixture-heavy; live texture memory remains V-1.

The concrete follow-ups are in
`docs/tasks/H64-9-05-FOLLOWUP-WORK.md`.

## Follow-up task templates

If needed, create one or more of:

- **H64-9-F1 — Rescale optimization.** Reduce per-update recoloring or batch it.
- **H64-9-F2 — Full-rebuild optimization.** Cache geometry/layout; split keys.
- **H64-9-F3 — Display-detail fallback.** Optional 32×32 display while storing 64.
- **H64-9-F4 — Aspect/occupied-mask study.** Feed G-2/G-3.
- **H64-9-F5 — Map-cap retention.** Feed DS-17/SC.
- **H64-9-F6 — Art/overlay cost.** Feed R-4/V-5.
- **H64-9-F7 — Collection-gate bug.** Only if the disabled path does work.

Each follow-up must include:

- the measured evidence;
- the exact code path;
- expected benefit;
- risk;
- test plan;
- whether it needs V-1.

## PLAN updates

After H64-9.3:

- Mark `H64-9` measured.
- Update the plan map:
  - benchmark open → measured;
  - note the chosen grid/cap follow-ups;
  - link the report.
- If a follow-up is created, add it to the correct work package (WP-1/WP-3/WP-5).

## Acceptance criteria

- Every gate is answered with data or “not enough evidence”.
- Follow-ups are created only for measured problems.
- No follow-up claims live performance.
- SC-2/DS-3/G-2/G-3/V-1 receive the relevant measurements.
- PLAN is updated with results and next task.
