--[[---------------------------------------------------------------------------------
  KillHistory/V2Evidence.lua
  Live V-2A API/field probe and local evidence capture.
  Evidence capture does not unlock retirement; it only records availability.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local Epoch = Util.Epoch
local SafeCall = Util.SafeCall
local SafeBool = Util.SafeBool

local API_NAMES = {
  "UnitHealth", "UnitHealthMax", "UnitBuff", "UnitDebuff",
  "GetNumGroupMembers", "GetNumSubgroupMembers", "GetXPExhaustion",
  "GetPlayerMapPosition", "C_NamePlate", "GetAddOnMemoryUsage",
}

local FIELD_NAMES = {
  "deathAttribution", "deathHealth", "deathBuffs", "deathGroup",
  "heatmapCellXP", "heatmapCellTime", "presenceTiming", "engagedTiming",
}

local function probeApi(name)
  if name == "C_NamePlate" then
    return type(_G.C_NamePlate) == "table"
  end
  return type(_G[name]) == "function"
end

local function safeValue(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  return ok and value or nil
end

function XPTooltip:CollectV2Probe()
  local apis = {}
  for _, name in ipairs(API_NAMES) do apis[name] = probeApi(name) end
  local fields = {}
  for _, name in ipairs(FIELD_NAMES) do fields[name] = false end

  local health = apis.UnitHealth and safeValue(UnitHealth, "player") or nil
  local healthMax = apis.UnitHealthMax and safeValue(UnitHealthMax, "player") or nil
  local groupSize = apis.GetNumGroupMembers
    and (tonumber(safeValue(GetNumGroupMembers)) or 1) or 1
  local mapID
  if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
    mapID = safeValue(C_Map.GetBestMapForUnit, "player")
  end
  local mapX, mapY
  if apis.GetPlayerMapPosition then
    local position = safeValue(GetPlayerMapPosition, "player")
    if type(position) == "table" and type(position.GetXY) == "function" then
      local ok, x, y = pcall(position.GetXY, position)
      if ok then mapX, mapY = tonumber(x), tonumber(y) end
    elseif type(position) == "number" then
      mapX = position
    end
  end

  return {
    at = Epoch(),
    interface = AceM2L2 and AceM2L2.GetInterfaceVersion
      and AceM2L2:GetInterfaceVersion() or nil,
    projectID = self:GetProjectID(),
    apis = apis,
    fields = fields,
    values = {
      playerHealth = health,
      playerHealthMax = healthMax,
      groupSize = groupSize,
      restedPool = type(self.GetRestedPool) == "function"
        and self:GetRestedPool() or nil,
      mapID = mapID,
      mapX = mapX,
      mapY = mapY,
      namePlateAPI = apis.C_NamePlate,
    },
  }
end

function XPTooltip:RecordV2Evidence(part, data)
  local journey = self:EnsureJourney()
  if not journey then return false end
  if type(journey.liveEvidence) ~= "table" then journey.liveEvidence = {} end
  journey.liveEvidence[tostring(part or "")] = data or self:CollectV2Probe()
  return true
end

function XPTooltip:GetV2Evidence(part)
  local journey = self.char and self.char.journey
  local evidence = journey and journey.liveEvidence
  return evidence and evidence[tostring(part or "")] or nil
end

function XPTooltip:PrintV2Probe()
  local probe = self:CollectV2Probe()
  AceM2L2:SafePrint("Kill Story V-2A probe:")
  local apiParts = {}
  for _, name in ipairs(API_NAMES) do
    apiParts[#apiParts + 1] = name .. "=" .. (probe.apis[name] and "yes" or "no")
  end
  AceM2L2:SafePrint("  APIS: " .. table.concat(apiParts, " "))
  local fieldParts = {}
  for _, name in ipairs(FIELD_NAMES) do
    fieldParts[#fieldParts + 1] = name .. "=" .. (probe.fields[name] and "yes" or "no")
  end
  AceM2L2:SafePrint("  FIELDS: " .. table.concat(fieldParts, " "))
  AceM2L2:SafePrint("  VALUES: health=" .. tostring(probe.values.playerHealth)
    .. "/" .. tostring(probe.values.playerHealthMax)
    .. " group=" .. tostring(probe.values.groupSize)
    .. " map=" .. tostring(probe.values.mapID))
  if self:RecordV2Evidence("v2a", probe) then
    AceM2L2:SafePrint("  V-2A evidence stored locally. Retirement remains blocked.")
  else
    AceM2L2:SafePrint("  V-2A evidence could not be stored.")
  end
end
