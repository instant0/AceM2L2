# DS-17.1 — Capacity math and storage strategy

**Status:** capacity calculation complete 2026-11-14  
**Consolidated research:** `docs/STORAGE-STRATEGY.md`  
**Purpose:** answer the actual storage question using 250 kills/level, zone and
instance counts, and the large-dataset tiers. This replaces the small real-store
baseline as the design target.

## What changed, and what did not

- The storage assumptions did **not** change: keep aggregate tables, 64×64
  cells, per-character raw history, small account aggregates, no per-kill log.
- DS-3's 10× result is real but small: 7,620 kills, 850 mobs, 20 zones,
  1,930 cells, 10 instances, 492,835 offline bytes. It is not a 15k–32.5k
  capacity proof.
- HC-5's 2,116,643-byte extreme figure is **truncated** at the estimator's
  200,000-entry limit. It is a lower bound, not a ceiling.
- The 250-kills/level and zone/instance tiers were already in DS-17.1, but they
  were not carried into the active DS-2/next-task sequence. DS-2 was a baseline
  detour. This document fixes that.

## Kill math

Assume 250 kills per level and 100 kills per instance record.

| Mode | Levels | Leveling kills | Instances | Instance kills | Total |
|---|---:|---:|---:|---:|---:|
| Forever 1–60 | 60 | 15,000 | 30 / 50 / 100 | 3,000 / 5,000 / 10,000 | 18,000 / 20,000 / 25,000 |
| Midnight 1–90 | 90 | 22,500 | 30 / 50 / 100 | 3,000 / 5,000 / 10,000 | 25,500 / 27,500 / 32,500 |

At 2,000 unique mobs, that is roughly **9–16 kills per tracked mob**, not a
per-kill event log. The 2,000-mob cap saturates before the 22,500-kill tier.

## Capacity tiers

Use tiers, not an exact content census:

| Dimension | Tier A | Tier B | Tier C |
|---|---:|---:|---:|
| Kills | 15,000 | 22,500 | 32,500 |
| Unique mobs | 500 | 1,000 | 2,000 cap |
| Open-world zones/areas | 40 | 100 | 200 |
| Instance records | 50 | 100 | 200 |
| Heatmap cells per zone | sparse real | 1,000 | 4,096 |
| Contexts per mob | 4 | 8 | 12 |
| Mob map/instance links | 2–4 | 4–8 | 8–20 |

PvP, arenas, scenarios, and delves are separate categories. Do not fold them
into open-world `areas`.

## Entry counts

At the worst hot tier (2,000 mobs, 40 zones, 4,096 cells, 12 contexts,
100 instances):

| Component | Entries |
|---|---:|
| Mobs | 2,000 |
| Level counters | up to 60/90 per mob, sparse in practice |
| `killsByMap` links | 2–8 per mob |
| `killsByAreaLevel` links | zones × levels per mob; must be capped/archived |
| Instance links | up to 20 per mob |
| Heatmap cells | 40 × 4,096 = **163,840** |
| Contexts | 2,000 × 12 = **24,000** |
| Instances | 100 records |

At 200 zones:

| Heatmap shape | Cells |
|---|---:|
| 200 × 1,000 | 200,000 |
| 200 × 4,096 | **819,200** |
| 200 × 256 (16×16) | 51,200 |

The current hot cap is 40 maps. 200 zones cannot be hot at full 64×64 without
either raising the cap or archiving/downsampling.

## Size estimate

This is a structural estimate, not a client file. It uses the diagnostics
constants and is calibrated against the DS-3 10× result; context cost is
approximate.

| Scenario | Mobs | Zones | Cells | Contexts | Instances | Hot estimate |
|---|---:|---:|---:|---:|---:|---:|
| Real sample | 85 | 2 | 193 | 0 | 1 | 70.7 KB actual |
| DS-3 10× | 850 | 20 | 1,930 | 0 | 10 | 492.8 KB offline |
| 2k / 40 zones dense / 4 contexts | 2,000 | 40 | 163,840 | 8,000 | 100 | **~6–8 MB** |
| 2k / 40 zones dense / 8 contexts | 2,000 | 40 | 163,840 | 16,000 | 100 | **~9–11 MB** |
| 2k / 40 zones dense / 12 contexts | 2,000 | 40 | 163,840 | 24,000 | 100 | **~11–14 MB** |
| 2k / 200 zones dense / 12 contexts | 2,000 | 200 | 819,200 | 24,000 | 200 | **~18–25 MB** |
| 2k / 200 zones 1k cells / 12 contexts | 2,000 | 200 | 200,000 | 24,000 | 200 | **~12–15 MB** |

Shape matters more than kill count:

- **Contexts** are the largest per-mob growth: 24,000 contexts is roughly
  8–9 MB by itself.
