--[[---------------------------------------------------------------------------------
  AceM2L2 - by faslkjd56
  Midnight 12.1.x + Forever 1.60.x compatibility update
------------------------------------------------------------------------------------]]

AceM2L2 = LibStub("AceAddon-3.0"):NewAddon("AceM2L2", "AceEvent-3.0", "AceConsole-3.0")

BINDING_HEADER_ACEM2L2 = BINDING_HEADER_ACEM2L2 or "Ace Mobs 2 Level 2"
BINDING_NAME_ACEM2L2_XPTOOLTIP = BINDING_NAME_ACEM2L2_XPTOOLTIP or "Toggle Kill History"

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

--[[--------------------------------------------------------------------------------
  Small defensive helpers
  Midnight may hand addons secret values in restricted content.  All values that
  come from the game are passed through these helpers before we compare, format
  or do arithmetic with them.
------------------------------------------------------------------------------------]]

local function IsSecretValue(value)
  return issecretvalue and issecretvalue(value) or false
end

local function SafeBoolean(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  return value and true or false
end

local function SafeNumber(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  if type(value) ~= "number" then
    return nil
  end
  return value
end

local function SafeString(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  if type(value) ~= "string" then
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

local function StripColorCodes(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
  value = value:gsub("|r", "")
  return value
end

local function SanitizeLabel(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  value = value:gsub("[\r\n\t]", " ")
  value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
  value = value:gsub("|r", "")
  if #value > 120 then
    value = value:sub(1, 117) .. "..."
  end
  return value
end

local function SafeLower(text)
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

local function NormalizeNumber(value, kind)
  if type(value) == "number" then
    return SafeNumber(value)
  end
  local text = SafeString(value)
  if not text then
    return nil
  end
  if kind == "f" then
    text = text:gsub("%s", ""):gsub(",", ".")
    return tonumber(text)
  end
  text = text:gsub("[^%d%-]", "")
  if text == "" or text == "-" then
    return nil
  end
  return tonumber(text)
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c, d
end

local function GetSafeTime()
  return SafeNumber(SafeCall(GetTime)) or 0
end

local function GetUnitXP()
  return SafeNumber(SafeCall(UnitXP, "player"))
end

local function GetUnitXPMax()
  return SafeNumber(SafeCall(UnitXPMax, "player"))
end

local function GetUnitLevel()
  return SafeNumber(SafeCall(UnitLevel, "player"))
end

local function GetPlayerGuildName()
  return SafeString(SafeCall(GetGuildInfo, "player"))
end

local function AddChatMessage(text)
  local message = SafeString(text)
  if not message then
    return false
  end
  if #message > 1000 then
    message = message:sub(1, 1000)
  end
  local frame = DEFAULT_CHAT_FRAME
  if not frame or type(frame.AddMessage) ~= "function" then
    return false
  end
  return pcall(frame.AddMessage, frame, message)
end

local function SanitizeBoolean(value, defaultValue)
  if type(value) == "boolean" then
    return value
  end
  return defaultValue
end

local function SanitizeInteger(value, defaultValue, minValue, maxValue)
  local number = tonumber(value)
  if not number then
    return defaultValue
  end
  number = math.floor(number + 0.5)
  if minValue and number < minValue then
    number = minValue
  end
  if maxValue and number > maxValue then
    number = maxValue
  end
  return number
end

local function CopyDefaults(source)
  local copy = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = CopyDefaults(value)
    else
      copy[key] = value
    end
  end
  return copy
end

--[[--------------------------------------------------------------------------------
  Localized format-string -> Lua pattern conversion

  Handles %s, %d, %f, %% and positional forms such as %1$s / %2$d.  Captures are
  tracked by their original argument slot so reordered localizations still map
  back correctly.
------------------------------------------------------------------------------------]]

local PATTERN_MAGIC = "([%(%)%.%%%+%-%*%?%[%]%^%$])"

local function EscapePattern(text)
  return (text:gsub(PATTERN_MAGIC, "%%%1"))
end

local function FormatToPattern(fmt)
  if type(fmt) ~= "string" or IsSecretValue(fmt) then
    return nil
  end

  fmt = StripColorCodes(fmt) or fmt

  local parts = {}
  local tokens = {}
  local nextSlot = 1
  local i = 1

  local function addLiteral(text)
    if text and text ~= "" then
      parts[#parts + 1] = EscapePattern(text)
    end
  end

  while i <= #fmt do
    local percent = fmt:find("%", i, true)
    if not percent then
      addLiteral(fmt:sub(i))
      break
    end

    addLiteral(fmt:sub(i, percent - 1))

    local after = fmt:sub(percent + 1)
    local position, conversion = after:match("^(%d+)%$([sdf])")
    local consumed = nil

    if conversion then
      consumed = #position + 3
    else
      conversion = after:match("^([sdf])")
      if conversion then
        consumed = 2
      elseif after:sub(1, 1) == "%" then
        parts[#parts + 1] = "%%"
        i = percent + 2
      else
        addLiteral("%")
        i = percent + 1
      end
    end

    if conversion then
      local slot = tonumber(position)
      if slot then
        if slot >= nextSlot then
          nextSlot = slot + 1
        end
      else
        slot = nextSlot
        nextSlot = nextSlot + 1
      end

      if conversion == "s" then
        parts[#parts + 1] = "(.+)"
      else
        parts[#parts + 1] = "([%d%.,%s%-]+)"
      end
      tokens[#tokens + 1] = {
        slot = slot,
        kind = conversion,
      }
      i = percent + consumed
    end
  end

  if #tokens == 0 then
    return nil
  end

  return "^" .. table.concat(parts) .. "$", tokens
end

local function SafeMatchN(message, pattern)
  if type(message) ~= "string" or IsSecretValue(message) then
    return nil
  end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(string.match, message, pattern)
  if not ok then
    return nil
  end
  return { a, b, c, d, e, f, g, h, i, j, k, l }
end

local function ParseFormatted(message, fmt)
  local pattern, tokens = FormatToPattern(fmt)
  if not pattern then
    return nil
  end
  local values = SafeMatchN(message, pattern)
  if not values then
    return nil
  end

  local slots = {}
  local ordered = {}
  for index, token in ipairs(tokens) do
    local value = values[index]
    if value ~= nil then
      local entry = {
        kind = token.kind,
        value = value,
        slot = token.slot,
      }
      slots[token.slot] = entry
      ordered[#ordered + 1] = entry
    end
  end

  if #ordered == 0 then
    return nil
  end
  return slots, ordered
end

--[[--------------------------------------------------------------------------------
  Faction data normalization

  Indexing a secret/forbidden table can error, so every field read happens inside
  a pcall and is copied to a plain table.
------------------------------------------------------------------------------------]]

local function NormalizeFaction(data)
  if type(data) ~= "table" then
    return nil
  end

  local ok, name, minVal, maxVal, curVal, factionID, isHeader, isHeaderWithRep, isChild, standingID = pcall(function()
    return data.name,
      data.currentReactionThreshold,
      data.nextReactionThreshold,
      data.currentStanding,
      data.factionID,
      data.isHeader,
      data.isHeaderWithRep,
      data.isChild,
      data.standingID
  end)
  if not ok then
    return nil
  end

  return {
    name = name,
    currentReactionThreshold = minVal,
    nextReactionThreshold = maxVal,
    currentStanding = curVal,
    factionID = factionID,
    isHeader = isHeader,
    isHeaderWithRep = isHeaderWithRep,
    isChild = isChild,
    standingID = standingID,
  }
end

--[[--------------------------------------------------------------------------------
  Addon lifecycle
------------------------------------------------------------------------------------]]

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

  local validStartTabs = { overview = true, mobs = true, areas = true, levels = true }
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

function AceM2L2:SafePrint(...)
  local ok = pcall(self.Print, self, ...)
  if not ok and type(print) == "function" then
    pcall(print, ...)
  end
end

function AceM2L2:ReportError(context, err)
  local message = tostring(context or "error") .. ": " .. tostring(err)
  if #message > 500 then
    message = message:sub(1, 500)
  end
  self.lastError = message
  if self.db and self.db.debug then
    self:SafePrint("|cffff5555" .. message .. "|r")
  end
end

function AceM2L2:SafeInvoke(context, method, ...)
  local fn = self[method]
  if type(fn) ~= "function" then
    self:ReportError(context, "missing method " .. tostring(method))
    return
  end
  local ok, err = pcall(fn, self, ...)
  if not ok then
    pcall(self.ReportError, self, context, err)
  end
end

function AceM2L2:SafeRegister(event, method)
  local ok, err = pcall(self.RegisterEvent, self, event, method)
  if not ok then
    self:ReportError("RegisterEvent " .. tostring(event), err)
  end
  return ok
end

function AceM2L2:SafeUnregister(event)
  pcall(self.UnregisterEvent, self, event)
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

function AceM2L2:RefreshFactionBaseline()
  local captured = self:CaptureFactionStandings()
  if next(captured) ~= nil then
    self.factionStandings = captured
  elseif not self.factionStandings then
    self.factionStandings = {}
  end
  self:ScheduleFactionBaselineRetry()
end

function AceM2L2:EnsureFactionBaseline()
  local captured = self:CaptureFactionStandings()
  self.factionStandings = self.factionStandings or {}
  for factionID, standing in pairs(captured) do
    if self.factionStandings[factionID] == nil then
      self.factionStandings[factionID] = standing
    end
  end
end

function AceM2L2:ScheduleFactionBaselineRetry()
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 2, function()
      if self:IsEnabled() then
        self:SafeInvoke("EnsureFactionBaseline", "EnsureFactionBaseline")
      end
    end)
  end
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

--[[--------------------------------------------------------------------------------
  Utility helpers
------------------------------------------------------------------------------------]]

function AceM2L2:RoundFormatted(number)
  local value = SafeNumber(number)
  if not value then
    return "?"
  end
  local precision = self:GetNumberSetting("precision", 2, 0, 4, true)
  return string.format("%0." .. precision .. "f", value)
end

function AceM2L2:AddSampleXP(xp)
  local value = SafeNumber(xp)
  if not value or value <= 0 then
    return
  end

  self.xpSamples = self.xpSamples or {}
  table.insert(self.xpSamples, value)
  local maxSamples = math.max(1, self:GetNumberSetting("rollingXPWindow", 5, 1, 100, true))
  while #self.xpSamples > maxSamples do
    table.remove(self.xpSamples, 1)
  end
end

function AceM2L2:GetAverageXP()
  local samples = self.xpSamples or {}
  if #samples == 0 then
    return nil
  end

  local total = 0
  for _, value in ipairs(samples) do
    total = total + value
  end

  return total / #samples
end

function AceM2L2:ShouldPrintXPMsg(estimatedKills)
  if not self.db.xpEnabled then
    return false
  end

  self.xpKillCounter = (self.xpKillCounter or 0) + 1
  local everyN = self:GetNumberSetting("xpEveryNKills", 1, 1, 1000, true)
  if self.xpKillCounter % everyN ~= 0 then
    return false
  end

  local minRemaining = self:GetNumberSetting("xpMinKillsRemaining", 0, 0, nil, true)
  return estimatedKills >= minRemaining
end

function AceM2L2:ShouldPrintRepMsg(remaining)
  if not self.db.repEnabled then
    return false
  end

  self.repGainCounter = (self.repGainCounter or 0) + 1
  local everyN = self:GetNumberSetting("repEveryNGains", 1, 1, 1000, true)
  if self.repGainCounter % everyN ~= 0 then
    return false
  end

  local minRemaining = self:GetNumberSetting("repMinRemaining", 0, 0, nil, true)
  return remaining >= minRemaining
end

--[[--------------------------------------------------------------------------------
  XP parsing
------------------------------------------------------------------------------------]]

function AceM2L2:GetXPFmts()
  if self.xpFmts then
    return self.xpFmts
  end

  local formats = {}
  for key, value in pairs(_G) do
    if type(key) == "string" and type(value) == "string" and key:match("^COMBATLOG_XPGAIN_") then
      local hasName = true
      if key:find("_UNNAMED", 1, true) or key:find("_QUEST", 1, true) then
        hasName = false
      end
      formats[#formats + 1] = {
        key = key,
        fmt = value,
        hasName = hasName,
      }
    end
  end

  table.sort(formats, function(a, b)
    return #a.key > #b.key
  end)

  self.xpFmts = formats
  return formats
end

function AceM2L2:ParseXPMessage(message)
  if not message or IsSecretValue(message) then
    return nil
  end

  local text = StripColorCodes(message) or message
  for _, info in ipairs(self:GetXPFmts()) do
    local _, ordered = ParseFormatted(text, info.fmt)
    if ordered then
      local name = nil
      local total = 0
      local foundNumber = false

      for _, item in ipairs(ordered) do
        if item.kind == "s" and info.hasName and not name then
          name = Trim(item.value)
        elseif item.kind == "d" or item.kind == "f" then
          local number = NormalizeNumber(item.value, item.kind)
          if number then
            total = total + number
            foundNumber = true
          end
        end
      end

      if foundNumber and total > 0 then
        return name, total, info.key
      end
    end
  end

  return nil
end

function AceM2L2:C(_, message)
  self:SafeInvoke("CHAT_MSG_COMBAT_XP_GAIN", "HandleXPText", message)
end

function AceM2L2:HandleXPText(message)
  if not self.db.xpEnabled then
    return
  end

  -- The amount comes from PLAYER_XP_UPDATE.  The chat event supplies the
  -- creature name and whether the gain was a quest, which the XP event does
  -- not carry.
  if IsSecretValue(message) then
    self.lastCreatureName = nil
    self.lastXPSource = nil
    self.lastXPInfoTime = GetSafeTime()
    return
  end

  local name, _, key = self:ParseXPMessage(message)
  if not key then
    self.lastCreatureName = nil
    self.lastXPSource = nil
    self.lastXPInfoTime = GetSafeTime()
    return
  end

  local isQuest = key:find("_QUEST", 1, true) ~= nil
  self.lastCreatureName = name
  self.lastXPSource = isQuest and "quest" or "kill"
  self.lastXPInfoTime = GetSafeTime()

  if self.db.debug then
    self:SafePrint("XP source: " .. tostring(name or (isQuest and "quest" or "mob")) .. " [" .. tostring(key) .. "]")
  end
end

function AceM2L2:HandleXPGain(creatureName, xp, isQuest)
  local value = SafeNumber(xp)
  if not value or value <= 0 then
    return
  end

  if not isQuest then
    self:AddSampleXP(value)
  end

  local levelAtGain = GetUnitLevel()
  local function printEstimate()
    if not self:IsEnabled() then
      return
    end
    if levelAtGain and GetUnitLevel() ~= levelAtGain then
      return
    end
    self:SafeInvoke("PrintXPEstimate", "PrintXPEstimate", creatureName, value, isQuest)
  end

  if C_Timer and C_Timer.After then
    local ok = pcall(C_Timer.After, 0, printEstimate)
    if not ok then
      printEstimate()
    end
  else
    printEstimate()
  end
end

function AceM2L2:PrintXPEstimate(creatureName, xp, isQuest)
  local xpMax = GetUnitXPMax()
  local xpCurrent = GetUnitXP()
  if not xpMax or not xpCurrent or xpMax <= 0 or xpCurrent >= xpMax then
    return
  end

  local xpPerKill = SafeNumber(xp)
  if self.db.useRollingXP and not isQuest then
    xpPerKill = self:GetAverageXP() or xpPerKill
  end
  xpPerKill = SafeNumber(xpPerKill)
  if not xpPerKill or xpPerKill <= 0 then
    return
  end

  local remaining = xpMax - xpCurrent
  if remaining <= 0 then
    return
  end

  local mobsToLevel = math.max(1, math.ceil(remaining / xpPerKill))
  if not self:ShouldPrintXPMsg(mobsToLevel) then
    return
  end

  local label = SanitizeLabel(creatureName) or (isQuest and "Quest" or "Mob")
  local suffix = isQuest and "quests to level" or "kills to level"
  AddChatMessage(
    "|cFFFFFFFF[|r|cff00FF00" .. mobsToLevel .. "|r|cFFFFFFFF] [|r" ..
    "|cff00FF00" .. label .. "|r|cFFFFFFFF] " .. suffix .. "|r"
  )
end

function AceM2L2:OnPlayerXPUpdate()
  self:SafeInvoke("PLAYER_XP_UPDATE", "HandlePlayerXPUpdate")
end

function AceM2L2:HandlePlayerXPUpdate()
  local current = GetUnitXP()
  if not current then
    return
  end

  if self.lastXP == nil then
    self.lastXP = current
    return
  end

  local delta = current - self.lastXP
  self.lastXP = current
  if delta <= 0 then
    return
  end

  local now = GetSafeTime()
  local isQuest = false
  local name = nil
  if self.lastXPInfoTime and self.lastXPInfoTime > 0 and (now - self.lastXPInfoTime) < 2 then
    isQuest = self.lastXPSource == "quest"
    name = self.lastCreatureName
  end

  self.lastCreatureName = nil
  self.lastXPSource = nil
  self.lastXPInfoTime = 0

  self:HandleXPGain(name, delta, isQuest)
end

--[[--------------------------------------------------------------------------------
  Reputation parsing and faction helpers
------------------------------------------------------------------------------------]]

function AceM2L2:GetRepFmts()
  if self.repFmts then
    return self.repFmts
  end

  local formats = {}
  for key, value in pairs(_G) do
    if type(key) == "string" and type(value) == "string" and key:match("^FACTION_STANDING_INCREASED") then
      formats[#formats + 1] = {
        key = key,
        fmt = value,
      }
    end
  end

  table.sort(formats, function(a, b)
    return #a.key > #b.key
  end)

  self.repFmts = formats
  return formats
end

function AceM2L2:ParseRepMessage(message)
  if not message or IsSecretValue(message) then
    return nil
  end

  local text = StripColorCodes(message) or message
  for _, info in ipairs(self:GetRepFmts()) do
    local _, ordered = ParseFormatted(text, info.fmt)
    if ordered then
      local factionName = nil
      local gain = 0
      local foundNumber = false

      for _, item in ipairs(ordered) do
        if item.kind == "s" and not factionName then
          factionName = Trim(item.value)
        elseif item.kind == "d" or item.kind == "f" then
          local number = NormalizeNumber(item.value, item.kind)
          if number then
            gain = gain + number
            foundNumber = true
          end
        end
      end

      if factionName and foundNumber and gain > 0 then
        return factionName, gain, info.key
      end
    end
  end

  return nil
end

function AceM2L2:GetNumFactions()
  if C_Reputation and C_Reputation.GetNumFactions then
    local ok, num = pcall(C_Reputation.GetNumFactions)
    num = SafeNumber(num)
    if ok and num then
      return num
    end
  end

  if GetNumFactions then
    local ok, num = pcall(GetNumFactions)
    num = SafeNumber(num)
    if ok and num then
      return num
    end
  end

  return 0
end

function AceM2L2:GetFactionDataByIndex(index)
  if C_Reputation and C_Reputation.GetFactionDataByIndex then
    local ok, data = pcall(C_Reputation.GetFactionDataByIndex, index)
    if ok and data then
      local faction = NormalizeFaction(data)
      if faction then
        faction.index = index
      end
      return faction
    end
  end

  if GetFactionInfo then
    local ok, name, _, standingID, minVal, maxVal, curVal, _, _, isHeader, _, hasRep, _, isChild, factionID = pcall(GetFactionInfo, index)
    if ok and name then
      local faction = NormalizeFaction({
        name = name,
        currentReactionThreshold = minVal,
        nextReactionThreshold = maxVal,
        currentStanding = curVal,
        standingID = standingID,
        factionID = factionID,
        isHeader = isHeader,
        isHeaderWithRep = hasRep,
        isChild = isChild,
      })
      if faction then
        faction.index = index
      end
      return faction
    end
  end

  return nil
end

function AceM2L2:GetFactionDataByID(factionID)
  local id = SafeNumber(factionID)
  if not id then
    return nil
  end

  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, data = pcall(C_Reputation.GetFactionDataByID, id)
    if ok and data then
      return NormalizeFaction(data)
    end
  end

  -- Fallback for clients/builds without GetFactionDataByID.
  local numFactions = self:GetNumFactions()
  for index = 1, numFactions do
    local faction = self:GetFactionDataByIndex(index)
    if faction and SafeNumber(faction.factionID) == id then
      return faction
    end
  end

  return nil
end

function AceM2L2:RefreshFactionData(faction)
  if not faction then
    return nil
  end

  local refreshed = self:GetFactionDataByID(faction.factionID)
  if not refreshed and faction.index then
    refreshed = self:GetFactionDataByIndex(faction.index)
  end
  return refreshed or faction
end

function AceM2L2:GetGuildFactionData()
  if C_Reputation and C_Reputation.GetGuildFactionData then
    local ok, data = pcall(C_Reputation.GetGuildFactionData)
    if ok and data then
      return NormalizeFaction(data)
    end
  end
  return nil
end

function AceM2L2:RebuildFactionCache()
  local cache = {}
  local numFactions = self:GetNumFactions()

  for index = 1, numFactions do
    local faction = self:GetFactionDataByIndex(index)
    local isHeader = faction and SafeBoolean(faction.isHeader) == true
    local isHeaderWithRep = faction and SafeBoolean(faction.isHeaderWithRep) == true
    if faction and faction.name and (not isHeader or isHeaderWithRep) then
      local key = SafeLower(faction.name)
      if key and not cache[key] then
        cache[key] = faction
      end
    end
  end

  self.factionCache = cache
  self.factionCacheTime = GetSafeTime()
end

function AceM2L2:GetFactionRecordByName(factionName)
  local key = SafeLower(factionName)
  if not key then
    return nil
  end

  local now = GetSafeTime()
  if not self.factionCache or (now - (self.factionCacheTime or 0)) > 2 then
    self:RebuildFactionCache()
    self.factionCacheTime = now
  end

  if self.factionCache then
    return self.factionCache[key]
  end
  return nil
end

function AceM2L2:GetReputationProgress(faction)
  if not faction then
    return nil
  end

  local factionID = SafeNumber(faction.factionID)
  local minVal = SafeNumber(faction.currentReactionThreshold) or 0
  local maxVal = SafeNumber(faction.nextReactionThreshold) or 0
  local curVal = SafeNumber(faction.currentStanding) or 0

  if factionID and C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.GetFactionParagonInfo then
    local ok, isParagon = pcall(C_Reputation.IsFactionParagon, factionID)
    if ok and SafeBoolean(isParagon) then
      local ok2, value, threshold = pcall(C_Reputation.GetFactionParagonInfo, factionID)
      value = SafeNumber(value)
      threshold = SafeNumber(threshold)
      if ok2 and value and threshold and threshold > 0 then
        return 0, threshold, value % threshold
      end
    end
  end

  if factionID and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
    local isMajor = true
    if C_Reputation and C_Reputation.IsMajorFaction then
      local ok, major = pcall(C_Reputation.IsMajorFaction, factionID)
      if ok and SafeBoolean(major) == false then
        isMajor = false
      end
    end

    if isMajor then
      local ok, earned, threshold = pcall(function()
        local major = C_MajorFactions.GetMajorFactionData(factionID)
        if not major then
          return nil
        end
        return SafeNumber(major.renownReputationEarned), SafeNumber(major.renownLevelThreshold)
      end)
      if ok and earned and threshold and threshold > 0 then
        return 0, threshold, earned
      end
    end
  end

  if maxVal <= minVal then
    return nil
  end

  return minVal, maxVal, curVal
end

function AceM2L2:HandleRepGain(factionName, faction, gain)
  if not faction then
    return
  end
  if SafeBoolean(faction.isHeader) == true and SafeBoolean(faction.isHeaderWithRep) ~= true then
    return
  end

  local value = SafeNumber(gain)
  if not value or value <= 0 then
    return
  end

  faction = self:RefreshFactionData(faction) or faction

  local _, maxVal, curVal = self:GetReputationProgress(faction)
  maxVal = SafeNumber(maxVal)
  curVal = SafeNumber(curVal)
  if not maxVal or not curVal then
    return
  end

  local remaining = maxVal - curVal
  if remaining < 0 then
    remaining = 0
  end

  if not self:ShouldPrintRepMsg(remaining) then
    return
  end

  local repeats = remaining / value
  local label = SanitizeLabel(factionName) or SanitizeLabel(faction.name) or "faction"
  AddChatMessage(
    "|cFFFFFFFF[|r|cff00FF00" .. self:RoundFormatted(remaining) .. "|r|cFFFFFFFF] to go with [|r" ..
    "|cff00FF00" .. label .. "|r|cFFFFFFFF] = [|r" ..
    "|cff00FF00" .. self:RoundFormatted(repeats) .. "|r|cFFFFFFFF] repeats (kills/quests)|r"
  )
end

function AceM2L2:RF(_, message)
  self:SafeInvoke("CHAT_MSG_COMBAT_FACTION_CHANGE", "HandleFactionText", message)
end

function AceM2L2:HandleFactionText(message)
  -- FACTION_STANDING_CHANGED is the primary, locale-independent source.
  -- Keep the chat parser only as a fallback for clients where that event is
  -- unavailable.
  if self.useStandingEvent or not self.db.repEnabled then
    return
  end

  local factionName, gain, key = self:ParseRepMessage(message)
  if not factionName or not gain or gain <= 0 then
    return
  end

  factionName = Trim(factionName) or factionName

  if self.db.debug then
    self:SafePrint("Rep parsed: " .. (SanitizeLabel(factionName) or "faction") .. " +" .. tostring(gain) .. " [" .. tostring(key) .. "]")
  end

  local faction = self:GetFactionRecordByName(factionName)

  if not faction then
    local guildName = GetPlayerGuildName()
    if guildName and SafeLower(guildName) == SafeLower(factionName) then
      faction = self:GetGuildFactionData()
    end
  end

  if not faction and (factionName == (GUILD_REPUTATION or "") or factionName == (GUILD or "")) then
    faction = self:GetGuildFactionData()
  end

  if not faction then
    return
  end

  self:HandleRepGain(factionName, faction, gain)
end

function AceM2L2:CaptureFactionStandings()
  local standings = {}
  local numFactions = self:GetNumFactions()

  for index = 1, numFactions do
    local faction = self:GetFactionDataByIndex(index)
    local factionID = faction and SafeNumber(faction.factionID)
    local isHeader = faction and SafeBoolean(faction.isHeader) == true
    local isHeaderWithRep = faction and SafeBoolean(faction.isHeaderWithRep) == true
    if faction and factionID and (not isHeader or isHeaderWithRep) then
      local standing = SafeNumber(faction.currentStanding)
      if standing then
        standings[factionID] = standing
      end
    end
  end

  local guild = self:GetGuildFactionData()
  local guildID = guild and SafeNumber(guild.factionID)
  if guild and guildID and standings[guildID] == nil then
    local standing = SafeNumber(guild.currentStanding)
    if standing then
      standings[guildID] = standing
    end
  end

  return standings
end

function AceM2L2:OnFactionStandingChanged(_, factionID, updatedStanding)
  self:SafeInvoke("FACTION_STANDING_CHANGED", "HandleFactionStandingChanged", factionID, updatedStanding)
end

function AceM2L2:HandleFactionStandingChanged(factionID, updatedStanding)
  local id = NormalizeNumber(factionID)
  local newValue = NormalizeNumber(updatedStanding)
  if not id or not newValue then
    return
  end

  self.factionStandings = self.factionStandings or {}
  local oldValue = self.factionStandings[id]
  self.factionStandings[id] = newValue

  -- Keep the baseline fresh even while output is disabled, otherwise the
  -- first gain after re-enabling would appear much larger than it is.
  if not self.db.repEnabled then
    return
  end

  -- No baseline means the faction was not present when we logged in/zoned in.
  -- Seed it and wait for the next gain.
  if oldValue == nil then
    return
  end

  local gain = newValue - oldValue
  if gain <= 0 then
    -- Reputation loss, or a paragon/renown threshold reset.  The next gain
    -- will be reported normally.
    return
  end

  local faction = self:GetFactionDataByID(id)
  if not faction then
    local guild = self:GetGuildFactionData()
    if guild and SafeNumber(guild.factionID) == id then
      faction = guild
    end
  end
  if not faction then
    return
  end

  if self.db.debug then
    self:SafePrint("Rep standing changed: " .. (SanitizeLabel(faction.name) or "faction") .. " +" .. tostring(gain))
  end

  self:HandleRepGain(faction.name, faction, gain)
end

--[[--------------------------------------------------------------------------------
  Interface options panel (modern Settings API)
------------------------------------------------------------------------------------]]

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

  addCheckbox(
    "Kill History: show kills to level",
    "ACEM2L2_XPTOOLTIP_SHOW_KILLS",
    true,
    function() return self.db.xpTooltip.showKillsToLevel end,
    function(value) self.db.xpTooltip.showKillsToLevel = SanitizeBoolean(value, true) end,
    "Show how many kills of this mob remain to level."
  )

  addCheckbox(
    "Kill History: show kill count",
    "ACEM2L2_XPTOOLTIP_SHOW_KILL_COUNT",
    true,
    function() return self.db.xpTooltip.showKillCount end,
    function(value) self.db.xpTooltip.showKillCount = SanitizeBoolean(value, true) end,
    "Show how many of this mob you have already killed."
  )

  addCheckbox(
    "Kill History: show rested",
    "ACEM2L2_XPTOOLTIP_SHOW_RESTED",
    true,
    function() return self.db.xpTooltip.showRested end,
    function(value) self.db.xpTooltip.showRested = SanitizeBoolean(value, true) end,
    "Show rested XP bonus and rested kill counts."
  )

  addCheckbox(
    "Kill History: show unknown mobs",
    "ACEM2L2_XPTOOLTIP_SHOW_UNKNOWN",
    true,
    function() return self.db.xpTooltip.showUnknown end,
    function(value) self.db.xpTooltip.showUnknown = SanitizeBoolean(value, true) end,
    "Show an estimate/unknown line for mobs that have not been observed yet."
  )

  addCheckbox(
    "Kill History: count zero-XP kills",
    "ACEM2L2_XPTOOLTIP_COUNT_ZERO",
    true,
    function() return self.db.xpTooltip.countZeroXPMobs end,
    function(value) self.db.xpTooltip.countZeroXPMobs = SanitizeBoolean(value, true) end,
    "Count gray/trivial kills when a readable UNIT_DIED event is available."
  )

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

--[[--------------------------------------------------------------------------------
  Slash commands
------------------------------------------------------------------------------------]]

function AceM2L2:GetClientLabel()
  if WOW_PROJECT_ID == CAMELOT_PROJECT_ID then
    return "Forever"
  elseif WOW_PROJECT_ID == MAINLINE_PROJECT_ID then
    return "Midnight"
  end
  return "Unknown"
end

function AceM2L2:GetInterfaceVersion()
  local _, _, _, interfaceVersion = SafeCall(GetBuildInfo)
  return SafeNumber(interfaceVersion)
end

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
  self:SafePrint("/acem2l2 xpt ui")
  self:SafePrint("/acem2l2 xpt kills [name]")
  self:SafePrint("/acem2l2 xpt areas")
  self:SafePrint("/acem2l2 xpt levels")
  self:SafePrint("/acem2l2 xpt session")
  self:SafePrint("/acem2l2 xpt stats")
  self:SafePrint("/acem2l2 xpt dump")
  self:SafePrint("/acem2l2 xpt table")
  self:SafePrint("/acem2l2 xpt theme aether|dark|midnight|class|contrast")
  self:SafePrint("/acem2l2 xpt scale 80-120")
  self:SafePrint("/acem2l2 xpt starttab overview|mobs|areas|levels")
  self:SafePrint("/acem2l2 xpt minimap on|off|reset|status")
  self:SafePrint("/acem2l2 xpt recalibrate confirm")
  self:SafePrint("/acem2l2 xpt delete <mob name>")
  self:SafePrint("/acem2l2 xpt delete confirm <mob name>")
  self:SafePrint("/acem2l2 xpt deleteunknown confirm")
  self:SafePrint("/acem2l2 xpt reset | resetkills")
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
      self:SafePrint("Kill History=" .. tostring(status))
    end
  else
    self:SafePrint("Kill History=module not loaded")
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
    self.db.xpMinKillsRemaining = SanitizeInteger(tonumber(arg) or self.db.xpMinKillsRemaining, 0, 0, 1000000)
  elseif cmd == "repmin" then
    self.db.repMinRemaining = SanitizeInteger(tonumber(arg) or self.db.repMinRemaining, 0, 0, 100000000)
  elseif cmd == "rolling" then
    local value = self:SetToggle(arg, "rolling")
    if value ~= nil then
      self.db.useRollingXP = value
    end
  elseif cmd == "window" then
    self.db.rollingXPWindow = SanitizeInteger(tonumber(arg) or self.db.rollingXPWindow, 1, 1, 100)
  elseif cmd == "precision" then
    self.db.precision = SanitizeInteger(tonumber(arg) or self.db.precision, 2, 0, 4)
  elseif cmd == "config" or cmd == "options" then
    if self.optionsCategory and Settings and Settings.OpenToCategory then
      pcall(Settings.OpenToCategory, self.optionsCategory:GetID())
    else
      self:SafePrint("Settings panel is not available.")
    end
  elseif cmd == "history" or cmd == "window" then
    local module = self:GetXPTooltipModule()
    if module and module.OpenUI then
      pcall(module.OpenUI, module)
    else
      self:SafePrint("Kill History module is not available.")
    end
  elseif cmd == "kills" then
    local module = self:GetXPTooltipModule()
    if module and module.HandleCommand then
      local ok, err = pcall(module.HandleCommand, module, "kills " .. (arg or ""))
      if not ok then
        self:ReportError("Kill History command", err)
      end
    else
      self:SafePrint("Kill History module is not available.")
    end
  elseif cmd == "xpt" or cmd == "xptooltip" then
    local module = self:GetXPTooltipModule()
    if module and module.HandleCommand then
      local ok, err = pcall(module.HandleCommand, module, arg)
      if not ok then
        self:ReportError("Kill History command", err)
      end
    else
      self:SafePrint("Kill History module is not available.")
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
