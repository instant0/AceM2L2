-- Focused static audit for generated overlay data and explored-overlay dedupe.

local F = dofile("tests/fixtures.lua")
local module = F.Init()

local data = module.MapOverlayData
assert(type(data) == "table", "generated overlay data missing")
assert(type(data[1]) == "table" and type(data[18]) == "table",
  "generated overlay projects missing")

for projectID, project in pairs(data) do
  for artID, entries in pairs(project) do
    assert(type(entries) == "table" and #entries > 0,
      "empty overlay art table " .. tostring(projectID) .. ":" .. tostring(artID))
    local seen = {}
    for index = 1, #entries do
      local entry = entries[index]
      assert(type(entry) == "table" and #entry == 5,
        "malformed overlay entry " .. tostring(artID))
      local width, height, offsetX, offsetY, files =
        tonumber(entry[1]), tonumber(entry[2]), tonumber(entry[3]), tonumber(entry[4]), entry[5]
      assert(width and width > 0 and height and height > 0,
        "invalid overlay dimensions " .. tostring(artID))
      assert(offsetX and offsetX >= 0 and offsetY and offsetY >= 0,
        "invalid overlay offset " .. tostring(artID))
      assert(type(files) == "string" and files ~= "", "missing overlay tiles")
      local fileIDs = {}
      for id in files:gmatch("%d+") do
        local value = tonumber(id)
        assert(value and value > 0, "invalid tile ID")
        assert(not fileIDs[value], "duplicate tile ID in one overlay")
        fileIDs[value] = true
      end
      local key = table.concat({ width, height, offsetX, offsetY, files }, ":")
      assert(not seen[key], "duplicate overlay tuple " .. tostring(projectID) .. ":" .. tostring(artID))
      seen[key] = true
    end
  end
end

-- Explored overlays: exact duplicates render once, and a middle-texture change
-- invalidates the art cache even when first/last/count are unchanged.
local savedMapArtLayers = C_Map.GetMapArtLayers
local savedMapArtLayerTextures = C_Map.GetMapArtLayerTextures
local savedGetMapArtID = C_Map.GetMapArtID
local savedExplorationInfo = C_MapExplorationInfo
local savedOverlayData = module.MapOverlayData

C_Map.GetMapArtLayers = function()
  return { { layerWidth = 256, layerHeight = 256, tileWidth = 128, tileHeight = 128 } }
end
C_Map.GetMapArtLayerTextures = function()
  return { 1001, 1002, 1003, 1004 }
end
C_Map.GetMapArtID = function()
  return 9999
end
module.MapOverlayData = { [module.projectID or 18] = { [9999] = {} } }
module.mapOverlayCache = nil
module:GetSettings().revealUnexplored = true

local function explored(textures)
  C_MapExplorationInfo = {
    GetExploredMapTextures = function()
      return { {
        textureWidth = 384,
        textureHeight = 128,
        offsetX = 0,
        offsetY = 0,
        fileDataIDs = textures,
        isShownByMouseOver = false,
      } }
    end,
  }
end

module:ResetHeatmaps()
assert(module:RecordHeatmapKill(14, 0.5, 0.5), "overlay audit heatmap seed failed")
module:OpenUI()
module:SetTab("heatmap")

local duplicate = { 2001, 2002, 2003 }
C_MapExplorationInfo = {
  GetExploredMapTextures = function()
    return {
      { textureWidth = 384, textureHeight = 128, offsetX = 0, offsetY = 0,
        fileDataIDs = duplicate, isShownByMouseOver = false },
      { textureWidth = 384, textureHeight = 128, offsetX = 0, offsetY = 0,
        fileDataIDs = duplicate, isShownByMouseOver = false },
    }
  end,
}
module:RefreshHeatmap()
local heatmap = module.ui.heatmap
local shown, found = 0, false
for _, tile in ipairs(heatmap.artTiles or {}) do
  if tile and tile.shown then
    shown = shown + 1
    if tile.texture == 2002 then found = true end
  end
end
assert(shown == 7 and found, "duplicate explored overlay rendered twice")

explored({ 2001, 7777, 2003 })
module:RefreshHeatmap()
local changed = false
for _, tile in ipairs(heatmap.artTiles or {}) do
  if tile and tile.shown and tile.texture == 7777 then changed = true end
end
assert(changed, "middle-texture change did not invalidate art cache")

module.mapOverlayCache = nil
module.MapOverlayData = savedOverlayData
C_Map.GetMapArtID = savedGetMapArtID
C_Map.GetMapArtLayers = savedMapArtLayers
C_Map.GetMapArtLayerTextures = savedMapArtLayerTextures
C_MapExplorationInfo = savedExplorationInfo

print("Map overlay audit passed")
