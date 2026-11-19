--[[---------------------------------------------------------------------------------
  KillHistory/Archive.lua
  Hot/warm/cold retention metadata, heatmap summaries, and block compaction.
  The 64x64 heatmap remains the durable source; 32x32 and 16x16 are derived.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local Epoch = Util.Epoch
local DAY = 86400
local SOURCE_GRID = 64
local WARM_GRID = 32
local COLD_GRID = 16

local PROFILES = {
  ["3m"] = { key = "3m", label = "3 months", warmDays = 30, coldDays = 90 },
  ["6m"] = { key = "6m", label = "6 months", warmDays = 90, coldDays = 180 },
  ["12m"] = { key = "12m", label = "12 months", warmDays = 180, coldDays = 365 },
}
local DEFAULT_PROFILE = "6m"

XPTooltip.RETENTION_PROFILES = PROFILES
XPTooltip.RETENTION_SOURCE_GRID = SOURCE_GRID
XPTooltip.RETENTION_WARM_GRID = WARM_GRID
XPTooltip.RETENTION_COLD_GRID = COLD_GRID

local function finite(value)
  local number = tonumber(value)
  if not number or number ~= number
    or number == math.huge or number == -math.huge then
    return 0
  end
  return number
end

local function copyProfile(profile)
  return {
    key = profile.key,
    label = profile.label,
    warmDays = profile.warmDays,
    coldDays = profile.coldDays,
  }
end

function XPTooltip:GetRetentionProfile(name)
  local key = name
  if key == nil then
    local journey = self.char and self.char.journey
    key = journey and journey.retentionProfile
  end
  local profile = PROFILES[tostring(key or "")]
  return copyProfile(profile or PROFILES[DEFAULT_PROFILE])
end

function XPTooltip:SetRetentionProfile(name)
  local profile = PROFILES[tostring(name or "")]
  if not profile then return false end
  local journey = self:EnsureJourneyStorage()
  if not journey then return false end
  journey.retentionProfile = profile.key
  return true
end

function XPTooltip:GetRetentionTierForAge(ageSeconds, profile)
  local policy = profile
  if type(policy) == "string" then policy = PROFILES[policy] end
  policy = policy or self:GetRetentionProfile()
  local age = finite(ageSeconds)
  if age <= (policy.warmDays or 0) * DAY then return "hot" end
  if age <= (policy.coldDays or 0) * DAY then return "warm" end
  return "cold"
end

local function targetCell(cell, sourceGrid, targetGrid)
  local index = cell - 1
  local column = index % sourceGrid
  local row = math.floor(index / sourceGrid)
  local ratio = sourceGrid / targetGrid
  local targetColumn = math.floor(column / ratio) + 1
  local targetRow = math.floor(row / ratio) + 1
  return (targetRow - 1) * targetGrid + targetColumn
end

function XPTooltip:DownsampleHeatmapCells(source, sourceGrid, targetGrid)
  local cells = {}
  local total = 0
  local from = tonumber(sourceGrid) or SOURCE_GRID
  local to = tonumber(targetGrid) or WARM_GRID
  if from <= 0 or to <= 0 or from % to ~= 0 then return cells, 0 end
  for rawCell, value in pairs(source or {}) do
    local cell = tonumber(rawCell) or 0
    local kills = type(value) == "table" and finite(value.kills) or finite(value)
    if cell > 0 and cell <= from * from and kills > 0 then
      local target = targetCell(cell, from, to)
      cells[target] = (cells[target] or 0) + kills
      total = total + kills
    end
  end
  local records = {}
  for cell, kills in pairs(cells) do records[cell] = { kills = kills } end
  return records, total
end

function XPTooltip:UpdateJourneyHeatmapSummaries()
  local journey = self:EnsureJourneyStorage()
  if not journey then return nil end
  local summaries = {}
  for key, entry in pairs(journey.heatmaps or {}) do
    if type(entry) == "table" and type(entry.cells) == "table" then
      local warmCells, warmTotal =
        self:DownsampleHeatmapCells(entry.cells, SOURCE_GRID, WARM_GRID)
      local coldCells, coldTotal =
        self:DownsampleHeatmapCells(entry.cells, SOURCE_GRID, COLD_GRID)
      summaries[key] = {
        mapID = tonumber(key) or 0,
        sourceGrid = SOURCE_GRID,
        sourceTotal = finite(entry.total),
        lastSeen = finite(entry.lastSeen),
        warm = {
          gridSize = WARM_GRID,
          cells = warmCells,
          total = warmTotal,
        },
        cold = {
          gridSize = COLD_GRID,
          cells = coldCells,
          total = coldTotal,
        },
      }
    end
  end
  journey.heatmapSummaries = summaries
  return summaries
end

local function markZoneDirty(self, zoneKey)
  if type(zoneKey) ~= "string" then return end
  if zoneKey:sub(1, 4) == "map:" then
    self:MarkJourneyDirty({ mapID = tonumber(zoneKey:sub(5)) })
  elseif zoneKey:sub(1, 9) == "instance:" then
    self:MarkJourneyDirty({ instanceKey = zoneKey:sub(10) })
  end
end

function XPTooltip:GetBlockRetentionTier(zoneKey, meta)
  local journey = self:EnsureJourneyStorage()
  if not journey then return "hot" end
  local currentZone = journey.time and journey.time.zone
  local instanceKey = journey.time and journey.time.instanceKey
  if (currentZone and ("map:" .. tostring(currentZone)) == zoneKey)
    or (instanceKey and ("instance:" .. tostring(instanceKey)) == zoneKey) then
    return "hot"
  end
  local stamp = finite(meta and meta.lastSeen)
  if stamp <= 0 then
    stamp = finite(meta and meta.updatedAt)
  end
  if stamp <= 0 then return "hot" end
  local now = Epoch()
  return self:GetRetentionTierForAge(now - stamp, self:GetRetentionProfile())
end

function XPTooltip:CompactJourneyBlocks()
  local journey = self:EnsureJourneyStorage()
  if not journey then return false end
  local blocks = journey.blocks
  local index = journey.blockIndex
  local removedBlocks, removedIndex, rebuiltIndex = 0, 0, 0
  for key, block in pairs(blocks or {}) do
    if type(block) ~= "table" or type(block.data) ~= "string" then
      blocks[key] = nil
      removedBlocks = removedBlocks + 1
    end
  end
  for key in pairs(index or {}) do
    if type(blocks[key]) ~= "table" then
      index[key] = nil
      removedIndex = removedIndex + 1
    end
  end
  for key, block in pairs(blocks or {}) do
    if type(index[key]) ~= "table" then
      index[key] = {
        checksum = block.checksum,
        count = tonumber(block.count) or 0,
        cellCount = tonumber(block.cellCount) or 0,
        heatmapKills = 0,
        lastSeen = 0,
        hasZone = false,
        tier = block.tier or "hot",
        updatedAt = tonumber(block.updatedAt) or 0,
      }
      rebuiltIndex = rebuiltIndex + 1
    end
  end
  return {
    removedBlocks = removedBlocks,
    removedIndex = removedIndex,
    rebuiltIndex = rebuiltIndex,
  }
end

function XPTooltip:ApplyJourneyRetention()
  local journey = self:EnsureJourneyStorage()
  if not journey then return nil end
  local profile = self:GetRetentionProfile()
  journey.retentionProfile = profile.key
  local now = Epoch()
  local compacted = self:CompactJourneyBlocks()
  local tiers = { hot = 0, warm = 0, cold = 0 }
  local changed = 0
  for zoneKey, meta in pairs(journey.blockIndex or {}) do
    if type(meta) == "table" then
      local tier = self:GetBlockRetentionTier(zoneKey, meta)
      tiers[tier] = tiers[tier] + 1
      if meta.tier ~= tier then
        meta.tier = tier
        meta.contextMode = tier == "hot" and "full" or "collapsed"
        local block = journey.blocks and journey.blocks[zoneKey]
        if type(block) == "table" then
          block.tier = tier
          block.contextMode = meta.contextMode
        end
        markZoneDirty(self, zoneKey)
        changed = changed + 1
      end
    end
  end
  self:UpdateJourneyHeatmapSummaries()
  journey.retention = {
    profile = profile.key,
    profileLabel = profile.label,
    appliedAt = now,
    blocks = tiers,
    changed = changed,
  }
  return {
    profile = profile,
    blocks = tiers,
    changed = changed,
    compacted = compacted,
  }
end

function XPTooltip:GetRetentionStats()
  local journey = self:EnsureJourneyStorage()
  if not journey then return {} end
  local profile = self:GetRetentionProfile()
  local tiers = { hot = 0, warm = 0, cold = 0 }
  local blockCount, blockBytes = 0, 0
  for key, meta in pairs(journey.blockIndex or {}) do
    if type(meta) == "table" then
      local tier = meta.tier or "hot"
      tiers[tier] = (tiers[tier] or 0) + 1
      blockCount = blockCount + 1
    end
    local block = journey.blocks and journey.blocks[key]
    if type(block) == "table" and type(block.data) == "string" then
      blockBytes = blockBytes + #block.data
    end
  end
  local summaries, summaryCells = 0, 0
  for _, summary in pairs(journey.heatmapSummaries or {}) do
    summaries = summaries + 1
    for _ in pairs(summary.warm and summary.warm.cells or {}) do
      summaryCells = summaryCells + 1
    end
    for _ in pairs(summary.cold and summary.cold.cells or {}) do
      summaryCells = summaryCells + 1
    end
  end
  local retention = type(journey.retention) == "table" and journey.retention or {}
  return {
    profile = profile.key,
    profileLabel = profile.label,
    appliedAt = tonumber(retention.appliedAt) or 0,
    blocks = tiers,
    blockCount = blockCount,
    blockBytes = blockBytes,
    summaries = summaries,
    summaryCells = summaryCells,
  }
end
