--[[---------------------------------------------------------------------------------
  Core/Settings.lua
  Profile and Kill History settings sanitization.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Defaults = AceM2L2.Defaults
local Util = AceM2L2.Util

local SCHEMA_VERSION = Defaults.SCHEMA_VERSION
local XPTOOLTIP_DEFAULTS = Defaults.XPTOOLTIP_DEFAULTS
local XPTOOLTIP_UI_DEFAULTS = Defaults.XPTOOLTIP_UI_DEFAULTS
local XPTOOLTIP_MINIMAP_DEFAULTS = Defaults.XPTOOLTIP_MINIMAP_DEFAULTS
local SanitizeBoolean = Util.SanitizeBoolean
local SanitizeInteger = Util.SanitizeInteger
local CopyDefaults = Util.CopyDefaults
local SafeString = Util.SafeString

function AceM2L2:SanitizeProfile()
  local profile = self.db
  profile.xpEnabled = SanitizeBoolean(profile.xpEnabled, true)
  profile.repEnabled = SanitizeBoolean(profile.repEnabled, true)
  profile.useRollingXP = SanitizeBoolean(profile.useRollingXP, true)
  profile.debug = SanitizeBoolean(profile.debug, false)
  profile.xpEveryNKills = SanitizeInteger(profile.xpEveryNKills, 1, 1, 1000)
  profile.xpMinKillsRemaining = SanitizeInteger(profile.xpMinKillsRemaining, 0, 0, 1000000)
  profile.repEveryNGains = SanitizeInteger(profile.repEveryNGains, 1, 1, 1000)
  profile.repMinRemaining = SanitizeInteger(profile.repMinRemaining, 0, 0, 100000000)
  profile.rollingXPWindow = SanitizeInteger(profile.rollingXPWindow, 5, 1, 100)
  profile.precision = SanitizeInteger(profile.precision, 2, 0, 4)
  self:SanitizeXPTooltipSettings()
  profile.schemaVersion = SCHEMA_VERSION
end

function AceM2L2:SanitizeXPTooltipSettings()
  local settings = self.db.xpTooltip
  if type(settings) ~= "table" then
    settings = CopyDefaults(XPTOOLTIP_DEFAULTS)
    self.db.xpTooltip = settings
  end

  settings.enabled = SanitizeBoolean(settings.enabled, true)
  settings.showXP = SanitizeBoolean(settings.showXP, true)
  settings.showPercent = SanitizeBoolean(settings.showPercent, true)
  settings.showXPRemaining = SanitizeBoolean(settings.showXPRemaining, true)
  settings.showXPRate = SanitizeBoolean(settings.showXPRate, true)
  settings.showTimeToLevel = SanitizeBoolean(settings.showTimeToLevel, true)
  settings.rateWindowMinutes = SanitizeInteger(settings.rateWindowMinutes, 10, 1, 60)
  settings.showDungeonXP = SanitizeBoolean(settings.showDungeonXP, true)
  settings.showGoal = SanitizeBoolean(settings.showGoal, true)
  settings.showSplits = SanitizeBoolean(settings.showSplits, true)
  settings.showEconomy = SanitizeBoolean(settings.showEconomy, true)
  settings.showGoldPerHour = SanitizeBoolean(settings.showGoldPerHour, true)
  settings.showGearUpgrades = SanitizeBoolean(settings.showGearUpgrades, true)
  settings.showGrindingSpot = SanitizeBoolean(settings.showGrindingSpot, true)
  settings.showHeatmap = SanitizeBoolean(settings.showHeatmap, true)
  settings.showNameplateLevel = SanitizeBoolean(settings.showNameplateLevel, false)
  settings.showMobLevel = SanitizeBoolean(settings.showMobLevel, true)
  settings.showXPBonuses = SanitizeBoolean(settings.showXPBonuses, true)
  settings.showKillsToLevel = SanitizeBoolean(settings.showKillsToLevel, true)
  settings.showKillCount = SanitizeBoolean(settings.showKillCount, true)
  settings.showRested = SanitizeBoolean(settings.showRested, true)
  settings.showUnknown = SanitizeBoolean(settings.showUnknown, true)
  settings.countZeroXPMobs = SanitizeBoolean(settings.countZeroXPMobs, true)
  settings.manualXPBonus = SanitizeInteger(settings.manualXPBonus, 0, 0, 100)
  settings.debug = SanitizeBoolean(settings.debug, false)
  settings.sound = SanitizeBoolean(settings.sound, true)

  local validThemes = { aether = true, dark = true, midnight = true, class = true, contrast = true }
  -- 1.11.2: "dark" was the previous default. Move existing profiles to the new
  -- Aether Blue default once, without overriding later explicit theme choices.
  if not settings.aetherThemeMigration then
    if settings.theme == nil or settings.theme == "dark" then
      settings.theme = "aether"
    end
    settings.aetherThemeMigration = true
  end
  settings.theme = SafeString(settings.theme) or "aether"
  if not validThemes[settings.theme] then
    settings.theme = "aether"
  end
  settings.scale = tonumber(settings.scale) or 1.0
  settings.scale = math.max(0.8, math.min(1.2, settings.scale))

  local validStartTabs = { overview = true, mobs = true, areas = true, levels = true, heatmap = true }
  settings.startTab = SafeString(settings.startTab) or "overview"
  if not validStartTabs[settings.startTab] then
    settings.startTab = "overview"
  end

  local minimap = settings.minimap
  if type(minimap) ~= "table" then
    minimap = CopyDefaults(XPTOOLTIP_MINIMAP_DEFAULTS)
    settings.minimap = minimap
  end
  minimap.hide = SanitizeBoolean(minimap.hide, false)
  minimap.lock = SanitizeBoolean(minimap.lock, false)
  minimap.minimapPos = SanitizeInteger(minimap.minimapPos, 200, 0, 360)

  local ui = settings.ui
  if type(ui) ~= "table" then
    ui = CopyDefaults(XPTOOLTIP_UI_DEFAULTS)
    settings.ui = ui
  end
  local validPoints = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
  }
  ui.point = SafeString(ui.point) or "CENTER"
  if not validPoints[ui.point] then
    ui.point = "CENTER"
  end
  ui.relativePoint = SafeString(ui.relativePoint) or "CENTER"
  if not validPoints[ui.relativePoint] then
    ui.relativePoint = "CENTER"
  end
  ui.x = SanitizeInteger(ui.x, 0, -5000, 5000)
  ui.y = SanitizeInteger(ui.y, 0, -5000, 5000)
  ui.width = SanitizeInteger(ui.width, 1000, 780, 1200)
  ui.height = SanitizeInteger(ui.height, 680, 520, 900)
  ui.sort = SafeString(ui.sort) or "kills"
  if ui.sort ~= "kills" and ui.sort ~= "name" and ui.sort ~= "lastSeen" then
    ui.sort = "kills"
  end
end

function AceM2L2:GetNumberSetting(key, defaultValue, minValue, maxValue, integer)
  local value = tonumber(self.db and self.db[key])
  if not value then
    value = defaultValue
  end
  if integer then
    value = math.floor(value + 0.5)
  end
  if minValue and value < minValue then
    value = minValue
  end
  if maxValue and value > maxValue then
    value = maxValue
  end
  return value
end
