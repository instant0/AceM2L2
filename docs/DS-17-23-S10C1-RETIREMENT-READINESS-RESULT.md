# DS-17.23 — S10C-1 retirement readiness result

**Status:** executed 2026-11-18  
**Scope:** offline retirement inventory, blockers, replay checks, and restore path.  
**Test:** `tests/s10c_retirement_readiness.lua`; full suite passes.

## 1. Why this is S10C-1

Removing dual writes, normalizers, fallbacks, and rollback insurance requires
live V-2 evidence. S10C-1 records what is left and proves the v2-only read path
without claiming live validation.

## 2. Readiness API

`KillHistory/Retirement.lua` exposes:

- `GetRetirementRootInventory()` — legacy and v2 counts for mobs, zones, levels,
  instances, deaths, quests, respawns, heatmaps, blocks, and block indexes.
- `GetRetirementRestorePath()` — migration-backup presence, restorability,
  schema, and stranded state.
- `GetRetirementReadiness()` — live gates, blockers, roots, restore path, and
  current/next stage.

The readiness result is deliberately **not ready** while:

- V-2A/V-2B/V-2C/V-2D lack evidence;
- legacy roots remain;
- dual writes remain;
- quest names still depend on the legacy ledger;
- a migration backup is missing.

## 3. Diagnostics

`GetDataStats().retirement` exposes the readiness report. It is available without
changing the diagnostics row count.

## 4. Tests

- legacy/v2 root inventory;
- V-2 gate blockers;
- dual-write and quest-ledger blockers;
- restore-path reporting;
- live evidence alone cannot declare S10C-1 ready;
- v2-only replay with legacy roots absent;
- diagnostics readiness.

Passing output:

```text
S10C retirement readiness passed
...
All offline checks passed.
```

## 5. Limits

- No dual write, normalizer, or fallback was removed.
- No live V-2 result is claimed.
- Quest names still use the legacy ledger.
- Rollback insurance remains.

## 6. Next

**S10C-2 — live-gated removal**, blocked on V-2A/B/C/D evidence and a restorable
migration backup.

## Artifacts

- `KillHistory/Retirement.lua`
- `KillHistory/UI/Diagnostics.lua`
- `AceM2L2.toc`
- `tests/s10c_retirement_readiness.lua`
- `tests/run_all.sh`
