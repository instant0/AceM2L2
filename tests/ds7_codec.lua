-- DS-7 + DS-12 packed cold-block codec prototype.
-- Usage:
--   lua tests/ds7_codec.lua <variant> <mobs> <zones> <instances> <grid> <contexts> <density> [namecache]
--
-- Variants:
--   plain            Lua tables per block (baseline; no serialization)
--   varint_dense     varint fields; every grid cell written
--   varint_sparse    varint fields; sparse delta cells
--   bitcells_sparse  varint fields; bitset cells + counts for set cells
--   hybrid_cells     per-block choice: sparse vs bitset
--
-- No names are stored in cold blocks. Names come from the live account-wide
-- name cache; a missing name falls back to "NPC <id>".

local variant = arg[1] or "hybrid_cells"
local mobs = tonumber(arg[2] or "10000") or 10000
local zones = tonumber(arg[3] or "40") or 40
local instances = tonumber(arg[4] or "100") or 100
local grid = tonumber(arg[5] or "64") or 64
local contexts = tonumber(arg[6] or "12") or 12
local density = tonumber(arg[7] or "0.15") or 0.15
local nameCacheSize = tonumber(arg[8] or "10000") or 10000

local VALID = {
  plain = true,
  varint_dense = true,
  varint_sparse = true,
  bitcells_sparse = true,
  hybrid_cells = true,
}
assert(VALID[variant], "unknown variant: " .. tostring(variant))
assert(mobs > 0 and zones > 0 and instances > 0, "bad profile")
assert(grid == 16 or grid == 32 or grid == 64, "grid must be 16/32/64")
assert(contexts > 0, "contexts must be positive")
assert(density > 0 and density < 0.8, "density must be 0..0.8")
assert(nameCacheSize >= 0, "name cache size must be >= 0")

local function clockMs()
  return os.clock() * 1000
end

