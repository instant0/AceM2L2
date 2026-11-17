-- Read-only 2x/4x/6x benchmark derived from a real SavedVariables sample.
-- Usage: lua tests/bench_real_scale.lua [/path/to/AceM2L2.lua]

local path = arg[1] or "/mnt/r/AceM2L2.lua"
local env = {}
local chunk = assert(loadfile(path, "t", env))
chunk()
local root = assert(env.AceM2L2CharDB, "AceM2L2CharDB missing")
local tooltip = root.xpTooltip or {}
local clients = tooltip.clients or {}
local base
for _, client in pairs(clients) do
  base = client
  break
end
assert(type(base) == "table", "no per-client store")

local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, item in pairs(value) do
    copy[deepCopy(key, seen)] = deepCopy(item, seen)
  end
  return copy
end

local function countKeys(value)
  local total = 0
  if type(value) == "table" then
    for _ in pairs(value) do total = total + 1 end
  end
  return total
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
    for index = 1, #keys do
      local key = keys[index]
      parts[#parts + 1] = "[" .. serialize(key, seen) .. "]="
        .. serialize(value[key], seen) .. ","
    end
    seen[value] = nil
    return "{" .. table.concat(parts) .. "}"
  elseif kind == "string" then
    return string.format("%q", value)
  elseif kind == "number" or kind == "boolean" then
    return tostring(value)
  end
  return "nil"
end

local function bytes(value)
  return #serialize(value, {})
end

local function scaleArray(value, factor)
  if type(value) ~= "table" then return value end
  local result = {}
  for copy = 1, factor do
    for _, item in ipairs(value) do
      result[#result + 1] = deepCopy(item)
    end
  end
  return result
end

local function scaledStore(factor)
  local scaled = deepCopy(base)
  scaled.mobs = {}
  local mobIndex = 0
  local kills = 0
  for key, mob in pairs(base.mobs or {}) do
    for copy = 1, factor do
      mobIndex = mobIndex + 1
      local newKey
      if tostring(key):sub(1, 4) == "npc:" then
        newKey = "npc:" .. tostring(9000000 + mobIndex)
      else
        newKey = tostring(key) .. ":" .. tostring(copy)
      end
      scaled.mobs[newKey] = deepCopy(mob)
      kills = kills + (tonumber(mob.kills) or 0)
    end
  end

  scaled.respawns = {}
  for key, entry in pairs(base.respawns or {}) do
    for copy = 1, factor do
      local id = (tonumber(key) or 0) + copy * 100000
      scaled.respawns[id] = deepCopy(entry)
    end
  end

  scaled.quests = {}
  local questIndex = 0
  for _, quest in pairs(base.quests or {}) do
    for copy = 1, factor do
      questIndex = questIndex + 1
      local copyQuest = deepCopy(quest)
      local id = 9000000 + questIndex
      copyQuest.id = id
      scaled.quests["quest:" .. tostring(id)] = copyQuest
    end
  end

  scaled.deaths = {}
  for copy = 1, factor do
    for _, death in ipairs(base.deaths or {}) do
      local copyDeath = deepCopy(death)
      copyDeath.at = (tonumber(copyDeath.at) or 0) + copy * 100000
      scaled.deaths[#scaled.deaths + 1] = copyDeath
    end
  end

  scaled.heatmaps = {}
  for mapID, entry in pairs(base.heatmaps or {}) do
    for copy = 1, factor do
      local id = (tonumber(mapID) or 0) + copy * 100000
      scaled.heatmaps[tostring(id)] = deepCopy(entry)
    end
  end

  scaled.instances = {}
  for key, entry in pairs(base.instances or {}) do
    for copy = 1, factor do
      scaled.instances[tostring(key) .. ":" .. tostring(copy)] = deepCopy(entry)
    end
  end

  scaled.rates = scaleArray(base.rates, factor)
  scaled.levelHistory = scaleArray(base.levelHistory, factor)
  scaled.totals = deepCopy(base.totals or {})
  scaled.totals.kills = kills
  scaled.totals.uniqueMobs = mobIndex
  return scaled
end

local function sectionBytes(store)
  local result = {}
  for _, name in ipairs({
    "mobs", "quests", "deaths", "respawns", "heatmaps", "instances",
    "rates", "levelHistory", "areas", "levels", "calibration",
  }) do
    result[name] = bytes(store[name])
  end
  result.client = bytes(store)
  return result
end

local baseBytes = sectionBytes(base)
print("factor,kills,mobs,quests,deaths,respawns,heatmap_zones,heatmap_cells,client_bytes,mobs_bytes,respawns_bytes,quests_bytes,heatmaps_bytes,other_bytes,serialize_ms")
for _, factor in ipairs({ 1, 2, 4, 6 }) do
  local store
  if factor == 1 then
    store = base
  else
    store = scaledStore(factor)
  end
  local started = os.clock()
  local sizes = sectionBytes(store)
  local elapsed = (os.clock() - started) * 1000
  local heatmapCells = 0
  for _, entry in pairs(store.heatmaps or {}) do
    heatmapCells = heatmapCells + countKeys(entry.cells)
  end
  local other = sizes.client - sizes.mobs - sizes.respawns - sizes.quests
    - sizes.heatmaps - sizes.instances - sizes.rates - sizes.levelHistory
    - sizes.areas - sizes.levels - sizes.calibration
  print(string.format(
    "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.1f",
    factor,
    store.totals and tonumber(store.totals.kills) or 0,
    countKeys(store.mobs), countKeys(store.quests), #(store.deaths or {}),
    countKeys(store.respawns), countKeys(store.heatmaps), heatmapCells,
    sizes.client, sizes.mobs, sizes.respawns, sizes.quests, sizes.heatmaps,
    other, elapsed
  ))
end

print("base_client_bytes=" .. tostring(baseBytes.client))
