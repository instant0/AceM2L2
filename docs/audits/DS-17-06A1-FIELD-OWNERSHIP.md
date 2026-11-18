# DS-17.6A1 — Field ownership audit

**Status:** complete (read-only slice; no source, test, or shared-doc edits)
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`
**Task:** `docs/tasks/DS-17-06A1-FIELD-OWNERSHIP.md`
**Date:** 2026-11-18

## 1. Scope

Field-by-field ownership of the current production Journey:

- logical field inventory for mobs, zones/instances, levels, kills/XP, time,
  contexts, deaths, quests/anchors, respawns, heatmaps, sessions, and
  schema/meta/project identity;
- comparison against the DS-17.5 v2 Journey schema;
- status, owner layer, and `file:line` / `file:function` evidence per field;
- duplicated/unowned fields and level-semantics ambiguities.

Out of scope (other A-slices):

- event write-path tracing and capture timing (A2);
- physical blocks, codec, caches, save/backup/migration mechanics (A3);
- UI/command consumers and query truth (A4).

No feature work, no docker/live client, no test execution.

## 2. Files read

Production Lua:

- `KillHistory/Journey.lua` (full)
- `KillHistory/JourneyStorage.lua` (full)
- `KillHistory/JourneyQueries.lua` (full)
- `KillHistory/JourneyIndex.lua` (full)
- `KillHistory/Data.lua` (schema/identity/normalization/mob/quest/level-history sections)
- `KillHistory/Tracking.lua` (kill/XP/session/context capture sections)
- `KillHistory/Calibration.lua` (observation/context sections)
- `KillHistory/Formula.lua` (context key)
- `KillHistory/Heatmap.lua` (record/normalize/index sections)
- `KillHistory/World.lua` (death/respawn sections)
- `KillHistory/Events.lua` (session start + event wiring)
- `KillHistory/Tooltip.lua` (block fallback mapping)
- `KillHistory/Commands.lua`, `KillHistory/Module.lua` (reset, diagnostics, account profile)

Design / decision documents:

- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/DS-11-DECISION-RECORD.md`
- `docs/DATA-MODEL-PLAN.md`
- `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md` (field inventory cross-check)

## 3. Method

1. Read the DS-17.5 Journey/Knowledge schema and the DS-11 field decisions.
2. Extracted every field reachable from `char.journey.*` plus the char-level
   stores that DS-17.5 names as migration targets (`mobs`, `areas`, `levels`,
   `areaLevels`, `instances`, `deaths`, `quests`, `respawns`, `heatmaps`,
   `session`, `levelHistory`).
3. For each field, located a production writer and reader and recorded the
   site as `file:line` or `file:function`.
4. Matched to the DS-17.5 v2 name; recorded status and owner layer.

Status semantics used in this report:

- **implemented** — field exists under the DS-17.5 name or an unambiguous
  equivalent, with a production writer and reader.
- **partial** — field exists but is incomplete, has the wrong shape, is stored
  under a conflicting/legacy name, or has no production writer.
- **missing** — no production field or no production writer at all.
- **V-2-only** — designed, but capture requires live-client confirmation
  (DS-11 §6); not verifiable offline.

Owner layers are restricted to: static metadata, per-character Journey, future
Knowledge, UI/derived.

The required table is split by field group for readability; every section uses
the exact required columns.

## 4. Field ownership table

### 4.1 Mob identity, naming, classification

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| mob key | `char.mobs[key]` with `npc:<id>` or `name:<lower>` | `journey.mobs[key]` | partial | static metadata | `Tracking.lua:207-227`, `Data.lua:1976-2032` | Stable `npc:` key preferred; name-only records stay per character. No `journey.mobs`. |
| `npcID` | `char.mobs[key].npcID` | `mobs[key].npcID` | implemented | static metadata | `Data.lua:1987`, `Data.lua:2011-2013` | 100/158 populated locally (DS-17.5 §3). |
| `name` | `char.mobs[key].name` | `mobs[key].name` | implemented | static metadata | `Data.lua:1988`, `Data.lua:2014-2018` | Fallback is `"Unknown"`, not DS-11's `NPC <id>`. |
| `classification` | `char.mobs[key].classification` | `mobs[key].classification` | implemented | static metadata | `Data.lua:1989`, `Data.lua:2019-2023`, `Tracking.lua:551` | "normal" default. |
| `firstSeen` | `char.mobs[key].firstSeen` | `mobs[key].firstSeen` | implemented | per-character Journey | `Data.lua:1990`, `Data.lua:2025` | Dropped by block records (`JourneyStorage.lua:288-293`). |
| `lastSeen` | `char.mobs[key].lastSeen` | `mobs[key].lastSeen` | implemented | per-character Journey | `Data.lua:1991`, `Tracking.lua:234` | Dropped by block records. |
| `zones` (≤4 refs) | `char.journey.mobZones[mobKey]` | `mobs[key].zones` | partial | static metadata | `JourneyStorage.lua:328-335`, `JourneyStorage.lua:520-527` | Rebuilt per flush from live maps; no 4-ref cap; instance refs capped at 20 (`Data.lua:1700-1733`). |
| `respawn` (per mob) | `char.respawns[npcID]` | `mobs[key].respawn` | partial | per-character Journey | `World.lua:443-491` | Keyed by `npcID`, not embedded in the mob record. |

