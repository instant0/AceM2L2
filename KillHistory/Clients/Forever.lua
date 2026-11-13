--[[---------------------------------------------------------------------------------
  KillHistory/Clients/Forever.lua
  Forever 1.60.1 profile: XP formula, gray/ZD rules, group prior, and capabilities.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Client = XPTooltip.Client
local Defaults = AceM2L2.Defaults or {}

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

local Profile = {
  id = "forever",
  name = "Forever",
  projectID = Defaults.CAMELOT_PROJECT_ID or WOW_PROJECT_CAMELOT or 18,
  capabilities = {
    hasKillTracking = true,
    hasKillIdentity = true,
    hasNameIdentity = true,
    hasGUIDIdentity = true,
    hasMapIdentity = true,
    hasPlayerXPState = true,
    hasLevelXPState = true,
    hasXPFormula = true,
    hasPerMobXP = true,
    hasObservedXP = true,
    hasTooltipHook = true,
    hasTooltipXP = true,
    hasKillsToLevel = true,
    hasRestedPool = true,
    hasWellFed = true,
    hasWellRestedAura = true,
    hasGroupXP = true,
    hasGroupLearning = false,
    hasModel = true,
    hasAuraAPI = true,
    hasReadableBooleans = true,
  },
}

function Profile:Supports(capability)
  return self.capabilities[capability] == true
end

function Profile:GetRequiredGlobals()
  return {
    "UnitXP", "UnitXPMax", "UnitLevel", "UnitName", "UnitGUID",
    "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
    "UnitCreatureType", "UnitCanAttack",
  }
end

function Profile:GetMaxLevel()
  local maxLevel
  if type(GetMaxPlayerLevel) == "function" then
    local ok, value = pcall(GetMaxPlayerLevel)
    if ok and type(value) == "number" then
      maxLevel = value
    end
  end
  if not maxLevel and type(GetMaxLevelForPlayer) == "function" then
    local ok, value = pcall(GetMaxLevelForPlayer)
    if ok and type(value) == "number" then
      maxLevel = value
    end
  end
  return maxLevel or 60
end

function Profile:GetFormula(playerLevel, mobLevel, classification)
  return FormulaXP(playerLevel, mobLevel, classification)
end

function Profile:GetBaseXP(playerLevel, mobLevel)
  return FormulaBaseXP(playerLevel, mobLevel)
end

function Profile:Round(value)
  return RoundForever(value)
end

function Profile:GetGroupPrior(groupSize)
  return CLASSIC_GROUP_PRIOR[min(groupSize or 1, 5)] or 1
end

function Profile:UsesGroupLearning()
  return GROUP_CALIBRATION_ENABLED == true
end

function Profile:GetStatusLabel()
  return "Forever (full)"
end

function Profile:GetEmptyStateText()
  return "Kill a mob to start the history."
end

Profile.ZERO_DIFFERENCE = ZERO_DIFFERENCE
Profile.CLASSIC_GROUP_PRIOR = CLASSIC_GROUP_PRIOR
Profile.GROUP_CALIBRATION_ENABLED = GROUP_CALIBRATION_ENABLED
Profile.ZeroDifference = ZeroDifference
Profile.GrayLevel = GrayLevel
Profile.RoundForever = RoundForever
Profile.ClassificationMultiplier = ClassificationMultiplier
Profile.FormulaBaseXP = FormulaBaseXP
Profile.FormulaXP = FormulaXP

Client:Register(Profile)
