--[[---------------------------------------------------------------------------------
  KillHistory/Data.lua
  Character database, mob identity, merge/deduplication, and entry accounting.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local floor, min, max = math.floor, math.min, math.max
local CALIBRATION_VERSION = Util.CALIBRATION_VERSION
local Lower = Util.Lower
local CopyTable = Util.CopyTable
local EnsureNumberMap = Util.EnsureNumberMap
local Epoch = Util.Epoch

function XPTooltip:EnsureDB()
  if type(AceM2L2CharDB) ~= "table" then
    AceM2L2CharDB = {}
  end
  local db = AceM2L2CharDB.xpTooltip
  if type(db) ~= "table" then
    db = {}
    AceM2L2CharDB.xpTooltip = db
  end

  db.schema = 1
  db.mobs = EnsureNumberMap(db.mobs)
  db.areas = EnsureNumberMap(db.areas)
  db.levels = EnsureNumberMap(db.levels)
  db.areaLevels = EnsureNumberMap(db.areaLevels)

  -- 1.10.x and early 1.11.x could persist inflated multiplicative
  -- calibration ratios. Discard them once, keep observations and kill counts.
  if tonumber(db.calibrationVersion) ~= CALIBRATION_VERSION then
    db.calibration = {}
    db.calibrationVersion = CALIBRATION_VERSION
  end

  db.calibration = type(db.calibration) == "table" and db.calibration or {}
  db.calibration.zones = EnsureNumberMap(db.calibration.zones)
  db.calibration.levels = EnsureNumberMap(db.calibration.levels)
  db.calibration.groups = EnsureNumberMap(db.calibration.groups)
  db.calibration.classes = EnsureNumberMap(db.calibration.classes)
  db.calibration.mobs = EnsureNumberMap(db.calibration.mobs)
  db.totals = type(db.totals) == "table" and db.totals or {}
  db.totals.kills = tonumber(db.totals.kills) or 0
  db.totals.xp = tonumber(db.totals.xp) or 0
  db.totals.uniqueMobs = tonumber(db.totals.uniqueMobs) or 0
  db.session = type(db.session) == "table" and db.session or {}
  db.session.startedAt = tonumber(db.session.startedAt) or 0
  db.session.kills = tonumber(db.session.kills) or 0
  db.session.xp = tonumber(db.session.xp) or 0

  self.char = db
  self:ConsolidateNameOnlyMobs()
  return db
end

function XPTooltip:FindNPCKeyByName(name)
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return nil
  end
  local lower = Lower(name)
  if not lower then
    return nil
  end
  local match, count
  for key, mob in pairs(db.mobs) do
    if type(key) == "string" and key:sub(1, 4) == "npc:"
      and type(mob) == "table" and Lower(mob.name) == lower then
      match = key
      count = (count or 0) + 1
      if count > 1 then
        return nil
      end
    end
  end
  return match
end

function XPTooltip:GetMobKey(name, npcID)
  if npcID then
    return "npc:" .. tostring(npcID)
  end
  local known = self:FindNPCKeyByName(name)
  if known then
    return known
  end
  local lower = Lower(name) or "unknown"
  return "name:" .. lower
end

function XPTooltip:MergeMobEntries(fromKey, toKey, historical)
  if not fromKey or not toKey or fromKey == toKey then
    return false
  end
  if type(fromKey) ~= "string" or fromKey:sub(1, 5) ~= "name:" then
    return false
  end
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return false
  end
  local from = db.mobs[fromKey]
  if type(from) ~= "table" then
    return false
  end

  local to = db.mobs[toKey]
  if type(to) ~= "table" then
    -- Promote the unresolved name-only entry to the NPC key.
    db.mobs[fromKey] = nil
    from.npcID = from.npcID or tonumber(tostring(toKey):match("^npc:(%d+)"))
    db.mobs[toKey] = from
    local calibration = db.calibration and db.calibration.mobs
    if type(calibration) == "table" and type(calibration[fromKey]) == "table" then
      calibration[toKey] = calibration[toKey] or calibration[fromKey]
      calibration[fromKey] = nil
    end
    return true
  end

  local fromLevels = EnsureNumberMap(from.killsAtLevel)
  local toLevels = EnsureNumberMap(to.killsAtLevel)
  local fromMaps = EnsureNumberMap(from.killsByMap)
  local toMaps = EnsureNumberMap(to.killsByMap)

  -- Older versions could record the same kill twice: once from XP chat under a
  -- name-only key, then again from UNIT_DIED under the NPC key with no XP. If
  -- their active ranges overlap, take the larger count and treat the overlap as
  -- duplicate events. Disjoint ranges are genuinely additive.
  local dedupe = false
  if historical then
    local fromFirst = tonumber(from.firstSeen) or 0
    local fromLast = tonumber(from.lastSeen) or 0
    local toFirst = tonumber(to.firstSeen) or 0
    local toLast = tonumber(to.lastSeen) or 0
    if fromFirst > 0 and toFirst > 0 and fromFirst <= toLast and toFirst <= fromLast then
      dedupe = true
    end
  end

  local fromKills = tonumber(from.kills) or 0
  local toKills = tonumber(to.kills) or 0
  local fromSession = tonumber(from.sessionKills) or 0
  local toSession = tonumber(to.sessionKills) or 0
  local duplicateKills, duplicateSessionKills = 0, 0
  if dedupe then
    to.kills = max(fromKills, toKills)
    to.sessionKills = max(fromSession, toSession)
    duplicateKills = fromKills + toKills - to.kills
    duplicateSessionKills = fromSession + toSession - to.sessionKills
  else
    to.kills = fromKills + toKills
    to.sessionKills = fromSession + toSession
  end

  local levelDuplicates, mapDuplicates = {}, {}
  if dedupe then
    for levelKey, value in pairs(fromLevels) do
      local overlap = min(tonumber(value) or 0, tonumber(toLevels[levelKey]) or 0)
      if overlap > 0 then
        levelDuplicates[levelKey] = overlap
      end
    end
    for mapKey, value in pairs(fromMaps) do
      local overlap = min(tonumber(value) or 0, tonumber(toMaps[mapKey]) or 0)
      if overlap > 0 then
        mapDuplicates[mapKey] = overlap
      end
    end
  end

  to.name = to.name or from.name
  to.npcID = to.npcID or from.npcID or tonumber(tostring(toKey):match("^npc:(%d+)"))
  if (not to.classification or to.classification == "normal")
    and from.classification and from.classification ~= "normal" then
    to.classification = from.classification
  end
  local fromFirst, toFirst = tonumber(from.firstSeen), tonumber(to.firstSeen)
  if fromFirst and (not toFirst or fromFirst < toFirst) then
    to.firstSeen = fromFirst
  end
  to.lastSeen = max(tonumber(to.lastSeen) or 0, tonumber(from.lastSeen) or 0)

  for levelKey, value in pairs(fromLevels) do
    local current = tonumber(toLevels[levelKey]) or 0
    local addition = tonumber(value) or 0
    if dedupe then
      toLevels[levelKey] = max(current, addition)
    else
      toLevels[levelKey] = current + addition
    end
  end
  for mapKey, value in pairs(fromMaps) do
    local current = tonumber(toMaps[mapKey]) or 0
    local addition = tonumber(value) or 0
    if dedupe then
      toMaps[mapKey] = max(current, addition)
    else
      toMaps[mapKey] = current + addition
    end
  end

  to.contexts = EnsureNumberMap(to.contexts)
  for contextKey, source in pairs(EnsureNumberMap(from.contexts)) do
    if type(source) == "table" then
      local target = to.contexts[contextKey]
      if type(target) ~= "table" then
        to.contexts[contextKey] = CopyTable(source)
      else
        target.samples = (tonumber(target.samples) or 0) + (tonumber(source.samples) or 0)
        target.sumBase = (tonumber(target.sumBase) or 0) + (tonumber(source.sumBase) or 0)
        target.sumBuffed = (tonumber(target.sumBuffed) or 0) + (tonumber(source.sumBuffed) or 0)
        target.sumTotal = (tonumber(target.sumTotal) or 0) + (tonumber(source.sumTotal) or 0)
        target.lastSeen = max(tonumber(target.lastSeen) or 0, tonumber(source.lastSeen) or 0)
        local sourceMin = tonumber(source.minBase) or 0
        local targetMin = tonumber(target.minBase) or 0
        if sourceMin > 0 and (targetMin == 0 or sourceMin < targetMin) then
          target.minBase = sourceMin
        end
        target.maxBase = max(tonumber(target.maxBase) or 0, tonumber(source.maxBase) or 0)
      end
    end
  end

  to.xp = type(to.xp) == "table" and to.xp or {}
  local fromXP = type(from.xp) == "table" and from.xp or {}
  to.xp.samples = (tonumber(to.xp.samples) or 0) + (tonumber(fromXP.samples) or 0)
  to.xp.sumBase = (tonumber(to.xp.sumBase) or 0) + (tonumber(fromXP.sumBase) or 0)
  to.xp.sumBuffed = (tonumber(to.xp.sumBuffed) or 0) + (tonumber(fromXP.sumBuffed) or 0)
  to.xp.sumTotal = (tonumber(to.xp.sumTotal) or 0) + (tonumber(fromXP.sumTotal) or 0)
  local fromMin = tonumber(fromXP.minBase) or 0
  local toMin = tonumber(to.xp.minBase) or 0
  if fromMin > 0 and (toMin == 0 or fromMin < toMin) then
    to.xp.minBase = fromMin
  end
  to.xp.maxBase = max(tonumber(to.xp.maxBase) or 0, tonumber(fromXP.maxBase) or 0)
  if (tonumber(to.xp.lastBase) or 0) == 0 then
    to.xp.lastBase = tonumber(fromXP.lastBase) or 0
  end
  if (tonumber(to.xp.lastTotal) or 0) == 0 then
    to.xp.lastTotal = tonumber(fromXP.lastTotal) or 0
  end

  local calibration = db.calibration and db.calibration.mobs
  if type(calibration) == "table" then
    local source = calibration[fromKey]
    local target = calibration[toKey]
    if type(source) == "table" then
      if type(target) ~= "table" then
        calibration[toKey] = source
      else
        local sourceSamples = tonumber(source.samples) or 0
        local targetSamples = tonumber(target.samples) or 0
        local totalSamples = sourceSamples + targetSamples
        if totalSamples > 0 then
          target.ratio = ((tonumber(target.ratio) or 1) * targetSamples
            + (tonumber(source.ratio) or 1) * sourceSamples) / totalSamples
        end
        target.samples = totalSamples
        target.updated = max(tonumber(target.updated) or 0, tonumber(source.updated) or 0)
      end
      calibration[fromKey] = nil
    end
  end

  if dedupe then
    db.totals = type(db.totals) == "table" and db.totals or {}
    db.session = type(db.session) == "table" and db.session or {}
    db.levels = EnsureNumberMap(db.levels)
    db.areas = EnsureNumberMap(db.areas)
    db.totals.kills = max(0, (tonumber(db.totals.kills) or 0) - duplicateKills)
    db.session.kills = max(0, (tonumber(db.session.kills) or 0) - duplicateSessionKills)
    for levelKey, overlap in pairs(levelDuplicates) do
      db.levels[levelKey] = max(0, (tonumber(db.levels[levelKey]) or 0) - overlap)
    end
    for mapKey, overlap in pairs(mapDuplicates) do
      db.areas[mapKey] = max(0, (tonumber(db.areas[mapKey]) or 0) - overlap)
    end
  end

  db.mobs[fromKey] = nil
  db.totals.uniqueMobs = max(0, (tonumber(db.totals.uniqueMobs) or 1) - 1)
  return true
end

function XPTooltip:ConsolidateNameOnlyMobs()
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return 0
  end
  local npcByName = {}
  for key, mob in pairs(db.mobs) do
    if type(key) == "string" and key:sub(1, 4) == "npc:" and type(mob) == "table" then
      local lower = Lower(mob.name)
      if lower then
        local matches = npcByName[lower]
        if not matches then
          matches = {}
          npcByName[lower] = matches
        end
        matches[#matches + 1] = key
      end
    end
  end

  local merges = {}
  for key, mob in pairs(db.mobs) do
    if type(key) == "string" and key:sub(1, 5) == "name:" and type(mob) == "table" then
      local lower = Lower(mob.name) or key:sub(6)
      local matches = npcByName[lower]
      if matches and #matches == 1 then
        merges[#merges + 1] = { from = key, to = matches[1] }
      end
    end
  end

  local merged = 0
  for _, pair in ipairs(merges) do
    if db.mobs[pair.from] and db.mobs[pair.to] then
      if self:MergeMobEntries(pair.from, pair.to, true) then
        merged = merged + 1
      end
    end
  end
  return merged
end

function XPTooltip:EnsureMob(mobKey, name, npcID, classification)
  local db = self.char
  local mob = db.mobs[mobKey]
  if type(mob) ~= "table" then
    mob = {
      npcID = npcID,
      name = name or "Unknown",
      classification = classification or "normal",
      firstSeen = Epoch(),
      lastSeen = 0,
      kills = 0,
      sessionKills = 0,
      killsAtLevel = {},
      killsByMap = {},
      contexts = {},
      xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 },
    }
    db.mobs[mobKey] = mob
    db.totals.uniqueMobs = (db.totals.uniqueMobs or 0) + 1
  else
    if npcID then
      mob.npcID = npcID
    end
    if name then
      mob.name = name
    end
    if classification then
      mob.classification = classification
    end
    mob.killsAtLevel = EnsureNumberMap(mob.killsAtLevel)
    mob.killsByMap = EnsureNumberMap(mob.killsByMap)
    mob.contexts = EnsureNumberMap(mob.contexts)
    mob.firstSeen = mob.firstSeen or Epoch()
  end
  return mob
end

function XPTooltip:RemoveMobEntry(mobKey, deferRefresh)
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return nil
  end
  local mob = db.mobs[mobKey]
  if type(mob) ~= "table" then
    return nil
  end

  local name = tostring(mob.name or mobKey)
  local kills = tonumber(mob.kills) or 0
  local sessionKills = tonumber(mob.sessionKills) or 0
  local mobXP = type(mob.xp) == "table" and (tonumber(mob.xp.sumTotal) or 0) or 0

  db.totals = type(db.totals) == "table" and db.totals or {}
  db.session = type(db.session) == "table" and db.session or {}
  db.levels = EnsureNumberMap(db.levels)
  db.areas = EnsureNumberMap(db.areas)

  db.totals.kills = max(0, (tonumber(db.totals.kills) or 0) - kills)
  db.totals.xp = max(0, (tonumber(db.totals.xp) or 0) - mobXP)
  local totalSessionKills = tonumber(db.session.kills) or 0
  db.session.kills = max(0, totalSessionKills - min(sessionKills, totalSessionKills))
  if sessionKills >= kills and kills > 0 then
    db.session.xp = max(0, (tonumber(db.session.xp) or 0) - mobXP)
  end

  for levelKey, count in pairs(EnsureNumberMap(mob.killsAtLevel)) do
    db.levels[levelKey] = max(0, (tonumber(db.levels[levelKey]) or 0) - (tonumber(count) or 0))
  end
  for mapKey, count in pairs(EnsureNumberMap(mob.killsByMap)) do
    db.areas[mapKey] = max(0, (tonumber(db.areas[mapKey]) or 0) - (tonumber(count) or 0))
  end

  db.totals.uniqueMobs = max(0, (tonumber(db.totals.uniqueMobs) or 1) - 1)
  db.mobs[mobKey] = nil
  if type(db.calibration) == "table" and type(db.calibration.mobs) == "table" then
    db.calibration.mobs[mobKey] = nil
  end

  if not deferRefresh then
    self:RefreshAfterMobDelete()
  end
  return name, kills
end
