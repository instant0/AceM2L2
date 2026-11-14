-- DS-3 offline storage sanity check.
--
-- Usage:
--   lua tests/storage_sanity.lua [sample] [scale] [output]
--
-- Defaults:
--   sample = /mnt/r/AceM2L2.lua
--   scale  = 1
--   output = /tmp/opencode/acem2l2-storage-sanity.lua
--
-- This measures load/normalize/save/reload and compares a canonical snapshot.
-- The serializer is ours, so absolute timings are only indicative; use them to
-- compare the real sample with the synthetic copy, not as client benchmarks.

local samplePath = arg[1] or "/mnt/r/AceM2L2.lua"
local scale = tonumber(arg[2] or "1") or 1
local outputPath = arg[3] or "/tmp/opencode/acem2l2-storage-sanity.lua"
arg[1] = "forever"

local F = dofile("tests/fixtures.lua")
local module = F.Init()

local function ClockMs()
  return os.clock() * 1000
end

local function SumMap(map)
  local total = 0
  for _, value in pairs(map or {}) do
    total = total + (tonumber(value) or 0)
  end
  return total
end

local function SumNested(map)
  local total = 0
  for _, nested in pairs(map or {}) do
    if type(nested) == "table" then
      total = total + SumMap(nested)
    end
  end
  return total
end

local function CountKeys(map)
  local count = 0
  for _ in pairs(map or {}) do
    count = count + 1
  end
  return count
end

local function DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, item in pairs(value) do
    copy[DeepCopy(key)] = DeepCopy(item)
  end
  return copy
end

local function SerializeNumber(value)
  if value ~= value then
    return "(0/0)"
  elseif value == math.huge then
    return "(1/0)"
  elseif value == -math.huge then
    return "(-1/0)"
  end
  return string.format("%.17g", value)
end

