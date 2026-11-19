# Next task

## V-2 live evidence run

**Status:** live-only; required before S10C-2  
**Task document:** `docs/tasks/V-2-LIVE-VERIFICATION.md`  
**Depends on:** a live client and `/acem2l2 xpt v2probe`

### Run

1. `/acem2l2 xpt v2probe` and capture the output/evidence.
2. V-2B: verify implemented capture under real combat.
3. V-2C: verify save/load, oversize, and companion behavior.
4. V-2D: verify heatmap/window visuals.
5. Record results in `docs/V-2-LIVE-VERIFICATION-RESULT.md`.

### Then

**DS-17.23 S10C-2** removes dual writes, normalizers, fallbacks, quest-ledger
dependency, and rollback insurance.

### Not required

- account Knowledge/ALT production writes;
- route recommendations;
- new storage-format study.
