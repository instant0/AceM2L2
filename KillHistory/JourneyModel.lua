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
    local level = type(context) == "table" and tonumber(context.mobLevel) or nil
    if level and level > 0 then
      if not minLevel or level < minLevel then minLevel = level end
      if not maxLevel or level > maxLevel then maxLevel = level end
    end
  end
  return minLevel or tonumber(mob.mobLevelMin) or 0,
    maxLevel or tonumber(mob.mobLevelMax) or 0
end

local function contextRecord(key, source)
  if type(source) ~= "table" then return nil end
  local samples = finite(source.samples)
  if samples <= 0 and finite(source.sumBase) <= 0
    and finite(source.sumBuffed) <= 0 and finite(source.sumTotal) <= 0 then
    return nil
  end
  return {
    key = tostring(key),
    playerLevel = finite(source.playerLevel),
    mobLevel = finite(source.mobLevel),
    groupSize = finite(source.groupSize),
    mapID = finite(source.mapID),
    instanceKey = source.instanceKey,
    classification = source.classification or "normal",
    buffSig = source.buffSig or "none",
    samples = samples,
    sumBase = finite(source.sumBase),
    sumBuffed = finite(source.sumBuffed),
    sumTotal = finite(source.sumTotal),
    minBase = finite(source.minBase),
    maxBase = finite(source.maxBase),
    lastSeen = finite(source.lastSeen),
  }
end

