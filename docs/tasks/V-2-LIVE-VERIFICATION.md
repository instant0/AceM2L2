# V-2 — Live-only residual verification

**Status:** deferred; narrow live-environment checks only  
**Depends on:** IMP-1B12; DS-17.7 for field scope  
**Blocks:** final rollback retirement only if live results change behavior  
**Related:** `docs/NON-LIVE-BACKLOG.md`

## Post-DS-17.6A correction

DS-17.6A found that several V-2 fields are not implemented in production
(death attribution/health, heatmap cell XP/time, durable per-zone time, etc.).
V-2 cannot validate a field that does not exist.

Split V-2 into:

- **V-2A** — API/field availability probes; no implementation dependency.
- **V-2B** — validation after the relevant migration slice lands.
- **V-2C** — save/load/oversize/companion validation.
- **V-2D** — visual/frame checks.

DS-17.7 defines the field list and which V-2 part applies.

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
