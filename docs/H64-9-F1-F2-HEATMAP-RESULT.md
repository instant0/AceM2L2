# H64-9-F1 + F2 — Heatmap rescale and disabled-state result

**Status:** executed 2026-11-16  
**Production module:** `KillHistory/UI/Heatmap.lua`  
**Test:** `tests/heatmap_render_ops.lua`; `./tests/run_all.sh`  
**Benchmark:** `tests/bench_heatmap.lua`  
**Scope:** no storage or schema change.

## 1. F1 — rescale path

- A max-cell change now recolors active cells without repositioning or
  re-showing them.
- Geometry work is performed only when:
  - the zone/geometry/theme changed (full rebuild); or
  - a newly active cell needs its first placement.
- Existing cells keep `SetPoint`/`SetSize`/`Show` untouched when only color or
  alpha changes.
- Stale cells are hidden once and removed from the rendered set.

Added `heatmap.renderOps` counters for geometry, show, hide, and color work.

Focused evidence:

| Refresh | Geometry | Show | Color |
|---|---:|---:|---:|
| First render, 100 active cells | 100 | 100 | 100 |
| Max-only rescale | **0** | **0** | 100 |
| One new active cell | **1** | **1** | **1** |

The dense benchmark rescale now reports **0 cell `SetPoint`/`SetSize`** work;
remaining color work is the intended 4,096-cell recolor. Timing varies with the
fixture process, so operation counts are the acceptance signal here.

## 2. F2 — disabled-state hide guard

- The first disabled refresh hides cells/art, hides the grid/legend/selector,
  and shows the disabled message.
- Subsequent disabled refreshes return immediately with no per-cell work.
- Re-enabling clears the guard and restores normal rendering.
- A later disable hides once again.

Focused evidence:

| Refresh | Cell hides |
|---|---:|
| First disabled refresh | > 0 |
| Repeated disabled refresh | **0** |
| Re-enable | normal render |
| Disable again | hides once |

The `disabled_square` benchmark scenario reports `disabled_ops Hide=0` on the
measured disabled path.

## 3. Tests

`tests/heatmap_render_ops.lua` verifies:

- initial geometry/show counts;
- max-only rescale performs zero geometry/Show work;
- new active cell gets exactly one geometry/Show pair;
- disabled cleanup happens once;
- repeated disabled refresh does zero cell work;
- re-enable resets the guard.

Passing output:

```text
Heatmap render ops passed
```

`./tests/run_all.sh` passes.

## 4. Limitations

- Live visual/frame confirmation remains a V-2/visual check.
- No display-detail cap, grid change, or storage change.
- Art-tile/overlay work is outside this task.

## 5. Next

**H64-9-F4 — Zone-scoped/lazy heatmap normalization.**

## Artifacts

- `KillHistory/UI/Heatmap.lua`
- `tests/heatmap_render_ops.lua`
- `tests/run_all.sh`
- `docs/tasks/H64-9-05-FOLLOWUP-WORK.md`
