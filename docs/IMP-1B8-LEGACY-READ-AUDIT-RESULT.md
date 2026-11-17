# IMP-1B8 — Remaining legacy read audit and command switch result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/JourneyIndex.lua`,
`KillHistory/Commands.lua`  
**Test:** `tests/commands_index.lua`; `./tests/run_all.sh`  
**Scope:** remaining legacy-read inventory, safe command switch, and explicit
follow-up classification. No Areas/Levels/heatmap switch.

## 1. Command switch

### `PrintKills`

- Uses `GetJourneyMobsForFilter(nil, filter)` when
  `journey.indexViews` is enabled.
- Keeps the legacy `db.mobs` scan as the rollback path.
- Preserves output, top-15 limit, filter detail, XP fields, and empty state.
- Added a deterministic kills/key tie-break so tied kill counts are stable and
  identical in both paths.

### `PrintDump`

- Uses the new `GetJourneyAllMobRows()` when index views are enabled.
- `GetJourneyAllMobRows()` includes zero-kill tracked mobs, so the dump count
  matches the legacy scan.
- `GetJourneyMobRows()` still returns only killed mobs for list/Overview.
- Keeps the legacy scan as the rollback path.
- Preserves top-50 output and the same kills/key ordering.

## 2. Remaining-read inventory

| Area | Current source | Classification | Follow-up |
|---|---|---|---|
| Mobs list | Journey index | switched | — |
| Overview top mobs | Journey index | switched | — |
| `PrintKills` | Journey index | switched | — |
| `PrintDump` | Journey all-rows index | switched | — |
| Areas/Levels list | `db.areas`, `db.levels` | parity/backfill needed | IMP-1B9 |
| Overview area/level cards | `db.areas`, `db.levels` | parity/backfill needed | IMP-1B9 |
| Window footer area/level | `db.areas`, `db.levels` | parity/backfill needed | IMP-1B9 |
| Minimap top area | `db.areas` | parity/backfill needed | IMP-1B9 |
| Area/level Detail | `db.areas`, `db.levels` | parity/backfill needed | IMP-1B9 |
| `PrintAreas` / `PrintLevels` | `db.areas`, `db.levels` | parity/backfill needed | IMP-1B9 |
| `PrintStats` area/level/top-area | `db.areas`, `db.levels` | parity/backfill needed | IMP-1B9 |
| Area/level mob field detail | `db.mobs` | index-safe candidate | later |
| `PrintStats` mob count | `db.mobs` | index-safe candidate | later |
| Delete-by-name / delete-unknown | `db.mobs` | index-safe candidate | later |
| Heatmap zones/cells UI | legacy `db.heatmaps` via `GetHeatmapZones` | bounded query needed | IMP-1B10 |
| `GetHeatmapTopCells` | legacy `db.heatmaps` | bounded query needed | IMP-1B10 |
| Heatmap diagnostics/probe counts | legacy `db.heatmaps` | bounded query needed | IMP-1B10 |

### Intentional non-switches

These keep reading or writing legacy data by design:

- `Data.lua`, `Tracking.lua`, `Events.lua`: capture, merge, prune, and
  normalization.
- `Calibration.lua`: calibration needs the full mob population.
- `JourneyStorage.lua`: block build and legacy fallback.
- `JourneyIndex.lua`: index build source.
- `JourneyQueries.GetJourneyZoneStats`: intentional legacy + Journey dual-read.
- `Tooltip.lua` and `UI/Detail.lua`: legacy-first fallback behavior.

## 3. Rebuild and rollback

| Case | Index builds |
|---|---:|
| First command after invalidation | **1** |
| Repeated `kills` + `dump` + filtered `kills` | **0 additional** |
| Mutation + next command | **1 additional** |
| `journey.indexViews = false` | **0** |

## 4. Test result

`tests/commands_index.lua` verifies:

- `kills` output parity;
- filtered `kills` detail parity;
- empty-filter output parity;
- dump output and zero-kill count parity;
- tied-kill ordering parity;
- one build for repeated commands;
- one rebuild after mutation;
- rollback builds zero indexes.

Passing output:

```text
Command index switch passed
```

`./tests/run_all.sh` passes.

## 5. Limitations

- The index still builds from legacy `db.mobs`; it is not a persisted Journey
  store.
- Areas/Levels remain legacy until parity or backfill is proven.
- Heatmap UI remains legacy until a selected-zone bounded query exists.
- Deletion/statistics commands still use legacy scans.
- No account Knowledge/merge.

## 6. Next

**IMP-1B9 — Areas/Levels parity and switch.**

- measure legacy vs Journey area/instance/level totals;
- choose dual-read, backfill, or documented partial-data switch;
- switch Areas/Levels behind a flag with rollback;
- preserve instance rows and empty states;
- no heatmap UI switch.

Then **IMP-1B10 — Heatmap UI bounded query.**

## Artifacts

- `KillHistory/JourneyIndex.lua`
- `KillHistory/Commands.lua`
- `tests/commands_index.lua`
- `tests/run_all.sh`
- `docs/tasks/IMP-1B8-LEGACY-READ-AUDIT-COMMANDS.md`
- `docs/tasks/IMP-1B9-AREAS-LEVELS-PARITY.md`
- `docs/tasks/IMP-1B10-HEATMAP-UI-BOUNDED-QUERY.md`