### 4.2 Mob level range and player-level subcounts

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| `mobLevelMin` / `mobLevelMax` | `char.mobs[key].mobLevelMin/Max` (read path only); block record `mobLevelMin/Max` | `mobs[key].mobLevelMin`, `mobLevelMax` | partial | static metadata | `Data.lua:46-72` (reader), `JourneyStorage.lua:102-112`, `JourneyStorage.lua:122-124`, `JourneyStorage.lua:292`, `UI/Detail.lua:366-368` | Derived from contexts only at block encode; never written back to `char.mobs`. `UI/Detail` therefore reads nil. |
| `mobLevelSamples` | — | `mobs[key].mobLevelSamples` | missing | static metadata | no writer; DS-17.5 requires level at sighting (`DS-17-05:173`) | DS-17.5 measured "1/158 known". |
| observed mob level | `char.mobs[key].contexts[key].mobLevel` | `mobs[key].contexts[].mobLevel` | implemented | per-character Journey | `Calibration.lua:157`, `Calibration.lua:176`, `Tracking.lua:816`, `Formula.lua:26-38` | Only recorded when a calibration observation succeeds (`Calibration.lua:147-166`). |
| `byPlayerLevel` | `char.mobs[key].killsAtLevel[playerLevel]` | `mobs[key].byPlayerLevel` | partial | per-character Journey | `Tracking.lua:241-245`, `Data.lua:1744` | Legacy name; value is player level (DS-17.5 §"Critical naming fix"). |
| `levels[playerLevel]` | `char.journey.levels[<playerLevel>]` | `journey.levels[playerLevel]` | partial | per-character Journey | `Journey.lua:96-107`, `Journey.lua:161-165`, `JourneyQueries.lua:59-78` | Keyed by player level; no `startedAt`/`endedAt`. |
| `levelHistory[]` | `char.levelHistory[n]` | `levels[].startedAt/endedAt` + xp/presence | partial | per-character Journey | `Data.lua:1839-1974` | Duplicate XP/kill owner alongside `journey.levels`. |

### 4.3 Zone and instance breakdowns

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| `byZone[map].kills` | `char.mobs[key].killsByMap[map]` | `mobs[key].byZone[map].kills` | partial | per-character Journey | `Tracking.lua:306-310`, `Data.lua:1745` | Rename pending; also mirrored in `char.areas`. |
| `byZone[map].playerLevels` | `char.mobs[key].killsByAreaLevel[map][level]` | `mobs[key].byZone[map].playerLevels` | partial | per-character Journey | `Tracking.lua:311-325`, `Data.lua:1746` | Duplicates `char.areaLevels[map][level]`. |
| `byInstance[key].kills` | `char.mobs[key].killsByInstance[key]` | `mobs[key].byInstance[key].kills` | partial | per-character Journey | `Tracking.lua:246-305`, `Data.lua:1747` | Pruned to 20 instance refs per mob. |
| `byInstance[key].playerLevels` | `char.mobs[key].killsByInstanceLevel[key][level]` | `mobs[key].byInstance[key].playerLevels` | partial | per-character Journey | `Tracking.lua:289-300`, `Data.lua:1748` | Same prune. |
| `journey.zones[map]` | `char.journey.zones[<mapID>]` | `journey.zones[map]` | partial | per-character Journey | `Journey.lua:71-83` | Keys are bare map IDs (`"12"`); blocks use `"map:12"`. |
| `zones[map].playerLevels` | `char.journey.zones[map].levels[level]` | `journey.zones[map].playerLevels` | partial | per-character Journey | `Journey.lua:85-94`, `Journey.lua:118-119` | Full per-level records, not a subcount map. |
| `zones[map].uniqueMobs` | — | `journey.zones[map].uniqueMobs` | missing | per-character Journey | only global `char.totals.uniqueMobs` (`Data.lua:794`) | No per-zone unique count. |
| `zones[map].sessions` | `char.journey.zones[].sessions` (initialized) | `journey.zones[map].sessions` | missing | per-character Journey | init `Journey.lua:77`; no writer | Always 0. |
| `journey.instances[key]` | — (legacy `char.instances[key]` only) | `journey.instances[key]` | missing | per-character Journey | `Data.lua:212-240`; no `journey.instances` | Instance kills land in `journey.zones[<instanceMapID>]`. |
| `instances[].presenceSeconds/engagedSeconds/deaths/uniqueMobs` | — | same | missing | per-character Journey | legacy entry has kills/xp/session/level only (`Tracking.lua:251-265`, `Data.lua:225-239`) | No instance time/death/unique fields. |

