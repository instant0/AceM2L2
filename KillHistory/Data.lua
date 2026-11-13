--[[---------------------------------------------------------------------------------
  KillHistory/Data.lua
  Character database, mob identity, merge/deduplication, and entry accounting.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local min, max = math.min, math.max
local CALIBRATION_VERSION = Util.CALIBRATION_VERSION
local MAX_MOBS = Util.MAX_MOBS
local Lower = Util.Lower
local CopyTable = Util.CopyTable
local EnsureNumberMap = Util.EnsureNumberMap
local Epoch = Util.Epoch

local STORAGE_SCHEMA = 2
local CLIENT_DATA_SCHEMA = 1
local LEGACY_PROJECT_ID = (AceM2L2.Defaults and AceM2L2.Defaults.CAMELOT_PROJECT_ID)
  or WOW_PROJECT_CAMELOT or 18

local LEGACY_DATA_KEYS = {
  "schema", "mobs", "areas", "levels", "areaLevels", "totals",
  "session", "calibration", "calibrationVersion",
}

local function NewEmptyClientData()
  return {
    dataSchema = CLIENT_DATA_SCHEMA,
    mobs = {},
    areas = {},
    levels = {},
    areaLevels = {},
    calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} },
    calibrationVersion = CALIBRATION_VERSION,
    totals = { kills = 0, xp = 0, uniqueMobs = 0 },
    session = { startedAt = 0, kills = 0, xp = 0 },
    schemaBlocked = true,
  }
end

function XPTooltip:GetMigrationBackup()
  if type(AceM2L2CharDB) ~= "table" then
    return nil
  end
  local root = AceM2L2CharDB.xpTooltip
  if type(root) ~= "table" or type(root.migrationBackup) ~= "table" then
    return nil
  end
  return root.migrationBackup
end

function XPTooltip:HasMigrationBackup()
  return self:GetMigrationBackup() ~= nil
end

-- Move 1.11.x root-scoped Kill History data into clients[Forever] once.
-- The migration is idempotent and never merges root data into a non-empty
-- clients table. When it moves data, the root data keys are cleared.
function XPTooltip:MigrateDB()
  if type(AceM2L2CharDB) ~= "table" then
    AceM2L2CharDB = {}
  end
  local root = AceM2L2CharDB.xpTooltip
  if type(root) ~= "table" then
    root = {}
    AceM2L2CharDB.xpTooltip = root
  end

  local storageSchema = tonumber(root.storageSchema) or 0
  if storageSchema > STORAGE_SCHEMA then
    return root, true
  end

  if type(root.clients) ~= "table" or next(root.clients) == nil then
    local clients = type(root.clients) == "table" and root.clients or {}
    local legacy = nil
    for _, key in ipairs(LEGACY_DATA_KEYS) do
      if root[key] ~= nil then
        legacy = legacy or {}
        legacy[key] = root[key]
        root[key] = nil
      end
    end
    if legacy then
      local backupData
      if type(root.migrationBackup) ~= "table" then
        backupData = CopyTable(legacy)
      end
      legacy.dataSchema = CLIENT_DATA_SCHEMA
      clients[LEGACY_PROJECT_ID] = legacy
      if backupData then
        root.migrationBackup = {
          createdAt = Epoch(),
          storageSchema = storageSchema,
          data = backupData,
        }
      end
    end
    root.clients = clients
  end

  root.storageSchema = STORAGE_SCHEMA
  return root, false
end

