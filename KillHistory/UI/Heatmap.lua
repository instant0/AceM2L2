--[[---------------------------------------------------------------------------------
  KillHistory/UI/Heatmap.lua
  Zone kill heatmap panel, 64x64 cell grid, zone pager, legend, and map art.
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

local GRID_SIZE = math.floor(tonumber(XPTooltip.HEATMAP_GRID_SIZE) or 64)
if GRID_SIZE < 1 then
  GRID_SIZE = 64
end
local GRID_CELLS = GRID_SIZE * GRID_SIZE
local MAX_ART_LAYERS = 8
local MAX_ART_TILES = 256
local MAX_OVERLAY_TILES = 600

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

-- A heatmap needs more than one colour. The ramp moves from the theme accent
-- (cool/low) through gold (mid) to red (high), and alpha rises with it. The
-- intensity setting reshapes the floor and curve so higher values increase
-- contrast instead of clamping every cell to fully opaque.
local HEAT_MID_COLOR = { 1.00, 0.82, 0.15 }
local HEAT_HIGH_COLOR = { 1.00, 0.10, 0.03 }
local HEAT_LOW_FALLBACK = { 0.25, 0.55, 0.95 }
local WARM_LOW_COLOR = { 1.00, 0.70, 0.12 }
local WARM_MID_COLOR = { 1.00, 0.32, 0.03 }
local WARM_HIGH_COLOR = { 0.78, 0.02, 0.02 }
local GRADIENT_STEPS = 15

local function Clamp01(value)
  if value < 0 then
    return 0
  elseif value > 1 then
    return 1
  end
  return value
end

local function Lerp(from, to, t)
  return from + (to - from) * t
end

local function LerpColor(from, to, t)
  return {
    Lerp(from[1] or 0, to[1] or 0, t),
    Lerp(from[2] or 0, to[2] or 0, t),
    Lerp(from[3] or 0, to[3] or 0, t),
  }
end

local function HeatRamp(intensity)
  local value = tonumber(intensity) or 1
  value = max(0.5, min(2, value))
  local floor = 0.55 - 0.20 * value          -- 0.45 at 50%, 0.35 at 100%, 0.15 at 200%
  local gamma = 0.90 - 0.20 * (value - 1)    -- 1.10, 0.90, 0.70
  return floor, gamma
end

local function HeatPalette(warm, accent)
  if warm then
    return WARM_LOW_COLOR, WARM_MID_COLOR, WARM_HIGH_COLOR
  end
  -- Keep the low end cool so every theme gets a real hue change. A gold or red
  -- theme accent would otherwise overlap the mid/high stops.
  local low = accent
  if type(low) ~= "table" or (low[3] or 0) < (low[1] or 0) then
    low = HEAT_LOW_FALLBACK
  end
  return low, HEAT_MID_COLOR, HEAT_HIGH_COLOR
end

-- Returns { r, g, b, a }. Kept public so offline tests can verify the ramp
-- without reading textures from the UI.
local function HeatColor(count, maximum, intensity, warm, accent)
  local value = tonumber(count) or 0
  local top = tonumber(maximum) or 0
  if value <= 0 or top <= 0 then
    return { 0, 0, 0, 0 }
  end
  local ratio = Clamp01(value / top)
  local floor, gamma = HeatRamp(intensity)
  local t = ratio ^ gamma
  local low, mid, high = HeatPalette(warm, accent)
  local color
  if t <= 0.5 then
    color = LerpColor(low, mid, t * 2)
  else
    color = LerpColor(mid, high, (t - 0.5) * 2)
  end
  return { color[1], color[2], color[3], min(1, floor + (1 - floor) * t) }
end

XPTooltip.GetHeatColor = HeatColor
XPTooltip.HeatPalette = HeatPalette

local function ApplyLegendGradient(heatmap, low, mid, high)
  local swatches = heatmap.gradientSwatches
  if type(swatches) ~= "table" or #swatches == 0 then
    return
  end
  local steps = #swatches
  for index = 1, steps do
    local position = steps > 1 and (index - 1) / (steps - 1) or 1
    local color
    if position <= 0.5 then
      color = LerpColor(low, mid, position * 2)
    else
      color = LerpColor(mid, high, (position - 0.5) * 2)
    end
    local swatch = swatches[index]
    if swatch and swatch.SetColorTexture then
      swatch:SetColorTexture(color[1], color[2], color[3], 1)
    end
  end
end


local function GetHeatCell(heatmap, index)
  local cell = heatmap.cells[index]
  if cell then
    return cell
  end
  cell = heatmap.grid:CreateTexture(nil, "ARTWORK")
  cell:SetColorTexture(0, 0, 0, 0)
  cell:Hide()
  heatmap.cells[index] = cell
  heatmap.cellCount = (heatmap.cellCount or 0) + 1
  return cell
end

local function HideHeatCells(heatmap)
  for _, cell in pairs(heatmap.cells or {}) do
    if cell and cell.Hide then
      cell:Hide()
    end
  end
  heatmap.renderedCounts = {}
  heatmap.renderedZoneKey = nil
  heatmap.renderedGeometryKey = nil
  heatmap.renderedThemeKey = nil
  heatmap.renderedMaximum = 0
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

local function TextureKey(value)
  if _G.issecretvalue and _G.issecretvalue(value) then
    return "?"
  end
  local kind = type(value)
  if kind == "number" or kind == "string" then
    return tostring(value)
  end
  return "?"
end

-- MapArtID overlay entries are identified by their 13-bit width, height, and
-- offset tuple. This is the same key used by WorldMapOverlay overlays and keeps
-- our generated data compact.
local function OverlayKey(width, height, offsetX, offsetY)
  return width * 2 ^ 39 + height * 2 ^ 26 + offsetX * 2 ^ 13 + offsetY
end

-- Blizzard's explored-map data is a set of overlay textures drawn above the
-- base zone art once the character has discovered those areas. The API returns
-- the overlay bounds and texture IDs, not a second fully-painted zone map.
local function ReadExploredMapTextures(mapID)
  local id = tonumber(mapID)
  local api = _G.C_MapExplorationInfo
  if not id or type(api) ~= "table"
    or type(api.GetExploredMapTextures) ~= "function" then
    return nil, ""
  end

  local ok, overlays = pcall(api.GetExploredMapTextures, id)
  if not ok or type(overlays) ~= "table" then
    return nil, ""
  end
  local countOK, count = pcall(function()
    return #overlays
  end)
  if not countOK or type(count) ~= "number" then
    return nil, ""
  end

  local result = {}
  local signature = {}
  for index = 1, count do
    local info = overlays[index]
    if type(info) == "table" then
      local infoOK, normalized, normalizedSignature = pcall(function()
        if info.isShownByMouseOver == true then
          return nil
        end
        local width = tonumber(info.textureWidth) or 0
        local height = tonumber(info.textureHeight) or 0
        local offsetX = tonumber(info.offsetX) or 0
        local offsetY = tonumber(info.offsetY) or 0
        local textures = info.fileDataIDs
        local textureCount = 0
        if type(textures) == "table" then
          local texturesOK, texturesCount = pcall(function()
            return #textures
          end)
          if texturesOK and type(texturesCount) == "number" then
            textureCount = texturesCount
          end
        end
        if width <= 0 or height <= 0 or textureCount <= 0 then
          return nil
        end
        local firstTexture = textures[1]
        local lastTexture = textures[textureCount]
        local drawOnTop = false
        local topOK, topValue = pcall(function()
          return info.isDrawOnTopLayer == true
        end)
        if topOK then
          drawOnTop = topValue
        end
        return {
          width = width,
          height = height,
          offsetX = offsetX,
          offsetY = offsetY,
          textures = textures,
          drawOnTop = drawOnTop,
          key = OverlayKey(width, height, offsetX, offsetY),
        }, string.format(
          "%d:%d:%d:%d:%d:%s:%s", width, height, offsetX, offsetY,
          textureCount, TextureKey(firstTexture), TextureKey(lastTexture)
        )
      end)
      if infoOK and type(normalized) == "table" then
        result[#result + 1] = normalized
        signature[#signature + 1] = normalizedSignature
      end
    end
  end

  if #result == 0 then
    return nil, ""
  end
  return result, table.concat(signature, "|")
end

local function ParseFileDataIDs(value)
  local result = {}
  if type(value) == "string" then
    for id in value:gmatch("%d+") do
      local number = tonumber(id)
      if number then
        result[#result + 1] = number
      end
    end
  end
  return result
end

-- Full overlay data generated from the official WorldMapOverlay /
-- WorldMapOverlayTile client tables. The runtime GetExploredMapTextures API only
-- returns the character's explored subset; this data fills in everything else.
local function ReadStaticMapOverlays(mapID)
  local id = tonumber(mapID)
  if not id or not C_Map or type(C_Map.GetMapArtID) ~= "function" then
    return nil, ""
  end
  local artOK, artID = pcall(C_Map.GetMapArtID, id)
  artID = tonumber(artID)
  if not artOK or not artID then
    return nil, ""
  end

  local projectID = tonumber(XPTooltip.projectID)
  if not projectID and type(XPTooltip.GetProjectID) == "function" then
    local projectOK, value = pcall(XPTooltip.GetProjectID, XPTooltip)
    if projectOK then
      projectID = tonumber(value)
    end
  end
  local projectData = projectID
    and XPTooltip.MapOverlayData
    and XPTooltip.MapOverlayData[projectID]
  local entries = projectData and projectData[artID]
  if type(entries) ~= "table" then
    return nil, tostring(artID)
  end

  local cache = XPTooltip.mapOverlayCache
  if type(cache) ~= "table" then
    cache = {}
    XPTooltip.mapOverlayCache = cache
  end
  local cacheKey = tostring(projectID) .. ":" .. tostring(artID)
  local cached = cache[cacheKey]
  if cached then
    return cached.entries, cached.signature
  end

  local result = {}
  local signature = {}
  for index = 1, #entries do
    local entry = entries[index]
    if type(entry) == "table" then
      local width = tonumber(entry[1]) or 0
      local height = tonumber(entry[2]) or 0
      local offsetX = tonumber(entry[3]) or 0
      local offsetY = tonumber(entry[4]) or 0
      local textures = ParseFileDataIDs(entry[5])
      if width > 0 and height > 0 and #textures > 0 then
        result[#result + 1] = {
          width = width,
          height = height,
          offsetX = offsetX,
          offsetY = offsetY,
          textures = textures,
          key = OverlayKey(width, height, offsetX, offsetY),
        }
        signature[#signature + 1] = string.format(
          "%d:%d:%d:%d:%d", width, height, offsetX, offsetY, #textures
        )
      end
    end
  end

  if #result == 0 then
    return nil, tostring(artID)
  end
  local resultSignature = tostring(artID) .. ":" .. tostring(#result) .. ":"
    .. table.concat(signature, "|")
  cache[cacheKey] = {
    entries = result,
    signature = resultSignature,
  }
  return result, resultSignature
end

local function NextPowerOfTwo(value)
  local size = 16
  while size < value do
    size = size * 2
  end
  return size
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

local function GetArtTile(heatmap, index, layerIndex, isOverlay)
  local tile = heatmap.artTiles[index]
  if not tile then
    tile = heatmap.grid:CreateTexture(nil, "BACKGROUND")
    heatmap.artTiles[index] = tile
  end
  if tile.SetDrawLayer then
    -- Keep map art above the grid backdrop but below the ARTWORK heat cells.
    -- Reserve BACKGROUND sublevel 7 for explored overlays; negative
    -- BACKGROUND sublevels sit behind the frame backdrop and wash the map out.
    local subLevel = isOverlay and 7 or min(layerIndex, 6)
    pcall(tile.SetDrawLayer, tile, "BACKGROUND", subLevel)
  end
  if tile.SetAlpha then
    pcall(tile.SetAlpha, tile, 1.0)
  end
  if tile.SetVertexColor then
    pcall(tile.SetVertexColor, tile, 1.0, 1.0, 1.0)
  end
  return tile
end

local function RenderOverlayTiles(heatmap, tileIndex, overlay, baseLayer,
  side, offsetX, offsetY, remaining)
  if remaining <= 0 then
    return tileIndex, remaining
  end
  local scaleX = side / baseLayer.width
  local scaleY = side / baseLayer.height
  local tileWidth = baseLayer.tileWidth
  local tileHeight = baseLayer.tileHeight
  local columns = ceil(overlay.width / tileWidth)
  local rows = ceil(overlay.height / tileHeight)
  if columns <= 0 or rows <= 0 then
    return tileIndex, remaining
  end

  local used = 0
  for row = 1, rows do
    if used >= remaining then
      break
    end
    local pixelHeight = tileHeight
    if row == rows then
      pixelHeight = overlay.height - (rows - 1) * tileHeight
      if pixelHeight <= 0 then
        pixelHeight = tileHeight
      end
    end
    local fileHeight = NextPowerOfTwo(pixelHeight)
    local y = offsetY + (overlay.offsetY + (row - 1) * tileHeight) * scaleY

    for column = 1, columns do
      if used >= remaining then
        break
      end
      local texture = overlay.textures[(row - 1) * columns + column]
      if texture ~= nil then
        local pixelWidth = tileWidth
        if column == columns then
          pixelWidth = overlay.width - (columns - 1) * tileWidth
          if pixelWidth <= 0 then
            pixelWidth = tileWidth
          end
        end
        local fileWidth = NextPowerOfTwo(pixelWidth)
        used = used + 1
        tileIndex = tileIndex + 1
        local tile = GetArtTile(heatmap, tileIndex, 7, true)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", heatmap.grid, "TOPLEFT",
          offsetX + (overlay.offsetX + (column - 1) * tileWidth) * scaleX,
          -y)
        tile:SetSize(
          max(1, pixelWidth * scaleX),
          max(1, pixelHeight * scaleY)
        )
        tile:SetTexture(texture)
        if tile.SetTexCoord then
          pcall(tile.SetTexCoord, tile, 0, pixelWidth / fileWidth,
            0, pixelHeight / fileHeight)
        end
        tile:Show()
      end
    end
  end
  return tileIndex, remaining - used
end

local function BuildHeatmapArt(heatmap, mapID, side, offsetX, offsetY)
  local reveal = true
  if type(XPTooltip.GetSettings) == "function" then
    local settingsOK, settings = pcall(XPTooltip.GetSettings, XPTooltip)
    if settingsOK and type(settings) == "table"
      and settings.revealUnexplored == false then
      reveal = false
    end
  end

  local explored, exploredKey = ReadExploredMapTextures(mapID)
  local static, staticKey = nil, ""
  if reveal then
    static, staticKey = ReadStaticMapOverlays(mapID)
  end
  local key = tostring(mapID) .. ":" .. tostring(side) .. ":"
    .. tostring(offsetX) .. ":" .. tostring(offsetY) .. ":"
    .. (exploredKey or "") .. ":" .. (staticKey or "")
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

  if layers[1] then
    local baseLayer = layers[1]
    local exploredKeys = {}
    for _, overlay in ipairs(explored or {}) do
      if overlay.key then
        exploredKeys[overlay.key] = true
      end
    end

    local budget = MAX_OVERLAY_TILES

    -- Fill every overlay the character has not discovered from our generated
    -- full WorldMapOverlay data. Static first, official explored overlays last.
    if static then
      for _, overlay in ipairs(static) do
        if not exploredKeys[overlay.key] then
          tileIndex, budget = RenderOverlayTiles(
            heatmap, tileIndex, overlay, baseLayer, side,
            offsetX, offsetY, budget
          )
        end
      end
    end

    if explored then
      -- Draw normal explored overlays first, then overlays Blizzard marks as
      -- draw-on-top. Both groups sit above the static/base art and below heat
      -- cells.
      table.sort(explored, function(a, b)
        if a.drawOnTop ~= b.drawOnTop then
          return not a.drawOnTop
        end
        return false
      end)
      for _, overlay in ipairs(explored) do
        tileIndex, budget = RenderOverlayTiles(
          heatmap, tileIndex, overlay, baseLayer, side,
          offsetX, offsetY, budget
        )
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

  -- Cells are created lazily per used index. A full 64x64 grid would otherwise
  -- allocate 4,096 textures before a single kill is rendered.
  local cells = {}

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
  legendRange:SetText("Low")

  -- A segmented swatch bar keeps the gradient readable without relying on
  -- SetGradient, which differs between the supported clients.
  local gradientBar = CreateFrame("Frame", nil, legend)
  gradientBar:SetPoint("LEFT", legendRange, "RIGHT", 8, 0)
  gradientBar:SetSize(GRADIENT_STEPS * 9, 10)
  local gradientSwatches = {}
  for index = 1, GRADIENT_STEPS do
    local swatch = gradientBar:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", gradientBar, "TOPLEFT", (index - 1) * 9, 0)
    swatch:SetSize(9, 10)
    swatch:SetColorTexture(0, 0, 0, 0)
    gradientSwatches[index] = swatch
  end

  local legendHigh = legend:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  legendHigh:SetPoint("LEFT", gradientBar, "RIGHT", 8, 0)
  legendHigh:SetText("High")

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
    cellCount = 0,
    renderedCounts = {},
    renderedZoneKey = nil,
    renderedGeometryKey = nil,
    renderedThemeKey = nil,
    renderedMaximum = 0,
    noData = noData,
    legend = legend,
    legendRange = legendRange,
    legendHigh = legendHigh,
    gradientBar = gradientBar,
    gradientSwatches = gradientSwatches,
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
    HideHeatCells(heatmap)
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
  if heatmap.legendHigh then
    heatmap.legendHigh:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  heatmap.legendDetail:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])

  local cellsData = type(selected.cells) == "table" and selected.cells or {}
  local counts = {}
  local active = {}
  local maximum = 0
  for index = 1, GRID_CELLS do
    local count = tonumber(cellsData[index]) or 0
    if count ~= count or count < 0 then
      count = 0
    end
    if count > 0 then
      counts[index] = count
      active[#active + 1] = index
      if count > maximum then
        maximum = count
      end
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
  local gap = stride >= 8 and 1 or 0
  local cellSize = max(1, stride - gap)
  local extent = stride * GRID_SIZE
  local offsetX = max(0, floor((availableWidth - extent) / 2))
  local offsetY = max(0, floor((availableHeight - extent) / 2))

  local settings = self:GetSettings()
  local intensity = tonumber(settings and settings.heatmapIntensity) or 100
  intensity = max(50, min(200, intensity)) / 100
  local warm = settings and settings.heatmapWarmColors == true
  local accent = theme.accent or HEAT_LOW_FALLBACK
  local lowColor, midColor, highColor = HeatPalette(warm, accent)
  local accentKey = tostring(warm) .. ":" .. tostring(lowColor[1])
    .. ":" .. tostring(lowColor[2]) .. ":" .. tostring(lowColor[3])
    .. ":" .. tostring(intensity)
  ApplyLegendGradient(heatmap, lowColor, midColor, highColor)
  local zoneKey = ZoneKey(selected)
  local geometryKey = tostring(extent) .. ":" .. tostring(offsetX) .. ":"
    .. tostring(offsetY) .. ":" .. tostring(stride) .. ":" .. tostring(cellSize)
  local fullRebuild = heatmap.renderedZoneKey ~= zoneKey
    or heatmap.renderedGeometryKey ~= geometryKey
    or heatmap.renderedThemeKey ~= accentKey
  -- A new per-zone maximum changes every active cell's alpha, but not its
  -- position. Recolor in place instead of hiding and re-showing the whole cell
  -- pool, which happens whenever a cell sets a new high-water mark.
  local rescale = heatmap.renderedMaximum ~= maximum
  local denominator = maximum > 0 and maximum or 1

  if fullRebuild then
    for _, cell in pairs(heatmap.cells) do
      if cell and cell.Hide then
        cell:Hide()
      end
    end
    heatmap.renderedCounts = {}
    for _, index in ipairs(active) do
      local cell = GetHeatCell(heatmap, index)
      local row = floor((index - 1) / GRID_SIZE)
      local col = (index - 1) % GRID_SIZE
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", heatmap.grid, "TOPLEFT",
        offsetX + col * stride, -(offsetY + row * stride))
      cell:SetSize(cellSize, cellSize)
      local heatColor = HeatColor(counts[index], denominator, intensity, warm, accent)
      Color(cell, heatColor, heatColor[4])
      cell:Show()
      heatmap.renderedCounts[index] = counts[index]
    end
    heatmap.renderedZoneKey = zoneKey
    heatmap.renderedGeometryKey = geometryKey
    heatmap.renderedThemeKey = accentKey
  else
    for _, index in ipairs(active) do
      local count = counts[index]
      if rescale or heatmap.renderedCounts[index] ~= count then
        local cell = GetHeatCell(heatmap, index)
        local row = floor((index - 1) / GRID_SIZE)
        local col = (index - 1) % GRID_SIZE
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", heatmap.grid, "TOPLEFT",
          offsetX + col * stride, -(offsetY + row * stride))
        cell:SetSize(cellSize, cellSize)
        local heatColor = HeatColor(count, denominator, intensity, warm, accent)
        Color(cell, heatColor, heatColor[4])
        cell:Show()
        heatmap.renderedCounts[index] = count
      end
    end

    local stale
    for index in pairs(heatmap.renderedCounts) do
      if counts[index] == nil then
        stale = stale or {}
        stale[#stale + 1] = index
      end
    end
    if stale then
      for _, index in ipairs(stale) do
        local cell = heatmap.cells[index]
        if cell then
          cell:Hide()
        end
        heatmap.renderedCounts[index] = nil
      end
    end
  end
  heatmap.renderedMaximum = maximum

  heatmap.legendDetail:SetText(
    "Max cell: " .. FormatNumber(maximum) .. "   Zone total: " .. FormatNumber(total)
  )

  local applied = false
  local ok, result = pcall(BuildHeatmapArt, heatmap, selected.mapID, extent, offsetX, offsetY)
  if ok then
    applied = result == true
  else
    if self.settings and self.settings.debug then
      AceM2L2:SafePrint("Heatmap art error: " .. tostring(result))
    end
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

function XPTooltip:OnMapExplorationUpdated()
  if self.tab == "heatmap" and self.ui and self.ui.heatmap then
    pcall(self.RefreshHeatmap, self)
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
