# DS-16 — Save/checkpoint policy

**Status:** executed 2026-11-16  
**Result:** `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`  
**Harness:** `tests/ds16_save_policy.lua`  
**Depends on:** DS-5, DS-7/DS-12, DS-17.5, DS-14, DS-16 inputs  
**Blocks:** DS-11, V-2

## Why

The richer Journey and future account Knowledge must not be saved per kill, and
must survive logout/reload, migration, and oversize failures.

## Scope

- Define checkpoint triggers:
  - session end;
  - logout/reload;
  - `C_AddOns.SaveAddOns`;
  - periodic/level/zone change if needed;
  - migration/compression.
- No per-kill disk write.
- Character Journey writes:
  - hot updates in memory;
  - cold block re-encode only for dirty blocks;
  - checksum during encode;
  - previous backup.
- Account Knowledge:
  - not written until ALT feature;
  - when added, write only after merge/checkpoint, not per kill.
- `SAVED_VARIABLES_TOO_LARGE`:
  - treat as load failure;
  - stop normal saving;
  - keep backup;
  - compaction/reset recovery.
- Migration/backup/downgrade.
- Save/reload and size tests.

## Acceptance

- No per-kill save.
- Dirty-block/incremental cold save is defined.
- Backup/restore path is defined.
- Account vs character write timing is explicit.
- Oversize recovery is defined.
- DS-11 can use the policy.
- V-2 can verify the assumptions.

## Not required

- implementing the entire schema;
- merge implementation;
- UI;
- live client test.
