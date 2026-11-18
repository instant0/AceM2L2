# DS-17.6A5 — Consolidation and decision

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`  
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`  
**Output:** `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`  
**May edit shared docs. No production code.**

## Goal

Merge A1–A4 into one data-model verdict and a prioritized follow-up list.

## Read

- `docs/audits/DS-17-06A1-FIELD-OWNERSHIP.md`
- `docs/audits/DS-17-06A2-CAPTURE-PATHS.md`
- `docs/audits/DS-17-06A3-STORAGE-RETRIEVAL.md`
- `docs/audits/DS-17-06A4-QUERY-TRUTH.md`

## Required output

1. **Field verdict table**
   - implemented;
   - partial;
   - missing;
   - V-2-only.
2. **Conflict/gap table**
   - duplicate fields;
   - name ambiguity;
   - stale readers;
   - storage/retrieval mismatch;
   - migration/save gaps.
3. **Priority list**
   - fix now (offline, data-model);
   - V-2 live confirmation;
   - future feature/deferred.
4. **Acceptance statement**
   - whether the current data model is internally consistent;
   - what blocks V-2;
   - what blocks IMP-1B11;
   - what is explicitly deferred (ALT/account Knowledge/route).
5. **Plan updates**
   - `PLAN.md`;
   - `docs/NEXT-TASK.md`;
   - `docs/NON-LIVE-BACKLOG.md`;
   - `docs/PERFORMANCE-REVIEW.md`;
   - `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md` status/result.
6. **Run `./tests/run_all.sh` once** after merging. This is the only slice that
   runs the full suite.

## Report contract

- Start with status, inputs, and merge method.
- Include the field verdict table, conflict/gap table, and priority list.
- State the full-suite result.
- State “no production code changed.”
- Do not commit or push.

## Rules

- Do not start unless all four A1–A4 reports exist and are complete.
- If a report is blocked or missing, return blocked; do not guess its contents.
- Treat A1–A4 reports as immutable inputs; do not edit them.
- Merge by unioning fields, then resolve only real conflicts by re-reading code.
- Do not start ALT/account Knowledge/route work.
- If a data-model fix is required, create a named follow-up task; do not hide it
  inside this consolidation.
- Do not implement feature code; follow-up code changes get their own task.
- Use only the four audit reports as inputs; re-read code only to resolve a
  conflict.
- Update the DS-17.6A task status/result and any follow-up task docs; do not
  implement follow-up code.

## Conflict boundary

This is the only parallel slice allowed to edit shared docs.
A1–A4 must have finished before this starts.
