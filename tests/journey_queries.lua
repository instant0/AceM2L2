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

local zone = module:GetJourneyZoneStats("12")
assert(zone.kills == 5, "journey zone kills")
assert(zone.questXP == 200000, "zone quest XP")
db.journey.levels = {
  ["20"] = {
    kills = 9, killXP = 10000, questXP = 0, otherXP = 0, xp = 10000,
    presenceSeconds = 600, engagedSeconds = 600, deaths = 0,
  },
}
local level = module:GetJourneyLevelStats(20)
assert(level.kills == 9, "journey level kills")

db.journey.heatmaps = db.journey.heatmaps or {}
db.journey.heatmaps["12"] = {
  mapID = 12, gridSize = 64,
  cells = { [1] = { kills = 10 }, [2] = { kills = 30 }, [3] = { kills = 20 } },
  total = 60, lastSeen = 100,
}
local cells = module:GetHeatmapTopCells("12", 2)
assert(#cells == 2, "heatmap top count")
assert(cells[1].cell == 2 and cells[1].kills == 30, "heatmap top cell")
assert(cells[1].share > 0.4, "heatmap share")

db.journey.mobs = db.journey.mobs or {}
db.journey.mobs["npc:123"] = {
  npcID = 123, name = "Test Mob", classification = "normal",
  kills = 5, xp = 500, lastSeen = 100,
  byZone = { ["12"] = { kills = 5, playerLevels = {} } },
  byInstance = {},
}
local mob = module:GetMobJourneySummary("npc:123")
assert(mob and mob.name == "Test Mob" and mob.kills == 5, "mob summary")
assert(mob.zones[1] == "map:12", "mob zone ref")

db.journey.quests = db.journey.quests or {}
db.journey.quests["quest:55"] = {
  id = 55, count = 1, xp = 500, lastSeen = 100,
  lastTurnInAt = 100, mapID = 12, playerLevel = 20,
}
db.quests = db.quests or {}
db.quests["quest:55"] = { id = 55, name = "Query Quest" }
local quest = module:GetQuestAnchor(55)
assert(quest and quest.name == "Query Quest" and quest.lastTurnInAt == 100,
  "quest anchor")

-- Query reads do not depend on legacy aggregate roots.
db.mobs, db.areas, db.levels, db.instances, db.heatmaps = nil, nil, nil, nil, nil
assert(module:GetJourneyZoneStats("12").kills == 5, "v2 zone stats")
assert(module:GetJourneyLevelStats(20).kills == 9, "v2 level stats")
assert(module:GetAreaRows()[1].kills > 0, "v2 area rows")
assert(module:GetLevelRows()[1].kills > 0, "v2 level rows")
assert(#module:GetHeatmapTopCells("12", 2) == 2, "v2 heatmap")
assert(module:GetMobJourneySummary("npc:123").kills == 5, "v2 mob summary")
assert(module:GetQuestAnchor(55).lastTurnInAt == 100, "v2 quest anchor")
db.quests = nil
assert(module:GetQuestAnchor(55).name == nil, "quest name read legacy ledger")

state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()
local time = module:GetJourneyTimeSummary()
assert(time and time.zone == "12" and time.level == 20, "journey time summary")

print("Journey queries passed")
