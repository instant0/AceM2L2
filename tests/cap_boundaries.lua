-- Boundary and idempotence tests for recency-capped stores.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

-- Deaths: keep the newest 100.
local deaths = {}
for index = 1, 101 do
  deaths[#deaths + 1] = {
    at = index, mapID = 12, x = 0.5, y = 0.5,
  }
end
db.deaths = module:NormalizeDeaths(deaths)
assert(#db.deaths == module.MAX_DEATHS, "death cap")
assert(db.deaths[1].at == 2 and db.deaths[#db.deaths].at == 101,
  "death pruning order")
module:NormalizeDeaths()
assert(#db.deaths == module.MAX_DEATHS, "death normalization idempotence")

-- Respawns: keep the newest MAX_RESPAWN_NPCS.
db.respawns = {}
for index = 1, module.MAX_RESPAWN_NPCS + 1 do
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
assert(respawnCount == module.MAX_RESPAWN_NPCS, "respawn cap")
assert(db.respawns[1] == nil and db.respawns[module.MAX_RESPAWN_NPCS + 1] ~= nil,
  "respawn pruning order")
module:NormalizeRespawns()
respawnCount = 0
for _ in pairs(db.respawns) do respawnCount = respawnCount + 1 end
assert(respawnCount == module.MAX_RESPAWN_NPCS, "respawn idempotence")

-- Level history: trim oldest finalized records.
db.levelHistory = {}
for index = 1, 201 do
  db.levelHistory[#db.levelHistory + 1] = {
    level = index, startedAt = index, endedAt = index + 1,
    xpGained = 100, kills = 10, duration = 10,
  }
end
module:TrimLevelHistory()
assert(#db.levelHistory == module.MAX_LEVEL_RECORDS, "level-record cap")
assert(db.levelHistory[1].level == 2 and db.levelHistory[#db.levelHistory].level == 201,
  "level-record pruning order")
module:TrimLevelHistory()
assert(#db.levelHistory == module.MAX_LEVEL_RECORDS, "level-record idempotence")

-- Rate samples: keep the newest 240.
db.rates = {}
for index = 1, 241 do
  db.rates[#db.rates + 1] = { at = index, xp = 10, mapID = 12, level = 10 }
end
module:NormalizeRates()
assert(#db.rates == module.MAX_RATE_SAMPLES, "rate-sample cap")
assert(db.rates[1].at == 2 and db.rates[#db.rates].at == 241,
  "rate-sample pruning order")
module:NormalizeRates()
assert(#db.rates == module.MAX_RATE_SAMPLES, "rate-sample idempotence")

-- Instance records: keep the newest 100.
db.instances = {}
for index = 1, module.Util.MAX_INSTANCE_RECORDS + 1 do
  db.instances["id:" .. tostring(index)] = {
    name = "Instance " .. tostring(index), instanceType = "party",
    kills = 1, lastSeen = index, firstSeen = index,
  }
end
module:NormalizeInstances()
local instanceCount = 0
for _ in pairs(db.instances) do instanceCount = instanceCount + 1 end
assert(instanceCount == module.Util.MAX_INSTANCE_RECORDS, "instance cap")
assert(db.instances["id:1"] == nil
  and db.instances["id:" .. tostring(module.Util.MAX_INSTANCE_RECORDS + 1)] ~= nil,
  "instance pruning order")
module:NormalizeInstances()
instanceCount = 0
for _ in pairs(db.instances) do instanceCount = instanceCount + 1 end
assert(instanceCount == module.Util.MAX_INSTANCE_RECORDS, "instance idempotence")

print("Cap boundaries passed")
