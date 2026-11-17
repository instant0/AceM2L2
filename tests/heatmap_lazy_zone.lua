-- Focused test for selected-zone heatmap normalization.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

db.heatmaps = {}
for mapID = 100, 119 do
  db.heatmaps[tostring(mapID)] = {
    gridSize = 64,
    cells = { [1] = mapID - 99, [4096] = 1 },
    total = mapID - 98,
    lastSeen = mapID,
  }
end
module:InvalidateHeatmapCache()

-- The UI zone list must not run the full normalizer.
local originalNormalize = module.NormalizeHeatmaps
module.NormalizeHeatmaps = function()
  error("lazy zone index called full normalization")
end
local zones = module:GetHeatmapZoneIndex()
assert(#zones == 20, "zone index count")
assert(zones[1].cells == nil, "zone index materialized cells")
module.NormalizeHeatmaps = originalNormalize

-- Only the requested zone normalizes; repeats use the zone cache.
module.heatmapZoneCache = nil
module.heatmapZoneNormalizations = 0
local cells = module:GetHeatmapZoneCells(105)
assert(cells and cells[1] == 6 and cells[4096] == 1, "selected zone cells")
assert(module.heatmapZoneNormalizations == 1, "selected zone should normalize once")
module:GetHeatmapZoneCells("105")
assert(module.heatmapZoneNormalizations == 1, "zone cache should not normalize again")
module:GetHeatmapZoneCells(106)
assert(module.heatmapZoneNormalizations == 2, "second zone should normalize once")

-- Recording a kill invalidates the selected-zone cache.
db.heatmaps["105"].cells[2] = 1
module:InvalidateHeatmapZoneCache()
module:GetHeatmapZoneCells(105)
assert(module.heatmapZoneNormalizations == 3, "cache should refresh for the new cell")
module:RecordHeatmapKill(105, 0.25, 0.25)
module:GetHeatmapZoneCells(105)
assert(module.heatmapZoneNormalizations == 4, "kill did not invalidate zone cache")

-- The full normalizer remains available for commands/tests.
local full = module:NormalizeHeatmaps()
local fullCount = 0
for _ in pairs(full) do fullCount = fullCount + 1 end
assert(fullCount == 20, "full normalization path changed")

-- The UI uses the zone index and normalizes only the selected zone.
module:OpenUI()
state.mapID = 105
module.heatmapZoneKey = nil
module.heatmapZoneCache = nil
module.heatmapZoneNormalizations = 0
module:SetTab("heatmap")
module:RefreshHeatmap()
assert(module.heatmapZoneNormalizations == 1, "heatmap UI normalized more than the selected zone")
assert(module.ui.heatmap.renderedMaximum > 0, "heatmap UI did not render selected zone")

print("Heatmap lazy zone passed")