### 4.4 Kills and XP

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| `mob.kills` | `char.mobs[key].kills` | `mobs[key].kills` | implemented | per-character Journey | `Tracking.lua:232` | |
| `mob.xp` (total kill XP) | `char.mobs[key].totalXP` | `mobs[key].xp` (numeric) | partial | per-character Journey | `Tracking.lua:361`, `Data.lua:1337-1343`, `JourneyStorage.lua:121`, `JourneyStorage.lua:285` | **Name collision:** production `mob.xp` is a table (see next row). |
| `mob.xp` (observation stats) | `char.mobs[key].xp` table (`samples/sumBase/sumBuffed/sumTotal/minBase/maxBase/lastBase/lastTotal`) | not in DS-17.5 | implemented | per-character Journey | `Calibration.lua:205-221`, `Data.lua:2003` | Unowned by DS-17.5; occupies the name DS-17.5 gives scalar XP. |
| `mob.sessionKills` / `sessionXP` / `sessionXPKnown` | `char.mobs[key].*` | same | partial | per-character Journey | `Tracking.lua:233`, `Tracking.lua:362-363`, `Data.lua:1740-1743` | Never reset by `StartSession` (`Events.lua:184-191`), so "session" is lifetime. |
| `zones[].kills` / `killXP` / `xp` | `char.journey.zones[].kills/killXP/xp` | `journey.zones[map].*` | implemented | per-character Journey | `Journey.lua:75`, `Journey.lua:155-169`, `Journey.lua:248-249` | Post-instrumentation subset; never added to legacy counts (`JourneyQueries.lua:43-47`). |
| `zones[].questXP` | `char.journey.zones[].questXP` | `journey.zones[map].questXP` | implemented | per-character Journey | `Journey.lua:293` | |
| `zones[].otherXP` | `char.journey.zones[].otherXP` | `journey.zones[map].otherXP` | partial | per-character Journey | init `Journey.lua:75`; `addXP` supports the field (`Journey.lua:155-169`) but no caller passes `"otherXP"` | No writer; always 0. |
| `zones[].quests` (count) | `char.journey.zones[].quests` | not in DS-17.5 | implemented | per-character Journey | `Journey.lua:179-186`, `Journey.lua:294` | Extra field, also written per level. |
| `levels[].killXP/questXP/otherXP/xp` | `char.journey.levels[]` | `journey.levels[].*` | partial | per-character Journey | `Journey.lua:101-102`, `Journey.lua:161-168` | `otherXP` has no writer. |
| kill XP attribution | `char.mobs[].totalXP` + `journey` `killXP` | `mobs[].xp`, `zones[].killXP` | implemented | per-character Journey | `Tracking.lua:361`, `Tracking.lua:419`, `Journey.lua:249`, `Journey.lua:266-267` | Late/chat XP uses `OnJourneyKillXP`. |
| unattributed XP | `char.unattributed {events,xp,byLevel,byMap,lastSeen}` | not in DS-17.5 Journey | implemented | per-character Journey | `Data.lua:114`, `Data.lua:162-179`, `Data.lua:844` | Never folded into `otherXP`. |
| quest XP ledger | `char.quests["quest:<id>"].totalXP` | `journey.quests` | partial | per-character Journey | `Data.lua:1754-1793`, `Journey.lua:293` | Lives in the legacy quest table. |

### 4.5 Presence and engaged time

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| `presenceSeconds` (zone/level/zone-level) | `journey.zones[].presenceSeconds`, `journey.levels[].presenceSeconds`, `journey.zones[].levels[].presenceSeconds` | `presenceSeconds` | implemented | per-character Journey | `Journey.lua:109-120`, `Journey.lua:136-142` | Uncapped gap since last event (AFK-inclusive). |
| `engagedSeconds` (zone/level/zone-level) | same three places | `engagedSeconds` | implemented | per-character Journey | `Journey.lua:122-134`, `Journey.lua:243-245`, `Journey.lua:345-347` | Capped at 60 s per gap (`Journey.lua:13`, `Journey.lua:127`). |
| per-instance time | — | `journey.instances[].presenceSeconds/engagedSeconds` | missing | per-character Journey | no writer | |
| per-mob time | — | `mobs[key].presenceSeconds/engagedSeconds` | missing | per-character Journey | no writer; block mob record has none (`JourneyStorage.lua:288-293`) | |
| runtime time cursor | `char.journey.time {zone,level,lastEventAt,lastKillAt,cap}` | not in DS-17.5 | implemented | per-character Journey | `Journey.lua:60-66`, `Journey.lua:188-201`, `JourneyQueries.lua:422-435` | Persisted runtime state; `lastEventAt`/`lastKillAt` zeroed at logout (`Journey.lua:348-349`). |

### 4.6 Combat and XP contexts

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| `contexts` | `char.mobs[key].contexts[key]` (string-keyed map) | `mobs[key].contexts` (array) | partial | per-character Journey | `Calibration.lua:168-203`, `Data.lua:1750`, `Formula.lua:26-38` | Map, not array. Key encodes `p/m/g/z/c/b/i`. |
| context record fields | `playerLevel, mobLevel, groupSize, mapID, instanceKey, classification, buffSig, samples, sumBase, sumBuffed, sumTotal, minBase, maxBase, lastSeen` | `contexts[]` | implemented | per-character Journey | `Calibration.lua:174-203` | `buffSig`/`groupSize` reliability is V-2 (DS-11 §6). |
| `combat` contexts | — | `mobs[key].combat` | missing | per-character Journey | no field; contexts carry no health/outcome/time-to-kill | Danger cannot be computed. |
| `xpContexts` | `char.mobs[key].contexts` + `char.mobs[key].xp` | `mobs[key].xpContexts` | missing | per-character Journey | no separate structure | One map serves observation and XP roles. |
| cold context retention | — | top-8 + `other`, packed | missing | per-character Journey | blocks encode no contexts (`JourneyStorage.lua:184-205`) | Retention policy not implemented. |
| calibration ratios | `char.calibration.{zones,levels,groups,classes,mobs}` | not in DS-17.5 | implemented | per-character Journey | `Calibration.lua:231-240`, `Data.lua:754-759` | Estimation support, not Journey history. |