- **Heatmap cells** dominate at 200 dense zones: 819,200 cells is roughly
  14–15 MB at ~18 bytes per cell. The 40-zone dense tier is roughly 3 MB.
- **Mobs** at 2,000 are roughly 1.2 MB including their base fields.
- **Instances** are comparatively small: 100 records are roughly 0.2–0.3 MB.
- **Other capped stores** (quests, deaths, respawns, rates, level history) are
  roughly 0.1 MB in this model.
- 15,000 vs 32,500 kills is not the driver. The same 2,000 mobs and same
  contexts/cells are.

## Strategy

The current system is not massive-ready as a single hot tier. Keep the hot schema
for the bounded working set, but add the missing cold/archive tier and tighten the
dimensions that actually grow.

### 1. Hot per-character store

Target roughly **6–8 MB per active character**:

- 2,000 hot mobs;
- 40 hot heatmap zones at 64×64;
- 100 hot instance records;
- **4 contexts per mob by default**, 8 for active/recent, 12 only for the
  current band if measured;
- sparse cells only;
- cap per-mob zone/instance links;
- keep `areas`/`levels`/`areaLevels` as small derived caches.

### 2. Contexts

Contexts are not free calibration detail:

- default 4 per mob, not 12;
- collapse rare contexts into a mob/zone/class aggregate;
- keep 8–12 only for the active level band or recently seen mobs;
- archive or drop old contexts at a lifecycle boundary;
- measure the actual context size before raising the cap.

24,000 contexts is a large store for a feature that mostly needs expected XP,
not every historical combination.

### 3. Heatmap

- keep 40 hot zones at 64×64;
- normalize/render only the current/selected zone;
- downsample old zones to 32×32 or 16×16;
- pack cold zone blocks;
- do not raise the hot cap to 200 without a measured load/save budget;
- keep 200 zones as a cold/archive tier, not 200 hot dense grids.

### 4. Zones, areas, instances

- open-world areas: 40 hot, more cold/summary;
- instances: 100 hot records, more as summaries;
- PvP/arenas/scenarios: separate categories;
- one row per zone or instance in the Areas view; no double count;
- keep top-N mobs per zone/instance, not full per-mob detail for every zone.

### 5. Mobs

- 2,000 hot mobs;
- cap `killsByMap` and `killsByInstance` links per mob;
- keep full `killsByAreaLevel` only for hot/recent levels; aggregate or archive
  older combinations;
- when pruning a mob, retain its zone/level contribution in the summaries;
- do not duplicate a mob record per zone.

### 6. Cold archive

- per-character packed zone blocks;
- versioned, checksummed, with a plain fallback;
- no per-zone SavedVariables files;
- optional LoadOnDemand companion only if V-2 proves variable timing and the
  size/load win;
- Base64 only as a wrapper for binary blocks, not hot data;
- keep a previous backup before destructive compaction.

### 7. Account vs character

- `AceM2L2DB`: settings plus small bounded aggregate knowledge; loads for every
  character;
- `AceM2L2CharDB`: raw history, hot zones, contexts, archives; active character
  only;
- never copy another character's raw history into the account root;
- no per-zone SavedVariables files.

### 8. Lifecycle

- leveling vs endgame modes;
- archive old level bands;
- downsample old heatmaps;
- collapse old contexts;
- release archive buffers after save;
- endgame reputation/instance history separate from leveling detail.

## Verdict

- The current layout is **not massive-ready** as a single hot tier. It does not
  need a full rewrite, but it needs a cold/archive tier and per-zone retention.
- The global 2,000-mob / 40-zone / 100-instance caps are too small for the
  200-zone/200-instance tiers. Do not raise them blindly; replace them with
  per-zone/per-block retention plus cold archives.
- At 15k–32.5k kills with 2,000 mobs and 40 dense zones, expect **~11–14 MB per
  character** if 12 contexts and full 64×64 grids are kept. That is the real
  target, not the 70 KB real sample.
- At 200 zones/200 instances and 12 contexts, all-hot is **~18–25 MB**. Do not
  make that the default hot state.
- A **6–8 MB** active target is achievable with 4 contexts, 40 hot zones,
  100 hot instances, and cold/downsampled archives.
- The largest wins are context reduction and heatmap archive/downsampling, not a
  new hot table shape.
- The small real baseline is reference only. HC-5's truncated 2.1 MB is a lower
  bound, not a ceiling.

## Next work

1. DS-17.1: turn this into the feature-to-data matrix, cardinality table, and
   explicit 64×64 accept/reject decision.
2. DS-17.2: lifecycle/archive boundaries.
3. DS-17.3: context collapse and heatmap downsampling.
4. DS-7/DS-12: cold-block size and codec.
5. DS-15/DS-16: selected-zone retrieval, checkpoint policy.
