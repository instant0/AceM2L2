# DS-17.6B — ALT/account-feature validation

**Status:** future; only after DS-17.6A and after ALT features are scheduled.  
**Depends on:** DS-17.6A, DS-17.4D, DS-17.5, DS-15  
**Blocks:** ALT feature scheduling and any account-persistence design

## Why

Account Knowledge, multiple-character advice, and route recommendations are
future features. DS-17.4D proved offline derivation is technically feasible, but
the runtime model is unresolved: per-character SavedVariables are not co-loaded
in game, and account persistence is not designed.

This task is deliberately deferred until the current data model is validated and
ALT features are actually scheduled.

## Scope

- 1/3/5-alt profiles and overlapping data;
- account Knowledge coverage/confidence;
- route recommendation and held-out backtesting;
- account persistence/co-loading options;
- account Knowledge staleness/rebuild;
- ALT UI/query needs;
- feature decision: schedule, defer, or reject.

## Required inputs

- DS-17.6A field/gap table;
- DS-17.4D offline derivation result;
- V-2 live field availability;
- MEM-1 memory sample;
- account persistence decision.

## Not required now

- production account storage;
- route implementation;
- account-wide raw history;
- cross-account data;
- UI.

## Gate

Do not start this task while DS-17.6A, V-2, or MEM-1 is unresolved.
