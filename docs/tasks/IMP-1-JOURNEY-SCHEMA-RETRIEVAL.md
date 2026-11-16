# IMP-1 — Journey schema and retrieval integration

**Status:** integration slice executed 2026-11-16; production wiring in IMP-1A  
**Result:** `docs/IMP-1-JOURNEY-SCHEMA-RETRIEVAL-RESULT.md`  
**Harness:** `tests/imp1_integration.lua`  
**Depends on:** DS-17.5, DS-15, DS-16, CAP-1, DS-14  
**Blocks:** V-2, UI features

## Why

The offline schema, codec, save, and retrieval prototypes now need one production
integration:

- v2 Journey schema and migration;
- dirty-block/incremental save;
- per-block base64/checksum;
- selected-block lazy decode and LRU;
- tooltip, danger, best-zone, heatmap queries;
- no full decode at login, no full scan, no merge.

## Scope

- Implement the v2 Journey schema in production code.
- Migration from current v1 with backup and idempotence.
- Hot/warm/cold movement and dirty-block save.
- Per-block checksum/base64.
- Selected-block lazy decode + bounded LRU.
- Tooltip:
  - current Journey;
  - metadata registry/account Knowledge when available;
  - `NPC <id>` fallback.
- Event-driven time:
  - `presenceSeconds`/`engagedSeconds`;
  - reuse existing events + one logout finalizer;
  - no timer/OnUpdate.
- Quest turn-in:
  - existing `QUEST_TURNED_IN` as sparse presence anchor;
  - split `killXP`/`questXP`/`otherXP`;
  - no engaged time from quest turn-in;
  - no quest state in mob context.
- Danger and best-zone XP/hour queries (total and kill-only).
- Heatmap top-N queries.
- Missing/corrupt block fallback.
- Oversize guard integration.
- Tests/fixtures; no UI redesign; no merge.

## Acceptance

- No full decode at login.
- No full scan for tooltip/zone/heatmap.
- No per-kill save.
- Migration/backup safe.
- Missing/corrupt data safe.
- No merge/account writes.
- V-2 can verify live timing.