### 4.7 Death fields

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| death record | `char.deaths[n] {at,mapID,x,y}` | `journey.deaths[]` | partial | per-character Journey | `World.lua:155-187`, `World.lua:202-238` | Normalizer reconstructs only these four fields. |
| mob attribution (`mobKey`/`npcID`) | — | `deaths[].mobKey/npcID` | V-2-only | per-character Journey | no writer; DS-17.5 §4 (`DS-17-05:153`); DS-11 §6 | Needs live killer GUID. |
| health before/after | — | `deaths[].health` | V-2-only | per-character Journey | no writer | |
| buffs / group / classification / difficulty | — | same | V-2-only | per-character Journey | no writer; difficulty exists only on `char.instances` (`Data.lua:229`) | |
| death combat context | — | `deaths[].context` | missing | per-character Journey | no writer | Depends on combat contexts. |
| zone/level death counters | `journey.zones[].deaths`, `journey.zones[].levels[].deaths`, `journey.levels[].deaths` | same | partial | per-character Journey | init `Journey.lua:77`, `Journey.lua:90`, `Journey.lua:102`; `addEvent` is never called with `"deaths"` | Always 0. |

### 4.8 Quests and quest anchors

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| quest records | `char.quests["quest:<id>"] {id,name,count,totalXP,lastXP,firstSeen,lastSeen}` | `journey.quests` | partial | per-character Journey | `Data.lua:1754-1793` | Still the legacy table; no `journey.quests`. |
| `lastTurnInAt` / `mapID` / `playerLevel` | `char.quests[key].*` | `journey.quests[].lastTurnInAt/mapID/playerLevel` | partial | per-character Journey | `Journey.lua:314-319`, `JourneyQueries.lua:403-420` | Written only if a matching quest record already exists. |
| quest anchors | `char.journey.questAnchors[] {questID,mapID,at,playerLevel,xp,x,y}` | not in DS-17.5 | implemented | per-character Journey | `Journey.lua:171-177`, `Journey.lua:295-306`, cap `Journey.lua:12`+`47-58` | Extra unbounded-by-design list, capped at 5000. |
| anchor read API | `GetQuestAnchors` / `GetQuestAnchor` | (consumer of quests/anchors) | implemented | UI/derived | `JourneyQueries.lua:360-420` | Joins anchors to quest names. |

### 4.9 Respawn aggregates

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| respawn record | `char.respawns[npcID] {name,intervals[],lastSeen,lastDeath}` | `journey.respawns` | partial | per-character Journey | `World.lua:304-368`, `World.lua:443-491` | Keyed by `npcID` at char level, not `journey.respawns`. |
| respawn aggregates (avg/samples/min/max) | `GetRespawnStats(npcID)` | `respawns[].avg/samples/min/max` | partial | UI/derived | `World.lua:493-529` | Computed per call from raw intervals; average suppressed below `MIN_RESPAWN_SAMPLES`. |

### 4.10 Heatmap cells, totals, top-N, lastSeen

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| heatmap zone record | `char.heatmaps[map] {gridSize,cells,total,lastSeen}` | `journey.heatmaps` | partial | per-character Journey | `Heatmap.lua:592-651`, `Heatmap.lua:422-490` | Legacy store plus separate block cells. |
| cell kill count | `char.heatmaps[map].cells[cell]` (scalar) | `cells[cell].kills` | partial | per-character Journey | `Heatmap.lua:628-631` | Scalar count, not a record. |
| cell XP / presence / engaged | block cells fields | `cells[cell].xp/presenceSeconds/engagedSeconds` | V-2-only | per-character Journey | `JourneyStorage.lua:163-168`, `JourneyStorage.lua:196-203`, `JourneyStorage.lua:300-311` | Schema exists; source value is always 0 (`Heatmap.lua:630`). |
| heatmap total | `char.heatmaps[map].total`; `char.journey.blockIndex["map:*"].heatmapKills` | `heatmaps[].total` | implemented | per-character Journey | `Heatmap.lua:631`, `Heatmap.lua:466`, `JourneyStorage.lua:380` | Stored twice. |
| heatmap `lastSeen` | `char.heatmaps[map].lastSeen`; `blockIndex.lastSeen` | `heatmaps[].lastSeen` | implemented | per-character Journey | `Heatmap.lua:633`, `JourneyStorage.lua:381` | Stored twice. |
| top-N cells | `GetHeatmapTopCells` → `TopHeatmapCells` | top-N hotspot summary retained | partial | UI/derived | `JourneyQueries.lua:279-321` | Recomputed per query; not persisted. |
| heatmap zone index | `char.journey.blockIndex` merged with `char.heatmaps` | (summary index) | implemented | per-character Journey | `JourneyStorage.lua:491-518`, `Heatmap.lua:322-390` | Two sources merged for the zone list. |

