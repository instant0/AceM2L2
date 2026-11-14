--[[---------------------------------------------------------------------------------
  KillHistory/Formula.lua
  Shared formula helpers. Client-specific XP policy lives in Clients/Forever.lua
  and Clients/Midnight.lua.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Formula = XPTooltip.Formula

local floor = math.floor

-- Banker's rounding, used by the Forever profile and safe for client-neutral
-- display values. Profiles may expose their own Round implementation.
local function Round(value)
  local base = floor(value)
  local fraction = value - base
  if fraction > 0.5 + 1e-9 then
    return base + 1
  elseif fraction >= 0.5 - 1e-9 and base % 2 == 1 then
    return base + 1
  end
  return base
end

local function ContextKey(playerLevel, mobLevel, groupSize, mapID, classification,
  buffSignature, instanceKey)
  local key = "p" .. tostring(playerLevel)
    .. "-m" .. tostring(mobLevel)
    .. "-g" .. tostring(groupSize)
    .. "-z" .. tostring(mapID)
    .. "-c" .. tostring(classification)
    .. "-b" .. tostring(buffSignature)
  if instanceKey and instanceKey ~= "" then
    key = key .. "-i" .. tostring(instanceKey)
  end
  return key
end

Formula.Round = Round
Formula.ContextKey = ContextKey
