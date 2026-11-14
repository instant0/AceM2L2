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
local MAX_INSTANCE_RECORDS = 100
local MAX_MOB_INSTANCES = 20
local INSTANCE_NAME_MAX = 80
local INSTANCE_KEY_MAX = 120
local CONTEXT_MAX_AGE = 120 * 86400
local ROW_HEIGHT = 28
local VISIBLE_ROWS = 13

local Defaults = AceM2L2.Defaults or {}
local DEFAULT_SETTINGS = {}
for key, value in pairs(Defaults.XPTOOLTIP_DEFAULTS or {}) do
  if key ~= "ui" and key ~= "minimap" then
    DEFAULT_SETTINGS[key] = value
  end
end
local DEFAULT_UI = Defaults.XPTOOLTIP_UI_DEFAULTS or {}
local DEFAULT_MINIMAP = Defaults.XPTOOLTIP_MINIMAP_DEFAULTS or {}

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
    x = source.x,
    y = source.y,
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

local function FormatDuration(seconds)
  local value = tonumber(seconds) or 0
  if value < 0 then
    value = 0
  end
  if value < 60 then
    return floor(value) .. "s"
  elseif value < 3600 then
    return floor(value / 60) .. "m"
  end
  local hours = floor(value / 3600)
  local minutes = floor((value % 3600) / 60)
  if hours >= 24 then
    return floor(hours / 24) .. "d " .. (hours % 24) .. "h"
  elseif minutes > 0 then
    return hours .. "h " .. minutes .. "m"
  end
  return hours .. "h"
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

