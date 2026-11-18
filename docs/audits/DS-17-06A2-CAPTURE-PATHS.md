# DS-17.6A2 — Capture-path audit

**Status:** complete (read-only)

**Slice:** DS-17.6A2, event/write-path tracing

**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`

**Task:** `docs/tasks/DS-17-06A2-CAPTURE-PATHS.md`

## Scope

Where and when every Journey-relevant field is written: event trigger, write
function, concrete write target, clock, and whether the path is covered offline.
Field *names* follow DS-17.5 / `docs/DATA-MODEL-AND-TEST-MATRIX.md`; field
*ownership* verdicts are deliberately not assigned here (A1). Physical
storage/save is A3; query/UI consumers are A4.

Out of scope: schema verdicts, storage codec correctness, UI truth, any code or
test change.

## Files read

Production Lua:

- `KillHistory/Tracking.lua`
- `KillHistory/Events.lua`
- `KillHistory/Journey.lua`
- `KillHistory/World.lua`
- `KillHistory/Util.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/Commands.lua` (reset path only; journey writes at 897-898)
- support files needed to follow write targets:
  `KillHistory/Data.lua`, `KillHistory/Calibration.lua`,
  `KillHistory/Formula.lua`, `KillHistory/JourneyStorage.lua`,
  `KillHistory/JourneyQueries.lua`, `KillHistory/Module.lua`,
  `Core/XP.lua`, `Core/Events.lua`

Tests inspected (read only, not executed):

- `tests/journey.lua`
- `tests/cap1_capture_fields.lua`
- `tests/quest_anchors.lua`
- `tests/heatmap_commit_position.lua`
- `tests/history_view.lua`
- `tests/imp1_integration.lua`

Documents:

- `docs/tasks/DS-17-06A2-CAPTURE-PATHS.md`
- `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`
- `docs/tasks/DS-17-05-SCHEMA-AND-MIGRATION.md`
- `docs/DATA-MODEL-AND-TEST-MATRIX.md` (model shape, contexts, heatmap, deaths)

## Method

1. Enumerate event entry points from `Module.lua:461-479` and
   `Core/Events.lua:103-109`, then follow each handler to its write.
2. Follow the two commit funnels: `XPTooltip:RecordKill`
   (`Tracking.lua:180-400`) and `XPTooltip:RecordQuestXP`
   (`Data.lua:1754-1818`).
3. For each model field, record the writer, the concrete table key written, the
   clock used, and whether an offline test asserts it.
4. Cross-check the five required checks (no timer, no per-kill log, no per-kill
   save, quest isolation, G-1B heatmap position).
5. Status vocabulary is exactly `implemented` / `partial` / `missing` /
   `V-2-only`. Nothing is assumed: a field with no writer is `missing`, even if
   a design or prototype exists.

Status legend: `V-2-only` is used only where code exists but the capture
capability is unverified without a live client. `partial` means a writer exists
but the stored shape differs from the DS-17.5 model (missing subfields, or one
merged record covering two model concepts).

## Required table

| Field | Status | Event/trigger | Function | Write target | Time source | Offline test |
|---|---|---|---|---|---|---|
| `journey.schema`, `journey.projectID` | implemented | any Journey hook | `XPTooltip:EnsureJourney` (`Journey.lua:35-69`) | `db.journey.schema` (`:41`), `.projectID` (`:42`) | none | `tests/journey.lua:18` |
| `journey.mode` / `journey.levelCap` | partial / missing | Journey init only | `EnsureJourney` (`Journey.lua:43`) | `journey.mode` defaults to `"leveling"`, never rewritten; no `levelCap` writer | none | none |
| Mob level at sighting (raw observation) | implemented | `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `NAME_PLATE_UNIT_ADDED` (`Module.lua:465-466`, `:510`) | `XPTooltip:CaptureUnit` → `SafeCall(UnitLevel, unit)` (`Util.lua:913`) | transient `info.level` in `lastTarget`/`lastMouseover`/death entry | `Util.Now` at capture (`Util.lua:943`) | none (position only: `tests/heatmap_commit_position.lua:120-163`) |
| Mob level persisted per mob (`mobLevelMin`/`mobLevelMax`) | partial | kill commit, only when an XP observation is trained | `RecordObservation` (`Calibration.lua:147-221`) → `mob.contexts[key].mobLevel` (`:176`); serialized by `mobLevelRange` (`JourneyStorage.lua:102-112`, `114-125`) | `mob.contexts[]`, then block `mobLevelMin/Max` | `Epoch` (`Calibration.lua:197`) | none |
| Player level | implemented | `PLAYER_LEVEL_UP` (`Module.lua:468`), kill/quest commit | `GetPlayerLevel` (`Util.lua:367`); `playerLevelFor` (`Journey.lua:27-33`) | `mob.killsAtLevel`, `db.levels` (`Tracking.lua:241-245`), `journey.levels`, `zone.levels` (`Journey.lua:96-107`, `155-169`, `179-186`) | `Epoch` deltas | `tests/journey.lua:56-60` |
| Player level vs mob level separated | implemented | kill commit | `ContextKey` (`Formula.lua:26-38`) | `mob.contexts` key `p<player>-m<mob>` + fields `playerLevel`/`mobLevel` | `Epoch` | none; fallback risk below |
| Kills (mob / session / total / area / instance) | implemented | XP chat, `UNIT_DIED` | `RecordKill` (`Tracking.lua:232-233`, `268-269`, `308-310`, `346-347`, `349-350`) | `mob.kills`, `mob.sessionKills`, `db.totals.kills`, `db.session.kills`, `mob.killsByMap`, `db.areas`, `mob.killsByInstance`, `instance.kills`, `dungeon.kills` | `Epoch` for `lastSeen` only | none |
| Kill XP | implemented | `CHAT_MSG_COMBAT_XP_GAIN` (`Module.lua:462`), late `add_xp`, `UNIT_DIED` counts-only | `RecordKill` (`Tracking.lua:360-379`), `AddKillXP` (`:402-462`), `RecordUnattributedXP` (`Data.lua:844-882`) | `mob.totalXP/sessionXP`, `db.totals.xp`, `db.session.xp`, `dungeon.xp`, `instance.xp`, `journey.zones[].killXP`, `journey.levels[].killXP` (`Journey.lua:249`, `267`) | `Epoch` (`Tracking.lua:230`, `:422`) | `tests/journey.lua:26,32,48` |
| Quest XP | implemented | `QUEST_TURNED_IN` (`Core/Events.lua:106`) + `PLAYER_XP_UPDATE` | `AceM2L2:RecordQuestGain` (`Core/XP.lua:358-383`) → `RecordQuestXP` (`Data.lua:1754-1818`) → `OnJourneyQuestTurnIn` (`Journey.lua:270-320`) | `db.quests[].totalXP`, `journey.zones[].questXP`, `journey.levels[].questXP`, `zone.levels[].questXP` | `Epoch` (`Journey.lua:278`) | `tests/journey.lua:38,60`; `tests/quest_anchors.lua:16-60` |
| Other XP | missing | — | `addXP` only called with `"killXP"`/`"questXP"` (`Journey.lua:249,267,293`; `addXP` `:155-169`) | `otherXP` is zero-initialized only (`Journey.lua:75,89,101`) | n/a | none |
| Presence seconds | implemented | world enter, zone change, level up, kill, quest turn-in, logout | `closePresence`/`addPresence` (`Journey.lua:109-120`, `136-142`); hooks `:188-353`; dispatch `Events.lua:120-168`, `:140-142` | `journey.zones[].presenceSeconds`, `journey.levels[].presenceSeconds`, `zone.levels[].presenceSeconds` | `Epoch` deltas between events | `tests/journey.lua:24,30,36,46,52` |
| Engaged seconds | implemented | consecutive kills in same zone+level; logout finalizer; 60 s gap cap | `addEngaged` (`Journey.lua:122-134`, cap at `:127`); `OnJourneyKill` (`:241-246`); `OnJourneyLogout` (`:344-347`) | `zone.engagedSeconds`, `level.engagedSeconds`, `zoneLevel.engagedSeconds` | `Epoch` deltas | `tests/journey.lua:25,31,37,47,53`; prototype `tests/imp1_integration.lua:160-187` |
| Combat context (per mob) | partial | kill commit with usable `rawBase` | `RecordObservation` (`Calibration.lua:147-221`) | `mob.contexts[key]`: `playerLevel`, `mobLevel`, `groupSize`, `mapID`, `instanceKey`, `classification`, `buffSig`, `samples`, `sumBase/sumBuffed/sumTotal`, `minBase/maxBase`, `lastSeen` | `Epoch` (`:197`) | none |
| Combat-context subfields `healthBand`, `instanceDifficulty`, `kills/deaths`, `healthLost*`, `timeToKill*` | missing | — | not written; key has no health/difficulty term (`Formula.lua:26-38`) | `mob.contexts` has no such fields | n/a | CAP-1 prototype only (`tests/cap1_capture_fields.lua:43-53,164-195`) — not production |
| XP context (per mob) | partial | same as combat context | `RecordObservation` (`Calibration.lua:168-221`) | same single `mob.contexts` map; one merged context serves both combat and XP | `Epoch` | none |
| XP-context `rested` flag / separate `xpContexts` map | missing | — | rested state is not in the key or record; only `buffSig` distinguishes buffs (`Util.lua:990-1013`) | n/a | n/a | none |
| Death record (time + position) | implemented | `PLAYER_DEAD` (`Module.lua:478`) | `OnPlayerDied` (`Events.lua:66-74`) → `HandlePlayerDeath` (`World.lua:240-249`) → `RecordDeath` (`:202-238`) | `db.deaths[]` = `{at, mapID, x, y}` (`:230-235`) | `Epoch` (`:216`, `:248`) | `tests/history_view.lua:100-106`; `tests/heatmap_commit_position.lua:165-171` |
| Death mob attribution (`mobKey`, `npcID`, `name`, `mobLevel`) | missing | — | `RecordDeath` writes coordinates only (`World.lua:230-236`); no `journey.deaths` root is written anywhere | n/a | n/a | CAP-1 prototype only (`tests/cap1_capture_fields.lua:164-195`) |
| Death player health / `healthBand` | missing | — | no `UnitHealth`/`UnitHealthMax` read anywhere in `KillHistory/` | n/a | n/a | CAP-1 prototype only (`tests/cap1_capture_fields.lua:4-16,273-296`) |
| Death buffs / group / classification / difficulty | partial | kill-time only, never death-time | `GetBuffSignature` (`Util.lua:990-1013`), `GetGroupSize` (`Util.lua:793-799`), `classification` (`Util.lua:914`), instance `difficultyID` (`Util.lua:519`; `Tracking.lua:255,283-284,355`) | `mob.contexts`, `db.instances[key].difficultyID`, `dungeon.lastDifficultyID` — none on `db.deaths` | `Epoch` at kill, not death | none |
| Instance attribution and non-attributable instance behavior | implemented | kill commit | `AttachInstanceState` (`Tracking.lua:107-131`); mapID zeroing (`:198-201`, `Util.lua:480-498`, `736-757`); instance bucket `:246-305`; heatmap skip via `ResolveHeatmapPosition` (`:144-147`) | `db.instances[key]`, `mob.killsByInstance(Level)`, `dungeon.lastInstance*`; no heatmap and no `db.areas` for non-attributable maps | `Epoch` (`:230`) | `tests/heatmap_commit_position.lua:124-163` |
| Journey zone/instance XP+time dimension | partial | kill/quest commit | `zoneKeyFor` (`Journey.lua:19-25`) is map-keyed only | non-attributable instance kills land in `journey.zones["0"]`; there is no `journey.instances` | `Epoch` | none |
| Heatmap cells (kill counts, 64×64) | implemented | kill commit funnel | `RecordKill` → `RecordHeatmapKill` (`Tracking.lua:332-344`; `Heatmap.lua:592-654`) | `db.heatmaps[mapID].cells[cell]` scalar count, `entry.total`, `entry.lastSeen` | `Epoch` (`Heatmap.lua:633`) | `tests/heatmap_commit_position.lua:120-163` |
| Heatmap kill position at commit (G-1B) | implemented | same | `ResolveHeatmapPosition` (`Tracking.lua:144-178`): sighting snapshot, refreshed only on same map, dropped on stale cross-map/instance | coordinates passed to `RecordHeatmapKill` | `Epoch` | `tests/heatmap_commit_position.lua:120-163` |
| Heatmap cell XP / presence / engaged seconds | missing | — | `RecordHeatmapKill` writes a scalar count only (`Heatmap.lua:628-631`); encoder fills `xp`/`presenceSeconds`/`engagedSeconds` from absent table fields (`JourneyStorage.lua:159-168`, `200-202`) | serialized as 0 | n/a | CAP-1 prototype only (`tests/cap1_capture_fields.lua:151-162,264-271`) |
| Heatmap cell `lastSeen` | missing (zone-level only) | — | only `entry.lastSeen` per zone is written (`Heatmap.lua:633`) | `db.heatmaps[mapID].lastSeen` | `Epoch` | none |
| Quest turn-in anchor | implemented | `QUEST_TURNED_IN` → quest XP delta | `OnJourneyQuestTurnIn` (`Journey.lua:270-320`) | `journey.questAnchors[]` = `questID, mapID, at, playerLevel, xp, x, y` (`:295-306`); cap 5000 (`:12`, `:171-177`) | `Epoch` + turn-in position (`:281-287`) | `tests/quest_anchors.lua:16-60`; `tests/heatmap_commit_position.lua:174-181` |
| Quest ledger | implemented | quest XP | `RecordQuestXP` (`Data.lua:1754-1818`); per-turn-in stamp written by `OnJourneyQuestTurnIn` (`Journey.lua:313-319`) | `db.quests[key]` = `id, name, count, totalXP, lastXP, firstSeen, lastSeen, lastTurnInAt, mapID, playerLevel` | `Epoch` | `tests/journey.lua:39-42` |
| Respawn intervals | implemented (legacy root, not Journey) | sighting capture + later same-NPC different-GUID sighting | `RecordRespawnDeath` (`World.lua:384-399`), `ObserveRespawn` (`:401-441`), `RecordRespawnInterval` (`:443-491`); called from `CaptureUnit` (`Util.lua:945-949`) and `RecordKill` (`Tracking.lua:235-240`) | `db.respawns[npcID] = {name, intervals[≤20], lastSeen, lastDeath}` | `Now`/GetTime for watch age (`World.lua:396,429`), `Epoch` for stored times (`:486-488`) | `tests/history_view.lua:100-106` |
| Per-mob `respawn` aggregate in Journey | missing | — | no `mob.respawn` writer; stats are derived on read (`World.lua:493-529`) | n/a | n/a | none |
| Sessions | missing | — | `journey.zones[].sessions` is initialized only (`Journey.lua:77`); no `journey.sessions` root; `addEvent` is called only with `"kills"`/`"quests"` (`:248,294`) | rolling `db.session.{startedAt,kills,xp}` on login (`Events.lua:184-224`) | `Epoch` (`:189`) | none |
| Level history | implemented | `PLAYER_LEVEL_UP`, login, each kill/XP | `EnsureLevelHistory` (`Data.lua:1900-1925`), `FinalizeLevelHistory` (`:1937-1955`), `AddLevelHistoryXP/Kill` (`:1957-1974`); hooks `Events.lua:129-138`, `Data.lua:359` | `db.levelHistory[]` = `level, startedAt, endedAt, xpGained, kills, duration` | `Epoch` (`Data.lua:1891,1916,1931,1946`) | none |