### 4.11 Sessions and level history

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| current session | `char.session {startedAt,kills,xp}` | `journey.sessions` | partial | per-character Journey | `Events.lua:184-191`, `Tracking.lua:347`, `Tracking.lua:365` | One live session at char level; reset at login. |
| session history | — | `journey.sessions[]` | missing | per-character Journey | no writer | No past-session records. |
| level history | `char.levelHistory[] {level,startedAt,endedAt,xpGained,kills,duration}` | `journey.levels[].startedAt/endedAt` | partial | per-character Journey | `Data.lua:1839-1974` | Split ownership: XP in `levelHistory` vs `journey.levels`. |

### 4.12 Schema, meta, and project identity

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| `journey.schema` | `char.journey.schema = 1` | not enumerated for Journey | implemented | per-character Journey | `Journey.lua:11`, `Journey.lua:41` | Value 1 conflicts with storage schema 2; never validated on load. |
| `storageSchema` | `AceM2L2CharDB.xpTooltip.storageSchema = 2` | schema 2 | implemented | per-character Journey | `Data.lua:28`, `Data.lua:622-625`, `Data.lua:671`, `JourneyStorage.lua:11` | The only value that rejects a newer schema. |
| `char.dataSchema` | `char.dataSchema = 1` | not in DS-17.5 | implemented | per-character Journey | `Data.lua:29`, `Data.lua:703-722` | Blocks on a newer client schema. |
| `calibrationVersion` | `char.calibrationVersion` | not in DS-17.5 | implemented | per-character Journey | `Data.lua:712-719`, `Calibration.lua:255` | Drives one-time observation reset. |
| `journey.projectID` | `char.journey.projectID` | `projectID` (listed for Knowledge only) | implemented | per-character Journey | `Journey.lua:42` | Also implicit client root `root.clients[projectID]` (`Data.lua:697-701`). |
| `journey.mode` | `char.journey.mode` (`"leveling"`) | `mode` (listed for Knowledge only) | implemented | per-character Journey | `Journey.lua:43` | Never changes after first write. |
| `interface`, `levelCap`, class/race/faction, playtime | — | `knowledge.interface`, `levelCap` | missing | future Knowledge | only runtime probes (`Commands.lua:37`); no stored field | |
| account Knowledge | — | `knowledge.*` | missing | future Knowledge | only `AceM2L2DB.profile` exists (`Module.lua:40-46`) | Explicitly deferred (DS-11 §2.8). |
| storage meta | `journey.storageSchema/storageMode/blockReadFallback/saveBlocked/oversizeSeen/oversizeAt/storageUpdatedAt` | not in DS-17.5 | implemented | per-character Journey | `JourneyStorage.lua:210-219`, `JourneyStorage.lua:390`, `JourneyStorage.lua:407-419` | Operational state, not analytical data. |
| blocks / blockIndex / backup / dirty / mobZones | `journey.blocks`, `blockIndex`, `blockBackup`, `dirtyZones`, `mobZones` | schema-2 blocks + summary | implemented | per-character Journey | `JourneyStorage.lua:211-215`, `JourneyStorage.lua:317-392` | Block mob record carries only 8 fields (`JourneyStorage.lua:114-125`). |
| `journey.indexViews` | `char.journey.indexViews` | (no DS-17.5 equivalent) | implemented | per-character Journey | `JourneyIndex.lua:16-26` | Runtime rollback switch. |
| legacy aggregates | `char.areas`, `char.levels`, `char.areaLevels`, `char.instances` | `journey.zones`, `journey.levels`, `zones[].playerLevels`, `journey.instances` | partial | per-character Journey | `Tracking.lua:244`, `Tracking.lua:310`, `Tracking.lua:312-324`, `Data.lua:212-240` | Still authoritative for list/overview rows (`JourneyQueries.lua:83-141`). |

### 4.13 Adjacent per-character fields (outside the DS-17.5 Journey schema)

| Field | Production path | DS-17.5 name | Status | Owner layer | Evidence | Notes |
|---|---|---|---|---|---|---|
| `totals` | `char.totals {kills,xp,uniqueMobs}` | `totals` | implemented | per-character Journey | `Data.lua:126`, `Tracking.lua:346`, `Data.lua:794` | Kept from migration table (`DS-17-05:110`). |
| `unattributed` | `char.unattributed` | not in DS-17.5 | implemented | per-character Journey | `Data.lua:114`, `Data.lua:162-179` | Identity-less group/remote XP. |
| `rates` | `char.rates[]` | not in DS-17.5 | implemented | per-character Journey | `Data.lua:116`, `Data.lua:734`, `Data.lua:1032-1078` | Session XP-rate samples. |
| `dungeon` | `char.dungeon` | not in DS-17.5 | implemented | per-character Journey | `Data.lua:128-132`, `Tracking.lua:348-357` | Instance bucket. |
| `economy` / `goal` | `char.economy`, `char.goal` | not in DS-17.5 | implemented | per-character Journey | `Data.lua:133-144`, `Data.lua:294-311` | Unrelated to Journey analytics. |
| `calibration` | `char.calibration` | not in DS-17.5 | implemented | per-character Journey | `Data.lua:124`, `Calibration.lua:243-269` | Estimation support. |
| account profile | `AceM2L2DB.profile` | not in DS-17.5 | implemented | per-character Journey (settings) | `Module.lua:40-46` | Only account-DB field; not Knowledge. |

