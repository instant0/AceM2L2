-- DS-17.4D offline Account Knowledge derivation prototype.
-- Usage: lua tests/ds17_4d_knowledge.lua
--
-- Synthetic 1/3/5-character corpora are the required proof. The local real
-- SavedVariables file is optional. This harness does not write production data.

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

local function isArray(value)
  local count = #value
  if count == 0 then return false end
  for index = 1, count do
    if value[index] == nil then return false end
  end
  return true
end

local function serialize(value, seen)
  local kind = type(value)
  if kind == "table" then
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local parts = {}
    if isArray(value) then
      for index = 1, #value do
        parts[#parts + 1] = serialize(value[index], seen)
      end
    else
      local keys = {}
      for key in pairs(value) do keys[#keys + 1] = key end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      for _, key in ipairs(keys) do
        parts[#parts + 1] = "[" .. serialize(key, seen) .. "]="
          .. serialize(value[key], seen)
      end
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

local function bytes(value)
  return #serialize(value, {})
end

local function heapKB()
  collectgarbage("collect")
  return collectgarbage("count")
end

local function nowMS()
  return os.clock() * 1000
end

local function sortedArray(set, numeric)
  local list = {}
  for key in pairs(set or {}) do list[#list + 1] = key end
  table.sort(list, function(a, b)
    if numeric and type(a) == "number" and type(b) == "number" then
      return a < b
    end
    return tostring(a) < tostring(b)
  end)
  return list
end

local function sortedMapValues(map)
  local keys = {}
  for key in pairs(map or {}) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local list = {}
  for _, key in ipairs(keys) do list[#list + 1] = map[key] end
  return list
end

--[[--------------------------------------------------------------------------------
  Synthetic per-character sources
------------------------------------------------------------------------------------]]

local function newSource(key, projectID, interface, levelCap, mode)
  return {
    sourceKey = key,
    characterID = "Char-" .. key,
    projectID = projectID,
    interface = interface,
    levelCap = levelCap,
    mode = mode,
    journey = {
      mobs = {}, zones = {}, instances = {}, heatmaps = {}, quests = {},
      deaths = {}, sessions = {},
    },
  }
end

local function addMob(source, data)
  local key = data.npcID and ("npc:" .. tostring(data.npcID))
    or ("name:" .. string.lower(data.name))
  source.journey.mobs[key] = data
end

local function addZone(source, map, data)
  source.journey.zones[tostring(map)] = data
end

local function addInstance(source, key, data)
  source.journey.instances[key] = data
end

local function addHeatmap(source, map, cells, total)
  source.journey.heatmaps[tostring(map)] = {
    gridSize = 64, cells = cells, total = total, lastSeen = 100,
  }
end

local function addQuest(source, id, count, xp, lastSeen)
  source.journey.quests["quest:" .. tostring(id)] = {
    id = id, count = count, totalXP = xp, samples = count,
    lastSeen = lastSeen or 100,
  }
end

local function mobData(npcID, name, classification, minLevel, maxLevel,
  kills, xp, zones, level, combatSamples, deaths)
  local byLevel = {
    [tostring(level)] = { kills = kills, xp = xp, samples = kills },
  }
  local contexts = {
    {
      key = "solo|normal", samples = combatSamples or kills,
      deaths = deaths or 0, sumBase = xp, sumBuffed = xp, sumTotal = xp,
      minBase = 1, maxBase = 100, lastSeen = 100,
    },
  }
  local xpContexts = {
    {
      key = "solo|normal|none", samples = kills, sumXP = xp,
      sumBase = xp, sumBuffed = xp, lastSeen = 100,
    },
  }
  return {
    npcID = npcID, name = name, classification = classification,
    mobLevelMin = minLevel, mobLevelMax = maxLevel,
    mobLevelSamples = kills,
    kills = kills, xp = xp, samples = kills,
    byPlayerLevel = byLevel,
    zones = zones, instances = {},
    combat = contexts, xpContexts = xpContexts,
    respawn = {
      count = math.max(1, math.floor(kills / 4)),
      min = 20, max = 40, sum = 30 * math.max(1, math.floor(kills / 4)),
      lastSeen = 100,
    },
    firstSeen = 10, lastSeen = 100,
  }
end

local function zoneData(kills, xp, presence, engaged, deaths, level)
  return {
    kills = kills, killXP = xp, questXP = 0, otherXP = 0, xp = xp,
    presenceSeconds = presence, engagedSeconds = engaged,
    deaths = deaths or 0, sessions = 1,
    playerLevels = {
      [tostring(level)] = { kills = kills, xp = xp, samples = kills },
    },
    lastSeen = 100,
  }
end

local function buildCorpus()
  local a = newSource("A", 18, 16001, 60, "normal")
  addMob(a, mobData(101, "Defias Pillager", "normal", 8, 10, 20, 2000, { "12" }, 10, 20, 1))
  addMob(a, mobData(102, "Kobold Vermin", "normal", 5, 6, 10, 500, { "12" }, 10, 10, 0))
  addMob(a, {
    name = "Mysterious Stranger", classification = "normal",
    mobLevelMin = 10, mobLevelMax = 10, mobLevelSamples = 1,
    kills = 1, xp = 10, samples = 1,
    byPlayerLevel = { ["10"] = { kills = 1, xp = 10, samples = 1 } },
    zones = { "12" }, instances = {}, combat = {}, xpContexts = {},
    respawn = { count = 1, min = 20, max = 20, sum = 20, lastSeen = 100 },
    firstSeen = 10, lastSeen = 100,
  })
  addZone(a, 12, zoneData(31, 2610, 3600, 1800, 1, 10))
  addHeatmap(a, 12, { [1] = 5, [2] = 10, [64] = 3 }, 18)
  addQuest(a, 1, 1, 100, 100)
  addQuest(a, 2, 1, 50, 90)
  a.journey.deaths[1] = { mapID = 12, x = 0.123, y = 0.456, at = 55 }
  a.journey.sessions[1] = { startedAt = 10, endedAt = 100 }

  local b = newSource("B", 18, 16001, 60, "normal")
  addMob(b, mobData(101, "Defias Pillager", "normal", 8, 10, 30, 3000, { "12", "1421" }, 20, 30, 2))
  addMob(b, mobData(102, "Kobold Vermin", "elite", 6, 8, 5, 250, { "12" }, 20, 5, 0))
  local riverpaw = mobData(103, "Riverpaw Gnoll", "normal", 10, 12, 15, 1500, { "1424" }, 20, 15, 0)
  riverpaw.instances = { "id:555:1" }
  addMob(b, riverpaw)
  addMob(b, {
    name = "Old Bear", classification = "normal",
    mobLevelMin = 12, mobLevelMax = 12, mobLevelSamples = 2,
    kills = 2, xp = 20, samples = 2,
    byPlayerLevel = { ["20"] = { kills = 2, xp = 20, samples = 2 } },
    zones = { "1421" }, instances = {}, combat = {}, xpContexts = {},
    respawn = { count = 1, min = 30, max = 30, sum = 30, lastSeen = 100 },
    firstSeen = 10, lastSeen = 100,
  })
  addZone(b, 12, zoneData(35, 3250, 1800, 900, 2, 20))
  addZone(b, 1421, zoneData(17, 1520, 1200, 600, 0, 20))
  addZone(b, 1424, zoneData(15, 1500, 1200, 600, 0, 20))
  addInstance(b, "id:555:1", {
    name = "Test Dungeon", instanceType = "party", instanceID = 555,
    difficultyID = 1, mapID = 1234,
    kills = 3, killXP = 300, questXP = 0, otherXP = 0, xp = 300,
    presenceSeconds = 600, engagedSeconds = 300, deaths = 0, sessions = 1,
    playerLevels = { ["20"] = { kills = 3, xp = 300, samples = 3 } },
    lastSeen = 100,
  })
  addHeatmap(b, 12, { [1] = 10, [3] = 10, [64] = 5 }, 25)
  addHeatmap(b, 1421, { [2] = 4, [66] = 4 }, 8)
  addQuest(b, 1, 1, 100, 100)
  addQuest(b, 3, 1, 75, 90)

  local c = newSource("C", 18, 16001, 60, "normal")
  addMob(c, mobData(101, "Defias Pillager", "normal", 8, 10, 10, 1000, { "1421" }, 30, 10, 0))
  addMob(c, mobData(104, "Syndicate Rogue", "normal", 20, 24, 12, 1800, { "1424" }, 30, 12, 0))
  addZone(c, 1421, zoneData(10, 1000, 900, 450, 0, 30))
  addZone(c, 1424, zoneData(12, 1800, 900, 450, 0, 30))
  addInstance(c, "id:555:1", {
    name = "Test Dungeon", instanceType = "party", instanceID = 555,
    difficultyID = 1, mapID = 1234,
    kills = 2, killXP = 200, questXP = 0, otherXP = 0, xp = 200,
    presenceSeconds = 300, engagedSeconds = 150, deaths = 0, sessions = 1,
    playerLevels = { ["30"] = { kills = 2, xp = 200, samples = 2 } },
    lastSeen = 100,
  })
  addHeatmap(c, 1421, { [65] = 6, [66] = 6 }, 12)
  addHeatmap(c, 1424, { [1] = 6 }, 6)
  addQuest(c, 4, 1, 120, 100)

  local d = newSource("D", 18, 16001, 60, "normal")
  addMob(d, mobData(101, "Defias Pillager", "normal", 8, 10, 8, 800, { "12" }, 15, 8, 0))
  addMob(d, {
    name = "Mysterious Stranger", classification = "normal",
    mobLevelMin = 10, mobLevelMax = 10, mobLevelSamples = 2,
    kills = 2, xp = 20, samples = 2,
    byPlayerLevel = { ["15"] = { kills = 2, xp = 20, samples = 2 } },
    zones = { "12" }, instances = {}, combat = {}, xpContexts = {},
    respawn = { count = 1, min = 20, max = 20, sum = 20, lastSeen = 100 },
    firstSeen = 10, lastSeen = 100,
  })
  addZone(d, 12, zoneData(10, 820, 900, 450, 0, 15))
  addHeatmap(d, 12, { [2] = 4 }, 4)
  addQuest(d, 2, 1, 50, 90)

  local e = newSource("E", 18, 16001, 60, "normal")
  addMob(e, mobData(105, "Worgen", "normal", 18, 20, 9, 900, { "1421" }, 25, 9, 0))
  addMob(e, mobData(101, "Defias Pillager", "normal", 8, 10, 5, 500, { "12" }, 25, 5, 0))
  addZone(e, 12, zoneData(5, 500, 600, 300, 0, 25))
  addZone(e, 1421, zoneData(9, 900, 600, 300, 0, 25))
  addHeatmap(e, 12, { [1] = 2 }, 2)
  addHeatmap(e, 1421, { [2] = 5 }, 5)
  addQuest(e, 3, 1, 75, 90)

  local f = newSource("F", 1, 120105, 90, "midnight")
  addMob(f, mobData(999, "Outland Mob", "normal", 60, 62, 7, 700, { "999" }, 60, 7, 0))
  addZone(f, 999, zoneData(7, 700, 600, 300, 0, 60))
  addHeatmap(f, 999, { [1] = 7 }, 7)
  addQuest(f, 9, 1, 90, 100)

  return { a, b, c, d, e, f }, a, b, c, d, e, f
end

--[[--------------------------------------------------------------------------------
  Derivation
------------------------------------------------------------------------------------]]

local function sourceGroup(source)
  return table.concat({
    tostring(source.projectID), tostring(source.interface),
    tostring(source.levelCap), tostring(source.mode or "normal"),
  }, "|")
end

local function mergeLevelMap(target, source)
  if type(source) ~= "table" then return end
  for levelKey, value in pairs(source) do
    local current = target[levelKey]
    if type(value) ~= "table" then
      value = { kills = tonumber(value) or 0 }
    end
    if not current then
      current = { kills = 0, xp = 0, samples = 0 }
      target[levelKey] = current
    end
    current.kills = (tonumber(current.kills) or 0) + (tonumber(value.kills) or 0)
    current.xp = (tonumber(current.xp) or 0) + (tonumber(value.xp) or 0)
    current.samples = (tonumber(current.samples) or 0)
      + (tonumber(value.samples) or tonumber(value.kills) or 0)
  end
end

local function mergeContext(target, record)
  if type(record) ~= "table" or not record.key then return end
  local entry = target[record.key]
  if not entry then
    entry = { key = record.key }
    target[record.key] = entry
  end
  for _, field in ipairs({
    "samples", "deaths", "sumBase", "sumBuffed", "sumTotal", "sumXP",
  }) do
    entry[field] = (tonumber(entry[field]) or 0) + (tonumber(record[field]) or 0)
  end
  for _, field in ipairs({ "minBase", "maxBase" }) do
    local value = tonumber(record[field])
    if value then
      local current = tonumber(entry[field])
      if not current then
        entry[field] = value
      elseif field == "minBase" then
        entry[field] = math.min(current, value)
      else
        entry[field] = math.max(current, value)
      end
    end
  end
  entry.lastSeen = math.max(tonumber(entry.lastSeen) or 0,
    tonumber(record.lastSeen) or 0)
end

local function mergeMob(knowledge, key, record)
  local mob = record.mob
  local target = knowledge.mobs[key]
  if not target then
    target = {
      npcID = mob.npcID, name = mob.name, classification = mob.classification,
      mobLevelMin = nil, mobLevelMax = nil, mobLevelSamples = 0,
      kills = 0, xp = 0, samples = 0,
      byPlayerLevel = {}, zones = {}, instances = {},
      combat = {}, xpContexts = {},
      respawn = { count = 0, min = nil, max = nil, sum = 0, lastSeen = 0 },
      firstSeen = nil, lastSeen = 0,
    }
    knowledge.mobs[key] = target
  end
  if target.npcID == nil and mob.npcID then target.npcID = mob.npcID end
  if target.name == nil and mob.name then target.name = mob.name end
  if mob.classification then
    if target.classification == nil then
      target.classification = mob.classification
    elseif target.classification ~= mob.classification then
      target.classification = "unknown"
      target.classificationConflict = true
    end
  end
  if mob.mobLevelMin then
    target.mobLevelMin = target.mobLevelMin
      and math.min(target.mobLevelMin, mob.mobLevelMin) or mob.mobLevelMin
  end
  if mob.mobLevelMax then
    target.mobLevelMax = target.mobLevelMax
      and math.max(target.mobLevelMax, mob.mobLevelMax) or mob.mobLevelMax
  end
  target.mobLevelSamples = (target.mobLevelSamples or 0)
    + (tonumber(mob.mobLevelSamples) or 0)
  target.kills = (target.kills or 0) + (tonumber(mob.kills) or 0)
  target.xp = (target.xp or 0) + (tonumber(mob.xp) or 0)
  target.samples = (target.samples or 0)
    + (tonumber(mob.samples) or tonumber(mob.kills) or 0)
  mergeLevelMap(target.byPlayerLevel, mob.byPlayerLevel)
  for _, mapID in ipairs(mob.zones or {}) do target.zones[tostring(mapID)] = true end
  for _, instanceKey in ipairs(mob.instances or {}) do
    target.instances[instanceKey] = true
  end
  for _, context in ipairs(mob.combat or {}) do mergeContext(target.combat, context) end
  for _, context in ipairs(mob.xpContexts or {}) do
    mergeContext(target.xpContexts, context)
  end
  local respawn = mob.respawn
  if type(respawn) == "table" then
    target.respawn.count = target.respawn.count + (tonumber(respawn.count) or 0)
    target.respawn.sum = target.respawn.sum + (tonumber(respawn.sum) or 0)
    if respawn.min then
      target.respawn.min = target.respawn.min
        and math.min(target.respawn.min, respawn.min) or respawn.min
    end
    if respawn.max then
      target.respawn.max = target.respawn.max
        and math.max(target.respawn.max, respawn.max) or respawn.max
    end
    target.respawn.lastSeen = math.max(target.respawn.lastSeen,
      tonumber(respawn.lastSeen) or 0)
  end
  if mob.firstSeen then
    target.firstSeen = target.firstSeen
      and math.min(target.firstSeen, mob.firstSeen) or mob.firstSeen
  end
  target.lastSeen = math.max(target.lastSeen, tonumber(mob.lastSeen) or 0)
end

local function mergeZone(knowledge, mapKey, zone)
  local target = knowledge.zones[mapKey]
  if not target then
    target = {
      kills = 0, killXP = 0, questXP = 0, otherXP = 0, xp = 0,
      presenceSeconds = 0, engagedSeconds = 0, deaths = 0, sessions = 0,
      uniqueMobs = 0, playerLevels = {}, lastSeen = 0,
    }
    knowledge.zones[mapKey] = target
  end
  for _, field in ipairs({
    "kills", "killXP", "questXP", "otherXP", "xp",
    "presenceSeconds", "engagedSeconds", "deaths", "sessions",
  }) do
    target[field] = target[field] + (tonumber(zone[field]) or 0)
  end
  mergeLevelMap(target.playerLevels, zone.playerLevels)
  target.lastSeen = math.max(target.lastSeen, tonumber(zone.lastSeen) or 0)
end

local function mergeInstance(knowledge, instanceKey, instance)
  local target = knowledge.instances[instanceKey]
  if not target then
    target = {
      name = instance.name, instanceType = instance.instanceType,
      instanceID = instance.instanceID, difficultyID = instance.difficultyID,
      mapID = instance.mapID,
      kills = 0, killXP = 0, questXP = 0, otherXP = 0, xp = 0,
      presenceSeconds = 0, engagedSeconds = 0, deaths = 0, sessions = 0,
      uniqueMobs = 0, playerLevels = {}, lastSeen = 0,
    }
    knowledge.instances[instanceKey] = target
  elseif (tonumber(instance.lastSeen) or 0) >= (target.lastSeen or 0) then
    target.name = instance.name or target.name
    target.instanceType = instance.instanceType or target.instanceType
    target.instanceID = instance.instanceID or target.instanceID
    target.difficultyID = instance.difficultyID or target.difficultyID
    target.mapID = instance.mapID or target.mapID
  end
  for _, field in ipairs({
    "kills", "killXP", "questXP", "otherXP", "xp",
    "presenceSeconds", "engagedSeconds", "deaths", "sessions",
  }) do
    target[field] = target[field] + (tonumber(instance[field]) or 0)
  end
  mergeLevelMap(target.playerLevels, instance.playerLevels)
  target.lastSeen = math.max(target.lastSeen, tonumber(instance.lastSeen) or 0)
end

local function mergeHeatmap(knowledge, mapKey, heatmap)
  local target = knowledge.heatmaps[mapKey]
  if not target then
    target = { cells = {}, total = 0, top10 = {}, lastSeen = 0, gridSize = 64 }
    knowledge.heatmaps[mapKey] = target
  end
  for cell, count in pairs(heatmap.cells or {}) do
    target.cells[cell] = (target.cells[cell] or 0) + (tonumber(count) or 0)
  end
  target.total = target.total + (tonumber(heatmap.total) or 0)
  target.lastSeen = math.max(target.lastSeen, tonumber(heatmap.lastSeen) or 0)
end

local function finishHeatmap(heatmap)
  local rows = {}
  for cell, count in pairs(heatmap.cells) do
    rows[#rows + 1] = { cell = cell, count = count }
  end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.cell < b.cell
  end)
  local top = {}
  for index = 1, math.min(10, #rows) do top[index] = rows[index] end
  heatmap.top10 = top
end

local function mergeQuest(knowledge, key, quest)
  local target = knowledge.quests[key]
  if not target then
    target = { id = quest.id, count = 0, xp = 0, samples = 0, lastSeen = 0 }
    knowledge.quests[key] = target
  end
  target.count = target.count + (tonumber(quest.count) or 0)
  target.xp = target.xp + (tonumber(quest.totalXP) or 0)
  target.samples = target.samples + (tonumber(quest.samples) or 0)
  target.lastSeen = math.max(target.lastSeen, tonumber(quest.lastSeen) or 0)
end

local function deriveKnowledge(sources, wantedGroup)
  local filtered = {}
  for _, source in ipairs(sources) do
    if not wantedGroup or sourceGroup(source) == wantedGroup then
      filtered[#filtered + 1] = source
    end
  end
  if #filtered == 0 then return nil end
  table.sort(filtered, function(a, b)
    return tostring(a.sourceKey) < tostring(b.sourceKey)
  end)

  local first = filtered[1]
  local knowledge = {
    schema = 1,
    projectID = first.projectID,
    interface = first.interface,
    levelCap = first.levelCap,
    mode = first.mode,
    meta = { sourceCount = #filtered, rebuiltAt = 0, schema = 1 },
    mobs = {}, zones = {}, instances = {}, heatmaps = {}, quests = {},
  }
  local stats = {
    sourceMobCount = 0, sourceMobKills = 0, sourceMobXP = 0,
    sourceCombatSamples = 0,
  }
  local nameOnly = {}

  for _, source in ipairs(filtered) do
    local journey = source.journey or {}
    for _, mob in pairs(journey.mobs or {}) do
      stats.sourceMobCount = stats.sourceMobCount + 1
      stats.sourceMobKills = stats.sourceMobKills + (tonumber(mob.kills) or 0)
      stats.sourceMobXP = stats.sourceMobXP + (tonumber(mob.xp) or 0)
      for _, context in ipairs(mob.combat or {}) do
        stats.sourceCombatSamples = stats.sourceCombatSamples
          + (tonumber(context.samples) or 0)
      end
      if mob.npcID then
        mergeMob(knowledge, "npc:" .. tostring(mob.npcID), { mob = mob })
      else
        local lower = string.lower(tostring(mob.name or "unknown"))
        local list = nameOnly[lower]
        if not list then
          list = {}
          nameOnly[lower] = list
        end
        list[#list + 1] = { mob = mob, sourceKey = source.sourceKey }
      end
    end
    for mapKey, zone in pairs(journey.zones or {}) do
      mergeZone(knowledge, tostring(mapKey), zone)
    end
    for instanceKey, instance in pairs(journey.instances or {}) do
      mergeInstance(knowledge, instanceKey, instance)
    end
    for mapKey, heatmap in pairs(journey.heatmaps or {}) do
      mergeHeatmap(knowledge, tostring(mapKey), heatmap)
    end
    for questKey, quest in pairs(journey.quests or {}) do
      local id = quest.id or tonumber((questKey:gsub("^quest:", "")))
      mergeQuest(knowledge, "quest:" .. tostring(id), quest)
    end
  end

  local lowerNames = {}
  for lower in pairs(nameOnly) do lowerNames[#lowerNames + 1] = lower end
  table.sort(lowerNames)
  for _, lower in ipairs(lowerNames) do
    local list = nameOnly[lower]
    table.sort(list, function(a, b)
      if a.sourceKey ~= b.sourceKey then return a.sourceKey < b.sourceKey end
      return tostring(a.mob.name) < tostring(b.mob.name)
    end)
    for index, record in ipairs(list) do
      local key
      if #list == 1 then
        key = "name:" .. lower
      else
        key = "name-ambiguous:" .. lower .. ":" .. tostring(index)
      end
      mergeMob(knowledge, key, record)
    end
  end

  for _, mob in pairs(knowledge.mobs) do
    mob.zones = sortedArray(mob.zones, true)
    mob.instances = sortedArray(mob.instances, false)
    mob.combat = sortedMapValues(mob.combat)
    mob.xpContexts = sortedMapValues(mob.xpContexts)
  end
  for _, heatmap in pairs(knowledge.heatmaps) do finishHeatmap(heatmap) end

  for _, mob in pairs(knowledge.mobs) do
    for _, mapKey in ipairs(mob.zones) do
      local zone = knowledge.zones[tostring(mapKey)]
      if zone then zone.uniqueMobs = zone.uniqueMobs + 1 end
    end
    for _, instanceKey in ipairs(mob.instances) do
      local instance = knowledge.instances[instanceKey]
      if instance then instance.uniqueMobs = instance.uniqueMobs + 1 end
    end
  end

  local rebuiltAt = 0
  for _, mob in pairs(knowledge.mobs) do
    rebuiltAt = math.max(rebuiltAt, tonumber(mob.lastSeen) or 0)
  end
  for _, zone in pairs(knowledge.zones) do
    rebuiltAt = math.max(rebuiltAt, tonumber(zone.lastSeen) or 0)
  end
  for _, instance in pairs(knowledge.instances) do
    rebuiltAt = math.max(rebuiltAt, tonumber(instance.lastSeen) or 0)
  end
  for _, heatmap in pairs(knowledge.heatmaps) do
    rebuiltAt = math.max(rebuiltAt, tonumber(heatmap.lastSeen) or 0)
  end
  for _, quest in pairs(knowledge.quests) do
    rebuiltAt = math.max(rebuiltAt, tonumber(quest.lastSeen) or 0)
  end
  knowledge.meta.rebuiltAt = rebuiltAt
  return knowledge, stats
end

local function knowledgeGroup(knowledge)
  return table.concat({
    tostring(knowledge.projectID), tostring(knowledge.interface),
    tostring(knowledge.levelCap), tostring(knowledge.mode or "normal"),
  }, "|")
end

--[[--------------------------------------------------------------------------------
  Queries and confidence
------------------------------------------------------------------------------------]]

local function queryMob(knowledge, npcID)
  return knowledge.mobs["npc:" .. tostring(npcID)]
end

local function queryZone(knowledge, mapID)
  return knowledge.zones[tostring(mapID)]
end

local function queryInstance(knowledge, key)
  return knowledge.instances[key]
end

local function queryHeatmap(knowledge, mapID)
  return knowledge.heatmaps[tostring(mapID)]
end

local function queryQuest(knowledge, questID)
  return knowledge.quests["quest:" .. tostring(questID)]
end

local function wilson(successes, total, z)
  if not total or total <= 0 then return 0, 1 end
  z = z or 1.96
  local p = successes / total
  local denominator = 1 + z * z / total
  local centre = (p + z * z / (2 * total)) / denominator
  local margin = z * math.sqrt(
    (p * (1 - p) + z * z / (4 * total)) / total
  ) / denominator
  return math.max(0, centre - margin), math.min(1, centre + margin)
end

local function bench(fn, iterations)
  local start = nowMS()
  for _ = 1, iterations do fn() end
  return (nowMS() - start) * 1000 / iterations
end

--[[--------------------------------------------------------------------------------
  Run
------------------------------------------------------------------------------------]]

local sources = buildCorpus()
local group18 = sourceGroup(sources[1])
local group1 = sourceGroup(sources[6])

print("# DS-17.4D Account Knowledge prototype")
print("")

local function corpusSources(count)
  local list = {}
  for index = 1, count do list[index] = sources[index] end
  return list
end

local function summarize(knowledge)
  local counts = {
    mobs = countKeys(knowledge.mobs),
    zones = countKeys(knowledge.zones),
    instances = countKeys(knowledge.instances),
    heatmaps = countKeys(knowledge.heatmaps),
    quests = countKeys(knowledge.quests),
  }
  return counts
end

print("## Corpus growth")
print("")
print("| Sources | Mobs | Zones | Instances | Heatmaps | Quests | Serialized bytes | Heap delta KB | Derive ms |")
print("|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
local corpusKnowledge = {}
for _, count in ipairs({ 1, 3, 5 }) do
  local list = corpusSources(count)
  local before = heapKB()
  local start = nowMS()
  local knowledge = deriveKnowledge(list, group18)
  local elapsed = nowMS() - start
  local after = heapKB()
  corpusKnowledge[count] = knowledge
  local counts = summarize(knowledge)
  print(string.format("| %d | %d | %d | %d | %d | %d | %d | %.1f | %.1f |",
    count, counts.mobs, counts.zones, counts.instances, counts.heatmaps,
    counts.quests, bytes(knowledge), after - before, elapsed))
end
print("")

local knowledge5 = corpusKnowledge[5]
local counts5 = summarize(knowledge5)
local stats5 = select(2, deriveKnowledge(corpusSources(5), group18))

print("## Coverage and merge")
print("")
print(string.format("source_mobs=%d merged_mobs=%d", stats5.sourceMobCount, counts5.mobs))
print(string.format("source_kills=%d knowledge_kills=%d",
  stats5.sourceMobKills, (function()
    local total = 0
    for _, mob in pairs(knowledge5.mobs) do total = total + mob.kills end
    return total
  end)()))
print(string.format("source_xp=%d knowledge_xp=%d",
  stats5.sourceMobXP, (function()
    local total = 0
    for _, mob in pairs(knowledge5.mobs) do total = total + mob.xp end
    return total
  end)()))
print(string.format("source_combat_samples=%d knowledge_combat_samples=%d",
  stats5.sourceCombatSamples, (function()
    local total = 0
    for _, mob in pairs(knowledge5.mobs) do
      for _, context in ipairs(mob.combat) do
        total = total + context.samples
      end
    end
    return total
  end)()))
print("")

local defias = queryMob(knowledge5, 101)
local kobold = queryMob(knowledge5, 102)
print("## Representative rows")
print("")
print(string.format("defias.kills=%d defias.xp=%d defias.zones=%s",
  defias.kills, defias.xp, table.concat(defias.zones, ",")))
print(string.format("kobold.classification=%s conflict=%s",
  tostring(kobold.classification), tostring(kobold.classificationConflict)))
local ambiguous = 0
for key in pairs(knowledge5.mobs) do
  if key:find("name%-ambiguous:") then ambiguous = ambiguous + 1 end
end
print(string.format("ambiguous_name_rows=%d", ambiguous))
print("")

print("## Heatmap and zone rate")
print("")
local heatmap = queryHeatmap(knowledge5, 1421)
print(string.format("heatmap_1421 cells=%d total=%d top10=%d top1=%d",
  countKeys(heatmap.cells), heatmap.total, #heatmap.top10,
  heatmap.top10[1] and heatmap.top10[1].count or 0))
local zone = queryZone(knowledge5, 1421)
local xpPerHour = zone.engagedSeconds > 0
  and zone.xp / zone.engagedSeconds * 3600 or 0
print(string.format("zone_1421 kills=%d xp=%d engaged=%d xp_per_hour=%.0f",
  zone.kills, zone.xp, zone.engagedSeconds, xpPerHour))
local low, high = wilson(defias.combat[1].deaths, defias.combat[1].samples)
print(string.format("defias_danger=%d/%d wilson=%.3f-%.3f",
  defias.combat[1].deaths, defias.combat[1].samples, low, high))
print("")

print("## Idempotence and rebuild")
print("")
local firstBytes = bytes(knowledge5)
local reverse = {}
for index = #sources - 1, 1, -1 do reverse[#reverse + 1] = sources[index] end
local reversedKnowledge = deriveKnowledge(reverse, group18)
local afterDelete = deriveKnowledge({ sources[1], sources[2], sources[3], sources[5] }, group18)
print(string.format("idempotent=%s source_order_independent=%s",
  tostring(bytes(deriveKnowledge(corpusSources(5), group18)) == firstBytes),
  tostring(bytes(reversedKnowledge) == firstBytes)))
print(string.format("deleted_source_mobs=%d ambiguous_after_delete=%d",
  countKeys(afterDelete.mobs), (function()
    local total = 0
    for key in pairs(afterDelete.mobs) do
      if key:find("name%-ambiguous:") then total = total + 1 end
    end
    return total
  end)()))
print("")

print("## Project separation")
print("")
local mixed = { sources[1], sources[6] }
local only18 = deriveKnowledge(mixed, group18)
local only1 = deriveKnowledge(mixed, group1)
print(string.format("group18_sources=%d group18_has_999=%s",
  only18.meta.sourceCount, tostring(queryMob(only18, 999) ~= nil)))
print(string.format("group1_sources=%d group1_has_999=%s",
  only1.meta.sourceCount, tostring(queryMob(only1, 999) ~= nil)))
print("")

print("## Query latency")
print("")
local iterations = 20000
print(string.format("mob_us=%.3f zone_us=%.3f instance_us=%.3f heatmap_us=%.3f quest_us=%.3f",
  bench(function() queryMob(knowledge5, 101) end, iterations),
  bench(function() queryZone(knowledge5, 1421) end, iterations),
  bench(function() queryInstance(knowledge5, "id:555:1") end, iterations),
  bench(function() queryHeatmap(knowledge5, 1421) end, iterations),
  bench(function() queryQuest(knowledge5, 1) end, iterations)))
print("")

print("## Source-field boundary")
print("")
local serialized = serialize(knowledge5, {})
local function containsKey(value, target, seen)
  if type(value) ~= "table" then return false end
  seen = seen or {}
  if seen[value] then return false end
  seen[value] = true
  for key, item in pairs(value) do
    if key == target then return true end
    if containsKey(item, target, seen) then return true end
  end
  return false
end
local clean = knowledge5.journey == nil
  and knowledge5.deaths == nil
  and knowledge5.sessions == nil
  and not containsKey(knowledge5, "characterID")
  and not containsKey(knowledge5, "sourceKey")
  and not containsKey(knowledge5, "x")
  and not containsKey(knowledge5, "y")
  and not serialized:find("Char-", 1, true)
print(string.format("aggregate_only=%s", tostring(clean)))
print("")

-- Assertions
local one = corpusKnowledge[1]
local three = corpusKnowledge[3]
assert(one.meta.sourceCount == 1, "1-source count")
assert(three.meta.sourceCount == 3, "3-source count")
assert(knowledge5.meta.sourceCount == 5, "5-source count")
assert(defias.kills == 73, "shared NPC kills were not additive")
assert(defias.xp == 7300, "shared NPC XP was not additive")
assert(kobold.classification == "unknown" and kobold.classificationConflict,
  "conflicting classification was not marked")
assert(ambiguous == 2, "ambiguous name-only mobs merged")
assert(queryMob(knowledge5, 999) == nil, "project 1 mob leaked into project 18")
assert(only18.meta.sourceCount == 1 and only18.projectID == 18, "project 18 filter")
assert(only1.meta.sourceCount == 1 and only1.projectID == 1, "project 1 filter")
assert(bytes(reversedKnowledge) == firstBytes, "source order changed bytes")
assert(countKeys(afterDelete.mobs) < counts5.mobs, "deleted source did not change knowledge")
assert(clean, "derived output contains source-only fields")
assert(#heatmap.top10 <= 10 and #heatmap.top10 > 0, "top-10 summary")
assert(xpPerHour > 0, "zone XP/hour not computable")

-- Source tables are not mutated.
local beforeSources = bytes(sources)
deriveKnowledge(corpusSources(5), group18)
assert(bytes(sources) == beforeSources, "source tables were mutated")

print("Account Knowledge prototype passed")
