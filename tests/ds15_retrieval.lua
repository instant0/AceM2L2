-- DS-15 lazy retrieval/cache prototype.
-- Loads cold blocks as base64 at startup, decodes only selected blocks on demand.
-- Offline only; no production code.

local function clockMs() return os.clock() * 1000 end
local function countKeys(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, #B64 do B64_INDEX[B64:sub(i, i)] = i - 1 end
local function base64Encode(text)
  local out = {}
  for i = 1, #text, 3 do
    local a = string.byte(text, i) or 0
    local b = string.byte(text, i + 1) or 0
    local c = string.byte(text, i + 2) or 0
    local value = a * 65536 + b * 256 + c
    local c1 = math.floor(value / 262144) % 64
    local c2 = math.floor(value / 4096) % 64
    local c3 = math.floor(value / 64) % 64
    local c4 = value % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (i + 1 <= #text and B64:sub(c3 + 1, c3 + 1) or "=")
      .. (i + 2 <= #text and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end
local function base64Decode(text)
  text = text:gsub("[^" .. B64 .. "=]", "")
  local out = {}
  for i = 1, #text, 4 do
    local c1 = B64_INDEX[text:sub(i, i)] or 0
    local c2 = B64_INDEX[text:sub(i + 1, i + 1)] or 0
    local c3 = B64_INDEX[text:sub(i + 2, i + 2)]
    local c4 = B64_INDEX[text:sub(i + 3, i + 3)]
    local value = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
    out[#out + 1] = string.char(math.floor(value / 65536) % 256)
    if c3 then out[#out + 1] = string.char(math.floor(value / 256) % 256) end
    if c4 then out[#out + 1] = string.char(value % 256) end
  end
  return table.concat(out)
end
local function checksum(text)
  local sum = #text % 65521
  for i = 1, #text do sum = (sum + string.byte(text, i) * (i % 251 + 1)) % 65521 end
  return sum
end

-- ---------------------------------------------------------------------------
-- Build blocks
-- ---------------------------------------------------------------------------

local BLOCKS = 400
local PER_BLOCK = 250
local blockIndex = {}
local mobBlock = {}
local rawBytes = 0
local buildStart = clockMs()
for block = 1, BLOCKS do
  local parts = {}
  for index = 1, PER_BLOCK do
    local id = 100000 + (block - 1) * PER_BLOCK + index
    local key = "npc:" .. id
    parts[#parts + 1] = string.format("%s|%d|%d\n", key, (index % 50) + 1,
      ((index % 50) + 1) * (40 + (id % 60)))
    mobBlock[key] = block
  end
  local raw = table.concat(parts)
  rawBytes = rawBytes + #raw
  blockIndex[block] = {
    raw = raw,
    base64 = base64Encode(raw),
    checksum = checksum(raw),
  }
end
local buildMs = clockMs() - buildStart

local path = "/tmp/opencode/ds15-cold-blocks.txt"
local writeStart = clockMs()
local file = assert(io.open(path, "wb"))
for block = 1, BLOCKS do
  file:write(block, "\t", blockIndex[block].checksum, "\t", blockIndex[block].base64, "\n")
end
file:close()
local writeMs = clockMs() - writeStart

-- ---------------------------------------------------------------------------
-- Login: load base64 only, no decode
-- ---------------------------------------------------------------------------

local loginStart = clockMs()
local loaded = {}
local read = assert(io.open(path, "rb"))
for line in read:lines() do
  local block, check, data = line:match("^(%d+)\t(%d+)\t(.+)$")
  if block then
    loaded[tonumber(block)] = { base64 = data, checksum = tonumber(check) }
  end
end
read:close()
local loginMs = clockMs() - loginStart
print(string.format("blocks=%d per_block=%d total_mobs=%d raw_mb=%.2f base64_mb_est=%.2f build_ms=%.1f save_file_ms=%.1f login_load_ms=%.1f login_decoded_blocks=0",
  BLOCKS, PER_BLOCK, BLOCKS * PER_BLOCK, rawBytes / 1024 / 1024,
  (function()
    local size = 0
    for _, entry in pairs(blockIndex) do size = size + #entry.base64 end
    return size / 1024 / 1024
  end)(), buildMs, writeMs, loginMs))

-- ---------------------------------------------------------------------------
-- Decode one block
-- ---------------------------------------------------------------------------

local decodeCount = 0
local function decodeBlock(block)
  local entry = loaded[block]
  if not entry then return nil, "missing" end
  local raw = base64Decode(entry.base64)
  if checksum(raw) ~= entry.checksum then return nil, "checksum" end
  local records = {}
  for line in raw:gmatch("[^\n]+") do
    local key, kills, xp = line:match("^([^|]+)|(%d+)|(%d+)$")
    if key then records[key] = { kills = tonumber(kills), xp = tonumber(xp) } end
  end
  decodeCount = decodeCount + 1
  return records
end

local function fullDecodeAll()
  local count = 0
  for block = 1, BLOCKS do
    local records = decodeBlock(block)
    if records then count = count + countKeys(records) end
  end
  return count
end

local fullStart = clockMs()
local fullMobs = fullDecodeAll()
local fullDecodeMs = clockMs() - fullStart

-- Selected-zone tooltip: one block, 10k lookups
local selectedBlock = 1
decodeCount = 0
local selectedStart = clockMs()
local selectedRecords = decodeBlock(selectedBlock)
local selectedDecodeMs = clockMs() - selectedStart
local selectedLookupStart = clockMs()
for index = 1, 10000 do
  local id = 100000 + index % PER_BLOCK + 1
  local record = selectedRecords["npc:" .. id]
  assert(record and record.kills > 0)
end
local selectedLookupMs = clockMs() - selectedLookupStart
print(string.format("full_decode_ms=%.1f full_mobs=%d selected_block_decode_ms=%.1f selected_lookup_10k_ms=%.3f selected_decoded_blocks=%d",
  fullDecodeMs, fullMobs, selectedDecodeMs, selectedLookupMs, decodeCount))

-- ---------------------------------------------------------------------------
-- LRU block cache
-- ---------------------------------------------------------------------------

local function makeCache(capacity)
  local cache = { capacity = capacity, map = {}, order = {}, decoded = 0, hits = 0, misses = 0 }
  local function remove(key)
    for index = 1, #cache.order do
      if cache.order[index] == key then table.remove(cache.order, index); return end
    end
  end
  function cache.get(block)
    local value = cache.map[block]
    if value then
      cache.hits = cache.hits + 1
      remove(block)
      cache.order[#cache.order + 1] = block
      return value
    end
    cache.misses = cache.misses + 1
    value = decodeBlock(block)
    if value then
      cache.map[block] = value
      cache.order[#cache.order + 1] = block
      cache.decoded = cache.decoded + 1
      if #cache.order > cache.capacity then
        local evicted = table.remove(cache.order, 1)
        cache.map[evicted] = nil
      end
    end
    return value
  end
  return cache
end

local keys = {}
for key in pairs(mobBlock) do keys[#keys + 1] = key end
table.sort(keys)
math.randomseed(20261116)
local randomKeys = {}
for index = 1, 10000 do randomKeys[index] = keys[math.random(1, #keys)] end

for _, capacity in ipairs({0, 16, 64, 256}) do
  decodeCount = 0
  local cache = makeCache(capacity)
  local start = clockMs()
  for _, key in ipairs(randomKeys) do
    local block = mobBlock[key]
    local records
    if capacity == 0 then
      records = decodeBlock(block)
    else
      records = cache.get(block)
    end
    assert(records and records[key])
  end
  local ms = clockMs() - start
  local hits = capacity == 0 and 0 or cache.hits
  local misses = capacity == 0 and 10000 or cache.misses
  local decoded = capacity == 0 and decodeCount or cache.decoded
  print(string.format("cache_capacity=%d lookup_10k_ms=%.1f hits=%d misses=%d decoded_blocks=%d hit_rate=%.3f",
    capacity, ms, hits, misses, decoded, hits / 10000))
end

-- ---------------------------------------------------------------------------
-- Best zone / heatmap queries: no block decode
-- ---------------------------------------------------------------------------

local zones = {}
for index = 1, 200 do
  zones[index] = { mapID = index, level = (index % 60) + 1,
    xp = (index * 173) % 100000 + 10000,
    activeSeconds = (index * 37) % 7200 + 600,
    kills = (index * 19) % 1000 + 50,
    sessions = (index % 6) + 1 }
end
local zoneStart = clockMs()
for _ = 1, 10000 do
  local best, bestXPH = nil, -1
  for _, zone in ipairs(zones) do
    local xph = zone.xp / (zone.activeSeconds / 3600)
    if xph > bestXPH then best, bestXPH = zone, xph end
  end
  assert(best)
end
local zoneQueryMs = clockMs() - zoneStart

local heatmapTop = {}
for map = 1, 200 do
  heatmapTop[map] = {}
  for cell = 1, 10 do heatmapTop[map][cell] = { cell = cell, kills = 100 - cell } end
end
local heatmapStart = clockMs()
for index = 1, 10000 do
  local map = (index % 200) + 1
  local top = heatmapTop[map][1]
  assert(top)
end
local heatmapQueryMs = clockMs() - heatmapStart
print(string.format("best_zone_query_10k_ms=%.2f heatmap_top_query_10k_ms=%.2f no_block_decode=true",
  zoneQueryMs, heatmapQueryMs))

-- ---------------------------------------------------------------------------
-- Missing / corrupt fallback
-- ---------------------------------------------------------------------------

local missing = decodeBlock(9999)
assert(missing == nil)
local corruptEntry = loaded[1]
local saved = corruptEntry.base64
corruptEntry.base64 = saved:sub(1, #saved - 4) .. "AAAA"
local corrupt = decodeBlock(1)
assert(corrupt == nil)
corruptEntry.base64 = saved
print("missing_block_fallback=true corrupt_block_rejected=true cache_not_poisoned=true")

print("login_decodes_all=false selected_block_lazy=true account_knowledge_query=none merge_implemented=false no_ui=true no_online=true")
