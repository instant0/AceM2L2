# G-1B — Heatmap commit-time position refresh result

**Status:** executed 2026-11-18  
**Production module:** `KillHistory/Tracking.lua`  
**Test:** `tests/heatmap_commit_position.lua`; `./tests/run_all.sh`  
**Scope:** one bounded heatmap-only change. No grid, schema, UI, or attribution
change.

## 1. Behavior

At the existing heatmap accounting point in `RecordKill`:

- the candidate snapshot must already contain valid `x`/`y` (replace-only);
- `GetPlayerMapPosition()` is read once at kill commit;
- fresh coordinates are used only when the fresh map equals the kill map;
- a fresh map mismatch skips the cell;
- a nil fresh read keeps the same-map snapshot;
- `info`, `db.areas`, `mob.killsByMap`, and instance attribution are untouched;
- one heatmap write per kill; late-chat `add_xp` never writes.

Attributable instance maps (real dungeon UI maps) keep their own heatmap entry.
Non-attributable instance maps still produce no world-map cell. A stale
open-world snapshot cannot become a world-map cell after zoning.

## 2. Implementation

Added a local `ResolveHeatmapPosition` helper in `Tracking.lua`:

- validates `0..1` coordinates;
- returns nil when the kill map is non-attributable;
- rejects stale snapshots when `inInstance` and the current instance map differs
  from the kill map;
- compares the fresh map ID with the kill map;
- falls back to the snapshot only for a nil/unavailable fresh read.

The existing `pcall(self.RecordHeatmapKill, ...)` call is unchanged apart from
using the resolved coordinates.

## 3. Tests

`tests/heatmap_commit_position.lua` covers:

- same-map movement → commit position wins;
- stale acquisition position is not used;
- cross-map change → no cell, attribution unchanged;
- fresh read nil → same-map snapshot fallback;
- missing snapshot → no cell (replace-only);
- out-of-range snapshot → no cell;
- late-chat `add_xp` → exactly one cell;
- group kill → local player position;
- non-attributable instance → no world-map cell;
- stale world snapshot after zoning → no cell;
- attributable instance map → own heatmap cell;
- death position unchanged;
- quest-anchor position unchanged.

Passing output:

```text
Heatmap commit position passed
```

`./tests/run_all.sh` passes.

## 4. Limitations

- No live client verification.
- The fresh read happens at kill commit, not at the exact damage event.
- Instance/vehicle behavior is based on current map attribution, not a live
  trace.
- Group kills still use the local player position by policy.
- No unit/world-position conversion; deferred by G-1A.

## 5. Rollback

Remove the `ResolveHeatmapPosition` call and pass `info.x`/`info.y` again. No data
migration is needed; the stored representation did not change.

## 6. Next

**HC-7 — Tracking-limit configurability decision** — executed 2026-11-18.
Result: `docs/HC-7-LIMIT-CONFIGURABILITY-RESULT.md`.

**UI-5 — Heatmap zone/instance selector** is next.

## Artifacts

- `KillHistory/Tracking.lua`
- `tests/heatmap_commit_position.lua`
- `tests/run_all.sh`
- `docs/tasks/G-1B-POSITION-REFRESH.md`
- `docs/G-1A-COORDINATE-REVIEW-RESULT.md`
