# DS-17.10 — S2A migration simulation result

**Status:** simulation passed 2026-11-18  
**Harness:** `tests/s2a_migration_sim.lua`  
**Scope:** offline migration/parity proof only. No production writer changed.

## What it does

1. Builds a legacy `db.mobs` snapshot.
2. Migrates it into v2-shaped `journey.mobs`.
3. Serializes the v2 table to a new file.
4. Loads the file back.
5. Removes legacy `db.mobs`.
6. Reads mob data through `JourneyModel:GetModelMob`.
7. Compares v2 against the original legacy snapshot.

## What it proves

- Migration is idempotent.
- The v2 file round-trips without data changes.
- Kills and XP match.
- `byPlayerLevel` matches.
- `byZone` and `byInstance` match.
- V2-only reads work with legacy removed.
- Name-only and NPC-keyed mobs survive.
- No double counting.

## Output

```text
S2A migration simulation passed
v2_file=/tmp/...-s2a-v2.lua
```

`./tests/run_all.sh` passes.

## What it does not prove

- The production writer has not switched to v2.
- No on-load backfill is wired.
- Legacy compatibility projection is not implemented.
- Fallback removal is not implemented.
- Block payload/retirement is not touched.

## Gate

Production S2A work must keep the simulation green before and after the writer
switch. This simulation is a prerequisite, not a replacement for production
migration.

## Artifacts

- `tests/s2a_migration_sim.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-10-S2A-MOB-MODEL-MIGRATION.md`
