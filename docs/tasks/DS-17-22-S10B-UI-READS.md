# DS-17.22 — S10B UI read retirement

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-22-S10B-UI-READS-RESULT.md`  
**Depends on:** DS-17.21  
**Blocks:** S10C live-gated retirement  
**Source:** `docs/DS-17-21-S10A-QUERY-RETIREMENT-RESULT.md`

## Goal

Remove direct legacy aggregate reads from UI list and detail paths after S10A.

## Scope

- Quest list rows read `journey.quests`; names resolve through the model.
- Respawn history reads `journey.respawns`.
- Death history reads `journey.deaths`.
- Mob list, index, tooltip, and detail read v2 mob records; block fallback
  remains only when no v2 record exists.
- Area/instance detail reads v2 zone/instance records.
- Heatmap/detail summaries read v2 heatmaps and blocks only.
- Footer/status/diagnostics counts use v2 roots.
- The mob index carries v2 session kills and XP statistics.

## Keep

- Legacy writes and normalizers until S10C.
- Quest ledger names until a v2 name source replaces them.
- Block fallbacks for old schema 2 blocks.
- Existing overlay toggles and persistent UI settings.

## Tests

`tests/s10_ui_read_retirement.lua`:

- quest/respawn/death rows with legacy roots absent;
- mob list with index views disabled and legacy mobs absent;
- area/instance detail parity;
- mob detail context parity;
- heatmap/detail reads without legacy heatmaps;
- footer/status counts;
- full offline suite.

## Acceptance

- UI list/detail paths do not depend on legacy aggregate roots.
- No write or normalizer removal in this slice.
- Full suite passes.

## Not in S10B

- stopping dual writes;
- removing normalizers/syncs;
- removing rollback insurance;
- live V-2 validation.
