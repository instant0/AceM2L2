-- DS-4P offline hybrid prototype.
-- Usage: lua tests/ds4p_hybrid.lua A|B|C
-- This is a structural prototype, not a client benchmark.

local tier = (arg[1] or "A"):upper()
local PROFILES = {
  A = { mobs = 2000,   zones = 40,  instances = 100, cells = 4096, contexts = 12 },
  B = { mobs = 10000,  zones = 100, instances = 200, cells = 1000, contexts = 12 },
  C = { mobs = 100000, zones = 200, instances = 200, cells = 1000, contexts = 12 },
}
local profile = assert(PROFILES[tier], "tier must be A, B, or C")

local function clockMs()
  return os.clock() * 1000
end

local function varint(value)
  local n = math.floor(tonumber(value) or 0)
  if n < 0 then n = 0 end
  local out = {}
  repeat
    local byte = n % 128
    n = math.floor(n / 128)
    if n > 0 then
      out[#out + 1] = string.char(byte + 128)
    else
      out[#out + 1] = string.char(byte)
    end
  until n == 0
  return table.concat(out)
end

local function readVarint(text, position)
  local value, shift = 0, 0
  while true do
    local byte = string.byte(text, position)
    if not byte then
      error("truncated varint")
    end
    position = position + 1
    value = value + (byte % 128) * (2 ^ shift)
    if byte < 128 then
      return value, position
    end
    shift = shift + 7
  end
end

local function checksum(text)
  -- Lightweight prototype checksum; not a cryptographic hash.
  local length = #text
  local sum = length % 65521
  for index = 1, math.min(length, 4096) do
    sum = (sum + string.byte(text, index) * index) % 65521
  end
  return sum
end

local function build()
  local started = clockMs()
  collectgarbage("collect")
  local heapBefore = collectgarbage("count")
  local hot = {
    names = {},
    kills = {},
    xp = {},
    zone = {},
    byName = {},
    zoneMeta = {},
    instanceMeta = {},
  }
  local zoneMobs = {}
  for zone = 1, profile.zones do
    zoneMobs[zone] = {}
  end

  for id = 1, profile.mobs do
    local zone = (id % profile.zones) + 1
    local name = string.format("Mob %06d", id)
    hot.names[id] = name
    hot.kills[id] = 12
    hot.xp[id] = 12 * 95
    hot.zone[id] = zone
    hot.byName[string.lower(name)] = id
    zoneMobs[zone][#zoneMobs[zone] + 1] = id
  end

  local coldParts = {}
  local coldBytes = 0
  for zone = 1, profile.zones do
    local ids = zoneMobs[zone]
    local parts = { varint(zone), varint(#ids), varint(profile.cells) }
    for cell = 1, profile.cells do
      parts[#parts + 1] = varint(cell)
      parts[#parts + 1] = varint(1)
    end
    for _, id in ipairs(ids) do
      local level = 1 + (id % 60)
      parts[#parts + 1] = varint(id)
      parts[#parts + 1] = varint(hot.kills[id])
      parts[#parts + 1] = varint(hot.xp[id])
      parts[#parts + 1] = varint(profile.contexts)
      for context = 1, profile.contexts do
        parts[#parts + 1] = varint(level)
        parts[#parts + 1] = varint(level)
        parts[#parts + 1] = varint(1)
        parts[#parts + 1] = varint(1)
        parts[#parts + 1] = varint(95)
        parts[#parts + 1] = varint(95)
      end
    end
    local block = table.concat(parts)
    hot.zoneMeta[zone] = {
      offset = coldBytes + 1,
      length = #block,
      checksum = checksum(block),
      mobs = #ids,
      cells = profile.cells,
    }
    coldParts[#coldParts + 1] = block
    coldBytes = coldBytes + #block
  end
  local cold = table.concat(coldParts)
  assert(#cold == coldBytes, "cold byte accounting mismatch")

  for instance = 1, profile.instances do
    hot.instanceMeta[instance] = {
      id = instance,
      kills = 120,
      length = 0,
      checksum = instance % 65521,
    }
  end

  collectgarbage("collect")
  local heapAfter = collectgarbage("count")
  local built = clockMs()
  return hot, cold, heapBefore, heapAfter, built - started
end

local function decodeZone(hot, cold, zone)
  local meta = assert(hot.zoneMeta[zone], "unknown zone")
  local text = cold:sub(meta.offset, meta.offset + meta.length - 1)
  assert(checksum(text) == meta.checksum, "cold checksum mismatch")
  local position = 1
  local zoneID, mobCount, cellCount
  zoneID, position = readVarint(text, position)
  mobCount, position = readVarint(text, position)
  cellCount, position = readVarint(text, position)
  for _ = 1, cellCount do
    local _, nextPosition = readVarint(text, position)
    position = nextPosition
    local _, nextPosition2 = readVarint(text, position)
    position = nextPosition2
  end
  local mobs = {}
  for index = 1, mobCount do
    local id, kills, xp, contexts
    id, position = readVarint(text, position)
    kills, position = readVarint(text, position)
    xp, position = readVarint(text, position)
    contexts, position = readVarint(text, position)
    for _ = 1, contexts do
      for _ = 1, 6 do
        local _, nextPosition = readVarint(text, position)
        position = nextPosition
      end
    end
    mobs[index] = { id = id, kills = kills, xp = xp }
  end
  return zoneID, mobs, cellCount
end

local function saveHybrid(hot, cold, path)
  local file = assert(io.open(path, "wb"))
  file:write("DS4P\t1\n")
  for id = 1, profile.mobs do
    file:write(string.format("%d\t%d\t%d\t%d\t%s\n",
      id, hot.kills[id], hot.xp[id], hot.zone[id], hot.names[id]))
  end
  for zone = 1, profile.zones do
    local meta = hot.zoneMeta[zone]
    file:write(string.format("Z\t%d\t%d\t%d\t%d\t%d\t%d\n",
      zone, meta.offset, meta.length, meta.checksum, meta.mobs, meta.cells))
  end
  for instance = 1, profile.instances do
    local meta = hot.instanceMeta[instance]
    file:write(string.format("I\t%d\t%d\t%d\n",
      instance, meta.kills, meta.checksum))
  end
  file:write(string.format("COLD\t%d\n", #cold))
  file:write(cold)
  file:close()
end

local function loadHybrid(path)
  local file = assert(io.open(path, "rb"))
  assert(file:read("*l") == "DS4P\t1", "bad prototype header")
  local hot = {
    names = {}, kills = {}, xp = {}, zone = {}, byName = {},
    zoneMeta = {}, instanceMeta = {},
  }
  for _ = 1, profile.mobs do
    local line = assert(file:read("*l"), "truncated mob line")
    local id, kills, xp, zone, name = line:match("^(%d+)\t(%d+)\t(%d+)\t(%d+)\t(.+)$")
    assert(id, "bad mob line")
    id, kills, xp, zone = tonumber(id), tonumber(kills), tonumber(xp), tonumber(zone)
    hot.names[id] = name
    hot.kills[id] = kills
    hot.xp[id] = xp
    hot.zone[id] = zone
    hot.byName[string.lower(name)] = id
  end
  for _ = 1, profile.zones do
    local line = assert(file:read("*l"), "truncated zone line")
    local zone, offset, length, sum, mobs, cells = line:match("^Z\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)$")
    assert(zone, "bad zone line")
    hot.zoneMeta[tonumber(zone)] = {
      offset = tonumber(offset), length = tonumber(length),
      checksum = tonumber(sum), mobs = tonumber(mobs), cells = tonumber(cells),
    }
  end
  for _ = 1, profile.instances do
    local line = assert(file:read("*l"), "truncated instance line")
    local id, kills, sum = line:match("^I\t(%d+)\t(%d+)\t(%d+)$")
    assert(id, "bad instance line")
    hot.instanceMeta[tonumber(id)] = {
      id = tonumber(id), kills = tonumber(kills), checksum = tonumber(sum),
    }
  end
  local coldLine = assert(file:read("*l"), "missing cold header")
  local length = assert(tonumber(coldLine:match("^COLD\t(%d+)$")), "bad cold header")
  local cold = assert(file:read(length), "truncated cold data")
  file:close()
  assert(#cold == length, "cold length mismatch")
  return hot, cold
end

local hot, cold, heapBefore, heapAfter, buildMs = build()
local savePath = "/tmp/opencode/ds4p-" .. tier .. ".dat"
local saveStart = clockMs()
saveHybrid(hot, cold, savePath)
local saveMs = clockMs() - saveStart
local loadStart = clockMs()
local loadedHot, loadedCold = loadHybrid(savePath)
local loadMs = clockMs() - loadStart
assert(#loadedCold == #cold, "loaded cold size mismatch")
assert(loadedHot.kills[1] == hot.kills[1], "loaded hot mismatch")
local loadedZoneID, loadedZoneMobs, loadedCells = decodeZone(loadedHot, loadedCold, 1)
assert(loadedZoneID == 1 and #loadedZoneMobs > 0 and loadedCells == profile.cells,
  "loaded selected-zone decode mismatch")
local coldMB = #cold / 1024 / 1024
local hotMB = (heapAfter - heapBefore) / 1024

local decodeStart = clockMs()
local zoneID, zoneMobs, cells = decodeZone(hot, cold, 1)
local decodeMs = clockMs() - decodeStart
assert(zoneID == 1 and #zoneMobs > 0 and cells == profile.cells,
  "selected-zone decode mismatch")

local tooltipStart = clockMs()
local testID = 1
for _ = 1, 10000 do
  assert(hot.kills[testID] == 12)
  assert(hot.names[testID] == "Mob 000001")
end
local tooltipMs = clockMs() - tooltipStart

local zoneListStart = clockMs()
local zoneCount = 0
for _ in pairs(hot.zoneMeta) do
  zoneCount = zoneCount + 1
end
local zoneListMs = clockMs() - zoneListStart
assert(zoneCount == profile.zones, "zone index mismatch")

print(string.format("tier=%s mobs=%d zones=%d instances=%d cells=%d contexts=%d",
  tier, profile.mobs, profile.zones, profile.instances, profile.cells, profile.contexts))
print(string.format("hot_heap_mb=%.2f cold_rows_mb=%.2f total_structural_mb=%.2f",
  hotMB, coldMB, hotMB + coldMB))
print(string.format("build_ms=%.1f selected_zone_decode_ms=%.1f",
  buildMs, decodeMs))
print(string.format("save_ms=%.1f reload_ms=%.1f prototype_file_mb=%.2f",
  saveMs, loadMs, (function()
    local f=io.open(savePath,"rb"); local n=#f:read("*a"); f:close(); return n/1024/1024
  end)())) 
print(string.format("tooltip_10k_ms=%.3f zone_list_ms=%.3f",
  tooltipMs, zoneListMs))
print(string.format("selected_zone_mobs=%d selected_zone_cells=%d",
  #zoneMobs, cells))
print("checksum=ok")
print("prototype=retrieval_ok")