local function buildContextShape(source)
  local records = {}
  for key, context in pairs(source or {}) do
    local record = contextRecord(key, context)
    if record then records[#records + 1] = record end
  end
  table.sort(records, function(a, b)
    if a.samples ~= b.samples then return a.samples > b.samples end
    return a.key < b.key
  end)
  local top8, other = {}, {
    key = "other", classification = "other", buffSig = "other",
    samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0,
    minBase = nil, maxBase = nil, lastSeen = 0,
  }
  for index = 1, #records do
    local record = records[index]
    if index <= 8 then
      top8[#top8 + 1] = record
    else
      other.samples = other.samples + record.samples
      other.sumBase = other.sumBase + record.sumBase
      other.sumBuffed = other.sumBuffed + record.sumBuffed
      other.sumTotal = other.sumTotal + record.sumTotal
      other.lastSeen = math.max(other.lastSeen, record.lastSeen)
      if record.minBase and (not other.minBase or record.minBase < other.minBase) then
        other.minBase = record.minBase
      end
      if record.maxBase and (not other.maxBase or record.maxBase > other.maxBase) then
        other.maxBase = record.maxBase
      end
    end
  end
  local combat, xpContexts = {}, {}
  for index = 1, #records do
    local record = records[index]
    combat[index] = {
      key = record.key, playerLevel = record.playerLevel,
      mobLevel = record.mobLevel, groupSize = record.groupSize,
      mapID = record.mapID, instanceKey = record.instanceKey,
      classification = record.classification, buffSig = record.buffSig,
      samples = record.samples, healthKnown = false,
      deaths = nil, lastSeen = record.lastSeen,
    }
    xpContexts[index] = {
      key = record.key, playerLevel = record.playerLevel,
      mobLevel = record.mobLevel, groupSize = record.groupSize,
      mapID = record.mapID, instanceKey = record.instanceKey,
      classification = record.classification, buffSig = record.buffSig,
      samples = record.samples, sumBase = record.sumBase,
      sumBuffed = record.sumBuffed, sumTotal = record.sumTotal,
      minBase = record.minBase, maxBase = record.maxBase,
      lastSeen = record.lastSeen,
    }
  end
  return records, combat, xpContexts, top8, other
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
  local contexts, combat, xpContexts, top8, other =
    buildContextShape(mob.contexts)
  return {
    npcID = mob.npcID,
    name = mob.name,
    classification = mob.classification or "normal",
    kills = finite(mob.kills),
    xp = finite(mob.totalXP),
    sessionKills = finite(mob.sessionKills),
    xpStats = type(mob.xp) == "table" and {
      samples = finite(mob.xp.samples),
      sumBase = finite(mob.xp.sumBase),
      sumBuffed = finite(mob.xp.sumBuffed),
      sumTotal = finite(mob.xp.sumTotal),
      minBase = finite(mob.xp.minBase),
      maxBase = finite(mob.xp.maxBase),
      lastBase = finite(mob.xp.lastBase),
      lastTotal = finite(mob.xp.lastTotal),
    } or nil,
    mobLevelMin = minLevel,
    mobLevelMax = maxLevel,
    mobLevelSamples = finite(mob.mobLevelSamples or mob.kills),
    byPlayerLevel = byPlayerLevel,
    byZone = byZone,
    byInstance = byInstance,
    contexts = contexts,
    combat = combat,
    xpContexts = xpContexts,
    contextsTop8 = top8,
    contextsOther = other,
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
  record.sessionKills = finite(record.sessionKills) + 1
  local stats = record.xpStats
  if type(stats) ~= "table" then
    stats = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0 }
    record.xpStats = stats
  end
  stats.samples = finite(stats.samples) + 1
  stats.sumTotal = finite(stats.sumTotal) + amount
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

function XPTooltip:SyncModelMobFromLegacy(mobKey)
  local journey = self:EnsureJourney()
  if not journey then return false end
  if type(journey.mobs) ~= "table" then journey.mobs = {} end
  local key = tostring(mobKey or "")
  local db = self.char or {}
  local legacy = db.mobs and db.mobs[key]
  if type(legacy) == "table" then
    journey.mobs[key] = migrateLegacyMob(legacy)
    return true
  end
  if journey.mobs[key] ~= nil then
    journey.mobs[key] = nil
    return true
  end
  return false
end

function XPTooltip:SyncModelMobContextsFromLegacy(mobKey)
  local journey = self:EnsureJourney()
  if not journey then return false end
  local key = tostring(mobKey or "")
  local db = self.char or {}
  local legacy = db.mobs and db.mobs[key]
  if type(legacy) ~= "table" then return false end
  local mobs = self:EnsureModelMobs()
  if not mobs then return false end
  local record = mobs[key]
  if type(record) ~= "table" then
    record = migrateLegacyMob(legacy)
    mobs[key] = record
  end
  local contexts, combat, xpContexts, top8, other =
    buildContextShape(legacy.contexts)
  record.contexts = contexts
  record.combat = combat
  record.xpContexts = xpContexts
  record.contextsTop8 = top8
  record.contextsOther = other
  if type(legacy.xp) == "table" then
    record.xpStats = {
      samples = finite(legacy.xp.samples),
      sumBase = finite(legacy.xp.sumBase),
      sumBuffed = finite(legacy.xp.sumBuffed),
      sumTotal = finite(legacy.xp.sumTotal),
      minBase = finite(legacy.xp.minBase),
      maxBase = finite(legacy.xp.maxBase),
      lastBase = finite(legacy.xp.lastBase),
      lastTotal = finite(legacy.xp.lastTotal),
    }
  end
  return true
end

function XPTooltip:SyncModelMobsFromLegacy()
  local journey = self:EnsureJourney()
  if not journey then return false end
  local db = self.char or {}
  local mobs = {}
  for key, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      mobs[key] = migrateLegacyMob(mob)
    end
  end
  journey.mobs = mobs
  journey.mobsMigrated = true
  return true
end

local function deriveZoneKillXP(db, mapKey)
  local total = 0
  for _, mob in pairs(db.mobs or {}) do
    local kills = tonumber(mob.kills) or 0
    local mapKills = tonumber((mob.killsByMap or {})[mapKey]) or 0
    local xp = tonumber(mob.totalXP) or 0
    if kills > 0 and mapKills > 0 and xp > 0 then
      total = total + xp * mapKills / kills
    end
  end
  return math.floor(total + 0.5)
end

function XPTooltip:EnsureModelZones()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.zones) ~= "table" then journey.zones = {} end
  if journey.zonesMigrated then return journey.zones end
  local db = self.char or {}
  journey.zonesMigrated = true
  for mapKey, kills in pairs(db.areas or {}) do
    local key = tostring(mapKey)
    local zone = journey.zones[key]
    if type(zone) ~= "table" then
      zone = { levels = {}, deaths = 0, sessions = 0, presenceSeconds = 0,
        engagedSeconds = 0, questXP = 0, otherXP = 0, xp = 0 }
      journey.zones[key] = zone
    end
    zone.kills = finite(kills)
    zone.playerLevels = copyLevelCounts((db.areaLevels or {})[key])
    if next(zone.playerLevels) == nil then
      zone.playerLevels = copyLevelRecords(zone.levels)
    end
    zone.killXP = deriveZoneKillXP(db, key)
    zone.otherXP = finite((db.unattributed and db.unattributed.byMap or {})[key])
    zone.questXP = finite(zone.questXP)
    zone.xp = finite(zone.killXP) + finite(zone.questXP) + finite(zone.otherXP)
    zone.killsExact = true
    zone.killXPCoverage = "derived"
    zone.questXPCoverage = "post-instrumentation"
    zone.otherXPCoverage = zone.otherXP > 0 and "derived" or "post-instrumentation"
    zone.xpCoverage = "partial"
    zone.timeCoverage = "post-instrumentation"
  end
  return journey.zones
end

function XPTooltip:EnsureModelLevels()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.levels) ~= "table" then journey.levels = {} end
  if journey.levelsMigrated then return journey.levels end
  local db = self.char or {}
  journey.levelsMigrated = true
  local history = {}
  for _, entry in pairs(db.levelHistory or {}) do
    local level = tonumber(entry.level)
    if level then history[tostring(level)] = entry end
  end
  for levelKey, kills in pairs(db.levels or {}) do
    local key = tostring(levelKey)
    local record = journey.levels[key]
    if type(record) ~= "table" then
      record = {
        kills = 0, killXP = 0, questXP = 0, otherXP = 0, xp = 0,
        presenceSeconds = 0, engagedSeconds = 0,
      }
      journey.levels[key] = record
    end
    record.kills = finite(kills)
    local entry = history[key]
    if entry then
      record.startedAt = finite(entry.startedAt)
      record.endedAt = finite(entry.endedAt)
      if finite(record.xp) <= 0 then
        record.xp = finite(entry.xpGained)
        record.xpCoverage = "level-history"
      else
        record.xpCoverage = "post-instrumentation"
      end
    else
      record.xpCoverage = "post-instrumentation"
    end
    record.killsExact = true
    record.xpCoverage = record.xpCoverage or "partial"
    record.timeCoverage = "post-instrumentation"
  end
  return journey.levels
