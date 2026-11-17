-- Focused production test for the global Journey mob index.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

db.mobs = {
  ["npc:1"] = { npcID = 1, name = "Alpha", classification = "normal",
    kills = 20, sessionKills = 5, lastSeen = 10,
    killsAtLevel = { ["10"] = 3 }, xp = { samples = 1, sumBase = 50 } },
  ["npc:2"] = { npcID = 2, name = "Beta", classification = "elite",
    kills = 10, sessionKills = 0, lastSeen = 20,
    killsAtLevel = { ["10"] = 0 }, xp = { samples = 0 } },
  ["npc:3"] = { npcID = 3, name = "Gamma", classification = "normal",
    kills = 30, sessionKills = 0, lastSeen = 30,
    killsAtLevel = { ["11"] = 4 }, xp = { samples = 0 } },
}
module:InvalidateJourneyMobIndex()

assert(module:GetJourneyMobCount() == 3, "mob index count")
local rows = module:GetJourneyMobRows()
assert(#rows == 3, "mob rows")
local row = assert(module:GetJourneyMobRow("npc:1"))
assert(row.name == "Alpha" and row.kills == 20, "mob row fields")

local top = module:GetJourneyTopMobs(2)
assert(#top == 2 and top[1].key == "npc:3" and top[2].key == "npc:1",
  "top mobs")

local elite = module:GetJourneyMobsForFilter("elite", "")
assert(#elite == 1 and elite[1].key == "npc:2", "elite filter")
local session = module:GetJourneyMobsForFilter("session", "")
assert(#session == 1 and session[1].key == "npc:1", "session filter")
local search = module:GetJourneyMobsForFilter(nil, "amm")
assert(#search == 1 and search[1].key == "npc:3", "search filter")

-- Kill invalidation rebuilds from the current data.
db.mobs["npc:2"].kills = 50
module:InvalidateJourneyMobIndex()
local rebuilt = module:GetJourneyMobRow("npc:2")
assert(rebuilt.kills == 50, "index invalidation")

print("Journey mob index passed")