function XPTooltip:EnsureDB()
  local root, storageBlocked = self:MigrateDB()
  local projectID = self:GetProjectID()
  if self.dataProjectID and self.dataProjectID ~= projectID then
    self:InvalidatePendingWork("client switch", true)
  end
  self.dataProjectID = projectID
  self.schemaBlocked = false
  self.schemaBlockedReason = nil

  if storageBlocked then
    self.schemaBlocked = true
    self.schemaBlockedReason = "storage schema newer than this build"
    self.char = NewEmptyClientData()
    self:InvalidatePendingWork("schema blocked", true)
    return self.char
  end

  local db = root.clients[projectID]
  if type(db) ~= "table" then
    db = {}
    root.clients[projectID] = db
  end

  local dataSchema = tonumber(db.dataSchema) or 0
  if dataSchema > CLIENT_DATA_SCHEMA then
    self.schemaBlocked = true
    self.schemaBlockedReason = "client data schema newer than this build"
    self.char = NewEmptyClientData()
    self:InvalidatePendingWork("schema blocked", true)
    return self.char
  end

  local calibrationVersion = tonumber(db.calibrationVersion) or 0
  if calibrationVersion > CALIBRATION_VERSION then
    self.schemaBlocked = true
    self.schemaBlockedReason = "calibration schema newer than this build"
    self.char = NewEmptyClientData()
    self:InvalidatePendingWork("schema blocked", true)
    return self.char
  end

  if dataSchema < CLIENT_DATA_SCHEMA then
    db.dataSchema = CLIENT_DATA_SCHEMA
  end
  db.mobs = EnsureNumberMap(db.mobs)
  db.areas = EnsureNumberMap(db.areas)
  db.levels = EnsureNumberMap(db.levels)
  db.areaLevels = EnsureNumberMap(db.areaLevels)

  -- 1.10.x and early 1.11.x could persist inflated multiplicative
  -- calibration ratios. Discard them once, keep observations and kill counts.
  if calibrationVersion < CALIBRATION_VERSION then
    db.calibration = {}
    db.calibrationVersion = CALIBRATION_VERSION
    -- Exact per-context snapshots from older calibration builds may be stale.
    -- Keep kills, but clear those observations on a version bump.
    for _, mob in pairs(db.mobs) do
      if type(mob) == "table" then
        mob.contexts = {}
      end
    end
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
  local mobCount = 0
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      mobCount = mobCount + 1
    end
  end
  db.totals.uniqueMobs = mobCount
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

