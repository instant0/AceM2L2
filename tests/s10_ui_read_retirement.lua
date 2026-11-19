-- DS-17.22 S10B UI read retirement test.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char
local state = F.state

state.now = 1000
local now = module.Util.Epoch()
db.journey = db.journey or {}
db.journey.mobs = {
  ["npc:1"] = {
    npcID = 1, name = "V2 Alpha", classification = "elite",
    kills = 20, xp = 1000, sessionKills = 2,
    firstSeen = now - 1000, lastSeen = now - 10,
    byPlayerLevel = { ["10"] = { kills = 20, xp = 1000, samples = 20 } },
    byZone = { ["12"] = { kills = 20, playerLevels = { ["10"] = { kills = 20 } } } },
    byInstance = {},
    contexts = {},
    xpStats = { samples = 20, sumBase = 900, sumTotal = 1000 },
    mobLevelMin = 10, mobLevelMax = 12,
  },
}
db.journey.zones = {
  ["12"] = {
    kills = 20, killXP = 1000, questXP = 50, otherXP = 0, xp = 1050,
    presenceSeconds = 600, engagedSeconds = 300, deaths = 0, sessions = 1,
    playerLevels = { ["10"] = { kills = 20 } },
  },
}
db.journey.instances = {
  ["id:9:1"] = {
    name = "V2 Instance", instanceType = "party", kills = 5, xp = 500,
    killXP = 500, questXP = 0, otherXP = 0, sessions = 1, deaths = 0,
    playerLevels = { ["10"] = { kills = 5 } }, lastSeen = now - 20,
  },
}
db.journey.levels = {
  ["10"] = {
    kills = 20, killXP = 1000, questXP = 50, otherXP = 0, xp = 1050,
    presenceSeconds = 600, engagedSeconds = 300,
  },
}
db.journey.heatmaps = {
  ["12"] = {
    mapID = 12, gridSize = 64, total = 20,
    cells = { [1] = { kills = 10 }, [2] = { kills = 10 } },
    lastSeen = now - 10,
  },
}
db.journey.quests = {
  ["quest:5"] = {
    id = 5, count = 2, xp = 100, firstSeen = now - 100,
    lastSeen = now - 10, lastTurnInAt = now - 10, mapID = 12, playerLevel = 10,
  },
}
db.journey.questAnchors = {
  { questID = 5, mapID = 12, at = now - 10, playerLevel = 10, xp = 50 },
}
db.journey.deaths = {
  { at = now - 30, mapID = 12, x = 0.2, y = 0.8 },
}
db.journey.respawns = {
  ["1234"] = {
    name = "Defias Pillager", intervals = { 300, 300, 300 },
    lastSeen = now - 20, lastDeath = now - 320,
  },
}
db.quests = { ["quest:5"] = { id = 5, name = "V2 Quest" } }

-- Retire every direct legacy aggregate root.
db.mobs, db.areas, db.areaLevels, db.levels = nil, nil, nil, nil
db.instances, db.heatmaps, db.deaths, db.respawns = nil, nil, nil, nil
module:InvalidateMobIndex()
module:InvalidateJourneyMobIndex()
module:InvalidateHeatmapCache()
module:InvalidateHeatmapZoneCache()
module:OpenUI()

-- Mob list and detail.
module:SetTab("mobs")
module:BuildList()
assert(#module.currentList == 1 and module.currentList[1].label == "V2 Alpha",
  "mob list did not use v2")
assert(module.currentList[1].value:find("avg 45 XP", 1, true),
  "mob list lost v2 XP stats")
module:UpdateMobDetail("npc:1")
assert(module.ui.heroName.text == "V2 Alpha", "mob detail name")
assert(module.ui.details.text:find("This session: 2", 1, true),
  "mob detail lost v2 session")
assert(module.ui.details.text:find("Avg base XP: 45", 1, true),
  "mob detail lost v2 XP stats")

-- Areas and levels.
module:SetTab("areas")
module:BuildList()
assert(#module.currentList == 2, "area list did not include v2 instance")
module:UpdateAreaDetail("12")
assert(module.ui.details.text:find("V2 Alpha", 1, true), "area detail mob")
assert(module.ui.details.text:find("Level range: 10-10", 1, true),
  "area detail levels")
assert(module.ui.details.text:find("Heatmap: 2 cells, 20 kills", 1, true),
  "area detail heatmap")
module:UpdateInstanceDetail("id:9:1")
assert(module.ui.heroName.text == "V2 Instance", "instance detail name")

module:SetTab("levels")
module:BuildList()
assert(#module.currentList == 1 and module.currentList[1].kills == 20,
  "level list did not use v2")
module:UpdateLevelDetail("10")
assert(module.ui.details.text:find("V2 Alpha", 1, true), "level detail mob")

-- Quests, deaths, respawns.
module:SetTab("quests")
module:BuildList()
assert(#module.currentList == 1 and module.currentList[1].label == "V2 Quest",
  "quest list did not use v2")
module:SetTab("deaths")
module:BuildList()
assert(#module.currentList == 2, "history rows did not use v2")
local kinds = {}
for _, row in ipairs(module.currentList) do kinds[row.kind] = true end
assert(kinds.death and kinds.respawn, "history kinds missing")

-- Overview.
module:SetTab("overview")
module:RefreshOverview()
assert(module.ui.overview.topMobsText.text:find("V2 Alpha", 1, true),
  "overview top mob did not use v2")
module:UpdateFooter()
assert(module.ui.footer.text:find("Total kills: 25", 1, true), "footer count")

print("S10 UI read retirement passed")
