# DS-17.13 — S3 zone/level ownership migration

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-13-S3-ZONE-LEVEL-OWNERSHIP-RESULT.md`  
**Depends on:** DS-17.12  
**Blocks:** S4 instances, S6 quests/respawns/level history  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Goal

Make `journey.zones` and `journey.levels` canonical for:

- kills, kill/quest/other XP, total XP;
- presence/engaged seconds;
- deaths/sessions where available;
- player-level subcounts;
- last seen.

Keep `db.areas`, `db.levels`, `db.areaLevels`, and `levelHistory` as compatibility
projections until S3 parity is proven. No block payload/UI/retirement.

## Exact vs derived fields

Do not invent historical XP components.

| Field | Migration source | Coverage |
|---|---|---|
| zone kills | `db.areas` | exact |
| zone player levels | `db.areaLevels` | exact kills |
| level kills | `db.levels` | exact |
| zone killXP | legacy mob XP allocated by `killsByMap` | derived |
| zone otherXP | `db.unattributed.byMap` | derived/available |
| zone questXP | existing Journey only | post-instrumentation |
| zone time | existing Journey only | post-instrumentation |
| level XP | existing Journey, else `levelHistory.xpGained` | partial |
| level startedAt/endedAt | `levelHistory` | available |

Add coverage flags:

```text
killsExact = true
killXPCoverage = "derived" | "post-instrumentation"
questXPCoverage = "post-instrumentation"
otherXPCoverage = "derived" | "post-instrumentation"
xpCoverage = "partial"
timeCoverage = "post-instrumentation"
```

`xp` is the sum of the available components. Do not claim a complete historical
XP total when quest/other history is absent.

## Sync contract

- `SyncModelZoneFromLegacy(mapID)` updates kills/playerLevels/killXP/otherXP and
  recomputes `xp`; preserves Journey time/deaths/sessions.
- `SyncModelLevelFromLegacy(level)` updates kills and levelHistory timestamps/xp
  fallback; preserves Journey time/split fields.
- `SyncModelZonesFromLegacy()` bulk-updates all zone/level records from legacy
  without wiping Journey time or post-instrumentation XP.
- Call bulk sync after mob merge/delete/prune and after load consolidation.
- `GetModelZone` / `GetModelLevel` become v2-first after migration, with no
  legacy read fallback.

## Scope

- Migrate legacy zone/level totals into `journey.zones`/`journey.levels`.
- De-duplicate:
  - `db.areas` vs `journey.zones[].kills`;
  - `db.levels` vs `journey.levels[].kills`;
  - `db.areaLevels`/`mob.killsByAreaLevel` vs zone `playerLevels`;
  - `levelHistory` XP vs `journey.levels[].xp`.
- Add a `SyncModelZoneFromLegacy` / `SyncModelLevelFromLegacy` path using the S1
  helper shape.
- Keep legacy projections updated until readers switch.
- Contexts/blocks/UI readers unchanged.
- No legacy retirement.

## Ownership rule

For each field, choose one canonical source:

| Field | Canonical |
|---|---|
| zone kills/XP | `journey.zones` |
| level kills/XP | `journey.levels` |
| player-level subcounts | `journey.zones[].playerLevels` |
| presence/engaged | Journey |
| level history timestamps | `journey.levels` after backfill |

Legacy tables become projections, not independent writers. If a legacy projection
is still written by an existing path, sync the v2 value from the final legacy
state rather than summing both.

## Tests

`tests/s3_zone_level_ownership.lua`:

- zone kills/player-level parity;
- derived zone killXP/otherXP and partial xp coverage;
- level kills/XP/time parity;
- duplicate/overlap does not double count;
- migration/backfill idempotence;
- merge/delete/prune sync;
- v2-only reads with legacy removed;
- coverage flags are not overstated;
- no block/UI/retirement changes.

## Acceptance

- `journey.zones`/`levels` canonical for listed fields.
- Kills/player-level/level counts are exact; XP/time coverage is explicit.
- Legacy tables are compatibility projections.
- No double counting.
- Full suite passes.
- S4 can start from non-drifting zone/level data.

## Not required

- instance migration;
- quest/death/respawn migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
