# IMP-1B11 — Rollback retirement

**Status:** preparation complete 2026-11-16; final removal after V-2  
**Result:** `docs/IMP-1B11-ROLLBACK-RETIREMENT-PREP.md`  
**Harness:** `tests/rollback_inventory.lua`  
**Depends on:** IMP-1B12, IMP-1B10, IMP-1B9, IMP-1B7, IMP-1B5; V-2 for final removal  
**Blocks:** final legacy retirement

## Why

Rollback branches exist to protect data during migration and to diagnose bad
paths on live clients. They are not a permanent architecture. Once V-2 and the
remaining UI switches are verified, keeping both paths increases code size,
test surface, and the chance of stale or double-counted reads.

## Scope

- Confirm V-2 results for:
  - tooltip/Detail block fallback;
  - index-backed list/Overview/commands/Areas/Levels;
  - save/checkpoint and oversize guard;
  - reset behavior.
- Remove runtime rollout flags:
  - `journey.indexViews`;
  - `journey.blockReadFallback`.
- Remove the legacy duplicate reads that exist only for rollback:
  - list/Overview scans;
  - command scans;
  - Areas/Levels inline scans;
  - tooltip/Detail legacy-first branch.
- Keep the legacy **data** until a separate migration/backfill proves it is no
  longer needed.
- Keep normal release/version rollback as the emergency mechanism.
- Update tests to assert one authoritative path.
- No account Knowledge/merge or UI redesign.

## Tests

- One-path output parity against the pre-removal snapshots.
- No rollout-flag references remain.
- Empty, corrupt-block, and migrate paths still work.
- Save/checkpoint/oversize guard unchanged.
- Reset still clears both authoritative and block data.

## Acceptance

- Runtime rollback flags are gone.
- Legacy duplicate **read** paths are gone.
- Legacy **data** is retained until a separate backfill decision.
- Emergency rollback is a normal release/version rollback.
- All tests pass.

## Not required

- legacy data deletion;
- account Knowledge/merge;
- UI redesign;
- route recommendation.
