# DS-17.1 — Capacity math and storage strategy

**Status:** capacity calculation complete 2026-11-14; validated by DS-3B
2026-11-15  
**Consolidated research:** `docs/STORAGE-STRATEGY.md`  
**Validation:** `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`  
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
| 2k / 40 zones dense / 4 contexts | 2,000 | 40 | 163,840 | 8,000 | 100 | not measured; expected lower |
| 2k / 40 zones dense / 8 contexts | 2,000 | 40 | 163,840 | 16,000 | 100 | not measured; expected lower |
| 2k / 40 zones dense / 12 contexts | 2,000 | 40 | 163,840 | 24,000 | 100 | **8.69 MB compact / 9.94 MB client estimate / 23 MB stable / 27–37 MB transient heap** |
| 2k / 200 zones dense / 12 contexts | 2,000 | 200 | 819,200 | 24,000 | 200 | not measured; old model 18–25 MB is an upper-bound guess |
| 2k / 200 zones 1k cells / 12 contexts | 2,000 | 200 | 200,000 | 24,000 | 200 | not measured; old model 12–15 MB is an upper-bound guess |

Shape matters more than kill count:

- The **actual 12-context profile** is 8.69 MB compact / 9.94 MB client
  estimate, so the old 11–14 MB file range was high.
- **Lua heap** is the real pressure: 27 MB after build/normalize and 37 MB after
  a fresh reload. The file-size target is not a heap target.
- Contexts remain a major contributor, but the earlier 8–9 MB context-only
  estimate was too high for this serializer.
- Heatmap cells still dominate at 200 dense zones; that tier is unmeasured.
- 15,000 vs 32,500 kills is not the driver. The same 2,000 mobs and same
  contexts/cells are.

## Strategy

The current system is not massive-ready as a single hot tier. Keep the hot schema
for the bounded working set, but add the missing cold/archive tier and tighten the
dimensions that actually grow.

### 1. Hot per-character store

There is **no fixed file-size or heap target**. Use a dynamic hot working set and
cold archives; the current 2,000/40/100 caps are implementation limits, not the
design.

- Store all mobs/zones/instances in per-zone/level blocks.
- Keep a dynamic hot cache based on measured memory and retrieval, not a
  hard-coded 40/100.
- Contexts are a tunable efficiency choice (4/8/12), not an arbitrary cap.
- Sparse cells only.
- Bound per-mob links by value, not a global count.
- Keep `areas`/`levels`/`areaLevels` as small derived caches.
- DS-3B measured 8.69 MB compact / 9.94 MB client estimate and 23 MB stable /
  27–37 MB transient for the current implementation profile. 23 MB stable is
  acceptable relative to ATT 51–65 MB.

### 2. Contexts

Contexts are not free calibration detail, but the 12 cap is not a design target:

- keep contexts that measurably improve XP/route estimates;
- collapse rare contexts into a mob/zone/class aggregate;
- keep recent/active-band contexts; archive stale ones;
- measure 4/8/12 variants and choose by retrieval value versus cost;
- do not hard-code a low cap just to save a few MB.

24,000 contexts is a real cost, but 23 MB stable is acceptable; the decision is
whether each context earns its keep, not a fixed number.

### 3. Heatmap

- current hot cache is 40 zones at 64×64; this is an implementation cache, not a
  content limit;
- normalize/render only the current/selected zone;
- downsample old zones to 32×32 or 16×16;
- pack cold zone blocks;
- store 200+ zones in the cold tier; do not discard them because of the 40-zone
  implementation cap;
- hot cache size is set by measured memory/retrieval, not an arbitrary number.

### 4. Zones, areas, instances

- open-world areas: all stored, dynamic hot/cold split; current 40-zone cache is
  not a limit;
- instances: all stored, dynamic hot/cold split; current 100-record cache is not
  a limit;
- PvP/arenas/scenarios: separate categories;
- one row per zone or instance in the Areas view; no double count;
- keep top-N mobs per zone/instance, not full per-mob detail for every zone.

### 5. Mobs

- all mobs are stored; the current 2,000 hot entry cap is an implementation cap,
  not a design limit;
- keep a dynamic hot/cold split; archive rare/old mob detail instead of dropping
  it;
- bound `killsByMap`/`killsByInstance` links by value, not an arbitrary number;
- keep full `killsByAreaLevel` for recent/hot levels; aggregate/archive older
  combinations;
- when moving a mob cold, retain its zone/level contribution in summaries;
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
- The actual 2k/40/12 profile is **8.69 MB compact / 9.94 MB client estimate** with
  **23 MB stable / 27–37 MB transient Lua heap**. There is no fixed MB target.
- At 200 zones/200 instances and 12 contexts, the old model said ~18–25 MB file;
  that tier is unmeasured. Do not make it the default hot state.
- Contexts are a measured trade-off, not a target: 4/8 variants may be worth
  testing for retrieval value, but do not impose an arbitrary MB cap.
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
