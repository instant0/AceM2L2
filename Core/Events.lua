--[[--------------------------------------------------------------------------------
  Core/Events.lua
  Addon lifecycle, saved-variable setup, and level/world event handlers.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Defaults = AceM2L2.Defaults
local Util = AceM2L2.Util

local defaults = Defaults.defaults
local XPTOOLTIP_DEFAULTS = Defaults.XPTOOLTIP_DEFAULTS
local XPTOOLTIP_UI_DEFAULTS = Defaults.XPTOOLTIP_UI_DEFAULTS
local XPTOOLTIP_MINIMAP_DEFAULTS = Defaults.XPTOOLTIP_MINIMAP_DEFAULTS
local CopyDefaults = Util.CopyDefaults
local GetUnitXP = Util.GetUnitXP

function AceM2L2:OnInitialize()
  if type(AceM2L2DB) ~= "table" then
    AceM2L2DB = {}
  end
  if type(AceM2L2DB.profile) ~= "table" then
    AceM2L2DB.profile = {}
  end

  local oldSchema = tonumber(AceM2L2DB.profile.schemaVersion) or 0

  for key, value in pairs(defaults.profile) do
    if key ~= "xpTooltip" and AceM2L2DB.profile[key] == nil then
      AceM2L2DB.profile[key] = value
    end
  end

  if type(AceM2L2DB.profile.xpTooltip) ~= "table" then
    AceM2L2DB.profile.xpTooltip = CopyDefaults(XPTOOLTIP_DEFAULTS)
  else
    for key, value in pairs(XPTOOLTIP_DEFAULTS) do
      if AceM2L2DB.profile.xpTooltip[key] == nil then
        if type(value) == "table" then
          AceM2L2DB.profile.xpTooltip[key] = CopyDefaults(value)
        else
          AceM2L2DB.profile.xpTooltip[key] = value
        end
      end
    end
    if type(AceM2L2DB.profile.xpTooltip.ui) ~= "table" then
      AceM2L2DB.profile.xpTooltip.ui = CopyDefaults(XPTOOLTIP_UI_DEFAULTS)
    else
      for key, value in pairs(XPTOOLTIP_UI_DEFAULTS) do
        if AceM2L2DB.profile.xpTooltip.ui[key] == nil then
          AceM2L2DB.profile.xpTooltip.ui[key] = value
        end
      end
    end
    if type(AceM2L2DB.profile.xpTooltip.minimap) ~= "table" then
      AceM2L2DB.profile.xpTooltip.minimap = CopyDefaults(XPTOOLTIP_MINIMAP_DEFAULTS)
    else
      for key, value in pairs(XPTOOLTIP_MINIMAP_DEFAULTS) do
        if AceM2L2DB.profile.xpTooltip.minimap[key] == nil then
          AceM2L2DB.profile.xpTooltip.minimap[key] = value
        end
      end
    end
  end

  if type(AceM2L2CharDB) ~= "table" then
    AceM2L2CharDB = {}
  end

  self.db = AceM2L2DB.profile
  self.lastError = nil
  self.lastSchemaVersion = oldSchema
  local ok, err = pcall(self.SanitizeProfile, self)
  if not ok then
    self.lastError = "SanitizeProfile: " .. tostring(err)
  end
  self.xpSamples = {}
  self.xpKillCounter = 0
  self.repGainCounter = 0
  self.factionStandings = {}
  self.factionCache = nil
  self.factionCacheTime = 0
  self.lastXP = nil
  self.lastCreatureName = nil
  self.lastXPSource = nil
  self.lastXPInfoTime = 0
  self.useStandingEvent = false
  self.optionsFailed = false

  if self.RegisterChatCommand then
    pcall(self.RegisterChatCommand, self, "acem2l2", "HandleSlashCommand")
    pcall(self.RegisterChatCommand, self, "am2", "HandleSlashCommand")
  end

  self:SafeCreateOptionsPanel()
end

function AceM2L2:OnEnable()
  self:SafeRegister("CHAT_MSG_COMBAT_XP_GAIN", "C")
  self:SafeRegister("PLAYER_XP_UPDATE", "OnPlayerXPUpdate")
  self:SafeRegister("PLAYER_LEVEL_UP", "OnLevelUp")
  self:SafeRegister("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
  self:SafeRegister("ADDON_LOADED", "OnAddonLoaded")

  -- FACTION_STANDING_CHANGED is available on Midnight 12.1.x and Forever
  -- 1.60.x and is the locale-independent source for reputation changes.
  self.useStandingEvent = self:SafeRegister("FACTION_STANDING_CHANGED", "OnFactionStandingChanged")
  self:SafeRegister("CHAT_MSG_COMBAT_FACTION_CHANGE", "RF")

  self.lastXP = GetUnitXP()
  self.lastCreatureName = nil
  self.lastXPSource = nil
  self.lastXPInfoTime = 0
  self:SafeInvoke("RefreshFactionBaseline", "RefreshFactionBaseline")

  if not self.optionsCategory then
    self:SafeCreateOptionsPanel()
  end
end

function AceM2L2:OnDisable()
  self:SafeUnregister("CHAT_MSG_COMBAT_XP_GAIN")
  self:SafeUnregister("CHAT_MSG_COMBAT_FACTION_CHANGE")
  self:SafeUnregister("PLAYER_XP_UPDATE")
  self:SafeUnregister("PLAYER_LEVEL_UP")
  self:SafeUnregister("PLAYER_ENTERING_WORLD")
  self:SafeUnregister("ADDON_LOADED")
  self:SafeUnregister("FACTION_STANDING_CHANGED")
end

function AceM2L2:OnAddonLoaded()
  self:SafeInvoke("ADDON_LOADED", "HandleAddonLoaded")
end

function AceM2L2:HandleAddonLoaded()
  if not self.optionsCategory then
    self:SafeCreateOptionsPanel()
  end
end

function AceM2L2:OnEnteringWorld()
  self:SafeInvoke("PLAYER_ENTERING_WORLD", "HandleEnteringWorld")
end

function AceM2L2:HandleEnteringWorld()
  self.lastXP = GetUnitXP()
  self.lastCreatureName = nil
  self.lastXPSource = nil
  self.lastXPInfoTime = 0
  self.factionCache = nil
  self:SafeInvoke("RefreshFactionBaseline", "RefreshFactionBaseline")
end

function AceM2L2:OnLevelUp()
  self:SafeInvoke("PLAYER_LEVEL_UP", "HandleLevelUp")
end

function AceM2L2:HandleLevelUp()
  self.xpSamples = {}
  self.xpKillCounter = 0
  self.lastXP = GetUnitXP()
  self.lastCreatureName = nil
  self.lastXPSource = nil
  self.lastXPInfoTime = 0
end
