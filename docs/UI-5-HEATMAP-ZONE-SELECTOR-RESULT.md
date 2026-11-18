# UI-5 — Heatmap zone/instance selector result

**Status:** executed 2026-11-18  
**Production modules:** `KillHistory/UI/Heatmap.lua`,
`KillHistory/UI/Window.lua`, `KillHistory/UI/Theme.lua`  
**Test:** `tests/heatmap_selector.lua`; `./tests/run_all.sh`  
**Scope:** Heatmap tab selector only. No schema, storage, or block-format
change.

## 1. Selector

Added a dedicated `Select` button beside the existing `<` / `>` and
`Current zone` controls.

Opening it shows a bounded panel with up to 10 rows:

```text
Zone / Instance                         Kills   Levels
Hillsbrad Foothills                        10    10-12
Map 1424                                    5        8
Test Dungeon Heroic            Dungeon      7    20-22
Tirisfal Glades                             2        —
```

- alphabetical by display name, case-insensitive;
- deterministic map-ID tie-break;
- heatmap kills as the primary count;
- recorded player-level range;
- small `Dungeon` tag for instance maps;
- footer page indicator and mouse-wheel scrolling when more than 10 rows exist;
- selected row highlighted.

## 2. Data model

One row per heatmap map ID:

- zones come from the existing heatmap zone index;
- instance metadata is merged by `mapID`;
- multiple difficulty entries on one map collapse into one row;
- the most recently seen instance name wins for that map;
- level ranges are the union of `killsAtLevel` for instances and
  `db.areaLevels` for zones;
- non-heatmap instances and zones are excluded;
- kills fall back to area/instance totals only when a heatmap total is absent.

`RefreshHeatmapSelector` is the testable helper; it stores
`selectorEntries` on the heatmap UI table.

## 3. Interaction

- Clicking a row sets `heatmapZoneKey` and refreshes the existing heatmap.
- Arrow paging and `Current zone` still work.
- The menu closes on selection, Escape, click outside, tab change, window hide,
  or when heatmap UI resources are released.
- The selector button reflects open state.
- No new SavedVariables; selection stays in memory.

## 4. Tests

`tests/heatmap_selector.lua` verifies:

- rows build for zones and attributable instances;
- non-heatmap instances are excluded;
- duplicate instance map IDs merge into one row;
- alphabetical, case-insensitive ordering;
- heatmap kills and fallback behavior;
- player-level ranges and `—` when absent;
- Dungeon tag;
- visual row labels;
- duplicate map IDs are not duplicated;
- page count and offset scrolling;
- selection updates the heatmap;
- arrow paging still works;
- close on tab change, window hide, outside click, and resource release;
- Select button toggles the menu;
- Escape registration;
- no Journey block decode while building the list.

Passing output:

```text
Heatmap selector passed
```

`./tests/run_all.sh` passes.

## 5. Limitations

- No live visual/frame check; V-1 remains the visual gate.
- Level range is recorded player level, not a content level range.
- Non-heatmap instances are intentionally absent; they remain in the Areas tab.
- The selector uses a bounded 10-row pool with mouse-wheel scrolling, not a new
  scrollbar template.
- No account Knowledge.

## 6. Next

**DS-17.4D — Account Knowledge derivation prototype** (future/offline design
block), with MEM-1/V-1/V-2 remaining live gates.

## Artifacts

- `KillHistory/UI/Heatmap.lua`
- `KillHistory/UI/Window.lua`
- `KillHistory/UI/Theme.lua`
- `tests/heatmap_selector.lua`
- `tests/run_all.sh`
- `docs/tasks/UI-5-HEATMAP-ZONE-SELECTOR.md`
