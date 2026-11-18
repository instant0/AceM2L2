# DS-17.10 — S2A mob model migration result

**Status:** executed 2026-11-18; kill/backfill path complete.  
**Limit:** merge/delete/prune mutation parity is split into DS-17.11.  
**Tests:** `tests/s1_model_helpers.lua`, `tests/s2a_migration_sim.lua`, full suite.

## 1. What changed

### V2 mob owner

`journey.mobs` is now populated and read as the v2 mob model:

- identity: `npcID`, name, classification;
- counts: kills, XP;
- mob level: min/max/samples;
- `byPlayerLevel`;
- `byZone[map].kills/playerLevels`;
- `byInstance[key].kills/playerLevels`;
- first/last seen.

### Migration

`JourneyModel:EnsureModelMobs` migrates `db.mobs` into `journey.mobs` once:

- idempotent;
- legacy is the backfill input, not a permanent read fallback;
- `journey.mobsMigrated` marks completion.

### New kills

`Tracking.RecordKill` calls `JourneyModel:RecordModelMobKill`:

- increments v2 kills/XP;
- updates player-level, zone, instance, and mob-level data;
- legacy `db.mobs` remains a compatibility projection for current readers.

### Reads

`JourneyModel:GetModelMob` is now **v2-only**:

- no legacy fallback;
- if `db.mobs` is removed, v2 reads still work;
- missing v2 returns `nil, "missing"`.

## 2. Tests

`tests/s2a_migration_sim.lua` now covers both directions:

- actual old-model `RecordKill` records are produced;
- v2 state is cleared;
- migration backfills from the actual legacy records;
- v2 is serialized to a new file, reloaded, and compared;
- legacy `db.mobs` is removed and reads still use v2;
- idempotence and parity for kills/XP/player-level/zone/instance;
- name-only mobs survive.

`tests/s1_model_helpers.lua` remains green with `GetModelMob` returning
`source = "v2"`.

## 3. What works

- old model -> migration -> v2 file -> v2-only read;
- new kill -> v2 update;
- migration idempotence;
- NPC-keyed and name-only identity;
- no v2 fallback to legacy.

## 4. What remains

Mutation paths that can change legacy mob data without a kill are not yet synced
to v2:

- `MergeMobEntries` name/NPC resolution;
- `DeleteMobEntry` / unknown-entry cleanup;
- prune/trim caps;
- any load-time normalization that removes/merges mobs.

Until DS-17.11, v2 can drift from legacy after those mutations.

Also unchanged:

- contexts remain keyed maps (S2B);
- block payload remains legacy-projected (S8);
- UI/commands still read legacy (by design);
- no legacy retirement.

## 5. Next

**DS-17.11 — S2A mutation parity and cleanup.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/Tracking.lua`
- `tests/s1_model_helpers.lua`
- `tests/s2a_migration_sim.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-10-S2A-MOB-MODEL-MIGRATION.md`