local function SubtractMobBreakdown(db, mob)
  if type(db) ~= "table" or type(mob) ~= "table" then
    return
  end
  db.levels = EnsureNumberMap(db.levels)
  db.areas = EnsureNumberMap(db.areas)
  db.areaLevels = EnsureNumberMap(db.areaLevels)

  for levelKey, count in pairs(EnsureNumberMap(mob.killsAtLevel)) do
    db.levels[levelKey] = max(0, (tonumber(db.levels[levelKey]) or 0) - (tonumber(count) or 0))
  end
  for mapKey, count in pairs(EnsureNumberMap(mob.killsByMap)) do
    db.areas[mapKey] = max(0, (tonumber(db.areas[mapKey]) or 0) - (tonumber(count) or 0))
  end

  local joint = EnsureNumberMap(mob.killsByAreaLevel)
  local hasJoint = false
  for _, byLevel in pairs(joint) do
    if type(byLevel) == "table" then
      hasJoint = true
      break
    end
  end
  if hasJoint then
    for mapKey, byLevel in pairs(joint) do
      local areaLevels = db.areaLevels[mapKey]
      if type(areaLevels) == "table" then
        for levelKey, count in pairs(EnsureNumberMap(byLevel)) do
          areaLevels[levelKey] = max(0, (tonumber(areaLevels[levelKey]) or 0) - (tonumber(count) or 0))
        end
      end
    end
  else
    local mapKeys, levelKeys = {}, {}
    for mapKey in pairs(EnsureNumberMap(mob.killsByMap)) do
      mapKeys[#mapKeys + 1] = mapKey
    end
    for levelKey in pairs(EnsureNumberMap(mob.killsAtLevel)) do
      levelKeys[#levelKeys + 1] = levelKey
    end
    if #mapKeys == 1 then
      local areaLevels = db.areaLevels[mapKeys[1]]
      if type(areaLevels) == "table" then
        for levelKey, count in pairs(EnsureNumberMap(mob.killsAtLevel)) do
          areaLevels[levelKey] = max(0, (tonumber(areaLevels[levelKey]) or 0) - (tonumber(count) or 0))
        end
      end
    elseif #levelKeys == 1 then
      local levelKey = levelKeys[1]
      for mapKey, count in pairs(EnsureNumberMap(mob.killsByMap)) do
        local areaLevels = db.areaLevels[mapKey]
        if type(areaLevels) == "table" then
          areaLevels[levelKey] = max(0, (tonumber(areaLevels[levelKey]) or 0) - (tonumber(count) or 0))
        end
      end
    else
      -- Multi-map/multi-level legacy entries without joint data cannot be
      -- reconstructed. Leave areaLevels unchanged instead of inventing counts.
    end
  end
end

local function EffectiveTotalXP(mob)
  local value = tonumber(mob and mob.totalXP) or 0
  if value <= 0 and type(mob and mob.xp) == "table" then
    value = tonumber(mob.xp.sumTotal) or 0
  end
  return max(0, value)
end

local function PickCountWinner(from, to)
  local fromKills = max(0, tonumber(from.kills) or 0)
  local toKills = max(0, tonumber(to.kills) or 0)
  if fromKills ~= toKills then
    return fromKills > toKills and from or to
  end
  local fromSeen = tonumber(from.lastSeen) or 0
  local toSeen = tonumber(to.lastSeen) or 0
  if fromSeen ~= toSeen then
    return fromSeen > toSeen and from or to
  end
  return to
end

local function PickSampleSource(from, to)
  local fromXP = type(from.xp) == "table" and from.xp or {}
  local toXP = type(to.xp) == "table" and to.xp or {}
  local fromSamples = tonumber(fromXP.samples) or 0
  local toSamples = tonumber(toXP.samples) or 0
  if fromSamples ~= toSamples then
    return fromSamples > toSamples and from or to
  end
  local fromSum = tonumber(fromXP.sumTotal) or 0
  local toSum = tonumber(toXP.sumTotal) or 0
  if fromSum ~= toSum then
    return fromSum > toSum and from or to
  end
  local fromSeen = tonumber(from.lastSeen) or 0
  local toSeen = tonumber(to.lastSeen) or 0
  if fromSeen ~= toSeen then
    return fromSeen > toSeen and from or to
  end
  return to
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

  local fromFirst = tonumber(from.firstSeen) or 0
  local fromLast = tonumber(from.lastSeen) or 0
  local toFirst = tonumber(to.firstSeen) or 0
  local toLast = tonumber(to.lastSeen) or 0
  local dedupe = historical
    and fromFirst > 0 and toFirst > 0
    and fromFirst <= toLast and toFirst <= fromLast

  local calibration = db.calibration and db.calibration.mobs

  if dedupe then
    local fromKills = max(0, tonumber(from.kills) or 0)
    local toKills = max(0, tonumber(to.kills) or 0)
    local fromSessionKills = max(0, tonumber(from.sessionKills) or 0)
    local toSessionKills = max(0, tonumber(to.sessionKills) or 0)
    local fromTotalXP = EffectiveTotalXP(from)
    local toTotalXP = EffectiveTotalXP(to)
    local fromSessionXP = max(0, tonumber(from.sessionXP) or 0)
    local toSessionXP = max(0, tonumber(to.sessionXP) or 0)

    local mergedKills = max(fromKills, toKills)
    local mergedSessionKills = max(fromSessionKills, toSessionKills)
    local mergedTotalXP = max(fromTotalXP, toTotalXP)
    local mergedSessionXP = max(fromSessionXP, toSessionXP)

    local countWinner = PickCountWinner(from, to)
    local sampleSource = PickSampleSource(from, to)
    local countLoser = (countWinner == from) and to or from

    db.totals = type(db.totals) == "table" and db.totals or {}
    db.session = type(db.session) == "table" and db.session or {}
    db.totals.kills = max(0, (tonumber(db.totals.kills) or 0)
      - (fromKills + toKills - mergedKills))
    db.totals.xp = max(0, (tonumber(db.totals.xp) or 0)
      - (fromTotalXP + toTotalXP - mergedTotalXP))
    db.session.kills = max(0, (tonumber(db.session.kills) or 0)
      - (fromSessionKills + toSessionKills - mergedSessionKills))
    db.session.xp = max(0, (tonumber(db.session.xp) or 0)
      - (fromSessionXP + toSessionXP - mergedSessionXP))

    -- Counts, levels, areas, and joint counts come from the count winner.
    SubtractMobBreakdown(db, countLoser)
    if countWinner == from then
      to.kills = fromKills
      to.sessionKills = fromSessionKills
      to.killsAtLevel = CopyTable(EnsureNumberMap(from.killsAtLevel))
      to.killsByMap = CopyTable(EnsureNumberMap(from.killsByMap))
      to.killsByAreaLevel = CopyTable(EnsureNumberMap(from.killsByAreaLevel))
    else
      to.kills = toKills
      to.sessionKills = toSessionKills
    end

    to.totalXP = mergedTotalXP
    to.sessionXP = mergedSessionXP
    to.sessionXPKnown = from.sessionXPKnown == true or to.sessionXPKnown == true
      or mergedSessionXP > 0

    -- Observations come from the sample-rich entry.
    if sampleSource == from then
      to.contexts = CopyTable(EnsureNumberMap(from.contexts))
      to.xp = CopyTable(type(from.xp) == "table" and from.xp or {})
    else
      to.contexts = EnsureNumberMap(to.contexts)
      to.xp = type(to.xp) == "table" and to.xp or {}
    end
    if (tonumber(to.xp.sumTotal) or 0) <= 0 and to.totalXP > 0 then
      to.xp.sumTotal = to.totalXP
    end

    -- Calibration follows the sample source.
    if type(calibration) == "table" then
      if sampleSource == from and type(calibration[fromKey]) == "table" then
        calibration[toKey] = CopyTable(calibration[fromKey])
      end
      calibration[fromKey] = nil
    end

    if (not to.name or to.name == "" or to.name == "Unknown") and from.name then
      to.name = from.name
    end
    if not to.npcID then
      to.npcID = from.npcID or tonumber(tostring(toKey):match("^npc:(%d+)"))
    end
    if (not to.classification or to.classification == "normal")
      and from.classification and from.classification ~= "normal" then
      to.classification = from.classification
    end
    if fromFirst > 0 and (toFirst <= 0 or fromFirst < toFirst) then
      to.firstSeen = fromFirst
    end
    to.lastSeen = max(toLast, fromLast)
  else
    local fromLevels = EnsureNumberMap(from.killsAtLevel)
    local toLevels = EnsureNumberMap(to.killsAtLevel)
    local fromMaps = EnsureNumberMap(from.killsByMap)
    local toMaps = EnsureNumberMap(to.killsByMap)
    local fromJoint = EnsureNumberMap(from.killsByAreaLevel)
    local toJoint = EnsureNumberMap(to.killsByAreaLevel)
    from.killsAtLevel = fromLevels
    to.killsAtLevel = toLevels
    from.killsByMap = fromMaps
    to.killsByMap = toMaps
    from.killsByAreaLevel = fromJoint
    to.killsByAreaLevel = toJoint

    local fromTotalXP = EffectiveTotalXP(from)
    local toTotalXP = EffectiveTotalXP(to)
    local fromSessionXP = max(0, tonumber(from.sessionXP) or 0)
    local toSessionXP = max(0, tonumber(to.sessionXP) or 0)
    to.kills = (tonumber(to.kills) or 0) + (tonumber(from.kills) or 0)
    to.sessionKills = (tonumber(to.sessionKills) or 0) + (tonumber(from.sessionKills) or 0)
    to.totalXP = toTotalXP + fromTotalXP
    to.sessionXP = toSessionXP + fromSessionXP
    to.sessionXPKnown = to.sessionXPKnown == true or from.sessionXPKnown == true
      or toSessionXP > 0 or fromSessionXP > 0

    for levelKey, value in pairs(fromLevels) do
      toLevels[levelKey] = (tonumber(toLevels[levelKey]) or 0) + (tonumber(value) or 0)
    end
    for mapKey, value in pairs(fromMaps) do
      toMaps[mapKey] = (tonumber(toMaps[mapKey]) or 0) + (tonumber(value) or 0)
    end
    for mapKey, byLevel in pairs(fromJoint) do
      if type(byLevel) == "table" then
        local targetByLevel = toJoint[mapKey]
        if type(targetByLevel) ~= "table" then
          targetByLevel = {}
          toJoint[mapKey] = targetByLevel
        end
        for levelKey, value in pairs(byLevel) do
          targetByLevel[levelKey] = (tonumber(targetByLevel[levelKey]) or 0) + (tonumber(value) or 0)
        end
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
    if (tonumber(to.xp.sumTotal) or 0) <= 0 and to.totalXP > 0 then
      to.xp.sumTotal = to.totalXP
    end

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

    if (not to.name or to.name == "" or to.name == "Unknown") and from.name then
      to.name = from.name
    end
    to.npcID = to.npcID or from.npcID or tonumber(tostring(toKey):match("^npc:(%d+)"))
    if (not to.classification or to.classification == "normal")
      and from.classification and from.classification ~= "normal" then
      to.classification = from.classification
    end
    if fromFirst > 0 and (toFirst <= 0 or fromFirst < toFirst) then
      to.firstSeen = fromFirst
    end
    to.lastSeen = max(toLast, fromLast)
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
      totalXP = 0,
      sessionXP = 0,
      sessionXPKnown = false,
      killsAtLevel = {},
      killsByMap = {},
      killsByAreaLevel = {},
      contexts = {},
      xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 },
    }
    db.mobs[mobKey] = mob
    db.totals.uniqueMobs = (db.totals.uniqueMobs or 0) + 1
    if db.totals.uniqueMobs > MAX_MOBS then
      self:SchedulePrune()
    end
  else
    if npcID then
      mob.npcID = npcID
    end
    if name and name ~= "" and name ~= "Unknown" then
      if not mob.name or mob.name == "" or mob.name == "Unknown" then
        mob.name = name
      end
    end
    if classification and classification ~= "normal" then
      mob.classification = classification
    elseif not mob.classification then
      mob.classification = classification or "normal"
    end
    mob.killsAtLevel = EnsureNumberMap(mob.killsAtLevel)
    mob.killsByMap = EnsureNumberMap(mob.killsByMap)
    mob.killsByAreaLevel = EnsureNumberMap(mob.killsByAreaLevel)
    mob.contexts = EnsureNumberMap(mob.contexts)
    mob.totalXP = tonumber(mob.totalXP) or 0
    mob.sessionXP = tonumber(mob.sessionXP) or 0
    mob.sessionXPKnown = mob.sessionXPKnown == true
    mob.firstSeen = mob.firstSeen or Epoch()
  end
  return mob
