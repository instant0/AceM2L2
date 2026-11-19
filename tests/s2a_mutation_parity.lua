-- DS-17.11 mutation parity: merge, delete, prune, consolidation.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local function mob(name, kills, xp, firstSeen, lastSeen, mapID)
  return {
    name = name, classification = "normal",
    kills = kills, totalXP = xp,
    firstSeen = firstSeen or 10, lastSeen = lastSeen or 20,
    killsAtLevel = { ["20"] = kills },
    killsByMap = { [tostring(mapID or 12)] = kills },
    killsByAreaLevel = {},
    killsByInstance = {}, killsByInstanceLevel = {},
    contexts = {},
  }
end

local function reset()
  module:ResetKills()
  state.mapID = 12
  state.playerLevel = 20
  state.now = 100
  module:OnJourneyEnterWorld()
end

local function modelKills(key)
  local record = module:GetModelMob(key)
  return record and record.kills or nil
end

-- Additive merge: name-only + NPC sums, and v2 follows the final legacy state.
reset()
db.mobs["name:wolf"] = mob("Wolf", 2, 20, 10, 20)
db.mobs["npc:5001"] = mob("Wolf", 3, 30, 15, 25)
module:EnsureModelMobs()
assert(module:MergeMobEntries("name:wolf", "npc:5001", false), "additive merge")
assert(db.mobs["name:wolf"] == nil, "legacy name key survived")
assert(db.mobs["npc:5001"].kills == 5, "legacy additive kills")
assert(modelKills("npc:5001") == 5, "v2 additive kills")
assert(module:GetModelMob("name:wolf") == nil, "v2 name key survived")

-- Historical/dedupe merge: max counts, not a second sum.
reset()
db.mobs["name:wolf"] = mob("Wolf", 2, 20, 10, 30)
db.mobs["npc:5001"] = mob("Wolf", 3, 30, 15, 25)
module:EnsureModelMobs()
assert(module:MergeMobEntries("name:wolf", "npc:5001", true), "dedupe merge")
assert(db.mobs["npc:5001"].kills == 3, "legacy dedupe kills")
assert(modelKills("npc:5001") == 3, "v2 dedupe kills")

-- Promotion: name-only becomes an NPC key.
reset()
db.mobs["name:bear"] = mob("Bear", 1, 10, 10, 20)
module:EnsureModelMobs()
assert(module:MergeMobEntries("name:bear", "npc:6001", true), "promotion")
assert(db.mobs["name:bear"] == nil and db.mobs["npc:6001"], "legacy promotion")
assert(modelKills("npc:6001") == 1, "v2 promotion")
assert(module:GetModelMob("name:bear") == nil, "v2 old name key")

-- Delete removes v2.
reset()
db.mobs["npc:5002"] = mob("Boar", 4, 40, 10, 20)
module:EnsureModelMobs()
module:RemoveMobEntry("npc:5002", true)
assert(db.mobs["npc:5002"] == nil, "legacy delete")
assert(module:GetModelMob("npc:5002") == nil, "v2 delete")

-- Prune removes the same identity from v2.
reset()
db.mobs["npc:5003"] = mob("Zero", 0, 0, 1, 1)
db.mobs["npc:5004"] = mob("Live", 5, 50, 10, 20)
module:EnsureModelMobs()
local originalLimit = module.GetMobCapacityLimit
module.GetMobCapacityLimit = function() return 1 end
module:Prune()
module.GetMobCapacityLimit = originalLimit
assert(db.mobs["npc:5003"] == nil, "legacy prune")
assert(module:GetModelMob("npc:5003") == nil, "v2 prune")
assert(modelKills("npc:5004") == 5, "v2 prune survivor")

-- Load consolidation syncs v2.
reset()
db.mobs["name:wolf"] = mob("Wolf", 2, 20, 1, 5)
db.mobs["npc:5005"] = mob("Wolf", 3, 30, 15, 25)
module:EnsureModelMobs()
module:ConsolidateNameOnlyMobs()
assert(db.mobs["name:wolf"] == nil, "consolidated legacy key")
assert(modelKills("npc:5005") == 5, "consolidated v2 kills")

-- Bulk sync is idempotent and follows final legacy state.
db.mobs["npc:5005"].kills = 99
module:SyncModelMobsFromLegacy()
local first = modelKills("npc:5005")
module:SyncModelMobsFromLegacy()
assert(first == 99 and modelKills("npc:5005") == 99, "bulk sync idempotence")

-- V2-only reads still work after legacy removal.
db.mobs = nil
assert(modelKills("npc:5005") == 99, "v2-only after mutation sync")

print("S2A mutation parity passed")