## Findings

### F1. Event-driven time only; no timer/OnUpdate accounting

- Presence and engaged time are computed only as `Epoch()` deltas at event
  boundaries: `closePresence`/`switchContext` (`Journey.lua:136-153`),
  `OnJourneyKill` (`:230-256`), `OnJourneyLogout` (`:335-353`).
- No `OnUpdate`/ticker accumulates time. The only `OnUpdate` in the addon is the
  UI click poller in `KillHistory/UI/Window.lua:440`; `LibDBIcon` is a vendored
  library.
- `C_Timer.After` is used only for deferred one-shot actions, never for elapsed
  time: pending chat commit (`Tracking.lua:491-500`), pending death commit
  (`:1063-1072`), prune scheduling (`Events.lua:237-252`), instance-state
  refresh (`Util.lua:666`), delayed XP print (`Core/XP.lua:310-317`).
- Caveat: `Epoch()` falls back to `GetTime()` when `time()` is unreadable
  (`Util.lua:129-131`), which would mix a wall clock with a session clock.

### F2. No per-kill timestamp log (with three bounded exceptions)

- No per-kill record list is persisted. `pendingDeaths`, `pendingChatXP`,
  `recentChatKills` are in-memory module fields with short windows
  (`Tracking.lua:464-530`, `926-1073`, `591-615`), never written to `db`.
