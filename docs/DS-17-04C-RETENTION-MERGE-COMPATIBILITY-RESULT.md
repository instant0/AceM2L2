# DS-17.4C — Retention and aggregation compatibility result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds17_4c_retention.lua`  
**Scope:** offline cold-retention prototype; no merge, no UI, no production code.

## 1. Context retention

Synthetic 10,000 mobs × 12 contexts. Contexts are stored as an **array** here,
not as a string-keyed map.

| Retention | Heap | Total kill coverage | Total XP coverage | Detail kill coverage | Detail XP coverage |
|---|---:|---:|---:|---:|---:|
| Full | 4.37 MB | 100% | 100% | 100% | 100% |
| Top 8 | 3.15 MB | 93.8% | 92.2% | 93.8% | 92.2% |
| Top 8 + `other` | 9.79 MB | **100%** | **100%** | 93.8% | 92.2% |
| Top 4 | 2.54 MB | 66.7% | 64.3% | 66.7% | 64.3% |
| Top 4 + `other` | 8.57 MB | **100%** | **100%** | 66.7% | 64.3% |

`other` is a single aggregate bucket containing the remaining contexts' kills,
deaths, XP, health lost, time-to-kill, and samples.

### Findings

- Top-4 loses too much detail.
- Top-8 preserves ~92–94% of detail.
- Adding `other` preserves **100% of totals** while keeping only top-8 detail.
- The `other` table is extra storage; a packed cold block should encode it as
  one record, not as a Lua table per mob.
- Danger verdict matched in this synthetic set, but that is not a general proof.

### Important schema finding

DS-17.4A stored contexts as a **string-keyed map** and measured 70.70 MB for
the same 10k×12 scale. This prototype stores them as an **array** and measures
4.37 MB. The keyed map's key strings and hash-table overhead are the difference.

**Recommendation:** use array/list context records for cold storage and
serialization. Use a keyed map only for hot/active context lookup.

## 2. Packed context retention

| Retention | Packed bytes | Packed MB | Encode | Checksum |
|---|---:|---:|---:|---:|
| Full | 1,902,843 | 1.81 | 719 ms | 74 ms |
| Top 8 + `other` | 1,500,004 | 1.43 | 575 ms | 59 ms |

- Corruption and truncation are detected.
- Packed top-8+other is smaller than the array table representation and preserves
  totals.
- The packed record is the right cold form; the table is the hot form.

## 3. Zone/level active-time preservation

Copying aggregate zone/level fields preserved:

```text
kills 1,800 -> 1,800
XP 380,000 -> 380,000
activeSeconds 13,800 -> 13,800
deaths 7 -> 7
```

This is the minimum requirement for best-zone XP/hour after retention.

## 4. Heatmap retention

Synthetic 64×64 grids at sparse and dense profiles:

| Density | Occupied | Total | 32 cells | 16 cells | Top10 overlap 32 | Top10 overlap 16 |
|---:|---:|---:|---:|---:|---:|---:|
| 0.5% | 20 | 210 | 20 | 20 | 10/10 | 10/10 |
| 3% | 122 | 1,265 | 119 | 109 | 9/10 | 5/10 |
| 5% | 204 | 2,114 | 192 | 154 | 3/10 | 3/10 |
| 15% (stress) | 614 | 6,419 | 521 | 244 | 1/10 | 2/10 |
| 30% (stress) | 1,228 | 12,854 | 858 | 256 | 2/10 | 2/10 |

Totals are preserved at every density, but **top-hotspot overlap degrades** as
density rises. The local sample is ~4.5–4.8%, where the earlier test showed
6/10–9/10 overlap. This is not enough data to promise a general rule.

### Decision

- Keep 64×64 hot.
- Downsample to 32/16 cold **plus** keep a top-N hotspot list and total/summary.
- Do not rely on downsampled cells alone to preserve the best spot.
- Treat 0.5–5% as normal; 15–30% as stress.
- Real-zone hotspot tests are still required; the local sample is too small.

## 5. Aggregation compatibility

A cold aggregate rebuilt from mob records preserved:

```text
kills 1,410,000 / 1,410,000
XP 79,728,800 / 79,728,800
```

This confirms the cold data still contains the additive inputs needed for future
account Knowledge. No merge was implemented.

## 6. Findings

1. **Cold context must be an array/list, not a string-keyed map.** Keyed maps are
   much larger at this scale.
2. **Top-8 + `other` is the best current retention shape.** It preserves total
   kills/XP/danger inputs while keeping top-8 detail.
3. **Top-4 loses too much detail** (about one third of kills/XP coverage).
4. **Packed top-8+other is compact** (1.43 MB at 10k×12) and detects
   corruption/truncation.
5. **Zone/level active time and totals survive a cold copy**, so XP/hour remains
   computable.
6. **64×64 zones are sparse.** 0.5–5% is normal; 15–30% is stress.
7. **Downsampling preserves totals but can lose the top hotspot.** Keep a top-N
   summary with the downsampled grid.
8. **Cold data still supports future aggregation.**
9. **No merge/UI/production code.**
10. **The local sample is too small for general heatmap conclusions.**

## 7. Decision

Adopt for schema/retention input:

- Hot: array/list contexts; recent/full detail; keyed map only for lookup.
- Warm/cold: top-8 contexts + `other` aggregate; packed records.
- Preserve zone/level/instance XP, active time, kills, deaths, samples.
- Heatmap: 64×64 hot; 32/16 cold plus top-N hotspot summary.
- Keep totals and confidence inputs; never drop aggregation totals.
- No per-kill log.
- No merge implementation.
- No account-wide writes yet.

## 8. Required follow-ups

- **DS-17.5** — schema fields and migration for array contexts, top-8+other,
  active time, heatmap top-N.
- **DS-15** — retrieval using packed top-8+other and top-N hotspots.
- **V-2** — real active time, death attribution/health/buffs/group, cell
  XP/time, and real-zone heatmap density.
- **DS-17.4D** — account Knowledge prototype later.
- **DS-11** — final decision.

## Acceptance

- Cold context alternatives measured: **yes**.
- Kill/XP/danger coverage measured: **yes**.
- Active time/totals preserved: **yes**.
- Sparse and dense heatmap retention measured: **yes**.
- Future aggregation inputs preserved: **yes**.
- Corruption/truncation detection: **yes**.
- No merge/UI/production code: **yes**.
- No online source: **yes**.

## Artifacts

- `tests/ds17_4c_retention.lua`
- `tests/ds17_4a_model.lua`
- `tests/ds17_4b_queries.lua`
- `docs/DATA-MODEL-PLAN.md`
- `docs/DATA-MODEL-AND-TEST-MATRIX.md`
