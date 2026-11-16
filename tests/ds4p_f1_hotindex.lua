-- DS-4P-F1 hot-index memory variants.
-- Usage: lua tests/ds4p_f1_hotindex.lua <variant> <mobs>
-- Variants: baseline, static, static_noidx, interned, records, stringkeys

local variant = arg[1] or "baseline"
local mobs = tonumber(arg[2] or "10000") or 10000
local VALID = {
  baseline = true, static = true, static_noidx = true,
  interned = true, records = true, stringkeys = true,
}
assert(VALID[variant], "unknown variant: " .. variant)

local function clockMs()
  return os.clock() * 1000
end

local function buildShared()
  local shared = { names = {}, byName = {} }
  local start = clockMs()
  for id = 1, mobs do
    local name = string.format("Mob %06d", id)
    shared.names[id] = name
    shared.byName[string.lower(name)] = id
  end
  collectgarbage("collect")
  return shared, clockMs() - start
end

local function buildHot(shared)
  local hot = { byName = {} }
  local start = clockMs()
  if variant == "baseline" then
    hot.names, hot.kills, hot.xp, hot.zone = {}, {}, {}, {}
    for id = 1, mobs do
      local name = string.format("Mob %06d", id)
      hot.names[id] = name
      hot.kills[id] = 12
      hot.xp[id] = 12 * 95
      hot.zone[id] = (id % 200) + 1
      hot.byName[string.lower(name)] = id
    end
  elseif variant == "static" then
    hot.names, hot.kills, hot.xp, hot.zone = {}, {}, {}, {}
    for id = 1, mobs do
      local name = string.format("Mob %06d", id)
      hot.kills[id] = 12
      hot.xp[id] = 12 * 95
      hot.zone[id] = (id % 200) + 1
      if id % 10 == 0 then
        hot.names[id] = name
        hot.byName[string.lower(name)] = id
      end
    end
  elseif variant == "static_noidx" then
    hot.names, hot.kills, hot.xp, hot.zone = {}, {}, {}, {}
    for id = 1, mobs do
      hot.kills[id] = 12
      hot.xp[id] = 12 * 95
      hot.zone[id] = (id % 200) + 1
      if id % 10 == 0 then
        hot.names[id] = string.format("Mob %06d", id)
      end
    end
  elseif variant == "interned" then
    hot.nameId, hot.kills, hot.xp, hot.zone = {}, {}, {}, {}
    for id = 1, mobs do
      hot.nameId[id] = id
      hot.kills[id] = 12
      hot.xp[id] = 12 * 95
      hot.zone[id] = (id % 200) + 1
    end
  elseif variant == "records" then
    hot.records = {}
    for id = 1, mobs do
      local name = string.format("Mob %06d", id)
      hot.records[id] = {
        kills = 12, xp = 12 * 95, zone = (id % 200) + 1, name = name,
      }
      hot.byName[string.lower(name)] = id
    end
  elseif variant == "stringkeys" then
    for id = 1, mobs do
      local name = string.format("Mob %06d", id)
      local key = "npc:" .. tostring(id)
      hot[key] = {
        kills = 12, xp = 12 * 95, zone = (id % 200) + 1, name = name,
      }
      hot.byName[string.lower(name)] = key
    end
  end
  collectgarbage("collect")
  return hot, clockMs() - start
end

local function getRecord(hot, id)
  local v = variant
  if v == "records" then
    return hot.records[id]
  elseif v == "stringkeys" then
    return hot["npc:" .. tostring(id)]
  end
  return nil
end

local function getKills(hot, id)
  local record = getRecord(hot, id)
  return record and record.kills or hot.kills[id]
end

local function getXp(hot, id)
  local record = getRecord(hot, id)
  return record and record.xp or hot.xp[id]
end

local function getZone(hot, id)
  local record = getRecord(hot, id)
  return record and record.zone or hot.zone[id]
end

local function getName(hot, shared, id)
  local record = getRecord(hot, id)
  if record then
    return record.name
  end
  if hot.names and hot.names[id] then
    return hot.names[id]
  end
  if hot.nameId then
    return shared.names[hot.nameId[id]]
  end
  return shared.names[id]
end

local function lookupByName(hot, shared, lower)
  if variant == "static_noidx" then
    return nil
  end
  local key = hot.byName and hot.byName[lower] or nil
  if key then
    return key
  end
  return shared and shared.byName and shared.byName[lower] or nil
end

collectgarbage("collect")
local heapBefore = collectgarbage("count")
local shared, sharedMs
if variant == "baseline" then
  shared, sharedMs = nil, 0
elseif variant == "interned" then
  shared, sharedMs = buildShared()
elseif variant == "records" or variant == "stringkeys" then
  shared, sharedMs = nil, 0
else
  -- static variants use shared names for 90%; the 10% name-only names are hot.
  shared = { names = {}, byName = {} }
  local start = clockMs()
  for id = 1, mobs do
    if id % 10 ~= 0 then
      local name = string.format("Mob %06d", id)
      shared.names[id] = name
      if variant ~= "static_noidx" then
        shared.byName[string.lower(name)] = id
      end
    end
  end
  collectgarbage("collect")
  sharedMs = clockMs() - start
end
local heapShared = collectgarbage("count")
local hotStart = clockMs()
local hot = buildHot(shared)
local hotBuildMs = clockMs() - hotStart
local heapHot = collectgarbage("count")

local lookupStart = clockMs()
for id = 1, 10000 do
  assert(getKills(hot, id) == 12)
  assert(getXp(hot, id) == 1140)
  assert(getZone(hot, id) > 0)
  assert(getName(hot, shared, id) ~= nil)
end
local lookupMs = clockMs() - lookupStart

local nameStart = clockMs()
local nameHits = 0
for id = 1, 10000 do
  local name = string.format("Mob %06d", id)
  if lookupByName(hot, shared, string.lower(name)) then
    nameHits = nameHits + 1
  end
end
local nameMs = clockMs() - nameStart
if variant ~= "static_noidx" then
  assert(nameHits == 10000, "name lookup misses")
end

print(string.format("variant=%s mobs=%d", variant, mobs))
print(string.format("hot_build_ms=%.1f shared_build_ms=%.1f",
  hotBuildMs, sharedMs))
print(string.format("hot_heap_mb=%.2f shared_heap_mb=%.2f total_heap_mb=%.2f",
  (heapHot - heapShared) / 1024, (heapShared - heapBefore) / 1024,
  (heapHot - heapBefore) / 1024))
print(string.format("tooltip_10k_ms=%.3f name_lookup_10k_ms=%.3f",
  lookupMs, nameMs))
print(string.format("name_hits=%d", nameHits))
