# AceM2L2 plan

Updated: 2026-11-13  
Current release: **2.1.6**  
Planning target: **2.2.0** — 64x64 heatmap; optional Carbonite overlay

## Active work

### 64x64 heatmap + optional Carbonite overlay (plan only)

**Status:** revised plan; no code implemented.  
**Recommendation:** ship the 64x64 default heatmap first, then the optional
Carbonite overlay through its public provider API. Do not embed Carbonite's map
frame.

---

## 1. Evaluation of the original Carbonite plan

### What was sound

- Using `Carbonite.Map:CreateProvider(name)` is the right integration surface.
  It is public, isolated per provider, and does not require private map frames.
- Embedding Carbonite's live map frame is not viable: it is a singleton,
  player-centered map driven by Carbonite's own tick, and there is no public API
  for an offscreen historical zone map.
- Keeping Carbonite optional, default-off, and capability-gated is correct.
- `ZR` pins are the most promising way to draw heat cells because Carbonite
  transforms zone rectangles into world/screen space and clips them with the
  map.
- Avoiding copied Carbonite code/assets is the correct licensing posture.

### Gaps and corrections found

1. **No live spike for `ZR`.** The plan assumed rectangle alignment, zoom, and
   clipping without proof. `ZR` is rarely used in Carbonite. This must be
   validated before building the full overlay, with a fallback to point pins or
   no overlay if it fails.
2. **No explicit heatmap-data change hook.** Carbonite's `OnMapChanged` only
   fires when Carbonite's visible map changes. A kill, reset, or import while
   the Carbonite map is open also needs to rebuild the overlay.
3. **No late-detection plan.** Carbonite may be absent, disabled, or loaded after
   Kill Story. Detection must be retried at `PLAYER_LOGIN`, when the heatmap is
   opened, and when the setting is toggled. File scope must never touch
   Carbonite.
4. **Map ID matching was underspecified.** Exact match is not enough. Carbonite
   may show a child/subzone or parent map. The overlay needs a bounded
   parent/child walk and a deterministic "no match means clear" rule.
5. **Overlay resolution was arbitrary.** A fixed 16x16 overlay throws away much
   of the new 64x64 detail. Use adaptive bucketing: 32x32 when the non-empty
   bucket count fits the pin cap, otherwise 16x16.
6. **Pins must never follow the Kill Story zone pager.** The overlay follows
   Carbonite's visible map. Selecting a different zone in Kill Story must not
   move Carbonite's map or rebuild pins for an unrelated zone.
7. **Options visibility was not addressed.** If Carbonite is not detected, the
   setting should be omitted or clearly unavailable, and enabling it must not
   create a provider.
8. **Performance and failure isolation were not testable.** There were no
   pin-count, frame-cost, fault-injection, or session-disable criteria.
9. **The plan had no task breakdown, sequencing, or release gates.** Those are
   added below.

### Verdict

The public-API overlay is feasible and worth building, but only after a live
`ZR` spike. The original plan was directionally correct; this revision adds the
missing validation gate, data-change sync, adaptive detail, failure handling,
and task structure.

---

## 2. Evaluation of 64x64 default heatmap

### Benefits

- Four times the spatial resolution of the current 32x32 grid.
- Better hotspot shape and finer grinding-spot detail.
- Matches the detail level of the tiled zone-map art.
- Sparse storage means most zones will not store all 4,096 cells.

### Costs and risks

- **UI texture count:** the current panel pre-creates one texture per cell. A
  naive `GRID_SIZE = 64` change would create 4,096 textures at panel creation
  and update all of them on every refresh. This is the main implementation risk.
- **Migration:** existing 16x16 and 32x32 data must be split into 64x64 cells
  while preserving totals, including remainders.
- **SavedVariables growth:** worst case is 40 zones x 4,096 cells. Sparse data
  is fine; dense data must be measured.
- **Small-window legibility:** at the minimum window size, 64x64 cells become
  very small. The layout needs a minimum-size check and a sensible gap policy.
- **Downgrade:** older Kill Story versions do not understand 64x64 cells and may
  drop them. This must be documented.
- **Carbonite overlay:** drawing 1,024 or 4,096 pins is not acceptable. The
  overlay must stay bucketed and capped.

