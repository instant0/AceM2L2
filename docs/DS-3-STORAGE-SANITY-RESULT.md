# DS-3 — Storage sanity result

**Status:** executed 2026-11-14  
**Verdict:** current layout is sane for the small/medium store; this is **not**
a massive-scale decision. See `docs/DS-17-1-CAPACITY-AND-STRATEGY.md`.

## Scope

Two checks only:

1. save/reload correctness;
2. load/save cost on the real sample and a simple 10× synthetic copy.

Known gaps were not retested:

- name-only tooltip lookup scans all mobs;
- heatmap normalization iterates every stored zone;
- account-wide alt knowledge is not implemented.

## Inputs

- Real save: `/mnt/r/AceM2L2.lua` — 70,661 bytes, 762 kills, 85 mobs,
  2 heatmap zones, 193 cells, 1 instance, 145 instance kills.
- The 389-kill / 25-mob figure is a memory sample, not a SavedVariables file.
  It is not used for storage timings.
- Synthetic 10×: clone mobs, instance records, and heatmap zones; keep quests,
  deaths, respawns, rates, and level history unchanged.
  - 85 → 850 mobs
  - 1 → 10 instances
  - 2 → 20 heatmap zones
  - 193 → 1,930 heatmap cells

No long-lived multi-zone save exists; none was required.

## Results

| Case | Source bytes | Saved bytes | Load source | Normalize | Save | Reload |
|---|---:|---:|---:|---:|---:|---:|
| Real sample | 70,661 | 61,783 | 1.96 ms | 0.95 ms | 5.34 ms | 2.13 ms |
| 10× synthetic | built in memory | 492,835 | — | — | 51.18 ms | 12.34 ms |

`Save` = serialize + write. `Reload` = parse + `EnsureDB`. Timings are offline
Lua timings, not WoW client benchmarks. The serializer is ours.

### Correctness

| Check | Real | 10× |
|---|---:|---:|
| Mobs | 85 | 850 |
| Total kills | 762 | 7,620 |
| Open-world kills | 617 | 6,170 |
| Instance kills | 145 | 1,450 |
| Total XP | 39,358 | 393,580 |
| Heatmap zones / cells | 2 / 193 | 20 / 1,930 |
| Instances / kills | 1 / 145 | 10 / 1,450 |
| Snapshot after reload | identical | identical |
| Fresh-process reload | pass | pass |
| Aggregate invariants | pass | pass |
| Empty/missing store | no invented data | no invented data |

Invariants checked:

- `totals.kills` = sum of mob kills.
- `totals.xp` = sum of mob XP.
- `totals.uniqueMobs` = mob count.
- `levels` = total kills (open world + instances).
- `areas` = open-world kills.
- `areaLevels` = open-world area/level kills.
- `instances[*].kills` = sum of mob instance kills.
- `instances[*].killsAtLevel` = sum of mob instance/level kills.
- open-world kills + instance kills = total kills.
- instance kills are not counted again in `areas`.
- loading an empty store creates no false totals or entries.

### Size estimate

| Case | Saved bytes | Diagnostic estimate | Ratio |
|---|---:|---:|---:|
| Real | 61,783 | 82,614 | 1.337 |
| 10× | 492,835 | 684,682 | 1.389 |

The diagnostic estimator is conservative by about 34–39% on this serializer,
consistent with HC-5's +16.9% result on the client-formatted file.

The reserialized real sample is 61,783 bytes versus the client file's 70,661
bytes. The difference is serializer formatting, not lost data: the canonical
snapshot is identical before and after reload.

## Interpretation

- No pathological growth: 10× data still reloads in about 12 ms and saves in
  about 51 ms with the offline serializer.
- The real sample loads and normalizes in about 3 ms total offline.
- The current nested-table layout is not the problem. The known costs are the
  name-only scan and all-zone heatmap normalization, not the file shape.
- 10× mobs, instances, and heatmap zones preserve all checked totals and
  invariants after save/reload.
- Keep the current layout for the small/medium store. This does not make it
  massive-ready; DS-4P is required for the hybrid hot/cold design.

## Caveats

- Offline Lua serializer and parser, not the WoW client's C serializer/parser.
  Compare relative results, not absolute client performance.
- The 10× copy does not scale quests, deaths, respawns, rates, or level history;
  it specifically scales the mob, instance, and heatmap payloads.
- The 389-kill / 25-mob sample has no saved file, so it is not a storage input.
- The timing table uses a same-process reload after clearing `module.char` and
  the heatmap cache. Both saved files were also loaded and checked in fresh Lua
  processes; totals, attribution, areas, levels, heatmap zones, and cells
  matched.

## Artifacts

- Harness: `tests/storage_sanity.lua`
- Real output: `/tmp/opencode/acem2l2-storage-sanity-1x.lua`
- 10× output: `/tmp/opencode/acem2l2-storage-sanity-10x.lua`

Run:

```sh
lua tests/storage_sanity.lua /mnt/r/AceM2L2.lua 1 /tmp/opencode/acem2l2-storage-sanity-1x.lua
lua tests/storage_sanity.lua /mnt/r/AceM2L2.lua 10 /tmp/opencode/acem2l2-storage-sanity-10x.lua
```

## Decision

The current layout is sane for the small/medium store: 762 kills, 85 mobs,
2 zones, 193 cells, 1 instance, and a 10× synthetic at 492,835 bytes. It does
not prove massive-scale capacity.

Massive-scale storage needs the hybrid hot/cold strategy in
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`: bounded hot index, packed cold
zone/level blocks, indexes, static metadata, and per-zone retention. DS-4P is
required to prototype that hybrid.

Next: DS-17.1 feature-to-data and 64×64 decision, then DS-17.2/DS-17.3 and the
cold-block prototype.
