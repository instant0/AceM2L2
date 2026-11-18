# DS-17.6A4 — Query-truth audit

**Status:** complete  
**Scope:** UI and command consumers only. This slice checks what each reader
opens, which stored model it reads, whether a legacy path is explicit, and
whether readers agree with each other. It does not audit the query API
implementation (A3), field ownership (A1), capture (A2), or physical
storage/save (A3).  
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`  
**Output:** this file only. No code or shared docs changed.

## Files read

Task and reference:

- `docs/tasks/DS-17-06A4-QUERY-TRUTH.md`
- `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`
- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/IMP-1B7-MOBS-LIST-OVERVIEW-RESULT.md`
- `docs/IMP-1B8-LEGACY-READ-AUDIT-RESULT.md`
- `docs/IMP-1B10-HEATMAP-BOUNDED-RESULT.md`
- `docs/NEXT-TASK.md`, `PLAN.md` (Journey/status sections only)

Production:

- `KillHistory/Tooltip.lua`
- `KillHistory/JourneyQueries.lua`
- `KillHistory/JourneyIndex.lua`
- `KillHistory/JourneyStorage.lua`
- `KillHistory/Journey.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/World.lua`
- `KillHistory/Module.lua`
- `KillHistory/Data.lua` (read paths, normalization, quest, level history)
- `KillHistory/Commands.lua`
- `KillHistory/Util.lua` (map attribution)
- `KillHistory/UI/Detail.lua`
- `KillHistory/UI/List.lua`
- `KillHistory/UI/Overview.lua`
- `KillHistory/UI/Window.lua`
- `KillHistory/UI/Heatmap.lua`
- `KillHistory/UI/Diagnostics.lua`
- `KillHistory/UI/Minimap.lua`

Tests inspected (not run):

- `tests/tooltip_fallback.lua`
- `tests/areas_levels_parity.lua`
- `tests/heatmap_bounded.lua`
- `tests/historical_relevance.lua`
- `tests/historical_zone.lua`
- `tests/heatmap_selector.lua`
- `tests/commands_index.lua`
- `tests/area_level_summaries.lua`
- `tests/history_view.lua`
- `tests/quest_ledger.lua`
- `tests/heatmap_commit_position.lua`

## Method

Static, read-only trace from each view/command entry point to its data access.
For each reader I recorded the concrete table/function opened, whether a legacy
scan remains as the primary or rollback path, and which existing offline test
assertion covers the behavior. Existing test assertions and result documents are
cited as evidence; no test was executed. Line numbers are from the files as read
on 2026-11-18.

## Limitations

- No runtime, saved-variable, or live-client inspection. Findings about stale
  blocks and heatmap-clearing are derived from control flow, not observed data.
- Test files were inspected only. Their assertions show intended behavior; they
  were not re-run in this slice.
- A3 owns block/storage internals; A1 owns field ownership. Cross-slice points
  are marked as gaps for A5 rather than decided here.
- The audit covers the views and command families named in the task. Settings
  UI, config forms, and rendering-only code were not exhaustively traced.
- `PLAN.md` and `NEXT-TASK.md` were read only for context; neither was edited.

## Executive result

Production currently uses **v1 legacy aggregate tables as the canonical
per-character store** (`db.mobs`, `db.areas`, `db.levels`, `db.quests`,
`db.deaths`, `db.respawns`, `db.heatmaps`), with `db.journey` as **additive
instrumentation** (zone/level XP and time, quest anchors, block snapshots).
That is explicit in `KillHistory/Data.lua:109` (`NewEmptyClientData`), the
normalization at `KillHistory/Data.lua:724`, and
`KillHistory/JourneyStorage.lua:218` (`storageMode = "additive"`).

Consequently most readers are internally consistent, but they are **not**
reading the DS-17.5 v2 Journey shape (`journey.mobs`, `journey.zones`,
`journey.quests`, `journey.deaths`, `journey.respawns`,
`journey.heatmaps`). The main query-truth risks found are:

1. heatmap block zones are never pruned while legacy heatmaps are, so the
   selector/commands can resurrect zones that no longer exist in the live model;
2. the heatmap header total comes from legacy metadata while the grid can come
   from a stale Journey block;
