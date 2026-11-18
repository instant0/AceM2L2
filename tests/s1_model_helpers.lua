-- Focused S1 read-owner/parity helper test.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

module:ResetKills()

db.mobs = {
  ["npc:5001"] = {
    npcID = 5001, name = "Model Mob", classification = "normal",
    kills = 5, totalXP = 50,
    killsAtLevel = { ["20"] = 5 },
    killsByMap = { ["12"] = 3, ["13"] = 2 },
    killsByAreaLevel = { ["12"] = { ["20"] = 3 } },
    killsByInstance = { ["id:1:1"] = 2 },
    killsByInstanceLevel = { ["id:1:1"] = { ["20"] = 2 } },
    contexts = {}, firstSeen = 10, lastSeen = 20,
  },
}
db.areas = { ["12"] = 100 }
db.areaLevels = { ["12"] = { ["20"] = 100 } }
db.levels = { ["20"] = 100 }
db.instances = {
  ["id:1:1"] = {
    name = "Dungeon", instanceType = "party", instanceID = 1,
    difficultyID = 1, mapID = 12, kills = 2, xp = 20,
    killsAtLevel = { ["20"] = 2 }, lastSeen = 20,
  },
}
db.heatmaps = {
  ["12"] = { cells = { [1] = 3 }, total = 3, lastSeen = 20 },
}
db.quests = {
  ["quest:1"] = {
    id = 1, count = 1, totalXP = 50, lastSeen = 20,
  },
}
db.deaths = { { at = 1, mapID = 12, x = 0.1, y = 0.2 } }
db.respawns = {
  ["5001"] = {
    name = "Model Mob", intervals = { 10, 20 }, lastSeen = 20,
  },
}
db.journey = {
  zones = {
    ["12"] = {
      kills = 50, killXP = 500, questXP = 25, otherXP = 0, xp = 525,
      presenceSeconds = 100, engagedSeconds = 50, deaths = 1, sessions = 2,
      levels = { ["20"] = { kills = 50, xp = 525 } },
    },
  },
  levels = {
    ["20"] = {
      kills = 50, killXP = 500, questXP = 25, otherXP = 0, xp = 525,
      presenceSeconds = 100, engagedSeconds = 50,
    },
  },
  quests = {},
  deaths = {},
  respawns = {},
  mobs = {},
  instances = {},
  heatmaps = {},
}

local function serialize(value, seen)
  if type(value) ~= "table" then return tostring(value) end
  seen = seen or {}
  if seen[value] then return "<cycle>" end
  seen[value] = true
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = tostring(key) .. "=" .. serialize(value[key], seen)
  end
  seen[value] = nil
  return "{" .. table.concat(parts, ";") .. "}"
end

module:EnsureModelMobs()
local before = serialize(db)

local mob = module:GetModelMob("npc:5001")
assert(mob and mob.source == "v2", "mob source")
assert(mob.kills == 5 and mob.xp == 50, "mob totals")
assert(mob.byPlayerLevel["20"].kills == 5, "byPlayerLevel")
assert(mob.byZone["12"].kills == 3
  and mob.byZone["12"].playerLevels["20"].kills == 3, "byZone")
assert(mob.byInstance["id:1:1"].kills == 2
  and mob.byInstance["id:1:1"].playerLevels["20"].kills == 2, "byInstance")
assert(mob.npcID == 5001 and mob.classification == "normal", "mob identity")

local zone = module:GetModelZone(12)
assert(zone and zone.source == "legacy", "zone source")
assert(zone.kills == 100, "legacy zone kills")
assert(zone.timeSource == "journey", "zone time source")
assert(zone.xp == 525 and zone.engagedSeconds == 50, "zone journey totals")
assert(zone.playerLevels["20"].kills == 100, "zone playerLevels")

local level = module:GetModelLevel(20)
assert(level and level.source == "legacy", "level source")
assert(level.kills == 100 and level.xp == 525, "level parity")

