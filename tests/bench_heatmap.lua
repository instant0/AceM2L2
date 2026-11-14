-- H64-9 offline heatmap benchmark.
-- Usage:
--   lua tests/bench_heatmap.lua --all
--   lua tests/bench_heatmap.lua --scenario dense_square_1
--   lua tests/bench_heatmap.lua --list

local args = arg or {}
local selected
local format = "keyvalue"
for index = 1, #args do
  local value = args[index]
  if value == "--scenario" then
    selected = args[index + 1]
    index = index + 1
  elseif value == "--format" then
    format = args[index + 1]
    index = index + 1
  elseif value == "--list" then
    selected = "list"
  end
end
if selected == "list" then
  print("scenarios: sparse_square_1 medium_square_1 dense_square_1 fewhot_square_1")
  print("           dense_wide_1 dense_tall_1 dense_irregular_1 dense_square_40 dense_square_41")
  print("           disabled_square noart_square")
  return
end

local savedArg1 = args[1]
args[1] = "forever"
local F = dofile("tests/fixtures.lua")
args[1] = savedArg1
local module = F.Init()

-- ---------------------------------------------------------------------------
-- Operation counters
-- ---------------------------------------------------------------------------
local counts = {}
local function resetCounts()
  counts = {}
end
local function bump(name)
  counts[name] = (counts[name] or 0) + 1
end
local function wrapMethod(object, name)
  local original = object[name]
  if type(original) ~= "function" then
    return
  end
  object[name] = function(self, ...)
    bump(name)
    return original(self, ...)
  end
end
local function wrapObject(object)
  if type(object) ~= "table" or object.__benchWrapped then
    return object
  end
  object.__benchWrapped = true
  for _, name in ipairs({
    "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetColorTexture",
    "SetTexture", "SetTexCoord", "ClearAllPoints", "SetDrawLayer",
    "SetAlpha", "SetVertexColor", "Show", "Hide",
  }) do
    wrapMethod(object, name)
  end
  local originalCreateTexture = object.CreateTexture
  if type(originalCreateTexture) == "function" then
    object.CreateTexture = function(self, ...)
      bump("CreateTexture")
      local texture = originalCreateTexture(self, ...)
      wrapObject(texture)
      return texture
    end
  end
  local originalCreateFontString = object.CreateFontString
  if type(originalCreateFontString) == "function" then
    object.CreateFontString = function(self, ...)
      bump("CreateFontString")
      local font = originalCreateFontString(self, ...)
      wrapObject(font)
      return font
    end
  end
  return object
end
local originalCreateFrame = CreateFrame
CreateFrame = function(...)
  bump("CreateFrame")
  local frame = originalCreateFrame(...)
  return wrapObject(frame)
end

-- ---------------------------------------------------------------------------
-- Deterministic profile generation
-- ---------------------------------------------------------------------------
local PROFILES = {
  { id = "sparse_square_1", shape = "square", maps = 1, active = 100, dist = "skewed", max = 10, art = true },
  { id = "medium_square_1", shape = "square", maps = 1, active = 1000, dist = "skewed", max = 50, art = true },
  { id = "dense_square_1", shape = "square", maps = 1, active = 4096, dist = "skewed", max = 100, art = true },
  { id = "fewhot_square_1", shape = "square", maps = 1, active = 200, dist = "fewhot", max = 200, art = true },
  { id = "dense_wide_1", shape = "wide", maps = 1, active = 1024, dist = "skewed", max = 100, art = true },
  { id = "dense_tall_1", shape = "tall", maps = 1, active = 1024, dist = "skewed", max = 100, art = true },
  { id = "dense_irregular_1", shape = "irregular", maps = 1, active = 1400, dist = "skewed", max = 100, art = true },
  { id = "dense_square_40", shape = "square", maps = 40, active = 4096, dist = "skewed", max = 100, art = true },
  { id = "dense_square_41", shape = "square", maps = 41, active = 4096, dist = "skewed", max = 100, art = true },
  { id = "disabled_square", shape = "square", maps = 1, active = 4096, dist = "skewed", max = 100, art = true, disabled = true },
  { id = "noart_square", shape = "square", maps = 1, active = 4096, dist = "skewed", max = 100, art = false },
}

