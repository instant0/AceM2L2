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
local Lower = Util.Lower

local GRID_SIZE = math.floor(tonumber(XPTooltip.HEATMAP_GRID_SIZE) or 64)
if GRID_SIZE < 1 then
  GRID_SIZE = 64
end
local GRID_CELLS = GRID_SIZE * GRID_SIZE
local MAX_ART_LAYERS = 8
local MAX_ART_TILES = 256
local MAX_OVERLAY_TILES = 600
local SELECTOR_VISIBLE_ROWS = 10
local SELECTOR_ROW_HEIGHT = 22
local SELECTOR_MENU_WIDTH = 640

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
  local getter = module.GetHeatmapZoneIndex or module.GetHeatmapZones
  if type(getter) ~= "function" then
    return zones
  end
  local ok, result = pcall(getter, module)
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


local function SelectorLevelRange(levels)
  local minLevel, maxLevel
  if type(levels) == "table" then
    for levelKey, count in pairs(levels) do
      local level = tonumber(levelKey)
      if level and (tonumber(count) or 0) > 0 then
        if not minLevel or level < minLevel then minLevel = level end
        if not maxLevel or level > maxLevel then maxLevel = level end
      end
    end
  end
  return minLevel, maxLevel
end

local function SelectorLevelText(minLevel, maxLevel)
  if not minLevel then
    return "—"
  end
  if not maxLevel or maxLevel == minLevel then
    return tostring(minLevel)
  end
  return tostring(minLevel) .. "-" .. tostring(maxLevel)
end

local function MergeSelectorLevels(target, source)
  if type(source) ~= "table" then return end
  for levelKey, count in pairs(source) do
    local amount = tonumber(count) or 0
    if amount > 0 then
      target[levelKey] = (target[levelKey] or 0) + amount
    end
  end
end

-- One row per heatmap map ID. Instance metadata is merged by map ID so
-- difficulty variants cannot produce duplicate selector rows.
local function BuildHeatmapSelectorRows(owner, zones)
  local db = owner.char or {}
  local areas = type(db.areas) == "table" and db.areas or {}
  local areaLevels = type(db.areaLevels) == "table" and db.areaLevels or {}
  local instances = type(db.instances) == "table" and db.instances or {}

  local byMap = {}
  for _, entry in pairs(instances) do
    if type(entry) == "table" then
      local mapID = tonumber(entry.mapID)
      if mapID and mapID > 0 then
        local info = byMap[mapID]
        if not info then
          info = { mapID = mapID, kills = 0, levels = {}, lastSeen = 0 }
          byMap[mapID] = info
        end
        info.kills = info.kills + (tonumber(entry.kills) or 0)
        MergeSelectorLevels(info.levels,
          type(entry.killsAtLevel) == "table" and entry.killsAtLevel or nil)
        local seen = tonumber(entry.lastSeen) or 0
        local name = type(entry.name) == "string" and entry.name or ""
        if name ~= "" and (seen > info.lastSeen
          or (seen == info.lastSeen and name < (info.name or ""))) then
          info.name = name
          info.lastSeen = seen
        end
      end
    end
  end

  local rows = {}
  for _, zone in ipairs(zones or {}) do
    local mapID = tonumber(zone.mapID)
    if mapID and mapID > 0 then
      local mapKey = tostring(mapID)
      local instance = byMap[mapID]
      local name = instance and instance.name or ReadMapName(owner, mapID)
      if not name or name == "" or name == "Unknown instance" then
        name = ReadMapName(owner, mapID)
      end
      local kills = tonumber(zone.total) or 0
      if kills <= 0 then
        kills = tonumber(areas[mapKey]) or (instance and instance.kills) or 0
      end
      local levels = instance and instance.levels or areaLevels[mapKey]
      local minLevel, maxLevel = SelectorLevelRange(levels)
      rows[#rows + 1] = {
        mapID = mapID,
        key = ZoneKey(zone) or mapKey,
        name = name,
        kills = kills,
        minLevel = minLevel,
        maxLevel = maxLevel,
        instance = instance ~= nil,
      }
    end
  end

  table.sort(rows, function(a, b)
    local left = Lower(a.name) or string.lower(tostring(a.name or ""))
    local right = Lower(b.name) or string.lower(tostring(b.name or ""))
    if left ~= right then
      return left < right
    end
    return a.mapID < b.mapID
  end)
  return rows
end

