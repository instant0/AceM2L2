-- DS-17.17 S6 quest/respawn ownership test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

module:ResetKills()
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()

db.quests = {
  ["quest:1"] = {
    id = 1, name = "Quest One", count = 2, totalXP = 200,
    firstSeen = 10, lastSeen = 20, lastTurnInAt = 20,
    mapID = 12, playerLevel = 20,
  },
  ["quest:2"] = {
    id = 2, name = "Quest Two", count = 1, totalXP = 50,
    firstSeen = 30, lastSeen = 30, lastTurnInAt = 30,
    mapID = 13, playerLevel = 20,
  },
}
module:EnsureModelQuests()
local quest = module:GetModelQuest(1)
assert(quest and quest.source == "v2", "quest source")
assert(quest.id == 1 and quest.count == 2 and quest.xp == 200, "quest totals")
assert(quest.lastTurnInAt == 20 and quest.mapID == 12, "quest anchor fields")
assert(quest.name == "Quest One", "quest name resolution")
assert(db.journey.quests["quest:1"].name == nil, "quest name duplicated")

-- Production quest path updates v2.
module:RecordQuestXP(1, "Quest One", 30)
assert(module:GetModelQuest(1).count == 3, "quest count sync")
assert(module:GetModelQuest(1).xp == 230, "quest XP sync")

-- Respawn migration and stats.
db.respawns = {
  [5001] = {
    name = "Respawn Mob", intervals = { 10, 20, 30 },
    lastSeen = 100, lastDeath = 70,
  },
  [5002] = {
    name = "Respawn Survivor", intervals = { 15 },
    lastSeen = 90, lastDeath = 75,
  },
}
module:EnsureModelRespawns()
local respawn = module:GetModelRespawn(5001)
assert(respawn and respawn.source == "v2", "respawn source")
assert(respawn.samples == 3 and respawn.min == 10 and respawn.max == 30
  and respawn.sum == 60, "respawn stats")
assert(respawn.name == "Respawn Mob" and respawn.lastDeath == 70,
  "respawn identity")

-- Production respawn path updates v2.
assert(module:RecordRespawnInterval(5001, "Respawn Mob", 40), "respawn record")
local updated = module:GetModelRespawn(5001)
assert(updated.samples == 4 and updated.max == 40, "respawn sync")

-- Bulk sync is idempotent and follows final legacy state.
module:SyncModelQuestsFromLegacy()
module:SyncModelRespawnsFromLegacy()
local q1 = module:GetModelQuest(1).count
local r1 = module:GetModelRespawn(5001).samples
module:SyncModelQuestsFromLegacy()
module:SyncModelRespawnsFromLegacy()
assert(module:GetModelQuest(1).count == q1, "quest sync idempotence")
assert(module:GetModelRespawn(5001).samples == r1, "respawn sync idempotence")

-- Deleted legacy entries are removed from v2.
db.quests["quest:2"] = nil
db.respawns[5001] = nil
module:SyncModelQuestsFromLegacy()
module:SyncModelRespawnsFromLegacy()
assert(module:GetModelQuest(2) == nil, "deleted quest removed")
assert(module:GetModelRespawn(5001) == nil, "deleted respawn removed")

-- V2-only reads with legacy removed.
db.quests = nil
db.respawns = nil
assert(module:GetModelQuest(1).count == 3, "v2-only quest")
assert(module:GetModelRespawn(5002).samples == 1, "v2-only respawn")

print("S6 quest/respawn ownership passed")