local function IndexFor(i, shape)
  local zero = i - 1
  local row = math.floor(zero / 64)
  local col = zero % 64
  if shape == "wide" then
    return (16 + (row % 32)) * 64 + col + 1
  elseif shape == "tall" then
    return row * 64 + (16 + (col % 32)) + 1
  elseif shape == "irregular" then
    return ((row * 37) % 64) * 64 + ((col * 53) % 64) + 1
  end
  return ((zero * 37) % 4096) + 1
end

local function CountFor(i, active, profile)
  if profile.dist == "uniform" then
    return 1
  elseif profile.dist == "linear" then
    return 1 + (i % profile.max)
  elseif profile.dist == "fewhot" then
    return (i % 20 == 0) and profile.max or 1
  end
  return 1 + ((i * 17) % profile.max)
end

local function BuildHeatmaps(profile)
  module:ResetHeatmaps()
  local maps = {}
  for mapIndex = 1, profile.maps do
    local mapID = 1000 + mapIndex
    local cells = {}
    local total = 0
    local seen = {}
    local target = math.min(profile.active, 4096)
    local i, count = 1, 0
    while count < target do
      local index = IndexFor(i, profile.shape)
      if not seen[index] then
        seen[index] = true
        count = count + 1
        local value = CountFor(count, target, profile)
        cells[index] = value
        total = total + value
      end
      i = i + 1
      if i > 1000000 then break end
    end
    maps[tostring(mapID)] = {
      gridSize = 64,
      cells = cells,
      total = total,
      lastSeen = mapIndex,
    }
  end
  module.char.heatmaps = maps
  module:InvalidateHeatmapCache()
  return maps
end

local function SetArt(enabled)
  if enabled then
    C_Map.GetMapArtID = function(id) return id end
    C_Map.GetMapArtLayers = function()
      return { { layerWidth = 256, layerHeight = 256, tileWidth = 128, tileHeight = 128 } }
    end
    C_Map.GetMapArtLayerTextures = function()
      return { 1001, 1002, 1003, 1004 }
    end
    C_MapExplorationInfo = {
      GetExploredMapTextures = function() return {} end,
    }
  else
    C_Map.GetMapArtID = nil
    C_Map.GetMapArtLayers = nil
    C_Map.GetMapArtLayerTextures = nil
    C_MapExplorationInfo = nil
  end
end

local function NowMS()
  return os.clock() * 1000
end

local function Measure(name, fn, repeats)
  local total = 0
  for _ = 1, repeats or 1 do
    local start = NowMS()
    fn()
    total = total + (NowMS() - start)
  end
  return total / (repeats or 1)
end

local function Render(profile, mapKey)
  module:OpenUI()
  local ui = module.ui
  ui:SetSize(1150, 780)
  if ui.heatmap then
    wrapObject(ui.heatmap.grid)
    wrapObject(ui.heatmap.panel)
    wrapObject(ui.heatmap.legend)
    for _, cell in pairs(ui.heatmap.cells or {}) do wrapObject(cell) end
    for _, tile in ipairs(ui.heatmap.artTiles or {}) do wrapObject(tile) end
    for _, swatch in ipairs(ui.heatmap.gradientSwatches or {}) do wrapObject(swatch) end
  end
  module.tab = "heatmap"
  module.heatmapZoneKey = mapKey
  SetArt(profile.art)
  module:GetSettings().heatmapEnabled = not profile.disabled
  module:GetSettings().showHeatmap = true
  module:GetSettings().revealUnexplored = true
  module:GetSettings().heatmapIntensity = 100
  module:GetSettings().heatmapWarmColors = false
end

