# IMP-1B2 — Production Journey migration and block storage

**Status:** block storage core executed 2026-11-16  
**Result:** `docs/IMP-1B2-JOURNEY-BLOCK-STORAGE-RESULT.md`  
**Harness:** `tests/journey_storage.lua`  
**Depends on:** IMP-1B, IMP-1A, DS-17.5, DS-15, DS-16, DS-14  
**Blocks:** V-2, UI

## Why

IMP-1B added production read-only queries. The remaining production storage work:

- v2 schema/migration;
- zone/instance/name-only blocks;
- login zero-decode;
- selected-block lazy decode;
- dirty-block save/guard;
- tooltip danger/best-zone/heatmap integration.

## Scope

- Migrate existing legacy data into v2 Journey without breaking current UI.
- Keep one-time backup and idempotence.
- Build zone/instance/name-only blocks.
- Load encoded blocks at login without decoding.
- Selected-block lazy decode + bounded LRU.
- Dirty-block save/checksum/backup/oversize guard.
- Missing/corrupt fallback.
- Keep current smoke/query tests green.
- No merge/account writes/UI.

## Acceptance

- Legacy data migrates safely.
- No full decode at login.
- No full scan.
- No per-kill save.
- Instance/name-only blocks work.
- Event time/quest anchors preserved.
- Existing behavior remains green.
- V-2 can verify live behavior.

## Not required

- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- live client test;
- route recommendation.