end

function XPTooltip:SyncModelZoneFromLegacy(mapID)
  local zones = self:EnsureModelZones()
  self:EnsureModelLevels()
  local db = self.char or {}
  local key = tostring(mapID or "")
  local zone = zones and zones[key]
  local legacyKills = db.areas and db.areas[key]
  if type(zone) ~= "table" and legacyKills == nil then return false end
  if type(zone) ~= "table" then
    zone = { levels = {}, deaths = 0, sessions = 0, presenceSeconds = 0,
      engagedSeconds = 0, questXP = 0, otherXP = 0, xp = 0 }
    zones[key] = zone
  end
  if legacyKills ~= nil then zone.kills = finite(legacyKills) end
  local playerLevels = copyLevelCounts((db.areaLevels or {})[key])
  if next(playerLevels) ~= nil then zone.playerLevels = playerLevels end
  zone.killXP = deriveZoneKillXP(db, key)
  zone.otherXP = finite((db.unattributed and db.unattributed.byMap or {})[key])
  zone.questXP = finite(zone.questXP)
  zone.xp = finite(zone.killXP) + finite(zone.questXP) + finite(zone.otherXP)
  zone.killXPCoverage = "derived"
  zone.otherXPCoverage = zone.otherXP > 0 and "derived" or "post-instrumentation"
  zone.questXPCoverage = "post-instrumentation"
  zone.xpCoverage = "partial"
  zone.timeCoverage = "post-instrumentation"
  return true
end

function XPTooltip:SyncModelLevelFromLegacy(level)
  local levels = self:EnsureModelLevels()
  local db = self.char or {}
  local key = tostring(level or "")
  local record = levels and levels[key]
  local legacyKills = db.levels and db.levels[key]
  if type(record) ~= "table" and legacyKills == nil then return false end
  if type(record) ~= "table" then
    record = {
      kills = 0, killXP = 0, questXP = 0, otherXP = 0, xp = 0,
      presenceSeconds = 0, engagedSeconds = 0,
    }
    levels[key] = record
  end
  if legacyKills ~= nil then record.kills = finite(legacyKills) end
  local history
  for _, entry in pairs(db.levelHistory or {}) do
    if tonumber(entry.level) == tonumber(level) then history = entry break end
  end
  if history then
    record.startedAt = finite(history.startedAt)
    record.endedAt = finite(history.endedAt)
    if finite(record.xp) <= 0 then
      record.xp = finite(history.xpGained)
      record.xpCoverage = "level-history"
    end
  end
  record.xpCoverage = record.xpCoverage or "post-instrumentation"
  record.timeCoverage = "post-instrumentation"
  return true