3. a cold block-only mob can appear in tooltip/Detail but not in Mobs,
   Overview, or diagnostics, and the tooltip does not label that source;
4. death/respawn/quest/level-history views remain legacy-only against the
   DS-17.5 target.

No silent numeric disagreement was found in the Areas/Levels/Mobs paths: those
readers share the same row helpers or the same legacy source.

## Required table

Legend for **Legacy path?**:

- **Primary** — the reader normally reads a v1 `db.*` aggregate.
- **Derived** — the reader reads an in-memory index built from v1 `db.*`.
- **Rollback** — Journey/index path by default, v1 scan behind
  `journey.indexViews = false`.
- **Only** — no Journey counterpart exists in production.
- **No** — reads `journey.*` only.

| View/query | Reader | Data source | Legacy path? | Status | Evidence |
|---|---|---|---|---|---|
| Tooltip, normal/historical | `XPTooltip:resolveTooltipMob`, `AddTooltipLines` | `char.mobs[key]`; if absent, targeted `journey.blocks["map:<current>"]` record | Primary; block fallback only when legacy entry is missing | Implemented; legacy-first, 0 decodes on legacy, 1 cold decode on fallback; fallback count is not labelled | `KillHistory/Tooltip.lua:157`, `:239`, `:273`; `tests/tooltip_fallback.lua:31`, `:37` |
| Tooltip historical lines | `AddTooltipHistoricalLines` | same mob record; block record when fallback | Primary | Implemented; omits first/last when block lacks them, does not fake XP | `KillHistory/Tooltip.lua:192`, `:283`; `tests/historical_relevance.lua:33` |
| Overview cards | `XPTooltip:RefreshOverview` | `db.totals.kills`, `db.session.kills`, `db.totals.uniqueMobs`, `GetTopAreaSummary()` → `db.areas` | Primary | Implemented; no Journey zone XP/time surfaced | `KillHistory/UI/Overview.lua:125`; `KillHistory/JourneyQueries.lua:144` |
| Overview “Most killed” | `RefreshOverview` | `GetJourneyTopMobs()` index over `db.mobs`; direct `db.mobs` rollback | Derived; Rollback | Implemented; parity and one-build budget tested | `KillHistory/UI/Overview.lua:149`; `KillHistory/JourneyIndex.lua:88`; `docs/IMP-1B7-MOBS-LIST-OVERVIEW-RESULT.md:53` |
| Overview level/quest/session panels | `RefreshOverview` | `db.levels`, `db.quests`, `db.levelHistory`, `db.dungeon`, `db.economy`, `db.goal` | Primary | Implemented; Journey `levels` XP/time is not shown | `KillHistory/UI/Overview.lua:180`, `:250`; `KillHistory/Data.lua:1839` |
| Mobs list / filter / search | `XPTooltip:BuildList` → `GetJourneyMobsForFilter` | in-memory index over `db.mobs`; direct `db.mobs` rollback | Derived; Rollback | Implemented; parity, filter, search, rollback tested | `KillHistory/UI/List.lua:330`; `KillHistory/JourneyIndex.lua:104`; `docs/IMP-1B7-MOBS-LIST-OVERVIEW-RESULT.md:74` |
| Areas list | `BuildList` → `GetAreaRows` | `db.areas` + `db.instances` | Primary | Implemented; legacy counts canonical, Journey zone counts not added | `KillHistory/UI/List.lua:236`; `KillHistory/JourneyQueries.lua:83`; `tests/areas_levels_parity.lua:64` |
| Levels list | `BuildList` → `GetLevelRows` | `db.levels` | Primary | Implemented; legacy counts canonical | `KillHistory/UI/List.lua:290`; `KillHistory/JourneyQueries.lua:121`; `tests/areas_levels_parity.lua:65` |
| Area detail | `UpdateAreaDetail` | `GetAreaKillCount`, top mobs index/`db.mobs`, `db.areaLevels`, deaths, quest anchors, heatmap zone metadata | Primary | Implemented; mixed sources; zero block decodes for summary | `KillHistory/UI/Detail.lua:623`; `tests/historical_zone.lua:88` |
| Level detail | `UpdateLevelDetail` | `GetLevelKillCount`, top mobs by `killsAtLevel` (player level) | Primary | Implemented | `KillHistory/UI/Detail.lua:657`; `KillHistory/JourneyQueries.lua:218` |
| Instance detail | `UpdateInstanceDetail` | `db.instances`, `db.totals.kills`, mob `killsByInstance` | Primary | Implemented | `KillHistory/UI/Detail.lua:422` |
| Mob detail | `UpdateMobDetail` | `db.mobs`; block fallback | Primary; block fallback | Implemented; block branch marks session/area/XP context unavailable | `KillHistory/UI/Detail.lua:298`, `:361`; `tests/tooltip_fallback.lua:55` |
| Heatmap zone selector | `ReadZones` → `GetHeatmapZoneIndex` → `BuildHeatmapSelectorRows` | `db.heatmaps` metadata + `journey.blockIndex` metadata; names/levels from `db.areas`/`db.areaLevels`/`db.instances` | Primary + additive | Implemented; metadata only, 0 decodes tested; stale Journey-only zones possible | `KillHistory/Heatmap.lua:322`; `KillHistory/UI/Heatmap.lua:135`; `tests/heatmap_selector.lua:177` |
| Heatmap grid | `XPTooltip:RefreshHeatmap` | selected `journey.blocks["map:<id>"]` cells when `journeySource`, else legacy `db.heatmaps` cells | Primary; Journey selected read, legacy fallback | Implemented; 1 decode + cache; header total and cell source can diverge | `KillHistory/UI/Heatmap.lua:1177`, `:1260`, `:1276`; `tests/heatmap_bounded.lua:25` |
| Heatmap top cells | `GetHeatmapTopCells` | Journey block cells then legacy cells | Primary | Implemented; one decode, cache-tested | `KillHistory/JourneyQueries.lua:306`; `tests/heatmap_bounded.lua:40` |
| Death history | `BuildHistoryRows`, `UpdateDeathDetail`, `PrintDeaths` | `db.deaths` | Only | Implemented for v1; no `journey.deaths` exists | `KillHistory/UI/List.lua:33`; `KillHistory/UI/Detail.lua:210`; `KillHistory/World.lua:189` |
| Respawn history | `BuildHistoryRows`, `GetRespawnStats`, `UpdateRespawnDetail`, `PrintRespawns` | `db.respawns` | Only | Implemented for v1; no `journey.respawns` exists | `KillHistory/UI/List.lua:65`; `KillHistory/World.lua:493`, `:531` |
| Quest ledger | `BuildQuestRows`, `UpdateQuestDetail`, `PrintQuests`, `GetQuestSummary` | `db.quests` | Only | Implemented for v1; no `journey.quests` exists | `KillHistory/UI/List.lua:148`; `KillHistory/UI/Detail.lua:275`; `KillHistory/Commands.lua:264`; `KillHistory/Data.lua:1820` |
| Area quest anchors | `GetQuestAnchors` | `journey.questAnchors`; display names from `db.quests` | No (falls back to `db.quests` when no anchors) | Implemented; no block decode | `KillHistory/JourneyQueries.lua:360`; `KillHistory/UI/Detail.lua:562` |
| Diagnostics | `GetDataStats`, `RefreshDiagnosticsUI` | `db.mobs`, `db.quests`, `db.deaths`, `db.levelHistory`, `db.rates`, `db.respawns`, `db.heatmaps`, `db.instances`, `db.calibration`; Journey block bytes/cache | Primary | Implemented; does not show Journey zone/level/blockIndex counts | `KillHistory/UI/Diagnostics.lua:139`, `:334`; `KillHistory/Module.lua:185` |
| Command `kills` / `dump` | `PrintKills`, `PrintDump` | index over `db.mobs`; direct `db.mobs` rollback | Derived; Rollback | Implemented; output and zero-kill dump parity tested | `KillHistory/Commands.lua:198`, `:791`; `tests/commands_index.lua:58` |
| Command `areas` / `levels` | `PrintAreas`, `PrintLevels` | `GetAreaRows` / `GetLevelRows` | Primary | Implemented; parity with legacy path tested | `KillHistory/Commands.lua:471`, `:532`; `tests/areas_levels_parity.lua:66` |
| Command `history` / `splits` | `PrintHistory`, `PrintSplits` | `db.levelHistory` | Only | Implemented for v1; Journey `levels` time/XP not read | `KillHistory/Commands.lua:307`, `:347`; `KillHistory/Data.lua:1839` |
| Command `stats` / `probe` | `PrintStats`, `PrintProbe` | shared area/level rows + raw `db.totals`, `db.deaths`, `db.respawns`, `db.heatmaps` | Primary | Implemented; probe reports legacy stores only | `KillHistory/Commands.lua:80`, `:712` |
| Command `heatmap` | `PrintHeatmap` | `GetHeatmapZones` (legacy + Journey metadata); legacy cells only | Primary + additive | Partial; Journey-only zone has `cells = nil` and cannot print its grid | `KillHistory/Heatmap.lua:709`, `:544`, `:768` |
| Command `deaths` / `respawns` | `PrintDeaths`, `PrintRespawns` | `db.deaths`, `db.respawns` | Only | Implemented for v1 | `KillHistory/World.lua:268`, `:531` |
| `GetJourneyZoneStats` / `GetJourneyLevelStats` | none (tests/API only) | `journey.zones` / `journey.levels`, plus legacy count for comparison | Dual-read | Implemented but unconsumed by UI/commands | `KillHistory/JourneyQueries.lua:34`, `:59`; `tests/areas_levels_parity.lua:91` |
| `GetBestZonesForLevel` / `GetJourneyTimeSummary` / `GetMobJourneySummary` | none (tests/API only) | Journey zones/levels/time; `db.mobs` then block | Dual-read | Implemented but unconsumed by UI/commands | `KillHistory/JourneyQueries.lua:234`, `:323`, `:422`; `tests/journey_queries.lua:46` |

