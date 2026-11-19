-- DS-17.20 S9 adaptive caps, retention, and archive policy test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local DAY = 86400
local function now()
  return 1760000000 + state.now
end

module:ResetKills()
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()

local journey = assert(db.journey)
journey.heatmaps = journey.heatmaps or {}
local source = {
  [1] = { kills = 1 },
  [2] = { kills = 2 },
  [65] = { kills = 3 },
  [4096] = { kills = 4 },
}
journey.heatmaps["12"] = {
  mapID = 12, gridSize = 64, cells = source, total = 10, lastSeen = 200,
  killsCoverage = "exact",
  cellXpCoverage = "unavailable",
  cellTimeCoverage = "unavailable",
}

local warm, warmTotal = module:DownsampleHeatmapCells(source, 64, 32)
local cold, coldTotal = module:DownsampleHeatmapCells(source, 64, 16)
assert(warmTotal == 10 and coldTotal == 10, "downsample total")
assert(warm[1].kills == 6 and warm[1024].kills == 4, "32x32 summary")
assert(cold[1].kills == 6 and cold[256].kills == 4, "16x16 summary")
assert(source[1].kills == 1 and source[2].kills == 2, "64x64 source mutated")

local summaries = module:UpdateJourneyHeatmapSummaries()
assert(summaries["12"].warm.gridSize == 32, "warm grid")
assert(summaries["12"].cold.gridSize == 16, "cold grid")
assert(summaries["12"].sourceGrid == 64, "source grid")
assert(summaries["12"].warm.total == 10 and summaries["12"].cold.total == 10,
  "summary totals")

-- Profiles are explicit 3/6/12-month policies.
assert(module:GetRetentionTierForAge(10 * DAY, "3m") == "hot", "3m hot")
assert(module:GetRetentionTierForAge(45 * DAY, "3m") == "warm", "3m warm")
assert(module:GetRetentionTierForAge(100 * DAY, "3m") == "cold", "3m cold")
assert(module:GetRetentionTierForAge(89 * DAY, "6m") == "hot", "6m hot")
assert(module:GetRetentionTierForAge(120 * DAY, "6m") == "warm", "6m warm")
assert(module:GetRetentionTierForAge(200 * DAY, "6m") == "cold", "6m cold")
assert(module:GetRetentionTierForAge(179 * DAY, "12m") == "hot", "12m hot")
assert(module:GetRetentionTierForAge(200 * DAY, "12m") == "warm", "12m warm")
assert(module:GetRetentionTierForAge(400 * DAY, "12m") == "cold", "12m cold")
assert(not module:SetRetentionProfile("unknown"), "invalid profile accepted")

-- Tier assignment: current zone is hot; old blocks move warm/cold.
journey.time.zone = "12"
local stamp = now()
local function fakeBlock()
  return { data = "x", checksum = 1, count = 0, cellCount = 0,
    updatedAt = stamp }
end
journey.blocks = {
  ["map:12"] = fakeBlock(),
  ["map:13"] = fakeBlock(),
  ["map:14"] = fakeBlock(),
  ["instance:id:1"] = fakeBlock(),
}
journey.blockIndex = {
  ["map:12"] = { lastSeen = stamp - DAY, updatedAt = stamp - DAY, count = 0 },
  ["map:13"] = { lastSeen = stamp - 100 * DAY, updatedAt = stamp - 100 * DAY, count = 0 },
  ["map:14"] = { lastSeen = stamp - 300 * DAY, updatedAt = stamp - 300 * DAY, count = 0 },
  ["instance:id:1"] = { lastSeen = stamp - 100 * DAY, updatedAt = stamp - 100 * DAY, count = 0 },
}
journey.retentionProfile = nil
module:SetRetentionProfile("6m")
local applied = module:ApplyJourneyRetention()
assert(applied.profile.key == "6m", "retention profile")
assert(journey.blockIndex["map:12"].tier == "hot", "current zone tier")
assert(journey.blockIndex["map:13"].tier == "warm", "warm tier")
assert(journey.blockIndex["map:14"].tier == "cold", "cold tier")
assert(journey.blockIndex["instance:id:1"].tier == "warm", "instance tier")
assert(journey.blocks["map:14"].contextMode == "collapsed", "cold context mode")
assert(journey.retention.blocks.hot == 1 and journey.retention.blocks.warm == 2
  and journey.retention.blocks.cold == 1, "retention counts")
assert(journey.dirtyZones["map:13"] and journey.dirtyZones["map:14"],
  "tier changes did not mark dirty")

local stats = module:GetRetentionStats()
assert(stats.blockCount == 4 and stats.blockBytes == 4, "retention block stats")
assert(stats.summaries == 1 and stats.summaryCells > 0, "summary stats")
local dataStats = module:GetDataStats()
assert(dataStats.retention and dataStats.retention.profile == "6m",
  "diagnostics retention")