end

function XPTooltip:SyncModelZonesFromLegacy()
  local journey = self:EnsureJourney()
  if not journey then return false end
  self:EnsureModelZones()
  self:EnsureModelLevels()
  local db = self.char or {}
  for mapKey in pairs(db.areas or {}) do
    self:SyncModelZoneFromLegacy(mapKey)
  end
  for level in pairs(db.levels or {}) do
    self:SyncModelLevelFromLegacy(level)
  end
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
    sessionKills = finite(journey.sessionKills),
    xpStats = journey.xpStats,
    mobLevelMin = finite(journey.mobLevelMin),
    mobLevelMax = finite(journey.mobLevelMax),
    mobLevelSamples = finite(journey.mobLevelSamples),
    byPlayerLevel = copyLevelRecords(journey.byPlayerLevel),
    byZone = journey.byZone or {},
    byInstance = journey.byInstance or {},
    contexts = journey.contexts or {},
    combat = journey.combat or {},
    xpContexts = journey.xpContexts or {},
    contextsTop8 = journey.contextsTop8 or {},
    contextsOther = journey.contextsOther,
    firstSeen = finite(journey.firstSeen),
    lastSeen = finite(journey.lastSeen),
  }
end

function XPTooltip:GetModelZone(mapID)
  local zones = self:EnsureModelZones()
  local key = tostring(mapID or "")
  local zone = zones and zones[key]
  if type(zone) ~= "table" then return nil, "missing" end
  return {
    source = "v2",
    timeSource = "journey",
    key = key,
    mapID = tonumber(mapID) or 0,
    kills = finite(zone.kills),
    killXP = finite(zone.killXP),
    questXP = finite(zone.questXP),
    otherXP = finite(zone.otherXP),
    xp = finite(zone.xp),
    presenceSeconds = finite(zone.presenceSeconds),
    engagedSeconds = finite(zone.engagedSeconds),
    deaths = finite(zone.deaths),
    sessions = finite(zone.sessions),
    playerLevels = copyLevelRecords(zone.playerLevels or zone.levels),
    uniqueMobs = finite(zone.uniqueMobs),
    lastSeen = finite(zone.lastSeen),
    killsExact = zone.killsExact == true,
    killXPCoverage = zone.killXPCoverage,
    questXPCoverage = zone.questXPCoverage,
    otherXPCoverage = zone.otherXPCoverage,
    xpCoverage = zone.xpCoverage,
    timeCoverage = zone.timeCoverage,
  }
end

function XPTooltip:GetModelLevel(level)
  local levels = self:EnsureModelLevels()
  local key = tostring(level or "")
  local record = levels and levels[key]
  if type(record) ~= "table" then return nil, "missing" end
  return {
    source = "v2",
    timeSource = "journey",
    level = tonumber(level) or 0,
    kills = finite(record.kills),
    killXP = finite(record.killXP),
    questXP = finite(record.questXP),
    otherXP = finite(record.otherXP),
    xp = finite(record.xp),
    presenceSeconds = finite(record.presenceSeconds),
    engagedSeconds = finite(record.engagedSeconds),
    startedAt = finite(record.startedAt),
    endedAt = finite(record.endedAt),
    killsExact = record.killsExact == true,
    xpCoverage = record.xpCoverage,
    timeCoverage = record.timeCoverage,
  }
end

local function migrateLegacyInstance(instance)
  return {
    name = instance.name,
    instanceType = instance.instanceType,
    instanceID = instance.instanceID,
    difficultyID = instance.difficultyID,
    mapID = instance.mapID,
    kills = finite(instance.kills),
    killXP = finite(instance.killXP),
    questXP = finite(instance.questXP),
    otherXP = finite(instance.otherXP),
    xp = finite(instance.xp),
    playerLevels = copyLevelCounts(instance.killsAtLevel or instance.playerLevels),
    presenceSeconds = finite(instance.presenceSeconds),
    engagedSeconds = finite(instance.engagedSeconds),
    deaths = finite(instance.deaths),
    sessions = finite(instance.sessions),
    firstSeen = finite(instance.firstSeen),
    lastSeen = finite(instance.lastSeen),
    killsExact = true,
    xpCoverage = "legacy-total",
    timeCoverage = "unavailable",
    deathCoverage = "unavailable",
    sessionCoverage = "unavailable",
  }
end

