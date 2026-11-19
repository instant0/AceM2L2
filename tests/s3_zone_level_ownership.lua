-- DS-17.13 S3 zone/level ownership test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

module:ResetKills()
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()

db.mobs = {
  ["npc:5001"] = {
    npcID = 5001, name = "Zone Mob", classification = "normal",
    kills = 10, totalXP = 100,
    killsAtLevel = { ["20"] = 10 },
    killsByMap = { ["12"] = 10, ["13"] = 5 },
    killsByAreaLevel = {},
    killsByInstance = {}, killsByInstanceLevel = {}, contexts = {},
  },
}
db.areas = { ["12"] = 10, ["13"] = 5 }
db.areaLevels = {
  ["12"] = { ["20"] = 10 },
  ["13"] = { ["20"] = 5 },
}
db.levels = { ["20"] = 15 }
db.levelHistory = {
  { level = 20, startedAt = 1, endedAt = 2, xpGained = 500, kills = 15 },
}
db.unattributed = {
  events = 0, xp = 0, byLevel = {}, byMap = { ["12"] = 25, ["13"] = 10 },
  lastSeen = 0,
}
db.journey.zones = {
  ["12"] = {
    kills = 4, killXP = 40, questXP = 30, otherXP = 0, xp = 70,
    presenceSeconds = 100, engagedSeconds = 50, deaths = 1, sessions = 2,
    levels = { ["20"] = { kills = 4, xp = 40 } },
  },
  ["13"] = {
    kills = 2, killXP = 20, questXP = 5, otherXP = 0, xp = 25,
    presenceSeconds = 50, engagedSeconds = 25, deaths = 0, sessions = 1,
    levels = { ["20"] = { kills = 2, xp = 20 } },
  },
}
db.journey.levels = {
  ["20"] = {
    kills = 6, killXP = 60, questXP = 0, otherXP = 0, xp = 0,
    presenceSeconds = 100, engagedSeconds = 50,
  },
}

module:EnsureModelZones()
module:EnsureModelLevels()

local zone = module:GetModelZone(12)
assert(zone and zone.source == "v2", "zone v2 source")
assert(zone.kills == 10 and zone.killsExact, "zone kills")
assert(zone.playerLevels["20"].kills == 10, "zone player levels")
assert(zone.killXP == 100, "derived zone kill XP: " .. tostring(zone.killXP))
assert(zone.otherXP == 25 and zone.questXP == 30, "zone XP components")
assert(zone.xp == 155, "zone XP sum")
assert(zone.presenceSeconds == 100 and zone.engagedSeconds == 50, "zone time")
assert(zone.killXPCoverage == "derived" and zone.xpCoverage == "partial",
  "zone coverage")
assert(zone.timeCoverage == "post-instrumentation", "zone time coverage")

local zone13 = module:GetModelZone(13)
assert(zone13.kills == 5, "second zone kills")
assert(zone13.killXP == 50, "second zone derived XP")
assert(zone13.otherXP == 10 and zone13.xp == 65, "second zone XP")

local level = module:GetModelLevel(20)
assert(level and level.source == "v2", "level v2 source")
assert(level.kills == 15 and level.killsExact, "level kills")
assert(level.xp == 500, "level history XP fallback")
assert(level.xpCoverage == "level-history", "level XP coverage")
assert(level.startedAt == 1 and level.endedAt == 2, "level timestamps")
assert(level.presenceSeconds == 100, "level time")

-- Sync after a legacy change preserves Journey time and quest/other split.
db.areas["12"] = 20
db.areaLevels["12"]["20"] = 20
assert(module:SyncModelZoneFromLegacy(12), "zone sync")
local updated = module:GetModelZone(12)
assert(updated.kills == 20 and updated.playerLevels["20"].kills == 20,
  "zone sync counts")
assert(updated.presenceSeconds == 100 and updated.engagedSeconds == 50,
  "zone sync lost time")
assert(updated.questXP == 30 and updated.otherXP == 25, "zone sync lost XP parts")
assert(updated.xp == 155, "zone sync recomputed XP")

-- Bulk sync is idempotent.
module:SyncModelZonesFromLegacy()
local first = module:GetModelZone(12)
module:SyncModelZonesFromLegacy()
local second = module:GetModelZone(12)
assert(first.kills == second.kills and first.xp == second.xp, "zone bulk sync")

-- v2-only reads with legacy sources removed.
db.areas = nil
db.levels = nil
db.areaLevels = nil
db.levelHistory = nil
db.unattributed = nil
local onlyZone = module:GetModelZone(12)
local onlyLevel = module:GetModelLevel(20)
assert(onlyZone and onlyZone.kills == 20, "v2-only zone")
assert(onlyLevel and onlyLevel.kills == 15, "v2-only level")

print("S3 zone/level ownership passed")
