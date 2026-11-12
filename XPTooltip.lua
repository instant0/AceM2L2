--[[---------------------------------------------------------------------------------
  XPTooltip - Forever 1.60.1 module for AceM2L2
  Standalone module: tooltip XP estimates, per-mob kill history, 3D model browser.
  Auto-disables outside Forever or when required APIs are unavailable.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2:NewModule("XPTooltip", "AceEvent-3.0")

local floor, min, max, huge = math.floor, math.min, math.max, math.huge
local CAMELOT_PROJECT_ID = WOW_PROJECT_CAMELOT or 18

local MAX_MOBS = 2000
local CALIBRATION_VERSION = 2
local MAX_CONTEXTS_PER_MOB = 12
local MAX_PENDING_DEATHS = 50
local CONTEXT_MAX_AGE = 120 * 86400
local ROW_HEIGHT = 28
local VISIBLE_ROWS = 13

local DEFAULT_SETTINGS = {
  enabled = true,
  showXP = true,
  showPercent = true,
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
}

local DEFAULT_UI = {
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
  width = 1000,
  height = 680,
  sort = "kills",
}

local DEFAULT_MINIMAP = {
  hide = false,
  minimapPos = 200,
  lock = false,
}

local THEMES = {
  aether = {
    canvas = { 0.027, 0.067, 0.122, 1.00 },
    panel = { 0.047, 0.106, 0.165, 0.94 },
    elevated = { 0.063, 0.149, 0.227, 0.96 },
    border = { 0.165, 0.337, 0.478, 1.00 },
    text = { 0.918, 0.965, 1.000 },
    muted = { 0.616, 0.722, 0.800 },
    accent = { 0.310, 0.765, 0.969 },
    accentSoft = { 0.310, 0.765, 0.969, 0.20 },
    bar = { 0.310, 0.765, 0.969, 0.50 },
    success = { 0.360, 0.840, 0.660 },
    warning = { 0.950, 0.760, 0.310 },
    danger = { 0.940, 0.440, 0.440 },
  },
  dark = {
    canvas = { 0.035, 0.055, 0.065, 1.00 },
    panel = { 0.055, 0.090, 0.100, 0.94 },
    elevated = { 0.075, 0.120, 0.135, 0.96 },
    border = { 0.180, 0.245, 0.270, 1.00 },
    text = { 0.910, 0.880, 0.810 },
    muted = { 0.620, 0.690, 0.670 },
    accent = { 0.850, 0.660, 0.310 },
    accentSoft = { 0.850, 0.660, 0.310, 0.22 },
    bar = { 0.850, 0.660, 0.310, 0.45 },
    success = { 0.500, 0.820, 0.550 },
  },
  midnight = {
    canvas = { 0.018, 0.040, 0.075, 1.00 },
    panel = { 0.040, 0.060, 0.095, 0.94 },
    elevated = { 0.060, 0.090, 0.135, 0.96 },
    border = { 0.160, 0.220, 0.320, 1.00 },
    text = { 0.880, 0.900, 0.940 },
    muted = { 0.580, 0.660, 0.780 },
    accent = { 0.300, 0.650, 0.920 },
    accentSoft = { 0.300, 0.650, 0.920, 0.22 },
    bar = { 0.300, 0.650, 0.920, 0.45 },
    success = { 0.450, 0.820, 0.700 },
  },
  class = {
    canvas = { 0.030, 0.050, 0.055, 1.00 },
    panel = { 0.055, 0.080, 0.085, 0.94 },
    elevated = { 0.075, 0.105, 0.110, 0.96 },
    border = { 0.180, 0.230, 0.240, 1.00 },
    text = { 0.930, 0.910, 0.870 },
    muted = { 0.650, 0.700, 0.690 },
    accent = { 0.850, 0.660, 0.310 },
    accentSoft = { 0.850, 0.660, 0.310, 0.22 },
    bar = { 0.850, 0.660, 0.310, 0.45 },
    success = { 0.500, 0.820, 0.550 },
  },
  contrast = {
    canvas = { 0.000, 0.000, 0.000, 1.00 },
    panel = { 0.010, 0.010, 0.010, 0.98 },
    elevated = { 0.040, 0.040, 0.040, 0.99 },
    border = { 0.700, 0.700, 0.700, 1.00 },
    text = { 1.000, 1.000, 1.000 },
    muted = { 0.850, 0.850, 0.850 },
    accent = { 1.000, 0.850, 0.250 },
    accentSoft = { 1.000, 0.850, 0.250, 0.28 },
    bar = { 1.000, 0.850, 0.250, 0.60 },
    success = { 0.500, 1.000, 0.500 },
  },
}

local ZERO_DIFFERENCE = {
  { 7, 5 }, { 9, 6 }, { 11, 7 }, { 15, 8 }, { 19, 9 },
  { 29, 11 }, { 39, 12 }, { 44, 13 }, { 49, 14 }, { 54, 15 },
  { 59, 16 }, { huge, 17 },
}

local CLASSIC_GROUP_PRIOR = {
  [1] = 1.00, [2] = 0.70, [3] = 0.60, [4] = 0.55, [5] = 0.52,
}

-- Group chat text may contain both the personal share and a party bonus.
-- Keep this off until the live amount is verified; otherwise a summed message
-- can train a 1.0 group ratio and make the tooltip show solo XP in a group.
local GROUP_CALIBRATION_ENABLED = false

--[[--------------------------------------------------------------------------------
  Defensive helpers
------------------------------------------------------------------------------------]]

local function IsSecret(value)
  return issecretvalue and issecretvalue(value) or false
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c, d, e
end

local function SafeNumber(value)
  if value == nil or IsSecret(value) or type(value) ~= "number" then
    return nil
  end
  return value
end

local function SafeString(value)
  if value == nil or IsSecret(value) or type(value) ~= "string" then
    return nil
  end
  return value
end

local function SafeBool(value)
  if value == nil or IsSecret(value) or type(value) ~= "boolean" then
    return nil
  end
  return value
end

local function Trim(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Lower(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  local lower = strlower or string.lower
  local ok, result = pcall(lower, value)
  if not ok then
    return nil
  end
  return result
end

local function CopyTable(source)
  local copy = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = CopyTable(value)
    else
      copy[key] = value
    end
  end
  return copy
end

local function CopyInfo(source)
  if type(source) ~= "table" then
    return nil
  end
  return {
    name = source.name,
    guid = source.guid,
    npcID = source.npcID,
    level = source.level,
    classification = source.classification,
    mobKey = source.mobKey,
    mapID = source.mapID,
    at = source.at,
  }
end

local function Now()
  return SafeNumber(SafeCall(GetTime)) or 0
end

local function Epoch()
  return SafeNumber(SafeCall(time)) or Now()
end

local function Clamp(number, minimum, maximum)
  if number < minimum then
    return minimum
  end
  if number > maximum then
    return maximum
  end
  return number
end

--[[--------------------------------------------------------------------------------
  Formula
------------------------------------------------------------------------------------]]

local function ZeroDifference(playerLevel)
  for _, row in ipairs(ZERO_DIFFERENCE) do
    if playerLevel <= row[1] then
      return row[2]
    end
  end
  return 17
end

local function GrayLevel(playerLevel)
  if playerLevel <= 5 then
    return 0
  elseif playerLevel <= 39 then
    return playerLevel - floor(playerLevel / 10) - 5
  end
  return playerLevel - floor(playerLevel / 5) - 1
end

local function RoundForever(value)
  local base = floor(value)
  local fraction = value - base
  if fraction > 0.5 + 1e-9 then
    return base + 1
  elseif fraction >= 0.5 - 1e-9 and base % 2 == 1 then
    return base + 1
  end
  return base
end

local function ClassificationMultiplier(classification)
  if classification == "elite" or classification == "rareelite" or classification == "worldboss" then
    return 2
  end
  return 1
end

local function FormulaBaseXP(playerLevel, mobLevel)
  if not playerLevel or not mobLevel or mobLevel == 0 then
    if not playerLevel then
      return 0
    end
    mobLevel = playerLevel
  end
  if mobLevel == -1 then
    mobLevel = playerLevel + 4
  end
  if mobLevel <= GrayLevel(playerLevel) then
    return 0
  end

  local base = 5 * min(playerLevel, mobLevel) + 45
  local multiplier
  if mobLevel >= playerLevel then
    multiplier = 1 + 0.05 * min(mobLevel - playerLevel, 4)
  else
    local zd = ZeroDifference(playerLevel)
    multiplier = (zd - (playerLevel - mobLevel)) / zd
  end
  return RoundForever(base * multiplier)
end

local function FormulaXP(playerLevel, mobLevel, classification)
  local base = FormulaBaseXP(playerLevel, mobLevel)
  if base <= 0 then
    return 0
  end
  return base * ClassificationMultiplier(classification)
end

local function ContextKey(playerLevel, mobLevel, groupSize, mapID, classification, buffSignature)
  return "p" .. tostring(playerLevel)
    .. "-m" .. tostring(mobLevel)
    .. "-g" .. tostring(groupSize)
    .. "-z" .. tostring(mapID)
    .. "-c" .. tostring(classification)
    .. "-b" .. tostring(buffSignature)
end

--[[--------------------------------------------------------------------------------
  Formatting
------------------------------------------------------------------------------------]]

local function FormatNumber(number)
  local value = tonumber(number) or 0
  if value >= 1000000 then
    return string.format("%.2fm", value / 1000000)
  elseif value >= 10000 then
    return string.format("%.1fk", value / 1000)
  end
  return tostring(floor(value + 0.5))
end

local function FormatPercent(number)
  local value = tonumber(number) or 0
  return string.format("%.2f%%", value)
end

local function FormatAgo(epoch)
  local value = tonumber(epoch) or 0
  if value <= 0 then
    return "never"
  end
  local delta = Epoch() - value
  if delta < 0 then
    delta = 0
  end
  if delta < 60 then
    return "just now"
  elseif delta < 3600 then
    return floor(delta / 60) .. "m ago"
  elseif delta < 86400 then
    return floor(delta / 3600) .. "h ago"
  end
  return floor(delta / 86400) .. "d ago"
end

local function FormatDate(epoch)
  local value = tonumber(epoch) or 0
  if value <= 0 or type(date) ~= "function" then
    return "unknown"
  end
  local ok, text = pcall(date, "%Y-%m-%d", value)
  if ok and text then
    return text
  end
  return "unknown"
end

--[[--------------------------------------------------------------------------------
  Character data
------------------------------------------------------------------------------------]]

local function EnsureNumberMap(tbl)
  if type(tbl) ~= "table" then
    return {}
  end
  return tbl
end

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
    settings = CopyTable(DEFAULT_SETTINGS)
    settings.ui = CopyTable(DEFAULT_UI)
    profile.xpTooltip = settings
  end
  if type(settings.ui) ~= "table" then
    settings.ui = CopyTable(DEFAULT_UI)
  end
  if type(settings.minimap) ~= "table" then
    settings.minimap = CopyTable(DEFAULT_MINIMAP)
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

function XPTooltip:GetTheme()
  local settings = self.settings or self:GetSettings()
  local key = settings and settings.theme or "dark"
  local base = THEMES[key] or THEMES.aether
  local theme = CopyTable(base)

  if key == "class" then
    local _, classFile = SafeCall(UnitClass, "player")
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color and classFile and C_ClassColor and C_ClassColor.GetClassColor then
      color = SafeCall(C_ClassColor.GetClassColor, classFile)
    end
    if color then
      theme.accent = { color.r, color.g, color.b }
      theme.accentSoft = { color.r, color.g, color.b, 0.22 }
      theme.bar = { color.r, color.g, color.b, 0.45 }
    end
  end
  return theme
end

function XPTooltip:StylePanel(frame, kind)
  if not frame or not frame.SetBackdropColor then
    return
  end
  local theme = self:GetTheme()
  local color
  if kind == "canvas" then
    color = theme.canvas or theme.panel
  elseif kind == "elevated" then
    color = theme.elevated
  else
    color = theme.panel
  end
  frame:SetBackdropColor(color[1], color[2], color[3], color[4])
  frame:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
end

function XPTooltip:ApplyTheme()
  if not self.ui then
    return
  end
  local theme = self:GetTheme()
  for _, panel in ipairs(self.ui.panels or {}) do
    self:StylePanel(panel, panel.xpTooltipKind or "panel")
  end
  if self.ui.title then
    self.ui.title:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
  end
  if self.ui.subtitle then
    self.ui.subtitle:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.heroName then
    self.ui.heroName:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
  end
  if self.ui.heroSub then
    self.ui.heroSub:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.modelHolder and self.ui.modelHolder.glow then
    self.ui.modelHolder.glow:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.10)
  end
  if self.ui.details then
    self.ui.details:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.footer then
    self.ui.footer:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.overview and self.ui.overview.labels then
    for _, label in ipairs(self.ui.overview.labels) do
      label:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
    end
  end
  if self.ui.overview and self.ui.overview.values then
    for _, value in ipairs(self.ui.overview.values) do
      value:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
    end
  end
  if self.ui.overview and self.ui.overview.accents then
    for _, accent in ipairs(self.ui.overview.accents) do
      accent:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)
    end
  end
  local function refreshButton(button)
    if button and button.ApplyStyle then
      button:ApplyStyle()
    end
  end
  for _, button in pairs(self.ui.tabs or {}) do
    refreshButton(button)
  end
  for _, button in pairs(self.ui.filterButtons or {}) do
    refreshButton(button)
  end
  refreshButton(self.ui.sortButton)
  refreshButton(self.ui.settingsButton)
  refreshButton(self.ui.closeButton)
  refreshButton(self.ui.deleteButton)
  if self.ui.searchBorder then
    self.ui.searchBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 1)
  end
  if self.ui.searchBg then
    self.ui.searchBg:SetColorTexture(theme.elevated[1], theme.elevated[2], theme.elevated[3], 1)
  end
  if self.ui.searchBox and self.ui.searchBox.SetTextColor then
    pcall(self.ui.searchBox.SetTextColor, self.ui.searchBox, theme.text[1], theme.text[2], theme.text[3])
  end
  if self.ui.searchPlaceholder then
    self.ui.searchPlaceholder:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  self:UpdateAmbient()
  self:UpdateStatusChip()
  self:UpdateRows()
end

function XPTooltip:RegisterPanel(panel, kind)
  if not self.ui then
    return
  end
  panel.xpTooltipKind = kind or "panel"
  self.ui.panels[#self.ui.panels + 1] = panel
  self:StylePanel(panel, kind)
end

function XPTooltip:EnsureDB()
  if type(AceM2L2CharDB) ~= "table" then
    AceM2L2CharDB = {}
  end
  local db = AceM2L2CharDB.xpTooltip
  if type(db) ~= "table" then
    db = {}
    AceM2L2CharDB.xpTooltip = db
  end

  db.schema = 1
  db.mobs = EnsureNumberMap(db.mobs)
  db.areas = EnsureNumberMap(db.areas)
  db.levels = EnsureNumberMap(db.levels)
  db.areaLevels = EnsureNumberMap(db.areaLevels)

  -- 1.10.x and early 1.11.x could persist inflated multiplicative
  -- calibration ratios. Discard them once, keep observations and kill counts.
  if tonumber(db.calibrationVersion) ~= CALIBRATION_VERSION then
    db.calibration = {}
    db.calibrationVersion = CALIBRATION_VERSION
  end

  db.calibration = type(db.calibration) == "table" and db.calibration or {}
  db.calibration.zones = EnsureNumberMap(db.calibration.zones)
  db.calibration.levels = EnsureNumberMap(db.calibration.levels)
  db.calibration.groups = EnsureNumberMap(db.calibration.groups)
  db.calibration.classes = EnsureNumberMap(db.calibration.classes)
  db.calibration.mobs = EnsureNumberMap(db.calibration.mobs)
  db.totals = type(db.totals) == "table" and db.totals or {}
  db.totals.kills = tonumber(db.totals.kills) or 0
  db.totals.xp = tonumber(db.totals.xp) or 0
  db.totals.uniqueMobs = tonumber(db.totals.uniqueMobs) or 0
  db.session = type(db.session) == "table" and db.session or {}
  db.session.startedAt = tonumber(db.session.startedAt) or 0
  db.session.kills = tonumber(db.session.kills) or 0
  db.session.xp = tonumber(db.session.xp) or 0

  self.char = db
  self:ConsolidateNameOnlyMobs()
  return db
end

function XPTooltip:FindNPCKeyByName(name)
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return nil
  end
  local lower = Lower(name)
  if not lower then
    return nil
  end
  local match, count
  for key, mob in pairs(db.mobs) do
    if type(key) == "string" and key:sub(1, 4) == "npc:"
      and type(mob) == "table" and Lower(mob.name) == lower then
      match = key
      count = (count or 0) + 1
      if count > 1 then
        return nil
      end
    end
  end
  return match
end

function XPTooltip:GetMobKey(name, npcID)
  if npcID then
    return "npc:" .. tostring(npcID)
  end
  local known = self:FindNPCKeyByName(name)
  if known then
    return known
  end
  local lower = Lower(name) or "unknown"
  return "name:" .. lower
end

function XPTooltip:MergeMobEntries(fromKey, toKey, historical)
  if not fromKey or not toKey or fromKey == toKey then
    return false
  end
  if type(fromKey) ~= "string" or fromKey:sub(1, 5) ~= "name:" then
    return false
  end
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return false
  end
  local from = db.mobs[fromKey]
  if type(from) ~= "table" then
    return false
  end

  local to = db.mobs[toKey]
  if type(to) ~= "table" then
    -- Promote the unresolved name-only entry to the NPC key.
    db.mobs[fromKey] = nil
    from.npcID = from.npcID or tonumber(tostring(toKey):match("^npc:(%d+)"))
    db.mobs[toKey] = from
    local calibration = db.calibration and db.calibration.mobs
    if type(calibration) == "table" and type(calibration[fromKey]) == "table" then
      calibration[toKey] = calibration[toKey] or calibration[fromKey]
      calibration[fromKey] = nil
    end
    return true
  end

  local fromLevels = EnsureNumberMap(from.killsAtLevel)
  local toLevels = EnsureNumberMap(to.killsAtLevel)
  local fromMaps = EnsureNumberMap(from.killsByMap)
  local toMaps = EnsureNumberMap(to.killsByMap)

  -- Older versions could record the same kill twice: once from XP chat under a
  -- name-only key, then again from UNIT_DIED under the NPC key with no XP. If
  -- their active ranges overlap, take the larger count and treat the overlap as
  -- duplicate events. Disjoint ranges are genuinely additive.
  local dedupe = false
  if historical then
    local fromFirst = tonumber(from.firstSeen) or 0
    local fromLast = tonumber(from.lastSeen) or 0
    local toFirst = tonumber(to.firstSeen) or 0
    local toLast = tonumber(to.lastSeen) or 0
    if fromFirst > 0 and toFirst > 0 and fromFirst <= toLast and toFirst <= fromLast then
      dedupe = true
    end
  end

  local fromKills = tonumber(from.kills) or 0
  local toKills = tonumber(to.kills) or 0
  local fromSession = tonumber(from.sessionKills) or 0
  local toSession = tonumber(to.sessionKills) or 0
  local duplicateKills, duplicateSessionKills = 0, 0
  if dedupe then
    to.kills = max(fromKills, toKills)
    to.sessionKills = max(fromSession, toSession)
    duplicateKills = fromKills + toKills - to.kills
    duplicateSessionKills = fromSession + toSession - to.sessionKills
  else
    to.kills = fromKills + toKills
    to.sessionKills = fromSession + toSession
  end

  local levelDuplicates, mapDuplicates = {}, {}
  if dedupe then
    for levelKey, value in pairs(fromLevels) do
      local overlap = min(tonumber(value) or 0, tonumber(toLevels[levelKey]) or 0)
      if overlap > 0 then
        levelDuplicates[levelKey] = overlap
      end
    end
    for mapKey, value in pairs(fromMaps) do
      local overlap = min(tonumber(value) or 0, tonumber(toMaps[mapKey]) or 0)
      if overlap > 0 then
        mapDuplicates[mapKey] = overlap
      end
    end
  end

  to.name = to.name or from.name
  to.npcID = to.npcID or from.npcID or tonumber(tostring(toKey):match("^npc:(%d+)"))
  if (not to.classification or to.classification == "normal")
    and from.classification and from.classification ~= "normal" then
    to.classification = from.classification
  end
  local fromFirst, toFirst = tonumber(from.firstSeen), tonumber(to.firstSeen)
  if fromFirst and (not toFirst or fromFirst < toFirst) then
    to.firstSeen = fromFirst
  end
  to.lastSeen = max(tonumber(to.lastSeen) or 0, tonumber(from.lastSeen) or 0)

  for levelKey, value in pairs(fromLevels) do
    local current = tonumber(toLevels[levelKey]) or 0
    local addition = tonumber(value) or 0
    if dedupe then
      toLevels[levelKey] = max(current, addition)
    else
      toLevels[levelKey] = current + addition
    end
  end
  for mapKey, value in pairs(fromMaps) do
    local current = tonumber(toMaps[mapKey]) or 0
    local addition = tonumber(value) or 0
    if dedupe then
      toMaps[mapKey] = max(current, addition)
    else
      toMaps[mapKey] = current + addition
    end
  end

  to.contexts = EnsureNumberMap(to.contexts)
  for contextKey, source in pairs(EnsureNumberMap(from.contexts)) do
    if type(source) == "table" then
      local target = to.contexts[contextKey]
      if type(target) ~= "table" then
        to.contexts[contextKey] = CopyTable(source)
      else
        target.samples = (tonumber(target.samples) or 0) + (tonumber(source.samples) or 0)
        target.sumBase = (tonumber(target.sumBase) or 0) + (tonumber(source.sumBase) or 0)
        target.sumBuffed = (tonumber(target.sumBuffed) or 0) + (tonumber(source.sumBuffed) or 0)
        target.sumTotal = (tonumber(target.sumTotal) or 0) + (tonumber(source.sumTotal) or 0)
        target.lastSeen = max(tonumber(target.lastSeen) or 0, tonumber(source.lastSeen) or 0)
        local sourceMin = tonumber(source.minBase) or 0
        local targetMin = tonumber(target.minBase) or 0
        if sourceMin > 0 and (targetMin == 0 or sourceMin < targetMin) then
          target.minBase = sourceMin
        end
        target.maxBase = max(tonumber(target.maxBase) or 0, tonumber(source.maxBase) or 0)
      end
    end
  end

  to.xp = type(to.xp) == "table" and to.xp or {}
  local fromXP = type(from.xp) == "table" and from.xp or {}
  to.xp.samples = (tonumber(to.xp.samples) or 0) + (tonumber(fromXP.samples) or 0)
  to.xp.sumBase = (tonumber(to.xp.sumBase) or 0) + (tonumber(fromXP.sumBase) or 0)
  to.xp.sumBuffed = (tonumber(to.xp.sumBuffed) or 0) + (tonumber(fromXP.sumBuffed) or 0)
  to.xp.sumTotal = (tonumber(to.xp.sumTotal) or 0) + (tonumber(fromXP.sumTotal) or 0)
  local fromMin = tonumber(fromXP.minBase) or 0
  local toMin = tonumber(to.xp.minBase) or 0
  if fromMin > 0 and (toMin == 0 or fromMin < toMin) then
    to.xp.minBase = fromMin
  end
  to.xp.maxBase = max(tonumber(to.xp.maxBase) or 0, tonumber(fromXP.maxBase) or 0)
  if (tonumber(to.xp.lastBase) or 0) == 0 then
    to.xp.lastBase = tonumber(fromXP.lastBase) or 0
  end
  if (tonumber(to.xp.lastTotal) or 0) == 0 then
    to.xp.lastTotal = tonumber(fromXP.lastTotal) or 0
  end

  local calibration = db.calibration and db.calibration.mobs
  if type(calibration) == "table" then
    local source = calibration[fromKey]
    local target = calibration[toKey]
    if type(source) == "table" then
      if type(target) ~= "table" then
        calibration[toKey] = source
      else
        local sourceSamples = tonumber(source.samples) or 0
        local targetSamples = tonumber(target.samples) or 0
        local totalSamples = sourceSamples + targetSamples
        if totalSamples > 0 then
          target.ratio = ((tonumber(target.ratio) or 1) * targetSamples
            + (tonumber(source.ratio) or 1) * sourceSamples) / totalSamples
        end
        target.samples = totalSamples
        target.updated = max(tonumber(target.updated) or 0, tonumber(source.updated) or 0)
      end
      calibration[fromKey] = nil
    end
  end

  if dedupe then
    db.totals = type(db.totals) == "table" and db.totals or {}
    db.session = type(db.session) == "table" and db.session or {}
    db.levels = EnsureNumberMap(db.levels)
    db.areas = EnsureNumberMap(db.areas)
    db.totals.kills = max(0, (tonumber(db.totals.kills) or 0) - duplicateKills)
    db.session.kills = max(0, (tonumber(db.session.kills) or 0) - duplicateSessionKills)
    for levelKey, overlap in pairs(levelDuplicates) do
      db.levels[levelKey] = max(0, (tonumber(db.levels[levelKey]) or 0) - overlap)
    end
    for mapKey, overlap in pairs(mapDuplicates) do
      db.areas[mapKey] = max(0, (tonumber(db.areas[mapKey]) or 0) - overlap)
    end
  end

  db.mobs[fromKey] = nil
  db.totals.uniqueMobs = max(0, (tonumber(db.totals.uniqueMobs) or 1) - 1)
  return true
end

function XPTooltip:ConsolidateNameOnlyMobs()
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return 0
  end
  local npcByName = {}
  for key, mob in pairs(db.mobs) do
    if type(key) == "string" and key:sub(1, 4) == "npc:" and type(mob) == "table" then
      local lower = Lower(mob.name)
      if lower then
        local matches = npcByName[lower]
        if not matches then
          matches = {}
          npcByName[lower] = matches
        end
        matches[#matches + 1] = key
      end
    end
  end

  local merges = {}
  for key, mob in pairs(db.mobs) do
    if type(key) == "string" and key:sub(1, 5) == "name:" and type(mob) == "table" then
      local lower = Lower(mob.name) or key:sub(6)
      local matches = npcByName[lower]
      if matches and #matches == 1 then
        merges[#merges + 1] = { from = key, to = matches[1] }
      end
    end
  end

  local merged = 0
  for _, pair in ipairs(merges) do
    if db.mobs[pair.from] and db.mobs[pair.to] then
      if self:MergeMobEntries(pair.from, pair.to, true) then
        merged = merged + 1
      end
    end
  end
  return merged
end

function XPTooltip:EnsureMob(mobKey, name, npcID, classification)
  local db = self.char
  local mob = db.mobs[mobKey]
  if type(mob) ~= "table" then
    mob = {
      npcID = npcID,
      name = name or "Unknown",
      classification = classification or "normal",
      firstSeen = Epoch(),
      lastSeen = 0,
      kills = 0,
      sessionKills = 0,
      killsAtLevel = {},
      killsByMap = {},
      contexts = {},
      xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 },
    }
    db.mobs[mobKey] = mob
    db.totals.uniqueMobs = (db.totals.uniqueMobs or 0) + 1
  else
    if npcID then
      mob.npcID = npcID
    end
    if name then
      mob.name = name
    end
    if classification then
      mob.classification = classification
    end
    mob.killsAtLevel = EnsureNumberMap(mob.killsAtLevel)
    mob.killsByMap = EnsureNumberMap(mob.killsByMap)
    mob.contexts = EnsureNumberMap(mob.contexts)
    mob.firstSeen = mob.firstSeen or Epoch()
  end
  return mob
end

--[[--------------------------------------------------------------------------------
  API wrappers
------------------------------------------------------------------------------------]]

function XPTooltip:GetPlayerLevel()
  return SafeNumber(SafeCall(UnitLevel, "player"))
end

function XPTooltip:GetXP()
  return SafeNumber(SafeCall(UnitXP, "player"))
end

function XPTooltip:GetXPMax()
  return SafeNumber(SafeCall(UnitXPMax, "player"))
end

function XPTooltip:GetMaxLevel()
  local maxLevel = SafeNumber(SafeCall(GetMaxPlayerLevel))
  if not maxLevel then
    maxLevel = SafeNumber(SafeCall(GetMaxLevelForPlayer))
  end
  return maxLevel or 60
end

function XPTooltip:IsXPDisabled()
  local disabled
  if C_PlayerInfo and C_PlayerInfo.IsXPUserDisabled then
    disabled = SafeBool(SafeCall(C_PlayerInfo.IsXPUserDisabled))
  end
  if disabled == nil and type(IsXPUserDisabled) == "function" then
    disabled = SafeBool(SafeCall(IsXPUserDisabled))
  end
  return disabled == true
end

function XPTooltip:GetRestedPool()
  return SafeNumber(SafeCall(GetXPExhaustion)) or 0
end

function XPTooltip:CanReadRested()
  if type(GetXPExhaustion) ~= "function" then
    return false
  end
  local ok, value = pcall(GetXPExhaustion)
  return ok and not IsSecret(value)
end

function XPTooltip:GetMapID()
  if C_Map and C_Map.GetBestMapForUnit then
    local mapID = SafeNumber(SafeCall(C_Map.GetBestMapForUnit, "player"))
    if mapID then
      return mapID
    end
  end
  local mapID = SafeNumber(SafeCall(GetCurrentMapAreaID))
  return mapID or 0
end

function XPTooltip:GetMapName(mapID)
  local id = tonumber(mapID)
  if not id then
    return "Unknown"
  end
  if C_Map and C_Map.GetMapInfo then
    local info = SafeCall(C_Map.GetMapInfo, id)
    if type(info) == "table" and type(info.name) == "string" and not IsSecret(info.name) then
      return info.name
    end
  end
  return "Map " .. tostring(id)
end

function XPTooltip:GetGroupSize()
  local size = SafeNumber(SafeCall(GetNumGroupMembers))
  if size and size > 0 then
    return size
  end
  return 1
end

function XPTooltip:ParseNPCID(guid)
  if not guid or IsSecret(guid) or type(guid) ~= "string" then
    return nil
  end
  local parts = {}
  for part in string.gmatch(guid, "[^-]+") do
    parts[#parts + 1] = part
  end
  if parts[1] ~= "Creature" then
    return nil
  end
  return tonumber(parts[6])
end

function XPTooltip:CaptureUnit(unit)
  local exists = SafeBool(SafeCall(UnitExists, unit))
  if not exists then
    return nil
  end
  local isPlayer = SafeBool(SafeCall(UnitIsPlayer, unit))
  if isPlayer == nil or isPlayer then
    return nil
  end
  local isDead = SafeBool(SafeCall(UnitIsDead, unit))
  if isDead == nil or isDead then
    return nil
  end
  local controlled = SafeBool(SafeCall(UnitPlayerControlled, unit))
  if controlled == nil or controlled then
    return nil
  end
  local creatureType = SafeCall(UnitCreatureType, unit)
  if creatureType == "Critter" then
    return nil
  end
  local canAttack = SafeBool(SafeCall(UnitCanAttack, "player", unit))
  if canAttack ~= true then
    return nil
  end
  local name = Trim(SafeCall(UnitName, unit))
  local guid = SafeString(SafeCall(UnitGUID, unit))
  local level = SafeNumber(SafeCall(UnitLevel, unit))
  local classification = SafeString(SafeCall(UnitClassification, unit)) or "normal"
  local npcID = guid and self:ParseNPCID(guid) or nil
  if not name and not npcID then
    return nil
  end
  return {
    name = name,
    guid = guid,
    level = level,
    classification = classification,
    npcID = npcID,
    mobKey = self:GetMobKey(name, npcID),
    mapID = self:GetMapID(),
    at = Now(),
  }
end

--[[--------------------------------------------------------------------------------
  Buffs and rest
------------------------------------------------------------------------------------]]

local function HasAura(name)
  if type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function" then
    local ok, aura = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
    if ok and aura and not IsSecret(aura) then
      return true
    end
  end
  if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
    for index = 1, 40 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
      if not ok or not aura then
        break
      end
      if not IsSecret(aura) then
        local auraName = aura.name
        if not IsSecret(auraName) and auraName == name then
          return true
        end
      end
    end
  end
  return false
end

local function HasAuraSpellID(spellID)
  if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then
    return false
  end
  for index = 1, 40 do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
    if not ok or not aura then
      break
    end
    if not IsSecret(aura) then
      local spellId = aura.spellId
      if not IsSecret(spellId) and tonumber(spellId) == spellID then
        return true
      end
    end
  end
  return false
end

function XPTooltip:CanDetectBuffs()
  local byName = type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function"
  local byID = C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function"
  return (byName or byID) and true or false
end

function XPTooltip:GetBuffInfo()
  local now = Now()
  local canDetect = self:CanDetectBuffs()
  if self.buffCacheTime and (now - self.buffCacheTime) < 1 then
    return self.buffCacheWellFed, self.buffCacheWellRested, self.buffCacheCanDetect
  end
  local wellFed = canDetect and HasAura("Well Fed") or false
  local wellRested = canDetect and (HasAura("Well-Rested") or HasAuraSpellID(429959)) or false
  self.buffCacheTime = now
  self.buffCacheWellFed = wellFed
  self.buffCacheWellRested = wellRested
  self.buffCacheCanDetect = canDetect
  return wellFed, wellRested, canDetect
end

function XPTooltip:GetBuffSignature()
  local settings = self.settings or self:GetSettings()
  local wellFed, wellRested = self:GetBuffInfo()
  local parts = {}
  if wellFed then
    parts[#parts + 1] = "wf"
  end
  if wellRested then
    parts[#parts + 1] = "wr"
  end
  local manual = settings and tonumber(settings.manualXPBonus) or 0
  if manual > 0 then
    parts[#parts + 1] = "m" .. tostring(manual)
  end
  if #parts == 0 then
    return "none", wellFed, wellRested
  end
  return table.concat(parts, "+"), wellFed, wellRested
end

function XPTooltip:GetBuffMultiplier(wellFed, wellRested)
  local settings = self.settings or self:GetSettings()
  local multiplier = 1
  if wellFed then
    multiplier = multiplier * 1.05
  end
  if wellRested then
    multiplier = multiplier * 1.03
  end
  local manual = settings and tonumber(settings.manualXPBonus) or 0
  if manual > 0 then
    multiplier = multiplier * (1 + manual / 100)
  end
  return multiplier
end

--[[--------------------------------------------------------------------------------
  Calibration
------------------------------------------------------------------------------------]]

function XPTooltip:UpdateRatio(store, key, ratio)
  if not store or not key then
    return
  end
  local entry = store[key]
  if type(entry) ~= "table" then
    entry = { ratio = ratio, samples = 0, updated = Epoch() }
    store[key] = entry
  end
  entry.samples = (tonumber(entry.samples) or 0) + 1
  local alpha = entry.samples <= 5 and 0.5 or 0.15
  entry.ratio = (tonumber(entry.ratio) or 1) + (ratio - (tonumber(entry.ratio) or 1)) * alpha
  entry.ratio = Clamp(entry.ratio, 0.5, 2.0)
  entry.updated = Epoch()
end

function XPTooltip:EffectiveRatio(entry)
  if type(entry) ~= "table" then
    return 1
  end
  local samples = tonumber(entry.samples) or 0
  if samples < 1 then
    return 1
  end
  local weight = min(samples, 10) / 10
  return 1 + ((tonumber(entry.ratio) or 1) - 1) * weight
end

function XPTooltip:HasRatioSamples(entry, minimum)
  return type(entry) == "table" and (tonumber(entry.samples) or 0) >= minimum
end

function XPTooltip:GetEstimate(playerLevel, mobLevel, classification, mapID, groupSize, mobKey, buffSignature)
  local base = FormulaXP(playerLevel, mobLevel, classification)
  if base <= 0 then
    return 0
  end

  local wellFed, wellRested = self:GetBuffInfo()
  local buffed = RoundForever(base * self:GetBuffMultiplier(wellFed, wellRested))

  local calibration = self.char and self.char.calibration
  local groupRatio
  if groupSize and groupSize > 1 then
    if GROUP_CALIBRATION_ENABLED then
      local groupEntry = calibration and calibration.groups[tostring(groupSize)]
      if self:HasRatioSamples(groupEntry, 5) then
        groupRatio = self:EffectiveRatio(groupEntry)
      else
        groupRatio = CLASSIC_GROUP_PRIOR[min(groupSize, 5)] or 1
      end
    else
      groupRatio = CLASSIC_GROUP_PRIOR[min(groupSize, 5)] or 1
    end
  else
    groupRatio = 1
  end

  local correction = 1
  if calibration then
    local function pick(entry, minimum)
      if not self:HasRatioSamples(entry, minimum) then
        return nil
      end
      local value = self:EffectiveRatio(entry)
      if math.abs(value - 1) < 0.02 then
        return nil
      end
      return value
    end

    local mobEntry = calibration.mobs[mobKey]
    local classEntry = calibration.classes[classification]
    local levelEntry = calibration.levels[tostring(playerLevel)]
    local zoneEntry = calibration.zones[tostring(mapID)]
    local picked = pick(mobEntry, 5)
      or pick(classEntry, 5)
      or pick(levelEntry, 5)
      or pick(zoneEntry, 3)
    if picked then
      correction = picked
    end
  end

  return RoundForever(buffed * groupRatio * correction)
end

--[[--------------------------------------------------------------------------------
  Kill and observation recording
------------------------------------------------------------------------------------]]

function XPTooltip:KillsToLevel(remaining, killXP, pool)
  if not remaining or remaining <= 0 or not killXP or killXP <= 0 then
    return 0
  end
  if not pool or pool <= 0 then
    return math.ceil(remaining / killXP)
  end

  local kills = 0
  while remaining > 0 and kills < 100000 do
    local bonus = min(killXP, floor(pool / 2))
    remaining = remaining - (killXP + bonus)
    pool = max(0, pool - 2 * bonus)
    kills = kills + 1
  end
  return kills
end

function XPTooltip:RecordObservation(mob, info, rawBase, buffedXP, totalXP)
  if not mob or not info or not rawBase or rawBase <= 0 then
    return
  end
  local playerLevel = info.playerLevel or self:GetPlayerLevel()
  local mobLevel = info.level
  if not playerLevel or not mobLevel then
    return
  end

  local classification = info.classification or mob.classification or "normal"
  local formula = FormulaXP(playerLevel, mobLevel, classification)
  if formula <= 0 then
    return
  end

  local contextKey = info.contextKey or ContextKey(
    playerLevel, mobLevel, info.groupSize or 1, info.mapID or 0, classification, info.buffSignature or "none"
  )
  local context = mob.contexts[contextKey]
  if type(context) ~= "table" then
    context = {
      playerLevel = playerLevel,
      mobLevel = mobLevel,
      groupSize = info.groupSize or 1,
      mapID = info.mapID or 0,
      classification = classification,
      buffSig = info.buffSignature or "none",
      samples = 0,
      sumBase = 0,
      sumBuffed = 0,
      sumTotal = 0,
      minBase = 0,
      maxBase = 0,
      lastSeen = 0,
    }
    mob.contexts[contextKey] = context
  end

  context.samples = (context.samples or 0) + 1
  context.sumBase = (context.sumBase or 0) + rawBase
  context.sumBuffed = (context.sumBuffed or 0) + (buffedXP or rawBase)
  context.sumTotal = (context.sumTotal or 0) + (totalXP or buffedXP or rawBase)
  context.lastSeen = Epoch()
  if context.minBase == 0 or rawBase < context.minBase then
    context.minBase = rawBase
  end
  if rawBase > (context.maxBase or 0) then
    context.maxBase = rawBase
  end

  local xp = mob.xp
  if type(xp) ~= "table" then
    xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 }
    mob.xp = xp
  end
  xp.samples = (xp.samples or 0) + 1
  xp.sumBase = (xp.sumBase or 0) + rawBase
  xp.sumBuffed = (xp.sumBuffed or 0) + (buffedXP or rawBase)
  xp.sumTotal = (xp.sumTotal or 0) + (totalXP or buffedXP or rawBase)
  xp.lastBase = rawBase
  xp.lastTotal = totalXP or buffedXP or rawBase
  if xp.minBase == 0 or rawBase < xp.minBase then
    xp.minBase = rawBase
  end
  if rawBase > (xp.maxBase or 0) then
    xp.maxBase = rawBase
  end

  local calibration = self.char.calibration
  local mapID = info.mapID or 0

  if info.groupSize and info.groupSize > 1 then
    -- Group observations are disabled until the live chat amount is verified.
    return
  end

  -- Each key stores the same observed/formula ratio. The estimator picks ONE
  -- correction by specificity (mob > class > level > zone), so the ratios are
  -- never multiplied together and cannot over-correct the same observation.
  local ratio = rawBase / formula
  if mapID and mapID > 0 then
    self:UpdateRatio(calibration.zones, tostring(mapID), ratio)
  end
  self:UpdateRatio(calibration.levels, tostring(playerLevel), ratio)
  self:UpdateRatio(calibration.classes, classification, ratio)
  self:UpdateRatio(calibration.mobs, info.mobKey or self:GetMobKey(info.name, info.npcID), ratio)
end

function XPTooltip:RecordKill(info, totalXP, rawBase, buffedXP, source, skipObservation)
  if not info then
    return
  end
  local db = self.char
  local playerLevel = info.playerLevel or self:GetPlayerLevel() or 0
  local mapID = info.mapID or self:GetMapID() or 0
  local mobKey = info.mobKey or self:GetMobKey(info.name, info.npcID)
  local lowerName = Lower(info.name)
  local nameKey = lowerName and ("name:" .. lowerName) or nil
  if info.npcID then
    local targetKey = "npc:" .. tostring(info.npcID)
    if nameKey and nameKey ~= targetKey and type(db.mobs) == "table" and db.mobs[nameKey] then
      self:MergeMobEntries(nameKey, targetKey)
    end
    mobKey = targetKey
  else
    local knownKey = type(mobKey) == "string" and mobKey:sub(1, 4) == "npc:" and mobKey
      or self:FindNPCKeyByName(info.name)
    if knownKey then
      if nameKey and nameKey ~= knownKey and type(db.mobs) == "table" and db.mobs[nameKey] then
        self:MergeMobEntries(nameKey, knownKey)
      end
      mobKey = knownKey
    elseif nameKey then
      mobKey = nameKey
    end
  end
  info.mobKey = mobKey
  local mob = self:EnsureMob(mobKey, info.name, info.npcID, info.classification)
  local now = Epoch()

  mob.kills = (tonumber(mob.kills) or 0) + 1
  mob.sessionKills = (tonumber(mob.sessionKills) or 0) + 1
  mob.lastSeen = now
  if playerLevel > 0 then
    local levelKey = tostring(playerLevel)
    mob.killsAtLevel[levelKey] = (tonumber(mob.killsAtLevel[levelKey]) or 0) + 1
    db.levels[levelKey] = (tonumber(db.levels[levelKey]) or 0) + 1
  end
  if mapID > 0 then
    local mapKey = tostring(mapID)
    mob.killsByMap[mapKey] = (tonumber(mob.killsByMap[mapKey]) or 0) + 1
    db.areas[mapKey] = (tonumber(db.areas[mapKey]) or 0) + 1
    if playerLevel > 0 then
      local areaLevels = db.areaLevels[mapKey]
      if type(areaLevels) ~= "table" then
        areaLevels = {}
        db.areaLevels[mapKey] = areaLevels
      end
      local levelKey = tostring(playerLevel)
      areaLevels[levelKey] = (tonumber(areaLevels[levelKey]) or 0) + 1
    end
  end

  db.totals.kills = (tonumber(db.totals.kills) or 0) + 1
  db.session.kills = (tonumber(db.session.kills) or 0) + 1
  if totalXP then
    db.totals.xp = (tonumber(db.totals.xp) or 0) + totalXP
    db.session.xp = (tonumber(db.session.xp) or 0) + totalXP
  end

  if rawBase and rawBase > 0 and not skipObservation then
    self:RecordObservation(mob, info, rawBase, buffedXP, totalXP)
  end

  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end

  if self.settings and self.settings.debug then
    AceM2L2:SafePrint(string.format(
      "Kill History: kill %s (%s) total=%s base=%s source=%s",
      tostring(mob.name or mobKey), tostring(mobKey), tostring(totalXP or "?"),
      tostring(rawBase or "?"), tostring(source or "?")
    ))
  end
end

--[[--------------------------------------------------------------------------------
  XP chat / XP update
------------------------------------------------------------------------------------]]

function XPTooltip:QueueUnidentifiedKill(info, totalXP, rawBase, buffedXP, skipObservation)
  if not self.pendingChatXP then
    self.pendingChatXP = {}
  end
  local stored = {}
  for key, value in pairs(info or {}) do
    stored[key] = value
  end
  local entry = {
    info = stored,
    totalXP = totalXP,
    rawBase = rawBase,
    buffedXP = buffedXP,
    skipObservation = skipObservation and true or false,
    at = Now(),
    generation = self.dataGeneration,
    consumed = false,
    canceled = false,
  }
  self.pendingChatXP[#self.pendingChatXP + 1] = entry
  if self.settings and self.settings.debug then
    AceM2L2:SafePrint(string.format(
      "Kill History: XP %s has no creature name yet; waiting for UNIT_DIED.",
      tostring(totalXP or "?")
    ))
  end
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 3.0, function()
      self:CommitUnidentifiedKill(entry)
    end)
  else
    self:CommitUnidentifiedKill(entry)
  end
  return entry
end

function XPTooltip:RemovePendingChatKill(entry)
  if not self.pendingChatXP then
    return
  end
  for index = #self.pendingChatXP, 1, -1 do
    if self.pendingChatXP[index] == entry then
      table.remove(self.pendingChatXP, index)
    end
  end
end

function XPTooltip:TakePendingChatKill(now)
  if not self.pendingChatXP then
    return nil
  end
  for index = 1, #self.pendingChatXP do
    local entry = self.pendingChatXP[index]
    if entry and not entry.consumed and not entry.canceled
      and entry.generation == self.dataGeneration
      and (now - (entry.at or 0)) <= 4 then
      entry.consumed = true
      table.remove(self.pendingChatXP, index)
      return entry
    end
  end
  return nil
end

function XPTooltip:CommitUnidentifiedKill(entry)
  if not entry or entry.consumed or entry.canceled then
    return
  end
  entry.consumed = true
  self:RemovePendingChatKill(entry)
  if entry.generation ~= self.dataGeneration or not self:IsActive() then
    return
  end
  local info = entry.info or { name = "Unknown" }
  info.playerLevel = info.playerLevel or self:GetPlayerLevel() or 1
  info.level = info.level or info.playerLevel
  info.classification = info.classification or "normal"
  info.groupSize = info.groupSize or self:GetGroupSize()
  info.mapID = info.mapID or self:GetMapID()
  info.buffSignature = info.buffSignature or self:GetBuffSignature()
  info.contextKey = ContextKey(
    info.playerLevel, info.level, info.groupSize, info.mapID,
    info.classification, info.buffSignature
  )
  if not info.mobKey then
    info.mobKey = self:GetMobKey(info.name, info.npcID)
  end
  if self.settings and self.settings.debug then
    AceM2L2:SafePrint(string.format(
      "Kill History: no death identity for XP %s; recording as %s.",
      tostring(entry.totalXP or "?"), tostring(info.name or "Unknown")
    ))
  end
  self:RecordKill(info, entry.totalXP, entry.rawBase, entry.buffedXP, "chat", entry.skipObservation)
  self.lastPool = self:GetRestedPool()
end

function XPTooltip:FindKillInfo(name, now)
  for index = #self.pendingDeaths, 1, -1 do
    local pending = self.pendingDeaths[index]
    if pending and not pending.counted then
      local pendingName = pending.info and pending.info.name
      if (now - pending.at) <= 3 and (not name or not pendingName or Lower(name) == Lower(pendingName)) then
        pending.counted = true
        return pending.info
      end
    end
  end

  local function matches(candidate)
    return candidate
      and (now - candidate.at) <= 3
      and (not name or not candidate.name or Lower(name) == Lower(candidate.name))
  end

  if matches(self.lastTarget) then
    return self.lastTarget
  end
  if matches(self.lastMouseover) then
    return self.lastMouseover
  end
  return { name = name or "Unknown", mobKey = self:GetMobKey(name), at = now }
end

function XPTooltip:OnXPChat(event, message)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleXPChat, self, message)
  if not ok then
    self:ReportError("OnXPChat", err)
  end
end

function XPTooltip:HandleXPChat(message)
  if IsSecret(message) then
    return
  end

  local name, total, key = AceM2L2:ParseXPMessage(message)
  if not key or not total or total <= 0 then
    return
  end
  if key:find("_QUEST", 1, true) then
    return
  end

  local now = Now()
  self.lastXPChatAt = now
  local poolAfter = self:GetRestedPool()
  local poolBefore = self.poolBeforeKill or self.lastPool or poolAfter
  self.poolBeforeKill = nil
  local wellFed, wellRested, buffDetection = self:GetBuffInfo()
  local buffMultiplier = self:GetBuffMultiplier(wellFed, wellRested)
  local buffedXP = total
  local rawBase = buffedXP / buffMultiplier
  -- Do not use rested kills for calibration unless the chat text is known to
  -- expose the base/rested split. The total already includes rested, so only
  -- non-rested observations are clean.
  local skipObservation = (poolAfter > 0) or (poolBefore > poolAfter) or (not buffDetection)

  local source = self:FindKillInfo(name, now)
  local info = CopyInfo(source) or {
    name = name or "Unknown",
    mobKey = self:GetMobKey(name),
    at = now,
  }
  local playerLevel = self:GetPlayerLevel() or 1
  local mobLevel = info.level
  if not mobLevel or mobLevel == 0 then
    mobLevel = playerLevel
  end
  local classification = info.classification or "normal"
  local groupSize = self:GetGroupSize()
  local mapID = self:GetMapID()
  local buffSignature = self:GetBuffSignature()
  if buffSignature ~= "none" then
    skipObservation = true
  end
  if groupSize > 1 then
    -- Until the live chat amount is verified for group kills, use the classic
    -- group prior for display and do not train a group ratio from a possibly
    -- summed "base + party bonus" text.
    skipObservation = true
  end
  if not self:CanReadRested() then
    skipObservation = true
  end

  info.playerLevel = playerLevel
  info.level = mobLevel
  info.classification = classification
  info.groupSize = groupSize
  info.mapID = mapID
  info.buffSignature = buffSignature
  info.contextKey = ContextKey(playerLevel, mobLevel, groupSize, mapID, classification, buffSignature)
  if not info.mobKey then
    info.mobKey = self:GetMobKey(info.name, info.npcID)
  end

  local resolvedName = Lower(info.name)
  if (not name or name == "" or Lower(name) == "unknown")
    and (not resolvedName or resolvedName == "" or resolvedName == "unknown") then
    -- Some XP messages omit the creature name. Wait briefly for UNIT_DIED so
    -- the guid/target path can identify the mob instead of recording "Unknown".
    self.lastPool = poolAfter
    self:QueueUnidentifiedKill(info, total, rawBase, buffedXP, skipObservation)
    return
  end

  self:RecordKill(info, total, rawBase, buffedXP, "chat", skipObservation)
  self.recentChatKills[#self.recentChatKills + 1] = {
    mobKey = info.mobKey,
    name = info.name,
    at = now,
  }
  while #self.recentChatKills > MAX_PENDING_DEATHS do
    table.remove(self.recentChatKills, 1)
  end
  self.lastPool = poolAfter
end

function XPTooltip:OnPlayerXPUpdate(event)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandlePlayerXPUpdate, self)
  if not ok then
    self:ReportError("OnPlayerXPUpdate", err)
  end
end

function XPTooltip:HandlePlayerXPUpdate()
  local current = self:GetXP()
  if not current then
    return
  end

  self.lastXP = current
  self.lastPool = self:GetRestedPool()
  self.lastXPUpdateAt = Now()
end

--[[--------------------------------------------------------------------------------
  Death tracking
------------------------------------------------------------------------------------]]

function XPTooltip:FindDeathCandidate(guid)
  local now = Now()
  -- Exact GUID matches are safe even if the target was acquired long ago.
  -- Target units are often cleared as soon as a mob dies, so keep the last
  -- valid hostile target briefly instead of dropping its identity.
  if guid and self.lastTarget and self.lastTarget.guid == guid
    and (now - (self.lastTarget.at or 0)) <= 60 then
    return self.lastTarget
  end
  if guid and self.lastMouseover and self.lastMouseover.guid == guid
    and (now - (self.lastMouseover.at or 0)) <= 60 then
    return self.lastMouseover
  end

  local targetDead = SafeBool(SafeCall(UnitIsDead, "target"))
  if targetDead and self.lastTarget and (now - self.lastTarget.at) <= 10 then
    return self.lastTarget
  end
  local mouseoverDead = SafeBool(SafeCall(UnitIsDead, "mouseover"))
  if mouseoverDead and self.lastMouseover and (now - self.lastMouseover.at) <= 10 then
    return self.lastMouseover
  end

  return nil
end

function XPTooltip:OnUnitDied(event, guid)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleUnitDied, self, guid)
  if not ok then
    self:ReportError("OnUnitDied", err)
  end
end

function XPTooltip:HandleUnitDied(guid)
  local safeGUID = SafeString(guid)
  local candidate = self:FindDeathCandidate(safeGUID)
  if not candidate then
    return
  end

  -- The XP chat event can arrive before UNIT_DIED. If we already counted this
  -- kill from chat, do not queue a second zero-XP death for it.
  local now = Now()
  for index = #self.recentChatKills, 1, -1 do
    local recent = self.recentChatKills[index]
    if recent and (now - (recent.at or 0)) <= 3 then
      local sameKey = recent.mobKey and candidate.mobKey and recent.mobKey == candidate.mobKey
      local bothKeysKnown = recent.mobKey and candidate.mobKey
      local sameName = recent.name and candidate.name and Lower(recent.name) == Lower(candidate.name)
      local recentNameOnly = type(recent.mobKey) == "string" and recent.mobKey:sub(1, 5) == "name:"
      local candidateNameOnly = type(candidate.mobKey) == "string" and candidate.mobKey:sub(1, 5) == "name:"
      if sameKey or (sameName and (recentNameOnly or candidateNameOnly))
        or (not bothKeysKnown and sameName) then
        if sameName and not sameKey and recent.mobKey and candidate.mobKey then
          if recentNameOnly then
            self:MergeMobEntries(recent.mobKey, candidate.mobKey)
          elseif candidateNameOnly then
            self:MergeMobEntries(candidate.mobKey, recent.mobKey)
          end
        end
        table.remove(self.recentChatKills, index)
        return
      end
    end
  end

  local pendingXP = self:TakePendingChatKill(now)
  if pendingXP then
    local info = CopyInfo(candidate) or {}
    local stored = pendingXP.info or {}
    info.name = info.name or stored.name
    info.guid = info.guid or stored.guid
    info.npcID = info.npcID or stored.npcID
    info.mobKey = info.mobKey or self:GetMobKey(info.name, info.npcID)
    info.level = info.level or stored.level
    info.classification = info.classification or stored.classification
    info.playerLevel = stored.playerLevel or self:GetPlayerLevel() or 1
    info.groupSize = stored.groupSize or self:GetGroupSize()
    info.mapID = stored.mapID or self:GetMapID()
    info.buffSignature = stored.buffSignature or self:GetBuffSignature()
    info.contextKey = ContextKey(
      info.playerLevel, info.level or info.playerLevel, info.groupSize, info.mapID,
      info.classification or "normal", info.buffSignature
    )
    self:RecordKill(info, pendingXP.totalXP, pendingXP.rawBase, pendingXP.buffedXP, "chat", pendingXP.skipObservation)
    return
  end

  self.poolBeforeKill = self:GetRestedPool()

  local entry = {
    info = candidate,
    at = Now(),
    counted = false,
    committed = false,
    generation = self.dataGeneration,
    countZero = self.settings and self.settings.countZeroXPMobs,
  }
  self.pendingDeaths[#self.pendingDeaths + 1] = entry
  while #self.pendingDeaths > MAX_PENDING_DEATHS do
    table.remove(self.pendingDeaths, 1)
  end

  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 2.5, function()
      self:CommitPendingDeath(entry)
    end)
  else
    self:CommitPendingDeath(entry)
  end
end

function XPTooltip:CommitPendingDeath(entry)
  if not entry or entry.counted or entry.committed then
    return
  end
  if entry.generation ~= self.dataGeneration then
    return
  end
  entry.committed = true
  if not self:IsActive() then
    return
  end
  if entry.countZero then
    local info = CopyInfo(entry.info) or { name = "Unknown", at = Now() }
    info.playerLevel = self:GetPlayerLevel() or 1
    info.level = info.level or info.playerLevel
    info.classification = info.classification or "normal"
    info.groupSize = self:GetGroupSize()
    info.mapID = info.mapID or self:GetMapID()
    info.buffSignature = self:GetBuffSignature()
    info.contextKey = ContextKey(
      info.playerLevel, info.level, info.groupSize, info.mapID, info.classification, info.buffSignature
    )
    self:RecordKill(info, nil, nil, nil, "death")
  end
  self.poolBeforeKill = nil
end

--[[--------------------------------------------------------------------------------
  Events
------------------------------------------------------------------------------------]]

function XPTooltip:OnTargetChanged(event)
  if not self:IsActive() then
    return
  end
  local captured = self:CaptureUnit("target")
  if captured then
    self.lastTarget = captured
  elseif self.lastTarget and (Now() - (self.lastTarget.at or 0)) > 60 then
    self.lastTarget = nil
  end
end

function XPTooltip:OnMouseoverChanged(event)
  if not self:IsActive() then
    return
  end
  local captured = self:CaptureUnit("mouseover")
  if captured then
    self.lastMouseover = captured
  elseif self.lastMouseover and (Now() - (self.lastMouseover.at or 0)) > 60 then
    self.lastMouseover = nil
  end
end

function XPTooltip:OnZoneChanged(event)
  self.lastPool = self:GetRestedPool()
  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end

function XPTooltip:OnLevelUp(event, level)
  self.lastPool = self:GetRestedPool()
  self:SchedulePrune()
  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end

function XPTooltip:OnLogin(event)
  self:StartSession()
  self.lastXP = self:GetXP()
  self.lastPool = self:GetRestedPool()
  self:SchedulePrune()
end

function XPTooltip:OnEnteringWorld(event)
  self.lastPool = self:GetRestedPool()
  if not self.active then
    self:Refresh()
  end
end

function XPTooltip:OnXPGainEnabled(event)
  self.lastXP = self:GetXP()
end

function XPTooltip:OnXPGainDisabled(event)
  self.lastXP = self:GetXP()
end

function XPTooltip:OnMaxLevelUpdate(event)
  self.lastPool = self:GetRestedPool()
end

function XPTooltip:StartSession()
  local db = self.char
  if type(db.session) ~= "table" then
    db.session = {}
  end
  db.session.startedAt = Epoch()
  db.session.kills = 0
  db.session.xp = 0
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      mob.sessionKills = 0
    end
  end
end

function XPTooltip:SchedulePrune()
  if self.pruneScheduled then
    return
  end
  self.pruneScheduled = true
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 5, function()
      self.pruneScheduled = false
      if self:IsActive() then
        self:Prune()
      end
    end)
  else
    self.pruneScheduled = false
    self:Prune()
  end
end

function XPTooltip:Prune()
  local db = self.char
  if not db then
    return
  end
  local now = Epoch()
  local mobCount = 0

  for mobKey, mob in pairs(db.mobs) do
    if type(mob) ~= "table" then
      db.mobs[mobKey] = nil
    else
      mobCount = mobCount + 1
      mob.kills = math.max(0, tonumber(mob.kills) or 0)
      mob.sessionKills = math.max(0, tonumber(mob.sessionKills) or 0)
      if type(mob.name) ~= "string" then
        mob.name = "Unknown"
      elseif #mob.name > 80 then
        mob.name = mob.name:sub(1, 80)
      end
      mob.killsAtLevel = EnsureNumberMap(mob.killsAtLevel)
      mob.killsByMap = EnsureNumberMap(mob.killsByMap)
      mob.contexts = EnsureNumberMap(mob.contexts)

      local contextCount = 0
      local oldestKey, oldestSeen
      for contextKey, context in pairs(mob.contexts) do
        if type(context) ~= "table" then
          mob.contexts[contextKey] = nil
        else
          local lastSeen = tonumber(context.lastSeen) or 0
          if lastSeen > 0 and (now - lastSeen) > CONTEXT_MAX_AGE then
            mob.contexts[contextKey] = nil
          else
            contextCount = contextCount + 1
            if not oldestSeen or lastSeen < oldestSeen then
              oldestSeen = lastSeen
              oldestKey = contextKey
            end
          end
        end
      end
      while contextCount > MAX_CONTEXTS_PER_MOB and oldestKey do
        mob.contexts[oldestKey] = nil
        contextCount = contextCount - 1
        oldestKey, oldestSeen = nil, nil
        for contextKey, context in pairs(mob.contexts) do
          local lastSeen = tonumber(context.lastSeen) or 0
          if not oldestSeen or lastSeen < oldestSeen then
            oldestSeen = lastSeen
            oldestKey = contextKey
          end
        end
      end
    end
  end

  if mobCount > MAX_MOBS then
    local removable = {}
    for mobKey, mob in pairs(db.mobs) do
      if type(mob) == "table" and (tonumber(mob.kills) or 0) <= 0 then
        removable[#removable + 1] = { key = mobKey, seen = tonumber(mob.lastSeen) or 0 }
      end
    end
    table.sort(removable, function(a, b) return a.seen < b.seen end)
    for _, entry in ipairs(removable) do
      if mobCount <= MAX_MOBS then
        break
      end
      db.mobs[entry.key] = nil
      if db.calibration and db.calibration.mobs then
        db.calibration.mobs[entry.key] = nil
      end
      mobCount = mobCount - 1
    end
  end

  if mobCount > MAX_MOBS then
    local removable = {}
    for mobKey, mob in pairs(db.mobs) do
      if type(mob) == "table" then
        removable[#removable + 1] = { key = mobKey, seen = tonumber(mob.lastSeen) or 0 }
      end
    end
    table.sort(removable, function(a, b) return a.seen < b.seen end)
    for _, entry in ipairs(removable) do
      if mobCount <= MAX_MOBS then
        break
      end
      db.mobs[entry.key] = nil
      if db.calibration and db.calibration.mobs then
        db.calibration.mobs[entry.key] = nil
      end
      mobCount = mobCount - 1
    end
  end
end

--[[--------------------------------------------------------------------------------
  Compatibility and lifecycle
------------------------------------------------------------------------------------]]

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

--[[--------------------------------------------------------------------------------
  Tooltip
------------------------------------------------------------------------------------]]

function XPTooltip:ToggleUI()
  if self.ui and self.ui:IsShown() then
    self:CloseUI()
  else
    self:OpenUI()
  end
end

function XPTooltip:InitializeMinimap()
  if not self:IsActive() then
    self:HideMinimapIcon()
    return
  end
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  local icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not ldb or type(ldb.NewDataObject) ~= "function"
    or not icon or type(icon.Register) ~= "function" then
    return
  end
  local settings = self:GetSettings()
  if type(settings.minimap) ~= "table" then
    settings.minimap = CopyTable(DEFAULT_MINIMAP)
  end
  if self.minimapSettingsTable ~= settings.minimap then
    self.minimapSettingsTable = settings.minimap
    self.minimapRegistered = false
  end
  if not self.minimapObject then
    self.minimapObject = ldb:NewDataObject("AceM2L2", {
      type = "launcher",
      icon = "Interface\\Icons\\INV_Misc_Map_01",
      iconR = 0.55,
      iconG = 0.84,
      iconB = 1.00,
      OnClick = function(_, button)
        self:OnMinimapClick(button)
      end,
      OnTooltipShow = function(tooltip)
        self:OnMinimapTooltip(tooltip)
      end,
    })
  end
  if not self.minimapRegistered then
    local ok = pcall(icon.Register, icon, "AceM2L2", self.minimapObject, settings.minimap)
    if not ok then
      return
    end
    self.minimapRegistered = true
  end
  self.minimapIcon = icon
  self:UpdateMinimapVisibility()
end

function XPTooltip:HideMinimapIcon()
  if self.minimapIcon and self.minimapRegistered then
    pcall(self.minimapIcon.Hide, self.minimapIcon, "AceM2L2")
  end
end

function XPTooltip:UpdateMinimapVisibility()
  if not self.minimapIcon or not self.minimapRegistered then
    return
  end
  local settings = self:GetSettings()
  local hidden = settings and settings.minimap and settings.minimap.hide
  if hidden or not self:IsActive() then
    pcall(self.minimapIcon.Hide, self.minimapIcon, "AceM2L2")
  else
    pcall(self.minimapIcon.Show, self.minimapIcon, "AceM2L2")
  end
end

function XPTooltip:OnMinimapClick(button)
  if button == "RightButton" then
    AceM2L2:HandleSlashCommand("config")
  else
    self:ToggleUI()
  end
end

function XPTooltip:OnMinimapTooltip(tooltip)
  if not tooltip then
    return
  end
  local theme = self:GetTheme()
  tooltip:AddLine("Ace Mobs 2 Level 2 - Kill History", theme.text[1], theme.text[2], theme.text[3])
  tooltip:AddLine(self:GetStatusText(), theme.muted[1], theme.muted[2], theme.muted[3])
  local db = self.char
  if db then
    tooltip:AddLine(
      "Kills: " .. FormatNumber(db.totals.kills or 0)
        .. "   Session: " .. FormatNumber(db.session.kills or 0),
      theme.muted[1], theme.muted[2], theme.muted[3]
    )
    local topMap, topKills = nil, 0
    for mapKey, kills in pairs(db.areas or {}) do
      if (tonumber(kills) or 0) > topKills then
        topKills = tonumber(kills) or 0
        topMap = mapKey
      end
    end
    if topMap then
      tooltip:AddLine(
        "Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topKills) .. ")",
        theme.muted[1], theme.muted[2], theme.muted[3]
      )
    end
  end
  tooltip:AddLine("Left-click: open   Right-click: settings", theme.muted[1], theme.muted[2], theme.muted[3])
end

function XPTooltip:PrintMinimapStatus()
  local settings = self:GetSettings()
  local minimap = settings and settings.minimap or {}
  local state = "shown"
  if minimap.hide then
    state = "hidden"
  elseif not self:IsActive() then
    state = "inactive (module disabled)"
  end
  AceM2L2:SafePrint("Kill History minimap icon: " .. state)
end

function XPTooltip:InstallTooltipHook()
  if self.tooltipHookInstalled then
    return
  end
  self.tooltipHookInstalled = true

  local installed = false
  if self.hasProcessor then
    local ok = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tooltip, data)
      self:OnTooltip(tooltip, data)
    end)
    installed = ok
  end

  if not installed and GameTooltip and GameTooltip.HookScript then
    local ok = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tooltip)
      self:OnTooltip(tooltip, nil)
    end)
    installed = ok
    if ok then
      self.hasProcessor = false
    end
  end

  if not installed then
    self.tooltipHookInstalled = false
    self:ReportError("tooltip hook", "no usable tooltip hook")
  end

  if GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(tooltip)
      tooltip.xpTooltipSignature = nil
    end)
  end
