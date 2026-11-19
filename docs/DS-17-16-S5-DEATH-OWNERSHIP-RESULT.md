# DS-17.16 — S5 death ownership result

**Status:** executed 2026-11-18  
**Scope:** exact death position/time; V-2 fields explicitly unavailable.  
**Test:** `tests/s5_death_ownership.lua`; full suite passes.

## 1. Ownership

`journey.deaths` is canonical for:

- `at`, `mapID`, `x`, `y`.

`db.deaths` remains a compatibility projection.

## 2. Coverage

| Field | Status |
|---|---|
| at/map/x/y | exact |
| mobKey/npcID | unavailable (V-2) |
| health/healthBand | unavailable (V-2) |
| buffs/group/classification/difficulty | unavailable (V-2) |
| combat context | unavailable (V-2) |

No attribution, health, or context values are invented.

## 3. Implementation

- `EnsureModelDeaths` backfills from normalized `db.deaths`.
- `SyncModelDeathsFromLegacy` rebuilds v2 from normalized legacy deaths.
- `RecordDeath` syncs v2 after append.
- Load normalization syncs v2.
- 100-death cap and 5-second duplicate suppression are preserved.
- `GetModelDeath` is v2-only.

## 4. Tests

- position/time parity;
- production death capture writes v2;
- duplicate suppression;
- 100-death cap/order;
- coverage flags unavailable;
- load sync idempotence;
- v2-only reads with `db.deaths` removed;
- no fabricated V-2 fields.

Passing output:

```text
S5 death ownership passed
...
All offline checks passed.
```

## 5. Limits

- Live killer/health/buff/context capture remains V-2.
- `NormalizeDeaths` still strips fields beyond at/map/x/y; future V-2 capture must
  preserve them.
- Block/UI/legacy retirement unchanged.

## 6. Next

**DS-17.17 — S6 quest/respawn ownership.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/World.lua`
- `KillHistory/Data.lua`
- `tests/s5_death_ownership.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-16-S5-DEATH-OWNERSHIP.md`