local instance = module:GetModelInstance("id:1:1")
assert(instance and instance.source == "legacy", "instance source")
assert(instance.kills == 2 and instance.name == "Dungeon", "instance parity")

local heatmap = module:GetModelHeatmap(12)
assert(heatmap and heatmap.source == "legacy", "heatmap source")
assert(heatmap.total == 3 and heatmap.cells[1] == 3, "heatmap parity")

local quest = module:GetModelQuest("quest:1")
assert(quest and quest.source == "legacy", "quest source")
assert(quest.id == 1 and quest.xp == 50, "quest parity")

local death = module:GetModelDeath(1)
assert(death and death.source == "legacy", "death source")
assert(death.mapID == 12 and death.x == 0.1 and death.y == 0.2, "death parity")

local respawn = module:GetModelRespawn(5001)
assert(respawn and respawn.source == "legacy", "respawn source")
assert(respawn.samples == 2, "respawn samples")

-- Helpers must not mutate the character table.
assert(serialize(db) == before, "helpers mutated character data")

-- v2-only fallback is used only when the legacy field is absent.
db.journey.mobs["npc:6001"] = {
  npcID = 6001, name = "V2 Mob", classification = "elite",
  kills = 4, xp = 40, mobLevelMin = 10, mobLevelMax = 12,
  byPlayerLevel = { ["20"] = { kills = 4, xp = 40 } },
  byZone = { ["12"] = { kills = 4, playerLevels = {} } },
  byInstance = {}, contexts = {}, firstSeen = 1, lastSeen = 2,
}
local v2Mob = module:GetModelMob("npc:6001")
assert(v2Mob and v2Mob.source == "v2" and v2Mob.xp == 40, "v2 mob fallback")
assert(v2Mob.byPlayerLevel["20"].kills == 4, "v2 mob shape")

db.journey.zones["14"] = {
  kills = 7, killXP = 70, questXP = 0, otherXP = 0, xp = 70,
  presenceSeconds = 10, engagedSeconds = 5, deaths = 0, sessions = 1,
  levels = { ["20"] = { kills = 7, xp = 70 } },
}
local v2Zone = module:GetModelZone(14)
assert(v2Zone and v2Zone.source == "v2" and v2Zone.kills == 7, "v2 zone fallback")

db.journey.levels["30"] = {
  kills = 9, killXP = 90, questXP = 0, otherXP = 0, xp = 90,
  presenceSeconds = 10, engagedSeconds = 5,
}
assert(module:GetModelLevel(30).source == "v2", "v2 level fallback")

db.journey.instances["id:2:1"] = {
  name = "V2 Dungeon", kills = 3, xp = 30,
  killsAtLevel = { ["20"] = 3 }, lastSeen = 30,
}
assert(module:GetModelInstance("id:2:1").source == "v2", "v2 instance fallback")

db.journey.heatmaps["15"] = {
  cells = { [2] = 4 }, total = 4, lastSeen = 30,
}
assert(module:GetModelHeatmap(15).source == "v2", "v2 heatmap fallback")

db.journey.quests["quest:2"] = {
  id = 2, count = 1, totalXP = 20, lastSeen = 30,
}
assert(module:GetModelQuest(2).source == "v2", "v2 quest fallback")

db.journey.deaths[1] = {
  at = 2, mapID = 12, x = 0.3, y = 0.4, mobKey = "npc:5001",
}
local legacyDeaths = db.deaths
db.deaths = nil
assert(module:GetModelDeath(1).source == "v2", "v2 death fallback")
db.deaths = legacyDeaths

db.journey.respawns["5001"] = {
  name = "V2 Respawn", intervals = { 5, 15 }, lastSeen = 30,
}
local legacyRespawns = db.respawns
db.respawns = nil
assert(module:GetModelRespawn(5001).source == "v2", "v2 respawn fallback")
db.respawns = legacyRespawns

assert(module:GetModelMob("npc:missing") == nil, "missing mob")
assert(module:GetModelZone(999) == nil, "missing zone")

print("S1 model helpers passed")
