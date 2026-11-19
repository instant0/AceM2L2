# DS-17.12 — S2B context shape result

**Status:** executed 2026-11-18  
**Scope:** v2 context arrays, combat/XP views, top-8+other. No block/UI/retirement.  
**Test:** `tests/s2b_context_shape.lua`; full suite passes.

## 1. Shape

`journey.mobs[key]` now carries:

- `contexts` — full deterministic array;
- `combat` — combat/danger-shaped view, `healthKnown=false`;
- `xpContexts` — XP-shaped view;
- `contextsTop8` — strongest 8;
- `contextsOther` — aggregate remainder.

Context records preserve:

- key, player/mob level, group size, map/instance;
- classification, buff signature;
- samples, base/buffed/total sums;
- min/max base, last seen.

No health or deaths are invented; `combat` marks health unknown until V-2.

## 2. Migration and sync

- `migrateLegacyMob` converts keyed legacy contexts into the shape.
- `SyncModelMobContextsFromLegacy` updates contexts only and preserves
  v2-only fields such as mob-level samples.
- `RecordObservation` syncs after a successful observation.
- Merge/delete/prune use the S2A full sync hooks.
- Bulk load sync rebuilds the shape from final legacy contexts.
- `ResetObservations` clears v2 contexts through bulk sync.

## 3. Retention

`contextsTop8` keeps the first 8 by:

1. `samples` descending;
2. context key ascending.

`contextsOther` aggregates samples, sums, min/max, and lastSeen for the
remainder. Top-8 + `other` preserves totals exactly.

## 4. Tests

`tests/s2b_context_shape.lua` covers:

- keyed -> array migration;
- sample sorting;
- combat/XP views;
- top-8 + `other` totals;
- context-only sync preserving v2 fields;
- observation hook;
- merge/delete sync;
- bulk idempotence;
- v2-only context reads after legacy removal.

Passing output:

```text
S2B context shape passed
...
All offline checks passed.
```

## 5. Limits

- Real health/danger values remain V-2 work.
- Block payload top-8 packing is S8.
- Legacy keyed contexts remain a compatibility view.
- No UI switch or legacy retirement.

## 6. Next

**DS-17.13 — S3 zone/level ownership migration.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/Calibration.lua`
- `KillHistory/Data.lua`
- `tests/s2b_context_shape.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-12-S2B-CONTEXT-SHAPE.md`