## 5. Findings

### 5.1 Duplicated or unowned fields

1. **Zone kill counters are triplicated.** `char.areas[map]` (`Tracking.lua:310`), `char.journey.zones[map].kills` (`Journey.lua:248`), and the sum of `char.levels` (`Tracking.lua:244`) all track kills. `GetJourneyZoneStats` deliberately reports Journey kills as a separate, non-additive subset (`JourneyQueries.lua:43-47`), so the duplication is acknowledged but unresolved.
2. **Player-level kill counters are duplicated.** `char.levels[level]` (`Tracking.lua:244`) vs `char.journey.levels[level].kills` (`Journey.lua:179-186`, `Journey.lua:248`) vs `mob.killsAtLevel` (`Tracking.lua:243`). Three owners, no reconciliation rule.
3. **Area×level counts are duplicated.** `char.areaLevels[map][level]` and `mob.killsByAreaLevel[map][level]` are both written per kill (`Tracking.lua:312-324`) and both decremented on prune (`Data.lua:1290-1334`).
4. **Level XP has two owners.** `char.levelHistory[].xpGained` (`Data.lua:1957-1968`) and `char.journey.levels[].xp` (`Journey.lua:161-168`). `startedAt`/`endedAt` exist only in the first.
5. **Mob kills/XP are stored twice.** Authoritative `char.mobs[].kills/totalXP` (`Tracking.lua:232`, `Tracking.lua:361`) and the additive block copy (`JourneyStorage.lua:114-125`, `JourneyStorage.lua:317-392`). `FlushJourneyBlocks` rebuilds blocks from live mobs, so storage is a derived copy, not the source of truth required by DS-11 §2.1.
6. **Heatmap totals/lastSeen are stored twice.** `char.heatmaps[map].total/lastSeen` (`Heatmap.lua:631-633`) and `journey.blockIndex["map:*"].heatmapKills/lastSeen` (`JourneyStorage.lua:380-381`).
7. **Mob→zone references are duplicated.** `mob.killsByMap`/`mob.killsByInstance` and `journey.mobZones[mobKey]` (`JourneyStorage.lua:328-335`) describe the same relation with different shapes.
8. **`char.mob.contexts` and `char.mob.xp` overlap.** Both accumulate the same observation sample (`Calibration.lua:193-221`); DS-17.5 has no `mob.xp` statistics object at all.
9. **No field owns "danger" or "XP context".** `combat` and `xpContexts` do not exist (`Calibration.lua:174-189`), so the single `contexts` map is doing two jobs with no owner for outcomes.
10. **Unowned runtime state inside the Journey.** `journey.time` (`Journey.lua:60-66`) and `journey.indexViews` (`JourneyIndex.lua:25`) are persisted in the char DB but are not in any DS-17.5 schema.
11. **`zones[].sessions`, `zones[].deaths`, `levels[].deaths` are unowned.** All are initialized (`Journey.lua:77`, `Journey.lua:90`, `Journey.lua:102`) but no writer exists, so readers get permanent zeroes (`JourneyQueries.lua:54-55`).
12. **Two zone-key namespaces.** `journey.zones` uses bare map IDs (`Journey.lua:19-25`), while blocks and `blockIndex` use `map:`/`instance:` prefixes (`JourneyStorage.lua:134`, `JourneyStorage.lua:184-205`). No instance-keyed Journey zone exists.

### 5.2 Names that imply the wrong level

1. **`killsAtLevel` means player level** (`Tracking.lua:241-245`). DS-17.5 renamed it to `byPlayerLevel` precisely for this (`DS-17-05:50-55`); production still uses the ambiguous name.
2. **`killsByAreaLevel` / `killsByInstanceLevel` / `areaLevels` / `levels` all key on player level** (`Tracking.lua:243`, `Tracking.lua:290-299`, `Tracking.lua:311-324`) but none says "player". A future reader can mistake them for mob-level data.
3. **`journey.levels` and `journey.zones[].levels` are player-level keys** (`Journey.lua:96-107`, `Journey.lua:85-94`), while `mobs[key].contexts[].mobLevel` is the only explicitly named mob level (`Calibration.lua:176`).
4. **`mob.xp` is an XP-statistics table, not total XP.** DS-17.5 assigns `mob.xp` to numeric total XP (`DS-17-05:99`), and the block codec already reads/writes `xp` as a scalar (`JourneyStorage.lua:121`, `JourneyStorage.lua:285`). Any code that copies `mob.xp` into a block record would serialize a table as a number. `GetJourneyMobSummary` therefore reads scalar XP from blocks but `totalXP` from live mobs (`JourneyQueries.lua:336`, `JourneyQueries.lua:350`).
5. **`GetMobLevelRange` mixes an observed unit level with stored mob-level fields** (`Data.lua:46-72`). Because `mobLevelMin/Max` are never persisted to `char.mobs`, only context-derived levels are visible, and `GetMobRelevance` falls back to `"active"` whenever the range is unknown (`Data.lua:77-79`).
6. **`sessionKills`/`sessionXP` do not follow `StartSession`.** `StartSession` resets `char.session` and `char.dungeon` (`Events.lua:184-204`) but not `mob.sessionKills`/`mob.sessionXP`, so "session" on a mob means lifetime.

