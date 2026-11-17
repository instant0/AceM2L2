-- Focused test for MEM-2 cache bounds, eviction counters, and UI release.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

-- Ten zone blocks, decoded through an 8-entry LRU.
db.mobs = {}
for index = 1, 10 do
  local mapID = 200 + index
  db.mobs["npc:" .. tostring(4000 + index)] = {
    npcID = 4000 + index,
    name = "Cache Mob " .. tostring(index),
    classification = "normal",
    kills = 1,
    totalXP = 10,
    killsByMap = { [tostring(mapID)] = 1 },
    killsByInstance = {},
    contexts = {},
  }
end
db.heatmaps = {}
for index = 1, 10 do
  local mapID = 200 + index
  db.heatmaps[tostring(mapID)] = {
    gridSize = 64,
    cells = { [1] = index, [2] = 1 },
    total = index + 1,
    lastSeen = index,
  }
end
assert(module:FlushJourneyBlocks(), "journey flush")

module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
for index = 1, 10 do
  assert(module:GetJourneyBlock("map:" .. tostring(200 + index)), "block decode")
end
local stats = module:GetCacheStats()
assert(stats.blockZones <= 8, "block cache exceeded capacity")
assert(stats.blockEvictions >= 2, "block evictions not counted")
assert(stats.blockCapacity == 8, "block capacity")
assert(stats.decodedBlocks == 10, "decoded block counter")

-- Ten selected heatmap zones, normalized through a 4-entry LRU.
module:InvalidateHeatmapCache()
module.heatmapZoneNormalizations = 0
for index = 1, 10 do
  assert(module:GetHeatmapZoneCells(200 + index), "heatmap zone decode")
end
stats = module:GetCacheStats()
assert(stats.heatmapZones <= 4, "heatmap cache exceeded capacity")
assert(stats.heatmapEvictions >= 6, "heatmap evictions not counted")
assert(stats.heatmapCapacity == 4, "heatmap capacity")
assert(stats.heatmapNormalizations == 10, "heatmap normalization counter")

-- Leaving the heatmap tab releases its cell pool.
db.heatmaps["12"] = {
  gridSize = 64,
  cells = { [1] = 2, [2] = 1 },
  total = 3,
  lastSeen = 1,
}
module:InvalidateHeatmapCache()
state.mapID = 12
module:OpenUI()
module:SetTab("heatmap")
module:RefreshHeatmap()
local heatmap = module.ui.heatmap
assert(heatmap.cellCount > 0, "heatmap cells were not created")
module:SetTab("overview")
assert(heatmap.cellCount == 0, "heatmap cells survived tab leave")
assert(next(heatmap.cells) == nil, "heatmap cell table not released")
assert(#heatmap.artTiles == 0, "heatmap art tiles not released")

-- Reopen creates a fresh pool, then closing the window releases transient caches.
module:SetTab("heatmap")
module:RefreshHeatmap()
assert(heatmap.cellCount > 0, "heatmap cells did not rebuild")
module:CloseUI()
stats = module:GetCacheStats()
assert(stats.uiCells == 0 and stats.uiArtTiles == 0, "UI pool survived close")
assert(stats.blockZones == 0, "block cache survived close")
assert(stats.heatmapZones == 0, "heatmap zone cache survived close")
assert(stats.normalizeZones == 0, "normalize cache survived close")
assert(stats.overlayCaches == 0, "overlay cache survived close")

-- Releasing caches must not delete stored data.
assert(db.heatmaps["12"], "heatmap data deleted")
assert(db.journey and db.journey.blocks["map:201"], "block data deleted")
local cells = module:GetHeatmapZoneCells(12)
assert(cells and cells[1] == 2, "heatmap data unavailable after release")

print("Memory policy passed")
