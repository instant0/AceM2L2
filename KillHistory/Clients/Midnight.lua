--[[---------------------------------------------------------------------------------
  KillHistory/Clients/Midnight.lua
  Midnight 12.1.5 profile: counts-only tracking.

  Midnight starts with kill/area/level/session counts. Formula estimates,
  calibration, kills-to-level, rested, and buff models stay off until live
  probes prove the data is readable and attributable.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Client = XPTooltip.Client
local Defaults = AceM2L2.Defaults or {}

local function Round(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local Profile = {
  id = "midnight",
  name = "Midnight",
  projectID = Defaults.MAINLINE_PROJECT_ID or WOW_PROJECT_MAINLINE or 1,
  capabilities = {
    hasKillTracking = true,
    hasKillIdentity = true,
    hasNameIdentity = true,
    hasGUIDIdentity = true,
    hasMapIdentity = true,
    hasPlayerXPState = false,
    hasLevelXPState = true,
    hasXPFormula = false,
    hasPerMobXP = false,
    hasObservedXP = false,
    hasTooltipHook = true,
    hasTooltipXP = false,
    hasKillsToLevel = false,
    hasRestedPool = false,
    hasWellFed = false,
    hasWellRestedAura = false,
    hasGroupXP = false,
    hasGroupLearning = false,
    hasModel = true,
    hasAuraAPI = false,
    hasReadableBooleans = false,
  },
}

function Profile:Supports(capability)
  return self.capabilities[capability] == true
end

function Profile:GetRequiredGlobals()
  -- Counts-only tracking does not require XP or tooltip APIs.
  return { "UnitExists", "UnitName", "UnitGUID", "UnitLevel" }
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
  return maxLevel or 90
end

function Profile:GetFormula()
  return nil
end

function Profile:GetBaseXP()
  return nil
end

function Profile:Round(value)
  return Round(value)
end

function Profile:GetGroupPrior()
  return 1
end

function Profile:UsesGroupLearning()
  return false
end

function Profile:GetStatusLabel()
  return "Midnight (counts only)"
end

function Profile:GetEmptyStateText()
  return "Kill a mob to start the history."
end

Client:Register(Profile)
