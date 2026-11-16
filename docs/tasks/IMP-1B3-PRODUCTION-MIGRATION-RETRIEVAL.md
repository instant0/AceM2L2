# IMP-1B3 — Journey migration and retrieval integration

**Status:** block-backed retrieval slice executed 2026-11-16  
**Result:** `docs/IMP-1B3-BLOCK-RETRIEVAL-RESULT.md`  
**Harness:** `tests/journey_storage.lua`  
**Depends on:** IMP-1B2, IMP-1B, IMP-1A, DS-15, DS-16, DS-14  
**Blocks:** V-2, UI

## Why

IMP-1B2 added per-zone/instance block storage, lazy decode, cache, and dirty
flush from legacy data. Remaining work:

- retire or migrate legacy storage safely;
- pack the remaining Journey data;
- wire retrieval queries to blocks;
- integrate save/guard;
- avoid permanent duplication.

## Scope

- Decide migration/retirement order for `db.mobs`/`areas`/`levels`/heatmaps.
- Preserve browser/UI behavior during migration.
- Pack heatmaps/quests/deaths/respawns only where measured beneficial.
- Wire tooltip/danger/best-zone/heatmap to block storage and Journey queries.
- Use selected-block lazy decode/cache.
- Dirty-block save/oversize guard integration.
- Backup/restore and downgrade.
- Remove duplication only after block storage and tests are proven.
- No account Knowledge/merge, no UI redesign.

## Acceptance

- Existing behavior stays green.
- No full decode at login.
- No full scan.
- No per-kill save.
- Block retrieval works for tooltip/best-zone/heatmap queries.
- Legacy data is either migrated or explicitly retained with a retirement plan.
- Backup/restore/oversize guard integrated.
- V-2 can verify live behavior.

## Not required

- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- live client test;
- route recommendation.
