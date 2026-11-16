# IMP-1B — Journey query API result

**Status:** query API slice executed 2026-11-16  
**Production module:** `KillHistory/JourneyQueries.lua`  
**Test:** `tests/journey_queries.lua`; included in `tests/run_all.sh`  
**Scope:** read-only production queries over `db.journey` and existing data. No
schema migration, block storage, save policy, or UI.

## 1. Implemented APIs

- `GetJourneyZoneStats(zoneKey)`
- `GetJourneyLevelStats(level)`
- `GetBestZonesForLevel(level, mode)` — `total` or `kill`
- `GetHeatmapTopCells(mapID, count)`
- `GetMobJourneySummary(mobKey)`
- `GetQuestAnchor(questID)`
- `GetJourneyTimeSummary()`

All are read-only and scan only the relevant per-zone/level tables.

## 2. Best-zone query

Uses the per-zone/level records added by IMP-1A:

```text
xpPerHour     = xp / (engagedSeconds / 3600)
killXPPerHour = killXP / (engagedSeconds / 3600)
```

If engaged time is unavailable, presence time is used.

Confidence:

- low: < 1,800 engaged seconds
- medium: ≥ 1,800
- high: ≥ 7,200

Test seed:

| Zone | killXP | questXP | total XP | engaged | Total XP/hour | Kill XP/hour |
|---|---:|---:|---:|---:|---:|---:|
| 12 | 100,000 | 200,000 | 300,000 | 3,600 | **300,000** | 100,000 |
| 13 | 250,000 | 0 | 250,000 | 3,600 | 250,000 | **250,000** |
| 14 | 10,000 | 0 | 10,000 | 600 | 60,000 | 60,000 |

- total XP/hour ranks Zone 12 first;
- kill-only XP/hour ranks Zone 13 first.

This is the expected quest-XP separation.

## 3. Other queries

- Legacy `db.areas` kills are merged into `GetJourneyZoneStats`.
- Heatmap top cells support numeric cells and future table cells.
- Mob summary returns name/npcID/kills/XP/zone refs.
- Quest anchor returns `lastTurnInAt`, map, player level.
- Time summary returns current zone/level/last event/last kill/cap.

## 4. Tests

`tests/journey_queries.lua` asserts:

- total vs kill-only best-zone ranking;
- confidence from engaged time;
- legacy zone kills merge;
- heatmap top cells/share;
- mob summary;
- quest anchor;
- journey time summary.

`tests/run_all.sh` passes.

## 5. What remains

This slice is query-only. Still required:

- v2 schema migration of existing `mobs`/`areas`/`levels`/heatmaps/deaths/quests;
- per-zone/instance/name-only block storage;
- login zero-decode + selected-block lazy decode;
- dirty-block save/checksum/backup/guard;
- tooltip danger/XP integration;
- heatmap best-part UI;
- account Knowledge/merge;
- UI.

These are **IMP-1B2 — Production Journey migration and block storage**.

## 6. Findings

1. **Query APIs work over the production Journey instrumentation.**
2. **Total vs kill-only XP/hour ranking can differ** when quest XP is present.
3. **Confidence from engaged time is straightforward.**
4. **Legacy zone kills can be merged without migrating storage yet.**
5. **The query layer is read-only and low risk.**
6. **Block storage/migration remains the harder integration step.**

## Artifacts

- `KillHistory/JourneyQueries.lua`
- `KillHistory/Journey.lua`
- `AceM2L2.toc`
- `tests/journey_queries.lua`
- `tests/run_all.sh`
- `docs/IMP-1A-JOURNEY-INSTRUMENTATION-RESULT.md`