## Findings

### F1. Production is additive Journey over v1 aggregates

`NewEmptyClientData` defines `mobs`, `areas`, `levels`, `areaLevels`, `quests`,
`deaths`, `respawns`, `heatmaps`, `instances`, `levelHistory`, and `rates`
directly on the per-character table; it does not create `journey.mobs`,
`journey.instances`, `journey.quests`, or `journey.deaths` (only
`journey.zones`/`journey.levels`/`journey.questAnchors`/`journey.time` are
created later by `EnsureJourney`) (`KillHistory/Data.lua:109`). `EnsureDB` normalizes those v1 tables in place
(`KillHistory/Data.lua:724`) and only then normalizes Journey-owned
deaths/respawns/heatmaps (`KillHistory/Data.lua:735`).

`EnsureJourney` creates only `zones`, `levels`, `questAnchors`, `time`, and
schema/mode metadata (`KillHistory/Journey.lua:35`). `JourneyStorage` declares
`storageMode = "additive"` and derives blocks from `db.mobs` and `db.heatmaps`
(`KillHistory/JourneyStorage.lua:127`, `:152`, `:218`, `:317`).

Therefore a UI reader on `db.mobs`/`db.areas`/`db.levels` is reading the
current canonical production model, not a stale duplicate. The gap is against
the DS-17.5 **target** shape (`docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md:15`),
not against production capture.