module:SetRetentionProfile("3m")
module:ApplyJourneyRetention()
assert(journey.blockIndex["map:13"].tier == "cold", "3m reclassification")
assert(journey.blockIndex["instance:id:1"].tier == "cold", "3m instance")

module:SetRetentionProfile("12m")
module:ApplyJourneyRetention()
assert(journey.blockIndex["map:13"].tier == "hot", "12m recent hot")
assert(journey.blockIndex["map:14"].tier == "warm", "12m old warm")
assert(journey.blockIndex["map:12"].tier == "hot", "12m current")

module:SetRetentionProfile("6m")

-- Cold blocks collapse contexts to top-8 + other; hot blocks keep all.
local contexts = {}
for index = 1, 10 do
  contexts["ctx" .. index] = {
    playerLevel = 20, mobLevel = 20 + index, groupSize = 1, mapID = 12,
    classification = "elite", buffSig = "none", samples = 11 - index,
    sumBase = 100 + index, sumBuffed = 150 + index,
    sumTotal = 250 + index * 2, minBase = 10 + index, maxBase = 20 + index,
    lastSeen = 100 + index,
  }
end
db.mobs = {
  ["npc:9001"] = {
    npcID = 9001, name = "Archive Mob", classification = "elite",
    kills = 10, totalXP = 1000, killsAtLevel = { ["20"] = 10 },
    killsByMap = { ["12"] = 10 },
    killsByAreaLevel = { ["12"] = { ["20"] = 10 } },
    killsByInstance = {}, contexts = contexts,
    firstSeen = 10, lastSeen = 200,
  },
}
db.areas = { ["12"] = 10 }
db.areaLevels = { ["12"] = { ["20"] = 10 } }
module:SyncModelMobsFromLegacy()
module:SyncModelZonesFromLegacy()
db.mobs = nil
db.areas = nil
db.areaLevels = nil

journey.time.zone = "99"
journey.heatmaps["12"].lastSeen = stamp - 300 * DAY
journey.blockIndex["map:12"] = {
  lastSeen = stamp - 300 * DAY, updatedAt = stamp - 300 * DAY,
}
journey.blocks["map:12"] = fakeBlock()
module:MarkJourneyDirty({ mapID = 12 })
module:ClearJourneyBlockCache()
assert(module:FlushJourneyBlocks(), "cold block flush")
local coldData = assert(module:GetJourneyBlockData("map:12"))
assert(coldData.schema == 3, "cold block schema")
assert(#coldData.records["npc:9001"].contexts == 9, "cold contexts not collapsed")
assert(coldData.records["npc:9001"].contexts[9].key == "other",
  "cold context other")
assert(coldData.records["npc:9001"].contextsOther.samples == 3,
  "cold context samples")
assert(journey.blocks["map:12"].tier == "cold", "cold block tier")

journey.time.zone = "12"
module:MarkJourneyDirty({ mapID = 12 })
module:ClearJourneyBlockCache()
assert(module:FlushJourneyBlocks(), "hot block flush")
local hotData = assert(module:GetJourneyBlockData("map:12"))
assert(#hotData.records["npc:9001"].contexts == 10, "hot contexts collapsed")
assert(journey.blocks["map:12"].tier == "hot", "hot block tier")
assert(hotData.records["npc:9001"].totalKills == 10, "hot block totals")

-- Compaction keeps blocks and indexes aligned.
journey.blockIndex["map:77"] = { lastSeen = stamp, count = 0 }
journey.blocks["map:78"] = { data = 12, checksum = 1 }
journey.blocks["map:79"] = { data = "x", checksum = 1, count = 0,
  cellCount = 0, updatedAt = stamp }
module:ClearJourneyBlockCache()
local compacted = module:CompactJourneyBlocks()
assert(compacted.removedIndex == 1, "stale index not removed")
assert(compacted.removedBlocks == 1, "invalid block not removed")
assert(compacted.rebuiltIndex == 1, "missing index not rebuilt")
assert(journey.blockIndex["map:77"] == nil, "stale index remains")
assert(journey.blocks["map:78"] == nil, "invalid block remains")
assert(journey.blocks["map:79"] and journey.blockIndex["map:79"],
  "valid block/index pair lost")

-- No blanket cap or MB limit was introduced.
assert(module.RETENTION_SOURCE_GRID == 64, "source grid changed")
assert(module.RETENTION_WARM_GRID == 32, "warm grid changed")
assert(module.RETENTION_COLD_GRID == 16, "cold grid changed")
assert(module:GetMobCapacityLimit() >= 2000, "adaptive mob cap changed")
assert(journey.heatmaps["12"].total == 10, "archive double counted heatmap")
assert(source[1].kills == 1, "archive mutated durable cells")

print("S9 caps/archive passed")
