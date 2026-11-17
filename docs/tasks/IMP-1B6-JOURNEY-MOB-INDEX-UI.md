# IMP-1B6 — Journey mob index and list/overview switch

**Status:** index core executed 2026-11-16; UI switch completed in IMP-1B7  
**Result:** `docs/IMP-1B6-JOURNEY-MOB-INDEX-RESULT.md`  
**Harness:** `tests/journey_index.lua`  
**Depends on:** IMP-1B5, IMP-1B4, DS-15, DS-17.5  
**Blocks:** V-2, UI

## Why

Tooltip/Detail can use single-entry block fallback. The Mobs list, Areas/Levels,
Overview, and commands iterate every mob and need a normalized Journey mob index.
Block storage alone cannot serve a full scan.

## Scope

- Build a compact `journey.mobs` index or equivalent:
  - key/npcID/name/classification;
  - kills/XP;
  - zone/instance refs;
  - level range.
- Keep it consistent with blocks/dirty flush.
- Add list/overview/area/level query APIs.
- Switch UI views one at a time behind a flag.
- Keep legacy fallback and rollback.
- No account Knowledge/merge or UI redesign.

## Acceptance

- List/overview queries are O(index), not full block decode.
- Tooltip/Detail behavior remains correct.
- Legacy fallback/rollback remains.
- No full decode/scan.
- No data deletion until migration/backup is proven.
- V-2 can verify live behavior.

## Not required

- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- live client test.