### F2. Tooltip is legacy-first with one targeted block fallback

`resolveTooltipMob` returns `char.mobs[mobKey]` immediately if present and only
then consults `journey.blockReadFallback` and `GetJourneyMob`
(`KillHistory/Tooltip.lua:157`). The first block lookup is scoped to the current
map (`KillHistory/Tooltip.lua:169`). `tests/tooltip_fallback.lua:31` asserts
zero decodes when the legacy mob exists, one cold decode when it is removed
(`:37`), cache reuse on repeat (`:49`), and zero decodes under
`blockReadFallback = false` (`:62`).

The fallback query decodes a whole zone block, then renders only the fields it
needs (`kills`, name, classification, `mobLevelMin/Max`). There is no per-mob
cold query and no field projection; this is "one targeted block", not "only the
rendered fields".

### F3. Mobs list and Overview share a derived index, not a second store

`EnsureJourneyMobIndex` builds from `db.mobs` (`KillHistory/JourneyIndex.lua:45`)
and is invalidated on kill/quest/prune/reset (`KillHistory/JourneyIndex.lua:10`,
`KillHistory/Journey.lua:253`, `KillHistory/Data.lua:1104`). The list uses
`GetJourneyMobsForFilter` (`KillHistory/UI/List.lua:356`) and the Overview uses
`GetJourneyTopMobs` (`KillHistory/UI/Overview.lua:151`). Rollback is the direct
`db.mobs` scan.

