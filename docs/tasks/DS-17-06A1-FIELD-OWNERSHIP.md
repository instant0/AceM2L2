# DS-17.6A1 — Field ownership audit

**Status:** parallel slice; read-only  
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`  
**Output file:** `docs/audits/DS-17-06A1-FIELD-OWNERSHIP.md`  
**No production code changes. No shared-doc edits.**

## Goal

Build the field-by-field ownership table for the current production Journey.

## Boundaries

- Owns the logical field inventory, status, and owner layer.
- Does not trace event write paths (A2).
- Does not audit physical blocks/caches/save (A3).
- Does not audit UI/command consumers (A4).

## Read

- `KillHistory/Data.lua`
- `KillHistory/Journey.lua`
- `KillHistory/JourneyStorage.lua`
- `KillHistory/JourneyQueries.lua`
- `KillHistory/JourneyIndex.lua`
- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/DS-11-DECISION-RECORD.md`
- `docs/DATA-MODEL-PLAN.md`

Do not edit these files.

## Required table

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|

Status must be one of: implemented, partial, missing, V-2-only.

Owner layer must be one of: static metadata, per-character Journey, future
Knowledge, UI/derived.

Cover at minimum:

- mob identity, name, classification;
- mob level range/samples vs `byPlayerLevel`;
- `byZone` / `byInstance` player-level subcounts;
- kills, kill XP, quest XP, other XP;
- presence/engaged seconds;
- combat contexts and XP contexts;
- death fields;
- quests and quest anchors;
- respawn aggregates;
- heatmap cells/total/top-N/lastSeen;
- sessions and level history;
- schema/meta/project identity.

## Required findings

- duplicated or unowned fields;
- fields whose names still imply player level but mean mob level, or vice versa;
- fields present in the design but absent in production;
- fields present in production but absent from DS-17.5;
- account-owned vs per-character-owned fields.

## Acceptance

- Every field is accounted for.
- Each status has a file/function citation.
- No source or shared doc is modified.
- Report is self-contained and can be merged by DS-17.6A5.


## Report contract

- Start with status, scope, files read, method, and limitations.
- Use the required table.
- Cite evidence as `file:line` or `file:function`.
- List gaps and open questions separately.
- State “no code changed; no tests run.”
- Do not commit or push.

## Conflict boundary

Write only `docs/audits/DS-17-06A1-FIELD-OWNERSHIP.md`.
Do not edit `PLAN.md`, `NEXT-TASK.md`, production Lua, tests, or other audit files.
Do not run tests. Do not create other files. Do not commit or push.
