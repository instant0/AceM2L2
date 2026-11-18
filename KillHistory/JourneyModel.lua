--[[---------------------------------------------------------------------------------
  KillHistory/JourneyModel.lua
  S1 read-owner/parity scaffolding.

  Read-only helpers expose the v2 field names without switching the canonical
  store. Legacy data is read first; v2 data is used only when the legacy value is
  absent. No writer, UI, block, or schema behavior changes here.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory

local function finite(value)
  local number = tonumber(value)
  if not number or number ~= number
    or number == math.huge or number == -math.huge then
    return 0
  end
  return number
end

local function copyLevelCounts(source)
  local result = {}
  for level, count in pairs(source or {}) do
    result[tostring(level)] = { kills = finite(count) }
  end
  return result
end

local function copyLevelRecords(source)
  local result = {}
  for level, record in pairs(source or {}) do
    if type(record) == "table" then
      result[tostring(level)] = {
        kills = finite(record.kills),
        xp = finite(record.xp),
        samples = finite(record.samples or record.kills),
      }
    else
      result[tostring(level)] = { kills = finite(record) }
    end
  end
  return result
end

local function questKey(value)
  local text = tostring(value or "")
  if text:sub(1, 6) == "quest:" then return text end
  return "quest:" .. text
end

local function mobLevelRangeFromLegacy(mob)
  local minLevel, maxLevel
  for _, context in pairs(mob.contexts or {}) do
    local level = tonumber(context.mobLevel)
    if level and level > 0 then
      if not minLevel or level < minLevel then minLevel = level end
      if not maxLevel or level > maxLevel then maxLevel = level end
    end
  end
  return minLevel or tonumber(mob.mobLevelMin) or 0,
    maxLevel or tonumber(mob.mobLevelMax) or 0
end

local function migrateLegacyMob(mob)
  local byPlayerLevel = copyLevelCounts(mob.killsAtLevel)
  local byZone = {}
  for mapID, kills in pairs(mob.killsByMap or {}) do
    byZone[tostring(mapID)] = { kills = finite(kills), playerLevels = {} }
  end
  for mapID, levels in pairs(mob.killsByAreaLevel or {}) do
    local zone = byZone[tostring(mapID)]
    if not zone then
      zone = { kills = 0, playerLevels = {} }
      byZone[tostring(mapID)] = zone
    end
    zone.playerLevels = copyLevelCounts(levels)
  end
  local byInstance = {}
  for instanceKey, kills in pairs(mob.killsByInstance or {}) do
    byInstance[tostring(instanceKey)] = {
      kills = finite(kills), playerLevels = {},
    }
  end
  for instanceKey, levels in pairs(mob.killsByInstanceLevel or {}) do
    local instance = byInstance[tostring(instanceKey)]
    if not instance then
      instance = { kills = 0, playerLevels = {} }
      byInstance[tostring(instanceKey)] = instance
    end
    instance.playerLevels = copyLevelCounts(levels)
  end
  local minLevel, maxLevel = mobLevelRangeFromLegacy(mob)
  return {
    npcID = mob.npcID,
    name = mob.name,
    classification = mob.classification or "normal",
    kills = finite(mob.kills),
    xp = finite(mob.totalXP),
    mobLevelMin = minLevel,
    mobLevelMax = maxLevel,
    mobLevelSamples = finite(mob.mobLevelSamples or mob.kills),
    byPlayerLevel = byPlayerLevel,
    byZone = byZone,
    byInstance = byInstance,
    contexts = mob.contexts,
    firstSeen = finite(mob.firstSeen),
    lastSeen = finite(mob.lastSeen),
  }
end

function XPTooltip:EnsureModelMobs()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.mobs) ~= "table" then journey.mobs = {} end
  if journey.mobsMigrated then return journey.mobs end
  local db = self.char or {}
  for key, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" and not journey.mobs[key] then
      journey.mobs[key] = migrateLegacyMob(mob)
    end
  end
  journey.mobsMigrated = true
  return journey.mobs
end

function XPTooltip:RecordModelMobKill(mobKey, info, mapID, instanceKey,
  playerLevel, totalXP)
  local journey = self:EnsureJourney()
  if not journey then return false end
  local mobs = self:EnsureModelMobs()
  if not mobs then return false end
  local key = tostring(mobKey or "")
  local record = mobs[key]
  if type(record) ~= "table" then
    record = migrateLegacyMob({
      npcID = info and info.npcID,
      name = info and info.name,
      classification = info and info.classification,
      kills = 0, totalXP = 0,
      killsAtLevel = {}, killsByMap = {}, killsByAreaLevel = {},
      killsByInstance = {}, killsByInstanceLevel = {},
      contexts = {}, firstSeen = 0, lastSeen = 0,
    })
    mobs[key] = record
  end
  local now = XPTooltip.Util and XPTooltip.Util.Epoch
    and XPTooltip.Util.Epoch() or 0
  local amount = finite(totalXP)
  local level = tonumber(playerLevel) or 0
  record.npcID = record.npcID or (info and info.npcID)
  record.name = record.name or (info and info.name)
  record.classification = record.classification
    or (info and info.classification) or "normal"
  record.kills = finite(record.kills) + 1
  record.xp = finite(record.xp) + amount
  local mobLevel = tonumber(info and info.level)
  if mobLevel and mobLevel > 0 then
    record.mobLevelMin = record.mobLevelMin > 0
      and math.min(record.mobLevelMin, mobLevel) or mobLevel
    record.mobLevelMax = math.max(tonumber(record.mobLevelMax) or 0, mobLevel)
    record.mobLevelSamples = finite(record.mobLevelSamples) + 1
  end
  if level > 0 then
    record.byPlayerLevel[tostring(level)] =
      record.byPlayerLevel[tostring(level)] or { kills = 0, xp = 0, samples = 0 }
    local atLevel = record.byPlayerLevel[tostring(level)]
    atLevel.kills = finite(atLevel.kills) + 1
    atLevel.xp = finite(atLevel.xp) + amount
    atLevel.samples = finite(atLevel.samples) + 1
  end
  local mapKey = tostring(mapID or 0)
  record.byZone[mapKey] = record.byZone[mapKey]
    or { kills = 0, playerLevels = {} }
  record.byZone[mapKey].kills = finite(record.byZone[mapKey].kills) + 1
  if level > 0 then
    local zoneLevels = record.byZone[mapKey].playerLevels
    zoneLevels[tostring(level)] =
      zoneLevels[tostring(level)] or { kills = 0 }
    zoneLevels[tostring(level)].kills =
      finite(zoneLevels[tostring(level)].kills) + 1
  end
  if instanceKey then
    local instanceKills = record.byInstance[tostring(instanceKey)]
      or { kills = 0, playerLevels = {} }
    record.byInstance[tostring(instanceKey)] = instanceKills
    instanceKills.kills = finite(instanceKills.kills) + 1
    if level > 0 then
      local instanceLevels = instanceKills.playerLevels
      instanceLevels[tostring(level)] =
        instanceLevels[tostring(level)] or { kills = 0 }
      instanceLevels[tostring(level)].kills =
        finite(instanceLevels[tostring(level)].kills) + 1
    end
  end
  record.firstSeen = record.firstSeen > 0 and record.firstSeen or now
  record.lastSeen = now
  return true
end

function XPTooltip:GetModelMob(mobKey)
  local key = tostring(mobKey or "")
  local mobs = self:EnsureModelMobs()
  local journey = mobs and mobs[key]
  if type(journey) ~= "table" then
    return nil, "missing"
  end
  return {
    source = "v2",
    key = key,
    npcID = journey.npcID,
    name = journey.name,
    classification = journey.classification or "normal",
    kills = finite(journey.kills),
    xp = finite(journey.xp),
    mobLevelMin = finite(journey.mobLevelMin),
    mobLevelMax = finite(journey.mobLevelMax),
    byPlayerLevel = copyLevelRecords(journey.byPlayerLevel),
    byZone = journey.byZone or {},
    byInstance = journey.byInstance or {},
    contexts = journey.contexts,
    firstSeen = finite(journey.firstSeen),
    lastSeen = finite(journey.lastSeen),
  }
end

function XPTooltip:GetModelZone(mapID)
  local db = self.char or {}
  local key = tostring(mapID or "")
  local legacyKills = db.areas and db.areas[key]
  local journey = db.journey and db.journey.zones
    and db.journey.zones[key]
  if legacyKills == nil and type(journey) ~= "table" then
    return nil, "missing"
  end
  local playerLevels = copyLevelCounts(db.areaLevels and db.areaLevels[key])
  if next(playerLevels) == nil and type(journey) == "table" then
    playerLevels = copyLevelRecords(journey.levels)
  end
  return {
    source = legacyKills ~= nil and "legacy" or "v2",
    timeSource = type(journey) == "table" and "journey" or nil,
    key = key,
    mapID = tonumber(mapID) or 0,
    kills = legacyKills ~= nil and finite(legacyKills)
      or (type(journey) == "table" and finite(journey.kills) or 0),
    killXP = type(journey) == "table" and finite(journey.killXP) or 0,
    questXP = type(journey) == "table" and finite(journey.questXP) or 0,
    otherXP = type(journey) == "table" and finite(journey.otherXP) or 0,
    xp = type(journey) == "table" and finite(journey.xp) or 0,
    presenceSeconds = type(journey) == "table"
      and finite(journey.presenceSeconds) or 0,
    engagedSeconds = type(journey) == "table"
      and finite(journey.engagedSeconds) or 0,
    deaths = type(journey) == "table" and finite(journey.deaths) or 0,
    sessions = type(journey) == "table" and finite(journey.sessions) or 0,
    playerLevels = playerLevels,
    uniqueMobs = 0,
    lastSeen = type(journey) == "table" and finite(journey.lastSeen) or 0,
  }
end

function XPTooltip:GetModelLevel(level)
  local db = self.char or {}
  local key = tostring(level or "")
  local legacyKills = db.levels and db.levels[key]
  local journey = db.journey and db.journey.levels
    and db.journey.levels[key]
  if legacyKills == nil and type(journey) ~= "table" then
    return nil, "missing"
  end
  return {
    source = legacyKills ~= nil and "legacy" or "v2",
    timeSource = type(journey) == "table" and "journey" or nil,
    level = tonumber(level) or 0,
    kills = legacyKills ~= nil and finite(legacyKills)
      or (type(journey) == "table" and finite(journey.kills) or 0),
    killXP = type(journey) == "table" and finite(journey.killXP) or 0,
    questXP = type(journey) == "table" and finite(journey.questXP) or 0,
    otherXP = type(journey) == "table" and finite(journey.otherXP) or 0,
    xp = type(journey) == "table" and finite(journey.xp) or 0,
    presenceSeconds = type(journey) == "table"
      and finite(journey.presenceSeconds) or 0,
    engagedSeconds = type(journey) == "table"
      and finite(journey.engagedSeconds) or 0,
  }
end

function XPTooltip:GetModelInstance(instanceKey)
  local db = self.char or {}
  local key = tostring(instanceKey or "")
  local legacy = db.instances and db.instances[key]
  local journey = db.journey and db.journey.instances
    and db.journey.instances[key]
  local source = type(legacy) == "table" and legacy
    or (type(journey) == "table" and journey or nil)
  if not source then return nil, "missing" end
  return {
    source = type(legacy) == "table" and "legacy" or "v2",
    key = key,
    name = source.name,
    instanceType = source.instanceType,
    instanceID = source.instanceID,
    difficultyID = source.difficultyID,
    mapID = source.mapID,
    kills = finite(source.kills),
    killXP = finite(source.killXP),
    questXP = finite(source.questXP),
    otherXP = finite(source.otherXP),
    xp = finite(source.xp),
    presenceSeconds = finite(source.presenceSeconds),
    engagedSeconds = finite(source.engagedSeconds),
    deaths = finite(source.deaths),
    sessions = finite(source.sessions),
    playerLevels = type(source.playerLevels) == "table"
      and copyLevelRecords(source.playerLevels)
      or copyLevelCounts(source.killsAtLevel),
    lastSeen = finite(source.lastSeen),
  }
end

function XPTooltip:GetModelHeatmap(mapID)
  local db = self.char or {}
  local key = tostring(mapID or "")
  local legacy = db.heatmaps and db.heatmaps[key]
  local journey = db.journey and db.journey.heatmaps
    and db.journey.heatmaps[key]
  local source = type(legacy) == "table" and legacy
    or (type(journey) == "table" and journey or nil)
  if not source then return nil, "missing" end
  return {
    source = type(legacy) == "table" and "legacy" or "v2",
    key = key,
    mapID = tonumber(mapID) or 0,
    cells = source.cells or {},
    total = finite(source.total),
    top10 = source.top10,
    lastSeen = finite(source.lastSeen),
  }
end

function XPTooltip:GetModelQuest(value)
  local db = self.char or {}
  local key = questKey(value)
  local legacy = db.quests and db.quests[key]
  local journey = db.journey and db.journey.quests
    and db.journey.quests[key]
  local source = type(legacy) == "table" and legacy
    or (type(journey) == "table" and journey or nil)
  if not source then return nil, "missing" end
  return {
    source = type(legacy) == "table" and "legacy" or "v2",
    key = key,
    id = tonumber(source.id) or tonumber(key:gsub("^quest:", "")) or 0,
    count = finite(source.count),
    xp = finite(source.totalXP or source.xp),
    lastTurnInAt = finite(source.lastTurnInAt),
    mapID = source.mapID,
    playerLevel = source.playerLevel,
    lastSeen = finite(source.lastSeen),
  }
end

function XPTooltip:GetModelDeath(index)
  local db = self.char or {}
  local legacy = db.deaths and db.deaths[index]
  local journey = db.journey and db.journey.deaths
    and db.journey.deaths[index]
  local source = type(legacy) == "table" and legacy
    or (type(journey) == "table" and journey or nil)
  if not source then return nil, "missing" end
  return {
    source = type(legacy) == "table" and "legacy" or "v2",
    index = index,
    at = finite(source.at),
    mapID = source.mapID,
    x = source.x,
    y = source.y,
    mobKey = source.mobKey,
    npcID = source.npcID,
    health = source.health,
    healthBand = source.healthBand,
    buffs = source.buffs,
    groupSize = source.groupSize,
    classification = source.classification,
    difficultyID = source.difficultyID,
  }
end

function XPTooltip:GetModelRespawn(npcID)
  local db = self.char or {}
  local key = tostring(npcID or "")
  local legacy = db.respawns and (db.respawns[key] or db.respawns[tonumber(npcID)])
  local journey = db.journey and db.journey.respawns
    and db.journey.respawns[key]
  local source = type(legacy) == "table" and legacy
    or (type(journey) == "table" and journey or nil)
  if not source then return nil, "missing" end
  return {
    source = type(legacy) == "table" and "legacy" or "v2",
    npcID = tonumber(npcID) or 0,
    name = source.name,
    samples = finite(source.samples or #(source.intervals or {})),
    min = finite(source.min),
    max = finite(source.max),
    sum = finite(source.sum),
    lastSeen = finite(source.lastSeen),
    lastDeath = finite(source.lastDeath),
  }
end

XPTooltip.JourneyModelReady = true
