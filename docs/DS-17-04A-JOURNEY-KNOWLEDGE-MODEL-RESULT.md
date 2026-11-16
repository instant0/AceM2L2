# DS-17.4A — Journey/Knowledge model validation result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds17_4a_model.lua`  
**Local source:** `/mnt/r/AceM2L2.lua` (one character, project 18)  
**Scope:** offline model validation; no production code, no online source.

## 1. Local Journey inventory

Observed local character:

| Item | Value |
|---|---:|
| Mobs | 158 |
| Areas/map aggregates | 4 |
| Instances | 3 |
| Level aggregates | 11 |
| Deaths | 16 |
| Quests | 38 |
| Heatmap cells | 385 |
| Heatmap cell type | number |

### Fields present

Mob records have:

- `name`, `npcID` (100/158), `classification`;
- `kills`, `totalXP`, `sessionKills`, `sessionXP`, `sessionXPKnown`;
- `killsAtLevel`, `killsByMap`, `killsByAreaLevel`,
  `killsByInstance`, `killsByInstanceLevel`;
- `contexts` (only **1 mob** has any context; 1 context entry total);
- `firstSeen`, `lastSeen`;
- `xp` samples.

Context fields present in that one entry:

- `playerLevel`, `mobLevel`, `buffSig`, `groupSize`, `classification`,
  `mapID`, `samples`, `sumBase`, `sumBuffed`, `sumTotal`, `minBase`, `maxBase`,
  `lastSeen`.

### Fields missing

| Missing field | Needed for |
|---|---|
| `activeSeconds` per zone/level/instance | Best-zone XP/hour |
| Explicit combat context (`combat`) | Danger tooltip |
| Explicit XP context (`xpContexts`) | Expected XP by context |
| Death `mobKey`/`npcID` | Mob-attributed danger |
| Death health/health band | “Same circumstances” danger |
| Death buffs/group/classification/difficulty | Comparable danger context |
| Heatmap cell XP/time | Best heatmap part by XP/hour |
| Per-zone/level time | XP/hour, active time |
| Durable session/zone time | XP/hour |

The local `deaths` records contain only `mapID`, `at`, `x`, `y`. They cannot
support a mob danger tooltip by themselves.

The local heatmap cells are numeric counts only. They support density ranking,
not XP/hour ranking.

## 2. Context cardinality and retention

Synthetic profile: **10,000 mobs × 12 observed contexts**, skewed so a small
common set dominates. This is a stress profile, not a real-game distribution.

| Context set | Entries kept | Kill coverage | XP coverage | Lua heap |
|---|---:|---:|---:|---:|
| Full 12 contexts | 120,000 | 100% | 100% | **70.70 MB** |
| Top 8 | 80,000 | 93.8% | 92.3% | **45.34 MB** |
| Top 4 | 40,000 | 66.7% | 64.3% | **23.06 MB** |
| Top 12 deep copy | 120,000 | 100% | 100% | 68.23 MB |

### Finding

- Full context tables are too large to keep for every mob at scale.
- Top-4 loses about one third of kills/XP coverage in this synthetic profile.
- Top-8 retains about 94% of kills and 92% of XP.
- Top-12 is full coverage but expensive.

**Recommendation:** keep full/recent contexts hot; keep **top-8 or packed
context records** in warm/cold. Top-4 is only acceptable for a compact summary,
not for danger/XP analysis. A packed-context test is required before choosing
the exact cold rule.

DS-17.4C later showed the representation matters: the same 10k×12 contexts
stored as an **array/list** measured 4.37 MB instead of 70.70 MB as a
string-keyed map. The keyed-map overhead is the difference. Use array/list
contexts for cold storage; keyed maps only for hot lookup.

The real local sample has only one context entry, so it cannot validate the
distribution. This synthetic test establishes the size/coverage trade-off, not
the real top-N threshold.

## 3. Schema shape

Metadata records at 10k/100k entries, 1–4 zone refs, fixed level range:

| Entries | Nested records | Parallel arrays | Packed metadata | Nested lookup 10k | Parallel lookup 10k |
|---:|---:|---:|---:|---:|---:|
| 10k | 3.48 MB | 3.25 MB | 0.44 MB | 4.2–7.7 ms | 6.3–11.0 ms |
| 100k | 33.75 MB | 26.00 MB | 4.45 MB | 57–65 ms | 79–84 ms |

### Finding

- Parallel arrays are ~20–23% smaller than nested metadata records.
- Packed metadata is ~87% smaller than nested records at 100k.
- Direct lookup is fast in both hot representations.
- Packed cold blocks remain the right large-scale representation (DS-7/DS-12).

**Recommendation:**

- hot/active: nested or parallel arrays, whichever keeps code simpler;
- cold/large: packed blocks;
- do not store full context tables inside every cold mob record.

## 4. Heatmap downsampling

### Actual local occupancy

