# H64-9 — Offline dense-zone benchmark report

**Status:** executed; harness and report complete  
**Harness:** `tests/bench_heatmap.lua`  
**Task:** `docs/tasks/H64-9-00-OVERVIEW.md`  
**Environment:** Lua 5.1-compatible fixture harness, no WoW client  
**Live frame-time boundary:** V-1

## 1. Environment and method

- `tests/fixtures.lua` initializes the real addon/module and UI mocks.
- Each profile was run in a separate Lua process for the isolated figures below.
- Profiles generate real heatmap tables with `gridSize = 64`, sparse `cells`,
  `total`, and `lastSeen`.
- UI operations are counted by wrapping fixture texture/frame methods.
- Times are `os.clock()` milliseconds. They are relative offline costs, not live
  frame times.
- Memory is `collectgarbage("count")` and includes fixture UI objects and the
  retained cell pool. It is not SavedVariables size.

## 2. Profiles

| Profile | Shape | Maps | Active | Occupied | Empty |
|---|---|---:|---:|---:|---:|
| sparse_square_1 | 1:1 | 1 | 100 | 100 | 3,996 |
| medium_square_1 | 1:1 | 1 | 1,000 | 1,000 | 3,096 |
| dense_square_1 | 1:1 | 1 | 4,096 | 4,096 | 0 |
| dense_wide_1 | 4:1 | 1 | 1,024 | 1,024 | 3,072 |
| dense_tall_1 | 1:4 | 1 | 1,024 | 1,024 | 3,072 |
| dense_irregular_1 | irregular | 1 | 1,400 | 1,400 | 2,696 |
| dense_square_40 | 1:1 | 40 | 4,096 | 4,096 | 0 |
| dense_square_41 | 1:1 | 41 | 4,096 | 4,096 | 0 |
| disabled_square | 1:1 | 1 | 4,096 | 4,096 | 0 |
| noart_square | 1:1 | 1 | 4,096 | 4,096 | 0 |

Wide/tall/irregular profiles use only occupied cells; the empty cells are not
inserted into the sparse cell table.

## 3. Results

Isolated per-process runs, one measurement each:

| Profile | Normalize ms | Record 1000 ms | First render ms | Rescale ms | Incremental ms | Resize ms | Disabled ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| sparse_square_1 | 0.08 | 6.47 | 0.49 | 0.40 | 0.22 | 0.45 | 0.03 |
| medium_square_1 | 0.56 | 6.31 | 2.22 | 1.91 | 0.39 | 2.09 | 0.17 |
| dense_square_1 | 2.19 | 5.48 | **9.44** | **6.39** | **0.75** | **7.79** | 0.64 |
| dense_wide_1 | 0.58 | 8.00 | 2.28 | 2.22 | 0.42 | 2.25 | 0.15 |
| dense_tall_1 | 0.60 | 5.18 | 2.18 | 2.01 | 0.41 | 2.24 | 0.15 |
| dense_irregular_1 | 0.98 | 5.67 | 3.08 | 2.78 | 0.58 | 4.42 | 0.22 |
| dense_square_40 | **93.18** | 6.24 | **12.38** | 7.95 | 1.16 | 7.70 | 0.62 |
| dense_square_41 | **91.28** | 6.18 | **11.02** | **11.59** | 1.28 | **11.73** | 0.56 |
| disabled_square | 2.13 | 5.24 | 0.67 | 0.59 | 0.54 | 0.63 | 0.65 |
| noart_square | 2.19 | 5.37 | 10.22 | 6.20 | 0.68 | 9.13 | 0.90 |

Memory and counts:

| Profile | Memory before KB | Memory after KB | Cells | Pool cells | Art tiles |
|---|---:|---:|---:|---:|---:|
| sparse_square_1 | 1,797 | 3,310 | 100 | 101 | 4 |
| medium_square_1 | 1,825 | 7,255 | 1,000 | 1,001 | 4 |
| dense_square_1 | 1,857 | **20,367** | 4,096 | 4,096 | 4 |
| dense_wide_1 | 1,825 | 7,578 | 1,024 | 1,025 | 4 |
| dense_tall_1 | 1,825 | 7,407 | 1,024 | 1,025 | 4 |
| dense_irregular_1 | 1,858 | 8,735 | 1,400 | 1,401 | 4 |
| dense_square_40 | 4,365 | 22,313 | 4,096 | 4,096 | 4 |
| dense_square_41 | 4,429 | 22,914 | 4,096 | 4,096 | 4 |
| disabled_square | 1,857 | 20,381 | 4,096 | 4,096 | 0 |
| noart_square | 1,857 | 20,389 | 4,096 | 4,096 | 0 |

## 4. Operation counts

Dense square, first full render:

- `CreateTexture`: 4 (art tiles only; cells were already pooled)
- `SetPoint`: 4,100
- `SetSize`: 4,100
- `SetColorTexture`: 4,111
- `Show`: 4,103
- `Hide`: 4,098