local function FormatMoney(copper)
  local raw = tonumber(copper) or 0
  local negative = raw < 0
  local value = floor(math.abs(raw))
  local gold = floor(value / 10000)
  local silver = floor((value % 10000) / 100)
  local remainder = value % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = gold .. "g"
  end
  if silver > 0 then
    parts[#parts + 1] = silver .. "s"
  end
  if remainder > 0 or #parts == 0 then
    parts[#parts + 1] = remainder .. "c"
  end
  local text = table.concat(parts, " ")
  if negative then
    return "-" .. text
  end
  return text
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
Util.MAX_INSTANCE_RECORDS = MAX_INSTANCE_RECORDS
Util.MAX_MOB_INSTANCES = MAX_MOB_INSTANCES
Util.INSTANCE_NAME_MAX = INSTANCE_NAME_MAX
Util.INSTANCE_KEY_MAX = INSTANCE_KEY_MAX
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
Util.FormatDuration = FormatDuration
Util.FormatDate = FormatDate
Util.FormatMoney = FormatMoney
Util.EnsureNumberMap = EnsureNumberMap


-- Client API wrappers, map/group helpers, and buff detection.

local WELL_FED_SPELL_IDS = {}
for spellID = 19705, 19740 do
  WELL_FED_SPELL_IDS[spellID] = true
end
-- Forever food grants "Well Fed XP Boost" (1243969, +5% kill XP) rather than
-- only the vanilla Well Fed stat buffs. Match it by spell ID because the aura
-- name differs from "Well Fed" on some clients.
WELL_FED_SPELL_IDS[1243969] = true
local WELL_RESTED_SPELL_IDS = { [429959] = true }

-- Verified 2026-11-13 against Wowhead Forever, ForeverDB, and Azeroth Pilot
-- Reloaded data:
--   Well Fed XP Boost 1243969: +5% kill XP from qualifying food.
--   Well-Rested 429959: +1% XP per stack, max 3; granted by inns and the
--     Cozy Sleeping Bag, so there is no separate bag aura to count.
--   Camp Tent 1307230: raises the rested pool to 5% of a level. It is a
--     rested-pool top-up, not an XP multiplier; the pool is already shown by
--     the rested line/tooltip.
--   Boosted Rest 1229451: 1-hour Camp Tent lockout, not an XP bonus.
local VERIFIED_BUFF_IDS = {
  wellFedXP = 1243969,
  wellRested = 429959,
  campTent = 1307230,
  boostedRest = 1229451,
}
Util.VERIFIED_BUFF_IDS = VERIFIED_BUFF_IDS

local function MatchesAura(aura, name, spellIDs)
  if type(aura) ~= "table" or IsSecret(aura) then
    return false
  end
  local auraName = aura.name
  if name and not IsSecret(auraName) and auraName == name then
    return true
  end
  local rawSpellID = aura.spellId
  if IsSecret(rawSpellID) then
    return false
  end
  local spellID = tonumber(rawSpellID)
  return spellID ~= nil and spellIDs ~= nil and spellIDs[spellID] == true
end

local function FindAura(name, spellIDs)
  if type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function" then
    local ok, aura = pcall(AuraUtil.FindAuraByName, name or "", "player", "HELPFUL")
    if ok and MatchesAura(aura, name, spellIDs) then
      return aura
    end
  end
  if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
    for index = 1, 40 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
      if not ok or not aura then
        break
      end
      if MatchesAura(aura, name, spellIDs) then
        return aura
      end
    end
  end
  return nil
end

local function AuraStacks(aura)
  if type(aura) ~= "table" then
    return 1
  end
  local raw = aura.applications
  if IsSecret(raw) then
    raw = nil
  end
  if raw == nil then
    raw = aura.charges
    if IsSecret(raw) then
      raw = nil
    end
  end
  local stacks = tonumber(raw) or 1
  return math.max(1, math.min(3, stacks))
end

function XPTooltip:GetPlayerLevel()
  return SafeNumber(SafeCall(UnitLevel, "player"))
end

function XPTooltip:GetXP()
  if not self:Supports("hasPlayerXPState") then
    return nil
  end
  return SafeNumber(SafeCall(UnitXP, "player"))
end

function XPTooltip:GetXPMax()
  if not self:Supports("hasPlayerXPState") then
    return nil
  end
  return SafeNumber(SafeCall(UnitXPMax, "player"))
end

function XPTooltip:GetXPProgress()
  local current = self:GetXP()
  local max = self:GetXPMax()
  if not current or not max or max <= 0 then
    return nil
  end
  local remaining = max - current
  if remaining < 0 then
    remaining = 0
  end
  return current, max, remaining, remaining / max * 100
end

function XPTooltip:GetMaxLevel()
  local profile = self.clientProfile or self:GetClientProfile()
  if profile and profile.GetMaxLevel then
    local value = profile:GetMaxLevel()
    if value then
      return value
    end
  end
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

function XPTooltip:GetMoney()
  if not self:Supports("hasMoney") then
    return nil
  end
  return SafeNumber(SafeCall(GetMoney))
end

function XPTooltip:GetRestedPool()
  if not self:Supports("hasRestedPool") then
    return 0
  end
  return SafeNumber(SafeCall(GetXPExhaustion)) or 0
end

function XPTooltip:CanReadRested()
  if not self:Supports("hasRestedPool") then
    return false
  end
  if type(GetXPExhaustion) ~= "function" then
    return false
  end
  local ok, value = pcall(GetXPExhaustion)
  return ok and not IsSecret(value)
end

local function ReadMapPosition(mapID)
  if not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then
    return nil
  end
  local position = SafeCall(C_Map.GetPlayerMapPosition, mapID, "player")
  if type(position) ~= "table" then
    return nil
  end
  local ok, x, y = pcall(function()
    if type(position.GetXY) == "function" then
      return position:GetXY()
    end
    return position.x, position.y
  end)
  x, y = SafeNumber(x), SafeNumber(y)
  if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
    return nil
  end
  return x, y
end


--[[--------------------------------------------------------------------------------
  Instance identity
------------------------------------------------------------------------------------]]

local VALID_INSTANCE_TYPES = {
  party = true, raid = true, scenario = true, pvp = true, arena = true,
  unknown = true,
}

local function IsAttributableMapID(mapID)
  local id = tonumber(mapID)
  if not id or id <= 0 then
    return false
  end
  if not C_Map or type(C_Map.GetMapInfo) ~= "function" then
    -- Legacy clients without C_Map: keep the old permissive behavior.
    return true
  end
  local info = SafeCall(C_Map.GetMapInfo, id)
  if type(info) ~= "table" then
    return true
  end
  local mapType = SafeNumber(info.mapType)
  if not mapType then
    return true
  end
  return mapType == 3 or mapType == 4
end

local function NormalizeInstanceType(value)
  local kind = Lower(value)
  if kind and VALID_INSTANCE_TYPES[kind] then
    return kind
  end
  return nil
end

local function GetInstanceInfoSafe()
  if type(GetInstanceInfo) ~= "function" then
    return nil
  end
  local ok, name, instanceType, difficultyID, _, _, _, _, instanceMapID = pcall(GetInstanceInfo)
  if not ok then
    return nil
  end
  local result = {
    name = SafeString(name),
    instanceType = SafeString(instanceType),
    difficultyID = SafeNumber(difficultyID),
    instanceID = SafeNumber(instanceMapID),
  }
  if result.name == "" then
    result.name = nil
  end
  return result
end

local function BuildInstanceKey(name, instanceID, difficultyID)
  local id = tonumber(instanceID) or 0
  local difficulty = floor(tonumber(difficultyID) or 0)
  if id > 0 then
    return string.format("id:%d:%d", id, difficulty)
  end
  local lower = Lower(name) or ""
  if lower ~= "" then
    local key = "name:" .. lower
    if #key > INSTANCE_KEY_MAX then
      key = key:sub(1, INSTANCE_KEY_MAX)
    end
    return key
  end
  return "unknown"
end

local function CopyInstanceState(state)
  if type(state) ~= "table" then
    return {
      inInstance = false,
      inDungeon = false,
      instanceType = "none",
      instanceID = 0,
      difficultyID = 0,
      mapID = 0,
      name = nil,
      key = nil,
    }
  end
  return {
    inInstance = state.inInstance == true,
    inDungeon = state.inDungeon == true,
    instanceType = state.instanceType or "none",
    instanceID = tonumber(state.instanceID) or 0,
    difficultyID = tonumber(state.difficultyID) or 0,
    mapID = tonumber(state.mapID) or 0,
    name = state.name,
    key = state.key,
  }
end

function XPTooltip:QueryInstanceState()
  local rawInInstance, rawType = SafeCall(IsInInstance)
  local inInstance = SafeBool(rawInInstance)
  if inInstance == nil then
    local number = SafeNumber(rawInInstance)
    if number then
      inInstance = number ~= 0
    end
  end

  local instanceType = NormalizeInstanceType(rawType)
  local info = GetInstanceInfoSafe()
  if not instanceType and info then
    instanceType = NormalizeInstanceType(info.instanceType)
  end
  if inInstance == nil then
    inInstance = instanceType ~= nil
  end
  if not inInstance then
    instanceType = "none"
  elseif not instanceType then
    instanceType = "unknown"
  end

  local name = info and info.name or nil
  if not name and inInstance then
    name = SafeString(SafeCall(GetRealZoneText)) or SafeString(SafeCall(GetZoneText))
  end
  name = name and Trim(name) or nil
  if name == "" then
    name = nil
  end

  local instanceID = info and info.instanceID or 0
  local difficultyID = info and info.difficultyID or 0
  local mapID = self:GetMapID() or 0
  if mapID > 0 and not IsAttributableMapID(mapID) then
    mapID = 0
  end

  local state = {
    inInstance = inInstance == true,
    instanceType = instanceType,
    instanceID = tonumber(instanceID) or 0,
    difficultyID = tonumber(difficultyID) or 0,
    mapID = mapID,
    name = name,
    key = inInstance and BuildInstanceKey(name, instanceID, difficultyID) or nil,
    updatedAt = Now(),
    identityAttemptAt = Now(),
  }
  state.inDungeon = state.inInstance
    and (state.instanceType == "party" or state.instanceType == "raid"
      or state.instanceType == "scenario")
  self.instanceState = state
  return state
end

function XPTooltip:GetInstanceState(force)
  local cached = self.instanceState
  if not cached then
    return self:QueryInstanceState()
  end
  if force then
    return self:QueryInstanceState()
  end

  local rawInInstance, rawType = SafeCall(IsInInstance)
  local inInstance = SafeBool(rawInInstance)
  if inInstance == nil then
    local number = SafeNumber(rawInInstance)
    if number then
      inInstance = number ~= 0
    end
  end
  if inInstance == nil then
    -- No readable API this time; keep the last good state.
    return cached
  end

  local instanceType = NormalizeInstanceType(rawType)
  if cached.inInstance ~= inInstance
    or (instanceType and cached.instanceType ~= instanceType) then
    return self:QueryInstanceState()
  end

  if cached.inInstance
    and ((not cached.name) or (tonumber(cached.instanceID) or 0) <= 0) then
    local now = Now()
    if (now - (tonumber(cached.identityAttemptAt) or 0)) > 30 then
      return self:QueryInstanceState()
    end
  end
  return cached
end

function XPTooltip:ScheduleInstanceStateRefresh(delay)
  if not self:IsActive() then
    return
  end
  self.instanceRefreshGeneration = (self.instanceRefreshGeneration or 0) + 1
  local generation = self.instanceRefreshGeneration
  local function run()
    if generation ~= self.instanceRefreshGeneration or not self:IsActive() then
      return
    end
    local ok, err = pcall(self.QueryInstanceState, self)
    if not ok then
      self:ReportError("QueryInstanceState", err, false)
    end
  end
  local wait = tonumber(delay) or 0.75
  if C_Timer and type(C_Timer.After) == "function" then
    local ok = pcall(C_Timer.After, wait, run)
    if not ok then
      run()
    end
  else
    run()
  end
end

function XPTooltip:RefreshInstanceState()
  return self:QueryInstanceState()
end

Util.IsAttributableMapID = IsAttributableMapID
Util.GetInstanceInfoSafe = GetInstanceInfoSafe
Util.BuildInstanceKey = BuildInstanceKey
Util.CopyInstanceState = CopyInstanceState

local function ResolveZoneMapID(mapID)
  local id = SafeNumber(mapID)
  if not id or id <= 0 then
    return 0
  end
  if not C_Map or type(C_Map.GetMapInfo) ~= "function" then
    return id
  end
  local info = SafeCall(C_Map.GetMapInfo, id)
  if type(info) ~= "table" then
    return id
  end
  local mapType = SafeNumber(info.mapType)
  if mapType ~= 1 and mapType ~= 2 then
    return id
  end
  if type(C_Map.GetMapInfoAtPosition) ~= "function" then
    return id
  end
  local x, y = ReadMapPosition(id)
  if not x or not y then
    return id
  end
  local child = SafeCall(C_Map.GetMapInfoAtPosition, id, x, y)
  if type(child) ~= "table" then
    return id
  end
  local childID = SafeNumber(child.mapID)
  local childType = SafeNumber(child.mapType)
  if childID and (childType == 3 or childType == 4) then
    return childID
  end
  return id
end

function XPTooltip:GetMapID()
  local mapID
  if type(MapUtil) == "table" and type(MapUtil.GetDisplayableMapForPlayer) == "function" then
    mapID = SafeNumber(SafeCall(MapUtil.GetDisplayableMapForPlayer))
  end
  if not mapID or mapID <= 0 then
    if C_Map and C_Map.GetBestMapForUnit then
      mapID = SafeNumber(SafeCall(C_Map.GetBestMapForUnit, "player"))
    end
  end
  if not mapID or mapID <= 0 then
    mapID = SafeNumber(SafeCall(GetCurrentMapAreaID))
  end
  if not mapID or mapID <= 0 then
    return 0
  end
  local resolved = ResolveZoneMapID(mapID)
  if not IsAttributableMapID(resolved) then
    return 0
  end
  return resolved
end

function XPTooltip:IsInDungeon()
  if not self:Supports("hasInstanceInfo") or type(IsInInstance) ~= "function" then
    return false
  end
  local ok, isInInstance, instanceType = pcall(IsInInstance)
  if not ok then
    return false
  end
  local inInstance = SafeBool(isInInstance)
  if inInstance == nil and type(isInInstance) == "number" and not IsSecret(isInInstance) then
    -- Some 1.12-era clients return 1/0 instead of a boolean.
    inInstance = isInInstance ~= 0
  end
  if inInstance ~= true then
    return false
  end
  local kind = SafeString(instanceType)
  return kind == "party" or kind == "raid" or kind == "scenario"
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

function XPTooltip:IsCritter(unit)
  if type(UnitIsCritter) == "function" then
    local value = SafeBool(SafeCall(UnitIsCritter, unit))
    if value ~= nil then
      return value
    end
  end
  return SafeString(SafeCall(UnitCreatureType, unit)) == "Critter"
end

function XPTooltip:IsTapDenied(unit)
  return SafeBool(SafeCall(UnitIsTapDenied, unit)) == true
end

function XPTooltip:IsUnitEligible(unit)
  if not unit or type(unit) ~= "string" or IsSecret(unit) then
    return false
  end
  local exists = SafeBool(SafeCall(UnitExists, unit))
  if exists ~= true then
    return false
  end

  local name = Trim(SafeCall(UnitName, unit))
  if not name or name == "" then
    name = nil
  end
  local guid = SafeString(SafeCall(UnitGUID, unit))
  local npcID = guid and self:ParseNPCID(guid) or nil

  -- GUID checks are safe even when the boolean APIs are secret or missing.
  if guid then
    if guid:match("^Player%-") or guid:match("^Pet%-") or guid:match("^Vehicle%-") then
      return false
    end
    if guid:match("^Creature%-") then
      if not npcID then
        return false
      end
    elseif not name then
      return false
    end
  end

  local strict = self:Supports("hasReadableBooleans")
  local isPlayer = SafeBool(SafeCall(UnitIsPlayer, unit))
  if strict then
    if isPlayer == nil or isPlayer then
      return false
    end
  elseif isPlayer == true then
    return false
  end

  local isDead = SafeBool(SafeCall(UnitIsDead, unit))
  if strict then
    if isDead == nil or isDead then
      return false
    end
  elseif isDead == true then
    return false
  end

  local controlled = SafeBool(SafeCall(UnitPlayerControlled, unit))
  if strict then
    if controlled == nil or controlled then
      return false
    end
  elseif controlled == true then
    return false
  end

  if self:IsCritter(unit) or self:IsTapDenied(unit) then
    return false
  end

  local canAttack = SafeBool(SafeCall(UnitCanAttack, "player", unit))
  if strict then
    if canAttack ~= true then
      return false
    end
  elseif canAttack == false then
    return false
  end

  -- Counts need some readable identity; never manufacture an Unknown entry.
  return name ~= nil or npcID ~= nil
end

function XPTooltip:CaptureUnit(unit)
  if not self:IsUnitEligible(unit) then
    return nil
  end
  local name = Trim(SafeCall(UnitName, unit))
  if not name or name == "" then
    name = nil
  end
  local guid = SafeString(SafeCall(UnitGUID, unit))
  local level = SafeNumber(SafeCall(UnitLevel, unit))
  local classification = SafeString(SafeCall(UnitClassification, unit)) or "normal"
  local npcID = guid and self:ParseNPCID(guid) or nil
  if not name and npcID then
    -- The NPC ID is attributable even when the name is secret. Use a stable
    -- label so DeleteUnknownEntries does not treat a real NPC as Unknown.
    name = "NPC " .. tostring(npcID)
  end
  local mapID = self:GetMapID()
  local x, y
  if type(self.GetPlayerMapPosition) == "function" then
    local positionMapID, positionX, positionY = self:GetPlayerMapPosition()
    if positionMapID then
      mapID = positionMapID
    end
    if positionX and positionY then
      x, y = positionX, positionY
    end
  end
  local result = {
    name = name,
    guid = guid,
    level = level,
    classification = classification,
    npcID = npcID,
    mobKey = self:GetMobKey(name, npcID),
    mapID = mapID,
    x = x,
    y = y,
    inDungeon = self:IsInDungeon(),
    at = Now(),
  }
  -- World.lua owns respawn watch logic; this is the only sighting path for
  -- target, mouseover, and nameplate captures. Do not duplicate it here.
  if type(self.ObserveRespawn) == "function" then
    self:ObserveRespawn(result)
  end
  return result
end

function XPTooltip:CanDetectBuffs()
  if not self:Supports("hasAuraAPI") then
    return false
  end
  local byName = type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function"
  local byID = C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function"
  return (byName or byID) and true or false
end

function XPTooltip:GetBuffInfo()
  local now = Now()
  local canDetect = self:CanDetectBuffs()
    and (self:Supports("hasWellFed") or self:Supports("hasWellRestedAura"))
  if self.buffCacheTime and (now - self.buffCacheTime) < 1 then
    return self.buffCacheWellFed, self.buffCacheWellRested,
      self.buffCacheCanDetect, self.buffCacheWellRestedStacks
  end
  local wellFedAura
  if canDetect and self:Supports("hasWellFed") then
    -- The Forever food buff is "Well Fed XP Boost"; older clients expose only
    -- the by-name aura API, so try both labels before falling back to spell ID.
    wellFedAura = FindAura("Well Fed", WELL_FED_SPELL_IDS)
      or FindAura("Well Fed XP Boost", WELL_FED_SPELL_IDS)
  end
  local restedAura = canDetect and self:Supports("hasWellRestedAura")
    and FindAura("Well-Rested", WELL_RESTED_SPELL_IDS) or nil
  local wellFed = wellFedAura ~= nil
  local wellRested = restedAura ~= nil
  local stacks = wellRested and AuraStacks(restedAura) or 0
  self.buffCacheTime = now
  self.buffCacheWellFed = wellFed
  self.buffCacheWellRested = wellRested
  self.buffCacheCanDetect = canDetect
  self.buffCacheWellRestedStacks = stacks
  return wellFed, wellRested, canDetect, stacks
end

function XPTooltip:GetBuffSignature()
  local settings = self.settings or self:GetSettings()
  local wellFed, wellRested, _, stacks = self:GetBuffInfo()
  wellFed = wellFed and self:Supports("hasWellFed") or false
  wellRested = wellRested and self:Supports("hasWellRestedAura") or false
  local parts = {}
  if wellFed then
    parts[#parts + 1] = "wf"
  end
  if wellRested then
    parts[#parts + 1] = "wr" .. tostring(stacks or 1)
  end
  local manual = 0
  if self:Supports("hasXPFormula") then
    manual = settings and tonumber(settings.manualXPBonus) or 0
  end
  if manual > 0 then
    parts[#parts + 1] = "m" .. tostring(manual)
  end
  if #parts == 0 then
    return "none", wellFed, wellRested
  end
  return table.concat(parts, "+"), wellFed, wellRested
end

function XPTooltip:GetBuffMultiplier(wellFed, wellRested, wellRestedStacks)
  if not self:Supports("hasXPFormula") then
    return 1
  end
  local settings = self.settings or self:GetSettings()
  local multiplier = 1
  if wellFed and self:Supports("hasWellFed") then
    multiplier = multiplier * 1.05
  end
  if wellRested and self:Supports("hasWellRestedAura") then
    local stacks = tonumber(wellRestedStacks) or 3
    stacks = math.max(1, math.min(3, stacks))
    multiplier = multiplier * (1 + 0.01 * stacks)
  end
  local manual = settings and tonumber(settings.manualXPBonus) or 0
  if manual > 0 then
    multiplier = multiplier * (1 + manual / 100)
  end
  return multiplier
end

-- Known XP bonuses only. This intentionally does not scan arbitrary buffs:
-- every entry must match a source the estimator actually applies.
function XPTooltip:GetActiveXPBonuses()
  local bonuses = {}
  if not self:Supports("hasXPFormula") then
    return bonuses, 1, 0
  end
  local settings = self.settings or self:GetSettings()
  local wellFed, wellRested, canDetect, stacks = self:GetBuffInfo()
  local multiplier = 1

  if canDetect and wellFed and self:Supports("hasWellFed") then
    bonuses[#bonuses + 1] = { id = "wellFed", label = "Well Fed", percent = 5 }
    multiplier = multiplier * 1.05
  end
  if canDetect and wellRested and self:Supports("hasWellRestedAura") then
    local count = math.max(1, math.min(3, tonumber(stacks) or 1))
    bonuses[#bonuses + 1] = {
      id = "wellRested", label = "Well-Rested", percent = count, stacks = count,
    }
    multiplier = multiplier * (1 + 0.01 * count)
  end
  local manual = settings and tonumber(settings.manualXPBonus) or 0
  if manual and manual > 0 then
    bonuses[#bonuses + 1] = { id = "manual", label = "Manual bonus", percent = manual }
    multiplier = multiplier * (1 + manual / 100)
  end

  return bonuses, multiplier, (multiplier - 1) * 100
end

function XPTooltip:FormatXPBonuses(bonuses, totalPercent)
  if type(bonuses) ~= "table" or #bonuses == 0 then
    return nil
  end
  local parts = {}
  for _, bonus in ipairs(bonuses) do
    local percent = tonumber(bonus.percent) or 0
    local text = tostring(bonus.label or bonus.id or "Bonus") .. " +" .. FormatNumber(percent) .. "%"
    if (tonumber(bonus.stacks) or 0) > 1 then
      text = text .. " (" .. bonus.stacks .. " stacks)"
    end
    parts[#parts + 1] = text
  end
  local text = table.concat(parts, ", ")
  if #bonuses > 1 then
    text = text .. " (total +" .. FormatPercent(tonumber(totalPercent) or 0) .. ")"
  end
  return text
end