- Three bounded per-kill timestamps *are* persisted, which the check should
  acknowledge rather than treat as absent:
  `mob.lastSeen` (`Tracking.lua:234`), heatmap zone `lastSeen`
  (`Heatmap.lua:633`), and one `db.rates` sample per kill, capped at 240
  (`Data.lua:32`, `815-838`, `353-380`). These are bounded fields/samples, not a
  per-kill log, but they are per-kill timestamped writes.

### F3. No per-kill save

- No `SaveVariables`/forced-save call exists in the addon; persistence is the
  client's SavedVariables write.
- Journey blocks are flushed only from `OnJourneyLogout`
  (`Journey.lua:350-352` → `JourneyStorage.lua:317`).
- A kill only marks dirty zones (`Journey.lua:250-251` →
  `JourneyStorage.lua:229-238`), and `SchedulePrune` is a 5 s debounced
  in-memory normalization (`Events.lua:237-252`), not a save.

### F4. Quest turn-in does not enter mob combat/XP context

- `RecordQuestXP` has no `EnsureMob`/`RecordKill` call; it writes the quest
  ledger and calls `OnJourneyQuestTurnIn` (`Data.lua:1754-1818`).
- `OnJourneyQuestTurnIn` writes only journey XP/anchor fields and the quest
  record (`Journey.lua:270-320`); no `mob.contexts` write.