### Verdict

64x64 is feasible and recommended **only with lazy cell creation**. Do not
simply change the constant. Keep 64x64 as the data resolution; if live testing
shows the display is too heavy or unreadable, add a display-detail fallback
(64 or 32) while keeping the stored data at 64.

---

## 3. Revisions in this version

- Added a live `ZR` spike as a hard gate before Carbonite overlay work.
- Added a 64x64 default heatmap workstream and evaluated its real costs.
- Added generic 16/32-to-64 migration with remainder preservation.
- Added lazy heat-cell pooling so sparse zones do not allocate 4,096 textures.
- Added a minimum-window layout check and adaptive gap rule.
- Replaced fixed 16x16 Carbonite buckets with adaptive 32x32 / 16x16 bucketing,
  capped at 256 pins.
- Added `NotifyHeatmapChanged` so kills, resets, and imports refresh the overlay.
- Clarified that the overlay follows Carbonite's map, not Kill Story's pager.
- Added parent/child map ID resolution with deterministic fallback.
- Added performance, SavedVariables, downgrade, fault-injection, and live-test
  acceptance criteria.
- Added a full task backlog, dependencies, sequencing, and release gates.

---

## 4. Revised design

### A. Default heatmap: 64x64

**Data model**
- `HEATMAP_GRID_SIZE = 64`; `HEATMAP_CELLS = 4096`.
- New entries always store `gridSize = 64`.
- `GetHeatmapZones()` includes `gridSize` in each zone record so renderers can
  validate the source resolution.
- Capture uses the existing formula with 64:
  `col = floor(px * 64) + 1`, `row = floor(py * 64) + 1`.
- `MAX_HEATMAP_MAPS`, `MAX_HEATMAP_COUNT`, and sparse cell storage stay
  unchanged.

**Migration**
- Add a generic `UpgradeCells(sourceCells, sourceGrid, targetGrid)`:
  - 16x16 -> 64x64: each cell becomes a 4x4 block (16 cells).
  - 32x32 -> 64x64: each cell becomes a 2x2 block (4 cells).
  - 64x64 -> 64x64: copy.
  - Split counts as evenly as possible; distribute the remainder one per cell
    until exhausted. The sum must equal the original count.
- Detect source grid from `entry.gridSize` when present.
- Legacy entries without `gridSize`:
  - max cell > 256 => 32x32
  - otherwise => 16x16 (preserve current behavior and document the ambiguity)
  - max cell > 1024 => invalid for known grids; skip those cells safely.
- Normalize to 64x64 in `MergeCells`/`MergeMapEntry`; never write a source grid.

**UI**
- `GRID_SIZE = 64` in `KillHistory/UI/Heatmap.lua`.
- `CreateHeatmapPanel` must not pre-create 4,096 textures. Start with an empty
  cell pool.
- Add `GetHeatCell(heatmap, poolIndex)` that creates a texture only when needed.
- `RefreshHeatmap`:
  1. Build an `active` list of cell indices with count > 0.
  2. Compute the maximum while building the list.
  3. For each active cell, take/create a pool cell, position it, color it, show
     it.
  4. Hide unused pool cells above the active count.
- Empty cells stay hidden so the zone-map art remains visible.
- Pool size grows to the number of non-empty cells, not 4,096.
- Keep the existing map-art layer below heat cells and above the grid backdrop.
- Layout:
  - `stride = max(1, floor(side / 64))`.
  - Use a 1px gap only when `stride >= 8`; at smaller sizes use the full stride
    to avoid a dotted/illegible grid.
  - `cellSize` must never be below 1.
  - Verify at the minimum 900x600 window, the default 1150x780 window, and the
    maximum size.

**Commands and output**
- `PrintHeatmap` continues to report cell-center percentages using 64.
- Legend text remains "Low -> High"; max cell and zone total are unchanged.
- No new user-facing setting is required for 64x64. If performance forces a
  fallback, add `heatmapDetail = 64|32` with default 64 and keep stored data at
  64.

### B. Optional Carbonite overlay

**Detection and lifecycle**
- New module: `KillHistory/Integrations/Carbonite.lua`, loaded after
  `KillHistory/Heatmap.lua` and before the UI files.
