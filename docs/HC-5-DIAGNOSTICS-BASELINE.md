# HC-5 — Offline diagnostics baseline

**Status:** completed offline review  
**Method:** replay SavedVariables through `GetDataStats()` with the offline
fixtures; compare the estimate with the actual file size. No live client used.

## Real captured store

Source: `/mnt/r/AceM2L2.lua` (Forever client 18).

| Field | Value |
|---|---:|
| Actual file bytes | 70,661 |
| Estimated bytes | 82,614 |
| Estimate / actual | **1.169** (+16.9%) |
| Estimate truncated | No |
| Mobs | 85 |
| Contexts | 0 |
| Heatmap zones / cells | 2 / 193 |
| Estimated heatmap bytes | 3,698 |
| Instances / instance kills | 1 / 145 |
| Level records | 6 |
| Rate samples | 0 |
| Calibration entries | 0 |
| Total tracked entries | 156 |

The estimator is conservative: it reports about 17% more than the serialized
file. That is acceptable for a size warning, but it must not be presented as an
exact SavedVariables file size.

## Synthetic profiles

### Moderate profile (not truncated)

100 mobs × 12 contexts, 5 heatmap zones × 4,096 cells, 100 instances, 200
quests, 100 deaths, 300 respawns × 20 intervals.

| Field | Value |
|---|---:|
| Estimated bytes | 1,116,453 |
| Estimate truncated | No |
| Contexts | 1,000 |
| Heatmap cells | 20,480 |
| Instances | 100 |
| Total tracked entries | 805 |

### Extreme profile (truncated)

2,000 mobs × 12 contexts, 40 heatmap zones × 4,096 cells, 100 instances, plus
the other caps.

| Field | Value |
|---|---:|
| Estimated bytes | 2,116,643 |
| Estimate truncated | **Yes** |
| Contexts | 24,000 |
| Heatmap cells | 163,840 |
| Instances | 100 |
| Total tracked entries | 2,000+ |

The estimator's bounded traversal (`ESTIMATE_ENTRY_LIMIT = 200,000`) is reached
on the extreme profile. The diagnostics panel already appends `(partial)`.
The estimate remains useful as a lower-bound safety signal but is not a full
byte count.

## Findings

1. **Real-store accuracy is acceptable but conservative.** The estimate is
   +16.9% versus the serialized file. Keep the approximate wording.
2. **`totalTracked` previously omitted instances.** Fixed: it now includes
   `stats.instances`, so the real baseline is 156, not 155.
3. **Large stores hit the estimator cap.** The extreme profile reports a partial
   2.1 MB estimate. This is expected and labeled. Do not raise the cap without
   measuring login/UI cost; use table counts and DS-3 scaling instead.
4. **Heatmap cells dominate synthetic growth.** 40 × 4,096 cells is the largest
   single contributor. This reinforces keeping heatmap collection opt-out and
   the 40-zone cap.
5. **The estimator counts structure, not serialized text.** It includes keys,
   nested tables, and contexts, so it is a safety estimate rather than a
   file-size API.
6. **Real caps are far below limits:** 85/2,000 mobs, 2/40 heatmap zones,
   1/100 instances. No pruning pressure in this sample.

## Reproducible helper

```sh
lua tests/measure_diagnostics.lua forever /mnt/r/AceM2L2.lua
```

The helper prints actual bytes, estimated bytes, ratio, truncation, and the
per-store counts. It is a diagnostic utility, not part of `run_all.sh`.

## Follow-up

- `SC-1` and `DS-2` should reuse this baseline and add long-lived/zone-heavy
  characters.
- `DS-3` should use the moderate and extreme shapes for the 1x/2x/4x/6x matrix.
- Live SavedVariables comparison remains in `V-2`.
