--[[---------------------------------------------------------------------------------
  KillHistory/UI/Diagnostics.lua
  Data-store diagnostics: tracked counts, limits, and approximate size.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local min, max = math.min, math.max
local CreateBackdropFrame = UI.CreateBackdropFrame
local CreateTextButton = UI.CreateTextButton
local FormatNumber = Util.FormatNumber
local FormatPercent = Util.FormatPercent
local SafeCall = Util.SafeCall
local SafeString = Util.SafeString

local ROW_COUNT = 17
local ROW_HEIGHT = 24
local ESTIMATE_ENTRY_LIMIT = 200000

local function CountKeys(value)
  local count = 0
  if type(value) == "table" then
    for _ in pairs(value) do
      count = count + 1
    end
  end
  return count
end

local function CountHeatmaps(heatmaps)
  local zones, cells = 0, 0
  if type(heatmaps) ~= "table" then
    return zones, cells
  end
  for _, entry in pairs(heatmaps) do
    if type(entry) == "table" then
      zones = zones + 1
      cells = cells + CountKeys(entry.cells)
    end
  end
  return zones, cells
end

local function CountRespawns(respawns)
  local npcs, samples = 0, 0
  if type(respawns) ~= "table" then
    return npcs, samples
  end
  for _, entry in pairs(respawns) do
    if type(entry) == "table" then
      npcs = npcs + 1
      if type(entry.intervals) == "table" then
        samples = samples + CountKeys(entry.intervals)
      end
    end
  end
  return npcs, samples
end

local function CountContexts(mobs)
  local contexts = 0
  if type(mobs) ~= "table" then
    return contexts
  end
  for _, mob in pairs(mobs) do
    if type(mob) == "table" then
      contexts = contexts + CountKeys(mob.contexts)
    end
  end
  return contexts
end

local function CountCalibration(calibration)
  if type(calibration) ~= "table" then
    return 0
  end
  return CountKeys(calibration.zones)
    + CountKeys(calibration.levels)
    + CountKeys(calibration.groups)
    + CountKeys(calibration.classes)
    + CountKeys(calibration.mobs)
end

local function EstimateSize(value, state)
  state.entries = state.entries + 1
  if state.entries > ESTIMATE_ENTRY_LIMIT then
    state.truncated = true
    return 0
  end

  local kind = type(value)
  if kind == "string" then
    return #value + 6
  elseif kind == "number" then
    return 9
  elseif kind == "boolean" then
    return 6
  elseif kind ~= "table" then
    return 4
  end

  if state.seen[value] then
    return 4
  end
  state.seen[value] = true

  local bytes = 10
  for key, item in pairs(value) do
    bytes = bytes + EstimateSize(key, state)
    bytes = bytes + EstimateSize(item, state)
    if state.truncated then
      break
    end
  end
  return bytes
end

local function FormatBytes(bytes)
  local value = tonumber(bytes) or 0
  if value >= 1024 * 1024 then
    return string.format("%.2f MB", value / (1024 * 1024))
  elseif value >= 1024 then
    return string.format("%.1f KB", value / 1024)
  end
  return FormatNumber(value) .. " B"
end

local function LimitText(count, limit)
  if limit and limit > 0 then
    return FormatNumber(count) .. " / " .. FormatNumber(limit)
      .. "  (" .. FormatPercent(count / limit * 100) .. ")"
  end
  return FormatNumber(count)
end

function XPTooltip:GetDataStats()
  local db = type(self.char) == "table" and self.char or {}
  local mobs = type(db.mobs) == "table" and db.mobs or {}
  local quests = type(db.quests) == "table" and db.quests or {}
  local deaths = type(db.deaths) == "table" and db.deaths or {}
  local levelRecords = type(db.levelHistory) == "table" and db.levelHistory or {}
  local rates = type(db.rates) == "table" and db.rates or {}
  local respawnNpcs, respawnSamples = CountRespawns(db.respawns)
  local heatmapZones, heatmapCells = CountHeatmaps(db.heatmaps)
  local heatmapEnabled = true
  if type(self.GetSettings) == "function" then
    local ok, settings = pcall(self.GetSettings, self)
    if ok and type(settings) == "table" then
      heatmapEnabled = settings.heatmapEnabled ~= false
    end
  end
  local heatmapEstimate = EstimateSize(
    type(db.heatmaps) == "table" and db.heatmaps or {},
    { entries = 0, seen = {}, truncated = false }
  )
  local instanceCount, instanceKills = 0, 0
  for _, instance in pairs(type(db.instances) == "table" and db.instances or {}) do
    if type(instance) == "table" then
      instanceCount = instanceCount + 1
      instanceKills = instanceKills + (tonumber(instance.kills) or 0)
    end
  end
  local contexts = CountContexts(mobs)
  local calibrationEntries = CountCalibration(db.calibration)

  local stats = {
    mobs = CountKeys(mobs),
    quests = CountKeys(quests),
    deaths = CountKeys(deaths),
    levelRecords = CountKeys(levelRecords),
    rateSamples = CountKeys(rates),
    respawnNpcs = respawnNpcs,
    respawnSamples = respawnSamples,
    heatmapZones = heatmapZones,
    heatmapCells = heatmapCells,
    heatmapEnabled = heatmapEnabled,
    estimatedHeatmapBytes = heatmapEstimate,
    instances = instanceCount,
    instanceKills = instanceKills,
    contexts = contexts,
    calibrationEntries = calibrationEntries,
    maxMobs = Util.MAX_MOBS or 0,
    maxContexts = Util.MAX_CONTEXTS_PER_MOB or 0,
    maxQuests = XPTooltip.MAX_QUESTS or 0,
    maxLevelRecords = XPTooltip.MAX_LEVEL_RECORDS or 0,
    maxRateSamples = XPTooltip.MAX_RATE_SAMPLES or 0,
    maxDeaths = XPTooltip.MAX_DEATHS or 0,
    maxRespawnNpcs = XPTooltip.MAX_RESPAWN_NPCS or 0,
    maxRespawnSamples = XPTooltip.MAX_RESPAWN_SAMPLES or 0,
    maxHeatmapZones = XPTooltip.MAX_HEATMAP_MAPS or 0,
    maxInstances = Util.MAX_INSTANCE_RECORDS or 0,
    client = self.clientProfile and self.clientProfile.name or "Unknown",
    projectID = self:GetProjectID(),
    character = SafeString(SafeCall(UnitName, "player")) or "Unknown",
    realm = SafeString(SafeCall(GetRealmName)) or "",
  }
  stats.totalTracked = stats.mobs + stats.quests + stats.deaths
    + stats.respawnNpcs + stats.heatmapZones + stats.levelRecords
    + stats.rateSamples

  local estimate = { entries = 0, seen = {}, truncated = false }
  stats.estimatedBytes = EstimateSize(db, estimate)
  stats.estimateTruncated = estimate.truncated
  return stats
end

local function CreateRow(frame, index)
  local row = {}
  row.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.label:SetPoint("TOPLEFT", 16, -(78 + (index - 1) * ROW_HEIGHT))
  row.label:SetWidth(330)
  row.label:SetJustifyH("LEFT")

  row.value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.value:SetPoint("TOPRIGHT", -16, -(78 + (index - 1) * ROW_HEIGHT))
  row.value:SetWidth(290)
  row.value:SetJustifyH("RIGHT")
  return row
end

function XPTooltip:CreateDiagnosticsUI()
  if self.diagnosticsUI then
    return self.diagnosticsUI
  end

  local frame = CreateBackdropFrame(UIParent, "AceM2L2DiagnosticsFrame")
  frame:SetSize(680, 680)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function()
    pcall(frame.StopMovingOrSizing, frame)
  end)
  self:StylePanel(frame, "canvas")
  frame:Hide()

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText("Kill Story Data")

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetWidth(500)
  subtitle:SetJustifyH("LEFT")

  local refresh = CreateTextButton(frame, "Refresh", 80, 24)
  refresh:SetPoint("TOPRIGHT", -104, -10)
  refresh:SetScript("OnClick", function()
    pcall(self.RefreshDiagnosticsUI, self)
  end)

  local close = CreateTextButton(frame, "X", 24, 24)
  close:SetPoint("TOPRIGHT", -6, -10)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  local clearHeatmap = CreateTextButton(frame, "Clear heatmap", 120, 24)
  clearHeatmap:SetPoint("BOTTOMLEFT", 16, 42)
  clearHeatmap:SetScript("OnClick", function()
    if type(self.RequestClearHeatmaps) == "function" then
      pcall(self.RequestClearHeatmaps, self)
    end
  end)

  local note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  note:SetPoint("BOTTOMLEFT", 16, 18)
  note:SetPoint("BOTTOMRIGHT", -16, 18)
  note:SetJustifyH("LEFT")
  note:SetText("Mob, quest, death and heatmap caps are per character and per client. "
    .. "Heatmap cells and deaths use separate stores.")

  frame.rows = {}
  for index = 1, ROW_COUNT do
    frame.rows[index] = CreateRow(frame, index)
  end
  frame.title = title
  frame.subtitle = subtitle
  self.diagnosticsUI = frame

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

  frame:SetScript("OnShow", function()
    pcall(self.RefreshDiagnosticsUI, self)
  end)
  return frame
end

function XPTooltip:RefreshDiagnosticsUI()
  local frame = self.diagnosticsUI
  if not frame then
    return
  end
  local stats = self:GetDataStats()
  local theme = self:GetTheme()

  if frame.title then
    frame.title:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
  end
  if frame.subtitle then
    frame.subtitle:SetText(
      stats.client .. " (project " .. tostring(stats.projectID) .. ")   "
        .. stats.character .. (stats.realm ~= "" and (" - " .. stats.realm) or "")
    )
    frame.subtitle:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end

  local rows = {
    { "Mobs tracked", LimitText(stats.mobs, stats.maxMobs) },
    { "Quests tracked", LimitText(stats.quests, stats.maxQuests) },
    { "Deaths stored", LimitText(stats.deaths, stats.maxDeaths) },
    { "Respawn NPCs", LimitText(stats.respawnNpcs, stats.maxRespawnNpcs) },
    { "Respawn samples", LimitText(stats.respawnSamples, stats.maxRespawnNpcs * stats.maxRespawnSamples) },
    { "Heatmap zones", LimitText(stats.heatmapZones, stats.maxHeatmapZones) },
    { "Heatmap cells", FormatNumber(stats.heatmapCells) },
    { "Heatmap collection", stats.heatmapEnabled and "On" or "Off" },
    { "Heatmap bytes", FormatBytes(stats.estimatedHeatmapBytes) },
    { "Instances", LimitText(stats.instances, stats.maxInstances) },
    { "Instance kills", FormatNumber(stats.instanceKills) },
    { "Level records", LimitText(stats.levelRecords, stats.maxLevelRecords) },
    { "Rate samples", LimitText(stats.rateSamples, stats.maxRateSamples) },
    { "Mob contexts", LimitText(stats.contexts, stats.mobs * stats.maxContexts) },
    { "Calibration entries", FormatNumber(stats.calibrationEntries) },
    { "Tracked entries", FormatNumber(stats.totalTracked) },
    {
      "Estimated size",
      FormatBytes(stats.estimatedBytes) .. (stats.estimateTruncated and " (partial)" or ""),
    },
  }

  for index, row in ipairs(frame.rows or {}) do
    local item = rows[index]
    if item then
      row.label:SetText(item[1])
      row.label:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
      row.value:SetText(item[2])
      row.value:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
      row.label:Show()
      row.value:Show()
    else
      row.label:Hide()
      row.value:Hide()
    end
  end
end

function XPTooltip:ToggleDiagnosticsUI()
  local frame = self:CreateDiagnosticsUI()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end
