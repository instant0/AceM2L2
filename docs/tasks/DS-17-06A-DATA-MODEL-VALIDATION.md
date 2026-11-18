# DS-17.6A — Current data-model validation

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`  
**Depends on:** DS-11, DS-17.1..DS-17.5, CAP-1, IMP-1A/B, DS-14/15/16, SC-1/2/6, G-1B  
**Blocks:** V-2 field confirmation and any data-model follow-up implementation  
**Parent:** `docs/tasks/DS-17-06-VALIDATION-AND-DECISION.md`

## Why

DS-11 made the **data model** the priority. The storage medium, grid, caps, and
codec are settled. Before adding more features, we need one field-by-field check
that the production Journey actually matches the agreed model and that every
open gap is assigned to either offline work, V-2 live verification, or a future
feature.

This is not an ALT/account Knowledge task. Account Knowledge is already parked
as a future derived view.

## Parallel execution plan

Four read-only audits can run simultaneously. They must not edit shared docs or
production code. Each writes exactly one report file.

| Slice | Focus | Output |
|---|---|---|
| DS-17.6A1 | field ownership vs DS-17.5 | `docs/audits/DS-17-06A1-FIELD-OWNERSHIP.md` |
| DS-17.6A2 | event capture paths | `docs/audits/DS-17-06A2-CAPTURE-PATHS.md` |
| DS-17.6A3 | storage/retrieval/save | `docs/audits/DS-17-06A3-STORAGE-RETRIEVAL.md` |
| DS-17.6A4 | query truth/UI/commands | `docs/audits/DS-17-06A4-QUERY-TRUTH.md` |
| DS-17.6A5 | consolidation | `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md` |

Rules:

- A1–A4 are read-only and run in parallel.
- A1–A4 may read the same files; only writes are separated.
- A1–A4 must not edit `PLAN.md`, `NEXT-TASK.md`, production Lua, tests, or each
  other's reports.
- A1–A4 must not run tests; inspect test files and cite existing results.
- A1–A4 must not commit or push.
- A5 starts only after A1–A4 finish.
- A5 alone may edit shared docs and run `./tests/run_all.sh`.

## Scope

### 1. Field-by-field schema audit

Compare production `journey.*` data against DS-17.5:

- mob identity/name/classification;
- `mobLevelMin`/`mobLevelMax` vs `byPlayerLevel`;
- `byZone` / `byInstance` player-level subcounts;
- kill XP / quest XP / other XP;
- presence and engaged time;
- combat and XP contexts;
- death fields;
- quests and quest anchors;
- respawn aggregates;
- heatmap cells, totals, top-N, lastSeen;
- sessions/level history;
- schema/meta/projectID ownership.

For each field, record:

- implemented / partial / missing;
- written by which event path;
- read by which query/UI;
- offline-tested or V-2-only;
- owner layer (static, per-character Journey, future Knowledge).

### 2. Capture-path audit

Verify:

- event-driven time only, no timer/OnUpdate;
- no per-kill timestamps or per-kill saves;
- player level and mob level are distinct;
- quest turn-in does not enter mob combat context;
- death attribution/health/buffs/group fields are either captured or explicitly
  V-2-only;
- heatmap cell XP/time is captured or explicitly V-2-only;
- instance attribution and non-attributable instance behavior are correct.

### 3. Storage/retrieval audit

Verify:

- schema-2 Journey blocks;
- sparse 64×64 heatmaps and top-N summaries;
- zero cold-block decode at login;
- selected-block lazy decode and bounded cache;
- no arbitrary block scans for global tooltips;
- save guard, backup, migration, downgrade, reset behavior;
- caps/retention match the accepted adaptive values;
- contexts are arrays with top-8 + `other` cold retention.

### 4. Query truth

Check that UI and commands read the same stored model:

- tooltip;
- Overview;
- Mobs;
- Areas;
- Levels;
- Heatmap;
- history/quest views;
- diagnostics.

No stale legacy path may silently disagree with Journey data.

### 5. Gap table

Produce one table with four outcomes:

1. implemented and offline-tested;
2. implemented but needs V-2 live confirmation;
3. designed but not implemented;
4. deferred future feature (account Knowledge, ALT, route, etc.).

Every gap gets a named next action or stays explicitly deferred.

## Test profiles

- local real store when present;
- synthetic 1× and 6× shape;
- sparse and dense heatmaps;
- missing/corrupt block;
- migration/backup/downgrade;
- context top-8+other;
- project/interface separation;
- no per-kill field check.

## Output

- field ownership/schema acceptance table;
- capture-path table;
- storage/retrieval/save verification;
- query-truth results;
- gap table with owners;
- data-model follow-up list (no feature work).

## Acceptance

- Every Journey field is accounted for as implemented/partial/missing.
- No duplicate or unowned field remains.
- No per-kill log or per-kill save is present.
- Player level and mob level are unambiguous.
- Storage/retrieval/save/migration checks pass or have named follow-ups.
- Every V-2-only field is listed.
- Every deferred feature is explicitly marked deferred.
- No ALT/account Knowledge/route feature work is started here.

## Report contract for A1–A4

Each report starts with:

- status: complete / blocked;
- scope;
- files read;
- method;
- limitations.

Then include the required table, findings with `file:line` evidence, gaps,
open questions, and a short “no code changed” statement.

## Subagent launch contract

Pre-create `docs/audits/` once before launching. Each slice is independent; do
not make one slice depend on another slice's report.

Launch one subagent per slice A1–A4 with:

- the slice task document path;
- the parent task document path;
- the exact output path under `docs/audits/`;
- “read-only; write only your report file”;
- “do not edit production Lua, tests, `PLAN.md`, `NEXT-TASK.md`, or other audit
  files”;
- “do not run tests”;
- “do not create files outside your output path”;
- “do not read or depend on another slice's report”;
- “do not commit or push”;
- “return a short summary plus the report path.”

Start A5 only after all four report files exist. If any report is missing or
blocked, A5 must not start; return the blocked slice instead. A5 is the only
slice allowed to edit shared docs and run `./tests/run_all.sh`.

## Task documents

- `docs/tasks/DS-17-06A1-FIELD-OWNERSHIP.md`
- `docs/tasks/DS-17-06A2-CAPTURE-PATHS.md`
- `docs/tasks/DS-17-06A3-STORAGE-RETRIEVAL.md`
- `docs/tasks/DS-17-06A4-QUERY-TRUTH.md`
- `docs/tasks/DS-17-06A5-CONSOLIDATION.md`

## Not required

- account Knowledge implementation;
- ALT/route features;
- new storage-format study;
- UI redesign;
- grid change;
- live client test;
- production feature code.