- The file must not touch Carbonite at load time.
- Detect:
  - `_G.Carbonite` is a table.
  - `Carbonite.Map` is a table.
  - `Carbonite.Map.CreateProvider` is a function.
- Retry at `PLAYER_LOGIN`, on heatmap open, and on setting toggle. Optionally
  listen for `ADDON_LOADED` for `"Carbonite"` if the event is already installed.
- Cache the capability result; do not compare Carbonite or interface versions.
- On module disable, logout, or fatal provider error, clear pins and disable the
  provider for the session.

**Setting and options**
- `db.xpTooltip.carboniteHeatmap`, default `false`.
- Add to `XPTOOLTIP_DEFAULTS`; sanitize in `SanitizeXPTooltipSettings`.
- Additive boolean; no schema bump.
- Show "Show heatmap on Carbonite map" under the World section when the
  capability is available. If unavailable, omit it or show it disabled with a
  short explanation; do not create a provider.
- If the setting is enabled but Carbonite is no longer available, force it false
  and print a short message.

**Provider and pins**
- Provider name: `"KillStoryHeatmap"` (stable and unique).
- Pin kind: `"Cell"`, `drawMode = "ZR"`, no class texture.
- Per-pin fields: `mapID`, `x`, `y`, `x2`, `y2`, `color`, optional `tip`.
- `ZR` coordinates are zone percent in the range 0..100, top-left origin,
  Y increasing downward.
- Color: `{r, g, b, a}` or `"AARRGGBB"`; alpha approximately
  `0.30 + 0.70 * (count / maximum)`.
- Tooltip: `"N kills"`.
- Never add a pin for an empty bucket.

**Adaptive bucketing**
- Source grid is 64x64.
- Target 32x32 first (2x2 source cells per bucket).
- If non-empty target buckets exceed 256, rebuild at 16x16 (4x4 source cells per
  bucket).
- If an 8x8 target is ever needed (it should not be), stop at 8x8.
- Cap at 256 pins per zone. This is a hard cap, not a suggestion.
- Reuse a shared bucket helper; do not duplicate aggregation math in the UI and
  the integration.

**Map matching**
- Exact map ID match first.
- Then walk the Carbonite map's `parentMapID` chain up to three levels and use
  the first heatmap zone found.
- Do not aggregate child zones onto a continent map in the first release. Clear
  instead.
- If multiple zones match, prefer exact, then nearest parent, then the most
  recently seen zone.
- No match means `Clear()`.
- Never change Carbonite's selected map from Kill Story.

**Sync**
- `OnMapChanged(mapID)` from Carbonite: rebuild for the new map.
- `NotifyHeatmapChanged(reason)` from Kill Story data mutations: rebuild if the
  current Carbonite map still matches.
- Setting toggle: enable + rebuild, or clear + disable.
- Heatmap reset/import: clear or rebuild as appropriate.
- Zone-pager changes: no effect on Carbonite.
- Never rebuild every frame.

**Failure isolation**
- Wrap every Carbonite call in `pcall`.
- If provider creation or pin definition fails, mark unavailable for the session
  and leave the normal heatmap untouched.
- If an `Add` fails, clear the layer and disable the overlay; do not leave a
  partially rendered heatmap.
- Do not hook Carbonite internals, replace its frames, or mutate its map state.
- Do not add Carbonite to `OptionalDeps` or any required dependency list.

**Probe**
- `/xpt probe` adds:
  - `carbonite` = detected yes/no
  - `carboniteProvider` = provider created yes/no
  - `carboniteMapID` = Carbonite's current map ID, if available
  - `carbonitePins` = current provider pin count
  - `heatmapGrid` = stored grid size

### C. Shared geometry and data helpers

- `Heatmap:GetCellRect(cell, gridSize)` returns `x1, y1, x2, y2` in percent.
- `Heatmap:GetCellIndex(row, col, gridSize)` returns the 1-based cell index.
- `Heatmap:BuildBuckets(cells, sourceGrid, targetGrid)` aggregates sparse cells
  and returns only non-empty buckets with their sums.
- The UI uses `GetCellRect` for percent math; it may keep a separate pixel-layout
  calculation for `SetPoint`/`SetSize`.
- The Carbonite module uses `GetCellRect` and `BuildBuckets`; it must not
  reimplement row/col or migration logic.

