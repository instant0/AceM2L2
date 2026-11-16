# IMP-1 — Journey schema and retrieval integration

**Status:** ready; after CAP-1/DS-14  
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
- Danger and best-zone XP/hour queries.
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
