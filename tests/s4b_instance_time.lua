-- DS-17.15 S4B instance time/death/session test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local function setInstance(mapID, instanceMapID, name, difficulty)
  state.mapID = mapID
  state.playerLevel = 20
  state.inInstance = true
  state.instanceType = "party"
  state.instanceName = name
  state.instanceMapID = instanceMapID
  state.difficultyID = difficulty or 0
  module:RefreshInstanceState()
end

-- Non-attributable instance: time/kills go to the instance, not zones["0"].
module:ResetKills()
state.now = 100
setInstance(947, 947, "Test Instance", 0)
local instanceState = module:GetInstanceState()
local key = instanceState and instanceState.key
assert(key, "instance key")
module:OnJourneyEnterWorld()
state.now = 110
module:OnJourneyKill({
  mapID = 0, instanceKey = key, instanceName = "Test Instance",
  instanceID = 947, difficultyID = 0, playerLevel = 20, level = 10,
}, 100)

local journey = db.journey
local record = journey.instances[key]
assert(record, "v2 instance record")
assert(record.presenceSeconds == 10, "instance presence")
assert(record.engagedSeconds == 10, "instance engaged")
assert(record.kills == 1 and record.killXP == 100, "instance kill/XP")
assert(record.sessions == 1, "instance sessions")
assert(record.playerLevels["20"].kills == 1, "instance player level")
assert(journey.zones["0"] == nil, "non-attributable zone 0 written")

module:OnJourneyInstanceDeath()
assert(record.deaths == 1, "instance death")
state.now = 120
module:OnJourneyLogout()
assert(record.presenceSeconds == 20, "instance logout presence")
assert(record.engagedSeconds == 20, "instance logout engaged")

local view = module:GetModelInstance(key)
assert(view and view.presenceSeconds == 20 and view.engagedSeconds == 20,
  "v2 instance time")
assert(view.timeCoverage == "post-instrumentation", "time coverage")
assert(view.deathCoverage == "post-instrumentation", "death coverage")
assert(view.sessionCoverage == "post-instrumentation", "session coverage")

-- Attributable instance map also uses the instance record for time.
module:ResetKills()
state.now = 200
setInstance(1234, 555, "Real Dungeon", 1)
local realState = module:GetInstanceState()
local realKey = realState and realState.key
assert(realKey, "real instance key")
module:OnJourneyEnterWorld()
state.now = 210
module:OnJourneyKill({
  mapID = 1234, instanceKey = realKey, instanceName = "Real Dungeon",
  instanceID = 555, difficultyID = 1, playerLevel = 20, level = 10,
}, 50)
local real = db.journey.instances[realKey]
assert(real and real.presenceSeconds == 10, "attributable instance time")
assert(db.journey.zones["1234"] == nil, "attributable zone time duplicated")

-- Legacy sync preserves event time/death/session coverage.
db.instances = {
  [realKey] = {
    name = "Real Dungeon", instanceType = "party", instanceID = 555,
    difficultyID = 1, mapID = 1234, kills = 1, xp = 50,
    killsAtLevel = { ["20"] = 1 }, firstSeen = 200, lastSeen = 210,
  },
}
module:SyncModelInstanceFromLegacy(realKey)
local synced = module:GetModelInstance(realKey)
assert(synced.kills == 1 and synced.xp == 50, "instance legacy totals")
assert(synced.presenceSeconds == 10, "instance sync lost time")
assert(synced.timeCoverage == "post-instrumentation", "sync time coverage")
assert(synced.deathCoverage == "unavailable", "sync death coverage")

-- V2-only read after legacy removal.
db.instances = nil
assert(module:GetModelInstance(realKey).presenceSeconds == 10,
  "v2-only instance time")

print("S4B instance time passed")
