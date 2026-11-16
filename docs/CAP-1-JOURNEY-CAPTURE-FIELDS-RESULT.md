# CAP-1 — Journey capture fields result

**Status:** executed 2026-11-16  
**Harness:** `tests/cap1_capture_fields.lua`  
**Scope:** capture/fallback prototype; no production code, no merge, no UI.

## 1. Capture matrix

The current addon already captures:

- `UnitName`, `UnitLevel`, `UnitClassification`;
- map/position/instance;
- group size;
- buff signature (well fed/well rested/manual bonus);
- kills/XP/contexts;
- heatmap cell counts;
- deaths (map/x/y only).

Target additions:

| Field | Source | Fallback |
|---|---|---|
| Mob level/range | `UnitLevel` at sighting/context | `mobLevelKnown=false`, no range; do not use player level as mob level |
| Player health/health max | `UnitHealth`/`UnitHealthMax` | `healthBand="unknown"`, `healthKnown=false` |
| Buff/rested context | existing `GetBuffSignature`/aura API | `buffSignature="unknown"`, `buffKnown=false` |
| Group size | `GetNumGroupMembers` | `groupSize=1`, `groupKnown=false` |
| Death mob attribution | `UNIT_DIED` GUID/combat log where available | `mobKey=nil`; no mob-level danger |
| Time | existing zone/level/kill/XP events + one logout finalizer | no time; XP/hour low confidence |
| Heatmap cell XP/time | add at kill | cell counts only |
| Death circumstances | health/buffs/group/level/class/difficulty | unknown fields; danger only zone-level |
| Quest turn-in anchor | existing `QUEST_TURNED_IN` timestamp/reward | no anchor; XP/hour still works from kills, but quest XP is not separated |

The Forever/Midnight rows must be verified in V-2. The `unknown` row exercises
degraded behavior.

## 2. Health bands

Boundaries:

| HP | Band |
|---:|---|
| 0–20% | `0-20` |
| 21–40% | `21-40` |
| 41–60% | `41-60` |
| 61–80% | `61-80` |
| 81–100% | `81-100` |
| missing/max≤0 | `unknown` |

Health band is for combat/danger context. It is not part of XP context.

## 3. Context rules

### Combat/danger context

Includes:

- player level;
- mob level;
- health band;
- buff signature;
- group size;
- classification;
- instance difficulty.

Excludes quest state.

### XP context

Includes:

- player level;
- mob level;
- group size;
- rested;
- buff signature;
- classification.

Excludes health and quest state.

## 4. Mob level range

- Update only on a known `UnitLevel`.
- Track `min`, `max`, `samples`.
- Missing mob level → no range entry; do not substitute player level for the
  fixed mob level range.
- The existing tooltip may still use a player-level fallback for XP estimates;
  that must not become stored mob metadata.

## 5. Event-driven time accounting

There is **no timer and no OnUpdate**. Time is updated only when events already
handled by the addon arrive.

Two fields:

- `presenceSeconds` — wall-clock time in the current zone/instance/level;
- `engagedSeconds` — kill/XP activity time, with long gaps capped.

### Existing events reused

- `PLAYER_ENTERING_WORLD`
- `ZONE_CHANGED_NEW_AREA`
- `PLAYER_LEVEL_UP`
- `CHAT_MSG_COMBAT_XP_GAIN`
- `PLAYER_XP_UPDATE`
- `UNIT_DIED`
- `PLAYER_LOGIN`

At most **one** finalization event is added: `PLAYER_LOGOUT` (preferred) or
`ADDONS_UNLOADING`, not both.

### Update rules

- On zone/level/enter event:
  - close the previous presence segment at `now`;
  - start the new zone/level segment.
- On kill/XP event:
  - add `now - lastEventAt` to `presenceSeconds` for the current zone/level;
  - add `min(now - lastKillAt, cap)` to `engagedSeconds`;
  - set `lastEventAt`/`lastKillAt = now`.
- On logout/checkpoint:
  - close the presence segment;
  - add the final capped engaged gap;
  - persist totals and `lastEventAt`.

No per-kill timestamp array is stored. Only aggregate seconds and the last event
timestamp are retained.

### Quest turn-in as a sparse anchor

Use the existing `QUEST_TURNED_IN` event; do not add a new event.

On quest turn-in:

- close the presence segment at `now` and start a new one for the current
  zone/level;
- update `lastEventAt`;
- do **not** add the gap to `engagedSeconds` (it is not kill/XP grinding time);
- add the quest reward to `questXP` and increment `questCount` for the current
  zone/level;
- update the quest record `lastTurnInAt`, `mapID`, and `playerLevel`.

Keep quest state out of mob combat/XP context. Quest turn-in is a low-frequency
anchor, not a timer.

Prototype:

```text
presence total: 260 seconds
zone 1: 200 seconds
zone 2: 60 seconds
level 20: 100 seconds
level 21: 160 seconds
engaged total: 190 seconds
```

The exact test values are illustrative; the important point is that all updates
occur on events, never on a timer. `tests/cap1_capture_fields.lua` asserts
`timer_used=false` and exercises enter/zone/level/kill/logout events only.

## 6. Heatmap cell fields

Cell update supports:

```lua
cells[cell] = {
  kills = ...,
  xp = ...,
  presenceSeconds = ...,
  engagedSeconds = ...,
  lastSeen = ...,
}
```

Prototype added 2 kills, 200 XP, and 30 seconds to one cell.

## 7. Death records

Death record includes:

- `at`, `mapID`, `x`, `y`;
- `mobKey`/`npcID` when attributed;
- player/mob level;
- health/healthMax/healthBand;
- buff signature;
- group size;
- classification;
- difficulty;
- combat context key.

If killer attribution is unavailable, `mobKey=nil`; the death can still feed
zone-level danger, but not mob-level danger.

## 8. Findings

1. **Most context fields already exist.** Group size and buff signature are
   captured today; the main missing fields are health, death attribution,
   event-driven time, and heatmap cell XP/time.
2. **Mob level must not silently become player level.** Store `mobLevelKnown`
   and a separate range.
3. **Health bands are sufficient for danger context.** Exact health is kept on
   death, but aggregation uses bands.
4. **Quest state is excluded from both contexts.**
5. **Time is event-driven, not timer-driven.** `presenceSeconds` and
   `engagedSeconds` update only on existing events plus one logout finalizer;
   no per-kill timestamps and no OnUpdate.
6. **Quest turn-in is a useful sparse anchor.** It updates presence time and
   separates quest XP from kill XP, but does not count as engaged kill time.
7. **Heatmap cells can carry XP/time without changing the grid.**
8. **Death attribution is the critical V-2 unknown.** Without it, danger is
   zone-level only.
9. **No production code changed.**

## 9. Integration points for IMP-1

- `KillHistory/Util.lua` `CaptureUnit`: mob level known/range; optional health.
- `KillHistory/Tracking.lua` `RecordKill`: context fields, event-driven
  presence/engaged time, heatmap cell XP/time.
- `KillHistory/World.lua` `RecordDeath`/`HandlePlayerDeath`: attribution,
  health, buffs, group, classification, difficulty.
- `KillHistory/Module.lua`/`Events.lua`: reuse existing time events; add only
  `PLAYER_LOGOUT` finalization.
- `KillHistory/Heatmap.lua`: cell XP/time.
- `KillHistory/Data.lua`: v2 schema fields and migration.
- No per-kill event log.
- Existing `QUEST_TURNED_IN` is reused for presence anchoring and quest XP
  separation.

## 10. V-2 checks

- `UnitHealth`/`UnitHealthMax` on Forever/Midnight.
- Death attribution via `UNIT_DIED`/combat log.
- Buff/rested/group APIs under combat/death.
- `UnitLevel` reliability and level scaling.
- Zone/level active-time transitions.
- Heatmap cell XP/time capture.
- Forever/Midnight differences.

## Acceptance

- Capture matrix defined: **yes**.
- Health bands/fallback: **yes**.
- Combat/XP context separation: **yes**.
- Mob level range: **yes**.
- Active time: **yes**.
- Heatmap cell XP/time: **yes**.
- Death attribution/fallback: **yes**.
- Quest state excluded: **yes**.
- No per-kill log/merge/UI/production code: **yes**.
- No online source: **yes**.

## Artifacts

- `tests/cap1_capture_fields.lua`
- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/DS-17-04B-DANGER-AND-XP-HOUR-RESULT.md`
- `docs/DS-11-DECISION-RECORD.md`