- The XP-chat path rejects quest text before identity matching: `key:find("_QUEST")`
  or ambiguous-plus-quest-window returns at `Tracking.lua:720-723`.
- The XP-delta path classifies quest deltas separately and routes them through
  `RecordQuestGain` (`Core/XP.lua:403-451`, `358-383`).
- Caveats (not violations of the stated rule): the turn-in resets
  `journey.time.lastKillAt` so quest time is not counted as engaged
  (`Journey.lua:291`; asserted `tests/journey.lua:36-37`), and
  `RecordDungeonXP` adds quest XP to the kill-oriented `dungeon.xp`
  (`Core/XP.lua:379-381`, `Data.lua:886-905`).

### F5. Heatmap kill position is captured at commit (G-1B)

- `RecordKill` is the sole heatmap accounting point; the position is resolved at
  commit inside `RecordKill` (`Tracking.lua:328-344`).
- `ResolveHeatmapPosition` uses the acquisition snapshot, refreshes only when
  the fresh position is on the same map, and returns `nil` for a stale
  cross-map snapshot or an unattributable instance map
  (`Tracking.lua:144-178`).
- Verified offline for world, group, stale-snapshot, non-attributable and
  attributable-instance cases (`tests/heatmap_commit_position.lua:120-163`).
- Death coordinates (`World.lua:244-248`) and quest anchors
  (`Journey.lua:281-287`) are independent snapshots at their own events.

