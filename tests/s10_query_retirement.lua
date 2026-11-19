-- DS-17.21 S10A query read retirement test.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

db.journey = db.journey or {}
db.journey.zones = {
  ["12"] = {
    kills = 10, killXP = 1000, questXP = 50, otherXP = 0, xp = 1050,
    presenceSeconds = 600, engagedSeconds = 300, deaths = 2, sessions = 1,
    levels = {
      ["20"] = {
        kills = 10, killXP = 1000, questXP = 50, otherXP = 0, xp = 1050,
        presenceSeconds = 600, engagedSeconds = 300,
      },
    },
  },
}
db.journey.instances = {
  ["id:7:1"] = {
    name = "V2 Instance", kills = 5, killXP = 500, xp = 500,
    playerLevels = { ["20"] = { kills = 5 } },
  },
}
db.journey.levels = {
  ["20"] = {
    kills = 10, killXP = 1000, questXP = 50, otherXP = 0, xp = 1050,
    presenceSeconds = 600, engagedSeconds = 300,
  },
}
db.journey.heatmaps = {
  ["12"] = {
    mapID = 12, gridSize = 64, total = 10,
    cells = { [1] = { kills = 4 }, [2] = { kills = 6 } },
    lastSeen = 100,
  },
}
db.journey.mobs = {
  ["npc:1"] = {
    npcID = 1, name = "V2 Mob", classification = "normal",
    kills = 10, xp = 1000, lastSeen = 100,
    byZone = { ["12"] = { kills = 10, playerLevels = { ["20"] = { kills = 10 } } } },
    byInstance = {},
  },
}
db.journey.quests = {
  ["quest:5"] = {
    id = 5, count = 1, xp = 50, lastSeen = 100,
    lastTurnInAt = 100, mapID = 12, playerLevel = 20,
  },
  ["quest:6"] = {
    id = 6, count = 2, xp = 80, lastSeen = 90,
    lastTurnInAt = 90, mapID = 12, playerLevel = 20,
  },
}
db.journey.questAnchors = {
  { questID = 5, mapID = 12, at = 100, playerLevel = 20, xp = 50 },
  { questID = 6, mapID = 12, at = 90, playerLevel = 20, xp = 40 },
}
db.quests = {
  ["quest:5"] = { id = 5, name = "Ledger Quest" },
  ["quest:6"] = { id = 6, name = "Second Quest" },
}

-- Remove aggregate legacy roots; only the quest name ledger remains.
db.mobs, db.areas, db.levels, db.instances = nil, nil, nil, nil
db.areaLevels, db.heatmaps = nil, nil
module:InvalidateMobIndex()

local zone = assert(module:GetJourneyZoneStats(12))
assert(zone.kills == 10 and zone.xp == 1050 and zone.deaths == 2, "zone stats")
assert(zone.legacyKills == nil, "zone stats kept legacy field")

local level = assert(module:GetJourneyLevelStats(20))
assert(level.kills == 10 and level.xp == 1050, "level stats")
assert(level.legacyKills == nil, "level stats kept legacy field")

local areaRows = module:GetAreaRows()
assert(#areaRows == 2, "area rows")
assert(areaRows[1].kind == "area" and areaRows[1].kills == 10, "map row")
assert(areaRows[2].kind == "instance" and areaRows[2].label == "V2 Instance",
  "instance row")
assert(module:GetAreaKillCount(12) == 10, "area kill count")

local levelRows = module:GetLevelRows()
assert(#levelRows == 1 and levelRows[1].level == 20 and levelRows[1].kills == 10,
  "level rows")
assert(module:GetLevelKillCount(20) == 10, "level kill count")

local topKills, topKey = module:GetTopAreaSummary()
assert(topKills == 10 and tostring(topKey) == "12", "top area")
local minLevel, maxLevel, topLevel = module:GetLevelSummary()
assert(minLevel == 20 and maxLevel == 20 and topLevel == 20, "level summary")

local topCells = module:GetHeatmapTopCells(12, 2)
assert(#topCells == 2 and topCells[1].cell == 2 and topCells[1].kills == 6,
  "heatmap top cells")

local mob = assert(module:GetMobJourneySummary("npc:1"))
assert(mob.source == "v2" and mob.kills == 10 and mob.zones[1] == "map:12",
  "mob summary")

local quest = assert(module:GetQuestAnchor(5))
assert(quest.name == "Ledger Quest" and quest.xp == 50
  and quest.lastTurnInAt == 100, "quest anchor")
local anchors = module:GetQuestAnchors(12, 2)
assert(#anchors == 2 and anchors[1].questID == 5, "quest anchors")

-- The retired area/level rollback flag no longer changes the query path.
db.journey.indexViews = false
assert(#module:GetAreaRows() == 2, "area rows depend on flag")
assert(#module:GetLevelRows() == 1, "level rows depend on flag")
db.journey.indexViews = true
assert(#module:GetAreaRows() == 2, "area rows flag true")

-- Missing quest ledger falls back without reading legacy aggregates.
db.quests = nil
assert(module:GetQuestAnchor(5).name == nil, "quest ledger read")
assert(module:GetQuestAnchors(12, 2)[1].name:find("Quest 5", 1, true),
  "quest fallback name")

print("S10 query retirement passed")