This index cannot silently disagree with tooltip counts because both are fed by
the same `db.mobs` mutations. It is not persisted Journey data; A1/A3 should not
treat it as a Journey store.

### F4. Areas and Levels share one row helper with Detail and commands

`GetAreaRows` and `GetLevelRows` read `db.areas`/`db.instances` and `db.levels`
(`KillHistory/JourneyQueries.lua:83`, `:121`). The Areas tab
(`KillHistory/UI/List.lua:238`), Areas command
(`KillHistory/Commands.lua:479`), Overview top area
(`KillHistory/JourneyQueries.lua:149`), footer
(`KillHistory/UI/Window.lua:789`), minimap
(`KillHistory/UI/Minimap.lua:113`), statistics
(`KillHistory/Commands.lua:723`), and Area Detail
(`KillHistory/UI/Detail.lua:626`) all route through the same helper or the same
underlying table. `tests/areas_levels_parity.lua:64` and
`tests/area_level_summaries.lua:65` assert parity across legacy/index paths.

Journey zone/level totals are reported **separately**, never added:
`GetJourneyZoneStats` returns `kills` and `legacyKills`
(`KillHistory/JourneyQueries.lua:34`), and the comment at
`KillHistory/JourneyQueries.lua:80` says legacy remains canonical for identity.
No UI/command currently displays those Journey-only stats.

### F5. Heatmap selector and grid are bounded, but zone enumeration can outlive legacy data

The selector reads metadata from `GetHeatmapZoneIndex`
(`KillHistory/Heatmap.lua:322`) and does not decode a block;
`tests/heatmap_selector.lua:177` asserts zero decodes. The grid reads the
selected block cells when `selected.journeySource` is set
(`KillHistory/UI/Heatmap.lua:1276`), with legacy cells as fallback
(`:1282`); `tests/heatmap_bounded.lua:25` asserts one zone decode, cache reuse,
and legacy fallback for a missing block.

However, `GetJourneyHeatmapZones` enumerates every `journey.blockIndex` entry
with `heatmapKills > 0` (`KillHistory/JourneyStorage.lua:491`) and nothing prunes
that index. Legacy heatmaps are capped at 64 by dropping the oldest entry
(`KillHistory/Heatmap.lua:642`), and `ClearHeatmaps` only clears `db.heatmaps`
(`KillHistory/Heatmap.lua:668`). Blocks and `blockIndex` survive both events.
The selector then adds Journey-only zones back
(`KillHistory/Heatmap.lua:354`) and `GetHeatmapZones` does the same
(`KillHistory/Heatmap.lua:531`).

`tests/heatmap_bounded.lua:60` only covers a *missing* block, not a legacy zone
that was pruned or cleared while its block remains.

### F6. Heatmap header total and grid cells can come from different vintages

`RefreshHeatmap` takes `total` from `selected.total` (`KillHistory/UI/Heatmap.lua:1260`)
and prints it in the header (`:1267`). `selected.total` for a legacy-backed zone
comes from `db.heatmaps` metadata (`KillHistory/Heatmap.lua:342`), which is
updated immediately on each kill (`KillHistory/Heatmap.lua:628`). The grid cells
then come from the Journey block when `journeySource` is set
(`KillHistory/UI/Heatmap.lua:1276`), and blocks are only rebuilt on dirty-zone
flush (`KillHistory/JourneyStorage.lua:317`). Between a kill and the next flush,
the header can be current while the grid is stale. No test compares the header
total with the sum of the block cells.

### F7. Death, respawn, quest, and level-history views have no Journey counterpart