end

function XPTooltip:OnTooltip(tooltip, data)
  if not self:IsActive() then
    return
  end
  if not tooltip or tooltip ~= GameTooltip then
    return
  end

  local ok, err = pcall(self.AddTooltipLines, self, tooltip, data)
  if not ok then
    self:ReportError("tooltip", err)
  end
end

function XPTooltip:IsTooltipCandidate(unit)
  if not unit or type(unit) ~= "string" or IsSecret(unit) then
    return false
  end
  if not UnitExists(unit) then
    return false
  end
  local isPlayer = SafeBool(SafeCall(UnitIsPlayer, unit))
  if isPlayer == nil or isPlayer then
    return false
  end
  local isDead = SafeBool(SafeCall(UnitIsDead, unit))
  if isDead == nil or isDead then
    return false
  end
  local controlled = SafeBool(SafeCall(UnitPlayerControlled, unit))
  if controlled == nil or controlled then
    return false
  end
  local creatureType = SafeCall(UnitCreatureType, unit)
  if creatureType == "Critter" then
    return false
  end
  local canAttack = SafeBool(SafeCall(UnitCanAttack, "player", unit))
  return canAttack == true
end

function XPTooltip.AddTooltipLines(self, tooltip, data)
  local unit = select(2, tooltip:GetUnit())
  if not unit and data then
    local guid = SafeString(data.guid)
    if guid and self.lastTarget and self.lastTarget.guid == guid then
      unit = "target"
    elseif guid and self.lastMouseover and self.lastMouseover.guid == guid then
      unit = "mouseover"
    end
  end
  if not unit and UnitExists("mouseover") then
    unit = "mouseover"
  end
  if not self:IsTooltipCandidate(unit) then
    return
  end

  local playerLevel = self:GetPlayerLevel()
  local xpMax = self:GetXPMax()
  local xpCurrent = self:GetXP()
  if not playerLevel or not xpMax or not xpCurrent or xpMax <= 0 then
    return
  end
  local maxLevel = self:GetMaxLevel()
  if playerLevel >= maxLevel or self:IsXPDisabled() then
    return
  end

  local name = Trim(SafeCall(UnitName, unit))
  name = Trim(name)
  local guid = SafeString(SafeCall(UnitGUID, unit))
  local npcID = guid and self:ParseNPCID(guid) or nil
  local rawMobLevel = SafeNumber(SafeCall(UnitLevel, unit))
  local mobLevel
  if rawMobLevel == nil or rawMobLevel == 0 then
    mobLevel = playerLevel
  else
    mobLevel = rawMobLevel
  end
  local classification = SafeString(SafeCall(UnitClassification, unit)) or "normal"
  local mobKey = self:GetMobKey(name, npcID)
  local mapID = self:GetMapID()
  local groupSize = self:GetGroupSize()
  local buffSignature = self:GetBuffSignature()
  local contextKey = ContextKey(playerLevel, mobLevel, groupSize, mapID, classification, buffSignature)

  local mob = self.char and self.char.mobs[mobKey] or nil
  local exact = false
  local estimate
  if (not groupSize or groupSize <= 1) and type(mob) == "table" and type(mob.contexts) == "table" then
    local context = mob.contexts[contextKey]
    if type(context) == "table" and (tonumber(context.samples) or 0) >= 1 then
      estimate = RoundForever((tonumber(context.sumBuffed) or 0) / context.samples)
      exact = true
    end
  end
  if not estimate or estimate <= 0 then
    estimate = self:GetEstimate(playerLevel, mobLevel, classification, mapID, groupSize, mobKey, buffSignature)
  end
  local soloEstimate = estimate
  if groupSize and groupSize > 1 then
    soloEstimate = self:GetEstimate(playerLevel, mobLevel, classification, mapID, 1, mobKey, buffSignature)
  end
  if not estimate or estimate <= 0 then
    if self.settings.showUnknown then
      tooltip:AddLine("|cffaaaaaaXP: no XP from this mob|r")
    end
    return
  end

  local signature = tostring(unit) .. ":" .. tostring(guid or "") .. ":" .. tostring(playerLevel)
    .. ":" .. tostring(mobLevel) .. ":" .. tostring(estimate) .. ":" .. tostring(soloEstimate)
    .. ":" .. tostring(groupSize) .. ":" .. tostring(buffSignature)
  if tooltip.xpTooltipSignature == signature then
    return
  end
  tooltip.xpTooltipSignature = signature

  local pool = self:GetRestedPool()
  local restedBonus = min(estimate, floor(pool / 2))
  local totalXP = estimate + restedBonus
  local percent = totalXP / xpMax * 100
  local remaining = xpMax - xpCurrent
  local kills = self:KillsToLevel(remaining, estimate, pool)
  local prefix = exact and "" or "~"
  local settings = self.settings

  if settings.showXP then
    local value = prefix .. FormatNumber(totalXP)
    if settings.showPercent then
      value = value .. " (" .. FormatPercent(percent) .. " of level)"
    end
    if groupSize and groupSize > 1 then
      value = value .. " |cffaaaaaa(group share; solo " .. prefix .. FormatNumber(soloEstimate) .. ")|r"
    end
    tooltip:AddDoubleLine("|cffaaaaaaXP:|r", "|cffffffff" .. value .. "|r")
  end

  if settings.showRested and pool > 0 and restedBonus > 0 then
    tooltip:AddDoubleLine(
      "|cffaaaaaaRested bonus:|r",
      "|cff55ff55+" .. FormatNumber(restedBonus) .. "|r |cffaaaaaa(pool " .. FormatNumber(pool) .. ")|r"
    )
  end

  if settings.showKillsToLevel and kills and kills > 0 then
    local suffix = ""
    if pool > 0 and settings.showRested then
      suffix = " |cffaaaaaa(while rested)|r"
    end
    tooltip:AddDoubleLine("|cffaaaaaaKills to level:|r", "|cffffffff" .. prefix .. FormatNumber(kills) .. suffix)
  end

  if settings.showKillCount then
    local killsTotal = tonumber(mob and mob.kills) or 0
    local killsAtLevel = 0
    if mob and type(mob.killsAtLevel) == "table" then
      killsAtLevel = tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0
    end
    tooltip:AddDoubleLine(
      "|cffaaaaaaKilled:|r",
      "|cffffffff" .. FormatNumber(killsTotal) .. "|r |cffaaaaaa(this level: " .. FormatNumber(killsAtLevel) .. ")|r"
    )
  end

  if groupSize and groupSize > 1 and settings.showXP then
    tooltip:AddLine("|cffaaaaaaGroup kills split XP; the XP line is your share.|r")
  end