local function CreateSelectorRow(owner, parent, index)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(SELECTOR_ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 12, -28 - (index - 1) * SELECTOR_ROW_HEIGHT)
  row:SetPoint("TOPRIGHT", -12, -28 - (index - 1) * SELECTOR_ROW_HEIGHT)

  local border = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  border:SetAllPoints()
  row.border = border
  local bg = row:CreateTexture(nil, "BACKGROUND", nil, 2)
  bg:SetPoint("TOPLEFT", 1, -1)
  bg:SetPoint("BOTTOMRIGHT", -1, 1)
  row.bg = bg

  local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nameLabel:SetPoint("LEFT", 8, 0)
  nameLabel:SetWidth(300)
  nameLabel:SetJustifyH("LEFT")
  nameLabel:SetWordWrap(false)
  row.nameLabel = nameLabel

  local tagLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  tagLabel:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
  tagLabel:SetWidth(72)
  tagLabel:SetJustifyH("LEFT")
  row.tagLabel = tagLabel

  local killsLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  killsLabel:SetPoint("RIGHT", -110, 0)
  killsLabel:SetWidth(82)
  killsLabel:SetJustifyH("RIGHT")
  row.killsLabel = killsLabel

  local levelLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  levelLabel:SetPoint("RIGHT", -12, 0)
  levelLabel:SetWidth(86)
  levelLabel:SetJustifyH("RIGHT")
  row.levelLabel = levelLabel

  row.entry = nil
  row.selected = false
  row.hover = false

  function row:ApplyStyle()
    local theme = owner:GetTheme()
    local fill = { 0, 0, 0, 0 }
    local edge = { 0, 0, 0, 0 }
    local nameColor = theme.text
    if self.selected then
      fill = { theme.accent[1], theme.accent[2], theme.accent[3], 0.28 }
      edge = { theme.accent[1], theme.accent[2], theme.accent[3], 0.8 }
      nameColor = theme.text
    elseif self.hover then
      fill = { theme.accent[1], theme.accent[2], theme.accent[3], 0.14 }
      edge = { theme.border[1], theme.border[2], theme.border[3], 0.6 }
    end
    self.bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
    self.border:SetColorTexture(edge[1], edge[2], edge[3], edge[4])
    self.nameLabel:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
    self.tagLabel:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
    self.killsLabel:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
    self.levelLabel:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end

  row:SetScript("OnEnter", function(self)
    self.hover = true
    self:ApplyStyle()
  end)
  row:SetScript("OnLeave", function(self)
    self.hover = false
    self:ApplyStyle()
  end)
  row:SetScript("OnClick", function(self)
    if self.entry then
      pcall(owner.SelectHeatmapSelectorEntry, owner, self.entry)
    end
  end)
  row:ApplyStyle()
  return row
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


local function AddRenderOp(heatmap, key)
  local ops = heatmap and heatmap.renderOps
  if ops then
    ops[key] = (ops[key] or 0) + 1
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
  AddRenderOp(heatmap, "hide")
  heatmap.cells[index] = cell
  heatmap.cellCount = (heatmap.cellCount or 0) + 1
  return cell
end

