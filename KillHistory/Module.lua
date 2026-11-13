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
    settings = {}
    profile.xpTooltip = settings
  end

  local function fillDefaults(target, defaults)
    for key, value in pairs(defaults) do
      if type(value) == "table" then
        if type(target[key]) ~= "table" then
          target[key] = Util.CopyTable(value)
        else
          fillDefaults(target[key], value)
        end
      elseif target[key] == nil then
        target[key] = value
      end
    end
  end

  fillDefaults(settings, Util.DEFAULT_SETTINGS)
  if type(settings.ui) ~= "table" then
    settings.ui = {}
  end
  fillDefaults(settings.ui, Util.DEFAULT_UI)
  if type(settings.minimap) ~= "table" then
    settings.minimap = {}
  end
  fillDefaults(settings.minimap, Util.DEFAULT_MINIMAP)
  return settings
end

function XPTooltip:CheckCompatibility()
  local reasons = {}
  local profile = self.clientProfile or self:GetClientProfile()
  if not profile then
    reasons[#reasons + 1] = "unsupported client"
  elseif not profile:Supports("hasKillTracking") then
    reasons[#reasons + 1] = "kill tracking disabled for this client"
  end

  local required = {}
  if profile and profile.GetRequiredGlobals then
    required = profile:GetRequiredGlobals() or {}
  end
  for _, globalName in ipairs(required) do
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

  -- A missing tooltip hook disables tooltip lines only, not kill tracking.
  return #reasons == 0, table.concat(reasons, ", "), hasProcessor, hasHook
end

function XPTooltip:OnInitialize()
  self:RefreshClient()
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
  self:RefreshClient()
  self:EnsureDB()
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
      self:ReportError("RegisterEvent " .. tostring(entry[1]), err, false)
    end
  end

  self:InstallTooltipHook()
  self.lastXP = self:GetXP()
  self.lastPool = self:GetRestedPool()
  self.lastTarget = self:CaptureUnit("target")
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

function XPTooltip:ReportError(context, err, countTowardCircuit)
  local message = tostring(context or "error") .. ": " .. tostring(err)
  if #message > 400 then
    message = message:sub(1, 400)
  end
  self.lastError = message
  local now = Util.Now()
  if self.lastErrorTime and (now - self.lastErrorTime) > 60 then
    self.circuitErrors = 0
  end
  self.lastErrorTime = now
  if countTowardCircuit ~= false then
    self.circuitErrors = (self.circuitErrors or 0) + 1
  end
  if self.circuitErrors >= 5 then
    self.active = false
    self.autoDisabled = true
    self.autoDisableReason = "handler errors"
    pcall(self.UnregisterAllEvents, self)
    self.installed = false
    self:CloseUI()
    self:HideMinimapIcon()
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
    local profile = self.clientProfile or self:GetClientProfile()
    local mode = profile and profile:GetStatusLabel() or "unknown client"
    local hook = "no tooltip hook"
    if self.tooltipHookInstalled then
      hook = self.hasProcessor and "TooltipDataProcessor" or "OnTooltipSetUnit"
    end
    return "active (" .. mode .. ", " .. hook .. ")"
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