local function varint(value)
  value = math.floor(tonumber(value) or 0)
  if value < 0 then
    value = 0
  end
  local parts = {}
  repeat
    local byte = value % 128
    value = math.floor(value / 128)
    if value > 0 then
      byte = byte + 128
    end
    parts[#parts + 1] = string.char(byte)
  until value == 0
  return table.concat(parts)
end

local function readVarint(text, position)
  local value, shift = 0, 1
  while true do
    local byte = string.byte(text, position)
    if not byte then
      error("truncated varint")
    end
    position = position + 1
    value = value + (byte % 128) * shift
    if byte < 128 then
      return value, position
    end
    shift = shift * 128
    if shift > 2 ^ 52 then
      error("varint too large")
    end
  end
end

local function checksum(text)
  local sum = #text % 65521
  for index = 1, #text do
    sum = (sum + string.byte(text, index) * (index % 251 + 1)) % 65521
  end
  return sum
end

local B64_ALPHABET =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for index = 1, #B64_ALPHABET do
  B64_INDEX[B64_ALPHABET:sub(index, index)] = index - 1
end

local function base64Encode(text)
  local out = {}
  for index = 1, #text, 3 do
    local a = string.byte(text, index) or 0
    local b = string.byte(text, index + 1) or 0
    local c = string.byte(text, index + 2) or 0
    local value = a * 65536 + b * 256 + c
    local c1 = math.floor(value / 262144) % 64
    local c2 = math.floor(value / 4096) % 64
    local c3 = math.floor(value / 64) % 64
    local c4 = value % 64
    out[#out + 1] = B64_ALPHABET:sub(c1 + 1, c1 + 1)
      .. B64_ALPHABET:sub(c2 + 1, c2 + 1)
      .. (index + 1 <= #text and B64_ALPHABET:sub(c3 + 1, c3 + 1) or "=")
      .. (index + 2 <= #text and B64_ALPHABET:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end

local function base64Decode(text)
  text = text:gsub("[^" .. B64_ALPHABET .. "=]", "")
  local out = {}
  for index = 1, #text, 4 do
    local c1 = B64_INDEX[text:sub(index, index)] or 0
    local c2 = B64_INDEX[text:sub(index + 1, index + 1)] or 0
    local c3 = B64_INDEX[text:sub(index + 2, index + 2)]
    local c4 = B64_INDEX[text:sub(index + 3, index + 3)]
    local value = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
    out[#out + 1] = string.char(math.floor(value / 65536) % 256)
    if c3 then
      out[#out + 1] = string.char(math.floor(value / 256) % 256)
    end
    if c4 then
      out[#out + 1] = string.char(value % 256)
    end
  end
  return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- Model
-- ---------------------------------------------------------------------------

local function addBlock(model, kind, id, count)
  local cells = {}
  local cellTotal = grid * grid
  local cellCount = math.floor(cellTotal * density)
  local step = math.max(1, math.floor(cellTotal / math.max(1, cellCount)))
  for index = 1, cellCount do
    local cell = ((index - 1) * step) % cellTotal + 1
    cells[cell] = (index % 20) + 1
  end

  local block = {
    kind = kind,
    id = id,
    grid = grid,
    cells = cells,
    cellCount = cellCount,
    mobs = {},
    top = {},
  }

  for mobIndex = 1, count do
    model.nextIndex = model.nextIndex + 1
    local index = model.nextIndex
    local npcID = 100000 + index * 7 + (index % 3)
    local kills = (index % 50) + 1
    local xp = kills * ((index % 20) + 10)
    local level = (index % 60) + 1
    local mob = {
      id = npcID,
      kills = kills,
      xp = xp,
      level = level,
      killsAtLevel = kills,
      xpAtLevel = xp,
      contexts = {},
    }
    for context = 1, contexts do
      mob.contexts[context] = {
        playerLevel = 1 + ((index + context) % 60),
        mobLevel = 1 + ((index + context * 3) % 60),
        groupSize = 1 + (context % 5),
        class = 1 + (context % 5),
        samples = 1 + (context % 3),
        sumXP = xp + context * 7,
      }
    end
    block.mobs[#block.mobs + 1] = mob
  end

  for index = 1, math.min(10, #block.mobs) do
    block.top[index] = {
      index = index,
      kills = block.mobs[index].kills,
    }
  end

  model.blocks[#model.blocks + 1] = block
end

local function buildModel()
  local model = { blocks = {}, nextIndex = 0 }
  local openMobs = math.floor(mobs * 0.8)
  local instanceMobs = mobs - openMobs

  for zone = 1, zones do
    local count = math.floor(openMobs / zones)
    if zone <= openMobs % zones then
      count = count + 1
    end
    addBlock(model, 1, zone, count)
  end

  for instance = 1, instances do
    local count = math.floor(instanceMobs / instances)
    if instance <= instanceMobs % instances then
      count = count + 1
    end
    addBlock(model, 2, instance, count)
  end

  assert(#model.blocks == zones + instances, "block count mismatch")
  return model
end

-- ---------------------------------------------------------------------------
-- Cell encodings
-- ---------------------------------------------------------------------------

local function sparseCellBytes(block)
  local previous = 0
  local bytes = 0
  for cell = 1, block.grid * block.grid do
    local count = block.cells[cell]
    if count then
      bytes = bytes + #varint(cell - previous) + #varint(count)
      previous = cell
    end
  end
  return bytes
end

local function bitCellBytes(block)
  local bits = math.ceil(block.grid * block.grid / 8)
  return bits + block.cellCount
end

local function chooseCellMode(block)
  if variant == "varint_dense" then
    return 0
  elseif variant == "varint_sparse" then
    return 1
  elseif variant == "bitcells_sparse" then
    return 2
  end
  -- hybrid: choose the smaller estimate; sparse wins at very low density.
  if bitCellBytes(block) < sparseCellBytes(block) then
    return 2
  end
  return 1
end

local function appendCells(parts, block, mode)
  local cellTotal = block.grid * block.grid
  if mode == 0 then
    for cell = 1, cellTotal do
      parts[#parts + 1] = varint(block.cells[cell] or 0)
    end
  elseif mode == 1 then
    local previous = 0
    for cell = 1, cellTotal do
      local count = block.cells[cell]
      if count then
        parts[#parts + 1] = varint(cell - previous)
        parts[#parts + 1] = varint(count)
        previous = cell
      end
    end
  else
    local bytes = {}
    local byteCount = math.ceil(cellTotal / 8)
    for byteIndex = 1, byteCount do
      local value = 0
      for bit = 0, 7 do
        local cell = (byteIndex - 1) * 8 + bit + 1
        if cell <= cellTotal and block.cells[cell] then
          value = value + 2 ^ bit
        end
      end
      bytes[byteIndex] = string.char(value)
    end
    parts[#parts + 1] = table.concat(bytes)
    for cell = 1, cellTotal do
      local count = block.cells[cell]
      if count then
        parts[#parts + 1] = varint(count)
      end
    end
  end
end

local function decodeCells(text, position, header)
  local cells = {}
  local cellTotal = header.grid * header.grid
  if header.cellMode == 0 then
    for cell = 1, cellTotal do
      local count
      count, position = readVarint(text, position)
      if count > 0 then
        cells[cell] = count
      end
    end
  elseif header.cellMode == 1 then
    local previous = 0
    for _ = 1, header.cellCount do
      local delta
      delta, position = readVarint(text, position)
      local cell = previous + delta
      previous = cell
      local count
      count, position = readVarint(text, position)
      cells[cell] = count
    end
  else
    local byteCount = math.ceil(cellTotal / 8)
    local start = position
    position = position + byteCount
    for byteIndex = 0, byteCount - 1 do
      local value = string.byte(text, start + byteIndex)
      if not value then
        error("truncated bitset")
      end
      for bit = 0, 7 do
        if math.floor(value / 2 ^ bit) % 2 == 1 then
          local cell = byteIndex * 8 + bit + 1
          if cell <= cellTotal then
            local count
            count, position = readVarint(text, position)
            cells[cell] = count
          end
        end
      end
    end
  end
  return cells, position
end

-- ---------------------------------------------------------------------------
-- Block encode/decode
-- ---------------------------------------------------------------------------

local function encodeBlock(block)
  local cellMode = chooseCellMode(block)
  local parts = {
    varint(1),             -- schema
    varint(block.kind),    -- 1=zone, 2=instance
    varint(block.id),
    varint(block.grid),
    varint(#block.mobs),
    varint(cellMode),
    varint(block.cellCount),
    varint(#block.top),
    varint(contexts),
  }
  appendCells(parts, block, cellMode)

  local previousID = 0
  for _, mob in ipairs(block.mobs) do
    parts[#parts + 1] = varint(mob.id - previousID)
    previousID = mob.id
    parts[#parts + 1] = varint(mob.kills)
    parts[#parts + 1] = varint(mob.xp)
    parts[#parts + 1] = varint(1) -- level count
    parts[#parts + 1] = varint(mob.level)
    parts[#parts + 1] = varint(mob.killsAtLevel)
    parts[#parts + 1] = varint(mob.xpAtLevel)
    for context = 1, contexts do
      local entry = mob.contexts[context]
      parts[#parts + 1] = varint(entry.playerLevel)
      parts[#parts + 1] = varint(entry.mobLevel)
      parts[#parts + 1] = varint(entry.groupSize)
      parts[#parts + 1] = varint(entry.class)
      parts[#parts + 1] = varint(entry.samples)
      parts[#parts + 1] = varint(entry.sumXP)
    end
  end

  for _, top in ipairs(block.top) do
    parts[#parts + 1] = varint(top.index)
    parts[#parts + 1] = varint(top.kills)
  end

  return table.concat(parts)
end

local function decodeBlock(text)
  local position = 1
  local header = {}
  header.schema, position = readVarint(text, position)
  header.kind, position = readVarint(text, position)
  header.id, position = readVarint(text, position)
  header.grid, position = readVarint(text, position)
  header.mobCount, position = readVarint(text, position)
  header.cellMode, position = readVarint(text, position)
  header.cellCount, position = readVarint(text, position)
  header.topCount, position = readVarint(text, position)
  header.contextCount, position = readVarint(text, position)
  if header.schema ~= 1 then
    error("bad schema")
  end

  local cells
  cells, position = decodeCells(text, position, header)

  local mobs = {}
  local previousID = 0
  for index = 1, header.mobCount do
    local delta, kills, xp, levelCount
    delta, position = readVarint(text, position)
    kills, position = readVarint(text, position)
    xp, position = readVarint(text, position)
    levelCount, position = readVarint(text, position)
    local levels = {}
    for levelIndex = 1, levelCount do
      local level, killsAtLevel, xpAtLevel
      level, position = readVarint(text, position)
      killsAtLevel, position = readVarint(text, position)
      xpAtLevel, position = readVarint(text, position)
      levels[levelIndex] = {
        level = level, kills = killsAtLevel, xp = xpAtLevel,
      }
    end
    local contextEntries = {}
    for context = 1, header.contextCount do
      local playerLevel, mobLevel, groupSize, class, samples, sumXP
      playerLevel, position = readVarint(text, position)
      mobLevel, position = readVarint(text, position)
      groupSize, position = readVarint(text, position)
      class, position = readVarint(text, position)
      samples, position = readVarint(text, position)
      sumXP, position = readVarint(text, position)
      contextEntries[context] = {
        playerLevel = playerLevel,
        mobLevel = mobLevel,
        groupSize = groupSize,
        class = class,
        samples = samples,
        sumXP = sumXP,
      }
    end
    previousID = previousID + delta
    mobs[index] = {
      id = previousID,
      kills = kills,
      xp = xp,
      levels = levels,
      contexts = contextEntries,
    }
  end

  local top = {}
  for index = 1, header.topCount do
    local mobIndex, kills
    mobIndex, position = readVarint(text, position)
    kills, position = readVarint(text, position)
    top[index] = { index = mobIndex, kills = kills }
  end

  return {
    header = header,
    cells = cells,
    mobs = mobs,
    top = top,
  }
end

-- ---------------------------------------------------------------------------
-- Plain baseline
-- ---------------------------------------------------------------------------

local function measurePlain(model)
  local start = clockMs()
  local kills = 0
  local blockIndex = 1
  local mobIndex = 1
  for _ = 1, math.min(10000, mobs) do
    local block = model.blocks[blockIndex]
    local mob = block.mobs[mobIndex]
    kills = kills + mob.kills
    mobIndex = mobIndex + 1
    if mobIndex > #block.mobs then
      mobIndex = 1
      blockIndex = blockIndex % #model.blocks + 1
    end
  end
  local lookupMs = clockMs() - start
  return kills, lookupMs
end

local function encodeModel(sourceModel)
  local coldParts = {}
  local blockMetas = {}
  local bytes = 0
  for _, block in ipairs(sourceModel.blocks) do
    local body = encodeBlock(block)
    local sum = checksum(body)
    blockMetas[#blockMetas + 1] = {
      offset = bytes + 1,
      length = #body,
      checksum = sum,
      kind = block.kind,
      id = block.id,
    }
    coldParts[#coldParts + 1] = body
    bytes = bytes + #body
  end
  local packed = table.concat(coldParts)
  assert(#packed == bytes, "cold length mismatch")
  return packed, blockMetas, bytes
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

collectgarbage("collect")
local heapBefore = collectgarbage("count")
local buildStart = clockMs()
local model = buildModel()
local buildMs = clockMs() - buildStart

local cold
local metas = {}
local encodeMs = 0
local checksumMs = 0
local selectedDecodeMs = 0
local coldBytes = 0
local escapedBytes = 0
local base64Bytes = 0
local base64EncodeMs = 0
local base64DecodeMs = 0
local base64Ok = true
local base64Tested = false
local blockBase64Bytes = 0
local blockBase64DecodeMs = 0
local blockBase64Ok = false
local heapAfter
local plainLookupMs = 0
local plainKills = 0

if variant == "plain" then
  collectgarbage("collect")
  heapAfter = collectgarbage("count")
  plainKills, plainLookupMs = measurePlain(model)
else
  local encodeStart = clockMs()
  cold, metas, coldBytes = encodeModel(model)
  encodeMs = clockMs() - encodeStart
  escapedBytes = #string.format("%q", cold)

  if #cold <= 6 * 1024 * 1024 then
    local encodedStart = clockMs()
    local encoded = base64Encode(cold)
    base64EncodeMs = clockMs() - encodedStart
    base64Bytes = #encoded
    local decodedStart = clockMs()
    local decoded = base64Decode(encoded)
    base64DecodeMs = clockMs() - decodedStart
    base64Ok = (decoded == cold)
    base64Tested = true
    encoded = nil
    decoded = nil
  else
    base64Bytes = math.ceil(#cold / 3) * 4
    base64Ok = false
  end

  local firstMeta = metas[1]
  local firstBody = cold:sub(firstMeta.offset,
    firstMeta.offset + firstMeta.length - 1)
  local firstEncoded = base64Encode(firstBody)
  blockBase64Bytes = #firstEncoded
  local blockDecodeStart = clockMs()
  local firstDecoded = base64Decode(firstEncoded)
  blockBase64DecodeMs = clockMs() - blockDecodeStart
  blockBase64Ok = (firstDecoded == firstBody)
  firstBody = nil
  firstEncoded = nil
  firstDecoded = nil

  local checksumStart = clockMs()
  local total = 0
  for _, meta in ipairs(metas) do
    local body = cold:sub(meta.offset, meta.offset + meta.length - 1)
    total = total + checksum(body)
  end
  checksumMs = clockMs() - checksumStart
  assert(total > 0, "checksum failed")

  -- Selected-block decode: decode 100 blocks round-robin.
  local decodeStart = clockMs()
  local decodeCount = math.min(100, #metas)
  local decodedMobs = 0
  local decodedCells = 0
  for index = 1, decodeCount do
    local meta = metas[(index - 1) % #metas + 1]
    local body = cold:sub(meta.offset, meta.offset + meta.length - 1)
    assert(checksum(body) == meta.checksum, "block checksum mismatch")
    local decoded = decodeBlock(body)
    decodedMobs = decodedMobs + #decoded.mobs
    decodedCells = decodedCells + #decoded.cells
  end
  selectedDecodeMs = (clockMs() - decodeStart) / decodeCount
  assert(decodedMobs > 0 and decodedCells > 0, "decode produced no data")

  -- Corruption/truncation checks on one block.
  local meta = metas[1]
  local body = cold:sub(meta.offset, meta.offset + meta.length - 1)
  local middle = math.max(1, math.floor(#body / 2))
  local byte = string.byte(body, middle)
  local corrupted = body:sub(1, middle - 1)
    .. string.char((byte + 1) % 256) .. body:sub(middle + 1)
  assert(checksum(corrupted) ~= meta.checksum, "corruption not detected")
  local ok = pcall(function()
    return decodeBlock(body:sub(1, math.max(1, #body - 2)))
  end)
  assert(not ok, "truncation not detected")

  -- Save/reload of the raw cold string.
  local path = "/tmp/opencode/ds7-" .. variant .. ".bin"
  local file = assert(io.open(path, "wb"))
  file:write(cold)
  file:close()
  local read = assert(io.open(path, "rb"))
  local reloaded = assert(read:read("*a"))
  read:close()
  assert(reloaded == cold, "save/reload mismatch")

  reloaded = nil
  body = nil
  corrupted = nil
  model = nil
  collectgarbage("collect")
  heapAfter = collectgarbage("count")
end

-- Live name cache: no names are shipped; names are captured while playing.
collectgarbage("collect")
local nameHeapBefore = collectgarbage("count")
local names = {}
local cacheCount = math.min(nameCacheSize, mobs)
for index = 1, cacheCount do
  local id = 100000 + index * 7 + (index % 3)
  names[id] = string.format("Mob %06d", index)
end
collectgarbage("collect")
local nameHeapAfter = collectgarbage("count")

local nameStart = clockMs()
local nameHits = 0
for index = 1, math.min(10000, cacheCount) do
  local id = 100000 + index * 7 + (index % 3)
  if names[id] then
    nameHits = nameHits + 1
  end
end
local nameLookupMs = clockMs() - nameStart
local missingID = 999999999
local fallback = names[missingID] or ("NPC " .. tostring(missingID))
assert(fallback == "NPC 999999999", "missing-name fallback wrong")

local coldMB = coldBytes / 1024 / 1024
local heapMB = (heapAfter - heapBefore) / 1024
local nameHeapMB = (nameHeapAfter - nameHeapBefore) / 1024

print(string.format("variant=%s mobs=%d zones=%d instances=%d grid=%d contexts=%d density=%.2f",
  variant, mobs, zones, instances, grid, contexts, density))
print(string.format("cold_bytes=%d cold_mb=%.2f heap_mb=%.2f",
  coldBytes, coldMB, heapMB))
print(string.format("escaped_bytes=%d escaped_mb=%.2f",
  escapedBytes, escapedBytes / 1024 / 1024))
print(string.format("base64_bytes=%d base64_mb=%.2f base64_encode_ms=%.1f base64_decode_ms=%.1f base64_roundtrip=%s",
  base64Bytes, base64Bytes / 1024 / 1024, base64EncodeMs, base64DecodeMs,
  base64Tested and tostring(base64Ok) or "not_tested"))
print(string.format("block_base64_bytes=%d block_base64_decode_ms=%.3f block_base64_roundtrip=%s",
  blockBase64Bytes, blockBase64DecodeMs, tostring(blockBase64Ok)))
print(string.format("build_ms=%.1f encode_ms=%.1f checksum_ms=%.1f",
  buildMs, encodeMs, checksumMs))
print(string.format("selected_block_decode_ms=%.3f", selectedDecodeMs))
print(string.format("name_cache_entries=%d name_cache_heap_mb=%.2f name_lookup_10k_ms=%.3f",
  cacheCount, nameHeapMB, nameLookupMs))
print(string.format("plain_lookup_10k_ms=%.3f plain_kills=%d",
  plainLookupMs, plainKills))
print("missing_name_fallback=NPC 999999999")
print("cold_inline_names=0")
if variant == "plain" then
  print("corruption_detected=n/a truncation_detected=n/a save_reload_ok=n/a")
else
  print("corruption_detected=true truncation_detected=true save_reload_ok=true")
end
