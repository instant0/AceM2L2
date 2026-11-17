# H64-9-F5 — Aspect ratio and occupied-mask result

**Status:** executed 2026-11-16  
**Test/benchmark:** `tests/bench_heatmap.lua`; real saved-store sample  
**Scope:** measurement and recommendation only. No grid, schema, or UI change.

## 1. Synthetic profiles

| Scenario | Shape | Active | Empty | Grid occupancy | First render | Fixture memory |
|---|---|---:|---:|---:|---:|---:|
| `dense_square_1` | square | 4,096 | 0 | 100% | ~7.6 ms | ~19.8 MB |
| `dense_wide_1` | wide | 1,024 | 3,072 | 25% | ~2.5 ms | ~7.7 MB |
| `dense_tall_1` | tall | 1,024 | 3,072 | 25% | ~2.3 ms | ~8.0 MB |
| `dense_irregular_1` | irregular | 1,400 | 2,696 | 34% | ~3.2 ms | ~9.2 MB |
| `medium_square_1` | square | 1,000 | 3,096 | 24% | ~2.2 ms | ~7.7 MB |

Empty cells cost no storage, and the UI creates cells lazily only for active
indices. Wide/tall profiles are cheaper to render than dense square profiles,
not slower.

## 2. Real saved-store sample

| Map | Cells | Grid occupancy | Bounding span | Span occupancy |
|---|---:|---:|---:|---:|
| `1420` | 1 | 0.02% | 1×1 | 100% |
| `1421` | 198 | 4.8% | 47×27 | 15.6% |
| `1424` | 186 | 4.5% | 39×36 | 13.2% |

The real sample is sparse, but its occupied spans are near-square. It does not
demonstrate a consistent wide/tall zone geometry that would justify a durable
rectangular grid.

## 3. Evaluation

### Occupied mask
Not justified now:

- empty cells already cost zero storage;
- lazy UI allocation already avoids textures for empty indices;
- a mask adds a second representation and merge/downsample complexity;
- current real spans are near-square.

### Rectangular grid
Not justified now:

- would change durable cell indexing and migration;
- would complicate block cells, downsampling, merge, and UI mapping;
- no real evidence of consistent extreme-aspect zones;
- benefit is display/resolution only, not storage.

### 96×96 / 128×128
Remains rejected:

- 2.25×/4× cells;
- roughly proportional dense render/rescale work;
- no storage or visual evidence to justify it.

## 4. Recommendation

- **Keep the durable 64×64 grid.**
- Do **not** add an occupied mask or rectangular durable grid now.
- Collect more real zone/aspect samples before G-2/G-3.
- If future real data shows consistent extreme aspect or poor effective
  resolution, evaluate a **display-only** rectangular mapping/downsample or
  occupied mask first; do not change stored indexing.
- Feed this result to G-2/G-3.

## 5. Next

**SC-1 — Real-store measurement.**

## Artifacts

- `tests/bench_heatmap.lua`
- `docs/H64-9-BENCHMARK-REPORT.md`
- `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`
- `docs/tasks/H64-9-05-FOLLOWUP-WORK.md`
