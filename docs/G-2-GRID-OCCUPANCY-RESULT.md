# G-2 — 64 vs 96/128 occupancy result

**Status:** executed 2026-11-17  
**Harness:** `tests/grid_occupancy.lua`; `./tests/run_all.sh`  
**Inputs:** SC-1 real aggregate, DS-17.4B hotspot shares, H64-9-F5 aspect
result, SC-2 6× shape  
**Scope:** measurement and recommendation only. No grid, schema, UI, or storage
change.

## 1. Method

- Recorded real 64×64 aggregates come from SC-1 and DS-17.4B.
- The raw SavedVariables file was not present in this offline session, so the
  real zones are replayed from their recorded aggregate shape:
  - `1421`: 198 occupied cells, 452 kills, 47×27 span;
  - `1424`: 186 occupied cells, 467 kills, 39×36 span;
  - `1420`: 1 cell, 1 kill.
- The replay reproduces the recorded 64-cell count, kill total, and span
  exactly. Subcell kills are distributed deterministically inside each 64-cell.
- Synthetic 256×256 kill clouds are rasterized at 64, 96, and 128.
- Sparse table bytes are measured with a SavedVariables-like serializer.
- Render/fixture cost is an offline envelope from H64-9:
  - ~0.0022 ms per active cell on first render;
  - ~3.0 KB fixture memory per active cell.
- Hotspot stability is measured by area-weighted downsample to 64 and top-10
  overlap. This is not a live frame claim.

## 2. Recorded real zones

### 1421 — Hillsbrad-shape

| Grid | Cells | Occupancy | Span | Span occ. | Median | Mean | 1-kill | Isolated | Top-10 share | →64 top-10 | Bytes | Render ms |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 64 | 198 | 4.83% | 47×27 | 15.6% | 2.0 | 2.28 | 42.9% | 1.5% | 23.9% | 10/10 | 1,774 | 0.4 |
| 96 | 270 | 2.93% | 69×41 | 9.5% | 1.0 | 1.67 | 60.7% | 7.0% | 15.3% | 7/10 | 2,434 | 0.6 |
| 128 | 331 | 2.02% | 93×53 | 6.7% | 1.0 | 1.37 | 78.2% | 11.2% | 13.3% | 10/10 | 2,983 | 0.7 |

### 1424 — near-square shape

| Grid | Cells | Occupancy | Span | Span occ. | Median | Mean | 1-kill | Isolated | Top-10 share | →64 top-10 | Bytes | Render ms |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 64 | 186 | 4.54% | 39×36 | 13.2% | 2.0 | 2.51 | 28.5% | 2.2% | 22.3% | 10/10 | 1,679 | 0.4 |
| 96 | 273 | 2.96% | 58×54 | 8.7% | 1.0 | 1.71 | 57.1% | 2.6% | 13.7% | 8/10 | 2,459 | 0.6 |
| 128 | 336 | 2.05% | 77×71 | 6.1% | 1.0 | 1.39 | 75.0% | 5.4% | 11.6% | 10/10 | 3,154 | 0.7 |

Cells, kills, and spans in the 64 columns match the recorded real values.
Singleton share, top-10 share, and cost are replay-derived. 96/128 are
aggregate-preserving replays: they add subcell detail without changing the
recorded 64-cell totals.

## 3. Synthetic profiles

| Profile | Grid | Cells | Occupancy | Span | Median | 1-kill | Isolated | Bytes | Render ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| sparse trail | 64 | 413 | 10.1% | 55×45 | 4.0 | 21.1% | 0.0% | 3,702 | 0.9 |
| | 96 | 716 | 7.8% | 82×68 | 3.0 | 28.9% | 0.4% | 6,458 | 1.6 |
| | 128 | 1,028 | 6.3% | 110×90 | 2.0 | 42.8% | 1.1% | 9,568 | 2.3 |
| medium roam | 64 | 1,482 | 36.2% | 64×52 | 6.0 | 14.6% | 0.7% | 13,710 | 3.3 |
| | 96 | 2,875 | 31.2% | 96×78 | 3.0 | 23.6% | 1.3% | 26,021 | 6.3 |
| | 128 | 4,288 | 26.2% | 128×104 | 2.0 | 32.9% | 1.7% | 39,941 | 9.4 |
| dense stress | 64 | 4,064 | 99.2% | 64×64 | 5.0 | 3.4% | 0.0% | 35,601 | 8.9 |
| | 96 | 8,176 | 88.7% | 96×96 | 2.0 | 27.8% | 0.0% | 72,622 | 18.0 |
| | 128 | 11,581 | 70.7% | 128×128 | 1.0 | 51.4% | 0.0% | 107,942 | 25.5 |
| wide band | 64 | 844 | 20.6% | 64×22 | 8.0 | 12.7% | 0.6% | 7,973 | 1.9 |
| | 96 | 1,671 | 18.1% | 96×32 | 4.0 | 21.6% | 0.7% | 15,239 | 3.7 |
| | 128 | 2,546 | 15.5% | 128×43 | 3.0 | 28.3% | 1.5% | 23,004 | 5.6 |
| tall band | 64 | 878 | 21.4% | 26×64 | 7.0 | 16.6% | 1.1% | 8,034 | 1.9 |
| | 96 | 1,689 | 18.3% | 39×96 | 4.0 | 20.1% | 1.5% | 15,221 | 3.7 |
| | 128 | 2,630 | 16.1% | 52×128 | 2.0 | 30.9% | 1.9% | 24,636 | 5.8 |
| irregular ring | 64 | 1,486 | 36.3% | 63×40 | 5.0 | 17.7% | 0.9% | 13,642 | 3.3 |
| | 96 | 2,776 | 30.1% | 93×59 | 3.0 | 28.2% | 1.1% | 25,006 | 6.1 |
| | 128 | 4,058 | 24.8% | 124×79 | 2.0 | 43.6% | 2.0% | 37,652 | 8.9 |
| few hotspots | 64 | 468 | 11.4% | 43×45 | 5.0 | 22.9% | 2.4% | 4,371 | 1.0 |
| | 96 | 857 | 9.3% | 64×68 | 3.0 | 28.0% | 2.3% | 7,882 | 1.9 |
| | 128 | 1,271 | 7.8% | 86×90 | 3.0 | 33.6% | 2.9% | 12,079 | 2.8 |

