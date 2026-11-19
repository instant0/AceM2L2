# DS-17.16 — S5 death ownership

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-16-S5-DEATH-OWNERSHIP-RESULT.md`  
**Depends on:** DS-17.15  
**Blocks:** S6 quests/respawns, V-2 death verification  
**Source:** `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md`

## Goal

Make `journey.deaths` canonical for death time/map/position and prepare the
attribution fields without inventing unavailable V-2 data.

## Exact vs V-2-only

| Field | Source | Status |
|---|---|---|
| at, mapID, x, y | `db.deaths` / death event | exact |
| mobKey/npcID | killer attribution | V-2-only |
| health/healthBand | death event | V-2-only |
| buffs/group/classification/difficulty | death event | V-2-only |
| combat context | death context | V-2-only |

Do not invent attribution, health, or death context. Missing fields stay absent
or explicitly `unavailable`.

## Death record contract

```text
journey.deaths[i] = {
  at, mapID, x, y,          -- exact
  attributionCoverage = "unavailable",
  healthCoverage = "unavailable",
  contextCoverage = "unavailable",
}
```

V-2-only fields (`mobKey`, `npcID`, health, buffs, group, classification,
difficulty, context) stay absent until captured. Do not insert zero or fake
values.

## Sync contract

- `EnsureModelDeaths` backfills from `db.deaths`.
- `SyncModelDeathsFromLegacy` rebuilds the v2 array from normalized legacy deaths.
- Call sync after `RecordDeath` and after load normalization.
- Preserve the existing 100-death cap and 5-second duplicate suppression.
- `GetModelDeath` becomes v2-only.
- No block/UI/retirement changes.
- `NormalizeDeaths` currently strips fields beyond at/map/x/y. S5 does not add
  V-2 fields; when they are captured, the normalizer must preserve them.
- Index order must match the normalized/capped legacy order.

## Scope

- Backfill `journey.deaths` from `db.deaths`.
- Write v2 deaths from `RecordDeath` / player-death event.
- Preserve normalization/cap behavior.
- Keep `db.deaths` as compatibility projection.
- `GetModelDeath` becomes v2-only.
- Add coverage flags for attribution/health/context.
- No block/UI/retirement.

## Tests

`tests/s5_death_ownership.lua`:

- at/map/x/y parity;
- death capture writes v2;
- duplicate suppression and cap parity;
- missing V-2 fields absent and coverage unavailable;
- load sync and idempotence;
- v2-only reads with `db.deaths` removed;
- no block/UI/retirement.

## Acceptance

- `journey.deaths` canonical for exact position/time fields.
- V-2-only fields explicitly marked unavailable.
- Legacy remains compatibility projection.
- No fabricated attribution/health.
- Full suite passes.

## Not required

- live killer/health/buff capture;
- quest/respawn migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
