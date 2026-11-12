--[[---------------------------------------------------------------------------------
  KillHistory/Module.lua
  Module creation and shared helper namespaces.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2:NewModule("XPTooltip", "AceEvent-3.0")

AceM2L2.KillHistory = XPTooltip

XPTooltip.Util = XPTooltip.Util or {}
XPTooltip.Formula = XPTooltip.Formula or {}
XPTooltip.UI = XPTooltip.UI or {}

local Util = XPTooltip.Util
local CAMELOT_PROJECT_ID = WOW_PROJECT_CAMELOT or 18

function XPTooltip:GetSettings()
  if type(AceM2L2DB) ~= "table" then
    AceM2L2DB = {}
  end
  if type(AceM2L2DB.profile) ~= "table" then
    AceM2L2DB.profile = {}
  end
  local profile = AceM2L2DB.profile
  local settings = profile.xpTooltip
  if type(settings) ~= "table" then
    settings = Util.CopyTable(Util.DEFAULT_SETTINGS)
    settings.ui = Util.CopyTable(Util.DEFAULT_UI)
    profile.xpTooltip = settings
  end
  if type(settings.ui) ~= "table" then
    settings.ui = Util.CopyTable(Util.DEFAULT_UI)
  end
  if type(settings.minimap) ~= "table" then
    settings.minimap = Util.CopyTable(Util.DEFAULT_MINIMAP)
  end
  if settings.theme == nil then
    settings.theme = "aether"
  end
  if settings.scale == nil then
    settings.scale = 1.0
  end
  if settings.startTab == nil then
    settings.startTab = "overview"
  end
  if settings.sound == nil then
    settings.sound = true
  end
  return settings
end

function XPTooltip:CheckCompatibility()
  local reasons = {}
  local isForever = WOW_PROJECT_ID == CAMELOT_PROJECT_ID
  if not isForever then
    reasons[#reasons + 1] = "not Forever"
  end
  for _, globalName in ipairs({
    "UnitXP", "UnitXPMax", "UnitLevel", "UnitName", "UnitGUID",
    "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
    "UnitCreatureType", "UnitCanAttack",
  }) do
    if type(_G[globalName]) ~= "function" then
      reasons[#reasons + 1] = "missing " .. globalName
    end
  end

  local hasProcessor = TooltipDataProcessor
    and TooltipDataProcessor.AddTooltipPostCall
    and Enum
    and Enum.TooltipDataType
    and Enum.TooltipDataType.Unit ~= nil
  local hasHook = GameTooltip and type(GameTooltip.HookScript) == "function"
  if not hasProcessor and not hasHook then
    reasons[#reasons + 1] = "no tooltip hook"
  end

  return #reasons == 0, table.concat(reasons, ", "), hasProcessor, hasHook
end

function XPTooltip:OnInitialize()
  self:EnsureDB()
  self.settings = self:GetSettings()
  self.pendingDeaths = {}
  self.recentChatKills = {}
  self.pendingChatXP = {}
  self.lastXP = nil
  self.lastPool = nil
  self.poolBeforeKill = nil
  self.lastTarget = nil
  self.lastMouseover = nil
  self.lastXPChatAt = 0
  self.lastXPUpdateAt = 0
  self.buffCacheTime = 0
  self.modelYaw = 0
  self.ui = nil
  self.installed = false
  self.active = false
  self.autoDisabled = false
  self.autoDisableReason = nil
  self.circuitErrors = 0
  self.dataGeneration = 0
  self.searchText = ""
end

function XPTooltip:OnEnable()
  self:EnsureDB()
  self:Refresh()
  if self:IsActive() then
    self:StartSession()
  end
end

function XPTooltip:OnDisable()
  self.active = false
  if self.installed then
    pcall(self.UnregisterAllEvents, self)
    self.installed = false
  end
  for _, entry in ipairs(self.pendingChatXP or {}) do
    entry.canceled = true
  end
  self.pendingDeaths = {}
  self.recentChatKills = {}
  self.pendingChatXP = {}
  self:CloseUI()
  self:HideMinimapIcon()
end

function XPTooltip:Refresh()
  self.settings = self:GetSettings()
  if not self.settings then
    self.active = false
    self.autoDisabled = true
    self.autoDisableReason = "settings unavailable"
    return
  end

  local compatible, reason, hasProcessor, hasHook = self:CheckCompatibility()
  self.hasProcessor = hasProcessor
  self.hasHook = hasHook

  if not compatible then
    self.active = false
    self.autoDisabled = true
    self.autoDisableReason = reason
    if self.installed then
      pcall(self.UnregisterAllEvents, self)
      self.installed = false
    end
    self:CloseUI()
    self:HideMinimapIcon()
    return
  end

  self.autoDisabled = false
  self.autoDisableReason = nil

  if not self.settings.enabled then
    self.active = false
    if self.installed then
      pcall(self.UnregisterAllEvents, self)
      self.installed = false
    end
    self:CloseUI()
    self:HideMinimapIcon()
    return
  end

  self:Install()
  if self.autoDisabled or not self.tooltipHookInstalled then
    return
  end
  self.active = true
  self:InitializeMinimap()
  self:RefreshUI()
end

function XPTooltip:Install()
  if self.installed then
    return
  end
  self.installed = true

  local events = {
    { "CHAT_MSG_COMBAT_XP_GAIN", "OnXPChat" },
    { "PLAYER_XP_UPDATE", "OnPlayerXPUpdate" },
    { "UNIT_DIED", "OnUnitDied" },
    { "PLAYER_TARGET_CHANGED", "OnTargetChanged" },
    { "UPDATE_MOUSEOVER_UNIT", "OnMouseoverChanged" },
    { "ZONE_CHANGED_NEW_AREA", "OnZoneChanged" },
    { "PLAYER_LEVEL_UP", "OnLevelUp" },
    { "PLAYER_ENTERING_WORLD", "OnEnteringWorld" },
    { "PLAYER_LOGIN", "OnLogin" },
    { "ENABLE_XP_GAIN", "OnXPGainEnabled" },
    { "DISABLE_XP_GAIN", "OnXPGainDisabled" },
    { "PLAYER_MAX_LEVEL_UPDATE", "OnMaxLevelUpdate" },
  }
  for _, entry in ipairs(events) do
    local ok, err = pcall(self.RegisterEvent, self, entry[1], entry[2])
    if not ok then
      self:ReportError("RegisterEvent " .. tostring(entry[1]), err)
    end
  end

  self:InstallTooltipHook()
  self.lastXP = self:GetXP()
  self.lastPool = self:GetRestedPool()
  self.lastTarget = self:CaptureUnit("target")

  if not self.tooltipHookInstalled then
    self.active = false
    self.autoDisabled = true
    self.autoDisableReason = "tooltip hook failed"
    pcall(self.UnregisterAllEvents, self)
    self.installed = false
  end
end

function XPTooltip:SetUserEnabled(value)
  local settings = self:GetSettings()
  if not settings then
    return
  end
  local wasActive = self:IsActive()
  settings.enabled = value and true or false
  self.settings = settings
  self:Refresh()
  if settings.enabled and not wasActive and self:IsActive() then
    self:StartSession()
  end
  if settings.enabled and self.autoDisabled then
    AceM2L2:SafePrint("Kill History auto-disabled: " .. tostring(self.autoDisableReason or "incompatible client"))
  end
end

function XPTooltip:IsActive()
  return self.active == true
    and self.settings ~= nil
    and self.settings.enabled == true
    and not self.autoDisabled
end

function XPTooltip:ReportError(context, err)
  local message = tostring(context or "error") .. ": " .. tostring(err)
  if #message > 400 then
    message = message:sub(1, 400)
  end
  self.lastError = message
  self.circuitErrors = (self.circuitErrors or 0) + 1
  if self.circuitErrors >= 5 then
    self.active = false
    self.autoDisabled = true
    self.autoDisableReason = "handler errors"
    pcall(self.UnregisterAllEvents, self)
    self.installed = false
    self:CloseUI()
  end
  if self.settings and self.settings.debug then
    AceM2L2:SafePrint("|cffff5555Kill History " .. message .. "|r")
  end
end

function XPTooltip:GetStatusText()
  local settings = self:GetSettings()
  if not settings then
    return "settings unavailable"
  end
  if not settings.enabled then
    return "disabled by user"
  end
  if self.autoDisabled then
    return "auto-disabled (" .. tostring(self.autoDisableReason or "incompatible") .. ")"
  end
  if self.active then
    return "active (" .. (self.hasProcessor and "TooltipDataProcessor" or "OnTooltipSetUnit") .. ")"
  end
  return "inactive"
end

function XPTooltip:ToggleUI()
  if self.ui and self.ui:IsShown() then
    self:CloseUI()
  else
    self:OpenUI()
  end
end
