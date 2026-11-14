# AceM2L2 plan

Updated: 2026-11-14  
Current release: **2.4.4**

## Plan map

| Workstream | Status | Task group |
|---|---|---|
| 64x64 heatmap | Implemented; static audit done, benchmark open | H64-9/H64-10; V-1 |
| Full generated map overlays | Implemented in 2.3.0; static review first | R-5/R-9/R-10; V-5 |
| Heat alpha | Superseded by the 2.4.4 gradient | A-3; V-1 |
| Heat intensity/warm colors | Implemented in 2.4.0; gradient in 2.4.4 | HC-1/A-2/A-3; V-1 |
| Data diagnostics | Implemented in 2.4.0; static review first | HC-2; V-2 |
| README feature guide | Completed in 2.4.1 | HC-6 |
| Documentation claim audit | Completed | — |
| Scope/grid/limit review | Static/offline analysis first | SC-1..SC-5, G-1..G-4b, A-1, HC-7; V-3 |
| Data storage architecture | Static/offline investigation | DS-1..DS-16; V-2 |
| Journey overlay | Proposed, after DS | J-1..J-6; V-4 |
| Cell inspector | Proposed, after DS | M-1..M-6; V-4 |
| Carbonite | Deferred | CB-0..CB-6 when reopened |
| KillStory split | Deferred | Decision list |
| Final live validation | Deferred until all static work is done | V-1..V-6 |

### Completeness check since 2.3.0

Covered in this plan:

- 64x64 heatmap and migration (2.3.0)
- full generated map overlays and reveal setting (2.3.0)
- stronger heat alpha (2.3.1)
- heat intensity/warm colors and data diagnostics (2.4.0)
- feature-focused README rewrite (2.4.1)
- grid-resolution/coordinate reliability review
- 2x/4x/6x limit scope review
- API-first storage architecture investigation
- Journey overlay proposal
- 4x4 hover cell inspector proposal
- Carbonite and KillStory split deferred work

Structural corrections: completed 2.3.0 full-map work moved out of Deferred;
H64 and CB task IDs added; a plan map and completeness check now precede the
workstreams.

### Validation policy

Default to **static validation first**:

- read the current code and call sites;
- check WoW API documentation and client-loading rules;
- inspect generated data and SavedVariables files offline;
- build synthetic datasets and offline Lua harnesses;
- review release artifacts and README claims against code.

Live in-game checks are consolidated into **one final validation phase** after
the static/open work. Do not create a separate in-game test task for every
feature.

## Recommended execution order

### Phase 1 — static audit of shipped work

Do these first; they are code/data/documentation reviews, not live tests.

Done:

- [x] **H64-8 — Static implementation audit.** Data model, migration, lazy
  cells, cache, and tests reviewed; extra coverage and the rescale fix landed.
- [x] **A-1 + HC-4 — Static heatmap visual review.** Formula, theme colors,
  intensity multiplier, warm palette, cache keys, and theme hook reviewed.
- [x] **A-3 — Multi-stop heat gradient.** Hue + alpha ramp, contrast-based
  intensity, gradient legend, and offline 1..13 spread tests.

Next:

1. **H64-9 — Offline dense-zone benchmark.** Synthetic refresh/memory check;
   fold the result into the later DS-3/SC-2 harness.
2. **HC-5 — Offline diagnostics review.** Compare the size estimate with
   synthetic/real SavedVariables data.
3. **R-4 — Static overlay/art audit.** Art-ID selection, overlay bucketing,
   phases, tile coordinates, cache keys.

### Phase 2 — storage evidence

This is the critical path for limits, Journey, and the inspector.

1. **DS-1 — Consumer inventory.**
2. **DS-2 — Real-store baseline.**
3. **DS-5 — SavedVariables/loading API matrix.**
4. **DS-6 — Static metadata feasibility.**
5. **DS-3 — Synthetic scale matrix.**
6. **DS-7 — Packing/compression feasibility.**

### Phase 3 — storage design and prototypes

1. **DS-4 — Schema prototypes.**
2. **DS-8 — Display redesign study.**
3. **DS-9 — Retention and migration.**
4. **DS-12 — Packed block codec.**
5. **DS-13 — On-demand companion packaging.**
6. **DS-14 — Constant-table/oversize guard.**
7. **DS-15 — Lazy retrieval/cache.**
8. **DS-16 — Save/checkpoint policy.**
9. **DS-10 — Offline prototype.**
10. **DS-11 — Decision record.**
11. **H64-10 — Schema/downgrade decision.** Decide schema `1` vs a bump after
    DS-9/DS-11; this is not a Phase 1 decision.

### Phase 4 — limits and grid decisions

Run after DS-2/DS-3 measurements:

1. **SC-1 — Real-store measurement.**
2. **SC-2 — 2x/4x/6x benchmark.**
3. **SC-3 — Choose tier.**
4. **SC-4 — Context cap.**
5. **SC-5 — Migration/pruning/tests.**
6. **G-1 — Coordinate code review.**
7. **G-2 — 64 vs 96/128 occupancy study.**
8. **G-3 — Grid decision.**
9. **HC-7 — Tracking-limit configurability decision.**

### Phase 5 — proposed features

Only after DS-11:

1. **J-1..J-6 — Journey overlay.**
2. **M-1..M-6 — Cell inspector.**

### Phase 6 — final live validation

Only after all static work:

- **V-1..V-6**, plus deferred Carbonite checks if reopened.

### Consolidation candidates

Before executing Phase 2/4, merge overlapping work where practical:

- **H64-9 + SC-2 + DS-3:** one synthetic measurement harness for 64/96/128 grids,
  1x/2x/4x/6x caps, and sparse/dense zones.
- **HC-5 + SC-1 + DS-2:** one real-store/offline diagnostics measurement pass.
- **DS-4 + DS-10:** one schema prototype harness; the live prototype is V-2.
- **DS-7 + DS-12:** one packing study that chooses the codec before implementing
  it.

