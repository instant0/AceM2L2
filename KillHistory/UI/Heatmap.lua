--[[---------------------------------------------------------------------------------
  KillHistory/UI/Heatmap.lua
  Zone kill heatmap panel, 16x16 cell grid, zone pager, legend, and map art.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local floor, min, max = math.floor, math.min, math.max
local CreateBackdropFrame = UI.CreateBackdropFrame
local CreateTextButton = UI.CreateTextButton
local FormatNumber = Util.FormatNumber

local GRID_SIZE = 16
local GRID_CELLS = GRID_SIZE * GRID_SIZE

--[[--------------------------------------------------------------------------------
  Defensive readers
------------------------------------------------------------------------------------]]

local function ZoneKey(zone)
  if type(zone) ~= "table" then
    return nil
  end
  local key = zone.key
  if key == nil then
    key = zone.mapID
  end
  if key == nil then
    return nil
  end
  return tostring(key)
end

local function ReadZones(module)
  local zones = {}
  if type(module.GetHeatmapZones) ~= "function" then
    return zones
  end
  local ok, result = pcall(module.GetHeatmapZones, module)
  if not ok or type(result) ~= "table" then
    return zones
  end
  for _, zone in ipairs(result) do
    if type(zone) == "table" and ZoneKey(zone) then
      zones[#zones + 1] = zone
    end
  end
  return zones
end

local function SupportsMapPosition(module)
  if type(module.Supports) ~= "function" then
    return true
  end
  local ok, value = pcall(module.Supports, module, "hasMapPosition")
  if not ok then
    return true
  end
  return value == true
end

local function ReadMapID(module)
  if type(module.GetMapID) ~= "function" then
    return 0
  end
  local ok, mapID = pcall(module.GetMapID, module)
  if not ok then
    return 0
  end
  return tonumber(mapID) or 0
end

local function ReadMapName(module, mapID)
  if type(module.GetMapName) == "function" then
    local ok, name = pcall(module.GetMapName, module, mapID)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return "Map " .. tostring(mapID)
end

local function Color(texture, color, alpha)
  if not texture or type(color) ~= "table" then
    return
  end
  texture:SetColorTexture(color[1] or 0, color[2] or 0, color[3] or 0, alpha or color[4] or 1)
end

--[[--------------------------------------------------------------------------------
  Panel construction
------------------------------------------------------------------------------------]]

function XPTooltip:CreateHeatmapPanel(frame)
  local panel = CreateBackdropFrame(frame)
  panel:SetPoint("TOPLEFT", 16, -90)
  panel:SetPoint("BOTTOMRIGHT", -16, 40)
  self:StylePanel(panel, "panel")
  panel.xpTooltipKind = "panel"
  frame.panels[#frame.panels + 1] = panel
  panel:Hide()

  local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 12, -10)
  header:SetText("Heatmap")

  local selector = CreateFrame("Frame", nil, panel)
  selector:SetPoint("TOPLEFT", 12, -38)
  selector:SetPoint("TOPRIGHT", -12, -38)
  selector:SetHeight(24)

  local previousButton = CreateTextButton(selector, "<", 26, 22)
  previousButton:SetPoint("LEFT", 0, 0)
  previousButton:SetScript("OnClick", function()
    pcall(self.SelectHeatmapZone, self, -1)
  end)

  local zoneLabel = selector:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  zoneLabel:SetPoint("LEFT", previousButton, "RIGHT", 10, 0)
  zoneLabel:SetWidth(480)
  zoneLabel:SetJustifyH("LEFT")
  zoneLabel:SetText("")

  local nextButton = CreateTextButton(selector, ">", 26, 22)
  nextButton:SetPoint("LEFT", zoneLabel, "RIGHT", 10, 0)
  nextButton:SetScript("OnClick", function()
    pcall(self.SelectHeatmapZone, self, 1)
  end)

  local currentButton = CreateTextButton(selector, "Current zone", 110, 22)
  currentButton:SetPoint("RIGHT", 0, 0)
  currentButton:SetScript("OnClick", function()
    -- A nil selection makes RefreshHeatmap fall back to the current map,
    -- then to the newest tracked zone when the current map is not tracked.
    self.heatmapZoneKey = nil
    pcall(self.RefreshHeatmap, self)
  end)

  local grid = CreateBackdropFrame(panel)
  grid:SetPoint("TOPLEFT", 12, -72)
  grid:SetPoint("BOTTOMRIGHT", -12, 34)
  self:StylePanel(grid, "elevated")
  grid.xpTooltipKind = "elevated"
  frame.panels[#frame.panels + 1] = grid

  local art = grid:CreateTexture(nil, "BACKGROUND", nil, 1)
  art:SetAllPoints()
  art:Hide()

  local cells = {}
  for index = 1, GRID_CELLS do
    local cell = grid:CreateTexture(nil, "ARTWORK")
    cell:SetColorTexture(0, 0, 0, 0)
    cell:Hide()
    cells[index] = cell
  end

  local noData = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  noData:SetPoint("CENTER", panel, "CENTER", 0, -10)
  noData:SetText("No heatmap data")
  noData:Hide()

  local artCaption = grid:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  artCaption:SetPoint("CENTER", grid, "CENTER", 0, 0)
  artCaption:SetText("")
  artCaption:Hide()

  local legend = CreateFrame("Frame", nil, panel)
  legend:SetPoint("BOTTOMLEFT", 12, 8)
  legend:SetPoint("BOTTOMRIGHT", -12, 8)
  legend:SetHeight(18)

  local legendRange = legend:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  legendRange:SetPoint("LEFT", 0, 0)
  legendRange:SetText("Low -> High")

  local legendDetail = legend:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  legendDetail:SetPoint("RIGHT", 0, 0)
  legendDetail:SetJustifyH("RIGHT")
  legendDetail:SetText("")

  local heatmap = {
    panel = panel,
    header = header,
    selector = selector,
    previousButton = previousButton,
    nextButton = nextButton,
    zoneLabel = zoneLabel,
    currentButton = currentButton,
    grid = grid,
    art = art,
    artCaption = artCaption,
    cells = cells,
    noData = noData,
    legend = legend,
    legendRange = legendRange,
    legendDetail = legendDetail,
  }

  frame.heatmap = heatmap
  if self.ui then
    self.ui.heatmap = heatmap
  end
  return heatmap
end

--[[--------------------------------------------------------------------------------
  Refresh
------------------------------------------------------------------------------------]]

function XPTooltip:RefreshHeatmap()
  if not self.ui or not self.ui.heatmap then
    return
  end
  local heatmap = self.ui.heatmap
  local panel = heatmap.panel
  if not panel then
    return
  end

  local theme = self:GetTheme()
  local zones = ReadZones(self)
  local supported = SupportsMapPosition(self)

  if #zones == 0 then
    heatmap.noData:SetText(supported and "No heatmap data" or "Heatmap unavailable on this client.")
    heatmap.noData:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
    heatmap.noData:Show()
    heatmap.selector:Hide()
    heatmap.grid:Hide()
    heatmap.legend:Hide()
    if heatmap.art then
      heatmap.art:Hide()
    end
    if heatmap.artCaption then
      heatmap.artCaption:Hide()
    end
    return
  end

  local selected
  local selectedKey = self.heatmapZoneKey
  if selectedKey ~= nil then
    for _, zone in ipairs(zones) do
      if ZoneKey(zone) == selectedKey then
        selected = zone
        break
      end
    end
  end
  if not selected then
    local currentMapID = ReadMapID(self)
    if currentMapID > 0 then
      for _, zone in ipairs(zones) do
        if tonumber(zone.mapID) == currentMapID then
          selected = zone
          break
        end
      end
    end
  end
  if not selected then
    selected = zones[1]
  end
  self.heatmapZoneKey = ZoneKey(selected)

  local zoneName = ReadMapName(self, selected.mapID)
  local total = tonumber(selected.total) or 0

  heatmap.noData:Hide()
  heatmap.selector:Show()
  heatmap.grid:Show()
  heatmap.legend:Show()

  heatmap.zoneLabel:SetText(zoneName .. "  -  " .. FormatNumber(total) .. " kills")
  heatmap.zoneLabel:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
  heatmap.legendRange:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  heatmap.legendDetail:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])

  local cellsData = type(selected.cells) == "table" and selected.cells or {}
  local counts = {}
  for index = 1, GRID_CELLS do
    local count = tonumber(cellsData[index]) or 0
    if count < 0 then
      count = 0
    end
    counts[index] = count
  end

  local maximum = 1
  for index = 1, GRID_CELLS do
    if counts[index] > maximum then
      maximum = counts[index]
    end
  end

  -- Measure the grid frame first; fall back to the panel (and then the window)
  -- because anchored frames report zero size before the first layout pass.
  local availableWidth = heatmap.grid:GetWidth() or 0
  local availableHeight = heatmap.grid:GetHeight() or 0
  if availableWidth <= 0 then
    availableWidth = (panel:GetWidth() or 0) - 24
  end
  if availableHeight <= 0 then
    availableHeight = (panel:GetHeight() or 0) - 106
  end
  if availableWidth <= 0 and self.ui then
    availableWidth = (self.ui:GetWidth() or 0) - 24
  end
  if availableHeight <= 0 and self.ui then
    availableHeight = (self.ui:GetHeight() or 0) - 106
  end
  if availableWidth <= 0 then
    availableWidth = 944
  end
  if availableHeight <= 0 then
    availableHeight = 444
  end

  local side = max(GRID_SIZE, min(availableWidth, availableHeight))
  local stride = max(1, floor(side / GRID_SIZE))
  local cellSize = max(1, stride - 1)
  local extent = stride * GRID_SIZE
  local offsetX = max(0, floor((availableWidth - extent) / 2))
  local offsetY = max(0, floor((availableHeight - extent) / 2))

  local accent = theme.accent
  local empty = theme.elevated or theme.panel or theme.border
  for index = 1, GRID_CELLS do
    local cell = heatmap.cells[index]
    if cell then
      local row = floor((index - 1) / GRID_SIZE)
      local col = (index - 1) % GRID_SIZE
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", heatmap.grid, "TOPLEFT",
        offsetX + col * stride, -(offsetY + row * stride))
      cell:SetSize(cellSize, cellSize)
      if counts[index] > 0 then
        local alpha = 0.10 + 0.70 * (counts[index] / maximum)
        Color(cell, accent, alpha)
      else
        Color(cell, empty, 0.35)
      end
      cell:Show()
    end
  end

  heatmap.legendDetail:SetText(
    "Max cell: " .. FormatNumber(maximum) .. "   Zone total: " .. FormatNumber(total)
  )

  local texture
  if type(self.GetHeatmapMapTexture) == "function" then
    local ok, value = pcall(self.GetHeatmapMapTexture, self, selected.mapID)
    if ok then
      texture = value
    end
  end

  local applied = false
  if texture and heatmap.art then
    applied = pcall(heatmap.art.SetTexture, heatmap.art, texture)
    if applied and heatmap.art.SetAlpha then
      pcall(heatmap.art.SetAlpha, heatmap.art, 0.55)
    end
  end
  if heatmap.art then
    heatmap.art:SetShown(applied)
  end
  if heatmap.artCaption then
    if applied then
      heatmap.artCaption:Hide()
    else
      heatmap.artCaption:SetText("Map art unavailable - " .. zoneName)
      heatmap.artCaption:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
      heatmap.artCaption:Show()
    end
  end
end

function XPTooltip:SelectHeatmapZone(delta)
  if not self.ui or not self.ui.heatmap then
    return
  end
  local zones = ReadZones(self)
  if #zones == 0 then
    return
  end

  local step = floor(tonumber(delta) or 1)
  if step == 0 then
    step = 1
  end
  local current = 1
  for index, zone in ipairs(zones) do
    if ZoneKey(zone) == self.heatmapZoneKey then
      current = index
      break
    end
  end

  local nextIndex = ((current - 1 + step) % #zones) + 1
  self.heatmapZoneKey = ZoneKey(zones[nextIndex])
  self:RefreshHeatmap()
end

--[[--------------------------------------------------------------------------------
  Map art
------------------------------------------------------------------------------------]]

function XPTooltip:GetHeatmapMapTexture(mapID)
  local id = tonumber(mapID)
  if not id then
    return nil
  end

  -- The whole probe runs inside pcall: some clients expose lazy/secret map-art
  -- structures whose field access can throw even when the API itself exists.
  local ok, texture = pcall(function()
    if C_Map and type(C_Map.GetMapArtLayers) == "function" then
      local layersOK, layers = pcall(C_Map.GetMapArtLayers, id)
      if layersOK and type(layers) == "table" then
        local firstOK, first = pcall(function()
          return layers[1]
        end)
        if firstOK and type(first) == "table" then
          local valueOK, fileDataID = pcall(function()
            return first.fileDataID
          end)
          if valueOK and type(fileDataID) == "number" then
            return fileDataID
          end
        end
      end
    end

    if C_Map and type(C_Map.GetMapArtLayerTextures) == "function" then
      local texturesOK, textures = pcall(C_Map.GetMapArtLayerTextures, id, 1)
      if texturesOK and type(textures) == "table" then
        local countOK, count = pcall(function()
          return #textures
        end)
        if countOK and type(count) == "number" then
          for index = 1, count do
            local valueOK, value = pcall(function()
              return textures[index]
            end)
            if valueOK and type(value) == "number" then
              return value
            end
          end
        end
      end
    end

    if type(GetMapInfo) == "function" then
      local infoOK, legacy = pcall(GetMapInfo, id)
      if infoOK and (type(legacy) == "string" or type(legacy) == "number") then
        if legacy ~= "" then
          return legacy
        end
      end
    end

    return nil
  end)

  if ok then
    return texture
  end
  return nil
end

--[[--------------------------------------------------------------------------------
  Theme hook
------------------------------------------------------------------------------------]]

-- The cell colors are refreshed on zone changes and tab refreshes. ApplyTheme is
-- only responsible for panel chrome, so hook it to recolor the grid on a theme
-- change without editing another module.
if type(hooksecurefunc) == "function" then
  pcall(hooksecurefunc, XPTooltip, "ApplyTheme", function(module)
    if module and type(module.RefreshHeatmap) == "function" then
      pcall(module.RefreshHeatmap, module)
    end
  end)
elseif type(XPTooltip.ApplyTheme) == "function" and not XPTooltip.heatmapThemeHooked then
  XPTooltip.heatmapThemeHooked = true
  local applyTheme = XPTooltip.ApplyTheme
  XPTooltip.ApplyTheme = function(module, ...)
    local ok, err = pcall(applyTheme, module, ...)
    if module and type(module.RefreshHeatmap) == "function" then
      pcall(module.RefreshHeatmap, module)
    end
    if not ok then
      error(err, 0)
    end
  end
end
