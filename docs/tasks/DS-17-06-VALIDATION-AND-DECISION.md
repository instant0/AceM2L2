# DS-17.6 — Validation, measurement, and decision (split)

**Status:** split 2026-11-18.  
**Current next:** DS-17.6A — current data-model validation.  
**Deferred:** DS-17.6B — ALT/account-feature validation.

## Why split

The original DS-17.6 mixed two different priorities:

1. **Current data-model validation** — does the production Journey match the
   agreed schema, and what gaps remain?
2. **Future ALT/account features** — multi-character Knowledge, route advice,
   confidence, and account persistence.

The data model is the priority now. ALT features are deferred.

## Task documents

- `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`
- `docs/tasks/DS-17-06B-ALT-FEATURE-VALIDATION.md`

## Order

1. DS-17.6A — current data-model validation.
2. V-2 — live-only field/API/save verification.
3. MEM-1 — live memory sample.
4. DS-17.6B — only if ALT features are scheduled.

No ALT/account feature work starts before the current data model is validated.