## 4. Findings

### 4.1 The real sample is sparse and already single-kill-heavy at 64

- Real occupancy is 4.5–4.8% of the grid.
- Mean kills per occupied cell is only 2.28–2.51.
- 29–43% of occupied 64-cells contain exactly one kill.
- The 64 grid is not saturated; it is already close to its useful resolution
  for this activity level.

### 4.2 128 mostly fragments cells

- At the recorded real shape, 128 raises occupied cells by 1.67–1.81×.
- 75–78% of those cells then contain a single kill; the median drops from 2 to
  1.
- Isolated-cell share rises from 1.5–2.2% to 5.4–11.2%.
- The extra cells are mostly singletons, not better-resolved hot regions.
- This is a best case: the replay spreads each 64-cell's kills uniformly. Real
  trails cluster inside a cell, so 128 would usually be even more
  singleton-heavy.

### 4.3 96 is the worst migration target

- 96 is not a power-of-two multiple of 64.
- Area-weighted 96→64 downsample preserves only 2–9 of the top-10 cells across
  profiles; the recorded real shapes preserve 7–8 of 10.
- 128→64 is exact: every profile preserves 10/10 because 128 nests under 64.
- If the durable grid ever changes, 96 would lose hotspot alignment during
  display, merge, or migration. It should not be a candidate.

### 4.4 Wide/tall shapes do not justify a rectangular durable grid

- Stored positions are normalized 0–1 on both axes. The heatmap record has no
  map aspect ratio or world dimensions.
- A rectangular durable grid would therefore be a guess, not aspect-aware
  geometry.
- Wide and tall profiles already occupy narrow bands (`64×22`, `26×64`) while
  span occupancy is 53–60%; the square grid tracks the band without wasting
  stored cells.
- An aspect-aware display can be considered later only if a reliable map
  dimension source is added; it does not require a durable grid change.

### 4.5 Cost growth is modest for the real shape but large under stress

- Real-shape 128 storage is ~1.7–1.9× the 64 table bytes for one zone:
  ~3.0–3.2 KB vs ~1.7 KB.
- Real-shape first-render envelope is ~0.7 ms vs ~0.4 ms for the selected zone.
- Dense stress is 2.85× cells, 3.03× bytes, and 2.86× render envelope.
- At the 6× SC-2 heatmap shape (18 zones, 2,310 cells at 64), 128 would still
  be a small absolute total (~38 KB vs ~22 KB). Storage is not the blocker;
  visual noise and migration risk are.

## 5. Cost/option table

| Option | Potential cells | Real-shape active | Real-shape bytes | Real-shape render | Nesting to 64 | Verdict |
|---|---:|---:|---:|---:|---|---|
| Square 64 | 4,096 | 186–198 | ~1.7 KB | ~0.4 ms | exact | **Keep.** |
| Square 96 | 9,216 | 270–273 | ~2.4–2.5 KB | ~0.6 ms | no; 2–9/10 top-10 | Reject. |
| Square 128 | 16,384 | 331–336 | ~3.0–3.2 KB | ~0.7 ms | exact 2× | Only with a future feature and live proof. |
| Rectangular durable | varies | same | same | same | migration-heavy | Reject; no aspect data. |
| Aspect-aware display | 64 durable | same | same | same | no change | Optional future display-only work. |
| Occupied mask | 64 durable | same | same | same | merge-heavy | Reject; empty cells are free. |

## 6. Recommendation for G-3

**Keep the durable 64×64 grid.**

- No 96×96 data grid.
- No 128×128 data grid now.
- No rectangular durable grid.
- No occupied mask.
- Keep sparse cells and lazy UI allocation.
- If a future cell-inspector feature needs more detail, add **per-cell top
  mobs/levels/instances at 64** before considering a finer grid.
- If a finer durable grid is ever justified, choose **128**, never 96, and gate
  it on a concrete feature plus live V-1/V-2 checks.

## 7. Limitations

- Raw real cells were unavailable in this session; real 96/128 columns are
  aggregate-preserving replays.
- Render and memory numbers are offline envelopes, not live frame times.
- One real character and three real zones.
- Synthetic profiles are deterministic but not a complete zone taxonomy.
- Uniform subcell replay is generous to higher resolutions.

## 8. Next

**G-3 — Grid decision.** See `docs/G-3-GRID-DECISION-RESULT.md`.

## Artifacts

- `tests/grid_occupancy.lua`
- `tests/run_all.sh`
- `docs/G-3-GRID-DECISION-RESULT.md`
- `docs/tasks/G-2-GRID-OCCUPANCY.md`
- `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md`
- `docs/DS-17-04B-DANGER-AND-XP-HOUR-RESULT.md`
- `docs/H64-9-F5-ASPECT-OCCUPANCY-RESULT.md`
