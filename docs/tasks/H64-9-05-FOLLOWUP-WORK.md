# H64-9.5 — Follow-up work from the heatmap benchmark

**Status:** follow-up tasks defined, not implemented  
**Parent:** H64-9  
**Source:** `docs/H64-9-BENCHMARK-REPORT.md`

## H64-9-F1 — Rescale path optimization

**Priority:** high  
**Evidence:** dense square rescale **6.4 ms**, dense 41-map rescale **11.6 ms**,
versus **0.75–1.28 ms** incremental.  
**Why:** a new per-zone maximum should not touch every active cell's geometry or
visibility when only color changes.

Scope:

- inspect `KillHistory/UI/Heatmap.lua` rescale/incremental branches;
- on rescale, avoid `ClearAllPoints`/`SetPoint`/`SetSize` for cells already in
  the correct geometry;
- avoid `Show()` when the cell is already shown;
- keep color/alpha updates for every active cell;
- add a test that counts geometry/show operations during rescale.

Acceptance:

- dense rescale performs no repositioning or redundant `Show` for visible cells;
- rendered output is unchanged;
- rescale operation counts and time are lower than the current baseline;
- no full rebuild occurs;
- live visual check remains V-1.

**Files:** `KillHistory/UI/Heatmap.lua`, `tests/smoke.lua`,
`tests/bench_heatmap.lua`.

## H64-9-F2 — Disabled-state hide guard

**Priority:** medium  
**Evidence:** with collection disabled, every refresh still performs `Hide` on
~4,100 cells and costs ~0.6 ms.  
**Why:** data/art work is already zero; UI cleanup should happen once, not on
every refresh.

Scope:

- track whether the cell pool is already hidden for the disabled state;
- short-circuit repeated disabled refreshes;
- preserve the disabled message and hidden grid/legend/art;
- test repeated disabled refreshes.

Acceptance:

- first disabled switch hides cells/art;
- subsequent disabled refreshes perform no per-cell work;
- re-enabling restores the normal render;
- report shows zero/negligible disabled work after the first switch.

**Files:** `KillHistory/UI/Heatmap.lua`, `tests/smoke.lua`.

## H64-9-F3 — Display detail and cell-pool study

**Priority:** low / not justified by current real samples  
**Evidence:** dense 4,096-cell profiles reach ~20 MB in the fixture process; the
pool persists at 4,096 cells and is reused by later sparse zones.  
**Reference context:** AllTheThings ~51 MB loaded / ~65 MB opened (several hundred
MB on Midnight); ForeverLevelingGuide ~48 MB. Real 2.5.2 samples: Hunter 389 kills / 25 mobs, UI open = **3.2 MB**; Priest
762 kills / 85 mobs with the Silverpine heatmap open = **3.85 MB**. The 20 MB
fixture figure is not a real-client budget.  
**Why:** this may be acceptable in-game; measure real memory first (`MEM-1`),
then decide whether a display-detail cap is warranted.

Scope:

- use `MEM-1` real-client measurements before optimizing;
- separate data memory from fixture/UI object memory;
- evaluate a display-only detail cap (for example 32×32) while keeping 64×64
  storage;
- measure memory/operation counts at 16/32/64 display;
- feed G-2/SC-2 and V-1;
- do not change the stored grid in this task.

Acceptance:

- measured display-detail options with bytes/operations;
- recommendation for or against a display cap;
- no storage-schema change;
- G-2/G-3 receive the result.

## H64-9-F4 — Zone-scoped/lazy normalization

**Priority:** high for storage/load, separate from UI  
**Evidence:** 40 dense maps normalize in **93 ms**; 41 maps in **91 ms**; one
dense map is **2.2 ms**. Cost scales with dense map count, not kill count.

Scope:

- investigate normalizing only the selected/current zone;
- evaluate lazy decode/materialization (DS-15);
- preserve map-cap pruning and diagnostics counts;
- measure login/first-open cost;
- coordinate with DS-2/SC-1.

Acceptance:

- normalization cost is bounded by the active zone, not all stored zones;
- selected-zone data remains identical;
- map-cap pruning remains deterministic;
- diagnostics still reports total stored zones/cells;
- DS-15/SC-1 receive the evidence.

## H64-9-F5 — Aspect ratio and occupied-mask follow-up

**Priority:** medium  
**Evidence:** wide/tall profiles use only 1,024 of 4,096 cells; empty cells cost
no storage but reduce effective resolution.  
**Scope:** feed G-2/G-3; evaluate occupied masks/rectangular grids/96/128 only
with visual and storage evidence.  
**Acceptance:** G-2 has the wide/tall/irregular data; G-3 decides with it.

## H64-9-F6 — Art/overlay cost follow-up

**Priority:** low/medium  
**Evidence:** offline art mock is inconclusive; art tiles and overlay rendering
must be judged in R-4/V-5.  
**Scope:** feed R-4 and V-5; do not change the data grid for art cost.  
**Acceptance:** R-4 audit includes the art-tile/overlay counts; V-5 confirms live
visual/frame behavior.

## Sequencing

1. **F1** rescale optimization — small, testable UI win.
2. **F2** disabled hide guard — small correctness/efficiency fix.
3. **F4** zone-scoped normalization — storage/load.
4. **F3** display-detail study — UI memory, gated by `MEM-1`.
5. **F5** aspect/occupied mask — G-2/G-3.
6. **F6** art — R-4/V-5.

## Plan updates required

- Mark `H64-9` measured.
- Add `H64-9-F1`..`F6` to the relevant work packages.
- Link this file and the benchmark report from `PLAN.md`.
- Do not mark any follow-up complete until its tests pass.
