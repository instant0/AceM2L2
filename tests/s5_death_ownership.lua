-- DS-17.16 S5 death ownership test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

module:ResetKills()
state.mapID = 12
state.mapX, state.mapY = 0.2, 0.8
state.playerLevel = 20
state.now = 1000
module:OnJourneyEnterWorld()

db.deaths = {
  { at = 100, mapID = 12, x = 0.1, y = 0.9 },
  { at = 200, mapID = 13, x = 0.2, y = 0.8 },
  { at = 300, mapID = 12, x = 0.3, y = 0.7 },
}
module:EnsureModelDeaths()
local first = module:GetModelDeath(1)
assert(first and first.source == "v2", "death source")
assert(first.at == 100 and first.mapID == 12
  and first.x == 0.1 and first.y == 0.9, "death position")
assert(first.attributionCoverage == "unavailable", "attribution coverage")
assert(first.healthCoverage == "unavailable", "health coverage")
assert(first.contextCoverage == "unavailable", "context coverage")
assert(first.mobKey == nil and first.health == nil, "V-2 field invented")

-- New death writes v2 through the production path.
assert(module:HandlePlayerDeath(), "death capture")
assert(#db.deaths == 4, "legacy death count")
assert(#db.journey.deaths == 4, "v2 death count")
local last = module:GetModelDeath(4)
assert(last.mapID == 12 and last.x == 0.2 and last.y == 0.8, "new death")
assert(last.attributionCoverage == "unavailable", "new death coverage")

-- Duplicate suppression still applies.
assert(not module:HandlePlayerDeath(), "duplicate death accepted")
assert(#db.deaths == 4 and #db.journey.deaths == 4, "duplicate changed deaths")

-- Cap/normalization parity.
state.now = 2000
local deaths = {}
for index = 1, 105 do
  deaths[index] = { at = index, mapID = 12, x = 0.1, y = 0.1 }
end
db.deaths = deaths
module:SyncModelDeathsFromLegacy()
assert(#db.journey.deaths == 100, "v2 death cap")
assert(db.journey.deaths[1].at == 6, "v2 death cap order")

-- Load/legacy sync is idempotent and follows final legacy state.
db.deaths = {
  { at = 1, mapID = 12, x = 0.4, y = 0.6 },
}
module:SyncModelDeathsFromLegacy()
local once = module:GetModelDeath(1)
module:SyncModelDeathsFromLegacy()
local twice = module:GetModelDeath(1)
assert(once.at == twice.at and once.x == twice.x, "death sync idempotence")

-- V2-only reads with legacy removed.
db.deaths = nil
assert(module:GetModelDeath(1).x == 0.4, "v2-only death")

print("S5 death ownership passed")
