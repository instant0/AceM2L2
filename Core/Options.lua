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

  local category, layout = Settings.RegisterVerticalLayoutCategory("Ace Mobs 2 Level 2 - Kill Story")
  Settings.RegisterAddOnCategory(category)
  self.optionSettings = {}

  local addonVersion
  if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
    local ok, value = pcall(C_AddOns.GetAddOnMetadata, "AceM2L2", "Version")
    if ok then
      addonVersion = value
    end
  elseif type(GetAddOnMetadata) == "function" then
    local ok, value = pcall(GetAddOnMetadata, "AceM2L2", "Version")
    if ok then
      addonVersion = value
    end
  end

  local module = self:GetXPTooltipModule()
  local function supports(capability)
    if not module then
      return false
    end
    if not module.clientProfile and type(module.RefreshClient) == "function" then
      pcall(module.RefreshClient, module)
    end
    return module.Supports and module:Supports(capability)
  end

  -- Settings are registered into `page`. Switching to a native subcategory
  -- keeps the tooltip controls on their own page while the main page stays
  -- focused on chat output and module controls.
  local page, pageLayout = category, layout

  local function addHeader(text)
    if not pageLayout or type(CreateSettingsListSectionHeaderInitializer) ~= "function" then
      return
    end
    local ok, initializer = pcall(CreateSettingsListSectionHeaderInitializer, text)
    if ok and initializer and type(pageLayout.AddInitializer) == "function" then
      pcall(pageLayout.AddInitializer, pageLayout, initializer)
    end
  end

  local function addSearchTags(initializer, ...)
    if initializer and type(initializer.AddSearchTags) == "function" then
      pcall(initializer.AddSearchTags, initializer, ...)
    end
  end

  local function addSetting(name, variable, defaultValue, getter, setter)
    local setting = Settings.RegisterProxySetting(
      page,
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
    return Settings.CreateCheckbox(page, setting, tooltip)
  end

  local function addSlider(name, variable, defaultValue, minValue, maxValue, step, getter, setter, tooltip)
    local setting = addSetting(name, variable, defaultValue, getter, setter)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
      and options and type(options.SetLabelFormatter) == "function" then
      pcall(options.SetLabelFormatter, options, MinimalSliderWithSteppersMixin.Label.Right)
    end
    return Settings.CreateSlider(page, setting, options, tooltip)
  end

  local function useSubcategory(name)
    if type(Settings.RegisterVerticalLayoutSubcategory) ~= "function" then
      return false
    end
    local ok, subcategory, sublayout = pcall(
      Settings.RegisterVerticalLayoutSubcategory, category, name
    )
    if not ok or not subcategory then
      return false
    end
    local registered = pcall(Settings.RegisterAddOnCategory, subcategory)
    if not registered then
      return false
    end
    page, pageLayout = subcategory, sublayout
    return true
  end

  addHeader(addonVersion and ("Kill Story " .. addonVersion) or "Kill Story")
  addHeader("Chat messages")

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
    1000,
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
    1000,
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
    100,
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
    1000,
    1,
    function() return self:GetNumberSetting("xpMinKillsRemaining", 0, 0, 1000, true) end,
    function(value) self.db.xpMinKillsRemaining = SanitizeInteger(value, 0, 0, 1000) end,
    "Do not print the XP estimate below this remaining kill count."
  )

  addSlider(
    "Minimum reputation remaining",
    "ACEM2L2_REP_MIN",
    0,
    0,
    50000,
    50,
    function() return self:GetNumberSetting("repMinRemaining", 0, 0, 50000, true) end,
    function(value) self.db.repMinRemaining = SanitizeInteger(value, 0, 0, 50000) end,
    "Do not print the reputation estimate below this remaining value."
  )

  addHeader("Kill Story")

  addCheckbox(
    "Enable Kill Story",
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
    "Track kills and show Kill Story tooltip lines."
  )

  addCheckbox(
    "Enable UI sounds",
    "ACEM2L2_XPTOOLTIP_SOUND",
    true,
    function() return self.db.xpTooltip.sound end,
    function(value) self.db.xpTooltip.sound = SanitizeBoolean(value, true) end,
    "Play UI sounds when the Kill Story window opens and closes."
  )

  addCheckbox(
    "Show minimap icon",
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

  addCheckbox(
    "Lock minimap icon",
    "ACEM2L2_XPTOOLTIP_MINIMAP_LOCK",
    false,
    function()
      local minimap = self.db.xpTooltip.minimap
      return type(minimap) == "table" and minimap.lock == true or false
    end,
    function(value)
      if type(self.db.xpTooltip.minimap) ~= "table" then
        self.db.xpTooltip.minimap = { hide = false, minimapPos = 200, lock = false }
      end
      self.db.xpTooltip.minimap.lock = SanitizeBoolean(value, false)
      local module = self:GetXPTooltipModule()
      if module then
        pcall(module.InitializeMinimap, module)
        pcall(module.UpdateMinimapVisibility, module)
      end
    end,
    "Prevent the minimap icon from being dragged."
  )

  addHeader("Diagnostics")

  addCheckbox(
    "Debug output",
    "ACEM2L2_XPTOOLTIP_DEBUG",
    false,
    function() return self.db.xpTooltip.debug end,
    function(value) self.db.xpTooltip.debug = SanitizeBoolean(value, false) end,
    "Print Kill Story XP and kill-identification diagnostics to chat."
  )

  local function addTooltipOptions()
    addHeader("XP lines")

    if supports("hasTooltipXP") then
      addCheckbox(
        "Show XP estimate",
        "ACEM2L2_XPTOOLTIP_SHOW_XP",
        true,
        function() return self.db.xpTooltip.showXP end,
        function(value) self.db.xpTooltip.showXP = SanitizeBoolean(value, true) end,
        "Show the estimated XP value on the mob tooltip."
      )

      addCheckbox(
        "Show percent of level",
        "ACEM2L2_XPTOOLTIP_SHOW_PERCENT",
        true,
        function() return self.db.xpTooltip.showPercent end,
        function(value) self.db.xpTooltip.showPercent = SanitizeBoolean(value, true) end,
        "Show how much of the current level one kill is worth."
      )

      addCheckbox(
        "Show XP remaining",
        "ACEM2L2_XPTOOLTIP_SHOW_XP_REMAINING",
        true,
        function() return self.db.xpTooltip.showXPRemaining end,
        function(value) self.db.xpTooltip.showXPRemaining = SanitizeBoolean(value, true) end,
        "Show XP remaining to the next level on tooltips and the overview."
      )
    end

    if supports("hasKillsToLevel") then
      addCheckbox(
        "Show kills to level",
        "ACEM2L2_XPTOOLTIP_SHOW_KILLS",
        true,
        function() return self.db.xpTooltip.showKillsToLevel end,
        function(value) self.db.xpTooltip.showKillsToLevel = SanitizeBoolean(value, true) end,
        "Show how many kills of this mob remain to level."
      )
    end

    addHeader("Kill lines")

    addCheckbox(
      "Show kill count",
      "ACEM2L2_XPTOOLTIP_SHOW_KILL_COUNT",
      true,
      function() return self.db.xpTooltip.showKillCount end,
      function(value) self.db.xpTooltip.showKillCount = SanitizeBoolean(value, true) end,
      "Show how many of this mob you have already killed."
    )

    local mobLevelCheckbox = addCheckbox(
      "Show mob level",
      "ACEM2L2_XPTOOLTIP_SHOW_MOB_LEVEL",
      true,
      function() return self.db.xpTooltip.showMobLevel end,
      function(value) self.db.xpTooltip.showMobLevel = SanitizeBoolean(value, true) end,
      "Show the target creature's level. Turn this off to hide the Level line."
    )
    addSearchTags(mobLevelCheckbox, "mob level", "creature level", "target level")

    if supports("hasPerMobXP") then
      addHeader("XP rate")

      addCheckbox(
        "Show XP rate",
        "ACEM2L2_XPTOOLTIP_SHOW_XP_RATE",
        true,
        function() return self.db.xpTooltip.showXPRate end,
        function(value) self.db.xpTooltip.showXPRate = SanitizeBoolean(value, true) end,
        "Show XP per hour and per minute in the overview."
      )

      addCheckbox(
        "Show time to level",
        "ACEM2L2_XPTOOLTIP_SHOW_TIME_TO_LEVEL",
        true,
        function() return self.db.xpTooltip.showTimeToLevel end,
        function(value) self.db.xpTooltip.showTimeToLevel = SanitizeBoolean(value, true) end,
        "Show the estimated time to the next level in the overview."
      )

      addSlider(
        "XP rate window (minutes)",
        "ACEM2L2_XPTOOLTIP_RATE_WINDOW",
        10,
        1,
        60,
        1,
        function() return self.db.xpTooltip.rateWindowMinutes or 10 end,
        function(value) self.db.xpTooltip.rateWindowMinutes = SanitizeInteger(value, 10, 1, 60) end,
        "Recent minutes of XP data used for the rate and time-to-level estimates."
      )
    end

    if supports("hasInstanceInfo") then
      addHeader("Dungeon")

      addCheckbox(
        "Show dungeon activity",
        "ACEM2L2_XPTOOLTIP_SHOW_DUNGEON",
        true,
        function() return self.db.xpTooltip.showDungeonXP end,
        function(value) self.db.xpTooltip.showDungeonXP = SanitizeBoolean(value, true) end,
        "Show dungeon kills and XP in the overview."
      )
    end

    local hasWorldGrinding = supports("hasPerMobXP")
    local hasWorldNameplates = supports("hasNamePlateAPI")
    if hasWorldGrinding or hasWorldNameplates then
      addHeader("World")

      if hasWorldGrinding then
        addCheckbox(
          "Show grinding spot",
          "ACEM2L2_XPTOOLTIP_SHOW_GRINDING_SPOT",
          true,
          function() return self.db.xpTooltip.showGrindingSpot end,
          function(value) self.db.xpTooltip.showGrindingSpot = SanitizeBoolean(value, true) end,
          "Show the best current grinding spot in the overview."
        )
      end

      if hasWorldNameplates then
        addCheckbox(
          "Show nameplate levels",
          "ACEM2L2_XPTOOLTIP_SHOW_NAMEPLATE_LEVEL",
          false,
          function() return self.db.xpTooltip.showNameplateLevel end,
          function(value)
            self.db.xpTooltip.showNameplateLevel = SanitizeBoolean(value, false)
            if module and type(module.RefreshNameplateLevels) == "function" then
              pcall(module.RefreshNameplateLevels, module)
            end
          end,
          "Show the level above nearby nameplates."
        )
      end
    end

    if supports("hasLevelXPState") then
      addHeader("Leveling goal")

      addCheckbox(
        "Show leveling goal",
        "ACEM2L2_XPTOOLTIP_SHOW_GOAL",
        true,
        function() return self.db.xpTooltip.showGoal end,
        function(value) self.db.xpTooltip.showGoal = SanitizeBoolean(value, true) end,
        "Show your leveling goal progress in the overview."
      )
    end

    if supports("hasLevelXPState") then
      addHeader("Level splits")

      addCheckbox(
        "Show level splits",
        "ACEM2L2_XPTOOLTIP_SHOW_SPLITS",
        true,
        function() return self.db.xpTooltip.showSplits end,
        function(value) self.db.xpTooltip.showSplits = SanitizeBoolean(value, true) end,
        "Show your last level split in the overview."
      )
    end

    addHeader("Economy")

    if supports("hasLootValue") then
      addCheckbox(
        "Show session loot",
        "ACEM2L2_XPTOOLTIP_SHOW_ECONOMY",
        true,
        function() return self.db.xpTooltip.showEconomy end,
        function(value) self.db.xpTooltip.showEconomy = SanitizeBoolean(value, true) end,
        "Show session loot value in the overview."
      )
    end

    if supports("hasMoney") then
      addCheckbox(
        "Show gold per hour",
        "ACEM2L2_XPTOOLTIP_SHOW_GOLD_PER_HOUR",
        true,
        function() return self.db.xpTooltip.showGoldPerHour end,
        function(value) self.db.xpTooltip.showGoldPerHour = SanitizeBoolean(value, true) end,
        "Show gold per hour in the overview."
      )
    end

    if supports("hasGearCompare") then
      addCheckbox(
        "Show gear upgrades",
        "ACEM2L2_XPTOOLTIP_SHOW_GEAR_UPGRADES",
        true,
        function() return self.db.xpTooltip.showGearUpgrades end,
        function(value) self.db.xpTooltip.showGearUpgrades = SanitizeBoolean(value, true) end,
        "Show gear upgrade notifications for looted items."
      )
    end

    addHeader("Rested and bonuses")

    if supports("hasRestedPool") then
      addCheckbox(
        "Show rested bonus",
        "ACEM2L2_XPTOOLTIP_SHOW_RESTED",
        true,
        function() return self.db.xpTooltip.showRested end,
        function(value) self.db.xpTooltip.showRested = SanitizeBoolean(value, true) end,
        "Show rested XP bonus and rested kill counts."
      )
    end

    if supports("hasXPFormula") then
      addCheckbox(
        "Show XP bonuses",
        "ACEM2L2_XPTOOLTIP_SHOW_XP_BONUSES",
        true,
        function() return self.db.xpTooltip.showXPBonuses end,
        function(value) self.db.xpTooltip.showXPBonuses = SanitizeBoolean(value, true) end,
        "Show the XP bonuses applied to tooltip and overview estimates."
      )

      addSlider(
        "Manual XP bonus (%)",
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

    addHeader("Edge cases")

    if supports("hasTooltipXP") then
      addCheckbox(
        "Show unknown mobs",
        "ACEM2L2_XPTOOLTIP_SHOW_UNKNOWN",
        true,
        function() return self.db.xpTooltip.showUnknown end,
        function(value) self.db.xpTooltip.showUnknown = SanitizeBoolean(value, true) end,
        "Show an estimate/unknown line for mobs that have not been observed yet."
      )
    end

    if supports("hasPerMobXP") then
      addCheckbox(
        "Count zero-XP kills",
        "ACEM2L2_XPTOOLTIP_COUNT_ZERO",
        true,
        function() return self.db.xpTooltip.countZeroXPMobs end,
        function(value) self.db.xpTooltip.countZeroXPMobs = SanitizeBoolean(value, true) end,
        "Count gray/trivial kills when a readable UNIT_DIED event is available."
      )
    end
  end

  local function addHeatmapOptions()
    if not supports("hasMapPosition") then
      return
    end

    local heatmapControls = {}
    local function SetHeatmapControlsEnabled(enabled)
      for _, control in ipairs(heatmapControls) do
        if control and type(control.SetEnabled) == "function" then
          pcall(control.SetEnabled, control, enabled)
        end
      end
    end

    addHeader("Collection")

    addCheckbox(
      "Enable heatmap collection",
      "ACEM2L2_XPTOOLTIP_HEATMAP_ENABLED",
      true,
      function() return self.db.xpTooltip.heatmapEnabled ~= false end,
      function(value)
        local enabled = SanitizeBoolean(value, true)
        self.db.xpTooltip.heatmapEnabled = enabled
        if not module then
          return
        end
        if type(module.RefreshHeatmapEventRegistration) == "function" then
          pcall(module.RefreshHeatmapEventRegistration, module)
        end
        if type(module.RefreshHeatmap) == "function" then
          pcall(module.RefreshHeatmap, module)
        end
        if type(module.RefreshUI) == "function" then
          pcall(module.RefreshUI, module)
        end
        if type(module.UpdateTabs) == "function" then
          pcall(module.UpdateTabs, module)
        end
        SetHeatmapControlsEnabled(enabled)
      end,
      "Record new heatmap data. Turning this off stops collection and saving; stored data stays until you clear it."
    )

    addHeader("Display")

    addCheckbox(
      "Show heatmap tab",
      "ACEM2L2_XPTOOLTIP_SHOW_HEATMAP",
      true,
      function() return self.db.xpTooltip.showHeatmap end,
      function(value)
        local showHeatmap = SanitizeBoolean(value, true)
        self.db.xpTooltip.showHeatmap = showHeatmap
        if not module then
          return
        end
        if not showHeatmap and module.tab == "heatmap" and type(module.SetTab) == "function" then
          pcall(module.SetTab, module, "overview")
        end
        if type(module.RefreshUI) == "function" then
          pcall(module.RefreshUI, module)
        end
        if type(module.UpdateTabs) == "function" then
          pcall(module.UpdateTabs, module)
        end
      end,
      "Show the Heatmap tab in the Kill Story window. This does not stop collection."
    )

    local revealControl = addCheckbox(
      "Reveal unexplored areas",
      "ACEM2L2_XPTOOLTIP_REVEAL_UNEXPLORED",
      true,
      function() return self.db.xpTooltip.revealUnexplored ~= false end,
      function(value)
        self.db.xpTooltip.revealUnexplored = SanitizeBoolean(value, true)
        if module and type(module.RefreshHeatmap) == "function" then
          pcall(module.RefreshHeatmap, module)
        end
      end,
      "Show the full zone map in the heatmap background, including areas this character has not explored."
    )
    heatmapControls[#heatmapControls + 1] = revealControl

    local intensityControl = addSlider(
      "Heatmap intensity",
      "ACEM2L2_XPTOOLTIP_HEATMAP_INTENSITY",
      100,
      50,
      200,
      5,
      function() return self.db.xpTooltip.heatmapIntensity or 100 end,
      function(value)
        self.db.xpTooltip.heatmapIntensity = SanitizeInteger(value, 100, 50, 200)
        if module and type(module.RefreshHeatmap) == "function" then
          pcall(module.RefreshHeatmap, module)
        end
      end,
      "Adjusts heat contrast. 100 is the default; higher values make hot cells stand out more."
    )
    heatmapControls[#heatmapControls + 1] = intensityControl

    local warmControl = addCheckbox(
      "Warm heat colors",
      "ACEM2L2_XPTOOLTIP_HEATMAP_WARM",
      false,
      function() return self.db.xpTooltip.heatmapWarmColors == true end,
      function(value)
        self.db.xpTooltip.heatmapWarmColors = SanitizeBoolean(value, false)
        if module and type(module.RefreshHeatmap) == "function" then
          pcall(module.RefreshHeatmap, module)
        end
      end,
      "Use a fire palette (amber to red) instead of the theme-accent heat gradient."
    )
    heatmapControls[#heatmapControls + 1] = warmControl
    SetHeatmapControlsEnabled(self.db.xpTooltip.heatmapEnabled ~= false)
  end

  if useSubcategory("Tooltip") then
    addTooltipOptions()
  else
    addHeader("Tooltip")
    addTooltipOptions()
  end

  if supports("hasMapPosition") then
    if useSubcategory("Heatmap") then
      addHeatmapOptions()
    else
      addHeader("Heatmap")
      addHeatmapOptions()
    end
  end

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
