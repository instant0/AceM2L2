-- Focused test for selected-zone heatmap blocks and bounded reads.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

db.mobs = {
  ["npc:3001"] = {
    npcID = 3001, name = "Heatmap Mob", classification = "normal",
    kills = 5, totalXP = 500, killsByMap = { ["12"] = 5 },
    killsByInstance = {}, contexts = {},
  },
}
db.heatmaps = {
  ["12"] = { cells = { [1] = 2, [2] = 6, [4096] = 1 }, lastSeen = 100 },
  ["13"] = { cells = { [5] = 4 }, lastSeen = 90 },
}
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()
assert(module:FlushJourneyBlocks(), "journey flush")

-- Zone metadata comes from the block index without decoding cells.
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
local zones = module:GetJourneyHeatmapZones()
assert(#zones == 2, "journey heatmap zone count")
assert(module.journeyDecodedBlocks == 0, "zone metadata decoded a block")

-- The selected zone decodes one block; a repeat uses the cache.
local cells, total = module:GetJourneyHeatmapCells(12)
assert(cells and cells[2].kills == 6 and total == 9, "journey cell decode")
assert(module.journeyDecodedBlocks == 1, "selected zone should decode once")
local cached = module:GetJourneyHeatmapCells("map:12")
assert(cached and cached[1].kills == 2, "journey cell cache")
assert(module.journeyDecodedBlocks == 1, "cache should not decode again")

-- Top cells use the Journey block while the flag is enabled.
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
local top = module:GetHeatmapTopCells(12, 2)
assert(#top == 2 and top[1].cell == 2 and top[1].kills == 6, "top cells")
assert(module.journeyDecodedBlocks == 1, "top cells should decode once")
module:GetHeatmapTopCells(12, 2)
assert(module.journeyDecodedBlocks == 1, "top cells should cache")

-- The UI selects the current zone and reads its cells from the block.
module:OpenUI()
module.heatmapZoneKey = nil
module:SetTab("heatmap")
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
module:RefreshHeatmap()
assert(module.journeyDecodedBlocks == 1, "heatmap UI should decode one block")
module:RefreshHeatmap()
assert(module.journeyDecodedBlocks == 1, "heatmap UI should reuse the cache")

-- A missing block falls back to the legacy cells without a failed read loop.
local savedBlock = db.journey.blocks["map:12"]
local savedIndex = db.journey.blockIndex["map:12"]
db.journey.blocks["map:12"] = nil
db.journey.blockIndex["map:12"] = nil
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
module:RefreshHeatmap()
assert(module.journeyDecodedBlocks == 0, "missing block should not decode")
db.journey.blocks["map:12"] = savedBlock
db.journey.blockIndex["map:12"] = savedIndex

-- Rollback uses legacy cells and never decodes.
db.journey.indexViews = false
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
module:RefreshHeatmap()
assert(module.journeyDecodedBlocks == 0, "rollback should not decode")
module:GetHeatmapTopCells(12, 2)
assert(module.journeyDecodedBlocks == 0, "rollback top cells should not decode")

print("Heatmap bounded query passed")