local function Serialize(value, out, active)
  local kind = type(value)
  if kind == "nil" then
    out[#out + 1] = "nil"
  elseif kind == "boolean" then
    out[#out + 1] = value and "true" or "false"
  elseif kind == "number" then
    out[#out + 1] = SerializeNumber(value)
  elseif kind == "string" then
    out[#out + 1] = string.format("%q", value)
  elseif kind == "table" then
    if active[value] then
      error("cycle in saved data")
    end
    active[value] = true

    local keys = {}
    for key in pairs(value) do
      local keyKind = type(key)
      if keyKind ~= "number" and keyKind ~= "string" then
        error("unsupported saved-data key: " .. keyKind)
      end
      keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
      local aKind, bKind = type(a), type(b)
      if aKind ~= bKind then
        return aKind < bKind
      end
      return a < b
    end)

    local arrayLength = 0
    while value[arrayLength + 1] ~= nil do
      arrayLength = arrayLength + 1
    end

    out[#out + 1] = "{"
    for index = 1, arrayLength do
      Serialize(value[index], out, active)
      out[#out + 1] = ","
    end
    for _, key in ipairs(keys) do
      local isArrayKey = type(key) == "number"
        and key >= 1 and key <= arrayLength and key == math.floor(key)
      if not isArrayKey then
        out[#out + 1] = "["
        Serialize(key, out, active)
        out[#out + 1] = "]="
        Serialize(value[key], out, active)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"

    active[value] = nil
  else
    error("unsupported saved-data value: " .. kind)
  end
end

local function SerializeSavedVariable(name, value)
  local out = {}
  out[#out + 1] = name .. " = "
  Serialize(value, out, {})
  out[#out + 1] = "\n"
  return table.concat(out)
end

local function AssertAggregates(db, label)
  local mobs, mobKills, mobXP, unique = 0, 0, 0, 0
  local openKills, instanceKills, instanceLevels = 0, 0, 0
  local levels, areas, areaLevels = {}, {}, {}

  for _, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      mobs = mobs + 1
      unique = unique + 1
      mobKills = mobKills + (tonumber(mob.kills) or 0)
      mobXP = mobXP + (tonumber(mob.totalXP) or 0)
      openKills = openKills + SumMap(mob.killsByMap)
      instanceKills = instanceKills + SumMap(mob.killsByInstance)
      instanceLevels = instanceLevels + SumNested(mob.killsByInstanceLevel)
      for key, value in pairs(mob.killsAtLevel or {}) do
        levels[key] = (levels[key] or 0) + (tonumber(value) or 0)
      end
      for key, value in pairs(mob.killsByMap or {}) do
        areas[key] = (areas[key] or 0) + (tonumber(value) or 0)
      end
      for mapKey, byLevel in pairs(mob.killsByAreaLevel or {}) do
        if type(byLevel) == "table" then
          areaLevels[mapKey] = areaLevels[mapKey] or {}
          for levelKey, value in pairs(byLevel) do
            areaLevels[mapKey][levelKey] =
              (areaLevels[mapKey][levelKey] or 0) + (tonumber(value) or 0)
          end
        end
      end
    end
  end

  assert((tonumber(db.totals.kills) or 0) == mobKills, label .. ": totals.kills")
  assert((tonumber(db.totals.xp) or 0) == mobXP, label .. ": totals.xp")
  assert((tonumber(db.totals.uniqueMobs) or 0) == unique, label .. ": totals.uniqueMobs")
  assert(SumMap(db.levels) == SumMap(levels), label .. ": levels")
  assert(SumMap(db.areas) == SumMap(areas), label .. ": areas")
  assert(SumNested(db.areaLevels) == SumNested(areaLevels), label .. ": areaLevels")
  assert(SumMap(db.areas) == openKills, label .. ": open-world total")
  assert(SumMap(db.levels) == mobKills, label .. ": level total")
  assert(SumNested(db.areaLevels) == openKills, label .. ": area-level total")

  local instanceSummaryKills, instanceSummaryLevels = 0, 0
  for _, instance in pairs(db.instances or {}) do
    if type(instance) == "table" then
      instanceSummaryKills = instanceSummaryKills + (tonumber(instance.kills) or 0)
      instanceSummaryLevels = instanceSummaryLevels + SumMap(instance.killsAtLevel)
    end
  end
  assert(instanceSummaryKills == instanceKills, label .. ": instance totals")
  assert(instanceSummaryLevels == instanceLevels, label .. ": instance levels")
  assert(openKills + instanceKills == mobKills, label .. ": attributed kills")

  return {
    mobs = mobs,
    kills = mobKills,
    xp = mobXP,
    open = openKills,
    instance = instanceKills,
  }
end

local function Snapshot(db, stats)
  return {
    storageSchema = db.storageSchema,
    dataSchema = db.dataSchema,
    calibrationVersion = db.calibrationVersion,
    totals = {
      kills = tonumber(db.totals.kills) or 0,
      xp = tonumber(db.totals.xp) or 0,
      uniqueMobs = tonumber(db.totals.uniqueMobs) or 0,
    },
    session = {
      startedAt = tonumber(db.session.startedAt) or 0,
      kills = tonumber(db.session.kills) or 0,
      xp = tonumber(db.session.xp) or 0,
    },
    mobs = stats.mobs,
    quests = stats.quests,
    deaths = stats.deaths,
    respawns = stats.respawnNpcs,
    respawnSamples = stats.respawnSamples,
    heatmapZones = stats.heatmapZones,
    heatmapCells = stats.heatmapCells,
    instances = stats.instances,
    instanceKills = stats.instanceKills,
    levelRecords = stats.levelRecords,
    rateSamples = stats.rateSamples,
    contexts = stats.contexts,
    calibrationEntries = stats.calibrationEntries,
    totalTracked = stats.totalTracked,
  }
end

local function MultiplyMap(map, factor)
  for key, value in pairs(map or {}) do
    map[key] = (tonumber(value) or 0) * factor
  end
end

local function MultiplyNested(map, factor)
  for _, nested in pairs(map or {}) do
    if type(nested) == "table" then
      MultiplyMap(nested, factor)
    end
  end
end

local function RemapInstanceMap(source, copyIndex)
  local result = {}
  for key, value in pairs(source or {}) do
    local target = copyIndex == 0 and key or (tostring(key) .. "@" .. copyIndex)
    result[target] = value
  end
  return result
end

local function RemapInstanceNested(source, copyIndex)
  local result = {}
  for key, nested in pairs(source or {}) do
    local target = copyIndex == 0 and key or (tostring(key) .. "@" .. copyIndex)
    result[target] = DeepCopy(nested)
  end
  return result
end

local function ScaleDB(db, factor)
  if factor <= 1 then
    return
  end

  local originals = {}
  for key, mob in pairs(db.mobs or {}) do
    originals[#originals + 1] = { key = key, mob = mob }
  end
  table.sort(originals, function(a, b)
    return tostring(a.key) < tostring(b.key)
  end)

  local instances = {}
  for key, instance in pairs(db.instances or {}) do
    instances[#instances + 1] = { key = key, instance = instance }
  end
  table.sort(instances, function(a, b)
    return tostring(a.key) < tostring(b.key)
  end)

  -- Clone instance records first so mob copies can point at their own keys.
  for copy = 1, factor - 1 do
    for _, entry in ipairs(instances) do
      local clone = DeepCopy(entry.instance)
      clone.key = tostring(entry.key) .. "@" .. copy
      clone.name = tostring(entry.instance.name or "Unknown instance") .. " #" .. copy
      db.instances[clone.key] = clone
    end
  end

  for copy = 1, factor - 1 do
    for index, entry in ipairs(originals) do
      local source = entry.mob
      local clone = DeepCopy(source)
      local npcID = (tonumber(source.npcID) or (1000000 + index)) + copy * 100000
      clone.npcID = npcID
      clone.name = tostring(source.name or "Unknown") .. " #" .. copy
      clone.killsByInstance = RemapInstanceMap(source.killsByInstance, copy)
      clone.killsByInstanceLevel = RemapInstanceNested(source.killsByInstanceLevel, copy)
      db.mobs["npc:" .. tostring(npcID)] = clone
    end
  end

  MultiplyMap(db.levels, factor)
  MultiplyMap(db.areas, factor)
  MultiplyNested(db.areaLevels, factor)
  db.totals.kills = (tonumber(db.totals.kills) or 0) * factor
  db.totals.xp = (tonumber(db.totals.xp) or 0) * factor
  db.totals.uniqueMobs = CountKeys(db.mobs)
  db.session.kills = (tonumber(db.session.kills) or 0) * factor
  db.session.xp = (tonumber(db.session.xp) or 0) * factor
  if type(db.dungeon) == "table" then
    db.dungeon.kills = (tonumber(db.dungeon.kills) or 0) * factor
    db.dungeon.xp = (tonumber(db.dungeon.xp) or 0) * factor
    db.dungeon.sessionKills = (tonumber(db.dungeon.sessionKills) or 0) * factor
    db.dungeon.sessionXP = (tonumber(db.dungeon.sessionXP) or 0) * factor
  end

  local heatmaps = {}
  for key, zone in pairs(db.heatmaps or {}) do
    heatmaps[#heatmaps + 1] = { key = key, zone = zone }
  end
  table.sort(heatmaps, function(a, b)
    return tostring(a.key) < tostring(b.key)
  end)
  for copy = 1, factor - 1 do
    for _, entry in ipairs(heatmaps) do
      local source = entry.zone
      local mapID = tonumber(entry.key) or 0
      local clone = DeepCopy(source)
      clone.mapID = mapID + copy * 1000
      clone.cells = DeepCopy(source.cells)
      db.heatmaps[tostring(clone.mapID)] = clone
    end
  end
end

local function FileBytes(path)
  local handle = assert(io.open(path, "rb"))
  local bytes = #handle:read("*a")
  handle:close()
  return bytes
end

local loadStart = ClockMs()
local ok, err = pcall(dofile, samplePath)
assert(ok, "load sample: " .. tostring(err))
local loadDone = ClockMs()
module:EnsureDB()
local normalizeDone = ClockMs()

local aggregate = AssertAggregates(module.char, "initial")
ScaleDB(module.char, scale)
aggregate = AssertAggregates(module.char, "scaled")
local beforeStats = module:GetDataStats()
local beforeSnapshot = SerializeSavedVariable("snapshot", Snapshot(module.char, beforeStats))

local saveStart = ClockMs()
local serialized = SerializeSavedVariable("AceM2L2CharDB", AceM2L2CharDB)
local saveSerializeDone = ClockMs()
local handle = assert(io.open(outputPath, "wb"))
handle:write(serialized)
handle:close()
local saveDone = ClockMs()

AceM2L2CharDB = nil
module.char = nil
module.heatmapNormalizeCache = nil
local reloadStart = ClockMs()
local reloadOk, reloadErr = pcall(dofile, outputPath)
assert(reloadOk, "reload saved data: " .. tostring(reloadErr))
local reloadLoadDone = ClockMs()
module:EnsureDB()
local reloadNormalizeDone = ClockMs()

local afterAggregate = AssertAggregates(module.char, "reloaded")
local afterStats = module:GetDataStats()
local afterSnapshot = SerializeSavedVariable("snapshot", Snapshot(module.char, afterStats))
assert(beforeSnapshot == afterSnapshot, "snapshot changed after reload")

local bytes = FileBytes(outputPath)
print(string.format("sample=%s scale=%d", samplePath, scale))
print(string.format("file_bytes=%d", bytes))
print(string.format("load_ms=%.3f normalize_ms=%.3f save_ms=%.3f reload_ms=%.3f",
  loadDone - loadStart, normalizeDone - loadDone, saveDone - saveStart,
  reloadNormalizeDone - reloadStart))
print(string.format("save_serialize_ms=%.3f save_write_ms=%.3f",
  saveSerializeDone - saveStart, saveDone - saveSerializeDone))
print(string.format("mobs=%d kills=%d open=%d instance=%d xp=%d",
  afterAggregate.mobs, afterAggregate.kills, afterAggregate.open,
  afterAggregate.instance, afterAggregate.xp))
print(string.format("heatmap_zones=%d heatmap_cells=%d instances=%d instance_kills=%d",
  afterStats.heatmapZones, afterStats.heatmapCells, afterStats.instances,
  afterStats.instanceKills))
print(string.format("estimated_bytes=%d estimated_ratio=%.3f truncated=%s",
  afterStats.estimatedBytes, afterStats.estimatedBytes / bytes,
  tostring(afterStats.estimateTruncated)))
-- Empty/missing store must normalize to empty data, not invented totals.
AceM2L2CharDB = {}
module.char = nil
module.heatmapNormalizeCache = nil
module:EnsureDB()
local emptyStats = module:GetDataStats()
assert((tonumber(module.char.totals.kills) or 0) == 0, "empty store invented kills")
assert((tonumber(module.char.totals.xp) or 0) == 0, "empty store invented xp")
assert(emptyStats.mobs == 0 and emptyStats.heatmapZones == 0 and emptyStats.instances == 0,
  "empty store invented entries")

print("snapshot=identical")
print("aggregates=ok")
print("empty_store=ok")
