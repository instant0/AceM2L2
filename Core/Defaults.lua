--[[---------------------------------------------------------------------------------
  Core/Defaults.lua
  Core addon constants and default settings.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2

local CAMELOT_PROJECT_ID = WOW_PROJECT_CAMELOT or 18
local MAINLINE_PROJECT_ID = WOW_PROJECT_MAINLINE or 1

local SCHEMA_VERSION = 4

local XPTOOLTIP_UI_DEFAULTS = {
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
  width = 1000,
  height = 680,
  sort = "kills",
}

local XPTOOLTIP_MINIMAP_DEFAULTS = {
  hide = false,
  minimapPos = 200,
  lock = false,
}

local XPTOOLTIP_DEFAULTS = {
  enabled = true,
  showXP = true,
  showPercent = true,
  showXPRemaining = true,
  showXPRate = true,
  showTimeToLevel = true,
  rateWindowMinutes = 10,
  showDungeonXP = true,
  showGoal = true,
  showSplits = true,
  showEconomy = true,
  showGoldPerHour = true,
  showGearUpgrades = true,
  showGrindingSpot = true,
  showHeatmap = true,
  showNameplateLevel = false,
  showMobLevel = true,
  showXPBonuses = true,
  showKillsToLevel = true,
  showKillCount = true,
  showRested = true,
  showUnknown = true,
  countZeroXPMobs = true,
  manualXPBonus = 0,
  debug = false,
  theme = "aether",
  scale = 1.0,
  startTab = "overview",
  sound = true,
  ui = XPTOOLTIP_UI_DEFAULTS,
  minimap = XPTOOLTIP_MINIMAP_DEFAULTS,
}

local defaults = {
  profile = {
    xpEnabled = true,
    repEnabled = true,
    xpEveryNKills = 1,
    xpMinKillsRemaining = 0,
    repEveryNGains = 1,
    repMinRemaining = 0,
    useRollingXP = true,
    rollingXPWindow = 5,
    precision = 2,
    debug = false,
    schemaVersion = SCHEMA_VERSION,
    xpTooltip = XPTOOLTIP_DEFAULTS,
  },
}

AceM2L2.Defaults = {
  CAMELOT_PROJECT_ID = CAMELOT_PROJECT_ID,
  MAINLINE_PROJECT_ID = MAINLINE_PROJECT_ID,
  SCHEMA_VERSION = SCHEMA_VERSION,
  XPTOOLTIP_UI_DEFAULTS = XPTOOLTIP_UI_DEFAULTS,
  XPTOOLTIP_MINIMAP_DEFAULTS = XPTOOLTIP_MINIMAP_DEFAULTS,
  XPTOOLTIP_DEFAULTS = XPTOOLTIP_DEFAULTS,
  defaults = defaults,
}
