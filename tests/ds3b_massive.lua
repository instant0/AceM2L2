-- DS-3B massive synthetic store validation.
-- Usage:
--   lua tests/ds3b_massive.lua write  [saved] [expected]
--   lua tests/ds3b_massive.lua verify [saved] [expected]
--
-- This is an offline structural capacity test, not a client benchmark.

local mode = arg[1] or "write"
local savedPath = arg[2] or "/tmp/opencode/ds3b-massive.lua"
local expectedPath = arg[3] or "/tmp/opencode/ds3b-expected.lua"
arg[1] = "forever"

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local Util = AceM2L2.KillHistory.Util
local CALIBRATION_VERSION = Util.CALIBRATION_VERSION

local function ClockMs()
  return os.clock() * 1000
end

local function CountKeys(map)
  local count = 0
  for _ in pairs(map or {}) do
    count = count + 1
  end
  return count
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
      error("cycle in synthetic data")
    end
    active[value] = true
    local keys = {}
    for key in pairs(value) do
      local keyKind = type(key)
      if keyKind ~= "number" and keyKind ~= "string" then
        error("unsupported key: " .. keyKind)
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
    error("unsupported value: " .. kind)
  end
end

local function SerializeVariable(name, value)
  local out = {}
  out[#out + 1] = name .. " = "
  Serialize(value, out, {})
  out[#out + 1] = "\n"
  return table.concat(out)
end

local function BuildProfile(now)
  local db = {
    dataSchema = 1,
    mobs = {},
    quests = {},
    deaths = {},
    levelHistory = {},
    rates = {},
    respawns = {},
    heatmaps = {},
    instances = {},
    areas = {},
    levels = {},
    areaLevels = {},
    calibration = {
      zones = {}, levels = {}, groups = {}, classes = {}, mobs = {},
    },
    calibrationVersion = CALIBRATION_VERSION,
    totals = { kills = 0, xp = 0, uniqueMobs = 0 },
    session = { startedAt = now, kills = 0, xp = 0 },
    dungeon = {
      xp = 0, kills = 0, sessionXP = 0, sessionKills = 0,
      lastInstance = 0, lastInstanceKey = nil, lastInstanceName = nil,
      lastInstanceID = 0, lastDifficultyID = 0,
    },
    goal = { targetLevel = 0, targetXP = 0, createdAt = 0 },
    economy = {
      lootValue = 0, sessionLootValue = 0, items = 0, sessionItems = 0,
      goldStart = 0, goldGained = 0, goldSpent = 0, lastMoney = 0,
      moneyKnown = false,
    },
    schemaBlocked = false,
  }

  local openKills, instanceKills = 0, 0
  local totalKills, totalXP = 0, 0
  local levelTotals, areaTotals = {}, {}
  local areaLevelTotals = {}

  for i = 1, 2000 do
    local mapID = 12 + (i % 40)
    local level = 1 + (i % 60)
    local isInstance = (i % 2 == 0)
    local instanceKey = isInstance and ("legacy:" .. tostring((i % 100) + 1)) or nil
    local mapKey = tostring(mapID)
    local mobKey = "npc:" .. tostring(100000 + i)
    local kills = 12
    local xpPerKill = 95

    local killsAtLevel = {}
    local killsByMap = {}
    local killsByAreaLevel = {}
    local killsByInstance = {}
    local killsByInstanceLevel = {}
    local contexts = {}

    for offset = 0, 11 do
      local levelKey = tostring(1 + ((level - 1 + offset) % 60))
      killsAtLevel[levelKey] = (killsAtLevel[levelKey] or 0) + 1
      levelTotals[levelKey] = (levelTotals[levelKey] or 0) + 1
      if isInstance then
        killsByInstanceLevel[instanceKey] = killsByInstanceLevel[instanceKey] or {}
        killsByInstanceLevel[instanceKey][levelKey] =
          (killsByInstanceLevel[instanceKey][levelKey] or 0) + 1
      else
        killsByAreaLevel[mapKey] = killsByAreaLevel[mapKey] or {}
        killsByAreaLevel[mapKey][levelKey] =
          (killsByAreaLevel[mapKey][levelKey] or 0) + 1
        areaLevelTotals[mapKey] = areaLevelTotals[mapKey] or {}
        areaLevelTotals[mapKey][levelKey] =
          (areaLevelTotals[mapKey][levelKey] or 0) + 1
      end
    end

    if isInstance then
      killsByInstance[instanceKey] = kills
      instanceKills = instanceKills + kills
    else
      killsByMap[mapKey] = kills
      areaTotals[mapKey] = (areaTotals[mapKey] or 0) + kills
      openKills = openKills + kills
    end

    for contextIndex = 1, 12 do
      local contextKey = string.format("p%d-m%d-g1-z%d-cnormal-bnone-%d",
        level, level, mapID, contextIndex)
      contexts[contextKey] = {
        playerLevel = level,
        mobLevel = level,
        groupSize = 1,
        mapID = mapID,
        instanceKey = instanceKey,
        classification = "normal",
        buffSig = "none",
        samples = 1,
        sumBase = xpPerKill,
        sumBuffed = xpPerKill,
        sumTotal = xpPerKill,
        minBase = xpPerKill,
        maxBase = xpPerKill,
        lastSeen = now - contextIndex,
      }
    end

    local totalMobXP = kills * xpPerKill
    db.mobs[mobKey] = {
      npcID = 100000 + i,
      name = string.format("Massive Mob %04d", i),
      classification = "normal",
      firstSeen = now - 1000,
      lastSeen = now,
      kills = kills,
      sessionKills = 0,
      totalXP = totalMobXP,
      sessionXP = 0,
      sessionXPKnown = true,
      killsAtLevel = killsAtLevel,
      killsByMap = killsByMap,
      killsByAreaLevel = killsByAreaLevel,
      killsByInstance = killsByInstance,
      killsByInstanceLevel = killsByInstanceLevel,
      contexts = contexts,
      xp = {
        samples = kills,
        sumBase = totalMobXP,
        sumBuffed = totalMobXP,
        sumTotal = totalMobXP,
        minBase = xpPerKill,
        maxBase = xpPerKill,
        lastBase = xpPerKill,
        lastTotal = xpPerKill,
      },
    }

    totalKills = totalKills + kills
    totalXP = totalXP + totalMobXP
  end

  db.totals.kills = totalKills
  db.totals.xp = totalXP
  db.totals.uniqueMobs = CountKeys(db.mobs)
  db.levels = levelTotals
  db.areas = areaTotals
  db.areaLevels = areaLevelTotals

  -- 100 instance records, 10 mobs each, 12 kills each.
  for index = 1, 100 do
    local key = "legacy:" .. tostring(index)
    local killsAtLevel = {}
    for level = 1, 60 do
      killsAtLevel[tostring(level)] = 2
    end
    -- 10 assigned mobs x 12 level entries = 120 level entries; 2 per level
    -- is 120 total for 60 levels.
    db.instances[key] = {
      instanceID = index,
      name = "Massive Instance " .. tostring(index),
      instanceType = "party",
      difficultyID = 0,
      mapID = 1234,
      kills = 120,
      xp = 120 * 95,
      sessionKills = 0,
      sessionXP = 0,
      killsAtLevel = killsAtLevel,
      firstSeen = now - 1000,
      lastSeen = now,
      legacy = true,
    }
  end
  db.dungeon.kills = instanceKills
  db.dungeon.xp = instanceKills * 95

  for index = 1, 200 do
    db.quests[index] = {
      count = 1, totalXP = 100, lastXP = 100,
      firstSeen = now - 1000, lastSeen = now,
    }
  end
  for index = 1, 100 do
    db.deaths[index] = {
      x = 0.5, y = 0.5, mapID = 12, at = now - index,
    }
  end
  for index = 1, 300 do
    local intervals = {}
    for sample = 1, 20 do
      intervals[sample] = 100 + sample
    end
    db.respawns[index] = { intervals = intervals }
  end
  for index = 1, 200 do
    db.levelHistory[index] = {
      level = 1 + (index % 60), at = now - index, kills = 12,
    }
  end
  for index = 1, 240 do
    db.rates[index] = {
      at = now - index, xp = 95, source = "kill", mapID = 12, level = 10,
    }
  end

  for zone = 1, 40 do
    local mapID = 11 + zone
    local cells = {}
    for cell = 1, 4096 do
      cells[cell] = 1
    end
    db.heatmaps[tostring(mapID)] = {
      mapID = mapID,
      gridSize = 64,
      cells = cells,
      total = 4096,
      lastSeen = now,
    }
  end

  return db, {
    mobs = 2000,
    kills = totalKills,
    xp = totalXP,
    open = openKills,
    instance = instanceKills,
    heatmapZones = 40,
    heatmapCells = 40 * 4096,
    instances = 100,
    instanceKills = instanceKills,
    contexts = 2000 * 12,
  }
end

local function Verify(db, expected, label)
  local mobs, kills, xp, open, instance = 0, 0, 0, 0, 0
  local levels, areas, areaLevels = {}, {}, {}
  local contexts = 0
  for _, mob in pairs(db.mobs or {}) do
    mobs = mobs + 1
    kills = kills + (tonumber(mob.kills) or 0)
    xp = xp + (tonumber(mob.totalXP) or 0)
    open = open + SumMap(mob.killsByMap)
    instance = instance + SumMap(mob.killsByInstance)
    contexts = contexts + CountKeys(mob.contexts)
    for key, value in pairs(mob.killsAtLevel or {}) do
      levels[key] = (levels[key] or 0) + (tonumber(value) or 0)
    end
    for key, value in pairs(mob.killsByMap or {}) do
      areas[key] = (areas[key] or 0) + (tonumber(value) or 0)
    end
    for mapKey, byLevel in pairs(mob.killsByAreaLevel or {}) do
      areaLevels[mapKey] = areaLevels[mapKey] or {}
      for levelKey, value in pairs(byLevel) do
        areaLevels[mapKey][levelKey] =
          (areaLevels[mapKey][levelKey] or 0) + (tonumber(value) or 0)
      end
    end
  end
  local instanceKills, instanceLevels = 0, 0
  for _, entry in pairs(db.instances or {}) do
    instanceKills = instanceKills + (tonumber(entry.kills) or 0)
    instanceLevels = instanceLevels + SumMap(entry.killsAtLevel)
  end
  local heatZones, heatCells, heatTotal = 0, 0, 0
  for _, zone in pairs(db.heatmaps or {}) do
    heatZones = heatZones + 1
    heatCells = heatCells + CountKeys(zone.cells)
    heatTotal = heatTotal + (tonumber(zone.total) or 0)
  end
  assert(mobs == expected.mobs, label .. ": mobs")
  assert(kills == expected.kills, label .. ": kills")
  assert(xp == expected.xp, label .. ": xp")
  assert(open == expected.open, label .. ": open")
  assert(instance == expected.instance, label .. ": instance")
  assert(contexts == expected.contexts, label .. ": contexts")
  assert(SumMap(db.levels) == kills, label .. ": levels")
  assert(SumMap(db.areas) == open, label .. ": areas")
  assert(SumNested(db.areaLevels) == open, label .. ": areaLevels")
  assert(instanceKills == expected.instanceKills, label .. ": instance summary")
  assert(instanceLevels == expected.instance, label .. ": instance levels")
  assert(heatZones == expected.heatmapZones, label .. ": heatmap zones")
  assert(heatCells == expected.heatmapCells, label .. ": heatmap cells")
  assert(heatTotal == expected.heatmapCells, label .. ": heatmap total")
  assert((tonumber(db.totals.kills) or 0) == expected.kills, label .. ": totals")
  assert((tonumber(db.totals.xp) or 0) == expected.xp, label .. ": totals xp")
  assert((tonumber(db.totals.uniqueMobs) or 0) == expected.mobs, label .. ": unique")
  return {
    mobs = mobs, kills = kills, xp = xp, open = open, instance = instance,
    contexts = contexts, heatZones = heatZones, heatCells = heatCells,
    instanceKills = instanceKills,
  }
end

local function BuildRoot(db)
  return {
    xpTooltip = {
      storageSchema = 2,
      clients = { [18] = db },
    },
  }
end

if mode == "write" then
  collectgarbage("collect")
  local heapBefore = collectgarbage("count")
  local buildStart = ClockMs()
  local db, expected = BuildProfile(os.time())
  AceM2L2CharDB = BuildRoot(db)
  local buildDone = ClockMs()
  module:EnsureDB()
  local normalizeDone = ClockMs()
  local heapAfter = collectgarbage("count")
  collectgarbage("collect")
  local heapStable = collectgarbage("count")
  local result = Verify(module.char, expected, "write")

  local serializeStart = ClockMs()
  local text = SerializeVariable("AceM2L2CharDB", AceM2L2CharDB)
  local serializeDone = ClockMs()
  local handle = assert(io.open(savedPath, "wb"))
  handle:write(text)
  handle:close()
  local saveDone = ClockMs()

  local expectedText = "return " .. (function()
    local out = {}
    Serialize(expected, out, {})
    return table.concat(out)
  end)() .. "\n"
  local expectedHandle = assert(io.open(expectedPath, "wb"))
  expectedHandle:write(expectedText)
  expectedHandle:close()

  local bytes = #text
  print("mode=write")
  print(string.format("bytes=%d", bytes))
  print(string.format("client_format_estimate_bytes=%d", math.floor(bytes * 70661 / 61783 + 0.5)))
  print(string.format("heap_before_kb=%.1f heap_after_kb=%.1f heap_stable_kb=%.1f heap_delta_mb=%.2f heap_stable_delta_mb=%.2f",
    heapBefore, heapAfter, heapStable, (heapAfter - heapBefore) / 1024,
    (heapStable - heapBefore) / 1024))
  print(string.format("build_ms=%.1f normalize_ms=%.1f serialize_ms=%.1f write_ms=%.1f",
    buildDone - buildStart, normalizeDone - buildDone,
    serializeDone - serializeStart, saveDone - serializeDone))
  print(string.format("mobs=%d kills=%d xp=%d open=%d instance=%d contexts=%d",
    result.mobs, result.kills, result.xp, result.open, result.instance,
    result.contexts))
  print(string.format("heatmap_zones=%d heatmap_cells=%d instances=%d instance_kills=%d",
    result.heatZones, result.heatCells, expected.instances, result.instanceKills))
  print("invariants=ok")
elseif mode == "verify" then
  collectgarbage("collect")
  local heapBefore = collectgarbage("count")
  local loadStart = ClockMs()
  local ok, err = pcall(dofile, savedPath)
  assert(ok, "load saved file: " .. tostring(err))
  local loadDone = ClockMs()
  module:EnsureDB()
  local normalizeDone = ClockMs()
  local heapAfter = collectgarbage("count")
  collectgarbage("collect")
  local heapStable = collectgarbage("count")
  local expected = assert(dofile(expectedPath), "load expected data")
  local result = Verify(module.char, expected, "verify")
  print("mode=verify")
  print(string.format("heap_before_kb=%.1f heap_after_kb=%.1f heap_stable_kb=%.1f heap_delta_mb=%.2f heap_stable_delta_mb=%.2f",
    heapBefore, heapAfter, heapStable, (heapAfter - heapBefore) / 1024,
    (heapStable - heapBefore) / 1024))
  print(string.format("load_ms=%.1f normalize_ms=%.1f", loadDone - loadStart,
    normalizeDone - loadDone))
  print(string.format("mobs=%d kills=%d xp=%d open=%d instance=%d contexts=%d",
    result.mobs, result.kills, result.xp, result.open, result.instance,
    result.contexts))
  print(string.format("heatmap_zones=%d heatmap_cells=%d instances=%d instance_kills=%d",
    result.heatZones, result.heatCells, expected.instances, result.instanceKills))
  print("invariants=ok")
else
  error("usage: write|verify")
end
