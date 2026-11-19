-- DS-17.19 S8 block payload v2 completeness test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function varint(value)
  value = math.floor(tonumber(value) or 0)
  if value < 0 then value = 0 end
  local parts = {}
  repeat
    local byte = value % 128
    value = math.floor(value / 128)
    if value > 0 then byte = byte + 128 end
    parts[#parts + 1] = string.char(byte)
  until value == 0
  return table.concat(parts)
end

local function writeString(parts, value)
  local text = tostring(value or "")
  parts[#parts + 1] = varint(#text)
  parts[#parts + 1] = text
end

local function checksum(text)
  local sum = #text % 65521
  for index = 1, #text do
    sum = (sum + string.byte(text, index) * (index % 251 + 1)) % 65521
  end
  return sum
end

local function base64Encode(text)
  local out = {}
  for index = 1, #text, 3 do
    local a = string.byte(text, index) or 0
    local b = string.byte(text, index + 1) or 0
    local c = string.byte(text, index + 2) or 0
    local value = a * 65536 + b * 256 + c
    local c1 = math.floor(value / 262144) % 64
    local c2 = math.floor(value / 4096) % 64
    local c3 = math.floor(value / 64) % 64
    local c4 = value % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (index + 1 <= #text and B64:sub(c3 + 1, c3 + 1) or "=")
      .. (index + 2 <= #text and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end

local function oldBlock(schema)
  local parts = { varint(schema), varint(1) }
  writeString(parts, "map:" .. tostring(90 + schema))
  parts[#parts + 1] = varint(1)
  writeString(parts, "npc:1")
  parts[#parts + 1] = varint(101)
  writeString(parts, "Old Mob")
  writeString(parts, "normal")
  parts[#parts + 1] = varint(2)
  parts[#parts + 1] = varint(20)
  parts[#parts + 1] = varint(1)
  parts[#parts + 1] = varint(2)
  if schema >= 2 then
    parts[#parts + 1] = varint(1)
    parts[#parts + 1] = varint(7)
    parts[#parts + 1] = varint(3)
    parts[#parts + 1] = varint(0)
    parts[#parts + 1] = varint(0)
    parts[#parts + 1] = varint(0)
  end
  local raw = table.concat(parts)
  return {
    data = base64Encode(raw),
    checksum = checksum(raw),
    count = 1,
    cellCount = schema >= 2 and 1 or 0,
  }
end

module:ResetKills()
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()

local contexts = {}
for index = 1, 10 do
  contexts["ctx" .. index] = {
    playerLevel = 20,
    mobLevel = 20 + index,
    groupSize = 1,
    mapID = 12,
    classification = "elite",
    buffSig = "none",
    samples = 11 - index,
    sumBase = 100 + index,
    sumBuffed = 150 + index,
    sumTotal = 250 + index * 2,
    minBase = 10 + index,
    maxBase = 20 + index,
    lastSeen = 100 + index,
  }
end

db.mobs = {
  ["npc:9001"] = {
    npcID = 9001, name = "S8 Mob", classification = "elite",
    kills = 10, totalXP = 1000,
    killsAtLevel = { ["20"] = 10 },
    killsByMap = { ["12"] = 6 },
    killsByAreaLevel = { ["12"] = { ["20"] = 6 } },
    killsByInstance = {},
    contexts = contexts,
    firstSeen = 10, lastSeen = 200,
  },
  ["npc:9002"] = {
    npcID = 9002, name = "S8 Add", classification = "normal",
    kills = 4, totalXP = 400,
    killsAtLevel = { ["20"] = 4 },
    killsByMap = { ["12"] = 4 },
    killsByAreaLevel = { ["12"] = { ["20"] = 4 } },
    killsByInstance = {},
    contexts = {},
    firstSeen = 20, lastSeen = 190,
  },
  ["name:instance mob"] = {
    name = "Instance Mob", classification = "normal",
    kills = 5, totalXP = 500,
    killsAtLevel = { ["20"] = 5 },
    killsByMap = {},
    killsByInstance = { ["id:33:1"] = 5 },
    killsByInstanceLevel = { ["id:33:1"] = { ["20"] = 5 } },
    contexts = {},
    firstSeen = 30, lastSeen = 180,
  },
}
db.areas = { ["12"] = 10 }
db.areaLevels = { ["12"] = { ["20"] = 10 } }
db.instances = {
  ["id:33:1"] = {
    name = "S8 Instance", instanceType = "party", instanceID = 33,
    difficultyID = 1, mapID = 12, kills = 5, killXP = 500, xp = 500,
    killsAtLevel = { ["20"] = 5 }, firstSeen = 30, lastSeen = 180,
  },
}
db.heatmaps = {
  ["12"] = {
    gridSize = 64,
    cells = { [1] = 3, [2] = 2 },
    total = 5,
    lastSeen = 200,
  },
}

module:SyncModelMobsFromLegacy()
module:SyncModelZonesFromLegacy()
module:SyncModelInstancesFromLegacy()
module:SyncModelHeatmapsFromLegacy()

local journeys = db.journey
local zone = journeys.zones["12"]
zone.presenceSeconds = 120
zone.engagedSeconds = 60
zone.levels["20"] = {
  kills = 10, xp = 1000, presenceSeconds = 30, engagedSeconds = 10,
}
zone.deaths = 2
zone.sessions = 3
zone.questXP = 50
zone.xp = zone.killXP + zone.questXP + zone.otherXP
zone.questXPCoverage = "post-instrumentation"
zone.xpCoverage = "partial"
zone.timeCoverage = "post-instrumentation"
zone.deathCoverage = "post-instrumentation"
zone.sessionCoverage = "post-instrumentation"

local instance = journeys.instances["id:33:1"]
instance.presenceSeconds = 90
instance.engagedSeconds = 45
instance.deaths = 1
instance.sessions = 2
instance.timeCoverage = "post-instrumentation"
instance.deathCoverage = "post-instrumentation"
instance.sessionCoverage = "post-instrumentation"

-- Encoding must use the v2 roots. Remove every legacy source first.
db.mobs = nil
db.areas = nil
db.areaLevels = nil
db.instances = nil
db.heatmaps = nil

assert(module:FlushJourneyBlocks(), "block flush")
assert(journeys.storageSchema == 3, "block storage schema")
assert(journeys.schema == 2, "data schema changed")
assert(journeys.blocks["map:12"].schema == 3, "block header schema")

local data = assert(module:GetJourneyBlockData("map:12"))
assert(data.schema == 3, "decoded schema")
local mob = assert(data.records["npc:9001"])
assert(mob.name == "S8 Mob" and mob.npcID == 9001, "mob identity")
assert(mob.classification == "elite", "mob classification")
assert(mob.totalKills == 10 and mob.totalXP == 1000, "mob globals")
assert(mob.kills == 6 and mob.xp == 600, "mob zone totals")
assert(mob.mobLevelMin == 21 and mob.mobLevelMax == 30, "mob level range")
assert(mob.mobLevelSamples == 10, "mob level samples")
assert(mob.firstSeen == 10 and mob.lastSeen == 200, "mob first/last")
assert(mob.byPlayerLevel["20"].kills == 10, "global player levels")
assert(mob.playerLevels["20"].kills == 6, "zone player levels")
assert(#mob.contexts == 10 and #mob.combat == 10 and #mob.xpContexts == 10,
  "context arrays")
assert(#mob.contextsTop8 == 8, "top-8 contexts")
assert(mob.contextsOther.key == "other"
  and mob.contextsOther.samples == 3, "other context")
assert(mob.contexts[1].key == "ctx1" and mob.contexts[1].samples == 10,
  "context order")
assert(mob.contexts[1].minBase == 11 and mob.contexts[1].maxBase == 21,
  "context min/max")
assert(mob.combat[1].healthKnown == false, "combat health coverage")
assert(data.records["name:instance mob"] == nil,
  "map block duplicated an instance-only mob")

local summary = assert(data.zone)
assert(summary.kind == "map", "zone kind")
local zoneRecord = summary.record
assert(zoneRecord.kills == 10 and zoneRecord.killXP == 1000, "zone XP")
assert(zoneRecord.questXP == 50 and zoneRecord.xp == zoneRecord.killXP + 50
  + zoneRecord.otherXP, "zone total XP")
assert(zoneRecord.presenceSeconds == 120 and zoneRecord.engagedSeconds == 60,
  "zone time")
assert(zoneRecord.deaths == 2 and zoneRecord.sessions == 3, "zone deaths/sessions")
assert(zoneRecord.playerLevels["20"].kills == 10, "zone levels")
assert(zoneRecord.playerLevels["20"].xp == 1000
  and zoneRecord.playerLevels["20"].presenceSeconds == 30
  and zoneRecord.playerLevels["20"].engagedSeconds == 10,
  "zone level XP/time merge")
assert(zoneRecord.xpCoverage == "partial"
  and zoneRecord.timeCoverage == "post-instrumentation", "zone coverage")
assert(journeys.blockIndex["map:12"].hasZone == true
  and journeys.blockIndex["map:12"].zoneKills == 10, "zone index")

assert(data.heatmap and data.heatmap.cells[1].kills == 3
  and data.heatmap.cells[2].kills == 2, "heatmap cells")
assert(data.heatmap.cells[1].xp == nil
  and data.heatmap.cells[1].presenceSeconds == nil, "heatmap absent XP/time")
assert(data.heatmap.total == 5 and data.heatmap.gridSize == 64,
  "heatmap metadata")
assert(data.heatmap.killsCoverage == "exact"
  and data.heatmap.cellXpCoverage == "unavailable"
  and data.heatmap.cellTimeCoverage == "unavailable", "heatmap coverage")

local cells, cellTotal = module:GetJourneyHeatmapCells(12)
assert(cells[1].kills == 3 and cellTotal == 5, "heatmap read path")
assert(cells[1].xp == nil, "heatmap read invented XP")

local instanceData = assert(module:GetJourneyBlockData("instance:id:33:1"))
local instanceSummary = assert(instanceData.zone)
assert(instanceSummary.kind == "instance", "instance kind")
assert(instanceSummary.record.name == "S8 Instance", "instance name")
assert(instanceSummary.record.kills == 5, "instance kills")
assert(instanceSummary.record.presenceSeconds == 90
  and instanceSummary.record.engagedSeconds == 45, "instance time")
assert(instanceSummary.record.deaths == 1 and instanceSummary.record.sessions == 2,
  "instance deaths/sessions")
local instanceMob = assert(instanceData.records["name:instance mob"])
assert(instanceMob.totalKills == 5 and instanceMob.kills == 5,
  "instance mob totals")
assert(instanceMob.playerLevels["20"].kills == 5, "instance player levels")

-- Dirty rebuild reads the updated v2 root, not legacy.
local modelMob = journeys.mobs["npc:9001"]
modelMob.kills = 11
modelMob.xp = 1100
modelMob.byZone["12"].kills = 7
journeys.zones["12"].kills = 11
module:MarkJourneyDirty({ mapID = 12 })
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
assert(module:FlushJourneyBlocks(), "dirty flush")
assert(module.journeyDecodedBlocks == 0, "flush decoded a block")
local rebuilt = assert(module:GetJourneyBlockData("map:12"))
assert(rebuilt.records["npc:9001"].totalKills == 11
  and rebuilt.records["npc:9001"].kills == 7, "dirty mob content")
assert(rebuilt.zone.record.kills == 11, "dirty zone content")

-- Zone-only blocks survive heatmap clearing; heatmap cells do not.
journeys.zones["14"] = {
  kills = 1, killXP = 10, questXP = 0, otherXP = 0, xp = 10,
  presenceSeconds = 5, engagedSeconds = 0, deaths = 0, sessions = 1,
  playerLevels = {}, lastSeen = 250, xpCoverage = "partial",
}
module:MarkJourneyDirty({ mapID = 14 })
assert(module:FlushJourneyBlocks(), "zone-only flush")
assert(journeys.blockIndex["map:14"].hasZone == true, "zone-only index")

module:ClearHeatmaps()
module:ClearJourneyBlockCache()
assert(module:FlushJourneyBlocks(), "post-clear flush")
assert(journeys.blocks["map:14"] and journeys.blocks["map:12"],
  "zone-bearing blocks deleted on heatmap clear")
local clearedMap = assert(module:GetJourneyBlockData("map:12"))
assert(clearedMap.zone.record.kills == 11, "map block lost zone after clear")
assert(next(clearedMap.cells) == nil, "cleared heatmap cells remained")
local zoneOnly = assert(module:GetJourneyBlockData("map:14"))
assert(zoneOnly.zone.record.kills == 1, "zone-only block content")

-- Schema 1/2 blocks still decode with their old shape.
for schema = 1, 2 do
  local key = "map:" .. tostring(90 + schema)
  journeys.blocks[key] = oldBlock(schema)
  journeys.dirtyZones[key] = nil
  module:ClearJourneyBlockCache()
  local old = assert(module:GetJourneyBlockData(key))
  assert(old.schema == schema, "old schema " .. schema)
  assert(old.records["npc:1"].kills == 2, "old mob schema " .. schema)
  assert(old.zone == nil, "old block invented zone schema " .. schema)
  if schema == 1 then
    assert(next(old.cells) == nil, "schema 1 cells")
  else
    assert(old.cells[7].kills == 3 and old.cells[7].xp == 0, "schema 2 cells")
  end
end

-- Corrupt blocks still fail safely.
local brokenKey = "map:12"
local saved = journeys.blocks[brokenKey].data
journeys.blocks[brokenKey].data = "not-base64"
module:ClearJourneyBlockCache()
local broken, brokenErr = module:GetJourneyBlockData(brokenKey)
assert(broken == nil and brokenErr, "corrupt block accepted")
journeys.blocks[brokenKey].data = saved
module:ClearJourneyBlockCache()
assert(module:GetJourneyBlockData(brokenKey), "corrupt block restore")

assert(AceM2L2CharDB.xpTooltip.storageSchema == 2, "root storage schema changed")

print("S8 block payload passed")