### F6. Production Journey is an additive overlay, not the DS-17.5 root shape

- `journey` currently holds only `schema`, `projectID`, `mode`, `zones`,
  `levels`, `time`, `questAnchors` plus storage metadata
  (`Journey.lua:35-69`, `JourneyStorage.lua:207-227`).
- The model roots `journey.mobs`, `journey.instances`, `journey.sessions`,
  `journey.deaths`, `journey.quests`, `journey.heatmaps`
  (`docs/DATA-MODEL-AND-TEST-MATRIX.md:53-179`) have no writer; grades,
  instances, deaths, quests and heatmaps are still written to the legacy
  character roots (`db.mobs`, `db.instances`, `db.deaths`, `db.quests`,
  `db.heatmaps`).
- Journey zone/level time+XP is per-map only. Because
  `zoneKeyFor` uses `mapID` (`Journey.lua:19-25`) and non-attributable instance
  maps are forced to 0 (`Tracking.lua:198-201`), those kills and their XP land
  in `journey.zones["0"]` with no instance dimension, while the instance bucket
  and heatmap correctly stay separate.

### F7. Mob level is observed at sighting but persisted only through observations

- The sighting snapshot carries `UnitLevel` (`Util.lua:913`), and the kill
  commit preserves `info.level` (`Tracking.lua:816`).
- Persistent `mobLevelMin/Max` come from `mob.contexts[].mobLevel`
  (`JourneyStorage.lua:102-112`), and contexts are only written by
  `RecordObservation`, which is skipped for counts-only clients, missing
  `rawBase`, group kills, non-`none` buff signatures, and unreadable rested
  state (`Tracking.lua:184,360,381-383`, `447-449`;
  `Calibration.lua:151-160`, `226-229`).
- Consequence: on counts-only clients, and for most buffed/group/rested kills,
  the persisted mob level range stays 0 even though the level was observed.
- Where the level is unknown, production substitutes the player level
  (`Tracking.lua:549-550`, `792-795`, `1101`), so player and mob level are
  stored separately but not always independently sourced.

