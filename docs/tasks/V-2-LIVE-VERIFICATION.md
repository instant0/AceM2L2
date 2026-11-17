# V-2 — Live-only residual verification

**Status:** deferred; narrow live-environment checks only  
**Depends on:** IMP-1B12  
**Blocks:** final rollback retirement only if live results change behavior  
**Related:** `docs/NON-LIVE-BACKLOG.md`

## Why this is narrow

Most of the behavior is already proven offline or measured from the real saved
store. Re-proving code paths live would duplicate work and delay non-live tasks.

## Already established offline

Do **not** repeat these as live acceptance items:

| Fact | Evidence |
|---|---|
| Block encode/decode, checksum, corruption fallback | `tests/journey_storage.lua`, `tests/ds7_codec.lua` |
| Schema 1 read / schema 2 write compatibility | `tests/journey_storage.lua` |
| Lazy decode, selected-zone reads, cache hits | `journey_storage`, `heatmap_bounded` |
| Save guard, backup/restore, blocked flush | `tests/journey_save_guard.lua` |
| Reset clears Journey/blocks/index | `tests/areas_levels_parity.lua` |
| Mob index/list/Overview/commands parity | `journey_index`, `list_overview_index`, `commands_index` |
| Areas/Levels and summary parity | `areas_levels_parity`, `area_level_summaries` |
| Selected-zone heatmap bounded reads | `heatmap_bounded` |
| Client profiles, interface branches, secret-value guards | smoke matrix for Forever/Midnight |
| SavedVariables structure/migration | smoke, storage-sanity, real-store baseline |
| Real-store size/shape | `docs/DS-2`, `docs/HC-5-DIAGNOSTICS-BASELINE.md` |
| Block codec/performance envelopes | `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md` |

## Live-only residual

Only verify facts that depend on the actual game environment:

1. Real combat event ordering and killer attribution.
2. Actual API values for health, buffs, group size, and rested XP under combat.
3. Presence/engaged timing under real event sequences.
4. Heatmap cell XP/time capture under real kills.
5. Actual SavedVariables write/load timing and size after a real session.
6. Actual `SAVED_VARIABLES_TOO_LARGE` behavior on the target client.
7. Midnight secret-value behavior during real combat/tooltips.
8. LoadOnDemand companion load timing, if the companion is enabled.
9. Visual/frame behavior of the heatmap and main window on the target client.

Everything else is covered by offline tests, smoke scenarios, or prior
measurements.

## Output

- Short live verification record with only the items above.
- Any environment-specific fix.
- Go/no-go for removing rollout flags.

## Not required

- Re-testing codec, cache, parity, save-guard logic, or reset logic live.
- Account Knowledge/merge.
- UI redesign.
