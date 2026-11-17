-- Focused test for the accepted 6x tier and adaptive quest limit.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

assert(module.MAX_RESPAWN_NPCS == 4000, "respawn cap tier")
assert(module.MAX_QUESTS == 10000, "quest hard ceiling")
assert(module.Util.MAX_MOBS == 12000, "mob hard ceiling")

db.areas = {}
db.instances = {}
assert(module:GetQuestCapacityLimit() == 500, "minimum quest limit")
assert(module:GetMobCapacityLimit() == 2000, "minimum mob limit")
for index = 1, 8 do db.areas[tostring(index)] = 1 end
assert(module:GetMobCapacityLimit() == 4000, "8-zone mob limit")
for index = 9, 40 do db.areas[tostring(index)] = 1 end
assert(module:GetQuestCapacityLimit() == 4000, "40-zone quest limit")
assert(module:GetMobCapacityLimit() == 12000, "24+ zone mob ceiling")
for index = 41, 100 do db.areas[tostring(index)] = 1 end
assert(module:GetQuestCapacityLimit() == 10000, "hard quest ceiling")
assert(module:GetMobCapacityLimit() == 12000, "mob hard ceiling")

-- Real-density quest growth: 50+ per zone must not hit the old 200/500 caps.
db.areas = {}
for index = 1, 40 do db.areas[tostring(index)] = 1 end
db.quests = {}
for index = 1, 3000 do
  db.quests["quest:" .. tostring(index)] = {
    id = index, name = "Quest " .. tostring(index), count = 1,
    totalXP = 100, lastSeen = index, firstSeen = index,
  }
end
module:RecordQuestXP(999999, "New Quest", 100)
local questCount = 0
for _ in pairs(db.quests) do questCount = questCount + 1 end
assert(questCount == 3001, "40-zone quest data was pruned")

-- At a small zone count the adaptive limit still prunes down to 500.
db.areas = {}
for index = 1, 4 do db.areas[tostring(index)] = 1 end
db.quests = {}
for index = 1, 600 do
  db.quests["quest:" .. tostring(index)] = {
    id = index, name = "Quest " .. tostring(index), count = 1,
    totalXP = 100, lastSeen = index, firstSeen = index,
  }
end
module:RecordQuestXP(1000000, "New Quest", 100)
questCount = 0
for _ in pairs(db.quests) do questCount = questCount + 1 end
assert(questCount == 500, "adaptive quest pruning")

-- The 6x respawn shape fits the accepted 500-NPC cap.
db.respawns = {}
for index = 1, 414 do
  db.respawns[index] = {
    name = "NPC " .. tostring(index),
    intervals = { 300, 300, 300 },
    lastSeen = index,
    lastDeath = index - 300,
  }
end
module:NormalizeRespawns()
local respawnCount = 0
for _ in pairs(db.respawns) do respawnCount = respawnCount + 1 end
assert(respawnCount == 414, "6x respawn shape was trimmed")

print("Limit tier passed")