local function HideHeatCells(heatmap)
  for _, cell in pairs(heatmap.cells or {}) do
    if cell and cell.Hide then
      if not cell.IsShown or cell:IsShown() then
        AddRenderOp(heatmap, "hide")
      end
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
  -- String keys avoid double-precision collisions for large map dimensions.
  return string.format("%d:%d:%d:%d", width, height, offsetX, offsetY)
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
  local seen = {}
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
        local drawOnTop = false
        local topOK, topValue = pcall(function()
          return info.isDrawOnTopLayer == true
        end)
        if topOK then
          drawOnTop = topValue
        end
        local textureParts = {}
        for textureIndex = 1, textureCount do
          textureParts[textureIndex] = TextureKey(textures[textureIndex])
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
          "%d:%d:%d:%d:%d:%s", width, height, offsetX, offsetY,
          textureCount, table.concat(textureParts, ",")
        )
      end)
      if infoOK and type(normalized) == "table"
        and not seen[normalizedSignature] then
        seen[normalizedSignature] = true
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
  local seen = {}
  for index = 1, #entries do
    local entry = entries[index]
    if type(entry) == "table" then
      local width = tonumber(entry[1]) or 0
      local height = tonumber(entry[2]) or 0
      local offsetX = tonumber(entry[3]) or 0
      local offsetY = tonumber(entry[4]) or 0
      local textures = ParseFileDataIDs(entry[5])
      if width > 0 and height > 0 and #textures > 0 then
        local entrySignature = string.format(
          "%d:%d:%d:%d:%s", width, height, offsetX, offsetY,
          table.concat(textures, ",")
        )
        if not seen[entrySignature] then
          seen[entrySignature] = true
          result[#result + 1] = {
            width = width,
            height = height,
            offsetX = offsetX,
            offsetY = offsetY,
            textures = textures,
            key = OverlayKey(width, height, offsetX, offsetY),
          }
          signature[#signature + 1] = entrySignature
        end
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

function XPTooltip:ReleaseHeatmapUIResources()
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap then return false end
  if type(self.CloseHeatmapSelector) == "function" then
    pcall(self.CloseHeatmapSelector, self)
  end
  HideHeatCells(heatmap)
  HideHeatmapArt(heatmap)
  heatmap.cells = {}
  heatmap.artTiles = {}
  heatmap.cellCount = 0
  heatmap.renderedCounts = {}
  heatmap.renderedZoneKey = nil
  heatmap.renderedGeometryKey = nil
  heatmap.renderedThemeKey = nil
  heatmap.renderedMaximum = 0
  heatmap.artKey = nil
  heatmap.artReady = false
  heatmap.disabledClean = false
  return true
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


  local selectButton = CreateTextButton(selector, "Select", 76, 22)
  selectButton:SetPoint("RIGHT", currentButton, "LEFT", -8, 0)
  selectButton:SetScript("OnClick", function()
    pcall(self.ToggleHeatmapSelector, self)
  end)

  local menuParent = _G.UIParent or panel
  local menu = CreateBackdropFrame(menuParent, "AceM2L2HeatmapSelector")
  menu:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -4)
  menu:SetSize(SELECTOR_MENU_WIDTH,
    28 + SELECTOR_VISIBLE_ROWS * SELECTOR_ROW_HEIGHT + 24)
  if menu.SetFrameStrata then
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
  end
  if menu.SetClampedToScreen then
    menu:SetClampedToScreen(true)
  end
  menu:EnableMouse(true)
  menu:Hide()
  self:StylePanel(menu, "elevated")

  local headerName = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerName:SetPoint("TOPLEFT", 20, -6)
  headerName:SetJustifyH("LEFT")
  headerName:SetText("Zone / Instance")

  local headerKills = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerKills:SetPoint("TOPRIGHT", -110, -6)
  headerKills:SetWidth(82)
  headerKills:SetJustifyH("RIGHT")
  headerKills:SetText("Kills")

  local headerLevels = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerLevels:SetPoint("TOPRIGHT", -12, -6)
  headerLevels:SetWidth(86)
  headerLevels:SetJustifyH("RIGHT")
  headerLevels:SetText("Levels")

  local selectorRows = {}
  for index = 1, SELECTOR_VISIBLE_ROWS do
    selectorRows[index] = CreateSelectorRow(self, menu, index)
    selectorRows[index]:Hide()
  end

  local selectorPage = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  selectorPage:SetPoint("BOTTOMLEFT", 12, 6)
  selectorPage:SetJustifyH("LEFT")
  selectorPage:SetText("")

  local catcherParent = _G.UIParent or panel
  local catcher = CreateFrame("Button", nil, catcherParent)
  catcher:SetAllPoints(catcherParent)
  if catcher.SetFrameStrata then
    catcher:SetFrameStrata("FULLSCREEN")
  end
  catcher:EnableMouse(true)
  catcher:Hide()
  catcher:SetScript("OnClick", function()
    pcall(self.CloseHeatmapSelector, self)
  end)

  menu:SetScript("OnHide", function()
    local heat = self.ui and self.ui.heatmap
    if heat then
      heat.selectorOpen = false
      if heat.selectorCatcher then heat.selectorCatcher:Hide() end
    end
  end)
  if menu.EnableMouseWheel then
    pcall(menu.EnableMouseWheel, menu, true)
  end
  menu:SetScript("OnMouseWheel", function(_, delta)
    pcall(self.ScrollHeatmapSelector, self, -(tonumber(delta) or 0))
  end)

  local menuName = (type(menu.GetName) == "function" and menu:GetName()) or nil
  if menuName and type(_G.UISpecialFrames) == "table" then
    local exists = false
    for _, value in ipairs(_G.UISpecialFrames) do
      if value == menuName then exists = true break end
    end
    if not exists then
      table.insert(_G.UISpecialFrames, menuName)
    end
  end

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
    selectButton = selectButton,
    selectorMenu = menu,
    selectorRows = selectorRows,
    selectorEntries = {},
    selectorOffset = 0,
    selectorOpen = false,
    selectorHeaderName = headerName,
    selectorHeaderKills = headerKills,
    selectorHeaderLevels = headerLevels,
    selectorPage = selectorPage,
    selectorCatcher = catcher,
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
    renderOps = { geometry = 0, show = 0, hide = 0, color = 0 },
    disabledClean = false,
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
  if type(self.ApplyHeatmapSelectorTheme) == "function" then
    pcall(self.ApplyHeatmapSelectorTheme, self)
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
  heatmap.renderOps = { geometry = 0, show = 0, hide = 0, color = 0 }

  local theme = self:GetTheme()
  local settings = self:GetSettings()
  local zones = ReadZones(self)
  local supported = SupportsMapPosition(self)

  if settings and settings.heatmapEnabled == false then
    if type(self.CloseHeatmapSelector) == "function" then
      pcall(self.CloseHeatmapSelector, self)
    end
    if not heatmap.disabledClean then
      heatmap.noData:SetText("Heatmap collection is disabled. Enable it in Settings > Heatmap.")
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
      heatmap.disabledClean = true
    end
    return
  end
  heatmap.disabledClean = false

  if #zones == 0 then
    if type(self.CloseHeatmapSelector) == "function" then
      pcall(self.CloseHeatmapSelector, self)
    end
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

  local cellsData = type(selected.cells) == "table" and selected.cells or nil
  if selected.journeySource and type(self.GetJourneyHeatmapCells) == "function" then
    local ok, journeyCells = pcall(self.GetJourneyHeatmapCells, self, selected.mapID)
    if ok and type(journeyCells) == "table" and next(journeyCells) ~= nil then
      cellsData = journeyCells
    end
  end
  if (not cellsData or next(cellsData) == nil)
    and type(self.GetHeatmapZoneCells) == "function" then
    local ok, legacyCells = pcall(self.GetHeatmapZoneCells, self, selected.mapID)
    if ok and type(legacyCells) == "table" then
      cellsData = legacyCells
    end
  end
  cellsData = cellsData or {}
  local counts = {}
  local active = {}
  local maximum = 0
  for index = 1, GRID_CELLS do
    local value = cellsData[index]
    local count = type(value) == "table" and tonumber(value.kills) or tonumber(value) or 0
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
        if not cell.IsShown or cell:IsShown() then
          AddRenderOp(heatmap, "hide")
        end
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
      AddRenderOp(heatmap, "geometry")
      local heatColor = HeatColor(counts[index], denominator, intensity, warm, accent)
      Color(cell, heatColor, heatColor[4])
      AddRenderOp(heatmap, "color")
      if not cell.IsShown or not cell:IsShown() then
        cell:Show()
        AddRenderOp(heatmap, "show")
      end
      heatmap.renderedCounts[index] = counts[index]
    end
    heatmap.renderedZoneKey = zoneKey
    heatmap.renderedGeometryKey = geometryKey
    heatmap.renderedThemeKey = accentKey
  else
    for _, index in ipairs(active) do
      local count = counts[index]
      local rendered = heatmap.renderedCounts[index]
      if rescale or rendered ~= count then
        local cell = heatmap.cells[index]
        local isNew = rendered == nil
        if isNew or not cell then
          cell = GetHeatCell(heatmap, index)
          local row = floor((index - 1) / GRID_SIZE)
          local col = (index - 1) % GRID_SIZE
          cell:ClearAllPoints()
          cell:SetPoint("TOPLEFT", heatmap.grid, "TOPLEFT",
            offsetX + col * stride, -(offsetY + row * stride))
          cell:SetSize(cellSize, cellSize)
          AddRenderOp(heatmap, "geometry")
          if not cell.IsShown or not cell:IsShown() then
            cell:Show()
            AddRenderOp(heatmap, "show")
          end
        end
        local heatColor = HeatColor(count, denominator, intensity, warm, accent)
        Color(cell, heatColor, heatColor[4])
        AddRenderOp(heatmap, "color")
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
          if not cell.IsShown or cell:IsShown() then
            AddRenderOp(heatmap, "hide")
          end
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
  if heatmap.selectorOpen then
    pcall(self.RefreshHeatmapSelector, self, zones)
  end