## Workstreams and status

### 64x64 heatmap — implementation complete; static review open

**Status:** code and tests are unchanged; the 2.4.1 documentation release is done.
Static review and offline benchmarks come first; live checks are consolidated in V-1. Carbonite work is deferred.

**Implemented**

- `HEATMAP_GRID_SIZE = 64`, `HEATMAP_CELLS = 4096`.
- Generic migration:
  - 16x16 -> 64x64: each cell becomes a 4x4 block.
  - 32x32 -> 64x64: each cell becomes a 2x2 block.
  - 64x64 -> 64x64: copied unchanged.
  - Counts are split evenly with remainders preserved.
- `GetHeatmapZones()` exposes `gridSize`; CLI percentages use the zone's grid.
- Heat cells are created lazily per used index; the panel no longer preallocates
  4,096 textures.
- Incremental refresh updates only changed cells when the zone, geometry, theme,
  and maximum are unchanged; a changed maximum now recolors active cells in
  place, and only zone/layout/theme changes trigger a full rebuild.
- A normalized-heatmap cache prevents copying every cell on each UI refresh.
- 64x64 layout uses a 1px gap only when `stride >= 8`; smaller windows keep
  readable full-stride cells.
- Offline coverage now includes 64x64 capture, 16/32-to-64 migration, lazy cell
  creation, incremental refresh, and cache reuse.
- Discovered-area map overlays are composited above the base zone art using
  `C_MapExplorationInfo.GetExploredMapTextures`; mouseover-only highlights are
  not baked into the static background.

**Remaining**

- [x] **H64-8 — Static implementation audit.** Reviewed the data model,
      migration, lazy-cell paths, incremental refresh, cache invalidation, and
      tests.
      - Added offline coverage for the 40-map cap, duplicate numeric/string map
        keys, legacy remainder distribution, reset/cache invalidation, and
        stale-cell hiding.
      - Fixed a per-kill full rebuild: a new per-zone maximum now recolors
        active cells in place instead of hiding and re-showing the whole pool.
      - Residual risk: a 32x32 save with no `gridSize` and every cell index
        `<= 256` is inferred as 16x16. Saves written since 2.2.0 always carry
        `gridSize = 64`, so this only affects a user skipping 2.2.0. Keep the
        current 16x16 default and document it under H64-10.
- [ ] **H64-9 — Offline dense-zone benchmark.** Use the Lua harness/synthetic
      data to measure refresh and memory growth, including how often a new
      maximum triggers a rescale and how map-cap pruning behaves. Live frame cost
      is deferred to V-1.
- [ ] **H64-10 — Schema/downgrade decision.** Decide whether to bump the
      per-client data schema for 64x64. It is currently `1`; the downgrade caveat
      is documented. Record the legacy 16/32 inference ambiguity here and decide
      whether to keep the 16x16 default or force `gridSize` during migration.
- Live checks: consolidated under V-1.

### Documentation claim audit — completed

Most headline features are implemented. The audit found several claims that
were client-specific, best-effort, or overstated; the player and promotional
docs were corrected.

| Claim area | Status | Notes |
|---|---|---|
| XP, kills-to-level, reputation repeats | Implemented | Core XP/reputation and chat output. |
| Kill Story tabs and mob/area/level/session history | Implemented | Overview, Mobs, Areas, Heatmap, Levels. |
| Quest XP ledger | Implemented, Forever-only | Gated by `hasPerMobXP`; Midnight does not track quest XP. Docs now qualify it. |
| Level history and splits | Implemented | Level-time/kill splits, not route-segmented speedrun splits. Wording corrected. |
| Dungeon XP, goals, splits | Implemented | Dungeon XP is Forever-only; goals/splits work on both clients. Docs now qualify it. |
| Loot value, gold/hour, gear upgrades | Implemented | Gear alerts compare item level and depend on readable item/equipped data; live-unverified. |
| Deaths, respawns, grinding spots | Implemented | Grinding spots are Forever-only; respawns need nameplate/capture sightings. Docs now qualify it. |
| Heatmap and zone art | Implemented | 64x64 now; base art uses `C_Map.GetMapArtLayers`/`GetMapArtLayerTextures`, with discovered-area overlays from `C_MapExplorationInfo.GetExploredMapTextures`. No legacy `GetMapInfo` art fallback exists. |
| Nameplate levels | Implemented, Midnight-only | Off by default; sightings still feed respawn tracking. |
| 3D model | Implemented | A model hero card with fallback, not a browsable 3D gallery. Wording corrected. |
| Search, filters, sort, themes, minimap, keybind, compartment | Implemented | UI/List, UI/Theme, UI/Minimap, Bindings.lua/xml, TOC. |
| Settings sections and Tooltip subpage | Implemented | Native Settings API and client-gated sections. |
| Per-client storage and secret-data handling | Implemented and tested | Separate Forever/Midnight namespaces; defensive API reads. |
| Documented caps | Implemented | 100 deaths, 300 respawn NPCs/20 samples, 200 quests, 200 level records, 240 rate samples, 2000 mobs, 40 heatmap zones. |
| Midnight XP/rate/calibration/rested/grinding off | Implemented | Midnight profile capabilities are intentionally disabled. |
| "Live verification pending" | Accurate caveat | Quest/dungeon/group XP semantics, gear compare, heatmap art/performance, and several Midnight paths still need live verification. |

**Documentation corrections made**

- Replaced "speedrun splits" with "level-time splits".
- Replaced "3D mob browser" with "3D mob model card".
- Softened "clear gear-upgrade notifications" to "gear-upgrade notifications".
- Clarified that quest XP, dungeon XP, and grinding spots are Forever-only.
- Removed the inaccurate legacy `GetMapInfo` heatmap-art claim.
- Updated all current 32x32 references to 64x64; historical changelog entries
  remain as history.

### Scope increase review — proposed, not implemented

**Status:** analysis only. Heat alpha/controls changed in 2.3.1/2.4.0; no storage
or grid limits changed. Current limits are safety/performance caps, not measured
behavioral limits.

