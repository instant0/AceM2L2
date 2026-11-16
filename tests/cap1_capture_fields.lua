-- CAP-1 Journey capture-field prototype.
-- Pure capture/fallback helpers; no production code, no network.

local function healthBand(current, maximum)
  local hp = tonumber(current)
  local maxHP = tonumber(maximum)
  if not hp or not maxHP or maxHP <= 0 then
    return "unknown", nil, false
  end
  local pct = math.max(0, math.min(100, hp / maxHP * 100))
  if pct <= 20 then return "0-20", pct, true end
  if pct <= 40 then return "21-40", pct, true end
  if pct <= 60 then return "41-60", pct, true end
  if pct <= 80 then return "61-80", pct, true end
  return "81-100", pct, true
end

local function groupInfo(capability, size)
  local n = tonumber(size)
  if capability and n and n > 0 then
    return n, true
  end
  return 1, false
end

local function buffInfo(capability, signature)
  if not capability then
    return "unknown", false
  end
  local value = tostring(signature or "none")
  if value == "" then value = "none" end
  return value, true
end

local function mobLevelInfo(capability, rawLevel)
  local level = tonumber(rawLevel)
  if capability and level and level > 0 then
    return level, true
  end
  return nil, false
end

local function combatContextKey(info)
  return table.concat({
    tostring(info.playerLevel or 0),
    tostring(info.mobLevel or 0),
    tostring(info.healthBand or "unknown"),
    tostring(info.buffSignature or "unknown"),
    tostring(info.groupSize or 1),
    tostring(info.classification or "normal"),
    tostring(info.difficulty or 0),
  }, "|")
end

local function xpContextKey(info)
  -- Quest state is intentionally absent.
  return table.concat({
    tostring(info.playerLevel or 0),
    tostring(info.mobLevel or 0),
    tostring(info.groupSize or 1),
    tostring(info.rested == true),
    tostring(info.buffSignature or "unknown"),
    tostring(info.classification or "normal"),
  }, "|")
end

local function updateMobLevelRange(state, observed, known)
  if not known then return state end
  local level = tonumber(observed)
  if not level or level <= 0 then return state end
  state.min = state.min and math.min(state.min, level) or level
  state.max = state.max and math.max(state.max, level) or level
  state.samples = (state.samples or 0) + 1
  return state
end

local function newTimeTracker(cap)
  return {
    presenceSeconds = 0,
    engagedSeconds = 0,
    zones = {},
    levels = {},
    engagedZones = {},
    engagedLevels = {},
    lastEventAt = nil,
    lastKillAt = nil,
    zone = nil,
    level = nil,
    cap = cap or 60,
  }
end
local function addPresence(tracker, seconds)
  if seconds <= 0 then return end
  tracker.presenceSeconds = tracker.presenceSeconds + seconds
  if tracker.zone then tracker.zones[tracker.zone] = (tracker.zones[tracker.zone] or 0) + seconds end
  if tracker.level then tracker.levels[tracker.level] = (tracker.levels[tracker.level] or 0) + seconds end
end
local function addEngaged(tracker, seconds)
  if seconds <= 0 then return end
  local capped = math.min(seconds, tracker.cap)
  tracker.engagedSeconds = tracker.engagedSeconds + capped
  if tracker.zone then tracker.engagedZones[tracker.zone] = (tracker.engagedZones[tracker.zone] or 0) + capped end
  if tracker.level then tracker.engagedLevels[tracker.level] = (tracker.engagedLevels[tracker.level] or 0) + capped end
end
local function closePresence(tracker, now)
  if tracker.lastEventAt and now >= tracker.lastEventAt then
    addPresence(tracker, now - tracker.lastEventAt)
  end
  tracker.lastEventAt = now
end
local function onZoneEvent(tracker, zone, level, now)
  closePresence(tracker, now)
  tracker.zone = zone
  tracker.level = level
  tracker.lastKillAt = now
end
local function onKillEvent(tracker, now)
  closePresence(tracker, now)
  if tracker.lastKillAt then
    addEngaged(tracker, now - tracker.lastKillAt)
  end
  tracker.lastKillAt = now
end
local function onLogout(tracker, now)
  closePresence(tracker, now)
  if tracker.lastKillAt then
    addEngaged(tracker, now - tracker.lastKillAt)
  end
  tracker.lastKillAt = now
end