end

function XPTooltip:SubtractMobAccounting(db, mob)
  if type(db) ~= "table" or type(mob) ~= "table" then
    return
  end
  db.totals = type(db.totals) == "table" and db.totals or {}
  db.session = type(db.session) == "table" and db.session or {}

  local kills = max(0, tonumber(mob.kills) or 0)
  local sessionKills = max(0, tonumber(mob.sessionKills) or 0)
  local mobXP = EffectiveTotalXP(mob)
  -- Never invent session XP from lifetime totals. A zero session total is a
  -- valid known-zero; unknown legacy session XP contributes nothing here.
  local sessionXP = max(0, tonumber(mob.sessionXP) or 0)

  db.totals.kills = max(0, (tonumber(db.totals.kills) or 0) - kills)
  db.totals.xp = max(0, (tonumber(db.totals.xp) or 0) - mobXP)
  db.session.kills = max(0, (tonumber(db.session.kills) or 0) - sessionKills)
  db.session.xp = max(0, (tonumber(db.session.xp) or 0) - sessionXP)

  SubtractMobBreakdown(db, mob)
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
  self:SubtractMobAccounting(db, mob)

  db.mobs[mobKey] = nil
  if type(db.calibration) == "table" and type(db.calibration.mobs) == "table" then
    -- Only the mob-specific calibration entry is retracted. Aggregate
    -- zone/level/class ratios learned from other observations are retained;
    -- deleting one mob does not invalidate them.
    db.calibration.mobs[mobKey] = nil
  end
  db.totals.uniqueMobs = max(0, (tonumber(db.totals.uniqueMobs) or 1) - 1)

  if not deferRefresh then
    self:RefreshAfterMobDelete()
  end
  return name, kills
end
