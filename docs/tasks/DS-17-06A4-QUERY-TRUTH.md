# DS-17.6A4 — Query-truth audit

**Status:** parallel slice; read-only  
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`  
**Output file:** `docs/audits/DS-17-06A4-QUERY-TRUTH.md`  
**No production code changes. No shared-doc edits.**

## Goal

Verify that every UI/command reader uses the current Journey model and agrees
with the stored data. Query API implementation is A3; this slice owns consumer
truth.

## Boundaries

- Owns UI/command consumer truth.
- Does not audit query API implementation (A3), field ownership (A1), or
  physical storage/save (A3).

## Read

- `KillHistory/Tooltip.lua`
- `KillHistory/UI/Detail.lua`
- `KillHistory/UI/List.lua`
- `KillHistory/UI/Window.lua`
- `KillHistory/UI/Heatmap.lua`
- `KillHistory/UI/Diagnostics.lua`
- `KillHistory/Commands.lua`
- `KillHistory/JourneyQueries.lua`
- `KillHistory/JourneyIndex.lua`
- read paths in `KillHistory/Data.lua`
- tests: `tests/tooltip_fallback.lua`, `tests/areas_levels_parity.lua`,
  `tests/heatmap_bounded.lua`, `tests/historical_relevance.lua`,
  `tests/historical_zone.lua`, `tests/heatmap_selector.lua`

## Required table

| View/query | Reader | Data source | Legacy path? | Status | Evidence |
|---|---|---|---|---|---|

Cover:

- tooltip;
- Overview;
- Mobs list/filter/search;
- Areas;
- Levels;
- Heatmap zone selector and grid;
- death/respawn history;
- quest ledger;
- diagnostics;
- commands.

## Required checks

- no stale legacy table silently disagrees with Journey;
- fallback view switches are explicit and tested;
- selected heatmap/zone reads do not decode unrelated blocks;
- area/level summaries use the same totals as Detail;
- tooltip fetches only fields it renders;
- no block scan for global/random tooltip.

## Acceptance

- Every reader has a source and status.
- Any disagreement is marked as a gap with a proposed follow-up.
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

Write only `docs/audits/DS-17-06A4-QUERY-TRUTH.md`.
Do not edit `PLAN.md`, `NEXT-TASK.md`, production Lua, tests, or other audit files.
Do not run tests. Do not create other files. Do not commit or push.