#### Heat color

- Existing ramp: `0.30 + 0.70 * density`.
- 2.3.1 ramp: `0.45 + 0.55 * density^0.70`.
- The floor is higher and mid-density cells are boosted without changing the
  theme color.
- Static review first; live visual check is deferred to V-1.
- Heat intensity (50-200%) and warm colors are now implemented in 2.4.0; live
  visual verification remains (A-1; live in V-1).

#### Grid resolution and coordinate reliability

- Current data grid: 64x64 (4,096 cells).
- Heatmap coordinates are captured by `CaptureUnit` from
  `C_Map.GetPlayerMapPosition`, which is the **player's** position, not the
  mob's position.
- `UNIT_DIED` uses the last target/mouseover capture; if a target is held for a
  long fight, the stored position can be several seconds old.
- Ranged/nameplate kills can be far from the player's position.
- 64x64 is about 1.6% of zone width per cell; 128x128 is about 0.8%. API float
  precision is not the limiter; capture semantics are.
- A 128x128 grid quadruples cells, storage, and potential UI textures. Dense
  zones would be much heavier, and small windows would show 3-4 px cells.
- Recommendation: do not raise the grid yet. First improve/measure capture, then
  compare 64 vs 128 occupancy and noise. A 128 cap could be stored with a 64
  display fallback, but that gives no visual gain in small windows.

#### Current limits: guestimates or measured?

They are fixed engineering caps, not derived from collected telemetry. The repo
has no recorded usage distribution or benchmark behind the values. `MAX_MOBS =
2000` is enforced by a test, but that only proves the cap works; it does not
justify the number. Treat the README values as conservative safety limits.

#### Proposed scope tiers (review only)

| Limit | Current | 2x | 4x | 6x |
|---|---:|---:|---:|---:|
| Mobs | 2000 | 4000 | 8000 | 12000 |
| Contexts per mob | 12 | 16 | 20 | 24 |
| Quests | 200 | 400 | 800 | 1200 |
| Level records | 200 | 400 | 800 | 1200 |
| Rate samples | 240 | 480 | 960 | 1440 |
| Deaths | 100 | 200 | 400 | 600 |
| Respawn NPCs | 300 | 600 | 1200 | 1800 |
| Respawn samples | 20 | 30 | 40 | 60 |
| Heatmap zones | 40 | 80 | 160 | 240 |
| Context age | 120d | 180d | 240d | 360d |

Do **not** scale contexts linearly without measurement; they dominate mob-entry
size. `MAX_PENDING_DEATHS`, visible rows, grinding thresholds, and
`MAX_HEATMAP_COUNT` are runtime/algorithm guards, not storage-scope limits.

#### Rough storage impact

- A synthetic worst-case 2000-mob/12-context dataset is about 6-7 MB of
  SavedVariables text; real data is smaller.
- A blanket 6x with 72 contexts per mob is unsafe: synthetic worst-case exceeds
  100 MB.
- 2x with 16 contexts is the lowest-risk tier; 4x needs measurement; 6x needs
  compaction/pruning or a different storage format.
- Heatmap zones are sparse in normal play. Dense 64x64 data grows roughly with
  zone count; 128x128 compounds it fourfold.
- These numbers are planning estimates, not acceptance thresholds.

#### Review tasks

- [ ] **SC-1 — Measure the current real store.** Add a diagnostic that reports
      SavedVariables/table size, mob count, context count, heatmap cells, and
      largest stores. Run it on a long-lived character.
- [ ] **SC-2 — Benchmark 2x/4x/6x.** Use synthetic and real data to measure
      login/load, pruning, list build, heatmap normalization, and UI refresh.
- [ ] **SC-3 — Choose a tier.** Approve 2x only if measured; make 4x/6x optional
      or reject. Do not raise every constant by the same factor.
- [ ] **SC-4 — Protect contexts.** Keep contexts capped independently; measure
      whether 16/20/24 improves calibration or just adds data.
- [ ] **SC-5 — Migration/pruning/tests.** Add versioned normalization, downgrade
      behavior, cap tests, and a documented reset/retention path.
- [ ] **G-1 — Coordinate capture code review.** Read `CaptureUnit`,
      `GetPlayerMapPosition`, death commits, and target/mouseover paths; evaluate
      `UnitPosition`/`C_Map.GetMapPosFromWorldPos` from API docs. Live position
      comparison is deferred to V-3.
- [ ] **G-2 — 64 vs 96/128 occupancy study.** Export real heatmap data and compare
      cell occupancy, trail noise, and visual readability at the same panel size.
- [ ] **G-3 — Decide grid.** Keep 64, or implement 96/128 only if the occupancy
      study and frame-cost benchmark pass. A 128 data grid with 64 display
      fallback is allowed only if it has a concrete product benefit.
- [ ] **G-4a — Instance identity and attribution.** Detect inside/outside
      dungeon state with `IsInInstance`, cache it from zoning events, store
      instance kills in `db.instances`/`mob.killsByInstance`, stop attributing
      map-less instances to Azeroth (947), and migrate historical world-map
      rows honestly. Ship first.
      Full specification: `docs/TASK-G-4-INSTANCE-ATTRIBUTION.md`.
- [ ] **G-4b — Heatmap collection gate.** Add `heatmapEnabled` to stop heatmap
      capture, normalization, event registration, and new saving when off. Keep
      the tab visible with a disabled message; `showHeatmap` remains the
      tab-only control. Ship after G-4a.
      Full specification: `docs/TASK-G-4-INSTANCE-ATTRIBUTION.md`.
- [x] **A-1 — Static alpha-ramp review.** Verified the 2.3.1 alpha-only ramp,
      intensity multiplier, warm palette, theme accent fallback, and cache key.
      Superseded by A-3. Live visual comparison is deferred to V-1.
- [x] **A-2 — Heat intensity/warm-color setting.** Implemented in 2.4.0;
      live verification is consolidated in V-1.
