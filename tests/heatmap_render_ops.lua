-- Focused test for heatmap rescale geometry and disabled-state guards.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local cells = {}
for index = 1, 100 do cells[index] = index end
db.heatmaps = { ["12"] = { gridSize = 64, cells = cells, lastSeen = 100 } }
state.mapID = 12
state.playerLevel = 20
state.now = 100

module:OpenUI()
module.heatmapZoneKey = "12"
module:SetTab("heatmap")
local heatmap = module.ui.heatmap
heatmap.renderedZoneKey = nil
heatmap.renderedCounts = {}
heatmap.renderedMaximum = 0
module:RefreshHeatmap()
assert(heatmap.renderOps.geometry == 100, "initial geometry count")
assert(heatmap.renderOps.show == 100, "initial show count")

-- A new maximum only changes colors; visible cells keep their geometry.
db.heatmaps["12"].cells[1] = 200
db.heatmaps["12"].total = 5249
module:InvalidateHeatmapZoneCache()
module:RefreshHeatmap()
assert(heatmap.renderOps.geometry == 0, "rescale repositioned visible cells")
assert(heatmap.renderOps.show == 0, "rescale re-showed visible cells")
assert(heatmap.renderOps.color == 100, "rescale did not recolor active cells")

-- A newly active cell still needs geometry and a show.
db.heatmaps["12"].cells[2000] = 1
db.heatmaps["12"].total = 5250
module:InvalidateHeatmapZoneCache()
module:RefreshHeatmap()
assert(heatmap.renderOps.geometry == 1, "new cell geometry")
assert(heatmap.renderOps.show == 1, "new cell show")
assert(heatmap.renderOps.color == 1, "existing cells were recolored without a rescale")

-- Disabled state hides once, then repeated refreshes do no cell work.
local settings = module:GetSettings()
settings.heatmapEnabled = false
module:RefreshHeatmap()
assert(heatmap.disabledClean == true, "disabled state not marked clean")
assert(heatmap.renderOps.hide > 0, "first disabled refresh did not hide cells")
module:RefreshHeatmap()
assert(heatmap.renderOps.hide == 0, "repeated disabled refresh touched cells")
assert(heatmap.renderOps.geometry == 0, "disabled refresh touched geometry")
assert(heatmap.renderOps.show == 0, "disabled refresh showed cells")

-- Re-enabling restores rendering, and a later disable hides once again.
settings.heatmapEnabled = true
module:RefreshHeatmap()
assert(heatmap.disabledClean == false, "re-enable did not clear disabled guard")
settings.heatmapEnabled = false
module:RefreshHeatmap()
assert(heatmap.disabledClean == true, "second disable did not hide cells")
assert(heatmap.renderOps.hide > 0, "second disable hide missing")

print("Heatmap render ops passed")
