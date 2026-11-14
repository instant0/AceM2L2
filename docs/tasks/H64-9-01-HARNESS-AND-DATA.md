# H64-9.1 — Harness, fixtures, and benchmark data

**Status:** executed; harness exists and was used for the report  
**Parent:** H64-9  
**Owner:** offline benchmark engineer  
**Depends on:** H64-8, HC-5  
**Blocks:** H64-9.2, H64-9.3  
**Deliverable:** `tests/bench_heatmap.lua` and its fixture data

## Scope

Build a reusable offline harness around the real Lua modules and the UI mocks.
It must measure both the data model and the UI paths without a WoW client.

## Files and entry points

Data model:

- `KillHistory/Heatmap.lua`
  - `RecordHeatmapKill`
  - `NormalizeHeatmaps`
  - `GetHeatmapZones`
  - `ResetHeatmaps`
  - `ClearHeatmaps`
  - `InvalidateHeatmapCache`

UI:

- `KillHistory/UI/Heatmap.lua`
  - `RefreshHeatmap`
  - `SelectHeatmapZone`
  - `OnMapExplorationUpdated`
  - art/legend/cell creation
- `KillHistory/UI/Theme.lua`, `KillHistory/UI/Widgets.lua`

Harness base:

- `tests/fixtures.lua` — module init, C_Map mocks, UI object mocks,
  `AdvanceTime`, `RunTimers`, frame width/height, texture methods.
- `tests/smoke.lua` — examples of heatmap and UI assertions.
- `tests/measure_diagnostics.lua` — example of a file-driven utility.

## Assignment information

The harness owner is responsible for:

1. Creating the runnable script and its data generator.
2. Wrapping UI methods to count operations without changing behavior.
3. Producing machine-readable output (plain key=value or JSON) and a readable
   summary.
4. Keeping production modules untouched except for a separately approved bug
   fix.
5. Documenting exact commands and profile IDs.

Reviewer responsibilities:

- Verify the harness measures the production paths, not a copy.
- Verify operation counts are not double-counted.
- Verify no live-only APIs are required.
- Verify reports include raw data and interpretation separately.

## Instrumentation

### Timing

- `os.clock()` around pure Lua data paths.
- Report absolute time and per-cell/per-map scaling.
- Do not present offline timing as live frame time.

### Memory

- `collectgarbage("collect")` before and after each scenario.
- `collectgarbage("count")` in KB.
- Table/cell/row/art-tile counts.

### UI operations

Wrap or monkeypatch fixture methods and count calls:

- `CreateTexture`
- `SetPoint`
- `SetSize`
- `SetColorTexture`
- `Show`
- `Hide`
- `SetTexture`
- `SetTexCoord`
- `ClearAllPoints`

Counts must distinguish:

- cells
- art tiles
- overlay tiles
- legend swatches
- rows (if involved)

### Art paths

Run with:

- map art enabled;
- map art unavailable;
- reveal on/off;
- collection enabled/disabled.

Use mock art textures/coordinates for deterministic counts. Do not benchmark
actual loading of DB2 artwork.

## Data profiles

Define reusable profiles in the harness:

```lua
{
  id = "dense_1to1",
  shape = "1:1",
  activeCells = 4096,
  maps = 1,
  countDistribution = "uniform" | "skewed" | "few_hot",
  maxCount = 100,
  mapID = 1421,
  width = 1.0,
  height = 1.0,
}
```

Required fields:

- profile id;
- map count;
- active cell count;
- occupied/empty cell ratio;
- aspect ratio and shape;
- count distribution;
- maximum count;
- art on/off;
- reveal on/off;
- collection on/off.

## Data required

- Synthetic heatmap entries using the real schema:
  `gridSize=64`, `cells={[index]=count}`, `total`, `lastSeen`.
- Zone IDs that exist in the fixture `C_Map` mocks.
- Aspect-ratio geometry: 1:1, 4:1, 1:4, and an irregular/land-mask profile.
- Optional real shape from `/mnt/r/AceM2L2.lua` (2 zones, 193 cells).
- Map art mock: layers/tiles, explored overlays, static overlay entries.
- Settings: `heatmapEnabled`, `showHeatmap`, `revealUnexplored`,
  `heatmapIntensity`, `heatmapWarmColors`, theme.

## Harness commands

Planned:

```sh
lua tests/bench_heatmap.lua --list
lua tests/bench_heatmap.lua --scenario dense_1to1
lua tests/bench_heatmap.lua --all --format keyvalue
lua tests/bench_heatmap.lua --all --format csv
```

The script must fail loudly on missing fixtures or unexpected nil methods.

## File changes

- Add `tests/bench_heatmap.lua`.
- Add generated fixture data only if needed; prefer deterministic generation in
  Lua.
- Add no production dependencies.
- Update `PLAN.md` when the harness is committed.

## Execution notes

- `tests/bench_heatmap.lua` exists and runs with `--list`, `--scenario`, `--all`,
  and `--format csv`.
- Profiles are generated deterministically; wide/tall/irregular shapes use
  unique occupied indices.
- The 41-map profile selects the newest retained map (the oldest is pruned).
- First-render runs force rendered keys so the full path is measured.
- Each profile should be run in its own process for isolated memory; the
  all-in-one run accumulates the UI cell pool and is not a memory baseline.
- Fixture UI memory includes mock objects/frames and is not SavedVariables size.

## Acceptance criteria

- The harness initializes the real addon/module through fixtures.
- It can create a zone with explicit cell counts and render it.
- It counts data and UI operations separately.
- It can run every scenario from H64-9.2.
- It emits raw results suitable for H64-9.3.
- It does not alter saved variables or production defaults.

## Risks

- Fixture UI methods may not match live draw cost; treat counts as relative.
- Map-art mocks may over- or under-count tiles; keep art and data results split.
- `os.clock` may be coarse; use repeated runs and report variance.