---

## 5. Task backlog

Tasks are not started. Check them off as they are completed.

### Shared foundation

- [ ] **S-1 — Heatmap geometry helpers (S).**
  - Add `GetCellRect` and `GetCellIndex` to `KillHistory/Heatmap.lua`.
  - Update `KillHistory/UI/Heatmap.lua` to use the shared percent math.
  - Done when round-trip tests pass for 16, 32, and 64 grids and the UI no
    longer contains duplicate index-to-percent calculations.

- [ ] **S-2 — Generic grid migration (M).**
  - Add `UpgradeCells(sourceCells, sourceGrid, targetGrid)` with even split and
    remainder distribution.
  - Detect source grid from `gridSize`; keep the legacy max-cell heuristic.
  - Done when 16x16 -> 64x64, 32x32 -> 64x64, and 64x64 -> 64x64 preserve all
    counts and stay within 1..4096.

- [ ] **S-3 — Heatmap change notification (S).**
  - Add `XPTooltip:NotifyHeatmapChanged(reason)` as a soft dispatch.
  - Call it after successful `RecordHeatmapKill`, `ResetHeatmaps`, and any
    import/restore path.
  - Done when a mock listener receives the notification and no listener is
    required for normal operation.

### 64x64 default heatmap

- [ ] **H64-1 — Switch the data model to 64x64 (S).**
  - Set `HEATMAP_GRID_SIZE = 64`, `HEATMAP_CELLS = 4096`.
  - Write `gridSize = 64` for new and normalized entries.
  - Include `gridSize` in `GetHeatmapZones()` records.
  - Done when capture, zone listing, and new-entry creation use 64.

- [ ] **H64-2 — Migrate existing data (M).**
  - Use S-2 inside `MergeCells`/`MergeMapEntry`.
  - Upgrade 16x16 and 32x32 entries to 64x64.
  - Preserve totals; do not drop counts through integer division.
  - Done when migration tests and total-preservation tests pass.

- [ ] **H64-3 — Lazy heat-cell pool (M).**
  - Remove the 4,096-texture preallocation from `CreateHeatmapPanel`.
  - Add lazy `GetHeatCell` creation and reuse.
  - Render only non-empty cells; hide unused pool cells.
  - Done when a sparse heatmap creates only the active cell count, and a dense
    heatmap still renders correctly.

- [ ] **H64-4 — 64x64 layout and resize (S).**
  - Recompute `stride`/`cellSize` for 64.
  - Use a 1px gap only at `stride >= 8`; otherwise use full stride.
  - Verify minimum, default, and maximum window sizes.
  - Done when cells do not overlap, never go below 1px, and the grid remains
    centered over the map art.

- [ ] **H64-5 — Capture, print, and legend math (S).**
  - Verify cell capture at 64 for boundary coordinates.
  - Update `PrintHeatmap` percentages and any legend copy.
  - Done when the printed cell center matches the visual cell.

- [ ] **H64-6 — Performance and data-volume gate (M).**
  - Measure refresh time for sparse and dense zones versus the current 32x32
    baseline.
  - Measure SavedVariables growth with a dense 40-zone fixture.
  - Add debug-only timing output if useful.
  - If the display is too heavy or unreadable, add `heatmapDetail = 64|32`
    (default 64) that aggregates for display while keeping stored data at 64.
  - Done when numbers are recorded and the fallback decision is documented.

### Carbonite overlay

- [ ] **CB-0 — Live `ZR` spike (M; hard gate).**
  - With Carbonite Retail installed, create a temporary provider with one `ZR`
    rectangle and a few point pins.
  - Verify alignment at multiple zoom levels, panning, clipping, map change,
    layer visibility, and approximate frame cost.
  - Done when results are recorded and a decision is made: proceed with `ZR`,
    fall back to point pins, or stop the overlay.
  - Do not start CB-3 until this passes.

- [ ] **CB-1 — Detector and lifecycle (S).**
  - Add `KillHistory/Integrations/Carbonite.lua` with no file-scope Carbonite
    access.
  - Implement the capability check, retries, cache, and session disable.
  - Register the file in the TOC after `KillHistory/Heatmap.lua`.
  - Done when absent, late, and partial Carbonite mocks never error.