local function RunProfile(profile)
  local maps = BuildHeatmaps(profile)
  local mapKey = tostring(1000 + profile.maps)
  collectgarbage("collect")
  local memBefore = collectgarbage("count")

  resetCounts()
  local normalizeMS = Measure("normalize", function()
    module:InvalidateHeatmapCache()
    module:NormalizeHeatmaps()
  end, 5)

  resetCounts()
  local recordMS = Measure("record", function()
    for _ = 1, 1000 do
      module:RecordHeatmapKill(tonumber(mapKey), 0.5, 0.5)
    end
  end, 1)

  local zonesBefore = 0
  for _ in pairs(module:NormalizeHeatmaps()) do zonesBefore = zonesBefore + 1 end

  Render(profile, mapKey)
  if module.ui and module.ui.heatmap then
    module.ui.heatmap.renderedZoneKey = "__force_full__"
    module.ui.heatmap.renderedGeometryKey = nil
    module.ui.heatmap.renderedThemeKey = nil
    module.ui.heatmap.renderedMaximum = -1
  end
  local heatmap = module.ui and module.ui.heatmap
  local poolCells = heatmap and heatmap.cellCount or 0
  local cells = profile.active
  local artTiles = 0
  for _, tile in ipairs(heatmap and heatmap.artTiles or {}) do
    if tile and tile.shown then artTiles = artTiles + 1 end
  end

  resetCounts()
  module.heatmapZoneKey = mapKey
  local firstRenderMS = Measure("first", function()
    module:RefreshHeatmap()
  end, 1)
  local firstOps = counts

  -- Rescale: force a new maximum while keeping the zone/geometry/theme.
  resetCounts()
  local maxCell
  local maxCount = 0
  for index, count in pairs(module.char.heatmaps[mapKey].cells or {}) do
    if count > maxCount then maxCount, maxCell = count, index end
  end
  if maxCell then
    module.char.heatmaps[mapKey].cells[maxCell] = maxCount + 50
    module.char.heatmaps[mapKey].total = (module.char.heatmaps[mapKey].total or 0) + 50
  end
  local rescaleMS = Measure("rescale", function()
    module:RefreshHeatmap()
  end, 1)
  local rescaleOps = counts

  -- Incremental: change a non-maximum cell.
  resetCounts()
  local updateCell
  for index, count in pairs(module.char.heatmaps[mapKey].cells or {}) do
    if index ~= maxCell then updateCell = index; break end
  end
  if updateCell then
    module.char.heatmaps[mapKey].cells[updateCell] =
      (module.char.heatmaps[mapKey].cells[updateCell] or 0) + 1
  end
  local incrementalMS = Measure("incremental", function()
    module:RefreshHeatmap()
  end, 1)
  local incrementalOps = counts

  -- Resize refresh.
  resetCounts()
  module.ui:SetSize(1400, 1050)
  local resizeMS = Measure("resize", function()
    module:RefreshHeatmap()
  end, 1)
  local resizeOps = counts

  -- Disabled state.
  resetCounts()
  module:GetSettings().heatmapEnabled = false
  local disabledRecord = module:RecordHeatmapKill(tonumber(mapKey), 0.5, 0.5)
  local disabledMS = Measure("disabled", function()
    module:RefreshHeatmap()
  end, 1)
  local disabledOps = counts
  module:GetSettings().heatmapEnabled = true

  collectgarbage("collect")
  local memAfter = collectgarbage("count")

  local result = {
    id = profile.id,
    shape = profile.shape,
    maps = profile.maps,
    active = profile.active,
    occupied = profile.active,
    empty = 4096 - profile.active,
    poolCells = poolCells,
    normalizeMS = normalizeMS,
    recordMS = recordMS,
    zonesBefore = zonesBefore,
    firstRenderMS = firstRenderMS,
    rescaleMS = rescaleMS,
    incrementalMS = incrementalMS,
    resizeMS = resizeMS,
    disabledMS = disabledMS,
    memoryBeforeKB = memBefore,
    memoryAfterKB = memAfter,
    cells = cells,
    artTiles = artTiles,
    firstOps = firstOps,
    rescaleOps = rescaleOps,
    incrementalOps = incrementalOps,
    resizeOps = resizeOps,
    disabledRecord = disabledRecord,
    disabledOps = disabledOps,
  }
  return result
end

local function Op(name)
  return tostring(counts[name] or 0)
end

