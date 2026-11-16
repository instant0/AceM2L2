# IMP-1B — Production Journey storage and retrieval integration

**Status:** query API slice executed 2026-11-16; storage/migration in IMP-1B2  
**Result:** `docs/IMP-1B-JOURNEY-QUERY-RESULT.md`  
**Harness:** `tests/journey_queries.lua`  
**Depends on:** IMP-1A, IMP-1, CAP-1, DS-17.5, DS-15, DS-16, DS-14  
**Blocks:** V-2, UI features

## Why

IMP-1A added production Journey instrumentation. The remaining work is to make
it the storage/retrieval source:

- v2 schema/migration;
- zone/instance/name-only blocks;
- dirty-block save/guard;
- selected decode/cache;
- tooltip/danger/best-zone/heatmap queries.

## Scope

- Migrate existing `mobs`/`areas`/`levels`/`heatmaps`/`deaths`/`quests` to v2
  Journey fields without losing current behavior.
- Preserve the existing schema until migration is proven.
- Build zone/instance/name-only blocks.
- Login loads encoded blocks; decode zero.
- Selected-block lazy decode + bounded LRU.
- Dirty-block save/checksum/backup/oversize guard.
- Tooltip:
  - current Journey;
  - metadata/registry;
  - selected block;
  - `NPC <id>` fallback.
- Danger by combat context.
- Best zone total XP/hour and kill-only XP/hour.
- Heatmap top-N.
- Missing/corrupt fallback.
- Tests/migration fixtures.

## Acceptance

- Existing behavior and smoke tests stay green.
- Migration is idempotent and backed up.
- No per-kill save.
- No full decode at login.
- No full scan.
- Instance/name-only blocks work.
- Event time/quest anchor preserved.
- No merge/account writes/UI.
- V-2 can verify live behavior.

## Not required

- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- live client test;
- route recommendation.