end

--[[--------------------------------------------------------------------------------
  Commands
------------------------------------------------------------------------------------]]

function XPTooltip:PrintStatus()
  local compatible, reason, hasProcessor, hasHook = self:CheckCompatibility()
  AceM2L2:SafePrint("Kill History: " .. self:GetStatusText())
  AceM2L2:SafePrint("  Project=" .. tostring(WOW_PROJECT_ID) .. ", Forever=" .. tostring(WOW_PROJECT_ID == CAMELOT_PROJECT_ID))
  AceM2L2:SafePrint("  Interface=" .. tostring(AceM2L2:GetInterfaceVersion())
    .. ", compatible=" .. tostring(compatible)
    .. ", processor=" .. tostring(hasProcessor)
    .. ", fallback=" .. tostring(hasHook))
  AceM2L2:SafePrint("  Buff detection=" .. tostring(self:CanDetectBuffs()))
  local settings = self:GetSettings()
  local minimap = settings and settings.minimap or {}
  AceM2L2:SafePrint("  Minimap=" .. (minimap.hide and "hidden" or "shown"))
  if not compatible and reason and reason ~= "" then
    AceM2L2:SafePrint("  Reason: " .. reason)
  end
  if self.autoDisabled and self.autoDisableReason and self.autoDisableReason ~= reason then
    AceM2L2:SafePrint("  AutoDisable: " .. tostring(self.autoDisableReason))
  end
  if self.lastError then
    AceM2L2:SafePrint("  LastError: " .. tostring(self.lastError))
  end
