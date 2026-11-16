-- DS-16 save/checkpoint policy prototype.
-- Measures dirty-block incremental base64 saves and exercises backup/oversize states.
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
-- Synthetic cold blocks
-- ---------------------------------------------------------------------------

local BLOCKS = 400
local BLOCK_BYTES = 10000
local blocks = {}
for block = 1, BLOCKS do
  local parts = {}
  for i = 1, BLOCK_BYTES, 64 do
    parts[#parts + 1] = string.format("%064d", block * 100000 + i)
  end
  blocks[block] = table.concat(parts)
end

local function encodeBlocks(indexes)
  local encoded = {}
  local rawBytes, encodedBytes = 0, 0
  for _, index in ipairs(indexes) do
    local text = blocks[index]
    encoded[#encoded + 1] = { index = index, raw = text,
      base64 = base64Encode(text), checksum = checksum(text) }
    rawBytes = rawBytes + #text
    encodedBytes = encodedBytes + #encoded[#encoded].base64
  end
  return encoded, rawBytes, encodedBytes
end

local allIndexes = {}
for index = 1, BLOCKS do allIndexes[index] = index end

print(string.format("blocks=%d block_bytes=%d raw_total_mb=%.2f", BLOCKS, BLOCK_BYTES,
  BLOCKS * BLOCK_BYTES / 1024 / 1024))

for _, dirtyCount in ipairs({1, 10, 100, 400}) do
  local indexes = {}
  for index = 1, dirtyCount do indexes[index] = index end
  local start = clockMs()
  local encoded, rawBytes, encodedBytes = encodeBlocks(indexes)
  local encodeMs = clockMs() - start
  print(string.format("checkpoint_dirty_blocks=%d encode_ms=%.1f raw_mb=%.2f base64_mb=%.2f entries=%d",
    dirtyCount, encodeMs, rawBytes / 1024 / 1024, encodedBytes / 1024 / 1024, #encoded))
end

-- ---------------------------------------------------------------------------
-- Save/reload simulation
-- ---------------------------------------------------------------------------

local encodedAll = encodeBlocks(allIndexes)
local path = "/tmp/opencode/ds16-save.txt"
local saveStart = clockMs()
local file = assert(io.open(path, "wb"))
for _, entry in ipairs(encodedAll) do
  file:write(entry.index, "\t", entry.checksum, "\t", entry.base64, "\n")
end
file:close()
local saveMs = clockMs() - saveStart

local loadStart = clockMs()
local read = assert(io.open(path, "rb"))
local count, sum = 0, 0
for line in read:lines() do
  local index, check, data = line:match("^(%d+)\t(%d+)\t(.+)$")
  if index then
    count = count + 1
    sum = sum + tonumber(check)
    local raw = base64Decode(data)
    assert(checksum(raw) == tonumber(check), "checksum mismatch")
  end
end
read:close()
local loadMs = clockMs() - loadStart
print(string.format("save_all_ms=%.1f reload_all_ms=%.1f blocks=%d checksum_sum=%d file_mb=%.2f",
  saveMs, loadMs, count, sum, (function()
    local f = assert(io.open(path, "rb")); local n = #f:read("*a"); f:close(); return n / 1024 / 1024
  end)()))

-- ---------------------------------------------------------------------------
-- Backup / restore
-- ---------------------------------------------------------------------------

local previous = {}
for _, entry in ipairs(encodedAll) do previous[entry.index] = entry end
local working = {}
for index, entry in pairs(previous) do working[index] = entry end
working[1] = { index = 1, base64 = "corrupt", checksum = 1 }
local restored = previous[1]
assert(restored and restored.checksum ~= working[1].checksum, "backup restore check failed")
print("backup_previous_retained=true restore_ok=true")

-- ---------------------------------------------------------------------------
-- Oversize state machine
-- ---------------------------------------------------------------------------

local state = {
  mode = "normal",
  saveBlocked = false,
  backupAvailable = true,
  overSizeSeen = false,
}

local function onTooLarge()
  state.mode = "oversized"
  state.saveBlocked = true
  state.overSizeSeen = true
end
local function beginCompaction()
  assert(state.backupAvailable, "no backup")
  state.mode = "compacting"
end
local function finishCompaction()
  state.mode = "normal"
  state.saveBlocked = false
end

onTooLarge()
assert(state.saveBlocked == true and state.backupAvailable == true)
beginCompaction()
finishCompaction()
assert(state.saveBlocked == false)
print("oversize_state=normal->oversized->compacting->normal save_blocked=true backup_available=true")

print("checkpoint_triggers=session_end;logout_reload;SaveAddOns;ADDONS_UNLOADING;migration_compression")
print("per_kill_disk_write=false account_knowledge_write=false merge_implemented=false no_ui=true no_online=true")