### F8. Death capture is position-only

- `RecordDeath` stores exactly `at, mapID, x, y` (`World.lua:230-236`).
- No killer attribution, NPC id, mob level, player health, health band, buff
  signature, group size, classification, difficulty or combat-context key is
  written at death.
- `db.deaths` is normalized to those four fields (`World.lua:155-200`), so even
  a future extra field would be dropped on load.
- CAP-1 (`tests/cap1_capture_fields.lua`) is a pure prototype of the intended
  shape; it is not wired into production and itself labels death attribution
  `"needs verification"` (`:202-204`).

### F9. Heatmap cells carry counts only

- `RecordHeatmapKill` writes `cells[cell] = count + 1`, `entry.total`, and a
  zone-level `lastSeen` (`Heatmap.lua:628-633`).
- The schema-2 codec already reserves per-cell `xp`, `presenceSeconds`,
  `engagedSeconds` (`JourneyStorage.lua:184-205`, `295-313`) but the writer never
  supplies them, so they encode and decode as 0 (`JourneyStorage.lua:159-168`).
- Per-cell `lastSeen` does not exist at all.

## Gaps

1. `journey.mobs` / `journey.instances` / `journey.sessions` / `journey.deaths`
   / `journey.quests` / `journey.heatmaps` model roots are unwritten; the legacy
   roots remain the capture target (F6).
2. `otherXP` has no writer; only zero-initialized (table row 9).
3. `journey.zones[].deaths` and `.sessions` have no writer; no `journey.sessions`
   root; `journey.mode` never changes and `levelCap` is never written.
4. Instance kills/XP/time have no Journey instance dimension; non-attributable
   instances collapse into `journey.zones["0"]` (F6).
5. Death records have no mob attribution and no health capture (F8).
6. Death-time buffs/group/classification/difficulty are not stored per death,
   only per kill context/instance (table row 17).
7. Heatmap cell XP / presence / engaged / per-cell `lastSeen` are not captured
   (F9).
8. Persisted mob level range depends on observation eligibility, so it can stay
   empty on counts-only and buffed/group/rested kills (F7).
9. Respawns live in `db.respawns`, not a per-mob Journey field, and use two
   clocks (watch age on `GetTime`, stored times on `Epoch`).
10. Per-kill bounded timestamps exist (`mob.lastSeen`, heatmap zone `lastSeen`,
    `db.rates` ≤240) and need an explicit accept/reject decision (F2).
11. Quest XP is added to the kill-oriented `dungeon.xp` bucket via
    `RecordDungeonXP` (`Core/XP.lua:379-381`).

## Open questions

1. Should quest turn-in keep resetting `journey.time.lastKillAt` (thus closing
   the engaged window) and keep contributing to `dungeon.xp`? Both are
   deliberate today but change what "engaged" and "dungeon XP" mean.
2. Is `journey.zones["0"]` the accepted home for non-attributable instance
   kills/time, or must the Journey zone key include `instanceKey`?
3. Is mob level meant to be persisted from the sighting snapshot (independent of
   XP observation) rather than derived from trained contexts?
4. Does A1 intend to move `db.deaths`/`db.respawns` into `journey.deaths` /
   per-mob `respawn`, or keep them as legacy roots behind a Journey view?
5. Are the bounded per-kill timestamps in F2 acceptable under the "no per-kill
   timestamp log" rule, or must `db.rates` become event-window aggregates?
6. V-2: is `UnitHealth`/`UnitHealthMax` readable at `PLAYER_DEAD` on Forever and
   Midnight, and is a death context key reproducible then? CAP-1 marks this
   `needs verification`.
7. Should `journey.mode`/`levelCap` have writers before any endgame-mode
   validation, or stay deferred?
8. Is the `Epoch() → GetTime()` fallback (`Util.lua:129-131`) acceptable for
   stored Journey timestamps, given it breaks cross-session deltas?

## Limitations

- Read-only static inspection; no live client, no saved-variable capture.
- No tests were executed; test columns cite what the test file asserts by
  inspection, not a passing run.
- Storage encoding/decoding fidelity, save guards, migration and caps are A3;
  ownership verdicts are A1; query/UI truth is A4.
- `docs/audits/` did not exist; only this report file was created. No other
  slice report was read or depended on.
- Line numbers refer to the working tree at audit time.

No code changed; no tests run. No commit, no push.
