# DS-17.9 — S1 data-model scaffolding

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-09-DATA-MODEL-S1-SCAFFOLDING-RESULT.md`  
**Depends on:** DS-17.8  
**Blocks:** S2 mob/context migration  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Goal

Add a single read-owner/parity layer for the v2 target without changing which
store is canonical yet. This lets S2 migrate data with less risk.

## Scope

1. Add read helpers for the domains in the owner matrix:
   - mob identity, kills, XP, mob level range;
   - `byPlayerLevel` / `byZone` / `byInstance`;
   - zone and level counts/XP/time;
   - instance totals;
   - heatmap cells/top-N;
   - quests, deaths, respawns.
2. Helpers read the **current legacy source first** and expose a v2-shaped
   result.
3. Optional v2 fallback only when the legacy field is absent.
4. Add parity tests comparing helper output to the existing readers.
5. Document the final owner matrix and the transitional read order.
6. Do not change writers, readers, blocks, or schema.

## Implementation contract

- Add `KillHistory/JourneyModel.lua` after `JourneyQueries.lua` in the TOC.
- Helpers are read-only and side-effect free:
  - `GetModelMob(mobKey)`
  - `GetModelZone(mapID)`
  - `GetModelLevel(level)`
  - `GetModelInstance(instanceKey)`
  - `GetModelHeatmap(mapID)`
  - `GetModelQuest(questKey)`
  - `GetModelDeath(index)`
  - `GetModelRespawn(npcID)`
- Return v2-shaped names (`byPlayerLevel`, `byZone`, `byInstance`, `playerLevels`)
  while reading the current legacy fields first.
- Use a v2 fallback only when the legacy value is absent. Never add legacy and v2
  values together.
- Do not change UI/commands/writers/blocks/schema.
- Record which source supplied each result (`source = "legacy" | "v2" | "missing"`).

## Parity contract

- `GetModelMob` parity: kills/totalXP/classification/zones/instances/player-level
  counts match `db.mobs`.
- `GetModelZone` parity: kills match `db.areas`; XP/time match `journey.zones`.
- `GetModelLevel` parity: kills match `db.levels`; XP/time match `journey.levels`.
- `GetModelInstance` parity: kills/XP match `db.instances`.
- `GetModelHeatmap` parity: cells/total/lastSeen match `db.heatmaps`.
- `GetModelQuest` / death / respawn parity.
- Calling helpers does not mutate the character table.

## Test contract

`tests/s1_model_helpers.lua` must cover each helper, a v2-only fallback case, a
missing-source case, no-mutation, and current-reader parity.

## Required behavior

- No production UI/command switch to the helper layer yet.
- No data migration or dual-write.
- No block payload change.
- No new SavedVariables key.
- Helpers must be deterministic and side-effect free.

## Tests

- `tests/s1_model_helpers.lua`:
  - legacy mob/zone/level/instance/heatmap/quest/death/respawn reads;
  - v2-shaped field names;
  - missing-field fallback;
  - parity with current readers;
  - no writes.

- Existing full suite remains green.

## Acceptance

- Helpers exist and are tested.
- Current readers still use their existing source.
- No data or schema migration.
- No feature/UI/account Knowledge work.
- S2 can consume the helpers.

## Not required

- S2 writer migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