- [x] **A-3 — Multi-stop heat gradient.** Implemented in 2.4.4. Revised scope:
      - Three-stop RGB ramp: theme accent (low) -> gold (mid) -> red (high);
        the fire setting swaps in amber -> orange -> deep red.
      - Alpha rises from a weak floor to full strength, so the weakest cell is
        visibly weaker than the hottest.
      - Intensity (50-200%) now reshapes the alpha floor and gamma instead of
        multiplying the final alpha and clamping. At 200% contrast increases
        instead of every cell becoming fully opaque.
      - The legend is a 15-swatch Low-to-High gradient bar.
      - `XPTooltip.GetHeatColor` is exposed for offline verification.
      - Tests use a 1..13 count spread: hue and alpha are distinct at low, mid,
        and high counts; 200% does not collapse the ramp; the legend swatches
        span the palette.
      - Live visual confirmation remains in V-1.

### Heatmap controls and data diagnostics — implemented in 2.4.0

**Status:** implemented; static review first; live visual check in V-1.

**Heatmap controls**

- `heatmapIntensity` (50-200%, default 100%) is under Settings > Heatmap.
  It reshapes the gradient floor and gamma: higher values increase contrast,
  lower values flatten it.
- `heatmapWarmColors` (off by default) switches the gradient from the theme
  accent/gold/red ramp to an amber/orange/deep-red fire ramp.
- The current ramp is a three-stop colour gradient (theme accent -> gold -> red)
  with alpha rising from a weak floor to 1.0.
- Both settings invalidate the heat-cell color cache and refresh the panel.

**Data diagnostics**

- Added a diagnostics frame with per-character/per-client counts, limits, usage
  percentages, heatmap cells, contexts, calibration entries, total tracked
  entries, and an approximate store size.
- Open it with **middle-click on the minimap icon** or `/acem2l2 xpt data`.
- The frame is draggable, Escape-closable, and has Refresh/Close buttons.
- Size is an estimate from a bounded recursive traversal, not a SavedVariables
  file-size API. It is labeled as approximate.
- Counts clarify that the 2000-mob cap is **per character and per client across
  all zones**, not per zone.

**Limit scope clarification**

- Mobs: total unique mob entries for this character/client, all maps combined.
  Silverpine's 500 mobs consume 25% of that character's global mob budget.
- Quests: unique quest-ledger entries for this character/client, not per zone.
- Deaths: the last 100 death locations for this character/client; separate from
  heatmaps.
- Heatmaps: up to 40 map IDs/zone grids, separate from the mob cap.
- Respawns: 300 NPCs with 20 intervals each, per character/client.
- Level records: 200 level-up records; rate samples: 240 recent XP samples.
- Contexts: 12 calibration contexts per mob, globally per character/client.

**Tasks**

- [x] **HC-1 — Heatmap intensity/color settings.**
- [x] **HC-2 — Data diagnostics frame and icon/command access.**
- [x] **HC-3 — Clarify cap scope in README/BROCHURE and diagnostics.**
- [x] **HC-4 — Static visual-code review.** Verified the ramp, warm palette,
      intensity clamp, theme accent key, `renderedMaximum` rescale path, and
      `hooksecurefunc` theme refresh. Live visual comparison is deferred to V-1.
- [ ] **HC-5 — Offline diagnostics review.** Compare estimated size with
      synthetic datasets and real SavedVariables files offline. Live
      long-lived-character comparison is deferred to V-2.
- [x] **HC-6 — Player README rewrite.** README.txt is now a concise feature
      guide with a short performance/data note.
- [x] **HC-8 — Heatmap Settings subpage.** Heatmap tab/reveal/intensity/warm
      controls moved out of Tooltip into Settings > Heatmap.
- [ ] **HC-7 — Decide whether tracking limits become player-configurable.**
      This depends on the SC-1/SC-2 measurements above; do not expose raw 6x
      caps yet.

### Data storage architecture investigation — plan only

**Status:** investigation plan; no storage changes implemented.

**Why:** the 2000-mob cap is **per character, per client, across all zones**.
A zone with 500 unique mobs consumes 25% of that character's entire mob budget,
so other zones lose detail. The cap counts unique mob identities, not kill
events.

**Important correction:** the current model is already aggregated, not a
per-kill log. Each mob entry stores counts such as `killsAtLevel`,
`killsByMap`, `killsByAreaLevel`, and `contexts`. The user's example — 15 kills
at level 15 and 300 at level 16 of one mob in one zone — is already close to
`killsByAreaLevel[zone][level] = count`. The problem is the **global mob-entry
cap and the shape of the tables**, not per-kill storage.

#### Questions to answer

1. Can a zone-first schema retain detail for many more zones without a global
   2000-mob ceiling?
2. Can mob identity (name, NPC ID, classification) be separated from per-zone
   counts so the same NPC is not duplicated across zones?
3. Do we need per-cell mob/level detail, or is the heatmap sufficient as a
   separate aggregate plus a zone-level mob list?
4. Can static metadata be shipped as Lua, like QuestieDB, to shrink saved data?
5. Does the client support multiple SavedVariables, per-character variables, or
   LoadOnDemand variables usefully? (No per-zone SavedVariables files exist.)
6. Which WoW loading/SavedVariables APIs let us store compactly and expand on
   demand? Addon implementations are reference patterns only; their data is not
   copied.

#### Storage candidates

- **A — Current global mob table.** One `db.mobs[mobKey]` per unique mob with
  zone/level sub-tables. Simple, but globally capped and duplicates identity
  across zones only once globally.
- **B — Identity/count split.** Small `mobIndex[mobKey] = {name, npcID,
  classification}` plus `zoneCounts[zone][mobKey][level] = count` and optional
  per-cell counts. Allows per-zone caps and preserves global identity.
- **C — Zone-first records.** `zones[mapID].mobs[mobKey] = {levels={...},
  cells={...}}`, with a shared identity registry. Natural for zone pages and
  per-zone pruning.
