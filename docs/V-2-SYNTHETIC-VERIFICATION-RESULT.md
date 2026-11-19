# V-2 synthetic verification result

**Status:** executed 2026-11-18  
**Scope:** simulated V-2A/B/C/D logic using the Lua fixtures and API stubs.  
**Test:** `tests/v2_synthetic_verification.lua`; full suite passes.

## 1. What simulation proves

- V-2A probe shape and unimplemented-field flags.
- Event-driven presence/engaged timing under synthetic event order.
- Kill/quest XP splitting.
- Death position capture with attribution/health remaining unavailable.
- Heatmap kill capture with cell XP/time remaining unavailable.
- Context array/combat/XP/top-8 shape.
- Schema 3 block round-trip.
- Save guard blocked/recovered behavior.
- Block backup/restore.
- Heat ramp monotonicity.
- Retirement remains blocked after simulation.

## 2. What simulation cannot prove

These remain live-only:

- real combat event ordering and killer attribution;
- actual health/buff/group/rested API values under combat;
- real SavedVariables write timing/limits;
- actual `SAVED_VARIABLES_TOO_LARGE` behavior;
- Midnight secret-value behavior during real combat/tooltips;
- LoadOnDemand companion timing;
- actual frame appearance and rendering.

## 3. Output

```text
V-2 synthetic verification
v2a_probe=pass (synthetic API matrix)
v2b_presence_engaged=pass (200/130 seconds)
v2b_xp_split=pass (kill/quest)
v2b_death_attribution=unavailable
v2b_death_health=unavailable
v2b_heatmap_cell_xp=unavailable
v2b_heatmap_cell_time=unavailable
v2b_heatmap_kills=pass (64x64 sparse)
v2b_context_shape=pass (combat/XP/top8)
v2c_block_roundtrip=pass (schema 3)
v2c_save_guard=pass (blocked/recovered)
v2c_backup_restore=pass (previous block)
v2d_heat_ramp=pass (monotonic data)
v2d_frame_appearance=live-only
v2c_real_savedvariables_timing=live-only
v2b_real_event_order=live-only
retirement_gate=blocked
```

## 4. Decision

Synthetic verification increases confidence in the Lua logic but does **not**
unlock S10C-2 or create live evidence. The live V-2B/C/D residual remains the
gate.

## Artifacts

- `tests/v2_synthetic_verification.lua`
- `tests/run_all.sh`
