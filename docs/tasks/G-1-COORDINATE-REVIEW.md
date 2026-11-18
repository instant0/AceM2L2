# G-1 — Coordinate capture review and refresh

**Status:** split on 2026-11-17  
**Next:** G-1A — coordinate source and policy review  
**Conditional:** G-1B — heatmap commit-time position refresh  
**Live gate:** V-3 only if G-1B lands

## Why split

The review and the fix have different risk profiles:

- **G-1A** is a static, no-code review. It must decide kill-time versus
  engagement-time semantics, replace-only versus fill-missing coverage, group
  kills, cross-map behavior, attribution boundaries, and instance/vehicle
  handling.
- **G-1B** is a small, conditional heatmap-only code change. It should not start
  until G-1A has resolved those semantics.
- **V-3** remains the live confirmation and is not part of either task.

Attempting review and implementation in one task would make it too easy to turn
a display-accuracy fix into an attribution or migration change.

## Task documents

- `docs/tasks/G-1A-COORDINATE-REVIEW.md`
- `docs/tasks/G-1B-POSITION-REFRESH.md`

## Not required

- live client test in G-1A/G-1B;
- new map database;
- unit/world-position conversion;
- grid/schema change;
- per-kill coordinate storage;
- account Knowledge.
