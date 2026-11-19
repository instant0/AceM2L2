# Next task

## V-2 live residual verification

**Status:** live-only; required before S10C-2  
**Task document:** `docs/tasks/V-2-LIVE-VERIFICATION.md`  
**Synthetic result:** `docs/V-2-SYNTHETIC-VERIFICATION-RESULT.md`

### Already covered synthetically

- V-2A probe shape and field flags;
- timing/XP split;
- death position with unavailable attribution/health;
- heatmap kills with unavailable cell XP/time;
- context shape;
- schema 3 block round-trip;
- save guard and backup/restore;
- heat ramp monotonicity.

### Remaining live-only checks

1. Real combat event ordering and killer attribution.
2. Actual health/buff/group/rested values under combat.
3. Real SavedVariables timing and oversize behavior.
4. Midnight secret-value behavior in combat/tooltips.
5. LoadOnDemand companion timing if enabled.
6. Actual heatmap/window frame appearance.

### Then

**DS-17.23 S10C-2** removes dual writes, normalizers, fallbacks,
quest-ledger dependency, and rollback insurance.