function XPTooltip:EnsureModelInstances()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.instances) ~= "table" then journey.instances = {} end
  if journey.instancesMigrated then return journey.instances end
  local db = self.char or {}
  for key, instance in pairs(db.instances or {}) do
    if type(instance) == "table" and not journey.instances[key] then
      journey.instances[key] = migrateLegacyInstance(instance)
    end
  end
  journey.instancesMigrated = true
  return journey.instances
end

function XPTooltip:SyncModelInstanceFromLegacy(instanceKey)
  local instances = self:EnsureModelInstances()
  local db = self.char or {}
  local key = tostring(instanceKey or "")
  local legacy = db.instances and db.instances[key]
  if type(legacy) ~= "table" then
    if instances and instances[key] then
      instances[key] = nil
      return true
    end
    return false
  end
  local record = instances[key]
  if type(record) ~= "table" then
    instances[key] = migrateLegacyInstance(legacy)
    return true
  end
  record.name = legacy.name or record.name
  record.instanceType = legacy.instanceType or record.instanceType
  record.instanceID = legacy.instanceID or record.instanceID
  record.difficultyID = legacy.difficultyID or record.difficultyID
  record.mapID = legacy.mapID or record.mapID
  record.kills = finite(legacy.kills)
  record.killXP = finite(legacy.killXP)
  record.questXP = finite(legacy.questXP)
  record.otherXP = finite(legacy.otherXP)
  record.xp = finite(legacy.xp)
  record.playerLevels = copyLevelCounts(legacy.killsAtLevel
    or legacy.playerLevels)
  record.firstSeen = finite(legacy.firstSeen)
  record.lastSeen = finite(legacy.lastSeen)
  record.killsExact = true
  record.xpCoverage = "legacy-total"
  record.timeCoverage = (finite(record.presenceSeconds) > 0
    or finite(record.engagedSeconds) > 0)
    and "post-instrumentation" or "unavailable"
  record.deathCoverage = finite(record.deaths) > 0
    and "post-instrumentation" or "unavailable"
  record.sessionCoverage = finite(record.sessions) > 0
    and "post-instrumentation" or "unavailable"
  return true
end

function XPTooltip:SyncModelInstancesFromLegacy()
  local instances = self:EnsureModelInstances()
  local db = self.char or {}
  for key in pairs(db.instances or {}) do
    self:SyncModelInstanceFromLegacy(key)
  end
  if type(db.instances) == "table" then
    for key in pairs(instances) do
      if db.instances[key] == nil then instances[key] = nil end
    end
  end
  return true
end

function XPTooltip:GetModelInstance(instanceKey)
  local instances = self:EnsureModelInstances()
  local key = tostring(instanceKey or "")
  local record = instances and instances[key]
  if type(record) ~= "table" then return nil, "missing" end
  return {
    source = "v2",
    key = key,
    name = record.name,
    instanceType = record.instanceType,
    instanceID = record.instanceID,
    difficultyID = record.difficultyID,
    mapID = record.mapID,
    kills = finite(record.kills),
    killXP = finite(record.killXP),
    questXP = finite(record.questXP),
    otherXP = finite(record.otherXP),
    xp = finite(record.xp),
    presenceSeconds = finite(record.presenceSeconds),
    engagedSeconds = finite(record.engagedSeconds),
    deaths = finite(record.deaths),
    sessions = finite(record.sessions),
    playerLevels = copyLevelRecords(record.playerLevels),
    lastSeen = finite(record.lastSeen),
    killsExact = record.killsExact == true,
    xpCoverage = record.xpCoverage,
    timeCoverage = record.timeCoverage,
    deathCoverage = record.deathCoverage,
    sessionCoverage = record.sessionCoverage,
  }
end