- **D — Heatmap-only aggregate.** Sum all mobs per cell and drop per-mob detail
  for cells. Smallest, but loses "which mob" and level breakdown; only viable
  as a display aggregate, not the primary store.
- **E — Static metadata DB.** Ship NPC/mob/zone metadata as a TOC-loaded Lua
  database (QuestieDB style); saved data stores IDs and counts only.
- **F — Packed/compressed history.** Store per-zone count blocks as packed
  strings or compressed blobs, decode lazily; reduces file size, increases CPU
  and migration complexity.
- **G — Multiple SavedVariables / LoadOnDemand.** Split settings, per-character
  history, and cold zone data. Multiple SV variables are supported, but the
  client has no per-zone SV files; LoadOnDemand saved-variable timing must be
  measured.

#### WoW API surface to use

The design should be driven by the client API, not by another addon's data.

- **SavedVariables directives:** `SavedVariables` and
  `SavedVariablesPerCharacter` accept comma-separated names. Multiple variables
  are allowed; account and character scopes are separate.
- **Load order:** `LoadSavedVariablesFirst: 1` makes a variable available before
  the addon's files execute. Otherwise it is available after `ADDON_LOADED`.
- **On-demand addon:** `## LoadOnDemand: 1` plus
  `C_AddOns.LoadAddOn(name)`; detect with `C_AddOns.DoesAddOnExist`,
  `C_AddOns.IsAddOnLoadOnDemand`, `C_AddOns.IsAddOnLoadable`, and
  `C_AddOns.IsAddOnLoaded`. Its `ADDON_LOADED` event marks availability.
- **Metadata:** `C_AddOns.GetAddOnInfo`, `GetAddOnMetadata`,
  `GetAddOnInterfaceVersion`, `GetAddOnDependencies`, and
  `GetAddOnOptionalDependencies` for compatibility and capability checks.
- **Explicit save/compaction:** `C_AddOns.SaveAddOns()` requests a save. Treat
  it as a checkpoint, not a per-kill write.
- **Oversize signal:** register `SAVED_VARIABLES_TOO_LARGE` and degrade
  gracefully. The client also emits `ADDONS_UNLOADING` before unload.
- **Practical limits:** there is no documented hard file-size limit, but the
  Lua VM's constant-table limit is roughly 262,144 unique literal values per
  file. Large plain tables can also hit practical 50-60 MB write problems. This
  is why packed strings and split variables matter.

#### Reference patterns, not data to copy

Use the addon implementations to learn API and loading patterns only. Do not
copy their databases, saved data, or schemas verbatim.

- **AllTheThings:** multiple `SavedVariables` plus
  `SavedVariablesPerCharacter` in the TOC; large static database under `db/`
  loaded as Lua, with account/character completion data separate.
- **Carbonite:** one `CarbData` AceDB with `profile`, `global`, and `char`
  scopes; `DataPersistence` exposes `Nx.CurCharacter` and
  `db.global.Characters`. Per-character data lives inside the global SV table.
- **Questie / QuestieDB:** `QuestieDB` is a separate Lua database addon, while
  Questie uses `QuestieConfig` and per-character `QuestieConfigCharacter`;
  Questie's TOC sets `LoadSavedVariablesFirst: 1`.
- **ForeverLevelingGuide:** closed/paid; inspect the installed addon during the
  investigation, but do not assume its internals. Likely static guide data plus
  per-character progress.
- **WoW SavedVariables:** multiple variables and account/per-character scopes
  are supported; no per-zone files. `LoadSavedVariablesFirst` changes load
  order. Test the historical Forever SavedVariables read/write bug on 1.60.1.

#### API-driven storage design

The target is **small persistent indexes plus packed cold blocks, expanded on
demand**, not one huge Lua table.

1. **Main index (small, always loaded).** Schema version, per-character summary,
   zone IDs, block lengths/checksums, and global totals. This supports the
   Overview, tooltips, diagnostics, and zone paging without touching cold data.
2. **Cold zone blocks.** One packed string per zone (or per zone/level group):
   numeric IDs, varint/delta counts, optional bit-packed level/cell entries.
   A block is decoded only when its zone is selected, then cached in an LRU
   with a small cap.
3. **Write path.** Update the active block in memory; re-pack only that block.
   Periodically compact append-only deltas. `SaveAddOns` is a checkpoint after
   major changes, not a per-kill operation.
4. **Optional companion addon.** Put cold blocks in a second addon with
   `LoadOnDemand: 1`. The main addon calls `C_AddOns.LoadAddOn` when history is
   opened. Test whether that companion's SavedVariables load only on demand on
   both clients; if not, keep the split for constant-table isolation only.
5. **Static metadata.** Ship generated official Lua metadata (NPC/zone IDs,
   names, levels, classification) so saved blocks contain numeric IDs and counts,
   not repeated strings.
6. **Safety.** Version/checksum every block, keep one previous block/backup,
   handle `SAVED_VARIABLES_TOO_LARGE`, and stay below the Lua constant-table
   limit by using packed strings rather than thousands of literals.

**Retrieval rules:** never load every zone to build a tooltip or the Mobs tab.
Use the index for totals and the active zone blocks for detail. Decode on
selection, keep a bounded cache, and drop cold blocks when the cache exceeds its
budget.

#### Proposed experiments

1. **Inventory consumers.** List every feature that reads mob data: Mobs tab,
   Areas/Levels, tooltips, calibration, heatmap, deletion, deletion-unknown,
   respawns, and migration.
2. **Measure the current store.** Use the 2.4.0 Data diagnostics panel plus a
   real SavedVariables file to record counts, contexts, heatmap cells, and
   bytes for a long-lived character and a Silverpine-heavy character.
3. **Build synthetic datasets.** One zone with 500 mobs, many zones, sparse and
   dense levels, 1x/2x/4x/6x caps. Record bytes, load time, prune time, UI
   build time, and heatmap normalize/refresh time.
