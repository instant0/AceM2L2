# DS-17.4B — Danger, best-zone XP/hour, and heatmap prototype result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds17_4b_queries.lua`  
**Local source:** `/mnt/r/AceM2L2.lua` (heatmaps only; danger/zone examples are synthetic)  
**Scope:** offline query prototype; no production code, no online source.

## 1. Danger by combat context

Synthetic combat contexts are used because the local save has no death-to-mob
attribution, health, buffs, or group context.

| Context | Kills | Deaths | Death rate | 95% Wilson | Confidence | Verdict |
|---|---:|---:|---:|---|---|---|
| Solo healthy normal | 400 | 4 | 1.0% | 0.4–2.5% | high | safe/slaughter |
| Solo low health | 60 | 30 | 33.3% | 24.5–43.6% | medium | dangerous |
| Group healthy normal | 200 | 2 | 1.0% | 0.3–3.5% | high | safe/slaughter |
| Elite low health | 30 | 15 | 33.3% | 21.4–47.9% | medium | dangerous |
| Sparse observation | 2 | 0 | 0% | 0–65.8% | low | not enough data |

### Findings

- Wilson bounds plus sample count prevent “0 deaths in 2 fights” from looking
  safe.
- Health/group context changes the danger verdict.
- Quest state is excluded.
- The local save cannot support real danger output yet: it lacks killer/mob
  attribution, health, buffs, and group on death records.
- Real danger data needs V-2 verification.

## 2. Best zone by XP/hour

Synthetic zones at level 20 and 30:

| Rank | Zone | XP/hour | Kills/hour | Active time | Sessions | Confidence |
|---:|---|---:|---:|---:|---:|---|
| 1 | Zone E | 480,000 | 600 | 600 s | 1 | **low** |
| 2 | Zone C | 200,000 | 720 | 900 s | 2 | **low** |
| 3 | Zone A | 100,000 | 500 | 3,600 s | 4 | medium |
| 4 | Zone B | 100,000 | 450 | 7,200 s | 6 | high |
| 5 | Zone D | 50,000 | 300 | 36,000 s | 12 | high |

At level 30:

| Rank | Zone | XP/hour | Kills/hour | Active time | Sessions | Confidence |
|---:|---|---:|---:|---:|---:|---|
| 1 | Zone F | 150,000 | 600 | 7,200 s | 5 | high |

### Findings

- Raw kills/hour does **not** rank zones the same as XP/hour.
- Zone E and C have the highest raw XP/hour but low confidence; they should not
  be presented as “best” without more time/samples.
- Zone B ties Zone A on XP/hour but has more active time and higher confidence.
- The local save cannot compute real best-zone XP/hour because it lacks durable
  per-zone/level active time.

## 3. Heatmap hotspots

Actual local heatmaps:

| Map | Grid | Occupied cells | Occupancy | Top 1 | Top 5 | Top 10 |
|---|---:|---:|---:|---:|---:|---:|
| 1421 | 64 | 198 | **4.83%** | 7.1% | 16.4% | 23.2% |
| 1424 | 64 | 186 | **4.54%** | 4.1% | 13.9% | 23.1% |
| 1420 | 64 | 1 | 0.02% | 100% | 100% | 100% |

Downsampling top-10 hotspot overlap:

| Map | 64→32 | 64→16 |
|---|---:|---:|
| 1421 | 6/10 | 9/10 |
| 1424 | 9/10 | 10/10 |
| 1420 | 1/10 | 1/10 |

### Findings

- **64×64 zones are sparse, not saturated.** The local sample is ~4.5–4.8%
  occupied, not 4,096 filled cells.
- The top 10 cells hold ~23% of kills in the two real zones; the rest are
  diffuse.
- Downsampling preserves the main hotspot in this tiny sample, but the sample is
  too small to conclude a general top-cell rule.
- The local cells store counts only; “best cell by XP/hour” needs per-cell
  XP/time.
- 15% density in earlier heatmap tests is a stress profile, not a realistic
  default. 0.5–5% should be the normal profile; 15–30% remains stress.

## 4. Decisions

- Danger output should be context-based with Wilson bounds and confidence.
  Sparse data must say “not enough data.”
- Best zone must rank by XP/hour with active time and confidence; low-sample
  high-XP/hour zones must not be presented as authoritative.
- Heatmap tests must include sparse profiles first; dense profiles are stress
  only.
- No design decision should use the tiny local dataset as proof of long-term
  distributions. It is a sanity sample.
- The local save still needs V-2 data/API verification for danger and XP/hour.

## 5. Required follow-ups

- **DS-17.4C** — retention/aggregation compatibility: top-8/packed contexts,
  active-time preservation, heatmap downsampling, cold archive quality.
- **V-2** — verify killer attribution, health/buffs/group on death, per-zone
  active time, cell XP/time.
- **DS-17.5** — schema fields for the above.
- **DS-15** — retrieval queries after schema.

## Acceptance

- Danger prototype: **yes** (synthetic).
- Best-zone XP/hour prototype: **yes** (synthetic).
- Heatmap sparse occupancy measured: **yes** (local).
- Top-cell downsampling measured: **yes**, but sample-limited.
- Quest state excluded: **yes**.
- No per-kill log: **yes**.
- No merge/UI/production code: **yes**.
- No online source: **yes**.

## Artifacts

- `tests/ds17_4b_queries.lua`
- `tests/ds17_4a_model.lua`
- `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`
- `docs/DATA-MODEL-PLAN.md`