local function buildHeatmapTop10(cells)
  local rows = {}
  for cell, value in pairs(cells or {}) do
    local kills = type(value) == "table" and finite(value.kills) or finite(value)
    if kills > 0 then
      rows[#rows + 1] = { cell = tonumber(cell) or 0, count = kills }
    end
  end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.cell < b.cell
  end)
  local top = {}
  for index = 1, math.min(10, #rows) do
    top[index] = rows[index]
  end
  return top
end

local function migrateLegacyHeatmap(entry, mapID)
  local gridSize = finite(entry.gridSize)
  if gridSize <= 0 then
    gridSize = XPTooltip.HEATMAP_GRID_SIZE or 64
  end
  local countCap = XPTooltip.MAX_HEATMAP_COUNT or 1000000
  local cellLimit = gridSize * gridSize
  local cells, total = {}, 0
  for rawCell, value in pairs(entry.cells or {}) do
    local numeric = tonumber(rawCell)
    local cell = numeric and math.floor(numeric)
    local kills = type(value) == "table" and finite(value.kills) or finite(value)
    if cell and cell == numeric and cell > 0 and cell <= cellLimit
      and kills > 0 then
      kills = math.min(kills, countCap)
      cells[cell] = { kills = kills }
      total = total + kills
    end
  end
  return {
    mapID = mapID,
    gridSize = gridSize,
    cells = cells,
    total = total,
    lastSeen = finite(entry.lastSeen),
    top10 = buildHeatmapTop10(cells),
    killsCoverage = "exact",
    cellXpCoverage = "unavailable",
    cellTimeCoverage = "unavailable",
  }
end

local function updateHeatmapTop10(record, cell)
  local top = record.top10
  if type(top) ~= "table" then
    top = buildHeatmapTop10(record.cells)
    record.top10 = top
    return
  end
  local kills = finite(record.cells[cell] and record.cells[cell].kills)
  local found
  for index = 1, #top do
    if top[index].cell == cell then found = index; break end
  end
  if found then
    if kills > 0 then
      top[found].count = kills
    else
      table.remove(top, found)
    end
  elseif kills > 0 then
    top[#top + 1] = { cell = cell, count = kills }
  end
  table.sort(top, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.cell < b.cell
  end)
  while #top > 10 do table.remove(top) end
end

function XPTooltip:UpdateModelHeatmapKill(mapID, cell, kills, total, lastSeen)
  local heatmaps = self:EnsureModelHeatmaps()
  if not heatmaps then return false end
  local id = tonumber(mapID)
  local index = tonumber(cell)
  if not id or not index then return false end
  local key = tostring(id)
  local record = heatmaps[key]
  if type(record) ~= "table" or type(record.cells) ~= "table" then
    return self:SyncModelHeatmapFromLegacy(id)
  end
  local count = finite(kills)
  if count > 0 then
    record.cells[index] = { kills = count }
  else
    record.cells[index] = nil
  end
  record.total = finite(total)
  record.lastSeen = finite(lastSeen)
  record.killsCoverage = "exact"
  record.cellXpCoverage = "unavailable"
  record.cellTimeCoverage = "unavailable"
  updateHeatmapTop10(record, index)
  return true
end

function XPTooltip:EnsureModelHeatmaps()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.heatmaps) ~= "table" then journey.heatmaps = {} end
  if journey.heatmapsMigrated and next(journey.heatmaps) ~= nil then
    return journey.heatmaps
  end
  local db = self.char or {}
  for key, entry in pairs(db.heatmaps or {}) do
    local mapID = tonumber(key)
    if mapID and type(entry) == "table" then
      local record = migrateLegacyHeatmap(entry, mapID)
      if record.total > 0 then
        journey.heatmaps[tostring(mapID)] = record
      end
    end
  end
  journey.heatmapsMigrated = true
  return journey.heatmaps
end

function XPTooltip:SyncModelHeatmapFromLegacy(mapID)
  local heatmaps = self:EnsureModelHeatmaps()
  if not heatmaps then return false end
  local db = self.char or {}
  local id = tonumber(mapID)
  local key = id and tostring(id) or tostring(mapID or "")
  local legacy = db.heatmaps
    and (db.heatmaps[key] or (id and db.heatmaps[id]) or nil)
  if type(legacy) ~= "table" or not id then
    if heatmaps[key] then heatmaps[key] = nil end
    return true
  end
  local record = migrateLegacyHeatmap(legacy, id)
  if record.total > 0 then
    heatmaps[key] = record
  else
    heatmaps[key] = nil
  end
  return true
end

function XPTooltip:SyncModelHeatmapsFromLegacy()
  local heatmaps = self:EnsureModelHeatmaps()
  if not heatmaps then return false end
  local db = self.char or {}
  local kept = {}
  for key, entry in pairs(db.heatmaps or {}) do
    local mapID = tonumber(key)
    if mapID and type(entry) == "table" then
      local record = migrateLegacyHeatmap(entry, mapID)
      local modelKey = tostring(mapID)
      if record.total > 0 then
        heatmaps[modelKey] = record
        kept[modelKey] = true
      end
    end
  end
  for key in pairs(heatmaps) do
    if not kept[key] then heatmaps[key] = nil end
  end
  local journey = self.char and self.char.journey
  if journey then journey.heatmapsMigrated = true end
  return true
end

function XPTooltip:GetModelHeatmap(mapID)
  local heatmaps = self:EnsureModelHeatmaps()
  local id = tonumber(mapID)
  local key = id and tostring(id) or tostring(mapID or "")
  local record = heatmaps and heatmaps[key]
  if type(record) ~= "table" then return nil, "missing" end
  local total = finite(record.total)
  local top10 = type(record.top10) == "table" and record.top10
    or buildHeatmapTop10(record.cells)
  local gridSize = finite(record.gridSize)
  if gridSize <= 0 then gridSize = XPTooltip.HEATMAP_GRID_SIZE or 64 end
  return {
    source = "v2",
    key = key,
    mapID = id or 0,
    gridSize = gridSize,
    cells = record.cells or {},
    total = total,
    top10 = top10,
    lastSeen = finite(record.lastSeen),
    killsCoverage = record.killsCoverage or "unknown",
    cellXpCoverage = record.cellXpCoverage or "unknown",
    cellTimeCoverage = record.cellTimeCoverage or "unknown",
  }
end

local function migrateLegacyQuest(entry)
  return {
    id = tonumber(entry.id) or 0,
    count = finite(entry.count),
    xp = finite(entry.totalXP),
    lastTurnInAt = finite(entry.lastTurnInAt),
    mapID = entry.mapID,
    playerLevel = entry.playerLevel,
    firstSeen = finite(entry.firstSeen),
    lastSeen = finite(entry.lastSeen),
  }
end

function XPTooltip:EnsureModelQuests()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.quests) ~= "table" then journey.quests = {} end
  if journey.questsMigrated then return journey.quests end
  local db = self.char or {}
  for key, quest in pairs(db.quests or {}) do
    if type(quest) == "table" and not journey.quests[key] then
      journey.quests[key] = migrateLegacyQuest(quest)
    end
  end
  journey.questsMigrated = true
  return journey.quests