4. **Prototype schemas offline.** Implement A–D in a Lua harness using the same
   read/write patterns; compare bytes and query complexity.
5. **Map SavedVariables/loading APIs from docs and source.** Document
   `SavedVariables`/`SavedVariablesPerCharacter`, `LoadSavedVariablesFirst`,
   `C_AddOns.LoadAddOn`, `IsAddOnLoaded`, `DoesAddOnExist`,
   `IsAddOnLoadOnDemand`, `SaveAddOns`, and `SAVED_VARIABLES_TOO_LARGE`.
   Confirm LoadOnDemand companion timing at runtime in V-2, not here.
6. **Evaluate static metadata.** Estimate size/licensing/maintenance for a
   generated NPC/mob/zone metadata DB. Do not copy QuestieDB/ATT/Carbonite
   data. Use official client data or our own generated tables.
7. **Evaluate packing.** Compare plain tables, numeric-only arrays, packed
   strings, and compression; measure save/load/CPU and debuggability.
8. **Design display.** Zone-scoped mob list with a level filter; heatmap cell
   aggregate plus optional "top mobs in this cell" list; avoid discarding
   identity just to fit the grid.

#### Tasks to investigate

- [ ] **DS-1 — Consumer inventory and invariants.** Document every reader and
  required field; mark optional/derived fields.
- [ ] **DS-2 — Real-store baseline.** Capture current counts/estimated bytes and
  actual SavedVariables size for representative characters.
- [ ] **DS-3 — Synthetic scale matrix.** Generate 1x/2x/4x/6x datasets and record
  bytes, load/prune/UI costs.
- [ ] **DS-4 — Schema prototypes.** Implement and compare A–D offline; include
  per-zone vs global cap behavior.
- [ ] **DS-5 — SavedVariables/loading API matrix.** Document multiple variables,
  per-character scope, `LoadSavedVariablesFirst`, `C_AddOns.LoadAddOn`,
  `SaveAddOns`, `SAVED_VARIABLES_TOO_LARGE`, and LoadOnDemand semantics from API
  docs and client source. Runtime timing/persistence checks are deferred to V-2.
- [ ] **DS-6 — Static metadata feasibility.** Size, source, licensing, version
  pinning, and regeneration process.
- [ ] **DS-7 — Packing/compression feasibility.** Measure size/CPU; decide
  whether it is worth the opacity and migration cost.
- [ ] **DS-8 — Display redesign study.** Zone-first Mobs/Areas/Levels and
  heatmap-cell detail without losing identity.
- [ ] **DS-9 — Retention and migration.** Per-zone caps, global totals, pruning,
  downgrade behavior, schema version, and reset paths.
- [ ] **DS-10 — Offline prototype.** Use saved-variable fixtures and synthetic
  zone-heavy/long-lived profiles to exercise packing, decode, and query paths.
  Live client verification is deferred to V-2.
- [ ] **DS-11 — Decision record.** Choose current, identity/count split,
  zone-first, static DB, packing, or a phased combination; include estimates and
  a migration plan.
- [ ] **DS-12 — Packed block codec.** Define the zone-block binary/string format,
  versioning, checksums, encode/decode functions, and corruption handling.
- [ ] **DS-13 — On-demand companion packaging.** Design the LoadOnDemand
  companion, its TOC, SavedVariables, load call, missing-companion fallback, and
  release packaging from API docs/source. Runtime timing is deferred to V-2.
- [ ] **DS-14 — Constant-table/oversize guard.** Stay below the Lua constant
  limit, register `SAVED_VARIABLES_TOO_LARGE`, keep a previous backup, and define
  automatic compaction/pruning.
- [ ] **DS-15 — Lazy retrieval/cache.** Decode only the selected zone, keep a
  bounded LRU, expose query APIs to Mobs/Areas/Levels/tooltips, and measure
  decode/UI latency.
- [ ] **DS-16 — Explicit save/checkpoint policy.** Review `C_AddOns.SaveAddOns`
  documentation and define checkpoint triggers from code. Runtime save behavior
  is deferred to V-2.

#### Review and revisions to the investigation

- The heatmap alone cannot replace mob entries: it loses mob identity and level.
  Use it as a per-cell aggregate, with a separate identity/level store.
- The current code already aggregates levels and zones per mob; the investigation
  must focus on cap shape and retention, not re-inventing per-kill logging.
- Multiple SavedVariables do not create per-zone files. Any claim that they
  reduce per-zone data must be verified against load/save behavior.
- Static Lua databases solve metadata size, not user history.
- The plan is API-first: use official client APIs and our own generated metadata;
  other addons are implementation references only, not data sources.
- Do not copy Mapster, QuestieDB, AllTheThings, or Carbonite data. Use generated
  official data or our own schema.
- Do not approve 2x/4x/6x until DS-2/DS-3 produce byte and latency numbers.
- Forever's historical SavedVariables bug must be checked in V-2.

**Decision gate:** no storage migration before DS-11 and the DS-12..DS-16
prototype results are reviewed and approved.

### Proposed: Journey overlay and cell inspector — after data-format work

**Status:** proposed only. Both features depend on the DS-1..DS-16 storage
decision. Do not implement them against the current global mob table.

**Ordering:** finish the data-format investigation first, then Journey, then the
cell inspector. The inspector needs richer per-cell identity data than the
current heatmap stores.

#### Feature A — Journey overlay

Show the character's movement through a zone on the heatmap, with deaths and
kill history tied to time.

Possible data:

- `journey[mapID] = { {t=epoch, x=0..1, y=0..1, cell=n}, ... }`
- optional `kills[mapID][cell] = { mobKey = count }` for time-window detail
- deaths already exist as `db.deaths` with `at`, `mapID`, `x`, `y`.

Rendering:

- Draw a polyline between sampled positions.
- Use 5-minute display blocks initially, but sample more frequently (30-60s) and
  aggregate for display if needed. A 5-minute centroid can produce misleading
  straight lines across terrain.
