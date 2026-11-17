# IMP-1B10 — Heatmap UI bounded query

**Status:** executed 2026-11-16  
**Result:** `docs/IMP-1B10-HEATMAP-BOUNDED-RESULT.md`  
**Harness:** `tests/heatmap_bounded.lua`  
**Depends on:** IMP-1B9, DS-15, DS-17.1  
**Blocks:** IMP-1B12, V-2, IMP-1B11

## Why

Heatmap UI and related summaries still read legacy `db.heatmaps`. Journey blocks did not
previously contain heatmap cells, so this task adds sparse cells to the zone
block first. Arbitrary cold-block scans remain too expensive for a UI refresh,
and a global cold tooltip has already been measured as unsafe.

## Scope

- Define a selected-zone bounded heatmap query:
  - current/selected zone only;
  - one block decode at most per refresh;
  - cached by zone;
  - top-N cells only.
- Use the existing lazy block cache and checksum validation.
- Keep legacy heatmap data authoritative until parity is proven.
- Switch heatmap UI behind a flag with legacy rollback.
- Do not add a global cold-block scan.
- No account Knowledge/merge or UI redesign.

## Tests

- Selected-zone query decodes at most one block.
- Cache hit decodes zero additional blocks.
- Top-N cell parity with legacy where both exist.
- Missing/corrupt block fallback to legacy.
- Rollback flag.
- No global cold scan.

## Acceptance

- Heatmap UI has a bounded, cached source.
- No arbitrary cold-block decode from a UI refresh.
- Legacy rollback works.
- No account Knowledge/merge or UI redesign.

## Not required

- live client test;
- global cold heatmap;
- account Knowledge/merge;
- UI redesign.
