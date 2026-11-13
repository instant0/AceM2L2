--[[---------------------------------------------------------------------------------
  Core/Commands.lua
  Slash commands, help, status, and Kill Story command routing.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Defaults = AceM2L2.Defaults
local Util = AceM2L2.Util

local defaults = Defaults.defaults
local XPTOOLTIP_DEFAULTS = Defaults.XPTOOLTIP_DEFAULTS
local CopyDefaults = Util.CopyDefaults
local SanitizeInteger = Util.SanitizeInteger

function AceM2L2:PrintHelp()
  self:SafePrint("Usage:")
  self:SafePrint("/acem2l2 xp on|off")
  self:SafePrint("/acem2l2 rep on|off")
  self:SafePrint("/acem2l2 xpevery <n>")
  self:SafePrint("/acem2l2 repevery <n>")
  self:SafePrint("/acem2l2 xmin <kills>")
  self:SafePrint("/acem2l2 repmin <value>")
  self:SafePrint("/acem2l2 rolling on|off")
  self:SafePrint("/acem2l2 window <n>")
  self:SafePrint("/acem2l2 precision <0-4>")
  self:SafePrint("/acem2l2 config")
  self:SafePrint("/acem2l2 debug on|off")
  self:SafePrint("/acem2l2 status")
  self:SafePrint("/acem2l2 reset")
  self:SafePrint("/acem2l2 history | window")
  self:SafePrint("/acem2l2 kills [name]")
  self:SafePrint("/acem2l2 xpt on|off")
  self:SafePrint("/acem2l2 xpt status")
  self:SafePrint("/acem2l2 xpt probe")
  self:SafePrint("/acem2l2 xpt ui")
  self:SafePrint("/acem2l2 xpt kills [name]")
  self:SafePrint("/acem2l2 xpt deaths [count]")
  self:SafePrint("/acem2l2 xpt respawns [name]")
  self:SafePrint("/acem2l2 xpt spots")
  self:SafePrint("/acem2l2 xpt quests")
  self:SafePrint("/acem2l2 xpt history [level]")
  self:SafePrint("/acem2l2 xpt rate [minutes]")
  self:SafePrint("/acem2l2 xpt dungeon")
  self:SafePrint("/acem2l2 xpt goal [set <level>|clear]")
  self:SafePrint("/acem2l2 xpt splits")
  self:SafePrint("/acem2l2 xpt economy")
  self:SafePrint("/acem2l2 xpt areas")
  self:SafePrint("/acem2l2 xpt heatmap [zone]")
  self:SafePrint("/acem2l2 xpt levels")
  self:SafePrint("/acem2l2 xpt session")
  self:SafePrint("/acem2l2 xpt stats")
  self:SafePrint("/acem2l2 xpt dump")
  self:SafePrint("/acem2l2 xpt table")
  self:SafePrint("/acem2l2 xpt theme aether|dark|midnight|class|contrast")
  self:SafePrint("/acem2l2 xpt scale 80-120")
  self:SafePrint("/acem2l2 xpt starttab overview|mobs|areas|levels|heatmap")
  self:SafePrint("/acem2l2 xpt minimap on|off|reset|status")
  self:SafePrint("/acem2l2 xpt debug on|off")
  self:SafePrint("/acem2l2 xpt recalibrate confirm")
  self:SafePrint("/acem2l2 xpt delete <mob name>")
  self:SafePrint("/acem2l2 xpt delete confirm <mob name>")
  self:SafePrint("/acem2l2 xpt deleteunknown confirm")
  self:SafePrint("/acem2l2 xpt reset confirm")
  self:SafePrint("/acem2l2 xpt resetkills confirm")
  self:SafePrint("/acem2l2 xpt config")
end

function AceM2L2:GetXPTooltipModule()
  local ok, module = pcall(self.GetModule, self, "XPTooltip", true)
  if ok then
    return module
  end
  return nil
end

function AceM2L2:PrintStatus()
  self:SafePrint("Client=" .. self:GetClientLabel() .. ", Interface=" .. tostring(self:GetInterfaceVersion()))
  self:SafePrint("XP=" .. tostring(self.db.xpEnabled) .. ", REP=" .. tostring(self.db.repEnabled)
    .. ", xpevery=" .. self.db.xpEveryNKills
    .. ", repevery=" .. self.db.repEveryNGains
    .. ", xmin=" .. self.db.xpMinKillsRemaining
    .. ", repmin=" .. self.db.repMinRemaining
    .. ", rolling=" .. tostring(self.db.useRollingXP)
    .. ", window=" .. self.db.rollingXPWindow
    .. ", precision=" .. self.db.precision
    .. ", debug=" .. tostring(self.db.debug)
    .. ", schema=" .. tostring(self.db.schemaVersion))
  local module = self:GetXPTooltipModule()
  if module and module.GetStatusText then
    local ok, status = pcall(module.GetStatusText, module)
    if ok and status then
      self:SafePrint("Kill Story=" .. tostring(status))
    end
  else
    self:SafePrint("Kill Story=module not loaded")
  end
  if self.lastError then
    self:SafePrint("LastError=" .. tostring(self.lastError))
  end
end

function AceM2L2:SetToggle(value, label)
  local arg = string.lower(value or "")
  if arg == "on" then
    return true
  elseif arg == "off" then
    return false
  end
  self:SafePrint("Usage: /acem2l2 " .. label .. " on|off")
  return nil
end

function AceM2L2:HandleSlashCommand(input)
  if not self.db then
    self:SafePrint("AceM2L2 is not initialized yet.")
    return
  end
  input = input or ""
  local cmd, arg = input:match("^(%S*)%s*(.-)$")
  cmd = string.lower(cmd or "")
  arg = string.lower(arg or "")

  if cmd == "" or cmd == "help" then
    self:PrintHelp()
  elseif cmd == "xp" then
    local value = self:SetToggle(arg, "xp")
    if value ~= nil then
      self.db.xpEnabled = value
    end
  elseif cmd == "rep" then
    local value = self:SetToggle(arg, "rep")
    if value ~= nil then
      self.db.repEnabled = value
    end
  elseif cmd == "xpevery" then
    self.db.xpEveryNKills = SanitizeInteger(tonumber(arg) or self.db.xpEveryNKills, 1, 1, 1000)
  elseif cmd == "repevery" then
    self.db.repEveryNGains = SanitizeInteger(tonumber(arg) or self.db.repEveryNGains, 1, 1, 1000)
  elseif cmd == "xmin" then
    self.db.xpMinKillsRemaining = SanitizeInteger(tonumber(arg) or self.db.xpMinKillsRemaining, 0, 0, 1000)
  elseif cmd == "repmin" then
    self.db.repMinRemaining = SanitizeInteger(tonumber(arg) or self.db.repMinRemaining, 0, 0, 50000)
  elseif cmd == "rolling" then
    local value = self:SetToggle(arg, "rolling")
    if value ~= nil then
      self.db.useRollingXP = value
    end
  elseif cmd == "window" then
    if arg == "" then
      local module = self:GetXPTooltipModule()
      if module and module.OpenUI then
        pcall(module.OpenUI, module)
      else
        self:SafePrint("Kill Story module is not available.")
      end
    else
      self.db.rollingXPWindow = SanitizeInteger(tonumber(arg) or self.db.rollingXPWindow, 1, 1, 100)
    end
  elseif cmd == "precision" then
    self.db.precision = SanitizeInteger(tonumber(arg) or self.db.precision, 2, 0, 4)
  elseif cmd == "config" or cmd == "options" then
    if self.optionsCategory and Settings and Settings.OpenToCategory then
      pcall(Settings.OpenToCategory, self.optionsCategory:GetID())
    else
      self:SafePrint("Settings panel is not available.")
    end
  elseif cmd == "history" then
    local module = self:GetXPTooltipModule()
    if module and module.OpenUI then
      pcall(module.OpenUI, module)
    else
      self:SafePrint("Kill Story module is not available.")
    end
  elseif cmd == "kills" then
    local module = self:GetXPTooltipModule()
    if module and module.HandleCommand then
      local ok, err = pcall(module.HandleCommand, module, "kills " .. (arg or ""))
      if not ok then
        self:ReportError("Kill Story command", err)
      end
    else
      self:SafePrint("Kill Story module is not available.")
    end
  elseif cmd == "xpt" or cmd == "xptooltip" then
    local module = self:GetXPTooltipModule()
    if module and module.HandleCommand then
      local ok, err = pcall(module.HandleCommand, module, arg)
      if not ok then
        self:ReportError("Kill Story command", err)
      end
    else
      self:SafePrint("Kill Story module is not available.")
    end
  elseif cmd == "debug" then
    local value = self:SetToggle(arg, "debug")
    if value ~= nil then
      self.db.debug = value
    end
  elseif cmd == "reset" then
    for key, value in pairs(defaults.profile) do
      if key == "xpTooltip" then
        self.db.xpTooltip = CopyDefaults(XPTOOLTIP_DEFAULTS)
      else
        self.db[key] = value
      end
    end
    self.xpSamples = {}
    self.xpKillCounter = 0
    self.repGainCounter = 0
    self.lastError = nil
    local module = self:GetXPTooltipModule()
    if module and module.Refresh then
      pcall(module.Refresh, module)
    end
    if module and module.ApplyTheme then
      pcall(module.ApplyTheme, module)
    end
    if module and module.ui and module.ui.SetScale and self.db.xpTooltip.scale then
      pcall(module.ui.SetScale, module.ui, self.db.xpTooltip.scale)
    end
    self:RefreshOptionsPanel()
    self:SafePrint("Settings reset.")
  elseif cmd == "status" then
    self:PrintStatus()
  else
    self:PrintHelp()
    return
  end

  self:RefreshOptionsPanel()
end
