# IMP-1B4 — Block backup and save guard result

**Status:** save/guard slice executed 2026-11-16  
**Production modules:** `KillHistory/JourneyStorage.lua`,
`KillHistory/Events.lua`, `KillHistory/Module.lua`  
**Test:** `tests/journey_save_guard.lua`; `./tests/run_all.sh`  
**Scope:** block backup/restore and `SAVED_VARIABLES_TOO_LARGE` save-blocking.
Tooltip/UI retirement remains IMP-1B5.

## 1. Implemented

- `journey.blockBackup`:
  - previous block/index retained before a dirty rewrite;
  - one generation per zone.
- `RestoreJourneyBlocks()`:
  - restores backed-up blocks;
  - clears the decoded cache.
- `journey.saveBlocked`, `journey.oversizeSeen`, `journey.oversizeAt`.
- `OnSavedVariablesTooLarge`:
  - ignores other add-ons;
  - for `AceM2L2`, sets `saveBlocked`.
- `FlushJourneyBlocks()`:
  - refuses to write when `saveBlocked`;
  - returns `false, "save_blocked"`.
- `ResetJourneySaveBlock()` recovery hook.
- `GetJourneySaveState()` diagnostics.
- `SAVED_VARIABLES_TOO_LARGE` registered in the module event list.

## 2. Test result

`tests/journey_save_guard.lua` verifies:

- initial block build;
- dirty rewrite creates a backup;
- restored block returns the previous kills;
- foreign `SAVED_VARIABLES_TOO_LARGE` is ignored;
- AceM2L2 oversize blocks further writes;
- blocked flush does not overwrite the block;
- explicit reset resumes saving;
- resumed flush writes the new value.

Passing output:

```text
Journey save guard passed
```

`tests/run_all.sh` passes.

## 3. What remains

- Tooltip/UI still read legacy data.
- Legacy `db.mobs`/`areas`/`levels` still duplicate block data.
- Heatmaps/quests/deaths/respawns are not packed.
- Full retirement/switchover/rollback is not implemented.
- Backup retention/pruning policy is minimal (one generation per zone).
- No account Knowledge/merge.

## 4. Next

**IMP-1B5 — Tooltip/UI retirement and rollback.**

- Switch safe reads to Journey/block queries.
- Keep legacy fallback during migration.
- Define and test rollback.
- Remove duplication only after tests/backup.
- Preserve current behavior and smoke tests.
- No account Knowledge/UI redesign.

## Artifacts

- `KillHistory/JourneyStorage.lua`
- `KillHistory/Events.lua`
- `KillHistory/Module.lua`
- `tests/journey_save_guard.lua`
- `tests/run_all.sh`
- `docs/IMP-1B3-BLOCK-RETRIEVAL-RESULT.md`
