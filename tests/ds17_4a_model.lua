-- DS-17.4A Journey/Knowledge model validation harness.
-- Local save inventory, context cardinality, schema shape, and retention checks.
-- No network. Loads /mnt/r/AceM2L2.lua when present.

local SAVE_PATH = "/mnt/r/AceM2L2.lua"

local function clockMs() return os.clock() * 1000 end
local function countKeys(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

local function varint(value)
  value = math.floor(tonumber(value) or 0)
  if value < 0 then value = 0 end
  local parts = {}
  repeat
    local byte = value % 128
    value = math.floor(value / 128)
    if value > 0 then byte = byte + 128 end
    parts[#parts + 1] = string.char(byte)
  until value == 0
  return table.concat(parts)
end

local function loadLocal()
  local env = {}
  local chunk, err = loadfile(SAVE_PATH, "t", env)
  if not chunk then return nil, err end
  local ok, loadErr = pcall(chunk)
  if not ok then return nil, loadErr end
  local root = env.AceM2L2CharDB
  if type(root) ~= "table" or type(root.xpTooltip) ~= "table" then
    return nil, "unexpected save shape"
  end
  for id, db in pairs(root.xpTooltip.clients or {}) do
    if type(db) == "table" and type(db.mobs) == "table" then
      return { id = id, db = db }
    end
  end
  return nil, "no client data"
end

local localData, localErr = loadLocal()
print("local_save=" .. (localData and "loaded" or ("missing:" .. tostring(localErr))))

-- ---------------------------------------------------------------------------
-- Local inventory
-- ---------------------------------------------------------------------------

if localData then
  local db = localData.db
  local mobFields = {}
  local contextFields = {}
  local deathFields = {}
  local contextMobs, contextEntries = 0, 0
  for _, mob in pairs(db.mobs or {}) do
    for key, value in pairs(mob) do
      local entry = mobFields[key] or { count = 0, type = type(value) }
      entry.count = entry.count + 1
      mobFields[key] = entry
    end
    local count = countKeys(mob.contexts)
    if count > 0 then contextMobs = contextMobs + 1 end
    contextEntries = contextEntries + count
    for _, context in pairs(mob.contexts or {}) do
      for key, value in pairs(context) do
        local entry = contextFields[key] or { count = 0, type = type(value) }
        entry.count = entry.count + 1
        contextFields[key] = entry
      end
    end
  end
  for _, death in pairs(db.deaths or {}) do
    for key, value in pairs(death) do
      local entry = deathFields[key] or { count = 0, type = type(value) }
      entry.count = entry.count + 1
      deathFields[key] = entry
    end
  end

  local heatmapCells, cellType = 0, "none"
  for _, heatmap in pairs(db.heatmaps or {}) do
    for _, cell in pairs(heatmap.cells or {}) do
      heatmapCells = heatmapCells + 1
      cellType = type(cell)
    end
  end

  local function hasField(fields, name) return fields[name] ~= nil end
  print(string.format("local_mobs=%d local_areas=%d local_instances=%d local_levels=%d local_deaths=%d local_quests=%d local_heatmap_cells=%d cell_type=%s",
    countKeys(db.mobs), countKeys(db.areas), countKeys(db.instances),
    countKeys(db.levels), countKeys(db.deaths), countKeys(db.quests),
    heatmapCells, cellType))
  print(string.format("local_context_mobs=%d local_context_entries=%d context_buffSig=%s context_groupSize=%s context_health=%s context_combatSplit=%s",
    contextMobs, contextEntries,
    tostring(hasField(contextFields, "buffSig")),
    tostring(hasField(contextFields, "groupSize")),
    tostring(hasField(contextFields, "health") or hasField(contextFields, "healthBand")),
    tostring(hasField(contextFields, "combat"))))
  print(string.format("local_death_mob=%s death_health=%s death_buffs=%s death_group=%s death_class=%s death_difficulty=%s",
    tostring(hasField(deathFields, "mobKey") or hasField(deathFields, "npcID")),
    tostring(hasField(deathFields, "health") or hasField(deathFields, "healthBand")),
    tostring(hasField(deathFields, "buffSig")),
    tostring(hasField(deathFields, "groupSize")),
    tostring(hasField(deathFields, "classification")),
    tostring(hasField(deathFields, "difficulty"))))
  print("local_active_seconds=false local_combat_outcomes=false local_xp_contexts=false local_heatmap_xp_time=false")
end

-- ---------------------------------------------------------------------------
-- Context cardinality and top-N coverage
-- ---------------------------------------------------------------------------

local function buildContexts(mobCount, contextsPerMob)
  local mobs = {}
  local totalKills, totalXP = 0, 0
  for mobIndex = 1, mobCount do
    local contexts = {}
    local mobKills, mobXP = 0, 0
    for contextIndex = 1, contextsPerMob do
      local common = contextIndex <= math.max(1, math.floor(contextsPerMob * 0.5))
      local playerLevel = common and (10 + (contextIndex % 50)) or (1 + (mobIndex + contextIndex) % 60)
      local mobLevel = common and (10 + (mobIndex % 10)) or (1 + (mobIndex + contextIndex * 3) % 60)
      local healthBand = common and (contextIndex % 2 + 4) or (1 + contextIndex % 5)
      local buffSig = common and ("b" .. (contextIndex % 2 + 1)) or ("b" .. (contextIndex % 8 + 1))
      local groupSize = common and (contextIndex % 2 + 1) or (1 + contextIndex % 5)
      local classification = common and "normal" or ({"normal","elite","rare","worldboss"})[1 + contextIndex % 4]
      local difficulty = common and 1 or (1 + contextIndex % 3)
      local key = string.format("%d|%d|%d|%s|%d|%s|%d",
        playerLevel, mobLevel, healthBand, buffSig, groupSize, classification, difficulty)
      local kills = common and (10 + contextIndex * 3) or (1 + (mobIndex + contextIndex) % 5)
      local xp = kills * (40 + mobLevel)
      contexts[key] = {
        playerLevel=playerLevel, mobLevel=mobLevel, healthBand=healthBand,
        buffSig=buffSig, groupSize=groupSize, classification=classification,
        difficulty=difficulty, kills=kills, xp=xp,
      }
      mobKills = mobKills + kills
      mobXP = mobXP + xp
    end
    contexts.mobKills = mobKills
    contexts.mobXP = mobXP
    mobs[mobIndex] = contexts
    totalKills = totalKills + mobKills
    totalXP = totalXP + mobXP
  end
  return mobs, totalKills, totalXP
end

local function contextCoverage(mobs, topN)
  local entries, keptEntries = 0, 0
  local keptKills, keptXP = 0, 0
  local totalKills, totalXP = 0, 0
  for _, contexts in ipairs(mobs) do
    local list = {}
    for key, context in pairs(contexts) do
      if type(context) == "table" then list[#list + 1] = context end
    end
    table.sort(list, function(a, b) return (a.kills or 0) > (b.kills or 0) end)
    for index, context in ipairs(list) do
      entries = entries + 1
      totalKills = totalKills + context.kills
      totalXP = totalXP + context.xp
      if index <= topN then
        keptEntries = keptEntries + 1
        keptKills = keptKills + context.kills
        keptXP = keptXP + context.xp
      end
    end
  end
  return entries, keptEntries,
    (totalKills > 0 and keptKills / totalKills or 0),
    (totalXP > 0 and keptXP / totalXP or 0)
end

local CONTEXT_MOBS = 10000
local CONTEXT_PER_MOB = 12
local function heapOf(fn)
  collectgarbage("collect")
  local before = collectgarbage("count")
  local value = fn()
  collectgarbage("collect")
  local after = collectgarbage("count")
  return (after - before) / 1024, value
end
collectgarbage("collect")
local contextHeapBefore = collectgarbage("count")
local contextMobs, totalContextKills, totalContextXP = buildContexts(CONTEXT_MOBS, CONTEXT_PER_MOB)
collectgarbage("collect")
local fullHeap = (collectgarbage("count") - contextHeapBefore) / 1024
local entries = contextCoverage(contextMobs, CONTEXT_PER_MOB)
print(string.format("context_mobs=%d contexts_per_mob=%d full_entries=%d full_heap_mb=%.2f",
  CONTEXT_MOBS, CONTEXT_PER_MOB, entries, fullHeap))
local function buildTrimmed(mobs, topN)
  local trimmed = {}
  for mobIndex, contexts in ipairs(mobs) do
    local list = {}
    for key, context in pairs(contexts) do
      if type(context) == "table" then list[#list + 1] = context end
    end
    table.sort(list, function(a, b) return (a.kills or 0) > (b.kills or 0) end)
    local keep = {}
    for index = 1, math.min(topN, #list) do
      local source = list[index]
      keep[index] = {
        playerLevel = source.playerLevel, mobLevel = source.mobLevel,
        healthBand = source.healthBand, buffSig = source.buffSig,
        groupSize = source.groupSize, classification = source.classification,
        difficulty = source.difficulty, kills = source.kills, xp = source.xp,
      }
    end
    trimmed[mobIndex] = keep
  end
  return trimmed
end

for _, topN in ipairs({4, 8, 12}) do
  local totalEntries, keptEntries, killCoverage, xpCoverage = contextCoverage(contextMobs, topN)
  local trimmedHeap = heapOf(function() return buildTrimmed(contextMobs, topN) end)
  print(string.format("context_top=%d kept_entries=%d kill_coverage=%.3f xp_coverage=%.3f heap_mb=%.2f",
    topN, keptEntries, killCoverage, xpCoverage, trimmedHeap))
end

-- ---------------------------------------------------------------------------
-- Schema shape: nested vs parallel arrays vs packed metadata
-- ---------------------------------------------------------------------------

local function makeRows(count)
  local rows = {}
  for index = 1, count do
    local id = 100000 + index * 3
    local zoneCount = (index % 4) + 1
    local zones = {}
    for zoneIndex = 1, zoneCount do
      zones[zoneIndex] = "map:" .. tostring((index * 7 + zoneIndex * 11) % 200 + 1)
    end
    rows[index] = {
      key = "npc:" .. id,
      id = id,
      name = string.format("Mob %06d", index),
      levelMin = (index % 60) + 1,
      levelMax = (index % 60) + 1 + (index % 5),
      zones = zones,
      kills = (index % 50) + 1,
      xp = ((index % 50) + 1) * 50,
    }
  end
  return rows
end

local function nestedRegistry(rows)
  local registry = {}
  for _, row in ipairs(rows) do
    registry[row.key] = {
      name = row.name, levelMin = row.levelMin, levelMax = row.levelMax,
      zones = row.zones, kills = row.kills, xp = row.xp,
    }
  end
  return registry
end

local function parallelRegistry(rows)
  local registry = { keys = {}, names = {}, levelMin = {}, levelMax = {},
    zones = {}, kills = {}, xp = {} }
  for index, row in ipairs(rows) do
    registry.keys[index] = row.key
    registry.names[row.key] = row.name
    registry.levelMin[row.key] = row.levelMin
    registry.levelMax[row.key] = row.levelMax
    registry.zones[row.key] = row.zones
    registry.kills[row.key] = row.kills
    registry.xp[row.key] = row.xp
  end
  return registry
end

local function packedMetadata(rows)
  local parts = { varint(#rows) }
  for _, row in ipairs(rows) do
    parts[#parts + 1] = varint(#row.key); parts[#parts + 1] = row.key
    parts[#parts + 1] = varint(#row.name); parts[#parts + 1] = row.name
    parts[#parts + 1] = varint(row.levelMin)
    parts[#parts + 1] = varint(row.levelMax)
    parts[#parts + 1] = varint(#row.zones)
    for _, zone in ipairs(row.zones) do
      parts[#parts + 1] = varint(#zone); parts[#parts + 1] = zone
    end
    parts[#parts + 1] = varint(row.kills)
    parts[#parts + 1] = varint(row.xp)
  end
  return table.concat(parts)
end

for _, count in ipairs({10000, 100000}) do
  local rows = makeRows(count)
  local nestedHeap = heapOf(function() return nestedRegistry(rows) end)
  local parallelHeap = heapOf(function() return parallelRegistry(rows) end)
  local packed = packedMetadata(rows)
  local lookupStart = clockMs()
  local nested = nestedRegistry(rows)
  for index = 1, math.min(10000, count) do
    assert(nested[rows[index].key].name ~= nil)
  end
  local nestedLookup = clockMs() - lookupStart
  local parallelStart = clockMs()
  local parallel = parallelRegistry(rows)
  for index = 1, math.min(10000, count) do
    assert(parallel.names[rows[index].key] ~= nil)
  end
  local parallelLookup = clockMs() - parallelStart
  print(string.format("schema_entries=%d nested_heap_mb=%.2f parallel_heap_mb=%.2f packed_bytes=%d packed_mb=%.2f nested_lookup_10k_ms=%.3f parallel_lookup_10k_ms=%.3f",
    count, nestedHeap, parallelHeap, #packed, #packed / 1024 / 1024,
    nestedLookup, parallelLookup))
  rows = nil; nested = nil; parallel = nil; packed = nil
  collectgarbage("collect")
end

-- ---------------------------------------------------------------------------
-- Heatmap downsampling
-- ---------------------------------------------------------------------------

local function makeGrid(size, density)
  local cells = {}
  local total = 0
  local step = math.max(1, math.floor(size * size * density))
  for index = 1, step do
    local cell = (index * 17) % (size * size) + 1
    local value = (index % 20) + 1
    cells[cell] = (cells[cell] or 0) + value
    total = total + value
  end
  return cells, total
end

local function downsample(cells, fromSize, toSize)
  local result = {}
  local ratio = fromSize / toSize
  for cell, count in pairs(cells) do
    local x = (cell - 1) % fromSize
    local y = math.floor((cell - 1) / fromSize)
    local nx = math.floor(x / ratio)
    local ny = math.floor(y / ratio)
    local target = ny * toSize + nx + 1
    result[target] = (result[target] or 0) + count
  end
  return result
end

local grid64, gridTotal = makeGrid(64, 0.15)
for _, size in ipairs({32, 16}) do
  local grid = downsample(grid64, 64, size)
  local sum = 0
  for _, value in pairs(grid) do sum = sum + value end
  print(string.format("heatmap_from=64 to=%d cells=%d source_cells=%d total=%d sum=%d total_preserved=%s",
    size, countKeys(grid), countKeys(grid64), gridTotal, sum,
    tostring(sum == gridTotal)))
end

-- ---------------------------------------------------------------------------
-- Account Knowledge mapping / gaps
-- ---------------------------------------------------------------------------

print("knowledge_map=mobs->mobs;combat->danger;xpContexts->xp;zones->zones;instances->instances;heatmaps->heatmaps;quests->quests;respawns->respawns")
print("knowledge_exclude=character_identity;session_timeline;raw_kills;exact_death_coords")
print("model_gaps=activeSeconds;combatContexts;xpContexts;deathAttribution;deathHealth;deathBuffs;deathGroup;heatmapXPTime;perZoneTime")
print("no_merge_implemented=true")
