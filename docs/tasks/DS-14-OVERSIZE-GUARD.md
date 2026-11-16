# DS-14 — Constant-table and oversize guard

**Status:** executed 2026-11-16  
**Result:** `docs/DS-14-OVERSIZE-GUARD-RESULT.md`  
**Harness:** `tests/ds14_oversize_guard.lua`  
**Depends on:** DS-5, DS-7/DS-12, DS-16, DS-17.5  
**Blocks:** DS-11, V-2

## Why

The Journey can be large and packed. The addon needs explicit guards for:

- Lua constant-table limits in generated/packed code;
- `SAVED_VARIABLES_TOO_LARGE` as a load failure;
- stopping normal saves after failure;
- preserving a previous backup;
- explicit compaction/reset recovery.

This is implementation of the DS-16 policy, not another storage study.

## Scope

- Detect/avoid oversized generated Lua constants.
- Keep packed blocks below the constant limit; split where needed.
- Handle `SAVED_VARIABLES_TOO_LARGE`:
  - set save-blocked state;
  - stop normal saving;
  - keep previous generation;
  - user-visible diagnostics;
  - compaction/reset path.
- Backup/restore hooks.
- Downgrade/unknown-schema read-only behavior.
- Tests:
  - normal save;
  - forced oversize state;
  - backup restore;
  - compaction;
  - downgrade guard.
- V-2 checks for actual client behavior.

## Acceptance

- Oversize is treated as a load failure.
- No silent overwrite after failure.
- Previous backup is restorable.
- Compaction/reset is explicit.
- Constant-table limits are respected.
- No UI redesign required.
- No online source required.
