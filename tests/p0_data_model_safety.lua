-- Focused DS-17.8 P0 data-model safety regressions.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local function reset()
  module:ResetKills()
  state.mapID = 12
  state.playerLevel = 20
  state.now = 100
  module:OnJourneyEnterWorld()
end

local function mobile(kills, maps)
  local byMap = {}
  for _, mapID in ipairs(maps or { "12" }) do byMap[tostring(mapID)] = kills end
  return {
    npcID = 5001, name = "P0 Mob", classification = "normal",
    kills = kills, totalXP = kills * 10,
    killsByMap = byMap, killsByInstance = {}, contexts = {},
  }
end

-- P0-1: legacy-empty dirty flush must not delete an existing block.
reset()
db.heatmaps = { ["12"] = { cells = { [1] = 3 }, total = 3, lastSeen = 100 } }
db.mobs = { ["npc:5001"] = mobile(3) }
assert(module:FlushJourneyBlocks(), "initial flush")
local journey = db.journey
local original = journey.blocks["map:12"]
local originalIndex = journey.blockIndex["map:12"]
assert(original and originalIndex, "initial block missing")
db.mobs = {}
db.heatmaps = {}
module:MarkJourneyDirty({ mapID = 12 })
assert(module:FlushJourneyBlocks(), "legacy-empty flush")
assert(journey.blocks["map:12"] == original, "legacy-empty flush deleted block")
assert(journey.blockIndex["map:12"] == originalIndex,
  "legacy-empty flush changed block index")

-- P0-3: clear/cap must not expose stale Journey zones; heatmap-only blocks go.
reset()
journey = db.journey
db.heatmaps = {
  ["12"] = { cells = { [1] = 3 }, total = 3, lastSeen = 100 },
  ["13"] = { cells = { [5] = 1 }, total = 1, lastSeen = 90 },
}
db.mobs = { ["npc:5001"] = mobile(3, { "12" }) }
assert(module:FlushJourneyBlocks(), "flush with heatmap-only zone")
assert(journey.blocks["map:12"] and journey.blocks["map:13"],
  "expected blocks")
module:ClearHeatmaps()
assert(journey.blocks["map:12"], "mob-bearing block was deleted on clear")
assert(not journey.blocks["map:13"], "heatmap-only block survived clear")
assert(journey.blockIndex["map:12"].heatmapKills == 0,
  "heatmap index survived clear")
assert(#module:GetJourneyHeatmapZones() == 0, "stale journey zone after clear")

-- Cap/removal sync acts like a dropped legacy map.
reset()
journey = db.journey
db.heatmaps = {
  ["12"] = { cells = { [1] = 3 }, total = 3, lastSeen = 100 },
  ["13"] = { cells = { [5] = 1 }, total = 1, lastSeen = 90 },
}
db.mobs = { ["npc:5001"] = mobile(3, { "12" }) }
assert(module:FlushJourneyBlocks(), "flush before cap simulation")
db.heatmaps["13"] = nil
module:SyncJourneyHeatmapIndex()
assert(not journey.blocks["map:13"], "capped heatmap-only block survived")
assert(journey.blockIndex["map:13"] == nil, "capped index survived")

-- P0-4: a Journey-only/legacy-nil cell set must not error the command.
reset()
journey = db.journey
db.heatmaps = { ["12"] = { cells = { [1] = 3 }, total = 3, lastSeen = 100 } }
db.mobs = { ["npc:5001"] = mobile(3) }
assert(module:FlushJourneyBlocks(), "flush before command fallback")
module:ClearJourneyBlockCache()
local originalZones = module.GetHeatmapZones
module.GetHeatmapZones = function()
  return { {
    mapID = 12, key = "map:12", gridSize = 64, total = 3,
    lastSeen = 100, cells = nil, journeySource = true,
  } }
end
local ok, err = pcall(module.PrintHeatmap, module, "Westfall")
module.GetHeatmapZones = originalZones
assert(ok, "PrintHeatmap errored: " .. tostring(err))

-- P0-5: mob zone refs are capped for cold fallback.
reset()
journey = db.journey
db.heatmaps = {}
db.mobs = { ["npc:5001"] = mobile(6, { 12, 13, 14, 15, 16, 17 }) }
assert(module:FlushJourneyBlocks(), "flush for zone cap")
local refs = module:GetJourneyMobZones("npc:5001")
assert(#refs <= 4, "mob zone refs not capped: " .. tostring(#refs))

-- P0-6: decode counter/cache reset per session.
module.journeyDecodedBlocks = 99
module.journeyBlockCache = { map = { ["map:12"] = {} }, order = { "map:12" } }
module:StartSession()
assert(module.journeyDecodedBlocks == 0, "decode counter not reset")
assert(next(module.journeyBlockCache.map) == nil, "block cache not cleared")

-- P0-7: Journey data-model schema aligns with storage schema.
db.journey.schema = 1
local ensured = module:EnsureJourney()
local storage = module:EnsureJourneyStorage()
assert(ensured.schema == 2, "journey data schema not aligned")
assert(storage.storageSchema == 2, "storage schema changed")

print("P0 data-model safety passed")
