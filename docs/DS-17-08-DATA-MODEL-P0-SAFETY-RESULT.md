# DS-17.8 — Data-model P0 safety result

**Status:** executed 2026-11-18  
**Scope:** offline P0 safety fixes only. No owner migration, no feature work.  
**Test:** `tests/p0_data_model_safety.lua`; `./tests/run_all.sh` passes.

## 1. Fixes

### P0-1 — Flush deletion safety

`FlushJourneyBlocks` no longer deletes an existing block merely because the
legacy source is empty. A dirty flush with no legacy records/cells keeps the
previous block and index. Deletion is explicit reset/compaction only.

### P0-3 — Stale block zones

- `GetJourneyHeatmapZones` filters to map IDs still retained in `char.heatmaps`.
- `SyncJourneyHeatmapIndex` zeroes `blockIndex.heatmapKills/lastSeen` and marks
  the map dirty when a legacy heatmap is removed.
- Heatmap-only blocks (`count == 0`) are deleted immediately.
- Mob-bearing blocks are kept and their cells are stripped on the next dirty
  flush.
- Clear and cap use the same sync path.

### P0-4 — `PrintHeatmap`

- Handles a Journey-only zone with `cells = nil`.
- Falls back to `GetJourneyHeatmapCells`.
- `CountCells` accepts numeric cells and `{ kills = ... }` cells.
- No command error when there is no legacy cell table.

### P0-5 — `mobZones` cap

- `journey.mobZones` is capped to 4 deterministic sorted refs per mob.
- Selected-zone lookup remains first; only unqualified cold fallback is bounded.

### P0-6 — Decode counter

- `StartSession` resets `journeyDecodedBlocks` and clears the block cache.
- A previous session/character cannot leak decode counts or cached blocks.

### P0-7 — Schema alignment

- `journey.schema` is now the data-model revision **2**, aligned with
  `storageSchema = 2`.
- The Journey test asserts the aligned value.

## 2. Tests

`tests/p0_data_model_safety.lua` verifies:

- block survives a legacy-empty dirty flush with unchanged index;
- clear/cap does not expose stale Journey zones;
- heatmap-only blocks are removed while mob-bearing blocks survive;
- Journey-only `PrintHeatmap` does not error and can read block cells;
- `mobZones` is capped at 4;
- `StartSession` resets decode count and cache;
- `journey.schema == storageSchema == 2`.

Passing output:

```text
P0 data-model safety passed
```

`./tests/run_all.sh` passes.

## 3. Limits

- P0-2 block payload v2 completeness is **not** included; it is S8.
- No owner migration (S1/S2) started.
- No legacy retirement.
- No live client verification.
- No account Knowledge/ALT/route work.

## 4. Next

**S1 — Schema/naming/ownership scaffolding** (DS-17.9).

## Artifacts

- `KillHistory/JourneyStorage.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/Events.lua`
- `KillHistory/Journey.lua`
- `tests/p0_data_model_safety.lua`
- `tests/journey.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-08-DATA-MODEL-P0-SAFETY.md`