end

function XPTooltip:SyncModelQuestFromLegacy(value)
  local key = questKey(value)
  local db = self.char or {}
  local quests = self:EnsureModelQuests()
  local legacy = db.quests and db.quests[key]
  if type(legacy) ~= "table" then
    if quests and quests[key] then quests[key] = nil; return true end
    return false
  end
  quests[key] = migrateLegacyQuest(legacy)
  return true
end

function XPTooltip:SyncModelQuestsFromLegacy()
  local quests = self:EnsureModelQuests()
  local db = self.char or {}
  for key in pairs(db.quests or {}) do
    self:SyncModelQuestFromLegacy(key)
  end
  if type(db.quests) == "table" then
    for key in pairs(quests) do
      if db.quests[key] == nil then quests[key] = nil end
    end
  end
  return true
end

local function respawnStats(entry)
  local samples, total, minimum, maximum = 0, 0, nil, nil
  for _, raw in ipairs(entry.intervals or {}) do
    local seconds = tonumber(raw)
    if seconds then
      samples = samples + 1
      total = total + seconds
      if not minimum or seconds < minimum then minimum = seconds end
      if not maximum or seconds > maximum then maximum = seconds end
    end
  end
  return samples, total, minimum, maximum
end

local function migrateLegacyRespawn(entry)
  local intervals = {}
  for _, raw in ipairs(entry.intervals or {}) do
    local seconds = tonumber(raw)
    if seconds then intervals[#intervals + 1] = seconds end
  end
  local samples, total, minimum, maximum = respawnStats({ intervals = intervals })
  return {
    name = entry.name,
    intervals = intervals,
    samples = samples,
    sum = total,
    min = minimum,
    max = maximum,
    lastSeen = finite(entry.lastSeen),
    lastDeath = finite(entry.lastDeath),
  }
end

function XPTooltip:EnsureModelRespawns()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.respawns) ~= "table" then journey.respawns = {} end
  if journey.respawnsMigrated then return journey.respawns end
  local db = self.char or {}
  for npcID, entry in pairs(db.respawns or {}) do
    if type(entry) == "table" then
      journey.respawns[tostring(npcID)] = migrateLegacyRespawn(entry)
    end
  end
  journey.respawnsMigrated = true
  return journey.respawns
end

