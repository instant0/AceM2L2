# MEM-2 — Load/unload and eviction policy result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/Module.lua`,
`KillHistory/JourneyStorage.lua`, `KillHistory/Heatmap.lua`,
`KillHistory/UI/Heatmap.lua`, `KillHistory/UI/Window.lua`,
`KillHistory/UI/Diagnostics.lua`  
**Test:** `tests/mem_policy.lua`; `./tests/run_all.sh`  
**Scope:** bounded caches, UI pool release, diagnostics, and a written policy.
No schema or SavedVariables-root change.

## 1. Load boundary

Unchanged and documented:

- account DB loads normally;
- only the active character’s per-character SavedVariables load;
- other characters remain outside the active session;
- no new SavedVariables root;
- no LoadOnDemand companion added;
- cold blocks remain lazy;
- heatmap UI normalizes only the selected zone.

## 2. Cache bounds

| Cache | Bound | Release |
|---|---:|---|
| Journey block cache | 8 zones | LRU; cleared on window close |
| Heatmap selected-zone cache | 4 zones | LRU; cleared on window close |
| Full normalized heatmap cache | derived | cleared on window close |
| Map overlay cache | static art IDs | cleared on window close |
| UI heat cells/art tiles | active zone | released on heatmap tab leave/window close |

Eviction counters are retained for diagnostics:

- block evictions;
- heatmap-zone evictions;
- decoded block count;
- heatmap normalization count.

## 3. UI release

Added `ReleaseHeatmapUIResources()`:

- hides and releases heat cells;
- hides and releases art/overlay tiles;
- resets cell count and rendered state;
- keeps the panel, grid, and legend objects for reuse.

Release points:

- leaving the Heatmap tab;
- hiding/closing the main window.

Added `ReleaseTransientCaches()`:

- clears decoded block cache;
- clears selected-zone heatmap cache;
- clears full normalized heatmap cache;
- clears map overlay cache;
- releases heatmap UI resources.

Stored data is not deleted.

## 4. Diagnostics

Added `GetCacheStats()` and diagnostics rows:

- block cache zones/capacity/evictions;
- heatmap cache zones/capacity/evictions;
- normalized-zone count;
- overlay cache count;
- UI cell/art counts.

No arbitrary MB cap was introduced. Measured guardrails remain pending MEM-1.

## 5. Tests

`tests/mem_policy.lua` verifies:

- block LRU stays at 8 and counts evictions;
- heatmap-zone LRU stays at 4 and counts evictions;
- leaving the Heatmap tab releases cells/art;
- reopening rebuilds the pool;
- closing the window clears transient caches;
- stored heatmap and block data survive cache release;
- data still renders after release.

Passing output:

```text
Memory policy passed
```

`./tests/run_all.sh` passes.

## 6. Limitations

- No live memory sample; guardrails remain pending MEM-1/V-2.
- No LoadOnDemand companion.
- No arbitrary MB target.
- UI texture memory may not return to the OS immediately.
- Account Knowledge/merge remains deferred.

## 7. Next

**IMP-1B11 — Rollback retirement preparation.** Final flag removal remains
gated by the live-only V-2 residual checks.

## Artifacts

- `KillHistory/Module.lua`
- `KillHistory/JourneyStorage.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/UI/Heatmap.lua`
- `KillHistory/UI/Window.lua`
- `KillHistory/UI/Diagnostics.lua`
- `tests/mem_policy.lua`
- `tests/run_all.sh`
- `docs/tasks/MEM-2-LOAD-UNLOAD-POLICY.md`
