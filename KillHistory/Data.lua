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
local SafeCall = Util.SafeCall
local SafeNumber = Util.SafeNumber
local SafeString = Util.SafeString

local STORAGE_SCHEMA = 2
local CLIENT_DATA_SCHEMA = 1
local MAX_QUESTS = 200
local MAX_LEVEL_RECORDS = 200
local MAX_RATE_SAMPLES = 240
XPTooltip.MAX_QUESTS = MAX_QUESTS
XPTooltip.MAX_LEVEL_RECORDS = MAX_LEVEL_RECORDS
XPTooltip.MAX_RATE_SAMPLES = MAX_RATE_SAMPLES
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
    quests = {},
    levelHistory = {},
    rates = {},
    deaths = {},
    respawns = {},
    heatmaps = {},
    areas = {},
    levels = {},
    areaLevels = {},
    calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} },
    calibrationVersion = CALIBRATION_VERSION,
    totals = { kills = 0, xp = 0, uniqueMobs = 0 },
    session = { startedAt = 0, kills = 0, xp = 0 },
    dungeon = { xp = 0, kills = 0, sessionXP = 0, sessionKills = 0, lastInstance = 0 },
    goal = { targetLevel = 0, targetXP = 0, createdAt = 0 },
    economy = {
      lootValue = 0,
      sessionLootValue = 0,
      items = 0,
      sessionItems = 0,
      goldStart = 0,
      goldGained = 0,
      goldSpent = 0,
      lastMoney = 0,
      moneyKnown = false,
    },
    schemaBlocked = true,
  }
end

-- Reject non-finite stored numbers (NaN and both infinities) before clamping.
-- A malformed SavedVariables value must never poison totals or spread through
-- later arithmetic.
local function NonNegativeFinite(value)
  local number = tonumber(value)
  if not number or number ~= number or number == math.huge or number == -math.huge then
    return 0
  end
  return max(0, number)
end

-- Dungeon totals are a self-contained bucket. Rebuild only the five supported
-- fields so stale or unknown keys never survive a load. Counters and the last
-- instance map are finite and non-negative.
local function NormalizeDungeon(value)
  local source = type(value) == "table" and value or {}
  return {
    xp = NonNegativeFinite(source.xp),
    kills = NonNegativeFinite(source.kills),
    sessionXP = NonNegativeFinite(source.sessionXP),
    sessionKills = NonNegativeFinite(source.sessionKills),
    lastInstance = NonNegativeFinite(source.lastInstance),
  }
end

-- Economy totals are a self-contained bucket too. Rebuild only the nine
-- supported fields so stale or unknown keys never survive a load. Counters are
-- finite, non-negative whole numbers; moneyKnown stays a strict boolean.
local function NormalizeEconomy(value)
  local source = type(value) == "table" and value or {}
  return {
    lootValue = math.floor(NonNegativeFinite(source.lootValue)),
    sessionLootValue = math.floor(NonNegativeFinite(source.sessionLootValue)),
    items = math.floor(NonNegativeFinite(source.items)),
    sessionItems = math.floor(NonNegativeFinite(source.sessionItems)),
    goldStart = math.floor(NonNegativeFinite(source.goldStart)),
    goldGained = math.floor(NonNegativeFinite(source.goldGained)),
    goldSpent = math.floor(NonNegativeFinite(source.goldSpent)),
    lastMoney = math.floor(NonNegativeFinite(source.lastMoney)),
    moneyKnown = source.moneyKnown == true,
  }
end

-- Overwrite a bucket with a normalized snapshot while preserving the table
-- identity. Callers and UI code can hold a reference to dungeon/economy across
-- a normalization pass without observing stale values.
local function ReplaceTableContents(target, normalized)
  for key in pairs(target) do
    if normalized[key] == nil then
      target[key] = nil
    end
  end
  for key, value in pairs(normalized) do
    target[key] = value
  end
  return target
end

local function NormalizeDungeonInPlace(db)
  if type(db) ~= "table" then
    return nil
  end
  local existing = type(db.dungeon) == "table" and db.dungeon or {}
  db.dungeon = ReplaceTableContents(existing, NormalizeDungeon(existing))
  return db.dungeon
end

