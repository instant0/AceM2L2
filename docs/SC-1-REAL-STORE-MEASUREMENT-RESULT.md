# SC-1 — Real-store measurement result

**Status:** executed 2026-11-16  
**Input:** `/mnt/r/AceM2L2.lua` (read-only)  
**Harness:** `tests/measure_real_store.lua`  
**Scope:** one real saved store; no writes, schema changes, or deletion.

## 1. Sample size

| Metric | Value |
|---|---:|
| Saved file bytes | 153,330 |
| Serialized root bytes | 122,313 |
| Serialized client bytes | 122,253 |
| Project | 18 (Forever) |
| Characters in sample | 1 |

The file has formatting overhead; the serialized client is the useful shape
measure.

**Important:** this sample has **no `journey` section**, so it predates the
Journey block storage. It measures the legacy/per-character store shape, not
block cold data.

## 2. Section share

| Section | Entries | Bytes | Share |
|---|---:|---:|---:|
| `mobs` | 158 | 86,119 | **70.4%** |
| `respawns` | 69 | 18,279 | **15.0%** |
| `quests` | 38 | 5,755 | 4.7% |
| `heatmaps` | 3 | 3,698 | 3.0% |
| `rates` | 38 | 3,114 | 2.5% |
| `deaths` | 16 | 1,381 | 1.1% |
| `levelHistory` | 11 | 1,300 | 1.1% |
| `instances` | 3 | 905 | 0.7% |
| `calibration` | 5 top-level | 442 | 0.4% |
| other | — | 1,260 | ~0.9% |

Mob records dominate. Respawns are the second-largest section. Heatmaps are
small in this sparse sample.

## 3. Mob shape

| Metric | Value |
|---|---:|
| Mobs | 158 |
| NPC-keyed | 100 |
| Name-only | 58 |
| Kills | 1,993 |
| Mob XP | 152,816 |
| Contexts | 1 |
| Max contexts/mob | 1 |
| Max zones/mob | 2 |
| Max kills/mob | 78 |
| Zone refs | 4 |
| Instance refs | 3 |

The sample is sparse and mostly one-zone. Contexts are negligible here, so this
sample does **not** validate context-heavy growth; DS-3B remains the stress
reference.

## 4. Non-mob shape

| Store | Value |
|---|---:|
| Quests | 38 |
| Quest gains | 38 |
| Quest XP | 77,455 |
| Deaths | 16 |
| Respawn NPCs | 69 |
| Respawn samples | 627 |
| Instances | 3 |
| Areas | 4 |
| Levels | 11 |
| Level history | 11 |
| Rate samples | 38 |

Respawn samples are numerous relative to NPC count, so interval arrays are the
section to watch after mobs.

## 5. Heatmap shape

| Map | Cells | Total kills | Grid occupancy | Span | Span occupancy |
|---|---:|---:|---:|---:|---:|
| 1420 | 1 | 1 | 0.02% | 1×1 | 100% |
| 1421 | 198 | 452 | 4.8% | 47×27 | 15.6% |
| 1424 | 186 | 467 | 4.5% | 39×36 | 13.2% |

- 3 zones, 385 cells, 920 heatmap kills.
- Max zone: 198 cells, 4.8% grid occupancy.
- Real occupied spans are near-square.
- Matches H64-9-F5: keep 64×64, no occupied mask now.

## 6. Calibration

| Bucket | Entries |
|---|---:|
| Zones | 2 |
| Levels | 2 |
| Groups | 0 |
| Classes | 1 |
| Mobs | 1 |

Calibration is small in this sample.

## 7. Real vs synthetic

| Dimension | Real sample | Synthetic stress |
|---|---|---|
| Mobs | 158 | 500–2,000 |
| Kills | 1,993 | 18k–32.5k |
| Heatmap zones | 3 | 40–200 |
| Heatmap cells | 385 | up to 163,840 |
| Dominant section | mobs 70% | mobs + contexts/cells |
| Block storage | absent | packed blocks |

The real sample confirms the mob-heavy shape, but is too small to prove the
worst-case limits. Synthetic profiles still drive scale decisions.

## 8. Implications

- Per-mob fields and names are the primary size driver.
- Respawn intervals are the next-largest section in this sample.
- Heatmap storage is cheap at real sparse occupancy; dense profiles remain
  stress-only.
- Context-heavy growth is not represented here; keep DS-3B context caps in the
  stress model.
- SC-2 should scale this shape at 2×/4×/6×; SC-3 can then choose the tier.
- G-2/G-3 should use H64-9-F5 plus SC-2, not this sample alone.

## 9. Limitations

- One character/client, one project.
- Pre-Journey sample; no blocks.
- Serializer is an approximation of SavedVariables syntax.
- Small sample; findings are observational, not general proof.

## 10. Next

**SC-2 — 2×/4×/6× benchmark.**

## Artifacts

- `tests/measure_real_store.lua`
- `docs/tasks/SC-1-REAL-STORE-MEASUREMENT.md`