end

function XPTooltip:PrintKills(filter)
  local db = self.char
  if not db then
    return
  end
  local list = {}
  local lowerFilter = Lower(filter)
  for mobKey, mob in pairs(db.mobs) do
    if type(mob) == "table" and (tonumber(mob.kills) or 0) > 0 then
      if not lowerFilter or lowerFilter == "" or (Lower(mob.name) or ""):find(lowerFilter, 1, true) then
        list[#list + 1] = { key = mobKey, mob = mob }
      end
    end
  end
  table.sort(list, function(a, b)
    return (tonumber(a.mob.kills) or 0) > (tonumber(b.mob.kills) or 0)
  end)

  if #list == 0 then
    AceM2L2:SafePrint("Kill History: no kills recorded yet.")
    return
  end

  if lowerFilter and lowerFilter ~= "" then
    local entry = list[1]
    local mob = entry.mob
    AceM2L2:SafePrint(string.format("%s (%s)", tostring(mob.name or entry.key), tostring(entry.key)))
    AceM2L2:SafePrint("  Total kills: " .. FormatNumber(mob.kills))
    AceM2L2:SafePrint("  This session: " .. FormatNumber(mob.sessionKills or 0))
    if type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
      AceM2L2:SafePrint("  Avg base XP: " .. FormatNumber((mob.xp.sumBase or 0) / mob.xp.samples))
      AceM2L2:SafePrint("  Avg total XP: " .. FormatNumber((mob.xp.sumTotal or 0) / mob.xp.samples))
    end
    AceM2L2:SafePrint("  First seen: " .. FormatDate(mob.firstSeen))
    AceM2L2:SafePrint("  Last seen: " .. FormatAgo(mob.lastSeen))
    return
  end

  AceM2L2:SafePrint("Top mobs killed:")
  for index = 1, min(#list, 15) do
    local mob = list[index].mob
    local avg = ""
    if type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
      avg = "  avg " .. FormatNumber((mob.xp.sumBase or 0) / mob.xp.samples) .. " XP"
    end
    AceM2L2:SafePrint(string.format(
      "  %-24s %8s%s  (%s)", tostring(mob.name or "Unknown"), FormatNumber(mob.kills), avg, FormatAgo(mob.lastSeen)
    ))
  end
end

function XPTooltip:PrintAreas()
  local db = self.char
  if not db then
    return
  end
  local total = tonumber(db.totals and db.totals.kills) or 0
  local list = {}
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > 0 then
      list[#list + 1] = { mapID = mapKey, kills = tonumber(kills) or 0 }
    end
  end
  table.sort(list, function(a, b) return a.kills > b.kills end)
  if #list == 0 then
    AceM2L2:SafePrint("Kill History: no area data yet.")
    return
  end
  AceM2L2:SafePrint("Kills by area:")
  for index = 1, min(#list, 15) do
    local entry = list[index]
    local percent = total > 0 and (entry.kills / total * 100) or 0
    AceM2L2:SafePrint(string.format(
      "  %-30s %8s  (%.1f%%)", self:GetMapName(entry.mapID), FormatNumber(entry.kills), percent
    ))
  end
end

function XPTooltip:PrintLevels()
  local db = self.char
  if not db then
    return
  end
  local total = tonumber(db.totals and db.totals.kills) or 0
  local list = {}
  for levelKey, kills in pairs(db.levels or {}) do
    if (tonumber(kills) or 0) > 0 then
      list[#list + 1] = { level = tonumber(levelKey) or 0, kills = tonumber(kills) or 0 }
    end
  end
  table.sort(list, function(a, b) return a.level < b.level end)
  if #list == 0 then
    AceM2L2:SafePrint("Kill History: no level data yet.")
    return
  end
  AceM2L2:SafePrint("Kills by player level:")
  for _, entry in ipairs(list) do
    local percent = total > 0 and (entry.kills / total * 100) or 0
    AceM2L2:SafePrint(string.format("  Level %-3d %8s  (%.1f%%)", entry.level, FormatNumber(entry.kills), percent))
  end
end

function XPTooltip:PrintSession()
  local db = self.char
  if not db or not db.session then
    return
  end
  AceM2L2:SafePrint("Kill History session:")
  AceM2L2:SafePrint("  Kills: " .. FormatNumber(db.session.kills or 0))
  AceM2L2:SafePrint("  XP: " .. FormatNumber(db.session.xp or 0))
  AceM2L2:SafePrint("  Started: " .. FormatAgo(db.session.startedAt or 0))
end

function XPTooltip:PrintStats()
  self:PrintStatus()
  local db = self.char
  if not db then
    return
  end

  local mobCount = 0
  for _, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      mobCount = mobCount + 1
    end
  end

  local areaCount = 0
  for _, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > 0 then
      areaCount = areaCount + 1
    end
  end

  local levelCount = 0
  for _, kills in pairs(db.levels or {}) do
    if (tonumber(kills) or 0) > 0 then
      levelCount = levelCount + 1
    end
  end

  AceM2L2:SafePrint("  Totals: kills=" .. FormatNumber(db.totals.kills or 0)
    .. ", xp=" .. FormatNumber(db.totals.xp or 0)
    .. ", uniqueMobs=" .. FormatNumber(db.totals.uniqueMobs or 0))
  AceM2L2:SafePrint("  DB: mobs=" .. FormatNumber(mobCount)
    .. ", areas=" .. FormatNumber(areaCount)
    .. ", levels=" .. FormatNumber(levelCount)
    .. ", sessionKills=" .. FormatNumber(db.session.kills or 0))

  local topMap, topMapKills = nil, 0
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > topMapKills then
      topMapKills = tonumber(kills) or 0
      topMap = mapKey
    end
  end
  if topMap then
    AceM2L2:SafePrint("  Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topMapKills) .. ")")
  end
end

function XPTooltip:PrintDump()
  local db = self.char
  if not db then
    return
  end
  local list = {}
  for mobKey, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      list[#list + 1] = { key = mobKey, mob = mob }
    end
  end
  table.sort(list, function(a, b)
    return (tonumber(a.mob.kills) or 0) > (tonumber(b.mob.kills) or 0)
  end)
  AceM2L2:SafePrint("Kill History dump (" .. tostring(#list) .. " mobs):")
  for index = 1, min(#list, 50) do
    local entry = list[index]
    local mob = entry.mob
    local contextCount = 0
    if type(mob.contexts) == "table" then
      for _ in pairs(mob.contexts) do
        contextCount = contextCount + 1
      end
    end
    AceM2L2:SafePrint(string.format(
      "  %s | %s | kills=%s | npc=%s | contexts=%d | last=%s",
      tostring(entry.key),
      tostring(mob.name or "Unknown"),
      FormatNumber(mob.kills or 0),
      tostring(mob.npcID or "?"),
      contextCount,
      FormatAgo(mob.lastSeen)
    ))
  end
end

function XPTooltip:PrintTable()
  local playerLevel = self:GetPlayerLevel()
  local xpMax = self:GetXPMax()
  local xpCurrent = self:GetXP()
  if not playerLevel or not xpMax or not xpCurrent then
    AceM2L2:SafePrint("Kill History: player XP state is unavailable.")
    return
  end
  local remaining = max(0, xpMax - xpCurrent)
  local pool = self:GetRestedPool()
  local mapID = self:GetMapID()
  local groupSize = self:GetGroupSize()

  AceM2L2:SafePrint(string.format(
    "Player level %d: %s / %s XP (%s remaining)",
    playerLevel, FormatNumber(xpCurrent), FormatNumber(xpMax), FormatNumber(remaining)
  ))
  AceM2L2:SafePrint("Mob level | XP per kill | kills to level")
  local maxLevel = self:GetMaxLevel()
  for mobLevel = max(1, playerLevel - 3), min(maxLevel, playerLevel + 4) do
    local estimate = self:GetEstimate(playerLevel, mobLevel, "normal", mapID, groupSize, "npc:table", "none")
    if estimate > 0 then
      local kills = self:KillsToLevel(remaining, estimate, pool)
      AceM2L2:SafePrint(string.format(
        "  %-8d | ~%-11s | ~%s", mobLevel, FormatNumber(estimate), FormatNumber(kills)
      ))
    else
      AceM2L2:SafePrint(string.format("  %-8d | no XP       | -", mobLevel))
    end
  end
end

function XPTooltip:ResetObservations()
  local db = self.char
  if not db then
    return
  end
  self.dataGeneration = (self.dataGeneration or 0) + 1
  self.pendingDeaths = {}
  self.recentChatKills = {}
  self.pendingChatXP = {}
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      mob.contexts = {}
      mob.xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 }
    end
  end
  db.calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} }
  db.calibrationVersion = CALIBRATION_VERSION
  AceM2L2:SafePrint("Kill History observations reset.")
  self:RefreshUI()
end

function XPTooltip:ResetCalibration()
  local db = self.char
  if not db then
    return
  end
  self.dataGeneration = (self.dataGeneration or 0) + 1
  self.pendingDeaths = {}
  self.recentChatKills = {}
  self.pendingChatXP = {}
  db.calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} }
  db.calibrationVersion = CALIBRATION_VERSION
  AceM2L2:SafePrint("Kill History calibration reset.")
  self:RefreshUI()
end

function XPTooltip:ResetKills()
  local db = self.char
  if not db then
    return
  end
  self.dataGeneration = (self.dataGeneration or 0) + 1
  self.pendingDeaths = {}
  self.recentChatKills = {}
  self.pendingChatXP = {}
  db.mobs = {}
  db.areas = {}
  db.levels = {}
  db.areaLevels = {}
  db.calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} }
  db.calibrationVersion = CALIBRATION_VERSION
  db.totals = { kills = 0, xp = 0, uniqueMobs = 0 }
  db.session = { startedAt = Epoch(), kills = 0, xp = 0 }
  AceM2L2:SafePrint("Kill History reset.")
  self:RefreshUI()
end

function XPTooltip:RemoveMobEntry(mobKey, deferRefresh)
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return nil
  end
  local mob = db.mobs[mobKey]
  if type(mob) ~= "table" then
    return nil
  end

  local name = tostring(mob.name or mobKey)
  local kills = tonumber(mob.kills) or 0
  local sessionKills = tonumber(mob.sessionKills) or 0
  local mobXP = type(mob.xp) == "table" and (tonumber(mob.xp.sumTotal) or 0) or 0

  db.totals = type(db.totals) == "table" and db.totals or {}
  db.session = type(db.session) == "table" and db.session or {}
  db.levels = EnsureNumberMap(db.levels)
  db.areas = EnsureNumberMap(db.areas)

  db.totals.kills = max(0, (tonumber(db.totals.kills) or 0) - kills)
  db.totals.xp = max(0, (tonumber(db.totals.xp) or 0) - mobXP)
  local totalSessionKills = tonumber(db.session.kills) or 0
  db.session.kills = max(0, totalSessionKills - min(sessionKills, totalSessionKills))
  if sessionKills >= kills and kills > 0 then
    db.session.xp = max(0, (tonumber(db.session.xp) or 0) - mobXP)
  end

  for levelKey, count in pairs(EnsureNumberMap(mob.killsAtLevel)) do
    db.levels[levelKey] = max(0, (tonumber(db.levels[levelKey]) or 0) - (tonumber(count) or 0))
  end
  for mapKey, count in pairs(EnsureNumberMap(mob.killsByMap)) do
    db.areas[mapKey] = max(0, (tonumber(db.areas[mapKey]) or 0) - (tonumber(count) or 0))
  end

  db.totals.uniqueMobs = max(0, (tonumber(db.totals.uniqueMobs) or 1) - 1)
  db.mobs[mobKey] = nil
  if type(db.calibration) == "table" and type(db.calibration.mobs) == "table" then
    db.calibration.mobs[mobKey] = nil
  end

  if not deferRefresh then
    self:RefreshAfterMobDelete()
  end
  return name, kills
end

function XPTooltip:DeleteMobEntry(mobKey)
  local name, kills = self:RemoveMobEntry(mobKey)
  if not name then
    AceM2L2:SafePrint("Kill History: that entry no longer exists.")
    return false
  end
  AceM2L2:SafePrint(string.format(
    "Kill History: removed %s (%s kills).", name, FormatNumber(kills or 0)
  ))
  return true
end

function XPTooltip:DeleteMobByName(name, confirm)
  local target = Trim(name)
  if not target or target == "" then
    AceM2L2:SafePrint("Usage: /acem2l2 xpt delete <mob name>")
    return
  end
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return
  end

  local lower = Lower(target)
  local matches = {}
  for mobKey, mob in pairs(db.mobs) do
    if type(mob) == "table" and Lower(mob.name) == lower then
      matches[#matches + 1] = {
        key = mobKey,
        name = tostring(mob.name or mobKey),
        kills = tonumber(mob.kills) or 0,
      }
    end
  end

  if #matches == 0 then
    AceM2L2:SafePrint("Kill History: no entry named " .. target .. ".")
    return
  end

  if not confirm then
    if #matches == 1 then
      AceM2L2:SafePrint(string.format(
        "Kill History: %s has %s kills. Use /acem2l2 xpt delete confirm %s to remove it.",
        matches[1].name, FormatNumber(matches[1].kills), matches[1].name
      ))
    else
      AceM2L2:SafePrint(string.format(
        "Kill History: %d entries are named %s. Use /acem2l2 xpt delete confirm %s to remove all of them.",
        #matches, target, target
      ))
    end
    return
  end

  local removed, kills = 0, 0
  for _, match in ipairs(matches) do
    local removedName, removedKills = self:RemoveMobEntry(match.key, true)
    if removedName then
      removed = removed + 1
      kills = kills + (removedKills or 0)
    end
  end
  if removed > 0 then
    self:RefreshAfterMobDelete()
  end
  AceM2L2:SafePrint(string.format(
    "Kill History: removed %d entr%s named %s (%s kills).",
    removed, removed == 1 and "y" or "ies", target, FormatNumber(kills)
  ))
end

function XPTooltip:DeleteUnknownEntries()
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return
  end
  local keys = {}
  for mobKey, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      local name = Lower(mob.name)
      if not name or name == "" or name == "unknown" then
        keys[#keys + 1] = mobKey
      end
    end
  end
  if #keys == 0 then
    AceM2L2:SafePrint("Kill History: no Unknown entries to remove.")
    return
  end

  local removed, kills = 0, 0
  for _, mobKey in ipairs(keys) do
    local removedName, removedKills = self:RemoveMobEntry(mobKey, true)
    if removedName then
      removed = removed + 1
      kills = kills + (removedKills or 0)
    end
  end
  if removed > 0 then
    self:RefreshAfterMobDelete()
  end
  AceM2L2:SafePrint(string.format(
    "Kill History: removed %d Unknown entr%s (%s kills).",
    removed, removed == 1 and "y" or "ies", FormatNumber(kills)
  ))
end

function XPTooltip:RefreshAfterMobDelete()
  self.pendingDeleteKey = nil
  self.pendingDeleteAt = nil
  if not self.ui then
    return
  end
  self:BuildList()
  if #self.currentList > 0 then
    self.selectedIndex = max(1, min(self.selectedIndex or 1, #self.currentList))
  else
    self.selectedIndex = 0
  end
  self:UpdateRows()
  self:UpdateDetail()
  self:RefreshOverview()
  self:UpdateFooter()
  self:UpdateStatusChip()
end

function XPTooltip:RequestDeleteSelected()
  local selected = self:GetSelected()
  if not selected or selected.kind ~= "mob" then
    return
  end
  local now = Now()
  if self.pendingDeleteKey == selected.key
    and (now - (self.pendingDeleteAt or 0)) <= 5 then
    self:DeleteMobEntry(selected.key)
    return
  end
  self.pendingDeleteKey = selected.key
  self.pendingDeleteAt = now
  self:UpdateDeleteButton(selected)
  AceM2L2:SafePrint("Kill History: click Remove again within 5 seconds to delete this entry.")
end

function XPTooltip:UpdateDeleteButton(selected)
  local button = self.ui and self.ui.deleteButton
  if not button then
    return
  end
  local isMob = selected and selected.kind == "mob"
  button:SetShown(isMob and true or false)
  if isMob then
    local confirm = self.pendingDeleteKey == selected.key
      and (Now() - (self.pendingDeleteAt or 0)) <= 5
    button:SetText(confirm and "Confirm" or "Remove")
  end
end

function XPTooltip:PrintHelp()
  AceM2L2:SafePrint("Kill History commands:")
  AceM2L2:SafePrint("/acem2l2 xpt on|off")
  AceM2L2:SafePrint("/acem2l2 xpt status")
  AceM2L2:SafePrint("/acem2l2 xpt ui")
  AceM2L2:SafePrint("/acem2l2 xpt kills [name]")
  AceM2L2:SafePrint("/acem2l2 xpt areas")
  AceM2L2:SafePrint("/acem2l2 xpt levels")
  AceM2L2:SafePrint("/acem2l2 xpt session")
  AceM2L2:SafePrint("/acem2l2 xpt stats")
  AceM2L2:SafePrint("/acem2l2 xpt dump")
  AceM2L2:SafePrint("/acem2l2 xpt table")
  AceM2L2:SafePrint("/acem2l2 xpt theme aether|dark|midnight|class|contrast")
  AceM2L2:SafePrint("/acem2l2 xpt scale 80-120")
  AceM2L2:SafePrint("/acem2l2 xpt starttab overview|mobs|areas|levels")
  AceM2L2:SafePrint("/acem2l2 xpt minimap on|off|reset|status")
  AceM2L2:SafePrint("/acem2l2 xpt recalibrate confirm")
  AceM2L2:SafePrint("/acem2l2 xpt delete <mob name>")
  AceM2L2:SafePrint("/acem2l2 xpt delete confirm <mob name>")
  AceM2L2:SafePrint("/acem2l2 xpt deleteunknown confirm")
  AceM2L2:SafePrint("/acem2l2 xpt reset|resetkills confirm")
  AceM2L2:SafePrint("/acem2l2 xpt config")
end

function XPTooltip:HandleCommand(input)
  local arg = input or ""
  local command, rest = arg:match("^(%S*)%s*(.-)$")
  command = Lower(command) or ""
  rest = rest or ""

  if command == "" or command == "help" then
    self:PrintHelp()
  elseif command == "on" then
    self:SetUserEnabled(true)
    AceM2L2:SafePrint("Kill History enabled.")
  elseif command == "off" then
    self:SetUserEnabled(false)
    AceM2L2:SafePrint("Kill History disabled.")
  elseif command == "status" then
    self:PrintStatus()
  elseif command == "ui" then
    self:OpenUI()
  elseif command == "kills" then
    self:PrintKills(rest)
  elseif command == "areas" then
    self:PrintAreas()
  elseif command == "levels" then
    self:PrintLevels()
  elseif command == "session" then
    self:PrintSession()
  elseif command == "stats" then
    self:PrintStats()
  elseif command == "dump" then
    self:PrintDump()
  elseif command == "table" then
    self:PrintTable()
  elseif command == "theme" then
    local theme = Lower(rest) or ""
    if THEMES[theme] then
      local settings = self:GetSettings()
      settings.theme = theme
      self:ApplyTheme()
      AceM2L2:SafePrint("Kill History theme: " .. theme)
    else
      AceM2L2:SafePrint("Themes: aether, dark, midnight, class, contrast")
    end
  elseif command == "scale" then
    local value = tonumber(rest)
    if value and value > 2 then
      value = value / 100
    end
    if value and value >= 0.8 and value <= 1.2 then
      local settings = self:GetSettings()
      settings.scale = value
      if self.ui and self.ui.SetScale then
        self.ui:SetScale(value)
      end
      AceM2L2:SafePrint(string.format("Kill History scale: %.2f", value))
    else
      AceM2L2:SafePrint("Usage: /acem2l2 xpt scale 80-120")
    end
  elseif command == "starttab" then
    local tab = Lower(rest) or ""
    if tab == "overview" or tab == "mobs" or tab == "areas" or tab == "levels" then
      local settings = self:GetSettings()
      settings.startTab = tab
      if self.ui and self.ui:IsShown() then
        self:SetTab(tab)
      end
      AceM2L2:SafePrint("Kill History start tab: " .. tab)
    else
      AceM2L2:SafePrint("Start tabs: overview, mobs, areas, levels")
    end
  elseif command == "minimap" then
    local action = Lower(rest) or ""
    local settings = self:GetSettings()
    if type(settings.minimap) ~= "table" then
      settings.minimap = CopyTable(DEFAULT_MINIMAP)
    end
    if action == "off" then
      settings.minimap.hide = true
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill History minimap icon hidden.")
    elseif action == "on" then
      settings.minimap.hide = false
      self:InitializeMinimap()
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill History minimap icon shown.")
    elseif action == "reset" then
      settings.minimap.minimapPos = 200
      if self.minimapIcon and self.minimapIcon.Refresh then
        pcall(self.minimapIcon.Refresh, self.minimapIcon, "AceM2L2", settings.minimap)
      else
        self.minimapRegistered = false
        self:InitializeMinimap()
      end
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill History minimap position reset.")
    elseif action == "status" or action == "" then
      self:PrintMinimapStatus()
    else
      AceM2L2:SafePrint("Usage: /acem2l2 xpt minimap on|off|reset|status")
    end
  elseif command == "config" then
    AceM2L2:HandleSlashCommand("config")
  elseif command == "recalibrate" then
    if Lower(rest) == "confirm" then
      self:ResetCalibration()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt recalibrate confirm to clear learned ratios.")
    end
  elseif command == "reset" then
    if Lower(rest) == "confirm" then
      self:ResetObservations()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt reset confirm to clear observations.")
    end
  elseif command == "resetkills" then
    if Lower(rest) == "confirm" then
      self:ResetKills()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt resetkills confirm to clear kill history.")
    end
  elseif command == "delete" then
    local target = Trim(rest)
    if not target or target == "" then
      AceM2L2:SafePrint("Usage: /acem2l2 xpt delete <mob name>")
      AceM2L2:SafePrint("Then: /acem2l2 xpt delete confirm <mob name>")
      return
    end
    local confirmName = target:match("^[Cc][Oo][Nn][Ff][Ii][Rr][Mm]%s+(.+)$")
    if confirmName then
      self:DeleteMobByName(confirmName, true)
    else
      self:DeleteMobByName(target, false)
    end
  elseif command == "deleteunknown" or command == "resetunknown" then
    if Lower(rest) == "confirm" then
      self:DeleteUnknownEntries()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt deleteunknown confirm to remove all Unknown entries.")
    end
  else
    self:PrintHelp()
  end
end

--[[--------------------------------------------------------------------------------
  UI
------------------------------------------------------------------------------------]]

local function CreateBackdropFrame(parent, name)
  local frameName = name
  if frameName and _G[frameName] then
    frameName = nil
  end
  local ok, frame = pcall(CreateFrame, "Frame", frameName, parent, "BackdropTemplate")
  if not ok then
    frame = CreateFrame("Frame", nil, parent)
  end
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  end
  return frame
end

local function CreateTextButton(parent, text, width, height)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width or 100, height or 24)
  button:EnableMouse(true)

  local border = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  border:SetAllPoints()
  button.border = border

  local bg = button:CreateTexture(nil, "BACKGROUND", nil, 2)
  bg:SetPoint("TOPLEFT", 1, -1)
  bg:SetPoint("BOTTOMRIGHT", -1, 1)
  button.bg = bg

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("CENTER", 0, 0)
  label:SetJustifyH("CENTER")
  button.label = label

  button.hover = false
  button.selected = false

  function button:ApplyStyle()
    local theme = XPTooltip:GetTheme()
    local fill = theme.elevated
    local edge = theme.border
    local textColor = theme.muted
    if self.selected then
      fill = { theme.accent[1], theme.accent[2], theme.accent[3], 0.34 }
      edge = theme.accent
      textColor = theme.text
    elseif self.hover then
      fill = { theme.accent[1], theme.accent[2], theme.accent[3], 0.18 }
      edge = theme.border
      textColor = theme.text
    end
    self.bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
    self.border:SetColorTexture(edge[1], edge[2], edge[3], edge[4] or 1)
    self.label:SetTextColor(textColor[1], textColor[2], textColor[3])
  end

  function button:SetText(value)
    self.label:SetText(value or "")
  end

  function button:SetButtonState(state, active)
    if active ~= nil then
      self.selected = active and true or false
    else
      self.selected = state == "PUSHED"
    end
    self:ApplyStyle()
  end

  function button:SetSelected(value)
    self.selected = value and true or false
    self:ApplyStyle()
  end

  button:SetScript("OnEnter", function(self)
    self.hover = true
    self:ApplyStyle()
  end)
  button:SetScript("OnLeave", function(self)
    self.hover = false
    self:ApplyStyle()
  end)

  button:SetText(text or "")
  button:ApplyStyle()
  return button
end

local function SetGradientTexture(texture, orientation, topColor, bottomColor)
  if texture.SetGradient and CreateColor then
    local ok = pcall(texture.SetGradient, texture, orientation,
      CreateColor(topColor[1], topColor[2], topColor[3], topColor[4] or 1),
      CreateColor(bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1))
    if ok then
      return
    end
  end
  texture:SetColorTexture(topColor[1], topColor[2], topColor[3], topColor[4] or 1)
end

function XPTooltip:CreateAmbient(frame)
  local theme = self:GetTheme()

  local canvas = frame:CreateTexture(nil, "BACKGROUND", nil, 5)
  canvas:SetAllPoints()
  canvas:SetTexture("Interface\\Buttons\\WHITE8X8")
  SetGradientTexture(canvas, "VERTICAL",
    { theme.canvas[1], theme.canvas[2], theme.canvas[3], 1 },
    { 0.008, 0.020, 0.040, 1 })
  frame.ambientCanvas = canvas

  local top = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(80)
  SetGradientTexture(top, "VERTICAL", { 0, 0, 0, 0.55 }, { 0, 0, 0, 0 })
  frame.ambientTop = top

  local bottom = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(80)
  SetGradientTexture(bottom, "VERTICAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.65 })
  frame.ambientBottom = bottom

  local left = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMLEFT")
  left:SetWidth(60)
  SetGradientTexture(left, "HORIZONTAL", { 0, 0, 0, 0.45 }, { 0, 0, 0, 0 })
  frame.ambientLeft = left

  local right = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  right:SetPoint("TOPRIGHT")
  right:SetPoint("BOTTOMRIGHT")
  right:SetWidth(60)
  SetGradientTexture(right, "HORIZONTAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.45 })
  frame.ambientRight = right
end
function XPTooltip:UpdateAmbient()
  if not self.ui then
    return
  end
  local theme = self:GetTheme()
  if self.ui.ambientCanvas then
    SetGradientTexture(self.ui.ambientCanvas, "VERTICAL",
      { theme.canvas[1], theme.canvas[2], theme.canvas[3], 1 },
      { 0.008, 0.020, 0.040, 1 })
  end
end

function XPTooltip:UpdateStatusChip()
  if not self.ui or not self.ui.statusText then
    return
  end
  local theme = self:GetTheme()
  local text = self:GetStatusText()
  local color = theme.muted
  if self:IsActive() then
    color = theme.success or theme.accent
  elseif self.autoDisabled then
    color = theme.danger or theme.warning or theme.accent
  end
  self.ui.statusText:SetText(text:upper())
  self.ui.statusText:SetTextColor(color[1], color[2], color[3])
end

function XPTooltip:CreateUI()
  if self.ui then
    return self.ui
  end

  local settings = self.settings or self:GetSettings()
  local uiSettings = settings and settings.ui or DEFAULT_UI
  local frame = CreateBackdropFrame(UIParent, "AceM2L2XPTooltipFrame")
  frame:SetSize(uiSettings.width or 1000, uiSettings.height or 680)
  frame.panels = {}
  if frame.SetScale then
    frame:SetScale((settings and settings.scale) or 1.0)
  end
  frame:SetPoint(
    uiSettings.point or "CENTER", UIParent, uiSettings.relativePoint or "CENTER",
    uiSettings.x or 0, uiSettings.y or 0
  )
  self:StylePanel(frame, "canvas")
  frame.panels[#frame.panels + 1] = frame
  frame.xpTooltipKind = "canvas"
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    self:SaveUIPosition()
  end)
  frame:SetScript("OnHide", function()
    self.modelDragging = false
    if self.ui and self.ui.model then
      self.ui.model.dragging = false
    end
  end)
  frame:SetScript("OnShow", function()
    self:SafeRefreshUI()
  end)

  self:CreateAmbient(frame)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText("ACE MOBS 2 LEVEL 2")
  frame.title = title

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  subtitle:SetText("KILL HISTORY")
  frame.subtitle = subtitle

  local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusText:SetPoint("TOPRIGHT", -200, -16)
  statusText:SetJustifyH("RIGHT")
  statusText:SetText("ACTIVE")
  frame.statusText = statusText

  local settingsButton = CreateTextButton(frame, "Settings", 80, 24)
  settingsButton:SetPoint("TOPRIGHT", -108, -10)
  settingsButton:SetScript("OnClick", function()
    AceM2L2:HandleSlashCommand("config")
  end)
  frame.settingsButton = settingsButton

  local closeButton = CreateTextButton(frame, "X", 24, 24)
  closeButton:SetPoint("TOPRIGHT", -6, -10)
  closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)
  frame.closeButton = closeButton

  if type(UISpecialFrames) == "table" and frame:GetName() then
    local found = false
    for _, name in ipairs(UISpecialFrames) do
      if name == frame:GetName() then
        found = true
        break
      end
    end
    if not found then
      UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
    end
  end

  local tabBar = CreateFrame("Frame", nil, frame)
  tabBar:SetPoint("TOPLEFT", 16, -54)
  tabBar:SetPoint("TOPRIGHT", -16, -54)
  tabBar:SetHeight(26)

  self.tabs = {}
  local tabDefinitions = {
    { key = "overview", label = "Overview" },
    { key = "mobs", label = "Mobs" },
    { key = "areas", label = "Areas" },
    { key = "levels", label = "Levels" },
  }
  local x = 0
  for _, definition in ipairs(tabDefinitions) do
    local button = CreateTextButton(tabBar, definition.label, 100, 26)
    button:SetPoint("TOPLEFT", x, 0)
    button:SetScript("OnClick", function()
      pcall(self.SetTab, self, definition.key)
    end)
    self.tabs[definition.key] = button
    x = x + 108
  end

  local sortButton = CreateTextButton(tabBar, "Sort: Kills", 120, 26)
  sortButton:SetPoint("TOPRIGHT", 0, 0)
  sortButton:SetScript("OnClick", function()
    pcall(self.CycleSort, self)
  end)
  frame.sortButton = sortButton

  local searchLabel = tabBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("RIGHT", sortButton, "LEFT", -158, 0)
  searchLabel:SetText("Search:")
  frame.searchLabel = searchLabel

  local theme = self:GetTheme()
  local searchBox = CreateFrame("EditBox", nil, tabBar)
  searchBox:SetSize(150, 26)
  searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 4, 0)
  searchBox:SetTextInsets(8, 8, 0, 0)
  searchBox:SetFontObject(GameFontHighlightSmall)
  if searchBox.SetTextColor then
    pcall(searchBox.SetTextColor, searchBox, theme.text[1], theme.text[2], theme.text[3])
  end
  searchBox:SetAutoFocus(false)
  searchBox:SetMaxLetters(40)
  searchBox:SetText("")

  local searchBorder = searchBox:CreateTexture(nil, "BACKGROUND", nil, 1)
  searchBorder:SetAllPoints()
  searchBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 1)
  local searchBg = searchBox:CreateTexture(nil, "BACKGROUND", nil, 2)
  searchBg:SetPoint("TOPLEFT", 1, -1)
  searchBg:SetPoint("BOTTOMRIGHT", -1, 1)
  searchBg:SetColorTexture(theme.elevated[1], theme.elevated[2], theme.elevated[3], 1)

  local searchPlaceholder = tabBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
  searchPlaceholder:SetText("Search mobs")
  frame.searchPlaceholder = searchPlaceholder
  frame.searchBg = searchBg
  frame.searchBorder = searchBorder

  searchBox:SetScript("OnTextChanged", function(box)
    self.searchText = box:GetText() or ""
    if self.ui and self.ui.searchPlaceholder then
      if self.searchText == "" then
        self.ui.searchPlaceholder:Show()
      else
        self.ui.searchPlaceholder:Hide()
      end
    end
    if self.tab ~= "mobs" then
      return
    end
    pcall(self.BuildList, self)
    pcall(self.UpdateRows, self)
    pcall(self.UpdateDetail, self)
  end)
  searchBox:SetScript("OnEscapePressed", function(box)
    box:ClearFocus()
  end)
  searchBox:SetScript("OnEnterPressed", function(box)
    box:ClearFocus()
  end)
  frame.searchBox = searchBox

  local detailPanel = CreateBackdropFrame(frame)
  detailPanel:SetPoint("TOPLEFT", 16, -90)
  detailPanel:SetPoint("BOTTOMLEFT", 16, 40)
  detailPanel:SetWidth(300)
  self:StylePanel(detailPanel, "panel")
  detailPanel.xpTooltipKind = "panel"
  frame.panels[#frame.panels + 1] = detailPanel
  frame.detailPanel = detailPanel

  local listPanel = CreateBackdropFrame(frame)
  listPanel:SetPoint("TOPLEFT", detailPanel, "TOPRIGHT", 12, 0)
  listPanel:SetPoint("BOTTOMRIGHT", -16, 40)
  self:StylePanel(listPanel, "panel")
  listPanel.xpTooltipKind = "panel"
  frame.panels[#frame.panels + 1] = listPanel
  frame.listPanel = listPanel

  local filterBar = CreateFrame("Frame", nil, listPanel)
  filterBar:SetPoint("TOPLEFT", 6, -6)
  filterBar:SetPoint("TOPRIGHT", -6, -6)
  filterBar:SetHeight(24)
  frame.filterBar = filterBar
  frame.filterButtons = {}
  self.filter = "all"
  local filterDefinitions = {
    { key = "all", label = "All" },
    { key = "level", label = "Level" },
    { key = "session", label = "Session" },
    { key = "elite", label = "Elite" },
  }
  local filterX = 0
  for _, definition in ipairs(filterDefinitions) do
    local button = CreateTextButton(filterBar, definition.label, 70, 22)
    button:SetPoint("TOPLEFT", filterX, 0)
    button:SetScript("OnClick", function()
      pcall(self.SetFilter, self, definition.key)
    end)
    frame.filterButtons[definition.key] = button
    filterX = filterX + 78
  end

  local listWidth = max(260, (frame:GetWidth() or 1000) - 16 - 300 - 12 - 16)
  local rowWidth = max(240, listWidth - 40)
  frame.rowWidth = rowWidth
  local scrollOK, scrollFrame = pcall(CreateFrame, "ScrollFrame", "AceM2L2XPTooltipScroll", listPanel, "UIPanelScrollFrameTemplate")
  if not scrollOK then
    scrollFrame = CreateFrame("ScrollFrame", nil, listPanel)
  end
  scrollFrame:SetPoint("TOPLEFT", 6, -34)
  scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(rowWidth, 1)
  scrollFrame:SetScrollChild(scrollChild)
  scrollFrame:SetScript("OnVerticalScroll", function()
    self:UpdateRows()
  end)
  frame.scrollFrame = scrollFrame
  frame.scrollChild = scrollChild

  self.rows = {}
  for index = 1, VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetSize(rowWidth, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0.04)
    row.background = background

    local crest = row:CreateTexture(nil, "ARTWORK")
    crest:SetSize(18, 18)
    crest:SetPoint("LEFT", 8, 0)
    crest:SetColorTexture(0.85, 0.66, 0.31, 0.55)
    row.crest = crest

    local crestText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    crestText:SetPoint("CENTER", crest, "CENTER", 0, 0)
    crestText:SetJustifyH("CENTER")
    crestText:SetText("?")
    row.crestText = crestText

    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("BOTTOMLEFT", 4, 2)
    bar:SetHeight(2)
    bar:SetColorTexture(0.2, 0.6, 1, 0.45)
    bar:Hide()
    row.bar = bar

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 32, 0)
    text:SetWidth(max(110, rowWidth - 250))
    text:SetJustifyH("LEFT")
    row.text = text

    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", -8, 0)
    value:SetWidth(200)
    value:SetJustifyH("RIGHT")
    row.value = value

    row:SetScript("OnClick", function(clicked)
      pcall(self.SelectIndex, self, clicked.index)
    end)
    row:SetScript("OnEnter", function(entered)
      local theme = self:GetTheme()
      entered.background:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.16)
    end)
    row:SetScript("OnLeave", function(left)
      local theme = self:GetTheme()
      if left.index == self.selectedIndex then
        left.background:SetColorTexture(theme.accentSoft[1], theme.accentSoft[2], theme.accentSoft[3], theme.accentSoft[4])
      else
        left.background:SetColorTexture(1, 1, 1, 0.04)
      end
    end)

    self.rows[index] = row
  end

  local modelHolder = CreateBackdropFrame(detailPanel)
  modelHolder:SetPoint("TOPLEFT", 8, -8)
  modelHolder:SetPoint("TOPRIGHT", -8, -8)
  modelHolder:SetHeight(230)
  self:StylePanel(modelHolder, "elevated")
  modelHolder.xpTooltipKind = "elevated"
  frame.panels[#frame.panels + 1] = modelHolder
  frame.modelHolder = modelHolder

  local modelGlow = modelHolder:CreateTexture(nil, "BACKGROUND", nil, 1)
  modelGlow:SetPoint("TOPLEFT", 8, -8)
  modelGlow:SetPoint("BOTTOMRIGHT", -8, 8)
  local theme = self:GetTheme()
  modelGlow:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.10)
  modelHolder.glow = modelGlow

  local modelOK, model = pcall(CreateFrame, "PlayerModel", nil, modelHolder)
  if not modelOK then
    model = CreateFrame("Frame", nil, modelHolder)
  end
  model:SetPoint("TOPLEFT", 6, -6)
  model:SetPoint("BOTTOMRIGHT", -6, 6)
  model:EnableMouse(true)
  model:SetScript("OnMouseDown", function(clicked, button)
    if button == "LeftButton" then
      clicked.dragging = true
      clicked.dragStartX = select(1, GetCursorPosition())
      clicked.dragStartYaw = self.modelYaw or 0
    end
  end)
  model:SetScript("OnMouseUp", function(clicked)
    clicked.dragging = false
  end)
  model:SetScript("OnUpdate", function(clicked)
    if clicked.dragging then
      local x = select(1, GetCursorPosition())
      self.modelYaw = (clicked.dragStartYaw or 0) + (x - (clicked.dragStartX or x)) * 0.01
      pcall(clicked.SetRotation, clicked, self.modelYaw)
    end
  end)
  frame.model = model

  local fallbackIcon = modelHolder:CreateTexture(nil, "ARTWORK")
  fallbackIcon:SetSize(64, 64)
  fallbackIcon:SetPoint("CENTER", 0, 24)
  fallbackIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  fallbackIcon:Hide()
  frame.modelFallbackIcon = fallbackIcon

  local fallback = modelHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fallback:SetPoint("CENTER", 0, -24)
  fallback:SetText("")
  frame.modelFallback = fallback

  local heroName = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  heroName:SetPoint("TOPLEFT", 12, -240)
  heroName:SetPoint("TOPRIGHT", -12, -240)
  heroName:SetJustifyH("LEFT")
  heroName:SetText("")
  frame.heroName = heroName

  local heroSub = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  heroSub:SetPoint("TOPLEFT", heroName, "BOTTOMLEFT", 0, -2)
  heroSub:SetPoint("TOPRIGHT", -12, -260)
  heroSub:SetJustifyH("LEFT")
  heroSub:SetText("")
  frame.heroSub = heroSub

  local details = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  details:SetPoint("TOPLEFT", 12, -282)
  details:SetPoint("BOTTOMRIGHT", -12, 38)
  details:SetJustifyH("LEFT")
  details:SetJustifyV("TOP")
  details:SetWordWrap(true)
  details:SetText("")
  frame.details = details

  local deleteButton = CreateTextButton(detailPanel, "Remove", 96, 22)
  deleteButton:SetPoint("BOTTOMRIGHT", -8, 8)
  deleteButton:Hide()
  deleteButton:SetScript("OnClick", function()
    pcall(self.RequestDeleteSelected, self)
  end)
  frame.deleteButton = deleteButton

  self:CreateOverviewPanel(frame)

  local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  footer:SetPoint("BOTTOMLEFT", 16, 16)
  footer:SetPoint("BOTTOMRIGHT", -16, 16)
  footer:SetJustifyH("LEFT")
  footer:SetText("")
  frame.footer = footer

  self.ui = frame
  self:ApplyTheme()
  self:SetTab((settings and settings.startTab) or "overview")
  self:UpdateFooter()
  return frame
end

function XPTooltip:CreateOverviewPanel(frame)
  local panel = CreateBackdropFrame(frame)
  panel:SetPoint("TOPLEFT", 16, -90)
  panel:SetPoint("BOTTOMRIGHT", -16, 40)
  self:StylePanel(panel, "panel")
  panel.xpTooltipKind = "panel"
  frame.panels[#frame.panels + 1] = panel
  panel:Hide()

  local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 12, -10)
  header:SetText("Overview")

  local cards = {}
  local labels = {}
  local values = {}
  local accents = {}
  labels[#labels + 1] = header
  local contentWidth = (frame:GetWidth() or 1000) - 32
  local availableWidth = contentWidth - 24
  local cardGap = 8
  local cardWidth = floor((availableWidth - cardGap * 3) / 4)
  for index = 1, 4 do
    local card = CreateBackdropFrame(panel)
    card:SetSize(cardWidth, 78)
    card:SetPoint("TOPLEFT", 12 + (index - 1) * (cardWidth + cardGap), -42)
    self:StylePanel(card, "elevated")
    card.xpTooltipKind = "elevated"
    frame.panels[#frame.panels + 1] = card

    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 8, -1)
    accent:SetPoint("TOPRIGHT", -8, -1)
    accent:SetHeight(2)
    local theme = self:GetTheme()
    accent:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)
    card.accent = accent
    accents[#accents + 1] = accent

    local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetText("")
    labels[#labels + 1] = label

    local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    value:SetPoint("TOPLEFT", 10, -30)
    value:SetWidth(cardWidth - 20)
    value:SetWordWrap(true)
    value:SetText("0")
    values[#values + 1] = value

    cards[index] = { card = card, label = label, value = value }
  end

  local topPanel = CreateBackdropFrame(panel)
  topPanel:SetPoint("TOPLEFT", 12, -132)
  topPanel:SetSize(floor(availableWidth * 0.52), 180)
  self:StylePanel(topPanel, "elevated")
  topPanel.xpTooltipKind = "elevated"
  frame.panels[#frame.panels + 1] = topPanel

  local topTitle = topPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  topTitle:SetPoint("TOPLEFT", 10, -8)
  topTitle:SetText("Most killed")
  labels[#labels + 1] = topTitle

  local topMobsText = topPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  topMobsText:SetPoint("TOPLEFT", 10, -30)
  topMobsText:SetPoint("BOTTOMRIGHT", -10, 8)
  topMobsText:SetJustifyH("LEFT")
  topMobsText:SetJustifyV("TOP")
  topMobsText:SetWordWrap(true)
  topMobsText:SetText("")

  local levelPanel = CreateBackdropFrame(panel)
  levelPanel:SetPoint("TOPLEFT", topPanel, "TOPRIGHT", 10, 0)
  levelPanel:SetPoint("BOTTOMRIGHT", -12, 12)
  self:StylePanel(levelPanel, "elevated")
  levelPanel.xpTooltipKind = "elevated"
  frame.panels[#frame.panels + 1] = levelPanel

  local levelTitle = levelPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  levelTitle:SetPoint("TOPLEFT", 10, -8)
  levelTitle:SetText("Level range")
  labels[#labels + 1] = levelTitle

  local levelText = levelPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  levelText:SetPoint("TOPLEFT", 10, -30)
  levelText:SetPoint("BOTTOMRIGHT", -10, 10)
  levelText:SetJustifyH("LEFT")
  levelText:SetJustifyV("TOP")
  levelText:SetWordWrap(true)
  levelText:SetText("")

  frame.overview = {
    panel = panel,
    cards = cards,
    labels = labels,
    values = values,
    topMobsText = topMobsText,
    levelText = levelText,
    accents = accents,
  }
end

function XPTooltip:RefreshOverview()
  if not self.ui or not self.ui.overview then
    return
  end
  local db = self.char
  if not db then
    return
  end
  local overview = self.ui.overview
  local total = tonumber(db.totals.kills) or 0
  local session = tonumber(db.session.kills) or 0
  local unique = tonumber(db.totals.uniqueMobs) or 0

  local topMap, topMapKills = nil, 0
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > topMapKills then
      topMapKills = tonumber(kills) or 0
      topMap = mapKey
    end
  end

  overview.cards[1].label:SetText("Total kills")
  overview.cards[1].value:SetText(FormatNumber(total))
  overview.cards[2].label:SetText("This session")
  overview.cards[2].value:SetText(FormatNumber(session))
  overview.cards[3].label:SetText("Mobs tracked")
  overview.cards[3].value:SetText(FormatNumber(unique))
  overview.cards[4].label:SetText("Top area")
  overview.cards[4].value:SetText(topMap and self:GetMapName(topMap) or "None")

  local mobs = {}
  for mobKey, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" and (tonumber(mob.kills) or 0) > 0 then
      mobs[#mobs + 1] = { key = mobKey, mob = mob, kills = tonumber(mob.kills) or 0 }
    end
  end
  table.sort(mobs, function(a, b) return a.kills > b.kills end)
  local lines = {}
  for index = 1, min(#mobs, 8) do
    local entry = mobs[index]
    lines[#lines + 1] = string.format(
      "%d. %s  -  %s kills", index, tostring(entry.mob.name or "Unknown"), FormatNumber(entry.kills)
    )
  end
  if #lines == 0 then
    lines[1] = "No kills recorded yet.\nKill a mob on Forever to start the history."
  end
  overview.topMobsText:SetText(table.concat(lines, "\n"))

  local minLevel, maxLevel, topLevel, topLevelKills
  for levelKey, kills in pairs(db.levels or {}) do
    local level = tonumber(levelKey)
    local value = tonumber(kills) or 0
    if level and value > 0 then
      if not minLevel or level < minLevel then
        minLevel = level
      end
      if not maxLevel or level > maxLevel then
        maxLevel = level
      end
      if not topLevelKills or value > topLevelKills then
        topLevelKills = value
        topLevel = level
      end
    end
  end

  local levelLines = {}
  if minLevel then
    levelLines[#levelLines + 1] = "Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
    levelLines[#levelLines + 1] = "Most kills: level " .. tostring(topLevel) .. " (" .. FormatNumber(topLevelKills) .. ")"
  else
    levelLines[#levelLines + 1] = "No level data yet."
  end
  levelLines[#levelLines + 1] = ""
  levelLines[#levelLines + 1] = "Use the tabs above to browse mobs, areas, and levels."
  overview.levelText:SetText(table.concat(levelLines, "\n"))
end

function XPTooltip:SetFilter(filter)
  if filter ~= "all" and filter ~= "level" and filter ~= "session" and filter ~= "elite" then
    return
  end
  self.filter = filter
  self.selectedIndex = 1
  self:UpdateFilterButtons()
  self:BuildList()
  self:UpdateRows()
  self:UpdateDetail()
end

function XPTooltip:UpdateFilterButtons()
  if not self.ui or not self.ui.filterButtons then
    return
  end
  for key, button in pairs(self.ui.filterButtons) do
    if button.SetButtonState then
      button:SetButtonState("PUSHED", key == self.filter)
    end
  end
end

function XPTooltip:SaveUIPosition()
  if not self.ui then
    return
  end
  local settings = self:GetSettings()
  if not settings or type(settings.ui) ~= "table" then
    return
  end
  local point, _, relativePoint, x, y = self.ui:GetPoint(1)
  if not point then
    return
  end
  settings.ui.point = point or "CENTER"
  settings.ui.relativePoint = relativePoint or "CENTER"
  settings.ui.x = floor((x or 0) + 0.5)
  settings.ui.y = floor((y or 0) + 0.5)
end

function XPTooltip:CycleSort()
  if self.tab ~= "mobs" then
    return
  end
  local settings = self:GetSettings()
  if not settings or type(settings.ui) ~= "table" then
    return
  end
  local order = { "kills", "name", "lastSeen" }
  local nextSort = "kills"
  for index, value in ipairs(order) do
    if settings.ui.sort == value then
      nextSort = order[(index % #order) + 1]
      break
    end
  end
  settings.ui.sort = nextSort
  if self.ui and self.ui.sortButton then
    self.ui.sortButton:SetText("Sort: " .. (nextSort == "lastSeen" and "Recent" or (nextSort == "name" and "Name" or "Kills")))
  end
  self:BuildList()
  self:UpdateRows()
  self:UpdateDetail()
end

function XPTooltip:SetTab(tab)
  if tab ~= "overview" and tab ~= "mobs" and tab ~= "areas" and tab ~= "levels" then
    tab = "overview"
  end
  self.tab = tab
  self.selectedIndex = 1
  self.filter = "all"
  if self.tab ~= "mobs" then
    self.searchText = ""
    if self.ui and self.ui.searchBox then
      self.ui.searchBox:SetText("")
    end
  end
  if self.ui and self.ui.scrollFrame then
    pcall(self.ui.scrollFrame.SetVerticalScroll, self.ui.scrollFrame, 0)
  end

  if self.ui and self.ui.overview then
    if self.tab == "overview" then
      self.ui.overview.panel:Show()
    else
      self.ui.overview.panel:Hide()
    end
  end
  if self.ui and self.ui.listPanel then
    if self.tab == "overview" then
      self.ui.listPanel:Hide()
    else
      self.ui.listPanel:Show()
    end
  end
  if self.ui and self.ui.detailPanel then
    if self.tab == "overview" then
      self.ui.detailPanel:Hide()
    else
      self.ui.detailPanel:Show()
    end
  end
  if self.ui and self.ui.filterBar then
    if self.tab == "mobs" then
      self.ui.filterBar:Show()
    else
      self.ui.filterBar:Hide()
    end
  end

  if self.tab == "overview" then
    self:RefreshOverview()
  else
    self:BuildList()
    self:UpdateRows()
    self:UpdateDetail()
  end
  self:UpdateFilterButtons()
  self:UpdateTabs()
  self:UpdateStatusChip()
  self:UpdateFooter()
end

function XPTooltip:UpdateTabs()
  if not self.tabs then
    return
  end
  for key, button in pairs(self.tabs) do
    if button.SetButtonState then
      button:SetButtonState("PUSHED", key == self.tab)
    end
  end
  if self.ui then
    local isMobs = self.tab == "mobs"
    if self.ui.sortButton and self.ui.sortButton.SetShown then
      self.ui.sortButton:SetShown(isMobs)
    end
    if self.ui.searchBox and self.ui.searchBox.SetShown then
      self.ui.searchBox:SetShown(isMobs)
    end
    if self.ui.searchLabel and self.ui.searchLabel.SetShown then
      self.ui.searchLabel:SetShown(isMobs)
    end
    if self.ui.searchPlaceholder then
      self.ui.searchPlaceholder:SetShown(isMobs and (self.searchText or "") == "")
    end
    if self.ui.filterBar and self.ui.filterBar.SetShown then
      self.ui.filterBar:SetShown(isMobs)
    end
  end
end

function XPTooltip:BuildList()
  local list = {}
  local settings = self:GetSettings()
  local sortMode = settings and settings.ui and settings.ui.sort or "kills"
  local db = self.char
  if not db then
    self.currentList = list
    return
  end

  if self.tab == "areas" then
    for mapKey, kills in pairs(db.areas or {}) do
      local value = tonumber(kills) or 0
      if value > 0 then
        list[#list + 1] = {
          kind = "area",
          key = mapKey,
          label = self:GetMapName(mapKey),
          value = FormatNumber(value) .. " kills",
          sortValue = value,
          kills = value,
        }
      end
    end
    table.sort(list, function(a, b) return a.sortValue > b.sortValue end)
    local totalKills = tonumber(db.totals.kills) or 0
    for _, item in ipairs(list) do
      item.bar = totalKills > 0 and (item.kills / totalKills) or 0
    end
  elseif self.tab == "levels" then
    for levelKey, kills in pairs(db.levels or {}) do
      local level = tonumber(levelKey) or 0
      local value = tonumber(kills) or 0
      if level > 0 and value > 0 then
        list[#list + 1] = {
          kind = "level",
          key = levelKey,
          label = "Level " .. tostring(level),
          value = FormatNumber(value) .. " kills",
          sortValue = level,
          kills = value,
        }
      end
    end
    table.sort(list, function(a, b) return a.sortValue < b.sortValue end)
    local maxKills = 0
    for _, item in ipairs(list) do
      if item.kills > maxKills then
        maxKills = item.kills
      end
    end
    for _, item in ipairs(list) do
      item.bar = maxKills > 0 and (item.kills / maxKills) or 0
    end
  else
    local search = Lower(self.searchText) or ""
    local playerLevel = self:GetPlayerLevel()
    for mobKey, mob in pairs(db.mobs or {}) do
      if type(mob) == "table" and (tonumber(mob.kills) or 0) > 0 then
        local name = Lower(mob.name) or ""
        local include = true
        if self.filter == "level" then
          include = playerLevel
            and type(mob.killsAtLevel) == "table"
            and (tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0) > 0
        elseif self.filter == "session" then
          include = (tonumber(mob.sessionKills) or 0) > 0
        elseif self.filter == "elite" then
          include = mob.classification == "elite"
            or mob.classification == "rareelite"
            or mob.classification == "worldboss"
        end
        if include and (search == "" or name:find(search, 1, true)) then
          local value = tonumber(mob.kills) or 0
          local rowValue = FormatNumber(value) .. " kills"
          if type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
            local avg = FormatNumber((tonumber(mob.xp.sumBase) or 0) / mob.xp.samples)
            rowValue = rowValue .. "  |  avg " .. avg .. " XP"
          end
          list[#list + 1] = {
            kind = "mob",
            key = mobKey,
            label = tostring(mob.name or "Unknown"),
            value = rowValue,
            sortKills = value,
            sortName = Lower(mob.name) or "",
            sortSeen = tonumber(mob.lastSeen) or 0,
            classification = mob.classification,
          }
        end
      end
    end
    local maxKills = 0
    for _, item in ipairs(list) do
      if item.sortKills > maxKills then
        maxKills = item.sortKills
      end
    end
    for _, item in ipairs(list) do
      item.bar = maxKills > 0 and (item.sortKills / maxKills) or 0
    end
    if sortMode == "name" then
      table.sort(list, function(a, b) return a.sortName < b.sortName end)
    elseif sortMode == "lastSeen" then
      table.sort(list, function(a, b) return a.sortSeen > b.sortSeen end)
    else
      table.sort(list, function(a, b)
        if a.sortKills == b.sortKills then
          return a.sortName < b.sortName
        end
        return a.sortKills > b.sortKills
      end)
    end
  end

  self.currentList = list
  if self.ui and self.ui.scrollChild then
    self.ui.scrollChild:SetSize(self.ui.rowWidth or 390, math.max(1, #list * ROW_HEIGHT))
    if self.ui.scrollFrame and self.ui.scrollFrame.UpdateScrollChildRect then
      pcall(self.ui.scrollFrame.UpdateScrollChildRect, self.ui.scrollFrame)
    end
  end
  if #list > 0 then
    self.selectedIndex = max(1, min(self.selectedIndex or 1, #list))
  else
    self.selectedIndex = 0
  end
  if self.ui and self.ui.sortButton then
    local label = sortMode == "lastSeen" and "Recent" or (sortMode == "name" and "Name" or "Kills")
    self.ui.sortButton:SetText("Sort: " .. label)
  end
end

function XPTooltip:UpdateRows()
  if not self.rows or not self.ui or not self.ui.scrollChild then
    return
  end
  local list = self.currentList or {}
  local offset = 0
  if self.ui and self.ui.scrollFrame then
    offset = SafeNumber(self.ui.scrollFrame:GetVerticalScroll()) or 0
  end
  local startIndex = floor(offset / ROW_HEIGHT) + 1
  local theme = self:GetTheme()
  local eliteColor = { 1.00, 0.82, 0.20 }
  local bossColor = { 0.90, 0.30, 0.30 }
  local rareColor = { 0.30, 0.65, 0.95 }

  for index = 1, #self.rows do
    local row = self.rows[index]
    local data = list[startIndex + index - 1]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.ui.scrollChild, "TOPLEFT", 0, -((startIndex + index - 2) * ROW_HEIGHT))
    if data then
      row.index = startIndex + index - 1
      row.text:SetText(data.label or "")
      row.value:SetText(data.value or "")
      local label = data.label or "?"
      if row.crestText then
        row.crestText:SetText(label:sub(1, 1):upper())
        if row.crestText.SetTextColor then
          row.crestText:SetTextColor(0.05, 0.05, 0.05)
        end
      end
      local crestColor = theme.accent
      if data.classification == "elite" or data.classification == "rareelite" then
        crestColor = eliteColor
      elseif data.classification == "worldboss" then
        crestColor = bossColor
      elseif data.classification == "rare" then
        crestColor = rareColor
      end
      if row.crest then
        row.crest:SetColorTexture(crestColor[1], crestColor[2], crestColor[3], 0.55)
      end
      row:Show()
      if data.bar and data.bar > 0 then
        row.bar:SetWidth(max(1, (row:GetWidth() - 8) * min(data.bar, 1)))
        row.bar:SetColorTexture(theme.bar[1], theme.bar[2], theme.bar[3], theme.bar[4])
        row.bar:Show()
      else
        row.bar:Hide()
      end
      if row.index == self.selectedIndex then
        row.background:SetColorTexture(theme.accentSoft[1], theme.accentSoft[2], theme.accentSoft[3], theme.accentSoft[4])
      else
        row.background:SetColorTexture(1, 1, 1, 0.04)
      end
    else
      row.index = nil
      row.bar:Hide()
      row:Hide()
    end
  end
end

function XPTooltip:SelectIndex(index)
  if not index or index <= 0 then
    return
  end
  self.selectedIndex = index
  self:UpdateRows()
  self:UpdateDetail()
end

function XPTooltip:GetSelected()
  if not self.currentList or not self.selectedIndex then
    return nil
  end
  return self.currentList[self.selectedIndex]
end

function XPTooltip:ShowModel(npcID)
  if not self.ui or not self.ui.model or not self.ui.modelFallback then
    return
  end
  if not self.ui.model.SetCreature then
    self:HideModel("No model support")
    return
  end
  if not npcID then
    self:HideModel("No model data")
    return
  end
  local ok = pcall(self.ui.model.SetCreature, self.ui.model, npcID)
  if not ok then
    self:HideModel("No model data")
    return
  end
  self.ui.model:Show()
  self.ui.modelFallback:Hide()
  self.ui.modelFallbackIcon:Hide()
  pcall(self.ui.model.SetRotation, self.ui.model, self.modelYaw or 0)
  if self.ui.model.SetCamDistanceScale then
    pcall(self.ui.model.SetCamDistanceScale, self.ui.model, 1.15)
  end
  if self.ui.model.SetAnimation then
    pcall(self.ui.model.SetAnimation, self.ui.model, 0)
  end
end

function XPTooltip:HideModel(text)
  if not self.ui or not self.ui.model or not self.ui.modelFallback then
    return
  end
  self.ui.model:Hide()
  self.ui.modelFallback:SetText(text or "")
  if text and text ~= "" then
    self.ui.modelFallback:Show()
    self.ui.modelFallbackIcon:Show()
  else
    self.ui.modelFallback:Hide()
    self.ui.modelFallbackIcon:Hide()
  end
end

function XPTooltip:UpdateDetail()
  if not self.ui or not self.ui.details then
    return
  end
  local selected = self:GetSelected()
  self:UpdateDeleteButton(selected)
  if not selected then
    self:SetDetailMode(false)
    self:HideModel("No kill data yet")
    if self.ui.heroName then
      self.ui.heroName:SetText("No kill data")
    end
    if self.ui.heroSub then
      self.ui.heroSub:SetText("Kill a mob on Forever to start the history.")
    end
    self.ui.details:SetText("")
    return
  end

  if selected.kind == "mob" then
    self:UpdateMobDetail(selected.key)
  elseif selected.kind == "area" then
    self:HideModel("")
    self:UpdateAreaDetail(selected.key)
  else
    self:HideModel("")
    self:UpdateLevelDetail(selected.key)
  end
end

function XPTooltip:SetDetailMode(showModel)
  if not self.ui or not self.ui.heroName or not self.ui.heroSub or not self.ui.details then
    return
  end
  if self.ui.modelHolder then
    if showModel then
      self.ui.modelHolder:Show()
    else
      self.ui.modelHolder:Hide()
    end
  end
  local top = showModel and -240 or -12
  self.ui.heroName:ClearAllPoints()
  self.ui.heroName:SetPoint("TOPLEFT", 12, top)
  self.ui.heroName:SetPoint("TOPRIGHT", -12, top)
  self.ui.heroSub:ClearAllPoints()
  self.ui.heroSub:SetPoint("TOPLEFT", 12, top - 22)
  self.ui.heroSub:SetPoint("TOPRIGHT", -12, top - 22)
  self.ui.details:ClearAllPoints()
  self.ui.details:SetPoint("TOPLEFT", 12, showModel and -282 or -60)
  self.ui.details:SetPoint("BOTTOMRIGHT", -12, 10)
end

function XPTooltip:UpdateMobDetail(mobKey)
  self:SetDetailMode(true)
  local mob = self.char and self.char.mobs[mobKey]
  if type(mob) ~= "table" then
    self:HideModel("No model data")
    if self.ui.heroName then self.ui.heroName:SetText("Mob data unavailable") end
    if self.ui.heroSub then self.ui.heroSub:SetText("") end
    self.ui.details:SetText("")
    return
  end

  self:ShowModel(mob.npcID)
  self.ui.heroName:SetText(tostring(mob.name or "Unknown"))
  self.ui.heroSub:SetText(
    string.upper(tostring(mob.classification or "normal"))
      .. "  ·  NPC " .. tostring(mob.npcID or "unknown")
  )

  local lines = {}
  lines[#lines + 1] = "Total kills: " .. FormatNumber(mob.kills or 0)
  lines[#lines + 1] = "This session: " .. FormatNumber(mob.sessionKills or 0)
  local playerLevel = self:GetPlayerLevel()
  if playerLevel then
    local atLevel = mob.killsAtLevel and tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0
    lines[#lines + 1] = "This level: " .. FormatNumber(atLevel)
  end

  if type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
    lines[#lines + 1] = "Avg base XP: " .. FormatNumber((tonumber(mob.xp.sumBase) or 0) / mob.xp.samples)
    lines[#lines + 1] = "Avg total XP: " .. FormatNumber((tonumber(mob.xp.sumTotal) or 0) / mob.xp.samples)
  end

  local topMap, topMapKills = nil, 0
  if type(mob.killsByMap) == "table" then
    for mapKey, kills in pairs(mob.killsByMap) do
      if (tonumber(kills) or 0) > topMapKills then
        topMapKills = tonumber(kills) or 0
        topMap = mapKey
      end
    end
  end
  if topMap then
    lines[#lines + 1] = "Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topMapKills) .. ")"
  end

  local minLevel, maxLevel
  if type(mob.killsAtLevel) == "table" then
    for levelKey, kills in pairs(mob.killsAtLevel) do
      local level = tonumber(levelKey)
      if level and (tonumber(kills) or 0) > 0 then
        if not minLevel or level < minLevel then
          minLevel = level
        end
        if not maxLevel or level > maxLevel then
          maxLevel = level
        end
      end
    end
  end
  if minLevel then
    lines[#lines + 1] = "Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
  end

  lines[#lines + 1] = "First seen: " .. FormatDate(mob.firstSeen)
  lines[#lines + 1] = "Last seen: " .. FormatAgo(mob.lastSeen)
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateAreaDetail(mapKey)
  self:SetDetailMode(false)
  local db = self.char
  local kills = tonumber(db.areas[mapKey]) or 0
  local total = tonumber(db.totals.kills) or 0
  local percent = total > 0 and (kills / total * 100) or 0
  self.ui.heroName:SetText(self:GetMapName(mapKey))
  self.ui.heroSub:SetText(
    "Kills: " .. FormatNumber(kills) .. "  ·  " .. string.format("%.1f%%", percent) .. " of total"
  )

  local top = {}
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" and type(mob.killsByMap) == "table" then
      local value = tonumber(mob.killsByMap[mapKey]) or 0
      if value > 0 then
        top[#top + 1] = { name = mob.name or "Unknown", kills = value }
      end
    end
  end
  table.sort(top, function(a, b) return a.kills > b.kills end)

  local lines = {}
  lines[#lines + 1] = "Top mobs:"
  for index = 1, min(#top, 6) do
    lines[#lines + 1] = "  " .. tostring(top[index].name) .. " - " .. FormatNumber(top[index].kills) .. " kills"
  end

  local minLevel, maxLevel
  local areaLevels = db.areaLevels and db.areaLevels[mapKey]
  if type(areaLevels) == "table" then
    for levelKey, count in pairs(areaLevels) do
      local level = tonumber(levelKey)
      if level and (tonumber(count) or 0) > 0 then
        if not minLevel or level < minLevel then
          minLevel = level
        end
        if not maxLevel or level > maxLevel then
          maxLevel = level
        end
      end
    end
  end
  if minLevel then
    lines[#lines + 1] = "Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
  end
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateLevelDetail(levelKey)
  self:SetDetailMode(false)
  local db = self.char
  local kills = tonumber(db.levels[levelKey]) or 0
  local total = tonumber(db.totals.kills) or 0
  local percent = total > 0 and (kills / total * 100) or 0
  self.ui.heroName:SetText("Player level " .. tostring(levelKey))
  self.ui.heroSub:SetText(
    "Kills: " .. FormatNumber(kills) .. "  ·  " .. string.format("%.1f%%", percent) .. " of total"
  )

  local top = {}
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" and type(mob.killsAtLevel) == "table" then
      local value = tonumber(mob.killsAtLevel[levelKey]) or 0
      if value > 0 then
        top[#top + 1] = { name = mob.name or "Unknown", kills = value }
      end
    end
  end
  table.sort(top, function(a, b) return a.kills > b.kills end)

  local lines = {}
  lines[#lines + 1] = "Top mobs:"
  for index = 1, min(#top, 8) do
    lines[#lines + 1] = "  " .. tostring(top[index].name) .. " - " .. FormatNumber(top[index].kills) .. " kills"
  end
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateFooter()
  if not self.ui or not self.ui.footer then
    return
  end
  local db = self.char
  if not db then
    self.ui.footer:SetText("")
    return
  end
  local total = tonumber(db.totals.kills) or 0
  local session = tonumber(db.session.kills) or 0
  local unique = tonumber(db.totals.uniqueMobs) or 0

  local topMap, topMapKills = nil, 0
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > topMapKills then
      topMapKills = tonumber(kills) or 0
      topMap = mapKey
    end
  end

  local minLevel, maxLevel
  for levelKey, kills in pairs(db.levels or {}) do
    local level = tonumber(levelKey)
    if level and (tonumber(kills) or 0) > 0 then
      if not minLevel or level < minLevel then
        minLevel = level
      end
      if not maxLevel or level > maxLevel then
        maxLevel = level
      end
    end
  end

  local text = "Total kills: " .. FormatNumber(total)
    .. "   Session: " .. FormatNumber(session)
    .. "   Mobs tracked: " .. FormatNumber(unique)
  if topMap then
    text = text .. "   Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topMapKills) .. ")"
  end
  if minLevel then
    text = text .. "   Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
  end
  self.ui.footer:SetText(text)
end

function XPTooltip:RefreshUI()
  if not self.ui or not self.ui:IsShown() then
    return
  end
  if not self:IsActive() then
    self.ui:Hide()
    return
  end
  if self.tab == "overview" then
    self:RefreshOverview()
  else
    self:BuildList()
    self:UpdateRows()
    self:UpdateDetail()
  end
  self:UpdateFilterButtons()
  self:UpdateTabs()
  self:UpdateStatusChip()
  self:UpdateFooter()
end

function XPTooltip:SafeRefreshUI()
  local ok, err = pcall(self.RefreshUI, self)
  if not ok then
    self:ReportError("RefreshUI", err)
  end
end

function XPTooltip:RequestUIUpdate()
  if self.uiRefreshPending then
    return
  end
  self.uiRefreshPending = true
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 0.25, function()
      self.uiRefreshPending = false
      if self:IsActive() then
        self:SafeRefreshUI()
      end
    end)
  else
    self.uiRefreshPending = false
    self:SafeRefreshUI()
  end
end

function XPTooltip:OpenUI()
  if not self:IsActive() then
    self:PrintStatus()
    return
  end
  local ok, frame = pcall(self.CreateUI, self)
  if not ok or not frame then
    self:ReportError("CreateUI", frame or "no frame")
    return
  end
  local showOK, err = pcall(frame.Show, frame)
  if not showOK then
    self:ReportError("ShowUI", err)
    return
  end
  local currentSettings = self:GetSettings()
  if currentSettings and currentSettings.scale and frame.SetScale then
    pcall(frame.SetScale, frame, currentSettings.scale)
  end
  self:ApplyTheme()
  pcall(frame.Raise, frame)
  local settings = self:GetSettings()
  if settings and settings.sound and type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then
    pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPEN)
  end
  if type(UIFrameFadeIn) == "function" then
    pcall(UIFrameFadeIn, frame, 0.15, 0, 1)
  end
  self:SafeRefreshUI()
end

function XPTooltip:CloseUI()
  if self.ui and self.ui.Hide then
    local settings = self:GetSettings()
    if settings and settings.sound and type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE then
      pcall(PlaySound, SOUNDKIT.IG_MAINMENU_CLOSE)
    end
    pcall(self.ui.Hide, self.ui)
  end
end
