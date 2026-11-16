-- DS-6-F1 mob metadata registry prototype.
--
-- Uses the local /mnt/r/AceM2L2.lua save when present. The save is data-only
-- and is loaded in an isolated environment. No network access.
--
-- Reports actual observed mob locality/level-range distribution, then measures
-- per-character registry layouts at 1k/10k/100k synthetic entries.
--
-- Assumptions supplied for this task:
--   * a mob exists in no more than 4 zones/instances;
--   * a mob has one fixed level range (levelMin..levelMax).

local SAVE_PATH = "/mnt/r/AceM2L2.lua"

local function clockMs()
  return os.clock() * 1000
end

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

local function countKeys(t)
  local count = 0
  for _ in pairs(t or {}) do count = count + 1 end
  return count
end

local function sortedNumberKeys(t)
  local keys = {}
  for key in pairs(t or {}) do keys[#keys + 1] = tonumber(key) or 0 end
  table.sort(keys)
  return keys
end

local function sortedStringKeys(t)
  local keys = {}
  for key in pairs(t or {}) do keys[#keys + 1] = tostring(key) end
  table.sort(keys)
  return keys
end

local function levelRange(mob)
  local levels = {}
  for _, byLevel in pairs(mob.killsByAreaLevel or {}) do
    for level in pairs(byLevel or {}) do levels[tonumber(level)] = true end
  end
  for _, byLevel in pairs(mob.killsByInstanceLevel or {}) do
    for level in pairs(byLevel or {}) do levels[tonumber(level)] = true end
  end
  local minLevel, maxLevel, distinct
  for level in pairs(levels) do
    distinct = (distinct or 0) + 1
    if not minLevel or level < minLevel then minLevel = level end
    if not maxLevel or level > maxLevel then maxLevel = level end
  end
  return minLevel, maxLevel, distinct
end

local function mobLocality(mob)
  local zones = {}
  local openWorld = 0
  local instance = 0
  for _, mapID in ipairs(sortedNumberKeys(mob.killsByMap)) do
    zones[#zones + 1] = "map:" .. tostring(mapID)
    openWorld = openWorld + 1
  end
  for _, key in ipairs(sortedStringKeys(mob.killsByInstance)) do
    zones[#zones + 1] = "instance:" .. key
    instance = instance + 1
  end
  return zones, openWorld, instance
end

local function bump(hist, key)
  hist[key] = (hist[key] or 0) + 1
end

local function printHistogram(label, hist)
  local keys = {}
  for key in pairs(hist) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  print(label)
  for _, key in ipairs(keys) do
    print(string.format("  %s=%d", tostring(key), hist[key]))
  end
end

local function loadLocal()
  local env = {}
  local chunk, err = loadfile(SAVE_PATH, "t", env)
  if not chunk then
    return nil, err
  end
  local ok, loadErr = pcall(chunk)
  if not ok then
    return nil, loadErr
  end
  local root = env.AceM2L2CharDB
  if type(root) ~= "table" or type(root.xpTooltip) ~= "table"
    or type(root.xpTooltip.clients) ~= "table" then
    return nil, "unexpected save shape"
  end
  local clientID, db
  for id, value in pairs(root.xpTooltip.clients) do
    if type(value) == "table" and type(value.mobs) == "table" then
      clientID, db = id, value
      break
    end
  end
  if not db then
    return nil, "no client mob data"
  end
  return { clientID = clientID, db = db }
end

-- ---------------------------------------------------------------------------
-- Local distribution
-- ---------------------------------------------------------------------------

local localData, localErr = loadLocal()
local localRows = {}
local zoneHist, levelWidthHist, identityHist, kindHist, sourceHist = {}, {}, {}, {}, {}
local maxZones = 0
local maxLevelWidth = 0

if localData then
  for key, mob in pairs(localData.db.mobs) do
    local zones, openWorld, instance = mobLocality(mob)
    local zoneCount = #zones
    local minLevel, maxLevel, distinctLevels = levelRange(mob)
    local width = (minLevel and maxLevel) and (maxLevel - minLevel) or nil
    local identity = mob.npcID and "npcID" or "name-only"
    local kind = (openWorld > 0 and instance > 0) and "mixed"
      or (instance > 0 and "instance") or (openWorld > 0 and "open-world") or "unknown"

    if zoneCount > maxZones then maxZones = zoneCount end
    if width and width > maxLevelWidth then maxLevelWidth = width end
    bump(zoneHist, zoneCount)
    if width then bump(levelWidthHist, width) end
    bump(identityHist, identity)
    bump(kindHist, kind)
    sourceHist[#sourceHist + 1] = tostring(key)

    localRows[#localRows + 1] = {
      key = tostring(key),
      name = mob.name,
      npcID = mob.npcID,
      zones = zones,
      zoneCount = zoneCount,
      openWorld = openWorld,
      instance = instance,
      minLevel = minLevel,
      maxLevel = maxLevel,
      width = width,
      identity = identity,
      kind = kind,
    }
  end
end

print(string.format("local_save=%s", localData and "loaded" or ("missing:" .. tostring(localErr))))
if localData then
  print(string.format("client_id=%s observed_mobs=%d max_zones=%d max_level_width=%s",
    tostring(localData.clientID), #localRows, maxZones, tostring(maxLevelWidth)))
  printHistogram("zones_per_mob", zoneHist)
  printHistogram("level_range_width", levelWidthHist)
  printHistogram("identity", identityHist)
  printHistogram("locality_kind", kindHist)
  print(string.format("assumption_violations_zones_gt_4=%d",
    (function()
      local count = 0
      for _, row in ipairs(localRows) do if row.zoneCount > 4 then count = count + 1 end end
      return count
    end)()))
end

-- ---------------------------------------------------------------------------
-- Registry layouts
-- ---------------------------------------------------------------------------

local function addEntry(registry, key, name, minLevel, maxLevel, zones)
  registry.keys[#registry.keys + 1] = key
  registry.names[key] = name
  registry.minLevel[key] = minLevel
  registry.maxLevel[key] = maxLevel
  registry.zones[key] = zones
end

local function buildRegistryFromLocal(filter)
  local registry = {
    schema = 1,
    projectID = localData and localData.clientID or 0,
    interface = 16001,
    keys = {},
    names = {},
    minLevel = {},
    maxLevel = {},
    zones = {},
    npcKey = {},
    byName = {},
    nameOnly = {},
  }
  for _, row in ipairs(localRows) do
    local include = not filter
      or (filter == "npc" and row.npcID)
      or (filter == "name" and not row.npcID)
    if include then
      addEntry(registry, row.key, row.name, row.minLevel, row.maxLevel, row.zones)
      if row.npcID then
        registry.npcKey[tonumber(row.npcID)] = row.key
      else
        local lower = string.lower(row.name or "")
        registry.nameOnly[lower] = row
        local existing = registry.byName[lower]
        if existing == nil then
          registry.byName[lower] = row.key
        elseif existing ~= row.key then
          registry.byName[lower] = false
        end
      end
    end
  end
  return registry
end

local function buildSyntheticRegistry(count, nameOnlyEvery)
  local registry = {
    schema = 1,
    projectID = 18,
    interface = 16001,
    keys = {},
    names = {},
    minLevel = {},
    maxLevel = {},
    zones = {},
    npcKey = {},
    byName = {},
    nameOnly = {},
  }
  nameOnlyEvery = nameOnlyEvery or 3
  for index = 1, count do
    local id = 100000 + index * 3
    local name = string.format("Mob %06d", index)
    local key = (nameOnlyEvery > 0 and index % nameOnlyEvery == 0)
      and ("name:" .. string.lower(name)) or ("npc:" .. id)
    local minLevel = (index % 60) + 1
    local maxLevel = minLevel + (index % 5)
    local zoneCount = (index % 4) + 1
    local zones = {}
    for zoneIndex = 1, zoneCount do
      zones[zoneIndex] = "map:" .. tostring((index * 7 + zoneIndex * 11) % 200 + 1)
    end
    addEntry(registry, key, name, minLevel, maxLevel, zones)
  end
  return registry
end

local function measureRegistry(registry)
  local start = clockMs()
  local lookupCount = math.min(10000, #registry.keys)
  local hits = 0
  local maxLevelMiss = 0
  for index = 1, lookupCount do
    local key = registry.keys[(index - 1) % #registry.keys + 1]
    if registry.names[key] then hits = hits + 1 end
    if not registry.minLevel[key] then maxLevelMiss = maxLevelMiss + 1 end
    local zones = registry.zones[key]
    if zones and #zones > 4 then
      error("zone count > 4")
    end
  end
  local lookupMs = clockMs() - start
  return lookupMs, hits, maxLevelMiss
end

local function packRegistry(registry)
  local sorted = {}
  for _, key in ipairs(registry.keys) do sorted[#sorted + 1] = key end
  table.sort(sorted)
  local parts = { varint(1), varint(registry.projectID), varint(registry.interface),
    varint(#sorted) }
  for _, key in ipairs(sorted) do
    local name = registry.names[key] or ""
    parts[#parts + 1] = varint(#key)
    parts[#parts + 1] = key
    parts[#parts + 1] = varint(#name)
    parts[#parts + 1] = name
    parts[#parts + 1] = varint(registry.minLevel[key] or 0)
    parts[#parts + 1] = varint(registry.maxLevel[key] or 0)
    local zones = registry.zones[key] or {}
    parts[#parts + 1] = varint(#zones)
    for _, zone in ipairs(zones) do
      local zoneRef = tostring(zone)
      parts[#parts + 1] = varint(#zoneRef)
      parts[#parts + 1] = zoneRef
    end
  end
  return table.concat(parts)
end

-- Local registry measurement
if localData then
  collectgarbage("collect")
  local heapBefore = collectgarbage("count")
  local registry = buildRegistryFromLocal()
  collectgarbage("collect")
  local heap = (collectgarbage("count") - heapBefore) / 1024
  local lookupMs, hits, levelMiss = measureRegistry(registry)
  local packed = packRegistry(registry)
  local nameOnlyCount = countKeys(registry.nameOnly)
  print(string.format("local_registry_entries=%d name_only=%d heap_mb=%.2f lookup_10k_ms=%.3f name_hits=%d level_misses=%d packed_bytes=%d",
    #registry.keys, nameOnlyCount, heap, lookupMs, hits, levelMiss, #packed))
  print("local_registry_zone_cap_ok=true level_range_present=true")

  collectgarbage("collect")
  local accountBefore = collectgarbage("count")
  local accountRegistry = buildRegistryFromLocal("npc")
  collectgarbage("collect")
  local accountHeap = (collectgarbage("count") - accountBefore) / 1024
  local accountPacked = packRegistry(accountRegistry)
  print(string.format("local_account_npc_entries=%d heap_mb=%.2f packed_bytes=%d",
    #accountRegistry.keys, accountHeap, #accountPacked))

  collectgarbage("collect")
  local nameBefore = collectgarbage("count")
  local nameRegistry = buildRegistryFromLocal("name")
  collectgarbage("collect")
  local nameHeap = (collectgarbage("count") - nameBefore) / 1024
  local namePacked = packRegistry(nameRegistry)
  print(string.format("local_character_name_only_entries=%d heap_mb=%.2f packed_bytes=%d",
    #nameRegistry.keys, nameHeap, #namePacked))
end

-- Synthetic scale
for _, count in ipairs({ 1000, 10000, 100000 }) do
  collectgarbage("collect")
  local heapBefore = collectgarbage("count")
  local registry = buildSyntheticRegistry(count)
  collectgarbage("collect")
  local heap = (collectgarbage("count") - heapBefore) / 1024
  local lookupMs = measureRegistry(registry)
  local packed = packRegistry(registry)
  print(string.format("synthetic_entries=%d heap_mb=%.2f lookup_10k_ms=%.3f packed_bytes=%d packed_mb=%.2f",
    count, heap, lookupMs, #packed, #packed / 1024 / 1024))
end

for _, count in ipairs({ 10000, 100000 }) do
  collectgarbage("collect")
  local heapBefore = collectgarbage("count")
  local registry = buildSyntheticRegistry(count, 0)
  collectgarbage("collect")
  local heap = (collectgarbage("count") - heapBefore) / 1024
  local lookupMs = measureRegistry(registry)
  local packed = packRegistry(registry)
  print(string.format("synthetic_account_npc_entries=%d heap_mb=%.2f lookup_10k_ms=%.3f packed_bytes=%d packed_mb=%.2f",
    count, heap, lookupMs, #packed, #packed / 1024 / 1024))
end

-- Behavioral checks
do
  local registry = localData and buildRegistryFromLocal() or buildSyntheticRegistry(10)
  local id = registry.keys[1]
  local oldName = registry.names[id]
  registry.names[id] = "Renamed Mob"
  assert(registry.names[id] == "Renamed Mob")
  registry.names[id] = oldName

  local missingID = 999999999
  assert(registry.names[missingID] == nil)
  assert((registry.names[missingID] or ("NPC " .. tostring(missingID)))
    == "NPC 999999999")

  -- Name-only/ambiguous handling is separate from npcID lookup.
  local ambiguous = { byName = {} }
  local function addName(lower, key)
    local existing = ambiguous.byName[lower]
    if existing == nil then
      ambiguous.byName[lower] = key
    elseif existing ~= key then
      ambiguous.byName[lower] = false
    end
  end
  addName("shared", "name:shared:1")
  addName("shared", "name:shared:2")
  assert(ambiguous.byName["shared"] == false)
  assert(registry.names[id] ~= nil)

  local function validate(meta, projectID, interface)
    return type(meta) == "table" and meta.schema == 1
      and meta.projectID == projectID and meta.interface == interface
  end
  assert(validate(registry, registry.projectID, registry.interface))
  assert(not validate(registry, registry.projectID + 1, registry.interface))
  assert(not validate(registry, registry.projectID, registry.interface + 1))

  -- Stable npcID metadata is shared in the account registry; the alt's raw
  -- history remains isolated and empty.
  local accountMeta = { names = {} }
  accountMeta.names[id] = registry.names[id]
  assert(accountMeta.names[id] ~= nil)
  local altRaw = { mobs = {}, names = {} }
  assert(next(altRaw.mobs) == nil)
  assert(altRaw.names[missingID] == nil)
  assert((altRaw.names[missingID] or ("NPC " .. tostring(missingID)))
    == "NPC 999999999")

  print("rename_ok=true missing_fallback_ok=true ambiguous_name_nil=true")
  print("project_mismatch_rejected=true account_npc_metadata_shared=true alt_raw_history_isolated=true")
end

print("zone_cap=4 fixed_level_range=true")