Dense square, rescale:

- `SetColorTexture`: 4,111
- `Show`: 4,099
- `Hide`: 2

Dense square, incremental:

- `SetColorTexture`: 16
- `Show`: 4
- `Hide`: 2

Disabled collection, each refresh:

- `SetColorTexture`: 0
- `Show`: 1
- `Hide`: 4,100

## 5. Findings

### F1 — First render is heavy at dense sizes

- Dense square: **9.4 ms** offline.
- 40/41 maps: **11–12.4 ms**.
- Wide/tall: ~2.2 ms.
- Irregular: ~3.1 ms.

This is expected for creating/positioning/coloring 4,096 cells, but it is the
largest UI path in the offline benchmark.

### F2 — Rescale is not as cheap as expected

- Dense square rescale: **6.4 ms**, versus **0.75 ms** incremental.
- 41-map rescale: **11.6 ms**.
- The rescale path colors and shows all active cells; it avoids the full hide
  and rebuild but still touches every active cell.

**Follow-up:** only recolor already-visible active cells; skip reposition/Show
when geometry is unchanged.

### F3 — Incremental updates are cheap

- Dense square incremental: **0.75 ms**.
- 40/41 maps: **1.2–1.3 ms**.
- Normal updates should use this path; a new maximum is the expensive case.

### F4 — Map normalize is the biggest data cost

- 40 dense maps: **93 ms** normalization.
- 41 maps: **91 ms** before pruning to 40.
- 1 dense map: **2.2 ms**.
- The cost is roughly linear in dense maps, not in kills.

**Follow-up:** zone-scoped/lazy normalization (DS-15) or avoid normalizing all
zones at load. This is a storage/load decision, not just heatmap UI.

### F5 — Collection-disabled still hides the cell pool every refresh

- Data/art work is zero.
- Each disabled refresh still performs `Hide` on ~4,100 cells and takes
  ~0.6 ms.
- The first switch to disabled should hide once; subsequent refreshes should
  short-circuit if already hidden.

**Follow-up:** guard `HideHeatCells` with a rendered/disabled state.

### F6 — Aspect ratio and empty cells

- Wide/tall 1,024-cell profiles use 3,072 empty cells and cost ~2.2 ms full
  render.
- Empty cells cost zero data storage but reduce effective resolution.
- This is not a performance problem in the current sparse model, but remains a
  G-2/G-3 visual/resolution question.

### F7 — Memory and cell pool

- Dense 4,096-cell profiles reach ~20 MB in the offline fixture process.
- The pool persists at 4,096 cells after dense zones; later sparse zones reuse
  the pool.
- The number includes mock UI objects and retained frames; it is not real GPU
  memory.

**Reference context:** AllTheThings uses ~51 MB loaded / ~65 MB opened (~several
hundred MB on Midnight); ForeverLevelingGuide uses ~48 MB. The 20 MB fixture
figure is not a real-client budget and is not a reason to optimize by itself.
Real 2.5.2 samples: Hunter 389 kills / 25 mobs, UI open = **3.2 MB**; Priest
762 kills / 85 mobs, Silverpine heatmap open (408 kills) = **3.85 MB**. Both are
far below the reference addons; the heatmap-open state adds about 0.65 MB.

**Follow-up:** gate H64-9-F3 behind `MEM-1` real-client memory measurement. Feed
G-2/SC-2/V-1 only if the measured client footprint is material.

### F8 — Art cost is inconclusive offline

- Art mock produced 4 tiles; no-art and art profiles were within noise of each
  other for first render.
- Real overlay/art cost belongs to R-4/V-5.

## 6. Harness limitations

- Fixture UI objects are not real textures/frames; operation counts are relative.
- Memory includes the fixture/UI object graph, not just heatmap data.
- `OpenUI`/panel priming can create pooled cells before a measured full render;
  the harness forces rendered keys for full-render runs.
- Profiles run in separate processes for isolated memory; the all-in-one run is
  useful only for sequence/operation counts, not memory.
- No live FPS/frame-time claim is made.

## 7. Recommendation

- Keep 64×64 storage; dense offline full render is measurable but not
  automatically a defect.
- Prioritize **H64-9-F1 (rescale optimization)** and **H64-9-F2 (disabled hide
  guard)** as small, testable UI fixes.
- Treat **H64-9-F4 (map normalize)** as a storage/load task for DS-15/SC-1.
- Gate **H64-9-F3 (display/cell pool)** behind **MEM-1**; the 20 MB fixture
  figure is far below the 48–65 MB reference addons.
- Feed aspect/empty-cell findings to G-2/G-3.
- Defer live validation to V-1/V-2.

## 8. Follow-up tasks

See `docs/tasks/H64-9-05-FOLLOWUP-WORK.md`.
