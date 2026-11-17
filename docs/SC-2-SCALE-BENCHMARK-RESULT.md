# SC-2 — 2×/4×/6× benchmark result

**Status:** executed 2026-11-17  
**Input shape:** SC-1 real store (`/mnt/r/AceM2L2.lua`)  
**Harness:** `tests/bench_real_scale.lua`  
**Scope:** offline scaled shape; no saved-store edit, cap change, or schema change.

## 1. Method

SC-1’s real per-character store was cloned at 1×/2×/4×/6×:

- mobs and kills scale together;
- quests, deaths, respawns, heatmaps, instances, rates, and level history scale
  proportionally;
- small aggregate maps/levels/calibration are held constant;
- the serializer is the same read-only table serializer used by SC-1;
- production caps are **not** applied to the benchmark shape; cap interactions
  are identified separately.

## 2. Growth table

| Factor | Kills | Mobs | Quests | Deaths | Respawns | Heatmap zones | Cells | Client bytes |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1× | 1,993 | 158 | 38 | 16 | 69 | 3 | 385 | 122,253 |
| 2× | 3,986 | 316 | 76 | 32 | 138 | 6 | 770 | 244,453 |
| 4× | 7,972 | 632 | 152 | 64 | 276 | 12 | 1,540 | 487,268 |
| 6× | 11,958 | 948 | 228 | 96 | 414 | 18 | 2,310 | 730,107 |

Growth is close to linear:

- 2×: **2.00×** bytes;
- 4×: **3.99×** bytes;
- 6×: **5.97×** bytes.

Even the 6× shape is only ~0.73 MB serialized. Runtime/block storage is separate.

## 3. Section growth

| Section | 1× | 2× | 4× | 6× | 6× share |
|---|---:|---:|---:|---:|---:|
| Mobs | 86,119 | 173,060 | 346,118 | 519,176 | **71.1%** |
| Respawns | 18,279 | 36,826 | 73,650 | 110,474 | **15.1%** |
| Quests | 5,755 | 12,028 | 24,054 | 36,080 | 4.9% |
| Heatmaps | 3,698 | 7,406 | 14,810 | 22,214 | 3.0% |
| Other | 2,471 | 3,859 | 6,635 | 9,412 | 1.3% |

Mob and respawn shares remain stable. Heatmaps remain a small share at the real
sparse occupancy.

## 4. Cap interaction

Current relevant caps:

| Store | Cap | 6× shape | Result |
|---|---:|---:|---|
| Mobs | 2,000 min / 12,000 hard | 948 | within |
| Quests | 200 old / adaptive now | 228 | within adaptive |
| Deaths | 100 | 96 | within |
| Respawn NPCs | 300 old / 4,000 now | 414 | within new cap |
| Heatmap zones | 40 | 18 | within |
| Contexts/mob | 12 | 1 in this sample | within |

- 2× and 4× fit the old caps in this shape.
- 6× exceeded the old quest and respawn caps.
- SC-3 accepted 6× and replaced those with adaptive/higher limits.
- This sample has almost no contexts, so context growth remains a synthetic
  stress concern, not a real-shape proof.

## 5. Cold blocks

The sample has no Journey blocks. DS-7 codec envelopes remain the cold reference:

| Profile | Packed cold |
|---|---:|
| 100k mobs, 4 contexts | 3.90 MB |
| 100k mobs, 8 contexts | 6.54 MB |
| 100k mobs, 12 contexts | 9.19 MB |
| 350k mobs, 4 contexts, split blocks | 13.22 MB |

At 948 mobs, cold data is far below those envelopes; contexts remain the
dominant cold variable.

## 6. Implications

- Real-shape growth through 6× is still small in serialized bytes.
- Mobs remain the dominant store.
- Quests and respawns were the old caps that collided at 6×; SC-3 replaced them.
- Heatmaps are not the growth problem at real occupancy.
- Context-heavy stress still comes from DS-3B/DS-7, not this sample.
- SC-3 accepted **6×** with selective changes:
  - adaptive quest limit by visited zones;
  - respawn cap 500.
  See `docs/SC-3-TIER-DECISION-RESULT.md`.
- Do not raise every cap by the same factor.

## 7. Limitations

- One real character, no Journey blocks, almost no contexts.
- Synthetic cloning preserves per-entry shape but not future class/route
  diversity.
- Serialized bytes are not client memory.
- Production cap trimming is not applied in the benchmark, only identified.

## 8. Next

**SC-3 — Choose a tier.**

## Artifacts

- `tests/bench_real_scale.lua`
- `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md`
- `docs/tasks/SC-2-SCALE-BENCHMARK.md`
