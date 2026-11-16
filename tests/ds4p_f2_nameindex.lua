-- DS-4P-F2 scoped/lazy name-index prototype.
-- Usage: lua tests/ds4p_f2_nameindex.lua <mobs>

local mobs = tonumber(arg[1] or "10000") or 10000

local function clockMs()
  return os.clock() * 1000
end

local function addName(index, lower, id)
  local existing = index[lower]
  if existing == nil then
    index[lower] = id
  elseif existing ~= id then
    index[lower] = false
  end
end

collectgarbage("collect")
local heapBefore = collectgarbage("count")

local shared = { names = {} }
local sharedStart = clockMs()
for id = 1, mobs do
  local isNameOnly = (id % 10 == 0)
  local missingStatic = (id % 100 == 1)
  if not isNameOnly and not missingStatic then
    shared.names[id] = string.format("Mob %06d", id)
  end
end
collectgarbage("collect")
local heapShared = collectgarbage("count")
local sharedMs = clockMs() - sharedStart

local hot = {
  names = {},
  nameIndex = {},
  kills = {},
  xp = {},
  zone = {},
}
local hotStart = clockMs()
for id = 1, mobs do
  hot.kills[id] = 12
  hot.xp[id] = 12 * 95
  hot.zone[id] = (id % 200) + 1
  local isNameOnly = (id % 10 == 0)
  local missingStatic = (id % 100 == 1)
  if isNameOnly or missingStatic then
    local name = string.format("Mob %06d", id)
    hot.names[id] = name
    addName(hot.nameIndex, string.lower(name), id)
  end
end
-- Two different unresolved mobs sharing a name must not resolve to one.
hot.nameIndex["ambiguous"] = false
collectgarbage("collect")
local heapHot = collectgarbage("count")
local hotMs = clockMs() - hotStart

local function getName(id)
  return hot.names[id] or shared.names[id]
end

local function lookupName(lower)
  local value = hot.nameIndex[lower]
  if type(value) == "number" then
    return value
  end
  return nil
end

local lookupStart = clockMs()
for id = 1, 10000 do
  local name = getName(id)
  assert(name ~= nil)
  assert(hot.kills[id] == 12)
  assert(hot.xp[id] == 1140)
  assert(hot.zone[id] > 0)
end
local lookupMs = clockMs() - lookupStart

local nameStart = clockMs()
local nameHits = 0
for id = 1, 10000 do
  local lower = string.lower(string.format("Mob %06d", id))
  if lookupName(lower) then
    nameHits = nameHits + 1
  end
end
local nameMs = clockMs() - nameStart
assert(lookupName("ambiguous") == nil, "ambiguous name resolved")
-- A statically named NPC is intentionally not in the scoped name index.
assert(lookupName(string.lower(string.format("Mob %06d", 2))) == nil,
  "static name unexpectedly indexed")
assert(lookupName(string.lower(string.format("Mob %06d", 10))) == 10,
  "name-only index miss")
assert(lookupName(string.lower(string.format("Mob %06d", 1))) == 1,
  "missing-static name index miss")

local indexCount = 0
for _ in pairs(hot.nameIndex) do
  indexCount = indexCount + 1
end

print(string.format("mobs=%d", mobs))
print(string.format("hot_build_ms=%.1f shared_build_ms=%.1f", hotMs, sharedMs))
print(string.format("hot_heap_mb=%.2f shared_heap_mb=%.2f total_heap_mb=%.2f",
  (heapHot - heapShared) / 1024, (heapShared - heapBefore) / 1024,
  (heapHot - heapBefore) / 1024))
print(string.format("tooltip_10k_ms=%.3f name_lookup_10k_ms=%.3f",
  lookupMs, nameMs))
print(string.format("name_index_entries=%d name_hits=%d", indexCount, nameHits))
print("static_name_lookup=miss")
print("ambiguous_lookup=nil")