local function NormalizeEconomyInPlace(db)
  if type(db) ~= "table" then
    return nil
  end
  local existing = type(db.economy) == "table" and db.economy or {}
  db.economy = ReplaceTableContents(existing, NormalizeEconomy(existing))
  return db.economy
end

-- Keep rate samples as a time-ordered list of numeric observations. Source is
-- optional; map/level default to 0 when unavailable.
local function NormalizeRateList(list)
  local normalized = {}
  if type(list) ~= "table" then
    return normalized
  end
  for _, entry in ipairs(list) do
    if type(entry) == "table" then
      local at = tonumber(entry.at)
      local xp = tonumber(entry.xp)
      if at and xp and at > 0 and xp > 0 then
        normalized[#normalized + 1] = {
          at = at,
          xp = xp,
          source = type(entry.source) == "string" and entry.source or nil,
          mapID = tonumber(entry.mapID) or 0,
          level = tonumber(entry.level) or 0,
        }
      end
    end
  end
  table.sort(normalized, function(a, b)
    return a.at < b.at
  end)
  if #normalized > MAX_RATE_SAMPLES then
    local newest = {}
    for index = #normalized - MAX_RATE_SAMPLES + 1, #normalized do
      newest[#newest + 1] = normalized[index]
    end
    normalized = newest
  end
  return normalized
end

-- Clamp the shared accounting buckets in place. Totals and session accept only
-- finite, non-negative values; quest counters and timestamps follow the same
-- rule so malformed saved data cannot reach derived displays.
local function NormalizeAccounting(db)
  if type(db) ~= "table" then
    return
  end

  db.totals = type(db.totals) == "table" and db.totals or {}
  db.totals.kills = NonNegativeFinite(db.totals.kills)
  db.totals.xp = NonNegativeFinite(db.totals.xp)
  db.totals.uniqueMobs = NonNegativeFinite(db.totals.uniqueMobs)

  db.session = type(db.session) == "table" and db.session or {}
  db.session.startedAt = NonNegativeFinite(db.session.startedAt)
  db.session.kills = NonNegativeFinite(db.session.kills)
  db.session.xp = NonNegativeFinite(db.session.xp)

  db.quests = EnsureNumberMap(db.quests)
  for _, quest in pairs(db.quests) do
    if type(quest) == "table" then
      quest.count = NonNegativeFinite(quest.count)
      quest.totalXP = NonNegativeFinite(quest.totalXP)
      quest.lastXP = NonNegativeFinite(quest.lastXP)
      quest.firstSeen = NonNegativeFinite(quest.firstSeen)
      quest.lastSeen = NonNegativeFinite(quest.lastSeen)
    end
  end
end

-- Public normalization entry points for the active character. Each mutates the
-- corresponding client bucket in place and returns the normalized result.
function XPTooltip:NormalizeDungeon()
  return NormalizeDungeonInPlace(self.char)
end

function XPTooltip:NormalizeEconomy()
  return NormalizeEconomyInPlace(self.char)
end

function XPTooltip:NormalizeAccounting()
  local db = self.char
  if type(db) ~= "table" then
    return nil
  end
  NormalizeAccounting(db)
  return db
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

-- Copy source keys that are not already present in target. Existing backup
-- values win, but nested tables are merged so later stranded keys are retained.
local function MergeTableInto(target, source)
  for key, value in pairs(source) do
    if target[key] == nil then
      target[key] = type(value) == "table" and CopyTable(value) or value
    elseif type(target[key]) == "table" and type(value) == "table" then
      MergeTableInto(target[key], value)
    end
  end
end

local function EnsureMigrationBackup(root, storageSchema)
  local backup = type(root.migrationBackup) == "table" and root.migrationBackup or nil
  if not backup then
    backup = {
      createdAt = Epoch(),
      storageSchema = storageSchema,
      data = {},
    }
    root.migrationBackup = backup
  end
  if type(backup.data) ~= "table" then
    backup.data = {}
  end
  return backup
end

-- Move 1.11.x root-scoped Kill Story data into clients[Forever] once.
-- The migration is idempotent. Root data is only merged into the Forever client
-- when no per-client data exists. If any client data is already present, root
-- data is never merged into it: the migration keeps/merges a recoverable backup,
-- flags the stranded keys, and clears them so the branch is not retried.
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

  local legacy
  for _, key in ipairs(LEGACY_DATA_KEYS) do
    if root[key] ~= nil then
      legacy = legacy or {}
      legacy[key] = root[key]
    end
  end

  local clients = type(root.clients) == "table" and root.clients or nil
  local hasClientData = clients ~= nil and next(clients) ~= nil

  if legacy then
    local backup = EnsureMigrationBackup(root, storageSchema)
    -- Snapshot before the migrated payload is stamped with dataSchema.
    MergeTableInto(backup.data, legacy)

    if hasClientData then
      -- Populated clients are authoritative. Record why the root data could not
      -- be migrated, but leave every client table untouched.
      backup.stranded = true
      if type(backup.strandedKeys) ~= "table" then
        backup.strandedKeys = {}
      end
      for key in pairs(legacy) do
        backup.strandedKeys[key] = true
      end
      backup.strandedAt = Epoch()
      backup.strandedStorageSchema = storageSchema
    else
      clients = clients or {}
      legacy.dataSchema = CLIENT_DATA_SCHEMA
      clients[LEGACY_PROJECT_ID] = legacy
      root.clients = clients
    end

    for _, key in ipairs(LEGACY_DATA_KEYS) do
      root[key] = nil
    end
  end

  if type(root.clients) ~= "table" then
    root.clients = {}
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
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      self:NormalizeMobFields(mob)
    end
  end
  db.quests = EnsureNumberMap(db.quests)
  db.areas = EnsureNumberMap(db.areas)
  db.levels = EnsureNumberMap(db.levels)
  db.areaLevels = EnsureNumberMap(db.areaLevels)
  db.rates = NormalizeRateList(db.rates)
  db.deaths = type(db.deaths) == "table" and db.deaths or {}
  db.respawns = type(db.respawns) == "table" and db.respawns or {}
  db.heatmaps = type(db.heatmaps) == "table" and db.heatmaps or {}

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

  self.char = db
  -- Accounting, world, and goal buckets are normalized once the active
  -- character is in place.
  self:NormalizeAccounting()
  self:NormalizeDungeon()
  db.goal = self:NormalizeGoal(db.goal)
  self:NormalizeEconomy()
  -- Level history uses self.char, so normalize it exactly once here.
  self:NormalizeLevelHistory()
  -- World.lua loads after Data.lua and owns death/respawn normalization; both
  -- operate on self.char, so run them once the active character is in place.
  if type(self.NormalizeDeaths) == "function" then
    self:NormalizeDeaths()
  end
  if type(self.NormalizeRespawns) == "function" then
    self:NormalizeRespawns()
  end
  -- Heatmap.lua loads after Data.lua and normalizes the per-zone kill grid once
  -- the active character is assigned.
  if type(self.NormalizeHeatmaps) == "function" then
    self:NormalizeHeatmaps(db)
  end
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

function XPTooltip:NormalizeRates()
  local db = self.char
  if not db then
    return {}
  end
  db.rates = NormalizeRateList(db.rates)
  return db.rates
end

function XPTooltip:ResetRates()
  if self.char then
    self.char.rates = {}
    return self.char.rates
  end
  return {}
end

function XPTooltip:RecordRateSample(xp, source)
  if not self:Supports("hasPerMobXP") then
    return false
  end
  local value = tonumber(xp)
  if not value or value <= 0 then
    return false
  end
  local db = self.char
  if not db then
    return false
  end
  if type(db.rates) ~= "table" then
    db.rates = {}
  end
  db.rates[#db.rates + 1] = {
    at = Epoch(),
    xp = value,
    source = type(source) == "string" and source or nil,
    mapID = self:GetMapID() or 0,
    level = self:GetPlayerLevel() or 0,
  }
  db.rates = NormalizeRateList(db.rates)
  return true
end

-- Route XP earned inside an instance into the dedicated dungeon bucket. This
-- is separate from totals/session/mob accounting.
function XPTooltip:RecordDungeonXP(xp)
  if not self:Supports("hasPerMobXP") then
    return false
  end
  local value = tonumber(xp)
  if not value or value <= 0 then
    return false
  end
  local db = self.char
  if not db then
    return false
  end
  if not self:IsInDungeon() then
    return false
  end
  NormalizeDungeonInPlace(db)
  db.dungeon.xp = db.dungeon.xp + value
  db.dungeon.sessionXP = db.dungeon.sessionXP + value
  return true
end

-- The leveling goal keeps only the three supported fields. targetLevel is a
-- whole level clamped to 0..max; a zero target clears the whole goal.
function XPTooltip:NormalizeGoal(value)
  local source = type(value) == "table" and value or {}
  local targetLevel = math.floor(NonNegativeFinite(source.targetLevel))
  local maxLevel = NonNegativeFinite(self:GetMaxLevel())
  targetLevel = max(0, min(targetLevel, maxLevel))
  if targetLevel <= 0 then
    return { targetLevel = 0, targetXP = 0, createdAt = 0 }
  end
  return {
    targetLevel = targetLevel,
    targetXP = NonNegativeFinite(source.targetXP),
    createdAt = NonNegativeFinite(source.createdAt),
  }
end

-- Record one loot event: every readable item counts toward the item counters,
-- but only items with a positive vendor sell price add loot value. Unknown item
-- data stays silent.
function XPTooltip:RecordLoot(itemID, quantity)
  if not self:Supports("hasLootValue") then
    return false
  end
  local id = SafeNumber(itemID)
  if not id or id <= 0 then
    return false
  end
  local db = self.char
  if not db then
    return false
  end
  local qty = math.floor(SafeNumber(quantity) or 1)
  qty = max(1, min(1000, qty))

  local name, link = SafeCall(GetItemInfo, id)
  if not SafeString(name) or not SafeString(link) then
    return false
  end

  -- The 11th GetItemInfo return is the vendor sell price; SafeCall stops at
  -- five values, so read it through pcall/select.
  local ok, sellPrice = pcall(function()
    return select(11, GetItemInfo(id))
  end)
  if not ok then
    return false
  end
  local price = SafeNumber(sellPrice) or 0

  local economy = NormalizeEconomyInPlace(db)
  economy.items = economy.items + qty
  economy.sessionItems = economy.sessionItems + qty
  if price > 0 then
    local value = price * qty
    economy.lootValue = economy.lootValue + value
    economy.sessionLootValue = economy.sessionLootValue + value
  end
  return true
end

-- Track net money movement from every source (loot, vendors, repairs, mail,
-- trade). The first readable value only establishes the baseline.
function XPTooltip:RecordMoney(current)
  if not self:Supports("hasMoney") then
    return false
  end
  local money = SafeNumber(current)
  if not money then
    return false
  end
  local db = self.char
  if not db then
    return false
  end

  local economy = NormalizeEconomyInPlace(db)
  if not economy.moneyKnown then
    economy.goldStart = money
    economy.lastMoney = money
    economy.goldGained = 0
    economy.goldSpent = 0
    economy.moneyKnown = true
    return true
  end

  local delta = money - economy.lastMoney
  if delta > 0 then
    economy.goldGained = economy.goldGained + delta
  elseif delta < 0 then
    economy.goldSpent = economy.goldSpent + math.abs(delta)
  end
  economy.lastMoney = money
  return true
end

-- Gold per hour from net money movement. Returns nil until a baseline exists
-- and the session has run for at least two minutes. Negative rates stay
-- negative instead of being clamped.
function XPTooltip:GetGoldPerHour()
  local db = self.char
  if not db then
    return nil
  end
  local economy = type(db.economy) == "table" and db.economy or nil
  if not economy or economy.moneyKnown ~= true then
    return nil
  end
  local session = type(db.session) == "table" and db.session or nil
  if not session then
    return nil
  end
  local startedAt = tonumber(session.startedAt) or 0
  if startedAt <= 0 then
    return nil
  end
  local elapsed = Epoch() - startedAt
  if elapsed < 120 then
    return nil
  end

  local net = (tonumber(economy.goldGained) or 0) - (tonumber(economy.goldSpent) or 0)
  return net / elapsed * 3600 / 10000, net, elapsed
end

function XPTooltip:GetXPRate(windowSeconds)
  if not self:Supports("hasPerMobXP") then
    return nil
  end
  local window = tonumber(windowSeconds) or 600
  window = max(60, min(3600, window))
  local now = Epoch()
  local cutoff = now - window

  local samples = self.char and self.char.rates
  local windowed = {}
  if type(samples) == "table" then
    for _, sample in ipairs(samples) do
      if type(sample) == "table" then
        local at = tonumber(sample.at)
        local xp = tonumber(sample.xp)
        if at and xp and xp > 0 and at >= cutoff then
          windowed[#windowed + 1] = { at = at, xp = xp }
        end
      end
    end
  end
  if #windowed < 2 then
    return nil
  end

  table.sort(windowed, function(a, b)
    return a.at < b.at
  end)
  local oldest = windowed[1].at
  local newest = windowed[#windowed].at
  local elapsed = newest - oldest
  if elapsed < 30 then
    return nil
  end

  local totalXP = 0
  -- The first sample marks the start of the measured interval; only XP gained
  -- after it belongs to the elapsed window.
  for index = 2, #windowed do
    totalXP = totalXP + windowed[index].xp
  end
  local xpPerSecond = totalXP / elapsed
  return xpPerSecond * 3600, xpPerSecond * 60, elapsed, #windowed
end

function XPTooltip:GetTimeToLevel(windowSeconds)
  local _, _, remaining = self:GetXPProgress()
  if not remaining or remaining <= 0 then
    return nil
  end
  local window = tonumber(windowSeconds)
  if not window then
    local settings = self.settings or self:GetSettings()
    local minutes = tonumber(settings and settings.rateWindowMinutes) or 10
    window = minutes * 60
  end
  local xpPerHour = self:GetXPRate(window)
  if not xpPerHour or xpPerHour <= 0 then
    return nil
  end
  return remaining / xpPerHour * 3600
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

function XPTooltip:NormalizeMobFields(mob)
  if type(mob) ~= "table" then
    return mob
  end
  mob.kills = max(0, tonumber(mob.kills) or 0)
  mob.sessionKills = max(0, tonumber(mob.sessionKills) or 0)
  mob.totalXP = tonumber(mob.totalXP) or 0
  mob.sessionXP = tonumber(mob.sessionXP) or 0
  mob.sessionXPKnown = mob.sessionXPKnown == true
  mob.killsAtLevel = EnsureNumberMap(mob.killsAtLevel)
  mob.killsByMap = EnsureNumberMap(mob.killsByMap)
  mob.killsByAreaLevel = EnsureNumberMap(mob.killsByAreaLevel)
  mob.contexts = EnsureNumberMap(mob.contexts)
  return mob
end

function XPTooltip:RecordQuestXP(questID, questName, xp)
  if not self:Supports("hasPerMobXP") then
    return
  end
  local value = tonumber(xp)
  if not value or value <= 0 then
    return
  end
  local db = self.char
  if not db then
    return
  end
  db.quests = EnsureNumberMap(db.quests)
  local key = questID and ("quest:" .. tostring(questID)) or "quest:unknown"
  local entry = db.quests[key]
  if type(entry) ~= "table" then
    entry = {}
    db.quests[key] = entry
  end
  entry.id = tonumber(questID) or entry.id
  entry.name = questName or entry.name or "Unknown quest"
  entry.count = (tonumber(entry.count) or 0) + 1
  entry.totalXP = (tonumber(entry.totalXP) or 0) + value
  entry.lastXP = value
  entry.firstSeen = tonumber(entry.firstSeen) or Epoch()
  entry.lastSeen = Epoch()

  local count = 0
  for _ in pairs(db.quests) do
    count = count + 1
  end
  if count > MAX_QUESTS then
    local removable = {}
    for questKey, quest in pairs(db.quests) do
      if type(quest) == "table" then
        removable[#removable + 1] = {
          key = questKey,
          seen = tonumber(quest.lastSeen) or 0,
        }
      end
    end
    table.sort(removable, function(a, b)
      if a.seen == b.seen then
        return a.key < b.key
      end
      return a.seen < b.seen
    end)
    for _, item in ipairs(removable) do
      if count <= MAX_QUESTS then
        break
      end
      db.quests[item.key] = nil
      count = count - 1
    end
  end

  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end

function XPTooltip:GetQuestSummary()
  local count, xp = 0, 0
  for _, quest in pairs(self.char and self.char.quests or {}) do
    if type(quest) == "table" then
      count = count + (tonumber(quest.count) or 0)
      xp = xp + (tonumber(quest.totalXP) or 0)
    end
  end
  return count, xp
end

--[[--------------------------------------------------------------------------------
  Level history (P-6)

  levelHistory is an ordered list. The last entry with endedAt == 0 is the
  active level. XP/kills accumulate while active; PLAYER_LEVEL_UP finalizes it
  and opens the next record. Midnight records kills/time but never XP.
------------------------------------------------------------------------------------]]

function XPTooltip:NormalizeLevelHistory()
  local db = self.char
  if not db then
    return {}
  end
  if type(db.levelHistory) ~= "table" then
    db.levelHistory = {}
  end
  local list = db.levelHistory
  for index = #list, 1, -1 do
    local record = list[index]
    if type(record) ~= "table" then
      table.remove(list, index)
    else
      record.level = NonNegativeFinite(record.level)
      record.startedAt = NonNegativeFinite(record.startedAt)
      record.endedAt = NonNegativeFinite(record.endedAt)
      record.xpGained = NonNegativeFinite(record.xpGained)
      record.kills = NonNegativeFinite(record.kills)
      record.duration = NonNegativeFinite(record.duration)
    end
  end
  return list
end

function XPTooltip:TrimLevelHistory()
  local list = self:NormalizeLevelHistory()
  while #list > MAX_LEVEL_RECORDS do
    local index = 1
    -- Prefer dropping the oldest finalized record; never drop the active one
    -- unless it is the only record left.
    if (tonumber(list[1].endedAt) or 0) == 0 and #list > 1 then
      index = 2
    end
    table.remove(list, index)
  end
  return list
end

function XPTooltip:GetCurrentLevelRecord(create)
  local list = self:NormalizeLevelHistory()
  local current = list[#list]
  if current and (tonumber(current.endedAt) or 0) == 0 then
    return current
  end
  if not create then
    return nil
  end
  current = {
    level = self:GetPlayerLevel() or 0,
    startedAt = Epoch(),
    endedAt = 0,
    xpGained = 0,
    kills = 0,
    duration = 0,
  }
  list[#list + 1] = current
  self:TrimLevelHistory()
  return current
end

function XPTooltip:EnsureLevelHistory()
  local list = self:NormalizeLevelHistory()
  local level = self:GetPlayerLevel() or 0
  local current = list[#list]
  if current and (tonumber(current.endedAt) or 0) == 0
    and level > 0 and (tonumber(current.level) or 0) ~= level then
    -- Missed level-up event: close the stale record before opening a new one.
    self:FinalizeLevelRecord(current)
    self:ResetRates()
    current = nil
  end
  if current and (tonumber(current.endedAt) or 0) == 0 then
    return current
  end
  current = {
    level = level,
    startedAt = Epoch(),
    endedAt = 0,
    xpGained = 0,
    kills = 0,
    duration = 0,
  }
  list[#list + 1] = current
  self:TrimLevelHistory()
  return current
end

function XPTooltip:FinalizeLevelRecord(record)
  if type(record) ~= "table" then
    return
  end
  local now = Epoch()
  record.endedAt = now
  local started = tonumber(record.startedAt) or now
  record.duration = max(0, now - started)
end

function XPTooltip:FinalizeLevelHistory(newLevel)
  local list = self:NormalizeLevelHistory()
  local current = list[#list]
  if current and (tonumber(current.endedAt) or 0) == 0 then
    self:FinalizeLevelRecord(current)
  end
  local level = tonumber(newLevel) or self:GetPlayerLevel() or 0
  current = {
    level = level,
    startedAt = Epoch(),
    endedAt = 0,
    xpGained = 0,
    kills = 0,
    duration = 0,
  }
  list[#list + 1] = current
  self:TrimLevelHistory()
  return current
end

function XPTooltip:AddLevelHistoryXP(xp)
  if not self:Supports("hasPerMobXP") then
    return false
  end
  local value = tonumber(xp)
  if not value or value <= 0 then
    return false
  end
  local record = self:EnsureLevelHistory()
  record.xpGained = (tonumber(record.xpGained) or 0) + value
  return true
end

function XPTooltip:AddLevelHistoryKill()
  local record = self:EnsureLevelHistory()
  record.kills = (tonumber(record.kills) or 0) + 1
  return true
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
    self:NormalizeMobFields(mob)
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
