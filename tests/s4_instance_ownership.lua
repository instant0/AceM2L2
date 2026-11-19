-- DS-17.14 S4A instance ownership test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

module:ResetKills()
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()

local function instance(name, mapID, kills, xp, level)
  return {
    name = name, instanceType = "party", instanceID = 555,
    difficultyID = 1, mapID = mapID,
    kills = kills, xp = xp,
    killsAtLevel = { [tostring(level)] = kills },
    firstSeen = 10, lastSeen = 20,
  }
end

db.instances = {
  ["id:555:1"] = instance("Test Dungeon", 0, 5, 500, 20),
  ["id:555:2"] = instance("Real Dungeon", 1234, 2, 200, 20),
}
module:EnsureModelInstances()

local inst = module:GetModelInstance("id:555:1")
assert(inst and inst.source == "v2", "instance source")
assert(inst.name == "Test Dungeon" and inst.instanceID == 555, "identity")
assert(inst.kills == 5 and inst.xp == 500, "totals")
assert(inst.playerLevels["20"].kills == 5, "player levels")
assert(inst.killsExact == true, "kills exact")
assert(inst.timeCoverage == "unavailable", "time coverage")
assert(inst.deathCoverage == "unavailable", "death coverage")
assert(inst.sessionCoverage == "unavailable", "session coverage")
assert(inst.presenceSeconds == 0 and inst.engagedSeconds == 0,
  "time invented")

local real = module:GetModelInstance("id:555:2")
assert(real and real.mapID == 1234, "attributable instance map")

-- Sync updates exact totals but preserves Journey time.
db.journey.instances["id:555:1"].presenceSeconds = 100
db.journey.instances["id:555:1"].engagedSeconds = 50
db.instances["id:555:1"].kills = 7
db.instances["id:555:1"].xp = 700
db.instances["id:555:1"].killsAtLevel["20"] = 7
assert(module:SyncModelInstanceFromLegacy("id:555:1"), "instance sync")
local synced = module:GetModelInstance("id:555:1")
assert(synced.kills == 7 and synced.xp == 700, "instance sync totals")
assert(synced.playerLevels["20"].kills == 7, "instance sync levels")
assert(synced.presenceSeconds == 100 and synced.engagedSeconds == 50,
  "instance sync lost time")

-- Bulk sync is idempotent and removes deleted legacy instances.
module:SyncModelInstancesFromLegacy()
local first = module:GetModelInstance("id:555:1").kills
module:SyncModelInstancesFromLegacy()
assert(module:GetModelInstance("id:555:1").kills == first, "bulk idempotence")
db.instances["id:555:2"] = nil
module:SyncModelInstancesFromLegacy()
assert(module:GetModelInstance("id:555:2") == nil, "deleted instance removed")

-- v2-only reads with legacy removed.
db.instances = nil
assert(module:GetModelInstance("id:555:1").kills == 7, "v2-only instance")
assert(db.journey.zones["0"] == nil, "zones[0] was touched")

print("S4 instance ownership passed")
