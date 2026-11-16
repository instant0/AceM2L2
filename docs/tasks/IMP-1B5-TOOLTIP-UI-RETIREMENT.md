# IMP-1B5 — Tooltip/UI retirement and rollback

**Status:** next; after IMP-1B4  
**Depends on:** IMP-1B4, IMP-1B3, DS-15, DS-16  
**Blocks:** V-2, UI

## Why

Block storage, retrieval, backup, and save-blocking now work. Legacy data is still
the UI/tooltip source and duplicates block data.

## Scope

- Switch safe tooltip/UI reads to Journey/block queries.
- Keep legacy fallback during migration.
- Define rollback/retirement order.
- Preserve current behavior and smoke tests.
- Remove duplication only after tests and backup.
- No account Knowledge/merge or UI redesign.

## Acceptance

- Tooltip/UI behavior stays green.
- No full decode at login.
- No full scan.
- No per-kill save.
- Rollback/backup works.
- Duplication removal is reversible.
- V-2 can verify live behavior.

## Not required

- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- live client test;
- route recommendation.
