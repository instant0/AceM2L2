# IMP-1A — Production Journey instrumentation result

**Status:** instrumentation slice executed 2026-11-16  
**Production module:** `KillHistory/Journey.lua`  
**Test:** `tests/journey.lua`; included in `tests/run_all.sh`  
**Scope:** production event-driven Journey time/quest instrumentation only. No
storage/retrieval migration yet.

## 1. What was implemented

A new production module records Journey state additively in
`self.char.journey`:

```lua
journey = {
  schema = 1,
  projectID = ...,
  mode = "leveling",
  time = {
    zone = ..., level = ...,
    lastEventAt = ..., lastKillAt = ...,
    cap = 60,
  },
  zones = {
    [mapID] = {
      kills, killXP, questXP, otherXP, xp,
      presenceSeconds, engagedSeconds,
      deaths, sessions,
    },
  },
  levels = {
    [playerLevel] = { ...same fields... },
  },
}
```

No timer, no OnUpdate, no per-kill log.

## 2. Event wiring

Reused existing events:

- `PLAYER_ENTERING_WORLD` → `OnJourneyEnterWorld`
- `ZONE_CHANGED_NEW_AREA` → `OnJourneyZoneChanged`
- `PLAYER_LEVEL_UP` → `OnJourneyLevelUp`
- `PLAYER_LOGIN` / session start → normal existing path
- `RecordKill` → `OnJourneyKill`
- late kill XP → `OnJourneyKillXP`
- quest XP recording → `OnJourneyQuestTurnIn`
- `UNIT_DIED` remains the existing kill path

Added one finalizer:

- `PLAYER_LOGOUT` → `OnJourneyLogout`

No periodic timer and no extra events beyond the logout finalizer.

## 3. Time rules

### Presence time

```text
close/open on enter, zone, level, kill, quest, logout
presenceSeconds += now - lastEventAt
```

### Engaged time

```text
engagedSeconds += min(now - lastKillAt, cap)
```

- `cap = 60` seconds in this slice.
- Quest turn-in closes presence and resets `lastKillAt` so quest/travel time is
  not counted as engaged kill time.
- Logout closes presence and adds a final capped engaged gap.

## 4. Quest anchor

`RecordQuestXP` now calls `OnJourneyQuestTurnIn` after the existing quest record
update.

It:

- closes the presence segment;
- adds `questXP` and `quests` count to the current zone/level;
- sets the quest `lastTurnInAt`, `mapID`, and `playerLevel`;
- does not add engaged kill time;
- does not enter mob combat/XP context.

## 5. Test result

`tests/journey.lua` sequence:

```text
enter, kill, kill, quest turn-in, kill, logout
```

Asserted:

```text
zone presence  = 200 s
zone engaged   = 140 s
killXP         = 175
questXP        = 500
lastTurnInAt   > 0
lastEventAt    = 0 after logout
```

Test passes. `tests/run_all.sh` passes.

## 6. What is not done yet

- v2 schema migration of existing `mobs`/`areas`/`levels`;
- block save/retrieval;
- instance/name-only blocks;
- danger/health/death-attribution capture;
- heatmap cell XP/time;
- tooltip/best-zone/heatmap queries from Journey;
- account Knowledge/merge;
- UI.

These remain in **IMP-1B**.

## 7. Findings

1. **Event-driven time works without a timer.**
2. **Quest turn-in is a useful sparse anchor** and must not count as engaged
   kill time.
3. **XP split is explicit** (`killXP`, `questXP`, `otherXP`) in Journey records.
4. **Production hooks are additive** and do not yet replace the existing schema.
5. **`PLAYER_LOGOUT` is the only added event.**
6. **Existing smoke and Journey tests pass.**

## 8. Follow-up

**IMP-1B — Production Journey storage and retrieval integration.**

- v2 schema/migration;
- blocks/instances/name-only;
- dirty-block save/guard;
- selected decode/cache;
- tooltip/danger/best-zone/heatmap;
- tests.

## Artifacts

- `KillHistory/Journey.lua`
- `KillHistory/Module.lua`
- `KillHistory/Events.lua`
- `KillHistory/Tracking.lua`
- `KillHistory/Data.lua`
- `AceM2L2.toc`
- `tests/journey.lua`
- `tests/run_all.sh`