function XPTooltip:SyncModelRespawnFromLegacy(npcID)
  local key = tostring(npcID or "")
  local respawns = self:EnsureModelRespawns()
  local db = self.char or {}
  local entry = db.respawns and (db.respawns[npcID] or db.respawns[key])
  if type(entry) ~= "table" then
    if respawns and respawns[key] then respawns[key] = nil; return true end
    return false
  end
  respawns[key] = migrateLegacyRespawn(entry)
  return true
end

function XPTooltip:SyncModelRespawnsFromLegacy()
  local respawns = self:EnsureModelRespawns()
  local db = self.char or {}
  for npcID in pairs(db.respawns or {}) do
    self:SyncModelRespawnFromLegacy(npcID)
  end
  if type(db.respawns) == "table" then
    for key in pairs(respawns) do
      if db.respawns[key] == nil and db.respawns[tonumber(key)] == nil then
        respawns[key] = nil
      end
    end
  end
  return true
end

function XPTooltip:GetModelQuest(value)
  local key = questKey(value)
  local quests = self:EnsureModelQuests()
  local record = quests and quests[key]
  if type(record) ~= "table" then return nil, "missing" end
  local db = self.char or {}
  local legacy = db.quests and db.quests[key]
  return {
    source = "v2",
    key = key,
    id = record.id,
    name = legacy and legacy.name or nil,
    count = finite(record.count),
    xp = finite(record.xp),
    lastTurnInAt = finite(record.lastTurnInAt),
    mapID = record.mapID,
    playerLevel = record.playerLevel,
    lastSeen = finite(record.lastSeen),
  }
end

local function migrateLegacyDeath(entry)
  return {
    at = finite(entry.at),
    mapID = finite(entry.mapID),
    x = tonumber(entry.x),
    y = tonumber(entry.y),
    attributionCoverage = "unavailable",
    healthCoverage = "unavailable",
    contextCoverage = "unavailable",
  }
end

function XPTooltip:EnsureModelDeaths()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  if type(journey.deaths) ~= "table" then journey.deaths = {} end
  if journey.deathsMigrated then return journey.deaths end
  local db = self.char or {}
  for index, entry in ipairs(db.deaths or {}) do
    if type(entry) == "table" then
      journey.deaths[index] = migrateLegacyDeath(entry)
    end
  end
  journey.deathsMigrated = true
  return journey.deaths
end

function XPTooltip:SyncModelDeathsFromLegacy()
  local journey = self:EnsureJourney()
  if not journey then return false end
  if type(self.NormalizeDeaths) == "function" then
    pcall(self.NormalizeDeaths, self)
  end
  local db = self.char or {}
  local deaths = {}
  for _, entry in ipairs(db.deaths or {}) do
    if type(entry) == "table" then
      deaths[#deaths + 1] = migrateLegacyDeath(entry)
    end
  end
  journey.deaths = deaths
  journey.deathsMigrated = true
  return true
end

function XPTooltip:GetModelDeath(index)
  local deaths = self:EnsureModelDeaths()
  local record = deaths and deaths[index]
  if type(record) ~= "table" then return nil, "missing" end
  return {
    source = "v2",
    index = index,
    at = finite(record.at),
    mapID = record.mapID,
    x = record.x,
    y = record.y,
    mobKey = record.mobKey,
    npcID = record.npcID,
    health = record.health,
    healthBand = record.healthBand,
    buffs = record.buffs,
    groupSize = record.groupSize,
    classification = record.classification,
    difficultyID = record.difficultyID,
    attributionCoverage = record.attributionCoverage,
    healthCoverage = record.healthCoverage,
    contextCoverage = record.contextCoverage,
  }
end

function XPTooltip:GetModelDeathList()
  local deaths = self:EnsureModelDeaths() or {}
  local list = {}
  for index = 1, #deaths do list[index] = deaths[index] end
  return list
end

function XPTooltip:GetModelRespawn(npcID)
  local respawns = self:EnsureModelRespawns()
  local key = tostring(npcID or "")
  local record = respawns and respawns[key]
  if type(record) ~= "table" then return nil, "missing" end
  local samples, total, minimum, maximum = respawnStats(record)
  return {
    source = "v2",
    npcID = tonumber(npcID) or 0,
    name = record.name,
    intervals = record.intervals,
    samples = samples,
    sum = total,
    min = minimum,
    max = maximum,
    lastSeen = finite(record.lastSeen),
    lastDeath = finite(record.lastDeath),
  }
end

XPTooltip.JourneyModelReady = true