- Mark deaths in the selected time range on the correct map.
- Add a time-window control: session, last 30/60 minutes, all recorded.
- Only show points belonging to the selected zone.
- Label the line as an approximate route, not a measured path.

Storage risks:

- More samples = more SavedVariables data.
- Need caps per zone/session and pruning.
- Could reuse a future event ledger for journey, kills, and cell detail instead of
  creating three unrelated stores.
- Sampling only on kills/deaths/zone changes is cheap but incomplete; periodic
  sampling is better but needs a throttle.

#### Feature B — Hover cell inspector

Mouse over the heatmap to select a 4x4 cell area and show what was killed there.

Display:

- Hover highlight over the 4x4 cell block.
- Aggregate count and percentage for the block.
- Top mobs in that block with count, level range, and last-seen time.
- Optional mob icon or portrait.
- Right-hand panel inside the Heatmap tab.

Data requirement:

- Current heatmap stores only aggregate per-cell counts. It does **not** know
  which mob was killed in each cell.
- Need a new sparse mapping such as
  `zoneCellMobs[mapID][cell][mobKey] = count` and possibly level buckets.
- Without that mapping, the inspector can show only density, not mob identity.

Interaction:

- Do not create 4,096 mouse-enabled cell frames.
- Use one transparent overlay frame and compute the hovered cell from cursor
  position.
- Aggregate the 4x4 block on mouse move, throttled.
- Hide the inspector when the heatmap tab is not visible or when the cursor
  leaves the grid.

Mob icons:

- Verify the available API for NPC/creature portraits before promising icons.
- Candidates: `SetPortraitTexture`, `C_CreatureInfo`, `GetCreatureInfo`, or a
  `PlayerModel` fallback.
- If no reliable icon exists, use a type/faction icon or text-only rows.

#### Priorities

- **P0 — DS-1..DS-11.** Finish the storage decision before adding new history
  stores.
- **P1 — Journey basic.** Zone-filtered route, deaths, session/last-hour filter,
  approximate-route label. High visual value, moderate data.
- **P2 — Cell inspector.** 4x4 hover block, aggregate density, top mobs. Needs
  per-cell mob data and icon verification.
- **P3 — Journey playback.** Time slider, pause/play, route smoothing, multi-zone
  transitions. Nice-to-have after basic Journey.
- **P4 — Rich mob portraits.** Only if a reliable client API exists.

#### Tasks

- [ ] **J-1 — Journey data model.** Decide sample cadence, fields, map/session
  keys, and whether it shares an event ledger with kills.
- [ ] **J-2 — Sampling strategy.** Compare periodic samples, kill/death-only
  samples, and zone-change samples; measure storage and path quality.
- [ ] **J-3 — Retention.** Cap points per zone/session; define pruning and
  migration.
- [ ] **J-4 — Renderer.** Draw zone-filtered polylines and death markers above
  map art but below heat cells or above them as a toggle.
- [ ] **J-5 — Time controls.** Session, last 30/60 minutes, all; optional playback.
- [ ] **J-6 — Journey offline tests.** Validate sampling/retention/render math with fixtures and synthetic routes. Live playback is deferred to V-4.
- [ ] **M-1 — Cell-mob data model.** Define sparse per-cell mob/level counts and
  storage caps.
- [ ] **M-2 — Icon/portrait API review.** Check NPC/creature portrait APIs in
  client docs/source for Forever and Midnight; specify text/type fallback. Live
  visual check is deferred to V-4.
- [ ] **M-3 — Hover hit-testing.** One overlay frame; compute 4x4 block without
  thousands of mouse frames.
- [ ] **M-4 — Inspector panel.** Aggregate block stats, top mobs, levels, last
  seen, and optional icons.
- [ ] **M-5 — Performance/accessibility.** Throttle hover updates, handle missing
  data, and keep the panel readable at minimum window size.
- [ ] **M-6 — Inspector offline tests.** Validate 4x4 hit math, aggregation, empty-data handling, and panel layout with fixtures. Live hover/icon checks are deferred to V-4.

#### Analysis and review

- The current `deaths` store can support death markers immediately, but the
  route needs new time-series data.
- The current heatmap cannot answer “what did I kill in this cell”; it only sums
  counts. The inspector must not pretend otherwise.
- A shared time-stamped event ledger is likely cheaper than separate journey,
  kill-cell, and inspector stores, but it must be evaluated against the current
  aggregate model.
- The 5-minute block idea is useful for display compression, not necessarily for
  raw sampling.
- Both features are local-only; no external services are involved.

### Fully revealed map background — implemented in 2.3.0

**Status:** implemented; static audit first; live check consolidated in V-5.

**Decision:** use a generated full-overlay pack from the official client
`WorldMapOverlay` / `WorldMapOverlayTile` tables. This is the FogClear mechanism
without copying Mapster/Leatrix data.

**Implementation**

- `KillHistory/MapOverlayData.lua` is generated for:
  - Midnight 12.1.5.69848
  - Forever 1.60.1.69913
- Each entry is keyed by `uiMapArtID` and stores overlay width/height/offsets and
  the official texture fileDataIDs.
- The heatmap uses `C_Map.GetMapArtID(mapID)` to select the right data, draws
  static overlays the character has not explored, then draws the official
  explored overlays on top.
- `C_Map.GetMapArtLayers` / `C_Map.GetMapArtLayerTextures` still provide the
  base art, tile sizes, and layer information.
- `Reveal unexplored areas` is a Settings > World option, on by default. When
  off, only the character's explored overlays are drawn.
- The static overlay data is parsed once per art ID and cached.
- Missing/stale data falls back to explored overlays and base art.
- No Mapster or Leatrix overlay data is copied.

**Verification**

- Offline: generated data loads; static overlays reveal missing art; explored
  overlays are not duplicated; the reveal setting disables static data.
- Live comparison: deferred to V-5; static audit is R-4.
- Release: 2.3.0 archive built and validated.