### 5.3 Fields in the design but absent in production

- `journey.mobs` as an aggregate (only 8-field block records exist: key, npcID, name, classification, kills, xp, mobLevelMin, mobLevelMax — `JourneyStorage.lua:114-125`, `JourneyStorage.lua:288-293`).
- `mobs[].byPlayerLevel`, `mobs[].byZone`, `mobs[].byInstance`, `mobs[].playerLevels`.
- `mobs[].mobLevelSamples`; a persisted mob level range in `char.mobs`.
- `mobs[].combat`, `mobs[].xpContexts`, array-shaped `contexts`, top-8+`other` cold contexts.
- `mobs[].presenceSeconds` / `engagedSeconds` / `respawn`.
- `journey.zones[map].playerLevels` (shape differs: `zones[].levels[]` full records), `uniqueMobs`, working `sessions`/`deaths`.
- `journey.instances` entirely (including per-instance time, deaths, unique mobs).
- `journey.levels[].startedAt` / `endedAt`.
- `journey.sessions` and session history.
- `journey.deaths` with attribution/health/buffs/group/classification/difficulty; the current normalizer would strip them even if written (`World.lua:155-187`).
- `journey.quests` (records still live in `char.quests`) and `journey.respawns`.
- `journey.heatmaps` and persisted top-N summaries; cell XP/time.
- `knowledge.*` (all account Knowledge fields), `interface`, `levelCap`, class/race/faction, playtime.

### 5.4 Fields in production but absent from DS-17.5

- `journey.questAnchors[]` (capped 5000) and per-zone/per-level `quests` counters.
- `journey.time {zone,level,lastEventAt,lastKillAt,cap}`.
- `journey.indexViews`, `journey.storageSchema`, `storageMode`, `blockReadFallback`, `saveBlocked`, `oversizeSeen`, `oversizeAt`, `storageUpdatedAt`, and the `blocks/blockIndex/blockBackup/dirtyZones/mobZones` containers.
- `mob.xp` observation statistics table (`samples/sumBase/sumBuffed/sumTotal/minBase/maxBase/lastBase/lastTotal`).
- `mob.sessionKills/sessionXP/sessionXPKnown` are listed, but `char.levels`, `char.areas`, `char.areaLevels` remain live production aggregates not represented as such.
- `char.dataSchema`, `char.calibrationVersion`, `char.calibration`, `char.unattributed`, `char.rates`, `char.dungeon`, `char.economy`, `char.goal`, `char.levelHistory`.
- Instance-record extras: `sessionKills`, `sessionXP`, `legacy`, `name`, `instanceType`, `difficultyID` (`Data.lua:225-239`).

### 5.5 Account-owned vs per-character-owned

- Everything audited here is **per-character** storage: `AceM2L2CharDB.xpTooltip.clients[projectID]` (`Data.lua:612-673`, `Data.lua:697-701`), including `journey.*`, `mobs`, `deaths`, `quests`, `respawns`, `heatmaps`, `levelHistory`, and schema/meta.
- The only account-scoped store is `AceM2L2DB.profile` (settings) (`Module.lua:40-46`).
- `npcID`-keyed static metadata (name, classification, level range) is the only category DS-11 §2.4 allows to become account-wide, but it is currently written per character. There is no account Knowledge writer anywhere (`Module.lua:40-46`).
- Name-only records (`name:<lower>`) must stay per character per DS-11 §2.4; production already keys them that way (`Tracking.lua:207-227`).

## 6. Gaps

Assigned for DS-17.6A5 consolidation; no implementation is proposed or performed here.