end


function XPTooltip:UpdateHeatmapSelectorRows()
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap or not heatmap.selectorRows then return end
  local entries = heatmap.selectorEntries or {}
  local offset = floor(tonumber(heatmap.selectorOffset) or 0)
  local maximum = max(0, #entries - SELECTOR_VISIBLE_ROWS)
  if offset < 0 then offset = 0 end
  if offset > maximum then offset = maximum end
  heatmap.selectorOffset = offset

  for index = 1, SELECTOR_VISIBLE_ROWS do
    local row = heatmap.selectorRows[index]
    local entry = entries[offset + index]
    row.entry = entry
    if entry then
      row.nameLabel:SetText(entry.name or "")
      row.tagLabel:SetText(entry.instance and "Dungeon" or "")
      row.killsLabel:SetText(FormatNumber(entry.kills or 0))
      row.levelLabel:SetText(SelectorLevelText(entry.minLevel, entry.maxLevel))
      row.selected = entry.key == self.heatmapZoneKey
      row:Show()
      row:ApplyStyle()
    else
      row.selected = false
      row:Hide()
    end
  end

  if heatmap.selectorPage then
    if #entries == 0 then
      heatmap.selectorPage:SetText("No heatmap zones")
    else
      local first = offset + 1
      local last = min(#entries, offset + SELECTOR_VISIBLE_ROWS)
      heatmap.selectorPage:SetText(string.format(
        "%d-%d of %d%s", first, last, #entries,
        maximum > 0 and "  ·  scroll" or ""
      ))
    end
  end
end

function XPTooltip:RefreshHeatmapSelector(zones)
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap or not heatmap.selectorRows then return {} end
  local entries = BuildHeatmapSelectorRows(self, zones or ReadZones(self))
  heatmap.selectorEntries = entries
  self:UpdateHeatmapSelectorRows()
  return entries
end

function XPTooltip:SetHeatmapSelectorOffset(value)
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap then return end
  local entries = heatmap.selectorEntries or {}
  local maximum = max(0, #entries - SELECTOR_VISIBLE_ROWS)
  local offset = floor(tonumber(value) or 0)
  if offset < 0 then offset = 0 end
  if offset > maximum then offset = maximum end
  heatmap.selectorOffset = offset
  self:UpdateHeatmapSelectorRows()
end

function XPTooltip:ScrollHeatmapSelector(delta)
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap then return end
  self:SetHeatmapSelectorOffset(
    (tonumber(heatmap.selectorOffset) or 0) + (tonumber(delta) or 0)
  )
end

function XPTooltip:OpenHeatmapSelector()
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap or not heatmap.selectorMenu then return false end
  local zones = ReadZones(self)
  if #zones == 0 then
    return false
  end
  self:RefreshHeatmapSelector(zones)

  local entries = heatmap.selectorEntries or {}
  local selected
  for index = 1, #entries do
    if entries[index].key == self.heatmapZoneKey then
      selected = index
      break
    end
  end
  if selected then
    local maximum = max(0, #entries - SELECTOR_VISIBLE_ROWS)
    heatmap.selectorOffset = max(0, min(maximum,
      selected - 1 - floor(SELECTOR_VISIBLE_ROWS / 2)))
    self:UpdateHeatmapSelectorRows()
  end

  heatmap.selectorOpen = true
  if heatmap.selectorCatcher then heatmap.selectorCatcher:Show() end
  heatmap.selectorMenu:Show()
  if heatmap.selectButton then
    heatmap.selectButton:SetButtonState("PUSHED", true)
  end
  return true
end

function XPTooltip:CloseHeatmapSelector()
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap then return end
  heatmap.selectorOpen = false
  if heatmap.selectorCatcher then heatmap.selectorCatcher:Hide() end
  if heatmap.selectorMenu and heatmap.selectorMenu:IsShown() then
    heatmap.selectorMenu:Hide()
  end
  if heatmap.selectButton then
    heatmap.selectButton:SetButtonState("PUSHED", false)
  end
end

function XPTooltip:ToggleHeatmapSelector()
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap then return end
  if heatmap.selectorOpen then
    self:CloseHeatmapSelector()
  else
    self:OpenHeatmapSelector()
  end
end

function XPTooltip:SelectHeatmapSelectorEntry(entry)
  if type(entry) ~= "table" or not entry.key then return end
  self.heatmapZoneKey = entry.key
  self:CloseHeatmapSelector()
  self:RefreshHeatmap()
end

function XPTooltip:ApplyHeatmapSelectorTheme()
  local heatmap = self.ui and self.ui.heatmap
  if not heatmap then return end
  local theme = self:GetTheme()
  if heatmap.selectorMenu then
    self:StylePanel(heatmap.selectorMenu, "elevated")
  end
  if heatmap.selectorHeaderName then
    heatmap.selectorHeaderName:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if heatmap.selectorHeaderKills then
    heatmap.selectorHeaderKills:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if heatmap.selectorHeaderLevels then
    heatmap.selectorHeaderLevels:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if heatmap.selectorPage then
    heatmap.selectorPage:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  for _, row in ipairs(heatmap.selectorRows or {}) do
    if row and row.ApplyStyle then row:ApplyStyle() end
  end
end

function XPTooltip:OnMapExplorationUpdated()
  local settings = self:GetSettings()
  if settings and settings.heatmapEnabled == false then
    return
  end
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