Capture writes `db.deaths` (`KillHistory/World.lua:189`, `:230`) and
`db.respawns` (`KillHistory/World.lua:493`), and the history views read those
same tables (`KillHistory/UI/List.lua:33`, `:65`;
`KillHistory/World.lua:268`, `:531`). Quest capture writes `db.quests`
(`KillHistory/Data.lua:1754`) and the ledger reads `db.quests`
(`KillHistory/UI/List.lua:148`). Level history reads `db.levelHistory`
(`KillHistory/Data.lua:1839`; `KillHistory/Commands.lua:307`).

`journey.questAnchors` is the only Journey-side quest structure
(`KillHistory/Journey.lua:270`), and `journey.levels` exists and holds XP/time
but is not used by the history or split views. DS-17.5 targets
`journey.deaths`, `journey.respawns`, and `journey.quests`; those tables are
absent from production, and `journey.levels` is not the reader's source.

### F8. Diagnostics reports the v1 store, not the Journey model

`GetDataStats` counts `db.mobs`, `db.quests`, `db.deaths`, `db.levelHistory`,
`db.rates`, `db.respawns`, `db.heatmaps`, `db.instances`, and `db.calibration`
(`KillHistory/UI/Diagnostics.lua:139`). Journey appears only as decoded-block
cache statistics and `blockBytes` (`KillHistory/UI/Diagnostics.lua:345`,
`:372`; `KillHistory/Module.lua:185`). There is no row for
`journey.zones`, `journey.levels`, `journey.blockIndex`, or the number of
stored Journey blocks.

This means an operator cannot see from Diagnostics that a cleared legacy
heatmap still has 64+ Journey blocks, which is the mechanism behind F5.

### F9. Commands mostly delegate; the heatmap command is the exception

`PrintKills`/`PrintDump` use the same index as the UI
(`KillHistory/Commands.lua:205`, `:797`), `PrintAreas`/`PrintLevels` use the
shared rows (`:478`, `:539`), and `PrintStats` uses the same rows for counts
(`:720`). `PrintHistory`/`PrintSplits` use `db.levelHistory`
(`:313`, `:355`). `PrintDeaths`/`PrintRespawns` use `db.deaths`/`db.respawns`.

`PrintHeatmap` is different: it obtains `GetHeatmapZones`
(`KillHistory/Heatmap.lua:729`), and for a Journey-only zone that function
returns `cells = nil` (`KillHistory/Heatmap.lua:550`). The listing path handles
nil through `CountCells` (`:756`), but the requested-zone path iterates
`pairs(zone.cells)` unguarded (`:768`). After a heatmap clear with retained
blocks, `/acem2l2 xpt heatmap <zone>` can error and cannot print Journey cell
data even when the block has it.

## Required checks

| Check | Result | Evidence |
|---|---|---|
| No stale legacy table silently disagrees with Journey | **Partial** — legacy is the declared source of truth, so ordinary reads agree; four divergences remain: stale block-only zones, heatmap header vs block cells, unlabelled block-only tooltip mobs, and v1-only history/quest views. | Gaps G1, G6, G8, G12; `KillHistory/Data.lua:109`; `KillHistory/JourneyStorage.lua:491`; `KillHistory/UI/Heatmap.lua:1260` |
| Fallback view switches are explicit and tested | **Pass** — `journey.indexViews` and `journey.blockReadFallback` are explicit flags; index, block, and missing-block fallbacks have focused tests. | `KillHistory/JourneyIndex.lua:16`; `KillHistory/Tooltip.lua:163`; `KillHistory/UI/Heatmap.lua:1282`; `tests/areas_levels_parity.lua:116`; `tests/tooltip_fallback.lua:62`; `tests/heatmap_bounded.lua:72` |
| Selected heatmap/zone reads do not decode unrelated blocks | **Pass** — zone list is metadata only; selected cells decode one block and cache. | `KillHistory/JourneyStorage.lua:491`; `KillHistory/JourneyStorage.lua:476`; `tests/heatmap_bounded.lua:25`; `tests/heatmap_selector.lua:177` |
| Area/level summaries use the same totals as Detail | **Pass** — List, Detail, Overview, footer, minimap, commands, and stats share `GetAreaRows`/`GetLevelRows`. | `KillHistory/JourneyQueries.lua:83`, `:121`; `tests/areas_levels_parity.lua:64`; `tests/area_level_summaries.lua:65` |
| Tooltip fetches only fields it renders | **Partial** — legacy path uses the full `db.mobs` record; block path decodes a whole zone block and projects fields in the renderer. No per-mob cold projection exists. | `KillHistory/Tooltip.lua:157`; `KillHistory/JourneyStorage.lua:288`; `KillHistory/JourneyStorage.lua:452` |
| No block scan for global/random tooltip | **Partial** — current-zone lookup is one block; the second `GetJourneyMob(mobKey)` call iterates every `mobZones` reference for that mob, with no DS-17.5 ≤4 cap. | `KillHistory/Tooltip.lua:169`; `KillHistory/JourneyStorage.lua:127`; `KillHistory/JourneyStorage.lua:536` |