local tracker = newTimeTracker(60)
onZoneEvent(tracker, "map:1421", 20, 100)
onKillEvent(tracker, 110)
onKillEvent(tracker, 170)
onZoneEvent(tracker, "map:1421", 21, 200) -- level change
onKillEvent(tracker, 260)
onZoneEvent(tracker, "map:1422", 21, 300) -- zone change
onLogout(tracker, 360)
assert(tracker.presenceSeconds == 260)
assert(tracker.zones["map:1421"] == 200)
assert(tracker.zones["map:1422"] == 60)
assert(tracker.levels[20] == 100)
assert(tracker.levels[21] == 160)
assert(tracker.engagedSeconds == 190)
print(string.format("event_time_presence_total=%d zone1=%d zone2=%d level20=%d level21=%d engaged_total=%d",
  tracker.presenceSeconds, tracker.zones["map:1421"], tracker.zones["map:1422"],
  tracker.levels[20], tracker.levels[21], tracker.engagedSeconds))
print("event_time_timer_used=false reused_events=enter,zone,level,kill,xp,death,login logout_finalizer=one")

local function addHeatmapCell(heatmap, cell, xp, seconds)
  local entry = heatmap.cells[cell]
  if type(entry) ~= "table" then
    entry = { kills = 0, xp = 0, activeSeconds = 0, lastSeen = 0 }
    heatmap.cells[cell] = entry
  end
  entry.kills = entry.kills + 1
  entry.xp = entry.xp + (tonumber(xp) or 0)
  entry.activeSeconds = entry.activeSeconds + (tonumber(seconds) or 0)
  heatmap.total = (heatmap.total or 0) + 1
  return entry
end

local function makeDeath(info)
  local band, pct, healthKnown = healthBand(info.health, info.healthMax)
  local groupSize, groupKnown = groupInfo(info.groupCapability, info.groupSize)
  local buffSignature, buffKnown = buffInfo(info.buffCapability, info.buffSignature)
  return {
    at = info.at,
    mapID = info.mapID,
    x = info.x,
    y = info.y,
    mobKey = info.mobKey,
    npcID = info.npcID,
    playerLevel = info.playerLevel or 0,
    mobLevel = info.mobLevel,
    mobLevelKnown = info.mobLevelKnown == true,
    playerHealth = info.health,
    playerHealthMax = info.healthMax,
    healthBand = band,
    healthKnown = healthKnown,
    buffSignature = buffSignature,
    buffKnown = buffKnown,
    groupSize = groupSize,
    groupKnown = groupKnown,
    classification = info.classification or "unknown",
    difficulty = info.difficulty or 0,
    combatContextKey = combatContextKey({
      playerLevel = info.playerLevel, mobLevel = info.mobLevel,
      healthBand = band, buffSignature = buffSignature,
      groupSize = groupSize, classification = info.classification,
      difficulty = info.difficulty,
    }),
  }
end

-- ---------------------------------------------------------------------------
-- Capture capability matrix
-- ---------------------------------------------------------------------------

local matrix = {
  { client = "Forever", health = true, buffs = true, group = true, mobLevel = true, deathAttribution = "needs verification", activeTime = true, cellXPTime = true },
  { client = "Midnight", health = true, buffs = true, group = true, mobLevel = true, deathAttribution = "needs verification", activeTime = true, cellXPTime = true },
  { client = "unknown", health = false, buffs = false, group = false, mobLevel = false, deathAttribution = false, activeTime = true, cellXPTime = false },
}
print("capture_matrix")
for _, row in ipairs(matrix) do
  print(string.format("  client=%s health=%s buffs=%s group=%s mobLevel=%s deathAttribution=%s activeTime=%s cellXPTime=%s",
    row.client, tostring(row.health), tostring(row.buffs), tostring(row.group),
    tostring(row.mobLevel), tostring(row.deathAttribution), tostring(row.activeTime),
    tostring(row.cellXPTime)))
end

-- ---------------------------------------------------------------------------
-- Field helper tests
-- ---------------------------------------------------------------------------

print("health_bands")
for _, pair in ipairs({{0, 100}, {20, 100}, {21, 100}, {40, 100}, {41, 100}, {60, 100}, {61, 100}, {80, 100}, {81, 100}, {100, 100}, {nil, 100}, {10, 0}}) do
  local band, pct, known = healthBand(pair[1], pair[2])
  print(string.format("  hp=%s/%s band=%s pct=%s known=%s",
    tostring(pair[1]), tostring(pair[2]), band, pct and string.format("%.1f", pct) or "nil", tostring(known)))
end

