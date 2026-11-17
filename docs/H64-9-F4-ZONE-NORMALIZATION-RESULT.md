# H64-9-F4 — Zone-scoped/lazy heatmap normalization result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/Heatmap.lua`,
`KillHistory/UI/Heatmap.lua`  
**Test:** `tests/heatmap_lazy_zone.lua`; `./tests/run_all.sh`  
**Scope:** selected-zone normalization and metadata-only zone listing. No storage
schema or grid change.

## 1. Zone index

Added `GetHeatmapZoneIndex()`:

- builds the UI zone list from raw heatmap metadata;
- does **not** upgrade or normalize cells;
- merges duplicate numeric/string map keys at metadata level;
- applies the existing map cap and sort order;
- overlays Journey block heatmap metadata when available.

The full `NormalizeHeatmaps()` path remains for commands, diagnostics, and
existing tests.

## 2. Selected-zone cells

Added `GetHeatmapZoneCells(mapID)`:

- normalizes only the requested map;
- upgrades 16/32/64 cells for that map only;
- caches up to four normalized zones;
- invalidated by `InvalidateHeatmapCache`, `ResetHeatmaps`, and
  `RecordHeatmapKill`;
- returns legacy cells for the UI fallback when a Journey block is missing.

## 3. UI

`UI/Heatmap.lua` now:

- reads the zone list from `GetHeatmapZoneIndex`;
- keeps Journey block cells as the first selected-zone source;
- falls back to `GetHeatmapZoneCells` for legacy selected-zone cells;
- still uses `GetHeatmapZones` only where full data is explicitly requested.

## 4. Tests

`tests/heatmap_lazy_zone.lua` verifies:

- the zone index does not call full normalization;
- the index does not materialize cells;
- only the selected zone normalizes;
- a repeated read uses the zone cache;
- a second zone normalizes once;
- a kill invalidates the zone cache;
- full normalization still works for commands/tests;
- the UI normalizes only the selected zone.

Passing output:

```text
Heatmap lazy zone passed
```

`./tests/run_all.sh` passes.

## 5. Limitations

- The zone index still scans raw metadata/totals, but does not upgrade cells.
- Full commands (`heatmap` print/clear/diagnostics) retain the full normalizer.
- No display-detail cap or grid change.
- Live visual/frame confirmation remains in V-2.

## 6. Next

**R-4 — Static overlay/art audit.**

## Artifacts

- `KillHistory/Heatmap.lua`
- `KillHistory/UI/Heatmap.lua`
- `tests/heatmap_lazy_zone.lua`
- `tests/run_all.sh`
- `docs/tasks/H64-9-05-FOLLOWUP-WORK.md`
