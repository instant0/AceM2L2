-- DS-6 static metadata feasibility harness.
-- Usage:
--   lua tests/ds6_static_metadata.lua <variant> <rows> <name_len> <fields>
-- variant: map | delta | packed_block | packed_full
-- rows:    10000 | 100000 | 350000
-- name_len: 12 | 24 | 40
-- fields:  name | full
--
-- Measures generated source/blob bytes, load time, Lua heap, lookup cost, and
-- missing-name fallback. This is an offline prototype; it is not production
-- schema and does not depend on any third-party addon data.

local variant = arg[1] or "map"
local rows = tonumber(arg[2] or "10000") or 10000
local nameLen = tonumber(arg[3] or "24") or 24
local fields = arg[4] or "name"

local VALID_VARIANTS = {
  map = true, delta = true, packed_block = true, packed_full = true,
}
assert(VALID_VARIANTS[variant], "unknown variant: " .. tostring(variant))
assert(rows > 0, "rows must be positive")
assert(nameLen >= 8, "name_len must be >= 8")
assert(fields == "name" or fields == "full", "fields must be name|full")

local BASE_ID = 100000
local STRIDE = 3
local BLOCK = 64
local PROJECT = "forever"
local INTERFACE = 16001
local SCHEMA = 1

local function clockMs()
  return os.clock() * 1000
end

