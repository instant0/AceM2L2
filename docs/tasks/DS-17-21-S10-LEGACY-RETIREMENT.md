# DS-17.21 — S10 legacy retirement

**Status:** S10A executed 2026-11-18; S10B next; S10C live-gated.  
**Result:** `docs/DS-17-21-S10A-QUERY-RETIREMENT-RESULT.md`  
**Depends on:** DS-17.19, DS-17.20, V-2  
**Blocks:** IMP-1B11 final rollback retirement  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## S10 split

S10 is split so offline work does not masquerade as live retirement:

- **S10A (executed):** query-layer reads become v2-only; legacy aggregate roots
  are not consulted by `JourneyQueries`.
- **S10B (next):** UI list/detail readers switch to v2 ownership.
- **S10C (live-gated):** stop dual writes, remove normalizers/syncs/fallbacks,
  and delete rollback insurance only after V-2 passes.

## Goal

Retire legacy aggregate ownership after v2 parity and live validation, keeping a
recoverable migration backup until the release gate passes.

## Preconditions

- S8 schema 3 blocks round-trip complete v2 records.
- S9 retention, summaries, context collapse, and compaction are stable.
- V-2A/V-2B capture and V-2C save/load/oversize checks pass on a live client.
- No open P0 data-loss issue.
- A restore path exists for the previous legacy payload.

## S10A scope

- `GetJourneyZoneStats`, `GetJourneyLevelStats`, area/level rows, summaries,
  kill counts, heatmap top cells, mob summaries, and quest anchors read the v2
  roots.
- `UseJourneyIndexViews` no longer selects a legacy fallback for these queries.
- Quest names still resolve through the quest ledger until a v2 name source
  replaces it in S10C.
- Status counts use v2 rows.
- Writes, normalizers, and compatibility projections are unchanged.

## Retirement slices

1. Remove legacy-first reads from `JourneyQueries` and UI fallbacks.
2. Stop dual-writing legacy projections after a parity window.
3. Remove legacy normalizers, sync calls, and compatibility fields.
4. Retire legacy blocks/index fallbacks and warm-cache guards.
5. Remove IMP-1B11 rollback insurance after the release gate.

## Keep

- per-character Journey as primary;
- schema 3 blocks and S9 archive tiers;
- account Knowledge deferred and derived;
- migration backup until the final retirement step;
- single-player local behavior.

## Tests

`tests/s10_query_retirement.lua` (S10A):

- v2-only query reads with legacy aggregate roots absent;
- zone/level stats, area/level rows, summaries, and kill counts;
- heatmap top cells, mob summary, quest anchors;
- status counts;
- no `UseJourneyIndexViews` legacy path.

`tests/s10_legacy_retirement.lua` (S10C):

- save/load replay from schema 3 blocks;
- no dual-write or fallback call remains;
- rollback backup and restore before final removal;
- full offline suite with legacy roots removed.

## Live gates

- V-2A field probes;
- V-2B implemented capture;
- V-2C save/load/oversize/companion;
- V-2D visual checks.

## Acceptance

S10A:

- query-layer reads do not depend on legacy aggregate roots;
- status counts use v2 rows;
- offline tests pass with those roots removed.

S10C:

- no production read or write depends on the retired legacy roots;
- live V-2 checks pass before rollback insurance is deleted;
- a documented restore path exists for the release window.

## Not in S10

- account Knowledge/ALT production writes;
- route recommendations;
- new storage-format study.
