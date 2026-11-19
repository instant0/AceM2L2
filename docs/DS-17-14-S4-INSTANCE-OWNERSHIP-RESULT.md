# DS-17.14 — S4A instance ownership result

**Status:** executed 2026-11-18  
**Scope:** exact instance identity/totals/XP/player levels.  
**Test:** `tests/s4_instance_ownership.lua`; full suite passes.

## 1. Ownership

`journey.instances` is now canonical for:

- name/type/ID/difficulty/map ID;
- kills;
- XP totals;
- player-level kills;
- first/last seen.

`db.instances` remains a compatibility projection.

## 2. Coverage

| Field | Status |
|---|---|
| identity | exact |
| kills | exact |
| XP | legacy-total |
| player-level kills | exact |
| first/last seen | exact |
| presence/engaged time | **unavailable** |
| deaths/sessions per instance | **unavailable** |

No time or deaths are invented. `journey.zones["0"]` was not touched.

## 3. Implementation

- `EnsureModelInstances` backfills from `db.instances`.
- `SyncModelInstanceFromLegacy` updates exact fields and preserves Journey time.
- `SyncModelInstancesFromLegacy` bulk-syncs and removes deleted instances.
- `GetModelInstance` is v2-only.
- Kill/merge/delete/prune/load hooks sync instances.

## 4. Tests

- identity parity;
- kills/XP/player levels;
- non-attributable instance keeps its own record;
- attributable instance map remains separate;
- sync preserves Journey time;
- bulk idempotence;
- deleted instances removed;
- v2-only reads after legacy removal;
- time/deaths/sessions marked unavailable;
- `zones["0"]` untouched.

Passing output:

```text
S4 instance ownership passed
...
All offline checks passed.
```

## 5. Limits

- Per-instance time/deaths/sessions remain S4B.
- Historical `journey.zones["0"]` aggregate cannot be split per instance.
- Block/UI/legacy retirement unchanged.

## 6. Next

**DS-17.15 — S4B instance time/death/session coverage.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/Tracking.lua`
- `KillHistory/Data.lua`
- `tests/s4_instance_ownership.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-14-S4-INSTANCE-OWNERSHIP.md`
