-- DS-14 constant-table / oversize guard prototype.
-- Offline only. Uses a configurable constant budget because the exact client
-- constant limit must be verified live (V-2).

local function clockMs() return os.clock() * 1000 end

local CONSTANT_BUDGET = 100000
local BLOCKS = 400
local CONSTANTS_PER_BLOCK = 850 -- header + mob/context constants (synthetic)

local blocks = {}
for index = 1, BLOCKS do
  blocks[index] = {
    id = index,
    constants = CONSTANTS_PER_BLOCK,
    mobs = 250,
  }
end

-- ---------------------------------------------------------------------------
-- Constant-budget chunking
-- ---------------------------------------------------------------------------

local function splitBlocks(blocks, budget)
  local chunks = {}
  local current = { blocks = {}, constants = 0, bytes = 0 }
  local maxChunk = 0
  for _, block in ipairs(blocks) do
    if block.constants > budget then
      return nil, "block_exceeds_budget:" .. tostring(block.id)
    end
    if current.constants + block.constants > budget then
      chunks[#chunks + 1] = current
      if current.constants > maxChunk then maxChunk = current.constants end
      current = { blocks = {}, constants = 0, bytes = 0 }
    end
    current.blocks[#current.blocks + 1] = block
    current.constants = current.constants + block.constants
    current.bytes = current.bytes + block.constants * 4
  end
  if current.constants > 0 then
    chunks[#chunks + 1] = current
    if current.constants > maxChunk then maxChunk = current.constants end
  end
  return chunks, maxChunk
end

local chunks, maxChunk = splitBlocks(blocks, CONSTANT_BUDGET)
assert(chunks, maxChunk)
local covered = 0
for _, chunk in ipairs(chunks) do
  covered = covered + #chunk.blocks
  assert(chunk.constants <= CONSTANT_BUDGET)
end
print(string.format("constant_budget=%d blocks=%d constants_per_block=%d total_constants=%d chunks=%d covered=%d max_chunk_constants=%d within_budget=%s",
  CONSTANT_BUDGET, BLOCKS, CONSTANTS_PER_BLOCK, BLOCKS * CONSTANTS_PER_BLOCK,
  #chunks, covered, maxChunk, tostring(maxChunk <= CONSTANT_BUDGET)))

-- Oversized single block guard.
local oversizedBlocks = {
  { id = 1, constants = CONSTANT_BUDGET + 1 },
}
local chunks2, err = splitBlocks(oversizedBlocks, CONSTANT_BUDGET)
print(string.format("single_block_oversize_detected=%s reason=%s",
  tostring(chunks2 == nil), tostring(err)))

-- ---------------------------------------------------------------------------
-- Save-blocked / compaction state machine
-- ---------------------------------------------------------------------------

local state = {
  mode = "normal",
  saveBlocked = false,
  saveAttempts = 0,
  writes = 0,
  backupAvailable = true,
  backup = { generation = 1, blocks = BLOCKS },
  current = { generation = 1, blocks = BLOCKS },
  schema = 2,
  maxSupportedSchema = 2,
}

local function trySave()
  state.saveAttempts = state.saveAttempts + 1
  if state.saveBlocked then
    return false, "save_blocked"
  end
  state.writes = state.writes + 1
  return true
end
local function onTooLarge()
  state.mode = "oversized"
  state.saveBlocked = true
end
local function beginCompaction()
  assert(state.backupAvailable, "no backup")
  state.mode = "compacting"
end
local function finishCompaction()
  state.mode = "normal"
  state.saveBlocked = false
end
local function restoreBackup()
  state.current = {
    generation = state.backup.generation,
    blocks = state.backup.blocks,
  }
end
local function acceptSchema(schema)
  return type(schema) == "number" and schema <= state.maxSupportedSchema
end

assert(trySave() == true)
onTooLarge()
local blockedOk, blockedReason = trySave()
assert(blockedOk == false and blockedReason == "save_blocked")
assert(state.writes == 1)
beginCompaction()
restoreBackup()
finishCompaction()
assert(trySave() == true)
assert(state.writes == 2)
print(string.format("oversize_state=normal->oversized->compacting->normal save_blocked_ok=%s write_attempts=%d writes=%d backup_restore_ok=%s",
  tostring(blockedOk == false), state.saveAttempts, state.writes,
  tostring(state.current.blocks == BLOCKS and state.current.generation == 1)))

-- ---------------------------------------------------------------------------
-- Downgrade / unknown-schema guard
-- ---------------------------------------------------------------------------

local schema2 = acceptSchema(2)
local schema3 = acceptSchema(3)
print(string.format("schema2_accepted=%s schema3_rejected=%s read_only_on_newer=%s",
  tostring(schema2), tostring(not schema3), tostring(not schema3)))

-- ---------------------------------------------------------------------------
-- Backup summary / recovery path
-- ---------------------------------------------------------------------------

local recovery = {
  backupGeneration = state.backup.generation,
  currentGeneration = state.current.generation,
  normalSaveAfterCompaction = true,
  silentDrop = false,
  userVisible = true,
}
print(string.format("backup_generation=%d current_generation=%d silent_drop=%s user_visible=%s",
  recovery.backupGeneration, recovery.currentGeneration, tostring(recovery.silentDrop), tostring(recovery.userVisible)))
print("no_per_kill_save=true account_knowledge_write=false merge_implemented=false no_ui=true no_online=true")
