--[[---------------------------------------------------------------------------------
  KillHistory/UI/Heatmap.lua
  Zone kill heatmap panel, 32x32 cell grid, zone pager, legend, and map art.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local floor, min, max = math.floor, math.min, math.max
local ceil = math.ceil
local CreateBackdropFrame = UI.CreateBackdropFrame
local CreateTextButton = UI.CreateTextButton
local FormatNumber = Util.FormatNumber

local GRID_SIZE = 32
local GRID_CELLS = GRID_SIZE * GRID_SIZE
local MAX_ART_LAYERS = 8
local MAX_ART_TILES = 256

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

local function ReadMapArtLayers(mapID)
  local id = tonumber(mapID)
  if not id or not C_Map or type(C_Map.GetMapArtLayers) ~= "function" then
    return nil
  end
  local ok, layers = pcall(C_Map.GetMapArtLayers, id)
  if not ok or type(layers) ~= "table" then
    return nil
  end
  local countOK, count = pcall(function()
    return #layers
  end)
  if not countOK or type(count) ~= "number" then
    return nil
  end

  local result = {}
  for layerIndex = 1, min(count, MAX_ART_LAYERS) do
    local layerOK, layer = pcall(function()
      return layers[layerIndex]
    end)
    if layerOK and type(layer) == "table" then
      local layerWidth = tonumber(layer.layerWidth) or 0
      local layerHeight = tonumber(layer.layerHeight) or 0
      local tileWidth = tonumber(layer.tileWidth) or 0
      local tileHeight = tonumber(layer.tileHeight) or 0
      if layerWidth > 0 and layerHeight > 0 and tileWidth > 0 and tileHeight > 0
        and type(C_Map.GetMapArtLayerTextures) == "function" then
        local texturesOK, textures = pcall(C_Map.GetMapArtLayerTextures, id, layerIndex)
        if texturesOK and type(textures) == "table" then
          local texturesCountOK, texturesCount = pcall(function()
            return #textures
          end)
          if texturesCountOK and type(texturesCount) == "number" and texturesCount > 0 then
            result[#result + 1] = {
              index = layerIndex,
              width = layerWidth,
              height = layerHeight,
              tileWidth = tileWidth,
              tileHeight = tileHeight,
              textures = textures,
            }
          end
        end
      end
    end
  end
  if #result == 0 then
    return nil
  end
  return result
end

local function HideHeatmapArt(heatmap)
  heatmap.artKey = nil
  heatmap.artReady = false
  for _, tile in ipairs(heatmap.artTiles or {}) do
    if tile and tile.Hide then
      tile:Hide()
    end
  end
end

local function GetArtTile(heatmap, index, layerIndex)
  local tile = heatmap.artTiles[index]
  if not tile then
    tile = heatmap.grid:CreateTexture(nil, "BACKGROUND")
    heatmap.artTiles[index] = tile
  end
  if tile.SetDrawLayer then
    -- Keep map art above the grid backdrop but below the ARTWORK heat cells.
    -- Negative BACKGROUND sublevels sit behind the frame backdrop and give the
    -- map a faded blue tint.
    pcall(tile.SetDrawLayer, tile, "BACKGROUND", min(layerIndex, 7))
  end
  if tile.SetAlpha then
    pcall(tile.SetAlpha, tile, 1.0)
  end
  if tile.SetVertexColor then
    pcall(tile.SetVertexColor, tile, 1.0, 1.0, 1.0)
  end
  return tile
end

local function BuildHeatmapArt(heatmap, mapID, side, offsetX, offsetY)
  local key = tostring(mapID) .. ":" .. tostring(side) .. ":"
    .. tostring(offsetX) .. ":" .. tostring(offsetY)
  if heatmap.artKey == key and heatmap.artReady then
    return true
  end

  local layers = ReadMapArtLayers(mapID)
  if not layers then
    HideHeatmapArt(heatmap)
    return false
  end

  local tileIndex = 0
  for _, layer in ipairs(layers) do
    local columns = ceil(layer.width / layer.tileWidth)
    local rows = ceil(layer.height / layer.tileHeight)
    if columns > 0 and rows > 0 then
      local scaleX = side / layer.width
      local scaleY = side / layer.height
      for column = 1, columns do
        for row = 1, rows do
          local texture = layer.textures[(row - 1) * columns + column]
          if texture ~= nil and tileIndex < MAX_ART_TILES then
            tileIndex = tileIndex + 1
            local tile = GetArtTile(heatmap, tileIndex, layer.index)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", heatmap.grid, "TOPLEFT",
              offsetX + (column - 1) * layer.tileWidth * scaleX,
              -(offsetY + (row - 1) * layer.tileHeight * scaleY))
            tile:SetSize(
              max(1, layer.tileWidth * scaleX),
              max(1, layer.tileHeight * scaleY)
            )
            tile:SetTexture(texture)
            tile:Show()
          end
        end
      end
    end
  end

  for index = tileIndex + 1, #heatmap.artTiles do
    local tile = heatmap.artTiles[index]
    if tile and tile.Hide then
      tile:Hide()
    end
  end

  if tileIndex == 0 then
    heatmap.artKey = nil
    heatmap.artReady = false
    return false
  end
  heatmap.artKey = key
  heatmap.artReady = true
  return true
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

  local artTiles = {}

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
    artTiles = artTiles,
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
    HideHeatmapArt(heatmap)
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
        local alpha = 0.30 + 0.70 * (counts[index] / maximum)
        Color(cell, accent, alpha)
        cell:Show()
      else
        -- Empty cells must stay hidden so the zone map art remains visible.
        cell:Hide()
      end
    end
  end

  heatmap.legendDetail:SetText(
    "Max cell: " .. FormatNumber(maximum) .. "   Zone total: " .. FormatNumber(total)
  )

  local applied = false
  local ok, result = pcall(BuildHeatmapArt, heatmap, selected.mapID, extent, offsetX, offsetY)
  if ok then
    applied = result == true
  else
    HideHeatmapArt(heatmap)
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

local function TextureValue(value)
  if type(value) == "number" then
    return value
  end
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

local function LayerTexture(layer)
  if type(layer) ~= "table" then
    return nil
  end
  local fields = { "fileDataID", "textureFileID", "texture", "fileID" }
  for index = 1, #fields do
    local ok, value = pcall(function()
      return layer[fields[index]]
    end)
    if ok then
      local texture = TextureValue(value)
      if texture then
        return texture
      end
    end
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