## Gaps

| ID | Gap | Severity | Evidence | Proposed follow-up |
|---|---|---|---|---|
| G1 | Production does not implement the DS-17.5 v2 shape; readers use v1 aggregates plus additive Journey. The audit cannot certify “readers use `journey.mobs/instances/quests/deaths/respawns/...`” because those tables do not exist (`journey.zones`/`journey.levels` exist but are not the readers' source). | Critical for A5 consolidation | `KillHistory/Data.lua:109`, `:724`; `KillHistory/JourneyStorage.lua:218`; `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md:15` | A5 must decide: (a) DS-17.5 is the target and these are migration gaps, or (b) production additive model is the baseline and DS-17.5 is re-scoped. Record the decision before assigning reader work. |
| G2 | Death and respawn history readers are legacy-only; no `journey.deaths`/`journey.respawns` is written or queried. | High | `KillHistory/World.lua:189`, `:493`; `KillHistory/UI/List.lua:33`, `:65`; `KillHistory/Commands.lua:1133`, `:1135` | A2/A5 to confirm whether DS-17.5 death/respawn fields are still targeted. If yes, add capture + read in a later migration task; if no, mark these views explicitly v1-owned. |
| G3 | Quest ledger reads `db.quests`; `journey.quests` is absent, and only `journey.questAnchors` is additive. | High | `KillHistory/Data.lua:1754`; `KillHistory/UI/List.lua:157`; `KillHistory/Commands.lua:274`; `KillHistory/Journey.lua:295` | Same decision as G2. If `journey.quests` is the target, the ledger/detail/command must switch together; anchors alone are not the ledger. |
| G4 | Level history and splits read `db.levelHistory`; `journey.levels` carries XP/time but no reader consumes it. | Medium | `KillHistory/Commands.lua:307`, `:355`; `KillHistory/UI/Overview.lua:250`; `KillHistory/Journey.lua:96` | Decide whether `journey.levels` supersedes `db.levelHistory` or is a parallel aggregate. If superseding, switch all three readers with parity tests. |
| G5 | Journey query surface is unconsumed: `GetJourneyZoneStats`, `GetJourneyLevelStats`, `GetBestZonesForLevel`, `GetJourneyTimeSummary`, `GetMobJourneySummary` have no UI/command caller. | Medium | `KillHistory/JourneyQueries.lua:34`, `:59`, `:234`, `:323`, `:422`; `tests/journey_queries.lua:46` | A5 to either wire them into Area/Level detail and Overview, or explicitly mark them API/test-only so they are not mistaken for live views. |
| G6 | `journey.blockIndex`/blocks are never pruned while `db.heatmaps` is capped/cleared. Selector and `GetHeatmapZones` re-add Journey-only zones, so stale zones can appear and Diagnostics disagrees. | High | `KillHistory/Heatmap.lua:642`, `:668`, `:531`; `KillHistory/JourneyStorage.lua:491`; `KillHistory/UI/Heatmap.lua:354` | Add a retention rule: prune `blockIndex` (and optionally blocks) with heatmap retention/clear, or filter Journey zone lists to currently retained legacy maps. Add a clear/prune test with a Journey-only block. |
| G7 | `PrintHeatmap` cannot render a Journey-only zone: `GetHeatmapZones` supplies `cells = nil`, and the requested-zone path calls `pairs(zone.cells)` unguarded. | High | `KillHistory/Heatmap.lua:544`, `:550`, `:768`; `KillHistory/Heatmap.lua:729` | Make `PrintHeatmap` use `GetJourneyHeatmapCells` for `journeySource` zones or guard nil, and add a command test for a Journey-only zone. |
| G8 | A block-only mob can appear in tooltip/Detail but not in Mobs/Overview/Diagnostics; the tooltip does not label the cold source, while Detail does. | Medium | `KillHistory/Tooltip.lua:157`, `:192`; `KillHistory/UI/Detail.lua:361`; `KillHistory/JourneyIndex.lua:45`; `KillHistory/UI/Diagnostics.lua:139` | Decide whether cold-only records belong in list views. At minimum add a visible block/cold marker to the tooltip line and a diagnostics count of block-only records. |
| G9 | Tooltip fallback without a zone key iterates every `mobZones` reference for the mob; the DS-17.5 ≤4-zone cap is not enforced in `buildMobZoneIndex`. | Medium | `KillHistory/Tooltip.lua:171`; `KillHistory/JourneyStorage.lua:127`, `:536` | Cap `mobZones` to the DS-17.5 ≤4 refs or make the fallback current-zone-only; add a multi-zone tooltip decode-budget test. |
| G10 | UI labels do not reflect the DS-17.5 player-level vs mob-level rename. Active Mob/Area detail says “Level range” for player levels from `killsAtLevel`/`areaLevels`; block/historical paths say “Mob level range” for mob levels. | Low but directly relevant to the model | `KillHistory/UI/Detail.lua:398`, `:366`; `KillHistory/UI/Detail.lua:641`; `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md:48` | If G1 chooses v2, rename `killsAtLevel` to `byPlayerLevel` and label UI “Player level range” vs “Mob level range”. If v1 stays, label both explicitly. |
| G11 | Diagnostics has no Journey zone/level/blockIndex coverage; only cache and byte size. | Low | `KillHistory/UI/Diagnostics.lua:334`; `KillHistory/Module.lua:185` | Add non-feature rows: Journey schema/zones/levels/block zones/dirty zones so operators can see divergence. |
| G12 | Heatmap header total (legacy metadata) and rendered grid (Journey block) can be from different vintages until a dirty flush. | Medium | `KillHistory/UI/Heatmap.lua:1260`, `:1276`; `KillHistory/Heatmap.lua:628`; `KillHistory/JourneyStorage.lua:317` | Derive the header total from the same cell set used for the grid, or label the grid source/staleness. Add a test that kills after the last flush and compares header sum to rendered cells. |

## Open questions

1. **Q1 — Which schema is the acceptance baseline?** DS-17.5 defines v2
   `journey.*`; production is additive v1 + `journey.zones/levels/blocks`.
   Without an A5 decision, G2–G4 and G10 are either required migrations or
   documentation corrections.
2. **Q2 — Should “Clear heatmap” clear Journey blocks too?** Today it clears
   only `db.heatmaps` (`KillHistory/Heatmap.lua:668`), leaving block zones that
   the selector can re-add.
3. **Q3 — Are cold block-only mobs first-class?** They are reachable by
   tooltip/Detail but invisible to Mobs/Overview/Diagnostics. Is that the
   intended “cold archive” behavior?
4. **Q4 — Are Journey zone/level stats meant to be user-visible?** They are
   implemented and tested but have no caller.
5. **Q5 — What should “kills” mean in the heatmap selector?** The selector uses
   heatmap kills (`KillHistory/UI/Heatmap.lua:175`), which can differ from the
   Areas tab’s area kills for the same map. The test intentionally asserts
   heatmap kills (`tests/heatmap_selector.lua:92`); the UI does not explain the
   distinction.
6. **Q6 — Should area Detail prefer anchors over the full ledger?** When any
   `journey.questAnchors` exist for a map, the older `db.quests` entries for
   that map are not shown (`KillHistory/UI/Detail.lua:563`). Is that acceptable
   partial history?

## No-change statement

No production Lua, tests, `PLAN.md`, `NEXT-TASK.md`, or other audit report was
edited. Only this report file was created. Nothing was committed or pushed.

**no code changed; no tests run.**