**Tasks**

- [x] **R-5 — Static overlay data.** Generated from official DB2 tables with
      `tests/generate_map_overlays.py`.
- [x] **R-9 — Decision record.** Static generated overlay pack selected over
      parent-crop, minimap, legacy, and child-map approaches.
- [ ] **R-4 — Static overlay/art audit.** Verify art-ID selection, overlay
      bucketing, phase handling, tile coordinates, and cache keys from code and
      data. Live quality/frame-cost comparison is consolidated in V-5.
- [x] **R-10 — Release/docs.** 2.3.0 documentation and archive built and
      release-validated.
- Deferred: parent/continent crop (R-0..R-3), minimap terrain (R-6), legacy art
      (R-7), and child-map compositing (R-8). The static pack supersedes them for
      the current feature.

**Alternatives not chosen**

- Parent/continent crop: no data, but lower resolution and unproven.
- Minimap terrain: highest detail, too much data/coordinate work.
- Legacy `Interface\WorldMap\...` art: partial coverage.
- Child-map compositing: uncertain coverage.
- CVar/engine force-reveal: no public API.

**Deferred alternative tasks when reopened**

- [ ] **R-0 — Source-map policy.** Choose immediate parent vs highest ancestor
      with art; reject degenerate/non-square crops.
- [ ] **R-1 — Parent-art probe.** Report parent art layers, tile count,
      resolution, map rect, and explored overlay counts.
- [ ] **R-2 — Parent-crop spike.** Render one zone from ancestor art with correct
      texture coordinates; keep base art as fallback.
- [ ] **R-3 — Parent-crop integration.** Default-off setting, cache key, and
      per-map fallback.
- [ ] **R-6 — Minimap terrain feasibility.** Evaluate data size, licensing,
      coordinate work, and Midnight coverage.
- [ ] **R-7 — Legacy art mapping probe.** Test a small zone-to-folder mapping for
      classic zones.
- [ ] **R-8 — Child-map compositing probe.** Check how many child maps return
      independent art and whether compositing helps.

## Final live validation — deferred until last

**Policy:** do not run these until static code/API/data review and offline
prototypes are complete. This is the single live-test gate; do not add separate
in-game tasks to each feature section.

- [ ] **V-1 — Heatmap visual/performance.** 64x64 sparse/dense zones,
      minimum/default/maximum window sizes, map art on/off, full reveal,
      gradient hue/alpha at 50/100/200% intensity, warm palette, gradient
      legend, heat-cell alignment, and frame cost.
- [ ] **V-2 — Storage/diagnostics runtime.** Compare diagnostics estimate with
      actual SavedVariables sizes on long-lived and zone-heavy characters; check
      LoadOnDemand companion timing, `SaveAddOns`, `SAVED_VARIABLES_TOO_LARGE`,
      and Forever 1.60.1 persistence.
- [ ] **V-3 — Coordinate/grid confirmation.** Only if G-1/G-2 propose changes:
      compare death-time position capture and 64 vs 96/128 occupancy/noise and
      latency.
- [ ] **V-4 — Journey/inspector runtime.** Only if implemented: route/death
      rendering, time filters, 4x4 hover selection, mob rows/icons, panel
      performance.
- [ ] **V-5 — Map overlays/art runtime.** Fully unexplored zone on Forever and
      Midnight; art-ID/phase alignment, heat-cell alignment, overlay quality, and
      frame cost.
- [ ] **V-6 — Documentation/release claims.** Verify player/developer docs, Data
      diagnostics access, install from the release zip, and final release check.

**Carbonite live checks** remain inside the deferred Carbonite section and are
not part of this gate until that work is reopened.

## Deferred work

### Carbonite integration

Deferred by user request. No Carbonite code or provider setup has been added.

Retained conclusions from the research:

- Carbonite's full map background uses the same Blizzard `C_Map` tiled art Kill
  Story already uses.
- Embedding Carbonite's live map frame is not viable.
- The only recommended integration is an optional overlay through the public
  `Carbonite.Map:CreateProvider` API.
- `ZR` rectangle pins must pass a live alignment/zoom/clipping/instance/docked
  minimap spike before implementation.
- The overlay would use adaptive 32x32/16x16 bucketing, capped at 256 pins, and
  would follow Carbonite's visible map rather than the Kill Story pager.
- Carbonite stays optional, default-off, capability-gated, and absent from
  `OptionalDeps`.
- Carbonite's radar-detail tiles and legacy art fallback remain deferred because
  they require private tables, coordinate transforms, and GPL review.

Do not start this work until V-1/V-5 pass and the work is explicitly approved.

**Deferred tasks when reopened**

- [ ] **CB-0 — Live ZR spike.** Validate alignment, zoom, clipping, instance
      levels, docked minimap, 3D mode, and frame cost.
- [ ] **CB-1 — Detector/lifecycle.** Capability gate, retries, lazy provider
      creation, session disable.
- [ ] **CB-2 — Setting/options/probe.** Default-off Carbonite overlay setting
      and diagnostics.
- [ ] **CB-3 — Provider/adaptive buckets.** 32x32/16x16 buckets, 256-pin cap,
      frame level, docked-minimap behavior.
- [ ] **CB-4 — Matching/sync.** Exact/parent matching, coalesced rebuilds,
      toggle/reset/theme/client-switch handling.
- [ ] **CB-5 — Failure isolation.** pcall all Carbonite calls; clear on errors.
- [ ] **CB-6 — Live tests/docs/release.**

### KillStory as a separate addon

Deferred until explicitly approved. When revisited, decide:

- Data ownership and SavedVariables location.
- Public AceM2L2 API, callbacks, capabilities, and version handshake.
- Tooltip ownership between AceM2L2 text and KillStory GUI.
- Two-addon packaging, dependency/load order, and missing-dependency behavior.
- Migration and downgrade behavior.
- Tests for the API contract and load order.

Do not implement the split before those decisions are accepted.
