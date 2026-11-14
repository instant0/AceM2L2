# DS-2 — Real-store baseline

**Status:** executed 2026-11-14; baseline captured  
**Purpose:** record the small real store as a reference, plus projection
anchors. This is **not** the massive-scale design target; use
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md` for that. No new storage test was
required.

## Inputs

- `docs/DS-3-STORAGE-SANITY-RESULT.md`
- `docs/HC-5-DIAGNOSTICS-BASELINE.md`
- `docs/tasks/MEM-1-MEMORY-BUDGET.md`
- `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`
- `docs/tasks/DS-17-01-AGGREGATION-AND-GRID.md`

The original `/mnt/r` samples may no longer be present. The recorded DS-3 and
HC-5 measurements are sufficient; do not block on re-reading the files.

## Real baseline

Source: `/mnt/r/AceM2L2.lua` as recorded by HC-5 and DS-3.

| Field | Value |
|---|---:|
| Client file bytes | 70,661 |
| Diagnostic estimate | 82,614 |
| Estimate / actual | 1.169 |
| Offline reserialized bytes | 61,783 |
| Mobs | 85 |
| Kills | 762 |
| Open-world kills | 617 |
| Instance kills | 145 |
| Heatmap zones / cells | 2 / 193 |
| Instances | 1 |
| Level records | 6 |
| Contexts | 0 |
| Rate samples | 0 |
| Calibration entries | 0 |
| Total tracked entries | 156 |

The 61,783-byte reserialized file is the compact offline serializer, not the
client baseline. Use **70,661 client bytes** when comparing with real
SavedVariables.

Memory samples are separate from file size:

| Sample | Kills / mobs | Addon memory | Heatmap |
|---|---:|---:|---|
| Hunter | 389 / 25 | 3.2 MB | closed |
| Priest | 762 / 85 | 3.85 MB | Silverpine, 408 kills |

The 389-kill sample has no SavedVariables file. Do not treat its memory figure as
a file-size baseline.

## Ratios supported by the save

| Ratio | Value | Note |
|---|---:|---|
| Unique mobs per kill | 85 / 762 = 0.1115 | Upper-bound planning ratio; discovery saturates. |
| Kills per unique mob | 762 / 85 = 8.96 | Same caveat. |
| Instance share | 145 / 762 = 19.0% | Kills, not instance-record count. |
| Heatmap cells per tracked zone | 193 / 2 = 96.5 | Sparse real sample; not a per-zone average. |
| Contexts per mob | 0 real / 12 cap | Use 0, 4, 8, 12 as planning tiers. |

**Kills/hour is not in the save.** Do not present it as measured. If time is
shown, label it as an assumption and keep storage size separate.

## Projection anchors

Use measured anchors before linear guesses:

| Case | Kills | Mobs | Instances | Zones | Cells | Contexts | Bytes |
|---|---:|---:|---:|---:|---:|---:|---:|
| Real | 762 | 85 | 1 | 2 | 193 | 0 | 70,661 client |
| DS-3 10× | 7,620 | 850 | 10 | 20 | 1,930 | 0 | 492,835 offline |
| HC-5 moderate estimate | — | 100 | 100 | 5 | 20,480 | 1,000 | 1,116,453 |
| HC-5 extreme (truncated lower bound) | — | 2,000 | 100 | 40 | 163,840 | 24,000 | 2,116,643* |

The HC-5 estimates are structural estimates, not actual files. The extreme
profile is truncated by the 200,000-entry estimator cap, so `2,116,643` is a
lower bound. For 15k–32.5k planning use
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`.

## Projection tiers

Kill and mob projections use the measured ratios:

```text
unique_mobs_upper = min(2000, kills × (85 / 762))
instance_kills = kills × (145 / 762)
open_world_kills = kills - instance_kills
```

Unique mobs is a distinct identity count, not an additional kill bucket.
Instance + open-world kills sum to the kill tier.

