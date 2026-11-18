-- S2A migration simulation: legacy db.mobs -> new v2 journey.mobs file.
-- This is an offline harness, not a production writer.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
  return result
end

local function serialize(value, seen)
  local kind = type(value)
  if kind == "table" then
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do
      parts[#parts + 1] = "[" .. serialize(key, seen) .. "]="
        .. serialize(value[key], seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
  elseif kind == "string" then
    return string.format("%q", value)
  elseif kind == "number" or kind == "boolean" then
    return tostring(value)
  end
  return "nil"
end

local function keys(value)
  local result = {}
  for key in pairs(value or {}) do result[#result + 1] = key end
  table.sort(result)
  return result
end

local function levelMap(source)
  local result = {}
  for level, count in pairs(source or {}) do
    result[tostring(level)] = { kills = tonumber(count) or 0 }
  end
  return result
end

local function migrateMobs(legacy)
  local result = {}
  for key, mob in pairs(legacy or {}) do
    if type(mob) == "table" then
      local byZone = {}
      for mapID, kills in pairs(mob.killsByMap or {}) do
        byZone[tostring(mapID)] = {
          kills = tonumber(kills) or 0, playerLevels = {},
        }
      end
      for mapID, levels in pairs(mob.killsByAreaLevel or {}) do
        local zone = byZone[tostring(mapID)]
        if not zone then
          zone = { kills = 0, playerLevels = {} }
          byZone[tostring(mapID)] = zone
        end
        zone.playerLevels = levelMap(levels)
      end
      local byInstance = {}
      for instanceKey, kills in pairs(mob.killsByInstance or {}) do
        byInstance[tostring(instanceKey)] = {
          kills = tonumber(kills) or 0, playerLevels = {},
        }
      end
      for instanceKey, levels in pairs(mob.killsByInstanceLevel or {}) do
        local instance = byInstance[tostring(instanceKey)]
        if not instance then
          instance = { kills = 0, playerLevels = {} }
          byInstance[tostring(instanceKey)] = instance
        end
        instance.playerLevels = levelMap(levels)
      end
      result[key] = {
        npcID = mob.npcID,
        name = mob.name,
        classification = mob.classification or "normal",
        kills = tonumber(mob.kills) or 0,
        xp = tonumber(mob.totalXP) or 0,
        mobLevelMin = tonumber(mob.mobLevelMin) or 0,
        mobLevelMax = tonumber(mob.mobLevelMax) or 0,
        mobLevelSamples = tonumber(mob.mobLevelSamples)
          or tonumber(mob.kills) or 0,
        byPlayerLevel = levelMap(mob.killsAtLevel),
        byZone = byZone,
        byInstance = byInstance,
        contexts = mob.contexts,
        firstSeen = tonumber(mob.firstSeen) or 0,
        lastSeen = tonumber(mob.lastSeen) or 0,
      }
    end
  end
  return result
end

-- Prove migration from records produced by the actual old-model kill path.
module:ResetKills()
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()
for _ = 1, 5 do
  module:RecordKill({
    name = "Sim Mob", npcID = 5001, mapID = 12,
    playerLevel = 20, level = 10, classification = "normal",
  }, 10, 10, 10, "test")
end
for _ = 1, 2 do
  module:RecordKill({
    name = "Sim Wolf", mapID = 12,
    playerLevel = 20, level = 8, classification = "normal",
  }, 10, 10, 10, "test")
end
local codeLegacy = copy(db.mobs)
assert(codeLegacy["npc:5001"].kills == 5, "old kill path kills")
assert(codeLegacy["npc:5001"].totalXP == 50, "old kill path XP")
-- Simulate the pre-migration state, then migrate from the actual legacy records.
db.journey.mobs = {}
db.journey.mobsMigrated = false
module:EnsureModelMobs()
local codeV2 = db.journey.mobs
assert(codeV2["npc:5001"].kills == 5, "code migration kills")
assert(codeV2["npc:5001"].xp == 50, "code migration XP")
assert(codeV2["npc:5001"].byPlayerLevel["20"].kills == 5,
  "code migration player level")
assert(codeV2["npc:5001"].byZone["12"].kills == 5, "code migration zone")
assert(codeV2["name:sim wolf"].kills == 2, "code migration name-only")

local legacy = {
  ["npc:5001"] = {
    npcID = 5001, name = "Sim Mob", classification = "normal",
    kills = 5, totalXP = 50, firstSeen = 10, lastSeen = 20,
    killsAtLevel = { ["20"] = 5 },
    killsByMap = { ["12"] = 3, ["13"] = 2 },
    killsByAreaLevel = { ["12"] = { ["20"] = 3 } },
    killsByInstance = { ["id:1:1"] = 2 },
    killsByInstanceLevel = { ["id:1:1"] = { ["20"] = 2 } },
    contexts = {},
  },
  ["name:sim wolf"] = {
    name = "Sim Wolf", classification = "normal",
    kills = 2, totalXP = 20, firstSeen = 11, lastSeen = 21,
    killsAtLevel = { ["20"] = 2 },
    killsByMap = { ["12"] = 2 }, killsByAreaLevel = {},
    killsByInstance = {}, killsByInstanceLevel = {}, contexts = {},
  },
}

local v2a = migrateMobs(legacy)
local v2b = migrateMobs(legacy)
assert(serialize(v2a, {}) == serialize(v2b, {}), "migration is not idempotent")
assert(v2a["npc:5001"].kills == 5 and v2a["npc:5001"].xp == 50,
  "mob totals")
assert(v2a["npc:5001"].byPlayerLevel["20"].kills == 5, "player-level map")
assert(v2a["npc:5001"].byZone["12"].kills == 3
  and v2a["npc:5001"].byZone["12"].playerLevels["20"].kills == 3,
  "zone map")
assert(v2a["npc:5001"].byInstance["id:1:1"].kills == 2
  and v2a["npc:5001"].byInstance["id:1:1"].playerLevels["20"].kills == 2,
  "instance map")

-- Write the migrated table to a new file, then load it back.
local path = arg[1] or (os.tmpname() .. "-s2a-v2.lua")
local file = assert(io.open(path, "wb"))
file:write("return " .. serialize(v2a, {}) .. "\n")
file:close()

local chunk = assert(loadfile(path, "t", {}))
local loaded = chunk()
assert(type(loaded) == "table", "v2 file did not load")
assert(serialize(loaded, {}) == serialize(v2a, {}), "v2 file round-trip changed data")

-- Remove legacy and prove v2-only reads through the S1 helper.
db.mobs = nil
db.journey = { mobs = loaded }
local mob, err = module:GetModelMob("npc:5001")
assert(mob and mob.source == "v2", "v2-only mob read: " .. tostring(err))
assert(mob.kills == 5 and mob.xp == 50, "v2-only totals")
assert(mob.byPlayerLevel["20"].kills == 5, "v2-only byPlayerLevel")
assert(mob.byZone["12"].kills == 3, "v2-only byZone")
local wolf = module:GetModelMob("name:sim wolf")
assert(wolf and wolf.source == "v2" and wolf.kills == 2, "v2-only name mob")

-- Parity against the original legacy snapshot.
local legacySnapshot = copy(legacy)
local v2FromFile = loaded
assert(#keys(legacySnapshot) == #keys(v2FromFile), "mob identity count")
for key, mob in pairs(legacySnapshot) do
  local migrated = v2FromFile[key]
  assert(migrated, "missing migrated mob: " .. key)
  assert(migrated.kills == (tonumber(mob.kills) or 0), "kills parity: " .. key)
  assert(migrated.xp == (tonumber(mob.totalXP) or 0), "xp parity: " .. key)
  for level, count in pairs(mob.killsAtLevel or {}) do
    assert(migrated.byPlayerLevel[tostring(level)]
      and migrated.byPlayerLevel[tostring(level)].kills == count,
      "player-level parity: " .. key)
  end
  for mapID, count in pairs(mob.killsByMap or {}) do
    assert(migrated.byZone[tostring(mapID)]
      and migrated.byZone[tostring(mapID)].kills == count,
      "zone parity: " .. key)
  end
  for instanceKey, count in pairs(mob.killsByInstance or {}) do
    assert(migrated.byInstance[tostring(instanceKey)]
      and migrated.byInstance[tostring(instanceKey)].kills == count,
      "instance parity: " .. key)
  end
end

print("S2A migration simulation passed")
print("v2_file=" .. path)
