# DS-17.6A2 — Capture-path audit

**Status:** parallel slice; read-only  
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`  
**Output file:** `docs/audits/DS-17-06A2-CAPTURE-PATHS.md`  
**No production code changes. No shared-doc edits.**

## Goal

Trace where every Journey field is written and when.

## Boundaries

- Owns event/write-path tracing.
- Uses DS-17.5 field names; does not assign the final field-ownership verdict (A1).
- Does not audit physical storage/save (A3) or UI consumers (A4).

## Read

- `KillHistory/Tracking.lua`
- `KillHistory/Events.lua`
- `KillHistory/Journey.lua`
- `KillHistory/World.lua`
- `KillHistory/Util.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/Commands.lua`
- tests: `tests/journey.lua`, `tests/cap1_capture_fields.lua`, `tests/quest_anchors.lua`

Do not edit these files.

## Required table

| Field | Status | Event/trigger | Function | Write target | Time source | Offline test |
|---|---|---|---|---|---|

Status must be one of: implemented, partial, missing, V-2-only.

Cover at minimum:

- mob level at sighting;
- player level and mob level separately;
- kills/XP/quest XP/other XP;
- presence and engaged seconds;
- combat contexts;
- XP contexts;
- death attribution/health/buffs/group/classification/difficulty;
- heatmap cells and optional XP/time;
- quest turn-in;
- respawn intervals;
- sessions/level history.

## Required checks

- no timer/OnUpdate time tracking;
- no per-kill timestamp log;
- no per-kill save;
- quest turn-in does not enter mob combat context;
- heatmap kill position is captured at commit (G-1B);
- missing fields are marked V-2-only or missing, not assumed.

## Acceptance

- Every write path has a file/function citation.
- The table distinguishes implemented, partial, missing, and V-2-only.
- No source or shared doc is modified.
- Report can be merged by DS-17.6A5.


## Report contract

- Start with status, scope, files read, method, and limitations.
- Use the required table.
- Cite evidence as `file:line` or `file:function`.
- List gaps and open questions separately.
- State “no code changed; no tests run.”
- Do not commit or push.

## Conflict boundary

Write only `docs/audits/DS-17-06A2-CAPTURE-PATHS.md`.
Do not edit `PLAN.md`, `NEXT-TASK.md`, production Lua, tests, or other audit files.
Do not run tests. Do not create other files. Do not commit or push.
