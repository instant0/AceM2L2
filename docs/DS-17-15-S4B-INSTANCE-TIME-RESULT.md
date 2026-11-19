# DS-17.15 — S4B instance time/death/session result

**Status:** executed 2026-11-18  
**Scope:** per-instance time/deaths/sessions; non-attributable routing.  
**Test:** `tests/s4b_instance_time.lua`; full suite passes.

## 1. Behavior

- Instance presence/engaged time is event-driven; no timer/OnUpdate.
- Instance time now goes to `journey.instances`, not `journey.zones["0"]`.
- Instance kills/XP/player-level counts update the instance record.
- First event in an instance increments `sessions`.
- Player deaths in an instance increment `deaths`.
- Attributable instance maps use the instance record for time instead of
  duplicating zone time.
- Legacy sync preserves event-captured time/deaths/sessions and updates exact
  totals.

## 2. Coverage

| Field | Coverage |
|---|---|
| per-instance presence/engaged | post-instrumentation |
| instance deaths | post-instrumentation |
| instance sessions | post-instrumentation |
| historical `zones["0"]` | unassigned; not split |

## 3. Tests

`tests/s4b_instance_time.lua` verifies:

- per-instance presence/engaged time;
- instance kills/XP/player levels;
- sessions on instance entry;
- instance death counter;
- non-attributable instance does not write `zones["0"]`;
- attributable instance does not duplicate zone time;
- legacy sync preserves time/deaths/sessions;
- v2-only reads after legacy removal.

Passing output:

```text
S4B instance time passed
...
All offline checks passed.
```

## 4. Limits

- Historical `zones["0"]` remains explicitly unassigned.
- Death attribution/health/context remain V-2/S5 work.
- Block/UI/legacy retirement unchanged.

## 5. Next

**DS-17.16 — S5 death ownership.**

## Artifacts

- `KillHistory/Journey.lua`
- `KillHistory/World.lua`
- `KillHistory/JourneyModel.lua`
- `tests/s4b_instance_time.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-15-S4B-INSTANCE-TIME.md`
