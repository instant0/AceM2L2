-- Focused production test for Journey block storage.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

db.heatmaps = {
  ["12"] = { cells = { [1] = 3, [4096] = 2 }, lastSeen = 100 },
  ["13"] = { cells = { [5] = 1 }, lastSeen = 90 },
}
db.mobs = {
  ["npc:1001"] = {
    npcID = 1001, name = "Block Mob A", classification = "normal",
    kills = 5, totalXP = 500, killsByMap = { ["12"] = 5 },
    killsByInstance = {}, contexts = {},
  },
  ["npc:1002"] = {
    npcID = 1002, name = "Block Mob B", classification = "elite",
    kills = 7, totalXP = 700, killsByMap = { ["12"] = 2, ["13"] = 5 },
    killsByInstance = {}, contexts = {},
  },
  ["name:instance mob"] = {
    name = "Instance Mob", classification = "normal",
    kills = 4, totalXP = 400, killsByMap = {},
    killsByInstance = { ["id:33:1"] = 4 }, contexts = {},
  },
}

state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()

assert(module:FlushJourneyBlocks(), "journey flush failed")
local journey = db.journey
assert(journey.storageSchema == 2, "storage schema")
assert(type(journey.blocks["map:12"]) == "table", "map 12 block missing")
assert(type(journey.blocks["map:13"]) == "table", "map 13 block missing")
assert(type(journey.blocks["instance:id:33:1"]) == "table", "instance block missing")
assert((module.journeyDecodedBlocks or 0) == 0, "flush must not decode")

local records, err = module:GetJourneyBlock("map:12")
assert(records and records["npc:1001"], "map 12 decode: " .. tostring(err))
assert(records["npc:1001"].name == "Block Mob A", "mob name")
assert(records["npc:1001"].kills == 5, "mob kills")
assert(module.journeyDecodedBlocks == 1, "first decode count")

local cached = module:GetJourneyBlock("map:12")
assert(cached == records, "cache should reuse")
assert(module.journeyDecodedBlocks == 1, "cache should not decode again")

local mob, mobErr = module:GetJourneyBlockMob("map:12", "npc:1002")
assert(mob and mob.kills == 2, "block mob lookup: " .. tostring(mobErr))

-- Heatmap cells are stored in the zone block and read through the same cache.
assert(journey.blockIndex["map:12"].cellCount == 2, "heatmap cell count")
assert(journey.blockIndex["map:12"].heatmapKills == 5, "heatmap kill total")
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
local zones = module:GetJourneyHeatmapZones()
assert(#zones == 2, "journey heatmap zones")
assert(module.journeyDecodedBlocks == 0, "zone metadata must not decode")
local cells, cellTotal = module:GetJourneyHeatmapCells(12)
assert(cells and cells[1].kills == 3 and cellTotal == 5, "heatmap cell decode")
assert(module.journeyDecodedBlocks == 1, "selected heatmap should decode once")
local cachedCells = module:GetJourneyHeatmapCells("map:12")
assert(cachedCells and cachedCells[4096].kills == 2, "heatmap cache")
assert(module.journeyDecodedBlocks == 1, "heatmap cache should not decode again")

-- Dirty block rebuild.
db.mobs["npc:1001"].kills = 9
db.mobs["npc:1001"].killsByMap["12"] = 9
module:MarkJourneyDirty({ mapID = 12 })
module:ClearJourneyBlockCache()
assert(module:FlushJourneyBlocks(), "dirty flush")
local updated = assert(module:GetJourneyBlock("map:12"))
assert(updated["npc:1001"].kills == 9, "dirty block content")

-- Corrupt/missing fallback.
module:ClearJourneyBlockCache()
local saved = journey.blocks["map:12"].data
journey.blocks["map:12"].data = "not-base64"
local bad, badErr = module:GetJourneyBlock("map:12")
assert(bad == nil and badErr, "corrupt block should fail")
journey.blocks["map:12"].data = saved
local missing, missingErr = module:GetJourneyBlock("map:9999")
assert(missing == nil and missingErr == "missing", "missing block fallback")

-- Block-backed retrieval can serve without legacy mob records.
local legacyMobs = db.mobs
db.mobs = {}
module:ClearJourneyBlockCache()
local blockMob = module:GetJourneyMob("npc:1001")
assert(blockMob and blockMob.name == "Block Mob A", "block-backed mob lookup")
local blockZones = module:GetJourneyMobZones("npc:1001")
assert(#blockZones >= 1 and blockZones[1] == "map:12", "mob zone index")
local blockSummary = module:GetMobJourneySummary("npc:1001")
assert(blockSummary and blockSummary.source == "block", "summary block fallback")
assert(blockSummary.kills == 9, "summary block kills")
db.mobs = legacyMobs

print("Journey block storage passed")