- [ ] **CB-2 — Setting, options, and probe (S).**
  - Add `carboniteHeatmap` to defaults and sanitization.
  - Add the options checkbox when available.
  - Add the probe fields.
  - Done when enabling with no Carbonite is a safe no-op and probe output is
    accurate.

- [ ] **CB-3 — Provider and adaptive buckets (M).**
  - Create `KillStoryHeatmap` and define `Cell` with `drawMode = "ZR"`.
  - Implement 64 -> 32 -> 16 bucket selection with the 256-pin cap.
  - Add colors, tooltips, and source `mapID`.
  - Done when mock tests verify bucket counts, coordinate ranges, colors, and
    the cap.

- [ ] **CB-4 — Map matching and sync (M).**
  - Implement exact and parent-chain matching with a three-level limit.
  - Handle `OnMapChanged`, `NotifyHeatmapChanged`, toggle, reset, and import.
  - Ignore Kill Story zone-pager changes.
  - Done when map-change, no-data, parent, and reset tests pass.

- [ ] **CB-5 — Failure isolation (S).**
  - Wrap all Carbonite calls in `pcall`.
  - Clear and disable on provider/pin errors.
  - Clear on module disable and logout.
  - Done when fault-injection tests leave normal Kill Story behavior intact.

- [ ] **CB-6 — Optional-Carbonite documentation (S).**
  - Add a user-facing section to `README.txt`.
  - Add a developer section to `README.md` covering the public API, capability
    gate, bucketing, GPL note, and no-dependency rule.
  - Done when the docs state that Carbonite is optional and that no map frames
    or assets are copied.

### Tests and release

- [ ] **T-1 — Test fixtures and mocks (M).**
  - Add Carbonite absent / partial / provider mocks.
  - Add 16x16, 32x32, and 64x64 heatmap fixtures.
  - Support late detection and provider fault injection.
  - Done when fixtures can drive every scenario below without global leakage.

- [ ] **T-2 — Offline behavior assertions (M).**
  - 16 -> 64 and 32 -> 64 migration; totals preserved.
  - 64x64 capture at boundaries and printed cell centers.
  - Lazy pool creates only non-empty cells.
  - Carbonite absent, no provider, enabled, map change, parent fallback, reset,
    toggle, 256-pin cap, provider error, and Forever with no provider.
  - Done when all assertions pass in every existing scenario.

- [ ] **T-3 — Layout and load-order checks (S).**
  - Add the integration file to `AceM2L2.toc` in the correct position.
  - Update `tests/check_layout.py` expectations if needed.
  - Done when layout validation passes.

- [ ] **T-4 — Full offline and release validation (S).**
  - Run `luac -p`, `./tests/run_all.sh`, LuaJIT checks, and
    `CHECK_RELEASE=1 ./tests/run_all.sh`.
  - Build the zip and verify both SHA-256 copies.
  - Done when all checks pass.

- [ ] **T-5 — Live verification matrix (M).**
  - Retail + Carbonite: multiple zones, multiple zoom levels, map open/closed,
    toggle on/off, UI reload, combat, instance map, continent map, and data
    reset.
  - Retail without Carbonite: no errors, no option if unavailable, normal
    heatmap unchanged.
  - Older Carbonite without `CreateProvider`: feature hidden, no errors.
  - Forever: feature unavailable, normal heatmap works.
  - Done when the checklist is complete and frame cost is acceptable.

- [ ] **T-6 — Version, docs, and release (S).**
  - Bump to the agreed version (2.2.0 if both features ship together; otherwise
    release 64x64 first and Carbonite as a follow-up).
  - Update `README.txt`, `README.md`, `BROCHURE.md`, and release metadata.
  - Done when the release check passes and the plan is updated to remove
    completed work from Active.

---

## 6. Sequencing

1. **S-1, S-2.** Geometry and migration foundation.
2. **H64-1 through H64-5.** 64x64 data and UI.
3. **H64-6.** Measure; decide whether a display fallback is needed.
4. **CB-0.** Live `ZR` spike. This can run in parallel once a Carbonite test
   client is available, but it must pass before CB-3.