local function PrintKeyValue(r)
  print(string.format("scenario=%s shape=%s maps=%d active=%d occupied=%d empty=%d",
    r.id, r.shape, r.maps, r.active, r.occupied, r.empty))
  print(string.format("  normalize_ms=%.3f record_1000_ms=%.3f first_render_ms=%.3f rescale_ms=%.3f incremental_ms=%.3f resize_ms=%.3f disabled_ms=%.3f",
    r.normalizeMS, r.recordMS, r.firstRenderMS, r.rescaleMS, r.incrementalMS, r.resizeMS, r.disabledMS))
  print(string.format("  memory_kb_before=%.1f memory_kb_after=%.1f zones_before=%d cells=%d pool_cells=%d art_tiles=%d",
    r.memoryBeforeKB, r.memoryAfterKB, r.zonesBefore, r.cells, r.poolCells, r.artTiles))
  print(string.format("  first_ops CreateTexture=%s SetPoint=%s SetSize=%s SetColorTexture=%s Show=%s Hide=%s",
    r.firstOps.CreateTexture or 0, r.firstOps.SetPoint or 0, r.firstOps.SetSize or 0,
    r.firstOps.SetColorTexture or 0, r.firstOps.Show or 0, r.firstOps.Hide or 0))
  print(string.format("  rescale_ops CreateTexture=%s SetColorTexture=%s Show=%s Hide=%s",
    r.rescaleOps.CreateTexture or 0, r.rescaleOps.SetColorTexture or 0,
    r.rescaleOps.Show or 0, r.rescaleOps.Hide or 0))
  print(string.format("  incremental_ops CreateTexture=%s SetColorTexture=%s Show=%s Hide=%s",
    r.incrementalOps.CreateTexture or 0, r.incrementalOps.SetColorTexture or 0,
    r.incrementalOps.Show or 0, r.incrementalOps.Hide or 0))
  print(string.format("  disabled_record=%s disabled_ops CreateTexture=%s SetColorTexture=%s Show=%s Hide=%s",
    tostring(r.disabledRecord), r.disabledOps.CreateTexture or 0,
    r.disabledOps.SetColorTexture or 0, r.disabledOps.Show or 0, r.disabledOps.Hide or 0))
end

local function PrintCSVHeader()
  print("scenario,shape,maps,active,occupied,empty,normalize_ms,record_1000_ms,first_render_ms,rescale_ms,incremental_ms,resize_ms,disabled_ms,memory_before_kb,memory_after_kb,cells,pool_cells,art_tiles,first_create_texture,first_set_color,rescale_create_texture,rescale_set_color,incremental_create_texture,incremental_set_color,disabled_create_texture,disabled_set_color")
end
local function PrintCSV(r)
  print(string.format("%s,%s,%d,%d,%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.1f,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
    r.id, r.shape, r.maps, r.active, r.occupied, r.empty, r.normalizeMS, r.recordMS,
    r.firstRenderMS, r.rescaleMS, r.incrementalMS, r.resizeMS, r.disabledMS,
    r.memoryBeforeKB, r.memoryAfterKB, r.cells, r.poolCells, r.artTiles,
    r.firstOps.CreateTexture or 0, r.firstOps.SetColorTexture or 0,
    r.rescaleOps.CreateTexture or 0, r.rescaleOps.SetColorTexture or 0,
    r.incrementalOps.CreateTexture or 0, r.incrementalOps.SetColorTexture or 0,
    r.disabledOps.CreateTexture or 0, r.disabledOps.SetColorTexture or 0))
end

local results = {}
if selected and selected ~= "list" then
  for _, profile in ipairs(PROFILES) do
    if profile.id == selected then
      results[1] = RunProfile(profile)
    end
  end
  if #results == 0 then
    error("unknown scenario: " .. tostring(selected))
  end
else
  for _, profile in ipairs(PROFILES) do
    results[#results + 1] = RunProfile(profile)
  end
end

if format == "csv" then
  PrintCSVHeader()
  for _, result in ipairs(results) do PrintCSV(result) end
else
  for _, result in ipairs(results) do PrintKeyValue(result) end
end