1. The v2 renames (`byPlayerLevel`, `byZone`, `byInstance`, `playerLevels`) are not applied; production still uses v1 names (`Tracking.lua:241-325`, `Data.lua:1744-1748`).
2. `mob.xp` name collision between the observation table (`Calibration.lua:205-221`) and DS-17.5's scalar XP (`DS-17-05:99`).
3. No persisted mob level range/samples; `mobLevelMin/Max` are read-only and block-only (`Data.lua:46-72`, `JourneyStorage.lua:292`).
4. `combat` and `xpContexts` are absent; `contexts` is a keyed map, not an array (`Calibration.lua:168-203`).
5. `journey.instances` does not exist, so instance time/deaths/unique mobs and instance-keyed Journey data are missing (`Journey.lua:19-25`).
6. `otherXP` has no writer (`Journey.lua:75`, `Journey.lua:155-169`).
7. Zone/level `deaths` and `sessions` counters have no writer (`Journey.lua:77`, `Journey.lua:90`, `Journey.lua:102`).
8. Death records cannot carry attribution/health/buffs/group/difficulty, and the normalizer discards them (`World.lua:155-187`).
9. Heatmap cells are scalar counts; xp/presence/engaged columns are encoded but always zero (`Heatmap.lua:628-631`, `JourneyStorage.lua:163-168`).
10. Top-N cells are recomputed per query, not retained as a summary (`JourneyQueries.lua:279-321`).
11. Quest records and quest XP live in the legacy table, not `journey.quests` (`Data.lua:1754-1793`).
12. Respawns live at char level keyed by `npcID`, with no `journey.respawns` and no stored aggregates (`World.lua:304-368`, `World.lua:493-529`).
13. Sessions are a single live bucket; no `journey.sessions` history (`Events.lua:184-191`).
14. `journey.levels` lacks `startedAt`/`endedAt`; they exist only in `char.levelHistory` (`Data.lua:1839-1974`).
15. `journey.schema = 1` is independent of, and inconsistent with, `storageSchema = 2`, and is never validated on load (`Journey.lua:11`, `Data.lua:28`, `Data.lua:622-625`).
16. Block mob records carry only 8 fields, so schema-2 blocks cannot answer level/zone/instance/context/time questions (`JourneyStorage.lua:114-125`).
17. Zone-key namespaces differ between `journey.zones` and blocks/`blockIndex` (`Journey.lua:19-25` vs `JourneyStorage.lua:134`).
18. `journey.mobZones` has no ≤4-ref enforcement, while per-mob instance refs are capped at 20 (`JourneyStorage.lua:328-335`, `Data.lua:1700-1733`).
19. No per-zone `uniqueMobs`; only the global total (`Data.lua:794`).
20. Account Knowledge, `interface`, `levelCap`, class/race/faction, and playtime are entirely absent (DS-11 §2.8 defers Knowledge).

V-2-only capture items (DS-11 §6), all absent from production fields today:

- death killer attribution, health before/after, time-to-kill;
- buff-signature and group-size reliability;
- heatmap cell XP/time;
- mob level at sighting;
- quest turn-in timestamp/reward reliability;
- durable per-zone/level presence/engaged time.

## 7. Open questions

1. Should `journey.schema` be aligned with the storage/data schema 2, or retired in favor of `storageSchema`? It is currently a third schema number (`Journey.lua:11`, `Data.lua:28-29`).
2. When blocks become authoritative, does `char.mobs` remain a hot cache, or is it removed? Today blocks are rebuilt from `char.mobs` on every flush (`JourneyStorage.lua:324-350`).
3. Should `mob.xp` (statistics) be renamed (e.g. `xpStats`) so DS-17.5's scalar `mob.xp` name is free? No rename exists in code or docs.
4. Is `mob.sessionKills/sessionXP` intended to be per-login? `StartSession` resets only `char.session`/`char.dungeon` (`Events.lua:184-204`).
5. Is `journey.time` meant to persist, or is it runtime-only that should be excluded from the schema? `lastEventAt`/`lastKillAt` are zeroed at logout (`Journey.lua:348-349`) but `zone`/`level` persist.
6. Is `presenceSeconds` intentionally AFK-inclusive? It is uncapped between events, unlike `engagedSeconds` (`Journey.lua:109-134`).
7. Should instance kills be tracked in `journey.zones[<instanceMapID>]` or moved to `journey.instances`? Today they land in the map-keyed zone bucket (`Journey.lua:19-25`).
8. Which key namespace is canonical: `"12"` or `"map:12"`? Both are live (`Journey.lua:24`, `JourneyStorage.lua:134`).
9. Does the DS-17.5 "≤4 zone refs" cap apply to instance refs too? Production caps instance refs at 20 and leaves zone refs uncapped (`Data.lua:1700-1733`, `JourneyStorage.lua:328-335`).
10. Should `journey.questAnchors` be folded into `journey.quests`, or remain a separate capped list? DS-17.5 does not describe it.
11. Should death normalization preserve unknown/forward fields instead of rebuilding `{at,mapID,x,y}` (`World.lua:160-175`)? Current behavior would erase V-2 attribution fields.
12. Which layer should own the derived legacy aggregates (`char.areas`, `char.levels`, `char.areaLevels`, `char.instances`) once the Journey is authoritative — keep as UI/derived caches or migrate into `journey.zones/levels/instances`?

## 8. Limitations

- Read-only static inspection only. No addon was loaded, no SavedVariables file was parsed, and no test was executed. All statements are code-path statements, not runtime observations.
- "Every field" here means every field reachable from `journey.*` plus the char-level stores DS-17.5 names as migration targets. UI widget state, module runtime counters, and settings under `AceM2L2DB.profile` were not inventoried.
- Status reflects presence of a writer/reader in code, not live correctness on Forever/Midnight. Items in DS-11 §6 are marked `V-2-only` rather than `implemented`.
- Write-path ordering, double-count prevention, and event timing were not audited (A2 owns this); codec/cache/save mechanics were not audited (A3); UI/command truth was not audited (A4).
- Large data files (`MapOverlayData.lua`, most of `Commands.lua`, `UI/*`) were read only where they referenced a Journey field.
- Line numbers refer to the working tree at the time of this audit and may drift.

## 9. Statement

No code changed; no tests run. No production Lua, tests, `PLAN.md`, `NEXT-TASK.md`, or other audit report was edited. Only this file was created. Nothing was committed or pushed.