5. **S-3, CB-1, CB-2.** Notification, detection, setting, and probe.
6. **CB-3, CB-4, CB-5.** Provider, bucketing, matching, sync, and failure
   isolation.
7. **T-1 through T-5.** Offline and live verification.
8. **T-6.** Release.

If the Carbonite gate fails, ship the 64x64 heatmap first and keep the Carbonite
overlay as a deferred item.

---

## 7. Acceptance criteria

### 64x64 heatmap

- New kills record into a 64x64 grid.
- Existing 16x16 and 32x32 data migrates without losing counts.
- A sparse zone creates only its non-empty heat-cell textures, not 4,096.
- The grid remains centered, legible, and non-overlapping at minimum, default,
  and maximum window sizes.
- Printing a cell reports the same center the UI displays.
- No visible stutter on refresh; dense-zone behavior is measured and documented.

### Carbonite overlay

- Without Carbonite, Kill Story behaves exactly as before: no provider, no new
  errors, no dependency.
- With the setting off, no pins and no visual change.
- With Carbonite and the setting on, heat cells appear on Carbonite's map for
  zones with data, align at multiple zoom levels, and update on map change.
- The overlay never exceeds 256 pins and never rebuilds every frame.
- Disabling the setting, resetting heatmaps, or losing Carbonite clears pins
  immediately.
- A provider error disables the overlay for the session without breaking the
  normal heatmap.
- `/xpt probe` reports detection, provider state, map ID, pin count, and grid
  size accurately.
- No Carbonite code, data table, or asset is copied into AceM2L2.

---

## 8. Performance and data budgets

- **Heatmap refresh:** compare 64x64 against the current 32x32 baseline for
  sparse and dense zones. Investigate any visible stutter; do not accept a
  regression just to keep the constant.
- **Cell pool:** size equals the number of non-empty cells. A dense zone may
  legitimately reach 4,096; record its cost.
- **SavedVariables:** measure a dense 40-zone fixture. If growth is
  unacceptable, revisit map limits or pruning before release.
- **Carbonite:** hard cap of 256 pins per zone. If frame cost is visible,
  coarsen to 16x16 or 8x8 rather than raising the cap.
- **No per-frame rebuilds.** Carbonite rebuilds only on map change, data change,
  or toggle.

---

## 9. Risks and stop conditions

- **`ZR` misalignment or clipping:** stop CB-3 and fall back to point pins or
  defer the overlay.
- **64x64 UI stutter:** add the `heatmapDetail = 32` display fallback while
  keeping 64x64 data.
- **64x64 unreadable at minimum window:** add the display fallback or raise the
  minimum window size; do not silently make cells sub-pixel.
- **SavedVariables too large:** measure first; then consider pruning or a lower
  map cap. Do not change retention silently.
- **Carbonite API absent/changed:** capability gate and hide the option; never
  hardcode a Carbonite or interface version.
- **Map ID mismatch:** clear rather than drawing pins on the wrong map. Add a
  probe/debug value for troubleshooting.
- **GPL/private-table pressure:** keep C2/C3 deferred; public API only for the
  first release.

---

## 10. Out of scope

- Embedding, moving, or reskinning Carbonite's live map frame.
- Using Carbonite's radar/minimap tiles as the default heatmap background.
- Copying Carbonite source, map data, or textures into AceM2L2.
- Requiring Carbonite for any normal Kill Story feature.
- Carbonite support on Forever 1.60.1 unless Carbonite itself ships a compatible
  provider API.
- Aggregating child-zone heatmaps onto a continent map in the first release.

---

## Deferred

### KillStory as a separate addon

Deferred until explicitly approved. When revisited, decide:

- Data ownership and SavedVariables location.
- Public AceM2L2 API, callbacks, capabilities, and version handshake.
- Tooltip ownership between AceM2L2 text and KillStory GUI.
- Two-addon packaging, dependency/load order, and missing-dependency behavior.
- Migration and downgrade behavior.
- Tests for the API contract and load order.

Do not implement the split before those decisions are accepted.

### Carbonite private-table art integration

Deferred. This covers the legacy `Interface\WorldMap\...` fallback and the
radar-detail `World\Minimaps\...` underlay. Both require private Carbonite
tables, coordinate transforms, and GPL review. Revisit only after the public
provider overlay ships and only with explicit approval.
