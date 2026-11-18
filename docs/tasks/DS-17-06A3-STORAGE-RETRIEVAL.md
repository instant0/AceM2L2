# DS-17.6A3 — Storage, retrieval, and save audit

**Status:** parallel slice; read-only  
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`  
**Output file:** `docs/audits/DS-17-06A3-STORAGE-RETRIEVAL.md`  
**No production code changes. No shared-doc edits.**

## Goal

Verify that the stored model, retrieval model, and save/migration behavior match
the decisions in DS-11 and DS-17.5.

## Boundaries

- Owns physical blocks, codec, caches, save, migration, and retention.
- Owns query API implementation.
- Does not audit logical field ownership (A1) or UI/command consumers (A4).

## Read

- `KillHistory/JourneyStorage.lua`
- `KillHistory/Module.lua`
- `KillHistory/Data.lua`
- `KillHistory/Util.lua`
- `KillHistory/JourneyQueries.lua`
- `KillHistory/JourneyIndex.lua`
- tests: `tests/journey_storage.lua`, `tests/journey_save_guard.lua`,
  `tests/ds16_save_policy.lua`, `tests/ds17_5_schema.lua`,
  `tests/storage_sanity.lua`, `tests/capacity_assessment.lua`

Do not edit these files.

## Required table

| Area | Expected | Actual | Status | Evidence | Follow-up |
|---|---|---|---|---|---|

Cover:

- schema-2 block layout;
- packed encode/decode and checksum;
- dirty-block save;
- previous-backup/restore;
- migration/downgrade/reset;
- login decode count;
- selected-block lazy decode;
- bounded block/heatmap caches;
- no arbitrary block scans;
- sparse 64×64 cells and top-N;
- adaptive caps/retention;
- contexts as arrays with top-8 + `other`;
- no per-kill save.

## Required checks

- login decodes zero cold blocks;
- a selected tooltip decodes one block and reuses it;
- missing/corrupt block fails safely;
- oversize/save-guard behavior is covered;
- caps are adaptive, not the old fixed 2,000/40/100/12 design.

## Acceptance

- Each row cites code or an offline test.
- Any mismatch is marked as a gap with a proposed follow-up.
- Query API implementation is in scope; UI/command consumers are A4.
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

Write only `docs/audits/DS-17-06A3-STORAGE-RETRIEVAL.md`.
Do not edit `PLAN.md`, `NEXT-TASK.md`, production Lua, tests, or other audit files.
Do not run tests. Do not create other files. Do not commit or push.