local function makeName(index, length)
  local suffix = string.format("%08d", index)
  if length <= #suffix then
    return suffix:sub(-length)
  end
  return string.rep("n", length - #suffix) .. suffix
end

local function rowId(index)
  return BASE_ID + index * STRIDE
end

local function rowName(index)
  return makeName(index, nameLen)
end

local function rowClass(index)
  return (index % 5) + 1
end

local function rowLevel(index)
  return (index % 60) + 1
end

-- ---------------------------------------------------------------------------
-- Source generators
-- ---------------------------------------------------------------------------

local function generateMapSource()
  local parts = {
    string.format(
      "return {schema=%d,project=%q,interface=%d,count=%d,names={",
      SCHEMA, PROJECT, INTERFACE, rows),
  }
  if fields == "full" then
    for i = 1, rows do
      parts[#parts + 1] = string.format("[%d]={n=%q,c=%d,l=%d},",
        rowId(i), rowName(i), rowClass(i), rowLevel(i))
    end
  else
    for i = 1, rows do
      parts[#parts + 1] = string.format("[%d]=%q,", rowId(i), rowName(i))
    end
  end
  parts[#parts + 1] = "}}"
  return table.concat(parts)
end

local function generateDeltaSource()
  local names, classes, levels = {}, {}, {}
  for i = 1, rows do
    names[i] = string.format("%q", rowName(i))
    if fields == "full" then
      classes[i] = tostring(rowClass(i))
      levels[i] = tostring(rowLevel(i))
    end
  end
  local parts = {
    string.format(
      "return {schema=%d,project=%q,interface=%d,count=%d,base=%d,names={",
      SCHEMA, PROJECT, INTERFACE, rows, BASE_ID + STRIDE),
    table.concat(names, ","),
    "}",
  }
  if fields == "full" then
    parts[#parts + 1] = ",classes={" .. table.concat(classes, ",") .. "}"
    parts[#parts + 1] = ",levels={" .. table.concat(levels, ",") .. "}"
  end
  parts[#parts + 1] = "}"
  return table.concat(parts)
end

local function varint(value)
  local bytes = {}
  repeat
    local byte = value % 128
    value = math.floor(value / 128)
    if value > 0 then
      byte = byte + 128
    end
    bytes[#bytes + 1] = string.char(byte)
  until value == 0
  return table.concat(bytes)
end

local function generatePacked()
  local parts = {}
  local offsets = {}
  local block = 1
  local byteCount = 0
  offsets[block] = 1
  local previous = 0
  for i = 1, rows do
    local id = BASE_ID + i * STRIDE
    if i > 1 and (i - 1) % BLOCK == 0 then
      block = block + 1
      offsets[block] = byteCount + 1
    end
    local name = rowName(i)
    assert(#name < 256, "name too long for this prototype")
    local delta = varint(id - previous)
    local lengthByte = string.char(#name)
    parts[#parts + 1] = delta
    parts[#parts + 1] = lengthByte
    parts[#parts + 1] = name
    byteCount = byteCount + #delta + 1 + #name
    if fields == "full" then
      local classByte = string.char(rowClass(i))
      local levelByte = string.char(rowLevel(i))
      parts[#parts + 1] = classByte
      parts[#parts + 1] = levelByte
      byteCount = byteCount + 2
    end
    previous = id
  end
  return table.concat(parts), offsets
end

-- Decode one 64-row block. Offsets are byte positions of each block start.
local function decodeBlock(blob, blockStart, blockEnd, firstId)
  local names, classes, levels = {}, {}, {}
  local position = blockStart
  local previous = firstId - STRIDE
  local count = 0
  while position <= blockEnd do
    -- varint id delta
    local shift, value = 1, 0
    while true do
      local byte = string.byte(blob, position)
      position = position + 1
      value = value + (byte % 128) * shift
      if byte < 128 then
        break
      end
      shift = shift * 128
    end
    previous = previous + value
    local length = string.byte(blob, position)
    position = position + 1
    local name = string.sub(blob, position, position + length - 1)
    position = position + length
    count = count + 1
    names[count] = name
    if fields == "full" then
      classes[count] = string.byte(blob, position)
      levels[count] = string.byte(blob, position + 1)
      position = position + 2
    end
  end
  return { firstId = firstId, names = names,
    classes = classes, levels = levels, count = count }
end

local function makePackedData(blob, offsets)
  local data = {
    schema = SCHEMA, project = PROJECT, interface = INTERFACE,
    count = rows, base = BASE_ID + STRIDE, blob = blob, offsets = offsets,
    block = BLOCK, stride = STRIDE,
  }
  return data
end

local function makePackedFullData(blob, offsets)
  -- Full decode into a numeric map; this is the worst-case heap option.
  local names, classes, levels = {}, {}, {}
  local blockCount = #offsets
  for block = 1, blockCount do
    local blockStart = offsets[block]
    local blockEnd = block < blockCount and (offsets[block + 1] - 1) or #blob
    local firstId = BASE_ID + ((block - 1) * BLOCK + 1) * STRIDE
    local decoded = decodeBlock(blob, blockStart, blockEnd, firstId)
    for i = 1, decoded.count do
      local id = decoded.firstId + (i - 1) * STRIDE
      names[id] = decoded.names[i]
      if fields == "full" then
        classes[id] = decoded.classes[i]
        levels[id] = decoded.levels[i]
      end
    end
  end
  return {
    schema = SCHEMA, project = PROJECT, interface = INTERFACE,
    count = rows, names = names, classes = classes, levels = levels,
  }
end

-- ---------------------------------------------------------------------------
-- Load and lookup
-- ---------------------------------------------------------------------------

local source
local packedBlob, packedOffsets

collectgarbage("collect")
local heapBefore = collectgarbage("count")
local genStart = clockMs()

if variant == "map" then
  source = generateMapSource()
elseif variant == "delta" then
  source = generateDeltaSource()
else
  packedBlob, packedOffsets = generatePacked()
end
local genMs = clockMs() - genStart

local generatedBytes = source and #source or #packedBlob
local packedSourceBytes = 0
if packedBlob then
  -- Show the escaped-source cost separately; the raw blob is the codec target.
  packedSourceBytes = #string.format("%q", packedBlob) +
    #("return {schema=1,blob=") + #("}")
end

local loadStart = clockMs()
local data
if source then
  local chunk = assert((loadstring or load)(source, "=ds6_static"))
  source = nil
  data = chunk()
  chunk = nil
else
  data = (variant == "packed_block")
    and makePackedData(packedBlob, packedOffsets)
    or makePackedFullData(packedBlob, packedOffsets)
  packedBlob = nil
  packedOffsets = nil
end
collectgarbage("collect")
local heapAfter = collectgarbage("count")
local loadMs = clockMs() - loadStart

local function getPackedBlockRow(id)
  local block = math.floor((id - data.base) / data.stride / data.block) + 1
  if block < 1 or block > #data.offsets then
    return nil
  end
  local blockStart = data.offsets[block]
  local blockEnd = block < #data.offsets
    and (data.offsets[block + 1] - 1) or #data.blob
  local firstId = BASE_ID + ((block - 1) * data.block + 1) * data.stride
  local decoded = decodeBlock(data.blob, blockStart, blockEnd, firstId)
  for i = 1, decoded.count do
    local rowId = decoded.firstId + (i - 1) * data.stride
    if rowId == id then
      return decoded.names[i], decoded.classes[i], decoded.levels[i]
    end
  end
  return nil
end

local function getName(id)
  if variant == "map" then
    local row = data.names[id]
    if row == nil then
      return nil
    end
    return type(row) == "table" and row.n or row
  elseif variant == "delta" then
    local index = id - data.base
    if index < 0 or index % STRIDE ~= 0 then
      return nil
    end
    index = index / STRIDE + 1
    return data.names[index]
  elseif variant == "packed_full" then
    return data.names[id]
  else
    return (getPackedBlockRow(id))
  end
end

local function getClass(id)
  if variant == "map" then
    local row = data.names[id]
    return type(row) == "table" and row.c or nil
  elseif variant == "delta" then
    local index = (id - data.base) / STRIDE + 1
    return data.classes and data.classes[index] or nil
  elseif variant == "packed_full" then
    return data.classes[id]
  else
    local _, class = getPackedBlockRow(id)
    return class
  end
end

local function getLevel(id)
  if variant == "map" then
    local row = data.names[id]
    return type(row) == "table" and row.l or nil
  elseif variant == "delta" then
    local index = (id - data.base) / STRIDE + 1
    return data.levels and data.levels[index] or nil
  elseif variant == "packed_full" then
    return data.levels[id]
  else
    local _, _, level = getPackedBlockRow(id)
    return level
  end
end

local function displayName(id)
  local name = getName(id)
  if name then
    return name
  end
  return "NPC " .. tostring(id)
end

local function validateStatic(meta)
  if type(meta) ~= "table" then
    return false
  end
  if meta.schema ~= SCHEMA or meta.project ~= PROJECT
    or meta.interface ~= INTERFACE then
    return false
  end
  if type(meta.count) ~= "number" or meta.count <= 0 then
    return false
  end
  return true
end

assert(validateStatic(data), "generated metadata failed validation")
assert(not validateStatic({ schema = SCHEMA + 1, project = PROJECT,
  interface = INTERFACE, count = rows }), "wrong schema accepted")
assert(not validateStatic({ schema = SCHEMA, project = "midnight",
  interface = INTERFACE, count = rows }), "wrong project accepted")
assert(not validateStatic({ schema = SCHEMA, project = PROJECT,
  interface = INTERFACE + 1, count = rows }), "wrong interface accepted")

local LOOKUPS = 10000
math.randomseed(20261116)
local ids = {}
for i = 1, LOOKUPS do
  ids[i] = rowId(math.random(1, rows))
end

local lookupStart = clockMs()
for i = 1, LOOKUPS do
  assert(getName(ids[i]) ~= nil, "lookup miss")
end
local lookupMs = clockMs() - lookupStart

local classStart = clockMs()
if fields == "full" then
  for i = 1, LOOKUPS do
    local id = ids[i]
    assert(getClass(id) ~= nil, "class miss")
    assert(getLevel(id) ~= nil, "level miss")
  end
end
local classMs = clockMs() - classStart

local missingId = rowId(rows + 10000)
assert(getName(missingId) == nil, "missing ID resolved")
local fallback = displayName(missingId)
assert(fallback == "NPC " .. tostring(missingId), "fallback label wrong")

-- Duplicate names must not corrupt ID lookup or silently resolve to one ID.
local duplicateById = { [111] = "Shared Name", [222] = "Shared Name" }
local scopedByName = {}
local function addScopedName(lower, id)
  local existing = scopedByName[lower]
  if existing == nil then
    scopedByName[lower] = id
  elseif existing ~= id then
    scopedByName[lower] = false
  end
end
addScopedName("shared name", 111)
addScopedName("shared name", 222)
assert(duplicateById[111] == "Shared Name")
assert(duplicateById[222] == "Shared Name")
assert(scopedByName["shared name"] == false, "ambiguous name resolved")

-- Verify a sample of decoded names to catch an off-by-one block/offset bug.
for i = 1, rows, math.max(1, math.floor(rows / 1000)) do
  local id = rowId(i)
  assert(getName(id) == rowName(i), "name mismatch at row " .. i)
end

print(string.format("variant=%s rows=%d name_len=%d fields=%s",
  variant, rows, nameLen, fields))
print(string.format("generated_bytes=%d packed_source_bytes=%d",
  generatedBytes, packedSourceBytes))
print(string.format("generate_ms=%.1f load_ms=%.1f heap_mb=%.2f",
  genMs, loadMs, (heapAfter - heapBefore) / 1024))
print(string.format("lookup_10k_ms=%.3f full_fields_10k_ms=%.3f",
  lookupMs, classMs))
print(string.format("missing_fallback=%s", fallback))
print(string.format("missing_name_nil=true sample_names_ok=true"))
print(string.format("version_validation=ok ambiguous_name=nil duplicate_ids_ok=true"))