| Map | Occupied | Occupancy |
|---|---:|---:|
| 1421 | 198 / 4,096 | **4.83%** |
| 1424 | 186 / 4,096 | **4.54%** |
| 1420 | 1 / 4,096 | 0.02% |

**64×64 zones are sparse, not saturated.** The local sample is ~4.5–4.8%
occupied. A full 64×64 zone is not the normal case.

### Downsampling stress profile

A 15% density profile (614 cells) is a **stress test**, not the default:

| From | To | Cells | Total preserved |
|---:|---:|---:|---|
| 64 | 32 | 428 | 6,419 / 6,419 |
| 64 | 16 | 256 | 6,419 / 6,419 |

Total counts are preserved by downsampling, but spatial detail is lost. This
supports keeping 64×64 hot and downsampling to 32/16 cold, with a summary/top-N
for cell detail. Use 0.5–5% occupancy as the normal profile; 15–30% is only a
stress profile.

## 5. Account Knowledge mapping

The Journey fields map as:

| Journey | Account Knowledge |
|---|---|
| `mobs` identity/name/level/classification/zones | `knowledge.mobs` static metadata |
| `mobs.combat` | `knowledge.mobs.danger` |
| `mobs.xpContexts` | `knowledge.mobs.xp` |
| `zones` XP/kills/active time/deaths | `knowledge.zones` by level band |
| `instances` | `knowledge.instances` |
| `heatmaps` cells | `knowledge.heatmaps` by zone/level band |
| `quests` | `knowledge.quests` |
| `respawns` | `knowledge.mobs.respawn` |
| `deaths` | danger aggregates; not raw coordinates |
| character identity/session timeline/raw kills | excluded |

No merge is implemented.

## 6. Findings

1. **The Journey schema is directionally correct but incomplete.** It has mob,
   zone, instance, level, heatmap, death, quest, and respawn data, but lacks
   active time, combat/XP contexts, death attribution/health/buffs/group, and
   per-cell XP/time.
2. **Full context tables are not viable at scale.** 10k mobs × 12 contexts is
   ~70 MB. Top-8 ~45 MB, top-4 ~23 MB. Cold must use top-N or packed contexts.
3. **Top-4 is not enough for danger/XP analysis.** It loses ~33–36% coverage in
   the synthetic profile. Top-8 is the safer compact starting point.
4. **Packed metadata is far smaller.** 100k metadata records: 33.75 MB nested,
   26.00 MB parallel, 4.45 MB packed.
5. **Heatmap downsampling preserves totals, but zones are sparse.** Local
   64×64 occupancy is 4.5–4.8%, not saturated. Keep 64×64 hot; 32/16 cold with
   summaries; use 0.5–5% as the normal profile and 15–30% only as stress.
6. **Local data cannot prove danger.** Deaths have no mob attribution or
   circumstances; this requires a V-2/API check.
7. **Best zone XP/hour is not computable yet.** There is no durable per-zone/
   level active time.
8. **Quest state is correctly excluded.** The model keeps quest records
   separate.
9. **No merge needed now.** The Journey schema can be aggregated later.
10. **No online source used.** No production code changed.

## 7. Decision

Keep the Journey/Knowledge split and revise the Journey schema:

- keep all mob/zone/instance/level records; do not shrink to current caps;
- add `activeSeconds` per zone/level/instance;
- add combat contexts with health/buffs/group/classification/difficulty;
- add XP contexts with group/rested/buffs/classification;
- keep full/recent contexts hot; top-8 or packed contexts in warm/cold;
- add death `mobKey`/`npcID`, health, buffs, group, classification, difficulty;
- add heatmap cell XP/time if best-part is XP/hour;
- keep quest records separate;
- keep account Knowledge as a derived target only;
- use packed blocks for cold metadata/context records;
- use nested/parallel arrays only for hot/active data.

## 8. Required follow-up tests

- packed context encoding and cold top-N quality (DS-17.4B/C);
- danger rate with context buckets and confidence (DS-17.4B);
- best-zone XP/hour with active time (DS-17.4B);
- heatmap top-cell quality after downsampling (DS-17.4B/C);
- death attribution/health/buff/group availability (V-2);
- per-zone/level active time capture (V-2);
- retention preserving aggregation inputs (DS-17.4C);
- account Knowledge derivation prototype (DS-17.4D, future).

## 9. Acceptance

- Local Journey inventory: **yes**.
- Context cardinality/top-N trade-off: **yes**, synthetic.
- Schema shape comparison: **yes**.
- Heatmap downsampling totals: **yes**.
- Account Knowledge mapping: **yes**.
- Danger/best-zone query prototypes: **moved to DS-17.4B**.
- Retention compatibility: **moved to DS-17.4C**.
- No online source: **yes**.
- No production code: **yes**.

## Artifacts

- `tests/ds17_4a_model.lua`
- `docs/DATA-MODEL-PLAN.md`
- `docs/DATA-MODEL-AND-TEST-MATRIX.md`
- `docs/tasks/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL.md`
