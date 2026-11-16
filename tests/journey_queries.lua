-- Focused production test for read-only Journey queries.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()

assert(module:IsActive(), "Forever module should be active")
assert(type(module.GetBestZonesForLevel) == "function", "best-zone query missing")
assert(type(module.GetHeatmapTopCells) == "function", "heatmap query missing")

local db = module.char
db.journey = db.journey or {}
db.journey.zones = {
  ["12"] = {
    kills = 5, killXP = 100000, questXP = 200000, otherXP = 0, xp = 300000,
    presenceSeconds = 3600, engagedSeconds = 3600, deaths = 1, sessions = 1,
    levels = {
      ["20"] = {
        kills = 5, killXP = 100000, questXP = 200000, otherXP = 0, xp = 300000,
        presenceSeconds = 3600, engagedSeconds = 3600, deaths = 1,
      },
    },
  },
  ["13"] = {
    kills = 9, killXP = 250000, questXP = 0, otherXP = 0, xp = 250000,
    presenceSeconds = 3600, engagedSeconds = 3600, deaths = 0, sessions = 1,
    levels = {
      ["20"] = {
        kills = 9, killXP = 250000, questXP = 0, otherXP = 0, xp = 250000,
        presenceSeconds = 3600, engagedSeconds = 3600, deaths = 0,
      },
    },
  },
  ["14"] = {
    kills = 1, killXP = 10000, questXP = 0, otherXP = 0, xp = 10000,
    presenceSeconds = 600, engagedSeconds = 600, deaths = 0, sessions = 1,
    levels = {
      ["20"] = {
        kills = 1, killXP = 10000, questXP = 0, otherXP = 0, xp = 10000,
        presenceSeconds = 600, engagedSeconds = 600, deaths = 0,
      },
    },
  },
}

local total = module:GetBestZonesForLevel(20, "total")
local kill = module:GetBestZonesForLevel(20, "kill")
assert(total[1].zoneKey == "12", "total XP/hour rank")
assert(kill[1].zoneKey == "13", "kill-only XP/hour rank")
assert(total[1].xpPerHour == 300000, "total XP/hour value")
assert(kill[1].killXPPerHour == 250000, "kill-only XP/hour value")
assert(total[1].confidence == "medium", "confidence from engaged time")

db.areas = db.areas or {}
db.areas["12"] = 10
local zone = module:GetJourneyZoneStats("12")
assert(zone.kills == 15, "legacy zone kills merged")
assert(zone.questXP == 200000, "zone quest XP")

db.heatmaps = db.heatmaps or {}
db.heatmaps["12"] = { cells = { [1] = 10, [2] = 30, [3] = 20 } }
local cells = module:GetHeatmapTopCells("12", 2)
assert(#cells == 2, "heatmap top count")
assert(cells[1].cell == 2 and cells[1].kills == 30, "heatmap top cell")
assert(cells[1].share > 0.4, "heatmap share")

db.mobs = db.mobs or {}
db.mobs["npc:123"] = {
  npcID = 123, name = "Test Mob", classification = "normal",
  kills = 5, totalXP = 500, lastSeen = 100,
  killsByMap = { ["12"] = 5 },
}
local mob = module:GetMobJourneySummary("npc:123")
assert(mob and mob.name == "Test Mob" and mob.kills == 5, "mob summary")
assert(mob.zones[1] == "map:12", "mob zone ref")

db.quests = db.quests or {}
db.quests["quest:55"] = {
  id = 55, name = "Query Quest", count = 1, totalXP = 500,
  lastSeen = 100, lastTurnInAt = 100, mapID = 12, playerLevel = 20,
}
local quest = module:GetQuestAnchor(55)
assert(quest and quest.name == "Query Quest" and quest.lastTurnInAt == 100,
  "quest anchor")

state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()
local time = module:GetJourneyTimeSummary()
assert(time and time.zone == "12" and time.level == 20, "journey time summary")

print("Journey queries passed")
