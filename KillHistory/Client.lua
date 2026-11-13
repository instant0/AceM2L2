--[[---------------------------------------------------------------------------------
  KillHistory/Client.lua
  Client profile registry and capability queries.

  Shared Kill Story code asks a profile for capabilities instead of branching on
  WOW_PROJECT_ID. Client-specific XP formulas/API policy live in Clients/.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Client = XPTooltip.Client or {}
XPTooltip.Client = Client

local Defaults = AceM2L2.Defaults or {}
local CAMELOT_PROJECT_ID = Defaults.CAMELOT_PROJECT_ID or WOW_PROJECT_CAMELOT or 18
local MAINLINE_PROJECT_ID = Defaults.MAINLINE_PROJECT_ID or WOW_PROJECT_MAINLINE or 1

-- Ordered so status/probe output is stable and easy to compare between clients.
Client.CAPABILITIES = {
  "hasKillTracking",
  "hasKillIdentity",
  "hasNameIdentity",
  "hasGUIDIdentity",
  "hasMapIdentity",
  "hasInstanceInfo",
  "hasMapPosition",
  "hasNamePlateAPI",
  "hasMoney",
  "hasLootValue",
  "hasGearCompare",
  "hasPlayerXPState",
  "hasLevelXPState",
  "hasXPFormula",
  "hasPerMobXP",
  "hasObservedXP",
  "hasTooltipHook",
  "hasTooltipXP",
  "hasKillsToLevel",
  "hasRestedPool",
  "hasWellFed",
  "hasWellRestedAura",
  "hasGroupXP",
  "hasGroupLearning",
  "hasModel",
  "hasAuraAPI",
  "hasReadableBooleans",
}

Client.CAPABILITY_LABELS = {
  hasKillTracking = "killTracking",
  hasKillIdentity = "killIdentity",
  hasNameIdentity = "nameIdentity",
  hasGUIDIdentity = "guidIdentity",
  hasMapIdentity = "mapIdentity",
  hasInstanceInfo = "instanceInfo",
  hasMapPosition = "mapPosition",
  hasNamePlateAPI = "namePlateAPI",
  hasMoney = "money",
  hasLootValue = "lootValue",
  hasGearCompare = "gearCompare",
  hasPlayerXPState = "playerXPState",
  hasLevelXPState = "levelXPState",
  hasXPFormula = "formula",
  hasPerMobXP = "perMobXP",
  hasObservedXP = "observedXP",
  hasTooltipHook = "tooltipHook",
  hasTooltipXP = "tooltipXP",
  hasKillsToLevel = "killsToLevel",
  hasRestedPool = "restedPool",
  hasWellFed = "wellFed",
  hasWellRestedAura = "wellRestedAura",
  hasGroupXP = "groupXP",
  hasGroupLearning = "groupLearning",
  hasModel = "model",
  hasAuraAPI = "auraAPI",
  hasReadableBooleans = "readableBooleans",
}

Client.profiles = Client.profiles or {}
Client.byProject = Client.byProject or {}

function Client:Register(profile)
  if type(profile) ~= "table" or not profile.id then
    return
  end
  self.profiles[profile.id] = profile
  if profile.projectID then
    self.byProject[tonumber(profile.projectID)] = profile
  end
end

function Client:GetProjectID()
  return tonumber(WOW_PROJECT_ID) or 0
end

function Client:Detect(projectID)
  return self.byProject[tonumber(projectID) or 0]
end

function Client:GetProfile()
  return self:Detect(self:GetProjectID())
end

--[[--------------------------------------------------------------------------------
  Module helpers
------------------------------------------------------------------------------------]]

function XPTooltip:GetProjectID()
  return Client:GetProjectID()
end

function XPTooltip:GetClientProfile()
  return Client:GetProfile()
end

function XPTooltip:RefreshClient()
  self.projectID = Client:GetProjectID()
  self.clientProfile = Client:Detect(self.projectID)
  return self.clientProfile
end

function XPTooltip:Supports(capability)
  local profile = self.clientProfile or self:GetClientProfile()
  return profile ~= nil and profile:Supports(capability) == true
end

function XPTooltip:GetCapabilitySummary()
  local profile = self.clientProfile or self:GetClientProfile()
  if not profile then
    return "none"
  end
  local parts = {}
  for _, name in ipairs(Client.CAPABILITIES) do
    local label = Client.CAPABILITY_LABELS[name] or name
    parts[#parts + 1] = label .. "=" .. (profile:Supports(name) and "yes" or "no")
  end
  return table.concat(parts, " ")
end
