--[[---------------------------------------------------------------------------------
  KillHistory/Util.lua
  Defensive helpers, shared constants, formatting, and number-map utilities.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local floor = math.floor

local MAX_MOBS = 2000
local CALIBRATION_VERSION = 2
local MAX_CONTEXTS_PER_MOB = 12
local MAX_PENDING_DEATHS = 50
local CONTEXT_MAX_AGE = 120 * 86400
local ROW_HEIGHT = 28
local VISIBLE_ROWS = 13

local DEFAULT_SETTINGS = {
  enabled = true,
  showXP = true,
  showPercent = true,
  showKillsToLevel = true,
  showKillCount = true,
  showRested = true,
  showUnknown = true,
  countZeroXPMobs = true,
  manualXPBonus = 0,
  debug = false,
  theme = "aether",
  scale = 1.0,
  startTab = "overview",
  sound = true,
}

local DEFAULT_UI = {
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
  width = 1000,
  height = 680,
  sort = "kills",
}

local DEFAULT_MINIMAP = {
  hide = false,
  minimapPos = 200,
  lock = false,
}

--[[--------------------------------------------------------------------------------
  Defensive helpers
------------------------------------------------------------------------------------]]

local function IsSecret(value)
  return issecretvalue and issecretvalue(value) or false
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c, d, e
end

local function SafeNumber(value)
  if value == nil or IsSecret(value) or type(value) ~= "number" then
    return nil
  end
  return value
end

local function SafeString(value)
  if value == nil or IsSecret(value) or type(value) ~= "string" then
    return nil
  end
  return value
end

local function SafeBool(value)
  if value == nil or IsSecret(value) or type(value) ~= "boolean" then
    return nil
  end
  return value
end

local function Trim(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Lower(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  local lower = strlower or string.lower
  local ok, result = pcall(lower, value)
  if not ok then
    return nil
  end
  return result
end

local function CopyTable(source)
  local copy = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = CopyTable(value)
    else
      copy[key] = value
    end
  end
  return copy
end

local function CopyInfo(source)
  if type(source) ~= "table" then
    return nil
  end
  return {
    name = source.name,
    guid = source.guid,
    npcID = source.npcID,
    level = source.level,
    classification = source.classification,
    mobKey = source.mobKey,
    mapID = source.mapID,
    at = source.at,
  }
end

local function Now()
  return SafeNumber(SafeCall(GetTime)) or 0
end

local function Epoch()
  return SafeNumber(SafeCall(time)) or Now()
end

local function Clamp(number, minimum, maximum)
  if number < minimum then
    return minimum
  end
  if number > maximum then
    return maximum
  end
  return number
end

--[[--------------------------------------------------------------------------------
  Formatting
------------------------------------------------------------------------------------]]

local function FormatNumber(number)
  local value = tonumber(number) or 0
  if value >= 1000000 then
    return string.format("%.2fm", value / 1000000)
  elseif value >= 10000 then
    return string.format("%.1fk", value / 1000)
  end
  return tostring(floor(value + 0.5))
end

local function FormatPercent(number)
  local value = tonumber(number) or 0
  return string.format("%.2f%%", value)
end

local function FormatAgo(epoch)
  local value = tonumber(epoch) or 0
  if value <= 0 then
    return "never"
  end
  local delta = Epoch() - value
  if delta < 0 then
    delta = 0
  end
  if delta < 60 then
    return "just now"
  elseif delta < 3600 then
    return floor(delta / 60) .. "m ago"
  elseif delta < 86400 then
    return floor(delta / 3600) .. "h ago"
  end
  return floor(delta / 86400) .. "d ago"
end

local function FormatDate(epoch)
  local value = tonumber(epoch) or 0
  if value <= 0 or type(date) ~= "function" then
    return "unknown"
  end
  local ok, text = pcall(date, "%Y-%m-%d", value)
  if ok and text then
    return text
  end
  return "unknown"
end

--[[--------------------------------------------------------------------------------
  Character data
------------------------------------------------------------------------------------]]

local function EnsureNumberMap(tbl)
  if type(tbl) ~= "table" then
    return {}
  end
  return tbl
end

Util.MAX_MOBS = MAX_MOBS
Util.CALIBRATION_VERSION = CALIBRATION_VERSION
Util.MAX_CONTEXTS_PER_MOB = MAX_CONTEXTS_PER_MOB
Util.MAX_PENDING_DEATHS = MAX_PENDING_DEATHS
Util.CONTEXT_MAX_AGE = CONTEXT_MAX_AGE
Util.ROW_HEIGHT = ROW_HEIGHT
Util.VISIBLE_ROWS = VISIBLE_ROWS
Util.DEFAULT_SETTINGS = DEFAULT_SETTINGS
Util.DEFAULT_UI = DEFAULT_UI
Util.DEFAULT_MINIMAP = DEFAULT_MINIMAP
Util.IsSecret = IsSecret
Util.SafeCall = SafeCall
Util.SafeNumber = SafeNumber
Util.SafeString = SafeString
Util.SafeBool = SafeBool
Util.Trim = Trim
Util.Lower = Lower
Util.CopyTable = CopyTable
Util.CopyInfo = CopyInfo
Util.Now = Now
Util.Epoch = Epoch
Util.Clamp = Clamp
Util.FormatNumber = FormatNumber
Util.FormatPercent = FormatPercent
Util.FormatAgo = FormatAgo
Util.FormatDate = FormatDate
Util.EnsureNumberMap = EnsureNumberMap


-- Client API wrappers, map/group helpers, and buff detection.

local function HasAuraSpellID(spellID)
  if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then
    return false
  end
  for index = 1, 40 do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
    if not ok or not aura then
      break
    end
    if not IsSecret(aura) then
      local spellId = aura.spellId
      if not IsSecret(spellId) and tonumber(spellId) == spellID then
        return true
      end
    end
  end
  return false
end


local function HasAura(name)
  if type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function" then
    local ok, aura = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
    if ok and aura and not IsSecret(aura) then
      return true
    end
  end
  if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
    for index = 1, 40 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
      if not ok or not aura then
        break
      end
      if not IsSecret(aura) then
        local auraName = aura.name
        if not IsSecret(auraName) and auraName == name then
          return true
        end
      end
    end
  end
  return false
end

function XPTooltip:GetPlayerLevel()
  return SafeNumber(SafeCall(UnitLevel, "player"))
end

function XPTooltip:GetXP()
  return SafeNumber(SafeCall(UnitXP, "player"))
end

function XPTooltip:GetXPMax()
  return SafeNumber(SafeCall(UnitXPMax, "player"))
end

function XPTooltip:GetMaxLevel()
  local maxLevel = SafeNumber(SafeCall(GetMaxPlayerLevel))
  if not maxLevel then
    maxLevel = SafeNumber(SafeCall(GetMaxLevelForPlayer))
  end
  return maxLevel or 60
end

function XPTooltip:IsXPDisabled()
  local disabled
  if C_PlayerInfo and C_PlayerInfo.IsXPUserDisabled then
    disabled = SafeBool(SafeCall(C_PlayerInfo.IsXPUserDisabled))
  end
  if disabled == nil and type(IsXPUserDisabled) == "function" then
    disabled = SafeBool(SafeCall(IsXPUserDisabled))
  end
  return disabled == true
end

function XPTooltip:GetRestedPool()
  return SafeNumber(SafeCall(GetXPExhaustion)) or 0
end

function XPTooltip:CanReadRested()
  if type(GetXPExhaustion) ~= "function" then
    return false
  end
  local ok, value = pcall(GetXPExhaustion)
  return ok and not IsSecret(value)
end

function XPTooltip:GetMapID()
  if C_Map and C_Map.GetBestMapForUnit then
    local mapID = SafeNumber(SafeCall(C_Map.GetBestMapForUnit, "player"))
    if mapID then
      return mapID
    end
  end
  local mapID = SafeNumber(SafeCall(GetCurrentMapAreaID))
  return mapID or 0
end

function XPTooltip:GetMapName(mapID)
  local id = tonumber(mapID)
  if not id then
    return "Unknown"
  end
  if C_Map and C_Map.GetMapInfo then
    local info = SafeCall(C_Map.GetMapInfo, id)
    if type(info) == "table" and type(info.name) == "string" and not IsSecret(info.name) then
      return info.name
    end
  end
  return "Map " .. tostring(id)
end

function XPTooltip:GetGroupSize()
  local size = SafeNumber(SafeCall(GetNumGroupMembers))
  if size and size > 0 then
    return size
  end
  return 1
end

function XPTooltip:ParseNPCID(guid)
  if not guid or IsSecret(guid) or type(guid) ~= "string" then
    return nil
  end
  local parts = {}
  for part in string.gmatch(guid, "[^-]+") do
    parts[#parts + 1] = part
  end
  if parts[1] ~= "Creature" then
    return nil
  end
  return tonumber(parts[6])
end

function XPTooltip:CaptureUnit(unit)
  local exists = SafeBool(SafeCall(UnitExists, unit))
  if not exists then
    return nil
  end
  local isPlayer = SafeBool(SafeCall(UnitIsPlayer, unit))
  if isPlayer == nil or isPlayer then
    return nil
  end
  local isDead = SafeBool(SafeCall(UnitIsDead, unit))
  if isDead == nil or isDead then
    return nil
  end
  local controlled = SafeBool(SafeCall(UnitPlayerControlled, unit))
  if controlled == nil or controlled then
    return nil
  end
  local creatureType = SafeCall(UnitCreatureType, unit)
  if creatureType == "Critter" then
    return nil
  end
  local canAttack = SafeBool(SafeCall(UnitCanAttack, "player", unit))
  if canAttack ~= true then
    return nil
  end
  local name = Trim(SafeCall(UnitName, unit))
  local guid = SafeString(SafeCall(UnitGUID, unit))
  local level = SafeNumber(SafeCall(UnitLevel, unit))
  local classification = SafeString(SafeCall(UnitClassification, unit)) or "normal"
  local npcID = guid and self:ParseNPCID(guid) or nil
  if not name and not npcID then
    return nil
  end
  return {
    name = name,
    guid = guid,
    level = level,
    classification = classification,
    npcID = npcID,
    mobKey = self:GetMobKey(name, npcID),
    mapID = self:GetMapID(),
    at = Now(),
  }
end

function XPTooltip:CanDetectBuffs()
  local byName = type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function"
  local byID = C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function"
  return (byName or byID) and true or false
end

function XPTooltip:GetBuffInfo()
  local now = Now()
  local canDetect = self:CanDetectBuffs()
  if self.buffCacheTime and (now - self.buffCacheTime) < 1 then
    return self.buffCacheWellFed, self.buffCacheWellRested, self.buffCacheCanDetect
  end
  local wellFed = canDetect and HasAura("Well Fed") or false
  local wellRested = canDetect and (HasAura("Well-Rested") or HasAuraSpellID(429959)) or false
  self.buffCacheTime = now
  self.buffCacheWellFed = wellFed
  self.buffCacheWellRested = wellRested
  self.buffCacheCanDetect = canDetect
  return wellFed, wellRested, canDetect
end

function XPTooltip:GetBuffSignature()
  local settings = self.settings or self:GetSettings()
  local wellFed, wellRested = self:GetBuffInfo()
  local parts = {}
  if wellFed then
    parts[#parts + 1] = "wf"
  end
  if wellRested then
    parts[#parts + 1] = "wr"
  end
  local manual = settings and tonumber(settings.manualXPBonus) or 0
  if manual > 0 then
    parts[#parts + 1] = "m" .. tostring(manual)
  end
  if #parts == 0 then
    return "none", wellFed, wellRested
  end
  return table.concat(parts, "+"), wellFed, wellRested
end

function XPTooltip:GetBuffMultiplier(wellFed, wellRested)
  local settings = self.settings or self:GetSettings()
  local multiplier = 1
  if wellFed then
    multiplier = multiplier * 1.05
  end
  if wellRested then
    multiplier = multiplier * 1.03
  end
  local manual = settings and tonumber(settings.manualXPBonus) or 0
  if manual > 0 then
    multiplier = multiplier * (1 + manual / 100)
  end
  return multiplier
end
