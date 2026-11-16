# CAP-1 — Journey capture fields

**Status:** executed 2026-11-16  
**Result:** `docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`  
**Harness:** `tests/cap1_capture_fields.lua`  
**Depends on:** DS-17.5, DS-15, DS-16, DS-11  
**Blocks:** IMP-1, V-2, UI features

## Why

The v2 Journey schema and retrieval model assume fields the current addon does
not capture yet:

- mob level range;
- event-driven time per zone/level/instance;
- combat health/buffs/group context;
- death attribution/health/buffs/group;
- heatmap cell XP/time;
- XP context group/rested/buffs;
- durable per-zone/level timing.

This task adds those capture points without a per-kill event log.

## Scope

- Mob level at sighting/context.
- Fixed mob level range.
- Player health/health max/health band for combat/death.
- Buff signature and group size for combat/XP.
- Death mob attribution and context.
- Event-driven time by zone/level/instance:
  - `presenceSeconds` (wall-clock);
  - `engagedSeconds` (capped kill/XP gaps);
  - reuse existing events;
  - no OnUpdate/periodic timer;
  - at most one logout finalizer event.
- Heatmap cell XP/time when available.
- Quest turn-in as a sparse presence anchor and quest-XP separation:
  - reuse existing `QUEST_TURNED_IN`;
  - no engaged time from quest turn-in;
  - quest state stays out of combat/XP context.
- XP context group/rested/buffs.
- Tests/fixtures for available/unavailable APIs.

## Acceptance

- Fields populate without per-kill writes.
- Missing APIs degrade safely.
- Quest state excluded.
- No merge/UI.
- V-2 can verify real client behavior.
