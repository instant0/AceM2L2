# IMP-1B8 — Remaining legacy read audit and safe command switch

**Status:** executed 2026-11-16  
**Result:** `docs/IMP-1B8-LEGACY-READ-AUDIT-RESULT.md`  
**Harness:** `tests/commands_index.lua`  
**Depends on:** IMP-1B7, IMP-1B6, IMP-1B5  
**Blocks:** IMP-1B9, IMP-1B10, V-2, remaining legacy retirement, UI

## Why

Mobs list and Overview now read through the Journey mob index. Several other
paths still scan legacy tables directly:

- command output (`kills`, `dump`, `stats`, `table`);
- Areas and Levels tabs;
- area/level summaries;
- heatmap UI and related summaries.

Not all of these can move yet. Areas/Levels need legacy/Journey parity or a
one-time backfill, and heatmap UI needs a bounded cell query. Commands that only
need the indexed mob rows can move safely now.

## Scope

1. Audit every remaining production read of:
   - `db.mobs`;
   - `db.areas`;
   - `db.levels`;
   - `db.heatmaps`.
2. Classify each read as:
   - safe for the Journey mob index;
   - needs legacy/Journey parity or backfill;
   - needs a bounded block/heatmap query.
3. Switch safe command reads to the index behind `journey.indexViews`:
   - `PrintKills`;
   - `PrintDump`;
   - any list-like command that only needs indexed mob rows.
4. Keep legacy fallback/rollback for every switched read.
5. Do **not** switch Areas/Levels until parity or backfill is proven.
6. Do **not** switch heatmap UI in this task.
7. Preserve current command output, filters, ordering, and top-N limits.
8. No account Knowledge/merge or UI redesign.

## Tests

- Command output parity for kills/filter/search and dump.
- One index build for repeated command output.
- Mutation invalidation rebuilds once.
- Rollback flag returns to legacy reads.
- Areas/Levels/heatmap remain on their current data.
- Existing smoke/query/storage/index/list tests stay green.

## Acceptance

- Remaining legacy reads are inventoried with a switch classification.
- Safe command reads use the index with parity.
- Areas/Levels/heatmap have explicit follow-up tasks.
- Rollback works.
- No account Knowledge/merge or UI redesign.

## Follow-ups

- **IMP-1B9 — Areas/Levels parity and switch.** Add legacy/Journey parity or a
  one-time backfill before switching the tabs.
- **IMP-1B10 — Heatmap UI bounded query.** Switch heatmap UI only after a
  selected-zone bounded cell query is proven.

## Not required

- live client test;
- account Knowledge/merge;
- UI redesign;
- LoadOnDemand companion;
- route recommendation.
