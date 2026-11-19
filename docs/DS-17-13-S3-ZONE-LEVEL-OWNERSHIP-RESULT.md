# DS-17.13 — S3 zone/level ownership result

**Status:** executed 2026-11-18  
**Scope:** v2 zone/level ownership with explicit XP/time coverage.  
**Test:** `tests/s3_zone_level_ownership.lua`; full suite passes.

## 1. Ownership

`journey.zones` and `journey.levels` are now canonical for:

- zone kills and player-level kills;
- level kills;
- derived zone kill XP;
- other XP from `unattributed.byMap`;
- existing Journey quest XP/time;
- level history timestamps and XP fallback.

Legacy `db.areas`, `db.levels`, `db.areaLevels`, `levelHistory`, and
`unattributed.byMap` remain compatibility inputs.

## 2. Exact vs derived

| Field | Source | Coverage |
|---|---|---|
| zone kills | `db.areas` | exact |
| zone player levels | `db.areaLevels` | exact kills |
| level kills | `db.levels` | exact |
| zone killXP | mob XP allocated by `killsByMap` | derived |
| zone otherXP | `unattributed.byMap` | derived/available |
| zone questXP | Journey only | post-instrumentation |
| zone time | Journey only | post-instrumentation |
| level XP | Journey, else `levelHistory.xpGained` | partial |
| level timestamps | `levelHistory` | available |

`xp` is the sum of available components. The model does not claim a complete
historical XP total when quest/other history is absent.

## 3. Sync

- `EnsureModelZones` / `EnsureModelLevels` migrate once.
- `SyncModelZoneFromLegacy` updates kills/player levels/derived XP and preserves
  Journey time/deaths/sessions/quest split.
- `SyncModelLevelFromLegacy` updates kills/timestamps and preserves Journey time.
- `SyncModelZonesFromLegacy` bulk syncs.
- Mob merge/delete/prune and load consolidation call zone/level sync.
- `GetModelZone`/`GetModelLevel` are v2-only after migration.

## 4. Tests

- zone/player-level/level parity;
- derived kill XP and other XP;
- XP component sum;
- coverage flags;
- level-history XP/timestamps;
- sync preserves time and XP split;
- bulk idempotence;
- v2-only reads with legacy removed.

Passing output:

```text
S3 zone/level ownership passed
...
All offline checks passed.
```

## 5. Limits

- Historical quest/other XP is partial and explicitly marked.
- Time is post-instrumentation only.
- Block payload/UI readers/legacy retirement unchanged.
- No live client test.

## 6. Next

**DS-17.14 — S4 instance ownership migration.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/Data.lua`
- `tests/s3_zone_level_ownership.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-13-S3-ZONE-LEVEL-OWNERSHIP.md`