local groupSize, groupKnown = groupInfo(false, 5)
assert(groupSize == 1 and groupKnown == false)
groupSize, groupKnown = groupInfo(true, 5)
assert(groupSize == 5 and groupKnown == true)
local buff, buffKnown = buffInfo(false, "wf")
assert(buff == "unknown" and buffKnown == false)
buff, buffKnown = buffInfo(true, "wf+wr3")
assert(buff == "wf+wr3" and buffKnown == true)
local mobLevel, mobKnown = mobLevelInfo(false, 26)
assert(mobLevel == nil and mobKnown == false)
mobLevel, mobKnown = mobLevelInfo(true, 26)
assert(mobLevel == 26 and mobKnown == true)
print("fallbacks=health_unknown;group_solo_unknown;buffs_unknown;mob_level_unknown")

local baseInfo = {
  playerLevel = 26, mobLevel = 26, healthBand = "81-100",
  buffSignature = "wf", groupSize = 1, classification = "normal", difficulty = 1,
}
local combatA = combatContextKey(baseInfo)
local combatB = combatContextKey({ playerLevel=26, mobLevel=26, healthBand="21-40", buffSignature="wf", groupSize=1, classification="normal", difficulty=1 })
assert(combatA ~= combatB)
local xpA = xpContextKey({ playerLevel=26, mobLevel=26, groupSize=1, rested=false, buffSignature="wf", classification="normal" })
local xpB = xpContextKey({ playerLevel=26, mobLevel=26, groupSize=2, rested=true, buffSignature="wf", classification="normal" })
assert(xpA ~= xpB)
assert(not xpA:find("quest"))
print(string.format("combat_key_len=%d xp_key_len=%d health_context_changes=true group_rested_context_changes=true quest_state_excluded=true",
  #combatA, #xpA))

local range = { min = nil, max = nil, samples = 0 }
updateMobLevelRange(range, 26, true)
updateMobLevelRange(range, 28, true)
updateMobLevelRange(range, 27, true)
assert(range.min == 26 and range.max == 28 and range.samples == 3)
local unknownRange = { min = nil, max = nil, samples = 0 }
updateMobLevelRange(unknownRange, 26, false)
assert(unknownRange.min == nil and unknownRange.samples == 0)
print(string.format("mob_level_range=%d..%d samples=%d unknown_fallback_ok=true",
  range.min, range.max, range.samples))

local heatmap = { cells = {}, total = 0 }
addHeatmapCell(heatmap, 42, 95, 10)
addHeatmapCell(heatmap, 42, 105, 20)
assert(heatmap.cells[42].kills == 2 and heatmap.cells[42].xp == 200)
assert(heatmap.cells[42].activeSeconds == 30 and heatmap.total == 2)
print(string.format("heatmap_cell kills=%d xp=%d active=%d total=%d",
  heatmap.cells[42].kills, heatmap.cells[42].xp,
  heatmap.cells[42].activeSeconds, heatmap.total))

local deathAttributed = makeDeath({
  at = 1000, mapID = 1421, x = 0.2, y = 0.3,
  mobKey = "npc:123", npcID = 123, playerLevel = 26, mobLevel = 27,
  mobLevelKnown = true, health = 80, healthMax = 100,
  groupCapability = true, groupSize = 1, buffCapability = true,
  buffSignature = "wf", classification = "elite", difficulty = 1,
})
assert(deathAttributed.mobKey == "npc:123")
assert(deathAttributed.healthBand == "61-80")
assert(deathAttributed.healthKnown == true)
assert(deathAttributed.groupKnown == true)
assert(deathAttributed.buffKnown == true)
local deathUnknown = makeDeath({
  at = 1001, mapID = 1421, x = 0.2, y = 0.3,
  mobKey = nil, npcID = nil, playerLevel = 26,
  mobLevel = nil, mobLevelKnown = false, health = nil, healthMax = nil,
  groupCapability = false, groupSize = nil, buffCapability = false,
  buffSignature = nil, classification = "unknown",
})
assert(deathUnknown.mobKey == nil)
assert(deathUnknown.healthBand == "unknown")
assert(deathUnknown.groupKnown == false)
assert(deathUnknown.buffKnown == false)
print("death_attributed=true death_unknown_safe=true death_same_circumstances_fields=health,buffs,group,mobLevel,classification,difficulty")
print("quest_state_in_combat_context=false quest_state_in_xp_context=false no_per_kill_log=true")
print("no_merge_implemented=true no_ui=true no_online=true")
