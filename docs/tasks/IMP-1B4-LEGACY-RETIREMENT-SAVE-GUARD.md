# IMP-1B4 — Legacy retirement and save/guard integration

**Status:** save/guard slice executed 2026-11-16; UI retirement in IMP-1B5  
**Result:** `docs/IMP-1B4-SAVE-GUARD-RESULT.md`  
**Harness:** `tests/journey_save_guard.lua`  
**Depends on:** IMP-1B3, DS-16, DS-14, DS-17.5  
**Blocks:** V-2, UI

## Why

Block-backed retrieval now works, but legacy storage is still authoritative for
the UI and blocks duplicate data. The next step is controlled retirement and
save/guard integration.

## Scope

- Switch tooltip/UI reads to Journey/block queries where safe.
- Keep a fallback to legacy during migration.
- Define migration/retirement order and rollback.
- Integrate dirty-block flush with:
  - backup/restore;
  - checksum;
  - `SAVED_VARIABLES_TOO_LARGE` guard;
  - downgrade safety.
- Remove legacy duplication only after tests/backup.
- Pack remaining Journey data only where measured beneficial.
- Preserve current behavior and smoke tests.
- No account Knowledge/merge, no UI redesign.

## Acceptance

- Tooltip/UI behavior remains green.
- No full decode at login.
- No full scan.
- No per-kill save.
- Legacy retirement has a rollback/backup plan.
- Oversize guard covers block writes.
- Duplication removal is measured and reversible.
- V-2 can verify live behavior.

## Not required

- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- live client test;
- route recommendation.
