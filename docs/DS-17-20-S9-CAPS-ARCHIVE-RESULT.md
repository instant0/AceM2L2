# DS-17.20 — S9 adaptive caps, retention, and archive policy result

**Status:** executed 2026-11-18  
**Scope:** retention profiles, block tiers, 32/16 heatmap summaries, cold context
collapse, compaction, and diagnostics.  
**Test:** `tests/s9_caps_archive.lua`; full suite passes.

## 1. Retention profiles

Explicit per-character profiles:

| Profile | Hot | Warm | Cold |
|---|---|---|---|
| 3m | ≤30 days | ≤90 days | older |
| 6m | ≤90 days | ≤180 days | older |
| 12m | ≤180 days | ≤365 days | older |

`journey.retentionProfile` defaults to `6m`. The current map/instance is always
hot. No player-facing cap controls were added.

## 2. Heatmap summaries

`journey.heatmapSummaries[map]` now stores:

- durable source grid 64 and source total;
- warm 32×32 cells/total;
- cold 16×16 cells/total;
- last seen.

The 64×64 `journey.heatmaps` source is unchanged. Downsampling sums source kills
into target cells, so 32/16 totals match the durable total and cannot
double-count.

## 3. Block movement and context collapse

- `blockIndex[zone].tier` and `block.tier` record hot/warm/cold.
- `contextMode` records `full` or `collapsed`.
- Hot blocks keep the full owned context array.
- Warm/cold blocks keep top-8 plus `other`, with sample counts and min/max range
  preserved.
- Tier changes mark the zone dirty so the next flush rewrites the payload.
- Blocks still use schema 3 and decode through the S8 path.

## 4. Compaction and diagnostics

- `CompactJourneyBlocks` removes invalid blocks and orphan indexes, and rebuilds
  missing indexes for valid blocks.
- `GetRetentionStats` reports profile, tier counts, block count, measured block
  bytes, summary count, and summary cell count.
- `GetDataStats().retention` exposes the same data.
- Diagnostics displays hot/warm/cold block counts and measured block bytes.

## 5. Caps

No blanket cap or MB limit was introduced. Existing adaptive mob/quest caps and
hard ceilings remain. Generation-file archives and archive deletion remain out
of this slice.

## 6. Tests

- 64→32→16 total and cell parity;
- source cells unchanged;
- 3/6/12-month profile thresholds;
- current-zone hot override;
- hot/warm/cold tier transitions and dirty marking;
- cold context collapse and hot full-context round-trip;
- compaction of invalid blocks/orphan indexes;
- diagnostics stats;
- no archive double counting;
- no blanket cap/grid change.

Passing output:

```text
S9 caps/archive passed
...
All offline checks passed.
```

## 7. Limits

- Per-generation archive files and delete flows remain future work.
- Legacy retirement remains S10.
- Live save/load/oversize validation remains V-2C.

## 8. Next

**DS-17.21 — S10 legacy retirement**, live-gated by V-2.

## Artifacts

- `KillHistory/Archive.lua`
- `KillHistory/JourneyStorage.lua`
- `KillHistory/Data.lua`
- `KillHistory/Events.lua`
- `KillHistory/UI/Diagnostics.lua`
- `AceM2L2.toc`
- `tests/s9_caps_archive.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-20-S9-CAPS-ARCHIVE.md`