| Kills | Unique mobs (upper bound) | Instance kills | Open-world kills |
|---:|---:|---:|---:|
| 1,000 | 112 | 190 | 810 |
| 10,000 | 1,115 | 1,903 | 8,097 |
| 22,500 | 2,000 cap | 4,281 | 18,219 |

Zones, cells, instance records, and contexts are **scenario dimensions**, not
linear functions of kills:

- zones: 2 (real), 10, 40 (current cap);
- cells per zone: sparse real, 1,000, 4,096 (per-zone cap);
- contexts per mob: 0, 4, 8, 12 (per-mob cap);
- instances: 1 (real), 10, 100 (record cap).

Do not invent a single bytes-per-kill multiplier. A single projected byte count
waits for DS-17.1 to choose the shape. The anchors bracket the range: 70.7 KB
for the real 85-mob store, 492.8 KB for 850 mobs/20 zones/1,930 cells, and
2.1 MB truncated lower bound for the extreme 2,000-mob/40-zone/163,840-cell/
24,000-context case. Shape matters more than kill count.

## Growth drivers and caps

- **Heatmap cells:** largest synthetic contributor; keep sparse. The 40-zone
  hot cap is a small/medium limit, not the massive design; archive/downsample
  older zones.
- **Contexts:** next largest. The 12-per-mob cap is an upper bound, not a target;
  massive data needs 4–8 contexts plus collapse/archive.
- **Mobs:** the 2,000 cap is a small/medium limit; massive data needs per-zone
  retention and cold summaries.
- **Instances:** the 100-record cap is a small/medium limit; more instances belong
  in summaries/cold archives.
- **Key text:** ~21.6 KB of the 70.7 KB real file; lazy optional fields and
  numeric keys help, but do not force a key migration just for size.
- **Quests/deaths/respawns/rates:** separately capped; not derivable from mob
  counts.

## Scope

- Account `AceM2L2DB`: settings plus small bounded aggregate knowledge; loads for
  every character.
- Per-character `AceM2L2CharDB`: raw active-character history; loads only for
  the active character.
- No per-zone SavedVariables files.
- Static metadata belongs outside the character save.

## Result

Executed 2026-11-14.

- Real baseline captured: **70,661 client bytes**, 85 mobs, 762 kills, 617
  open-world / 145 instance, 2 heatmap zones / 193 cells, 1 instance.
- Diagnostic estimate: **82,614 bytes** (+16.9%); offline compact reserialize:
  61,783 bytes.
- 10× anchor: **492,835 offline bytes**, 850 mobs, 7,620 kills, 20 zones,
  1,930 cells, 10 instances.
- HC-5 extreme anchor: **2,116,643 estimated bytes, but truncated** at the
  estimator's 200,000-entry limit. Treat it as a lower bound, not a ceiling.
  The capacity model in `docs/DS-17-1-CAPACITY-AND-STRATEGY.md` supersedes it for
  15k–32.5k planning.
- Projection ratios: 0.1115 unique mobs/kill, 8.96 kills/unique mob, 19.0%
  instance share. The 2,000-mob cap is reached at about 17,900 kills, so the
  22,500-kill row is capped, not linear.
- No measured kills/hour exists. Time remains an assumption, not a baseline.
- Growth is shape-driven: heatmap cells and contexts dominate synthetic growth;
  the real store is far below its caps.

## Output

`docs/DS-2-REAL-STORE-BASELINE.md` is this document. The baseline and projection
tables above are the executable result.

## Acceptance

- Real file bytes, estimate, counts, and memory samples are recorded.
- Ratios are limited to what the save supports.
- Kills/hour is not presented as measured.
- Projections use measured anchors and label scenario dimensions.
- Growth drivers and caps are named.
- No new storage test, schema change, or code change is required.

## Not required

- long-lived multi-zone save;
- exact WoW content census;
- new storage tests;
- new schema;
- repeating DS-3 or DS-5;
- full external-corpus analysis;
- claiming measured kills/hour.
