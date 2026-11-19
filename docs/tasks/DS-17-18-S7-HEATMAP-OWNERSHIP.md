# DS-17.18 — S7 heatmap ownership and top-N

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-18-S7-HEATMAP-OWNERSHIP-RESULT.md`  
**Depends on:** DS-17.17  
**Blocks:** S8 block payload v2 completeness  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Goal

Make `journey.heatmaps` canonical for heatmap metadata and cells, with explicit
coverage for unavailable per-cell data.

## Exact vs unavailable

| Field | Source | Status |
|---|---|---|
| mapID, gridSize | `db.heatmaps` | exact |
| cell kill counts | `db.heatmaps` | exact |
| total kills | `db.heatmaps` | exact |
| lastSeen | `db.heatmaps` | exact |
| top-10 cells | derived from cells | exact |
| cell XP/presence/engaged | none in legacy | unavailable |
| 32/16 cold downsampling | derived later | S8 |

Do not invent per-cell XP/time.

## Heatmap record contract

```text
journey.heatmaps["<mapID>"] = {
  mapID, gridSize,
  cells = { [cell] = { kills = n } },
  total, lastSeen,
  top10 = { { cell = n, count = n }, ... },
  killsCoverage = "exact",
  cellXpCoverage = "unavailable",
  cellTimeCoverage = "unavailable",
}
```

- Cells store only measured kills. `xp`, `presenceSeconds`, and `engagedSeconds`
  stay absent until V-2 capture exists.
- `total` is the sum of retained cell counts, not a copied counter.
- `gridSize` stays 64. No 32/16 cold tier in S7.
- Map keys are stringified numeric map IDs so the model matches `db.heatmaps`.

## Top-N contract

- `top10` is derived from the canonical cells, sorted by kills descending.
- Ties sort by cell index ascending for deterministic output.
- At most 10 rows, only cells with positive kills.
- Top-N is a summary, not a second kill counter; it never adds to `total`.

## Sync contract

- Migration is one-way legacy → v2 until S10; v2 is never copied back into
  `db.heatmaps`.
- Normalize the legacy projection first, then rebuild the v2 map.
- Update the affected v2 cell after a kill; rebuild that map only when it is
  absent. Sync all maps after clear, cap eviction, prune, and load.
- Preserve the 64-map cap, the per-cell kill ceiling, and sparse cell indexing.
- `db.heatmaps` remains a compatibility projection and the block source until
  S8; this slice does not change block payloads.
- `GetModelHeatmap` is v2-only and has no implicit legacy fallback.

## Scope

- Backfill `journey.heatmaps` from `db.heatmaps`.
- Write v2 heatmap cells on kill/clear/cap.
- Store deterministic top-10 summaries.
- Keep `db.heatmaps` as compatibility projection.
- `GetModelHeatmap` becomes v2-only.
- Sync on clear/cap/prune/load.
- No block payload, 32/16 archive, UI, or retirement.

## Tests

`tests/s7_heatmap_ownership.lua`:

- cell/total/lastSeen parity;
- top-10 ordering and deterministic ties;
- cell XP/time marked unavailable and absent from cell records;
- clear/cap/prune sync;
- v2-only reads with `db.heatmaps` removed;
- idempotence;
- no block/UI/retirement.

## Acceptance

- `journey.heatmaps` canonical for cells/total/lastSeen/top-10.
- Legacy remains compatibility projection.
- Cell XP/time not invented.
- No double counting.
- Full suite passes.

## Not required

- block payload v2 completeness;
- 32/16 cold tier (S8);
- UI reader switch;
- legacy retirement;
- live client test.
