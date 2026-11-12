--[[---------------------------------------------------------------------------------
  KillHistory/Formula.lua
  Forever XP formula, gray-level rules, classification multipliers, and context keys.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Formula = XPTooltip.Formula

local floor, min, huge = math.floor, math.min, math.huge

local ZERO_DIFFERENCE = {
  { 7, 5 }, { 9, 6 }, { 11, 7 }, { 15, 8 }, { 19, 9 },
  { 29, 11 }, { 39, 12 }, { 44, 13 }, { 49, 14 }, { 54, 15 },
  { 59, 16 }, { huge, 17 },
}

local CLASSIC_GROUP_PRIOR = {
  [1] = 1.00, [2] = 0.70, [3] = 0.60, [4] = 0.55, [5] = 0.52,
}

-- Group chat text may contain both the personal share and a party bonus.
-- Keep this off until the live amount is verified; otherwise a summed message
-- can train a 1.0 group ratio and make the tooltip show solo XP in a group.
local GROUP_CALIBRATION_ENABLED = false

--[[--------------------------------------------------------------------------------
  Formula
------------------------------------------------------------------------------------]]

local function ZeroDifference(playerLevel)
  for _, row in ipairs(ZERO_DIFFERENCE) do
    if playerLevel <= row[1] then
      return row[2]
    end
  end
  return 17
end

local function GrayLevel(playerLevel)
  if playerLevel <= 5 then
    return 0
  elseif playerLevel <= 39 then
    return playerLevel - floor(playerLevel / 10) - 5
  end
  return playerLevel - floor(playerLevel / 5) - 1
end

local function RoundForever(value)
  local base = floor(value)
  local fraction = value - base
  if fraction > 0.5 + 1e-9 then
    return base + 1
  elseif fraction >= 0.5 - 1e-9 and base % 2 == 1 then
    return base + 1
  end
  return base
end

local function ClassificationMultiplier(classification)
  if classification == "elite" or classification == "rareelite" or classification == "worldboss" then
    return 2
  end
  return 1
end

local function FormulaBaseXP(playerLevel, mobLevel)
  if not playerLevel or not mobLevel or mobLevel == 0 then
    if not playerLevel then
      return 0
    end
    mobLevel = playerLevel
  end
  if mobLevel == -1 then
    mobLevel = playerLevel + 4
  end
  if mobLevel <= GrayLevel(playerLevel) then
    return 0
  end

  local base = 5 * min(playerLevel, mobLevel) + 45
  local multiplier
  if mobLevel >= playerLevel then
    multiplier = 1 + 0.05 * min(mobLevel - playerLevel, 4)
  else
    local zd = ZeroDifference(playerLevel)
    multiplier = (zd - (playerLevel - mobLevel)) / zd
  end
  return RoundForever(base * multiplier)
end

local function FormulaXP(playerLevel, mobLevel, classification)
  local base = FormulaBaseXP(playerLevel, mobLevel)
  if base <= 0 then
    return 0
  end
  return base * ClassificationMultiplier(classification)
end

local function ContextKey(playerLevel, mobLevel, groupSize, mapID, classification, buffSignature)
  return "p" .. tostring(playerLevel)
    .. "-m" .. tostring(mobLevel)
    .. "-g" .. tostring(groupSize)
    .. "-z" .. tostring(mapID)
    .. "-c" .. tostring(classification)
    .. "-b" .. tostring(buffSignature)
end

Formula.ZERO_DIFFERENCE = ZERO_DIFFERENCE
Formula.CLASSIC_GROUP_PRIOR = CLASSIC_GROUP_PRIOR
Formula.GROUP_CALIBRATION_ENABLED = GROUP_CALIBRATION_ENABLED
Formula.ZeroDifference = ZeroDifference
Formula.GrayLevel = GrayLevel
Formula.RoundForever = RoundForever
Formula.ClassificationMultiplier = ClassificationMultiplier
Formula.FormulaBaseXP = FormulaBaseXP
Formula.FormulaXP = FormulaXP
Formula.ContextKey = ContextKey
