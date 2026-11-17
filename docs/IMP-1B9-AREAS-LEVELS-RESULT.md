# IMP-1B9 — Areas/Levels parity and switch result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/JourneyQueries.lua`,
`KillHistory/UI/List.lua`, `KillHistory/Commands.lua`,
`KillHistory/Journey.lua`  
**Test:** `tests/areas_levels_parity.lua`; `tests/journey_queries.lua`;
`./tests/run_all.sh`  
**Scope:** overlap-safe Areas/Levels rows, switch behind the existing
`journey.indexViews` flag, and Journey reset consistency. No heatmap UI switch.

## 1. Parity model chosen

**Legacy counts remain canonical. Journey stats are reported separately.**

Reason:

- `db.areas`/`db.instances`/`db.levels` contain all history, including
  pre-Journey kills.
- `journey.zones`/`journey.levels` contain only post-instrumentation kills.
- The old `GetJourneyZoneStats` added the two together, which double-counts a
  kill once both paths have recorded it.
- Journey zone keys collapse world and instance kills into the same map ID, so a
  zone-level Journey kill count cannot safely replace the legacy area count.

This is a documented partial switch, not full legacy retirement. Full
retirement needs instance-aware Journey zones or a proven backfill.

## 2. Query APIs

Added:

- `GetAreaRows()` — legacy area + instance rows, names preserved;
- `GetLevelRows()` — legacy level rows.

Changed:

- `GetJourneyZoneStats()` no longer adds legacy kills to Journey kills. It
  returns:
  - `kills` — Journey-only kills;
  - `legacyKills` — legacy world-area kills separately.
- `GetJourneyLevelStats()` now also returns `legacyKills`.

This removes the double-counting hazard.

## 3. Switched paths

Behind `journey.indexViews = true` (default):

- Areas tab uses `GetAreaRows()`.
- Levels tab uses `GetLevelRows()`.
- `PrintAreas` uses `GetAreaRows()`.
- `PrintLevels` uses `GetLevelRows()`.

`journey.indexViews = false` restores the original inline legacy scans.

Added deterministic area tie-breaking by key so equal-kill rows are stable in
both paths.

## 4. Reset consistency

`ResetKills` now calls `ResetJourneyData()`:

- clears `char.journey` (zones, levels, time, blocks, backups);
- clears the Journey block cache;
- clears the Journey mob index.

Without this, a kill-history reset would leave old Journey zone/level stats and
blocks behind.

## 5. Tests

`tests/areas_levels_parity.lua` verifies:

- Areas list parity;
- Levels list parity;
- `PrintAreas` output parity;
- `PrintLevels` output parity;
- instance rows and names;
- excluded map IDs;
- empty-state parity;
- overlap-safe zone/level stats;
- rollback flag never calls the shared row path;
- reset clears Journey data and the mob index.

`tests/journey_queries.lua` now asserts Journey and legacy kills stay separate.

Passing output:

```text
Areas/Levels parity passed
Journey queries passed
```

`./tests/run_all.sh` passes.

## 6. Rollback policy

Rollback paths are kept only for three reasons:

1. **Data safety during migration** — legacy still holds history that Journey
   does not fully own.
2. **Live-client diagnosis** — a per-character flag can isolate a bad path
   without shipping a code rollback.
3. **Parity proof** — the legacy path is the comparison oracle until a switch is
   verified.

They are not meant to be permanent. There are now only two rollout flags:

- `journey.indexViews`;
- `journey.blockReadFallback`.

New switches should reuse these flags. After V-2 and heatmap UI verification,
**IMP-1B11 — rollback retirement** will remove the runtime flags and the legacy
duplicate paths. Emergency rollback then becomes a normal release/version
rollback, not a permanent code branch.

## 7. Remaining limitations

- Areas/Levels still rely on legacy counts as the canonical totals.
- Journey zones are not instance-aware at the aggregate level.
- Overview cards, footer, minimap, and area/level Detail still read legacy
  area/level tables directly.
- Heatmap UI remains legacy until a bounded selected-zone query exists.
- No account Knowledge/merge.

## 8. Next

**IMP-1B10 — Heatmap UI bounded query.**

- selected/current zone only;
- one block decode at most per refresh;
- cached by zone;
- top-N cells only;
- legacy fallback;
- no global cold scan;
- no new runtime flag.

Then **IMP-1B11 — Rollback retirement** after V-2 and heatmap verification.

## Artifacts

- `KillHistory/JourneyQueries.lua`
- `KillHistory/UI/List.lua`
- `KillHistory/Commands.lua`
- `KillHistory/Journey.lua`
- `tests/areas_levels_parity.lua`
- `tests/journey_queries.lua`
- `tests/run_all.sh`
- `docs/tasks/IMP-1B9-AREAS-LEVELS-PARITY.md`
- `docs/tasks/IMP-1B10-HEATMAP-UI-BOUNDED-QUERY.md`
- `docs/tasks/IMP-1B11-ROLLBACK-RETIREMENT.md`
