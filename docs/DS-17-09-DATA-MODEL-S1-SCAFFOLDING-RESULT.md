# DS-17.9 — S1 data-model scaffolding result

**Status:** executed 2026-11-18  
**Scope:** read-only owner/parity helpers. No canonical-store switch, no writes,
no schema migration.  
**Test:** `tests/s1_model_helpers.lua`; `./tests/run_all.sh` passes.

## 1. Added

New module:

- `KillHistory/JourneyModel.lua` (loaded after `JourneyQueries.lua`).

Helpers:

- `GetModelMob(mobKey)`
- `GetModelZone(mapID)`
- `GetModelLevel(level)`
- `GetModelInstance(instanceKey)`
- `GetModelHeatmap(mapID)`
- `GetModelQuest(questKey)`
- `GetModelDeath(index)`
- `GetModelRespawn(npcID)`

All return a v2-shaped result with:

- `source = "legacy" | "v2" | "missing"`;
- v2 names: `byPlayerLevel`, `byZone`, `byInstance`, `playerLevels`;
- legacy-first reads;
- v2 fallback only when the legacy field is absent.

No existing reader or writer was switched.

## 2. Ownership behavior

| Domain | Transitional read | V2 fallback |
|---|---|---|
| Mob | `db.mobs` | `journey.mobs` |
| Zone | `db.areas` + `journey.zones` time/XP | `journey.zones` |
| Level | `db.levels` + `journey.levels` time/XP | `journey.levels` |
| Instance | `db.instances` | `journey.instances` |
| Heatmap | `db.heatmaps` | `journey.heatmaps` |
| Quest | `db.quests` | `journey.quests` |
| Death | `db.deaths` | `journey.deaths` |
| Respawn | `db.respawns` | `journey.respawns` |

`source` and `timeSource` make mixed ownership explicit. Legacy and v2 values are
never added together.

## 3. Tests

`tests/s1_model_helpers.lua` verifies:

- mob identity/counts/XP/player-level/zone/instance shape;
- zone kills from legacy plus time/XP from Journey;
- level parity;
- instance parity;
- heatmap cells/total;
- quest/death/respawn parity;
- v2-only fallback for every helper;
- missing-source behavior;
- helper calls do not mutate character data.

Passing output:

```text
S1 model helpers passed
```

`./tests/run_all.sh` passes, including TOC/layout validation for the new file.

## 4. Limits

- Helpers are not yet consumed by UI/commands.
- Contexts are not normalized from keyed map to array; that is S2B.
- Heatmap helpers use legacy cells; block decode remains separate.
- No writer migration, block payload change, or legacy retirement.
- No live client test.

## 5. Next

**DS-17.10 — S2A mob model migration.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `AceM2L2.toc`
- `tests/s1_model_helpers.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-09-DATA-MODEL-S1-SCAFFOLDING.md`
