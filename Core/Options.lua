--[[---------------------------------------------------------------------------------
  Core/Options.lua
  Settings API options panel registration and refresh.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Util = AceM2L2.Util

local SanitizeBoolean = Util.SanitizeBoolean
local SanitizeInteger = Util.SanitizeInteger

function AceM2L2:SafeCreateOptionsPanel()
  if self.optionsCategory or self.optionsFailed then
    return
  end
  local ok, err = pcall(self.CreateOptionsPanel, self)
  if not ok then
    self.optionsFailed = true
    if self.db and self.db.debug then
      self:SafePrint("Could not create options panel: " .. tostring(err))
    end
  end
end

function AceM2L2:CreateOptionsPanel()
  if self.optionsCategory then
    return
  end

  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory
    and Settings.RegisterProxySetting and Settings.CreateCheckbox and Settings.CreateSlider
    and Settings.CreateSliderOptions) then
    return
  end

  local category = Settings.RegisterVerticalLayoutCategory("Ace Mobs 2 Level 2")
  self.optionSettings = {}

  local module = self:GetXPTooltipModule()
  local function supports(capability)
    return module and module.Supports and module:Supports(capability)
  end

  local function addSetting(name, variable, defaultValue, getter, setter)
    local setting = Settings.RegisterProxySetting(
      category,
      variable,
      type(defaultValue),
      name,
      defaultValue,
      getter,
      setter
    )
    self.optionSettings[#self.optionSettings + 1] = setting
    return setting
  end

  local function addCheckbox(name, variable, defaultValue, getter, setter, tooltip)
    local setting = addSetting(name, variable, defaultValue, getter, setter)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  local function addSlider(name, variable, defaultValue, minValue, maxValue, step, getter, setter, tooltip)
    local setting = addSetting(name, variable, defaultValue, getter, setter)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
      and options and type(options.SetLabelFormatter) == "function" then
      pcall(options.SetLabelFormatter, options, MinimalSliderWithSteppersMixin.Label.Right)
    end
    Settings.CreateSlider(category, setting, options, tooltip)
  end

  addCheckbox(
    "Enable XP messages",
    "ACEM2L2_XP_ENABLED",
    true,
    function() return self.db.xpEnabled end,
    function(value) self.db.xpEnabled = SanitizeBoolean(value, true) end,
    "Show kills-to-level messages."
  )

  addCheckbox(
    "Enable reputation messages",
    "ACEM2L2_REP_ENABLED",
    true,
    function() return self.db.repEnabled end,
    function(value) self.db.repEnabled = SanitizeBoolean(value, true) end,
    "Show faction gain estimates."
  )

  addCheckbox(
    "Use rolling average XP",
    "ACEM2L2_ROLLING_XP",
    true,
    function() return self.db.useRollingXP end,
    function(value) self.db.useRollingXP = SanitizeBoolean(value, true) end,
    "Estimate using the average of recent kills instead of the last kill."
  )

  addSlider(
    "XP output every N kills",
    "ACEM2L2_XP_EVERY",
    1,
    1,
    20,
    1,
    function() return self:GetNumberSetting("xpEveryNKills", 1, 1, 1000, true) end,
    function(value) self.db.xpEveryNKills = SanitizeInteger(value, 1, 1, 1000) end,
    "Only print the XP estimate every N kills."
  )

  addSlider(
    "Reputation output every N gains",
    "ACEM2L2_REP_EVERY",
    1,
    1,
    20,
    1,
    function() return self:GetNumberSetting("repEveryNGains", 1, 1, 1000, true) end,
    function(value) self.db.repEveryNGains = SanitizeInteger(value, 1, 1, 1000) end,
    "Only print the reputation estimate every N gains."
  )

  addSlider(
    "Rolling average window",
    "ACEM2L2_XP_WINDOW",
    5,
    1,
    20,
    1,
    function() return self:GetNumberSetting("rollingXPWindow", 5, 1, 100, true) end,
    function(value) self.db.rollingXPWindow = SanitizeInteger(value, 5, 1, 100) end,
    "Number of recent kills used for the rolling average."
  )

  addSlider(
    "Decimal precision",
    "ACEM2L2_PRECISION",
    2,
    0,
    4,
    1,
    function() return self:GetNumberSetting("precision", 2, 0, 4, true) end,
    function(value) self.db.precision = SanitizeInteger(value, 2, 0, 4) end,
    "Decimal places used in the chat output."
  )

  addSlider(
    "Minimum kills remaining",
    "ACEM2L2_XP_MIN",
    0,
    0,
    100,
    1,
    function() return self:GetNumberSetting("xpMinKillsRemaining", 0, 0, nil, true) end,
    function(value) self.db.xpMinKillsRemaining = SanitizeInteger(value, 0, 0, 1000000) end,
    "Do not print the XP estimate below this remaining kill count."
  )

  addSlider(
    "Minimum reputation remaining",
    "ACEM2L2_REP_MIN",
    0,
    0,
    50000,
    50,
    function() return self:GetNumberSetting("repMinRemaining", 0, 0, nil, true) end,
    function(value) self.db.repMinRemaining = SanitizeInteger(value, 0, 0, 100000000) end,
    "Do not print the reputation estimate below this remaining value."
  )

  addCheckbox(
    "Enable Kill History module",
    "ACEM2L2_XPTOOLTIP_ENABLED",
    true,
    function() return self.db.xpTooltip.enabled end,
    function(value)
      self.db.xpTooltip.enabled = SanitizeBoolean(value, true)
      local module = self:GetXPTooltipModule()
      if module then
        pcall(module.SetUserEnabled, module, self.db.xpTooltip.enabled)
      end
    end,
    "Show XP, kills-to-level, and per-mob kill history on unit tooltips."
  )

  addCheckbox(
    "Kill History: show minimap icon",
    "ACEM2L2_XPTOOLTIP_MINIMAP",
    true,
    function()
      return not (self.db.xpTooltip.minimap and self.db.xpTooltip.minimap.hide)
    end,
    function(value)
      if type(self.db.xpTooltip.minimap) ~= "table" then
        self.db.xpTooltip.minimap = { hide = false, minimapPos = 200, lock = false }
      end
      self.db.xpTooltip.minimap.hide = not SanitizeBoolean(value, true)
      local module = self:GetXPTooltipModule()
      if module then
        pcall(module.InitializeMinimap, module)
        pcall(module.UpdateMinimapVisibility, module)
      end
    end,
    "Show the AceM2L2 launcher icon around the minimap."
  )

  if supports("hasTooltipXP") then
    addCheckbox(
      "Kill History: show XP",
      "ACEM2L2_XPTOOLTIP_SHOW_XP",
      true,
      function() return self.db.xpTooltip.showXP end,
      function(value) self.db.xpTooltip.showXP = SanitizeBoolean(value, true) end,
      "Show the estimated XP value on the mob tooltip."
    )

    addCheckbox(
      "Kill History: show percent of level",
      "ACEM2L2_XPTOOLTIP_SHOW_PERCENT",
      true,
      function() return self.db.xpTooltip.showPercent end,
      function(value) self.db.xpTooltip.showPercent = SanitizeBoolean(value, true) end,
      "Show how much of the current level one kill is worth."
    )

  end

  if supports("hasKillsToLevel") then
    addCheckbox(
      "Kill History: show kills to level",
      "ACEM2L2_XPTOOLTIP_SHOW_KILLS",
      true,
      function() return self.db.xpTooltip.showKillsToLevel end,
      function(value) self.db.xpTooltip.showKillsToLevel = SanitizeBoolean(value, true) end,
      "Show how many kills of this mob remain to level."
    )
  end

  addCheckbox(
    "Kill History: show kill count",
    "ACEM2L2_XPTOOLTIP_SHOW_KILL_COUNT",
    true,
    function() return self.db.xpTooltip.showKillCount end,
    function(value) self.db.xpTooltip.showKillCount = SanitizeBoolean(value, true) end,
    "Show how many of this mob you have already killed."
  )

  if supports("hasRestedPool") then
    addCheckbox(
      "Kill History: show rested",
      "ACEM2L2_XPTOOLTIP_SHOW_RESTED",
      true,
      function() return self.db.xpTooltip.showRested end,
      function(value) self.db.xpTooltip.showRested = SanitizeBoolean(value, true) end,
      "Show rested XP bonus and rested kill counts."
    )
  end

  if supports("hasTooltipXP") then
    addCheckbox(
      "Kill History: show unknown mobs",
      "ACEM2L2_XPTOOLTIP_SHOW_UNKNOWN",
      true,
      function() return self.db.xpTooltip.showUnknown end,
      function(value) self.db.xpTooltip.showUnknown = SanitizeBoolean(value, true) end,
      "Show an estimate/unknown line for mobs that have not been observed yet."
    )
  end

  if supports("hasPerMobXP") then
    addCheckbox(
      "Kill History: count zero-XP kills",
      "ACEM2L2_XPTOOLTIP_COUNT_ZERO",
      true,
      function() return self.db.xpTooltip.countZeroXPMobs end,
      function(value) self.db.xpTooltip.countZeroXPMobs = SanitizeBoolean(value, true) end,
      "Count gray/trivial kills when a readable UNIT_DIED event is available."
    )
  end

  addCheckbox(
    "Kill History: debug output",
    "ACEM2L2_XPTOOLTIP_DEBUG",
    false,
    function() return self.db.xpTooltip.debug end,
    function(value) self.db.xpTooltip.debug = SanitizeBoolean(value, false) end,
    "Print Kill History XP and kill-identification diagnostics to chat."
  )

  if supports("hasXPFormula") then
    addSlider(
      "Kill History: manual XP bonus (%)",
      "ACEM2L2_XPTOOLTIP_MANUAL_BONUS",
      0,
      0,
      100,
      1,
      function() return self.db.xpTooltip.manualXPBonus or 0 end,
      function(value) self.db.xpTooltip.manualXPBonus = SanitizeInteger(value, 0, 0, 100) end,
      "Extra XP bonus for buffs the addon does not recognize."
    )
  end

  Settings.RegisterAddOnCategory(category)
  self.optionsCategory = category
end

function AceM2L2:RefreshOptionsPanel()
  if not self.optionSettings or not Settings or not Settings.NotifyUpdate then
    return
  end

  for _, setting in ipairs(self.optionSettings) do
    local ok, variable = pcall(setting.GetVariable, setting)
    if ok and variable then
      pcall(Settings.NotifyUpdate, variable)
    end
  end
end
