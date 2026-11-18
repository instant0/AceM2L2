--[[---------------------------------------------------------------------------------
  KillHistory/JourneyStorage.lua
  Per-zone/instance Journey block storage: base64, checksum, lazy decode, LRU.
  Additive storage only; existing UI/data remain active.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local STORAGE_SCHEMA = 2
local CACHE_CAPACITY = 8
local MAX_MOB_ZONE_REFS = 4
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for index = 1, #B64 do B64_INDEX[B64:sub(index, index)] = index - 1 end

local function Epoch()
  return Util.Epoch and Util.Epoch() or 0
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

local function readVarint(text, position)
  local value, shift = 0, 1
  while true do
    local byte = string.byte(text, position)
    if not byte then error("truncated varint") end
    position = position + 1
    value = value + (byte % 128) * shift
    if byte < 128 then return value, position end
    shift = shift * 128
    if shift > 2 ^ 52 then error("varint too large") end
  end
end

local function checksum(text)
  local sum = #text % 65521
  for index = 1, #text do
    sum = (sum + string.byte(text, index) * (index % 251 + 1)) % 65521
  end
  return sum
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
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (index + 1 <= #text and B64:sub(c3 + 1, c3 + 1) or "=")
      .. (index + 2 <= #text and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end

local function base64Decode(text)
  text = text:gsub("[^" .. B64 .. "=]", "")
  local out = {}
  for index = 1, #text, 4 do
    local c1 = B64_INDEX[text:sub(index, index)] or 0
    local c2 = B64_INDEX[text:sub(index + 1, index + 1)] or 0
    local c3 = B64_INDEX[text:sub(index + 2, index + 2)]
    local c4 = B64_INDEX[text:sub(index + 3, index + 3)]
    local value = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
    out[#out + 1] = string.char(math.floor(value / 65536) % 256)
    if c3 then out[#out + 1] = string.char(math.floor(value / 256) % 256) end
    if c4 then out[#out + 1] = string.char(value % 256) end
  end
  return table.concat(out)
end

local function writeString(parts, value)
  local text = tostring(value or "")
  parts[#parts + 1] = varint(#text)
  parts[#parts + 1] = text
end

local function readString(text, position)
  local length
  length, position = readVarint(text, position)
  if length > 1000000 then error("string too large") end
  return text:sub(position, position + length - 1), position + length
end

local function mobLevelRange(mob)
  local minLevel, maxLevel
  for _, context in pairs(mob.contexts or {}) do
    local level = tonumber(context.mobLevel)
    if level and level > 0 then
      if not minLevel or level < minLevel then minLevel = level end
      if not maxLevel or level > maxLevel then maxLevel = level end
    end
  end
  return minLevel or 0, maxLevel or 0
end

local function encodeMob(parts, record)
  local mob = record.mob
  writeString(parts, record.key)
  parts[#parts + 1] = varint(tonumber(mob.npcID) or 0)
  writeString(parts, mob.name or "")
  writeString(parts, mob.classification or "normal")
  parts[#parts + 1] = varint(tonumber(record.kills) or tonumber(mob.kills) or 0)
  parts[#parts + 1] = varint(tonumber(record.xp) or tonumber(mob.totalXP) or 0)
  local minLevel, maxLevel = mobLevelRange(mob)
  parts[#parts + 1] = varint(minLevel)
  parts[#parts + 1] = varint(maxLevel)
end

local function buildMobZoneIndex(db)
  local index = {}
  for key, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      local totalKills = tonumber(mob.kills) or 0
      local totalXP = tonumber(mob.totalXP) or 0
      for mapKey, mapKills in pairs(mob.killsByMap or {}) do
        local zoneKey = "map:" .. tostring(mapKey)
        index[zoneKey] = index[zoneKey] or {}
        local kills = tonumber(mapKills) or 0
        local xp = totalKills > 0 and totalXP * kills / totalKills or 0
        index[zoneKey][#index[zoneKey] + 1] = { key = key, mob = mob, kills = kills, xp = xp }
      end
      for instanceKey, instanceKills in pairs(mob.killsByInstance or {}) do
        local zoneKey = "instance:" .. tostring(instanceKey)
        index[zoneKey] = index[zoneKey] or {}
        local kills = tonumber(instanceKills) or 0
        local xp = totalKills > 0 and totalXP * kills / totalKills or 0
        index[zoneKey][#index[zoneKey] + 1] = { key = key, mob = mob, kills = kills, xp = xp }
      end
    end
  end
  return index
end

local function buildHeatmapZoneIndex(db)
  local index = {}
  for mapKey, entry in pairs(db.heatmaps or {}) do
    if type(entry) == "table" and type(entry.cells) == "table" then
      local zoneKey = "map:" .. tostring(mapKey)
      local cells = {}
      local total = 0
      for cell, value in pairs(entry.cells) do
        local cellIndex = tonumber(cell) or 0
        local kills = type(value) == "table" and tonumber(value.kills) or tonumber(value)
        if cellIndex > 0 and kills and kills > 0 then
          cells[cellIndex] = {
            kills = kills,
            xp = type(value) == "table" and tonumber(value.xp) or 0,
            presenceSeconds = type(value) == "table" and tonumber(value.presenceSeconds) or 0,
            engagedSeconds = type(value) == "table" and tonumber(value.engagedSeconds) or 0,
          }
          total = total + kills
        end
      end
      if total > 0 then
        index[zoneKey] = {
          cells = cells,
          total = total,
          lastSeen = tonumber(entry.lastSeen) or 0,
        }
      end
    end
  end
  return index
end

local function encodeZone(zoneKey, records, cellEntry)
  local parts = { varint(STORAGE_SCHEMA), varint(1) }
  writeString(parts, zoneKey)
  parts[#parts + 1] = varint(#records)
  for _, record in ipairs(records) do
    encodeMob(parts, record)
  end
  local cells = cellEntry and cellEntry.cells or {}
  local cellKeys = {}
  for cell in pairs(cells) do cellKeys[#cellKeys + 1] = cell end
  table.sort(cellKeys)
  parts[#parts + 1] = varint(#cellKeys)
  for _, cell in ipairs(cellKeys) do
    local value = cells[cell]
    parts[#parts + 1] = varint(cell)
    parts[#parts + 1] = varint(value.kills)
    parts[#parts + 1] = varint(value.xp)
    parts[#parts + 1] = varint(value.presenceSeconds)
    parts[#parts + 1] = varint(value.engagedSeconds)
  end
  return table.concat(parts)
end

function XPTooltip:EnsureJourneyStorage()
  local journey = self:EnsureJourney()
  if not journey then return nil end
  journey.storageSchema = STORAGE_SCHEMA
  journey.blocks = type(journey.blocks) == "table" and journey.blocks or {}
  journey.blockIndex = type(journey.blockIndex) == "table" and journey.blockIndex or {}
  journey.mobZones = type(journey.mobZones) == "table" and journey.mobZones or {}
  journey.dirtyZones = type(journey.dirtyZones) == "table" and journey.dirtyZones or {}
  journey.blockBackup = type(journey.blockBackup) == "table" and journey.blockBackup or {}
  journey.saveBlocked = journey.saveBlocked == true
  journey.oversizeSeen = journey.oversizeSeen == true
  journey.storageMode = journey.storageMode or "additive"
  journey.blockReadFallback = journey.blockReadFallback ~= false
  if not self.journeyBlockCache then
    self.journeyBlockCache = {
      map = {}, order = {}, capacity = CACHE_CAPACITY, evictions = 0,
    }
  end
  if not self.journeyDecodedBlocks then self.journeyDecodedBlocks = 0 end
  return journey
end

function XPTooltip:MarkJourneyDirty(info)
  local journey = self:EnsureJourneyStorage()
  if not journey then return end
  if info and tonumber(info.mapID) and tonumber(info.mapID) > 0 then
    journey.dirtyZones["map:" .. tostring(info.mapID)] = true
  end
  if info and info.instanceKey then
    journey.dirtyZones["instance:" .. tostring(info.instanceKey)] = true
  end
end

local function cacheGet(self, zoneKey)
  local cache = self.journeyBlockCache
  local records = cache and cache.map[zoneKey]
  if not records then return nil end
  for index = 1, #cache.order do
    if cache.order[index] == zoneKey then
      table.remove(cache.order, index)
      break
    end
  end
  cache.order[#cache.order + 1] = zoneKey
  return records
end

local function cachePut(self, zoneKey, records)
  local cache = self.journeyBlockCache
  if not cache then return end
  cache.map[zoneKey] = records
  cache.order[#cache.order + 1] = zoneKey
  if #cache.order > cache.capacity then
    local evicted = table.remove(cache.order, 1)
    cache.map[evicted] = nil
    cache.evictions = (cache.evictions or 0) + 1
  end
end

local function decodeZone(text)
  local position = 1
  local schema, kind
  schema, position = readVarint(text, position)
  kind, position = readVarint(text, position)
  if (schema ~= 1 and schema ~= 2) or kind ~= 1 then
    error("unsupported block")
  end
  local zoneKey, count
  zoneKey, position = readString(text, position)
  count, position = readVarint(text, position)
  local records = {}
  for _ = 1, count do
    local key, npcID, name, classification, kills, xp, minLevel, maxLevel
    key, position = readString(text, position)
    npcID, position = readVarint(text, position)
    name, position = readString(text, position)
    classification, position = readString(text, position)
    kills, position = readVarint(text, position)
    xp, position = readVarint(text, position)
    minLevel, position = readVarint(text, position)
    maxLevel, position = readVarint(text, position)
    records[key] = {
      key = key, npcID = npcID > 0 and npcID or nil,
      name = name, classification = classification,
      kills = kills, xp = xp,
      mobLevelMin = minLevel, mobLevelMax = maxLevel,
    }
  end
  local cells = {}
  if schema >= 2 then
    local cellCount
    cellCount, position = readVarint(text, position)
    for _ = 1, cellCount do
      local cell, kills, xp, presenceSeconds, engagedSeconds
      cell, position = readVarint(text, position)
      kills, position = readVarint(text, position)
      xp, position = readVarint(text, position)
      presenceSeconds, position = readVarint(text, position)
      engagedSeconds, position = readVarint(text, position)
      cells[cell] = {
        kills = kills,
        xp = xp,
        presenceSeconds = presenceSeconds,
        engagedSeconds = engagedSeconds,
      }
    end
  end
  return zoneKey, records, cells
end

function XPTooltip:FlushJourneyBlocks()
  local db = self.char
  local journey = self:EnsureJourneyStorage()
  if not db or not journey then return false end
  if journey.saveBlocked then
    return false, "save_blocked"
  end
  local index = buildMobZoneIndex(db)
  local heatmapIndex = buildHeatmapZoneIndex(db)
  -- Rebuild the compact mob -> zone-key index from the current source data.
  -- It is small (1-4 refs/mob) and avoids stale block references.
  journey.mobZones = {}
  for zoneKey, records in pairs(index) do
    for _, record in ipairs(records) do
      local list = journey.mobZones[record.key] or {}
      list[#list + 1] = zoneKey
      journey.mobZones[record.key] = list
    end
  end
  -- Bound cold fallback fan-out. Selected-zone lookups remain first; this cap
  -- only limits the unqualified fallback index.
  for _, list in pairs(journey.mobZones) do
    table.sort(list)
    while #list > MAX_MOB_ZONE_REFS do
      table.remove(list)
    end
  end
  local dirty = journey.dirtyZones
  local buildAll = next(journey.blocks) == nil
  local keys, seen = {}, {}
  if buildAll then
    for zoneKey in pairs(index) do
      if not seen[zoneKey] then seen[zoneKey] = true; keys[#keys + 1] = zoneKey end
    end
    for zoneKey in pairs(heatmapIndex) do
      if not seen[zoneKey] then seen[zoneKey] = true; keys[#keys + 1] = zoneKey end
    end
  else
    for zoneKey in pairs(dirty) do
      if not seen[zoneKey] then seen[zoneKey] = true; keys[#keys + 1] = zoneKey end
    end
  end
  for _, zoneKey in ipairs(keys) do
    local records = index[zoneKey] or {}
    local cellEntry = heatmapIndex[zoneKey]
    local cellCount = 0
    if cellEntry then
      for _ in pairs(cellEntry.cells) do cellCount = cellCount + 1 end
    end
    local previousBlock = journey.blocks[zoneKey]
    if previousBlock then
      journey.blockBackup[zoneKey] = {
        block = previousBlock,
        index = journey.blockIndex[zoneKey],
        at = Epoch(),
      }
    end
    if #records > 0 or cellCount > 0 then
      local raw = encodeZone(zoneKey, records, cellEntry)
      local sum = checksum(raw)
      journey.blocks[zoneKey] = {
        data = base64Encode(raw),
        checksum = sum,
        count = #records,
        cellCount = cellCount,
        updatedAt = Epoch(),
      }
      journey.blockIndex[zoneKey] = {
        checksum = sum,
        count = #records,
        cellCount = cellCount,
        heatmapKills = cellEntry and cellEntry.total or 0,
        lastSeen = cellEntry and cellEntry.lastSeen or 0,
        updatedAt = Epoch(),
      }
    elseif journey.blocks[zoneKey] then
      -- Do not delete a block merely because the legacy source is empty.
      -- Retirement, a partial migration, or a clear can present an empty
      -- legacy view while the block is still the only surviving copy.
      -- Explicit reset/compaction owns deletion.
    end
    dirty[zoneKey] = nil
  end
  journey.storageUpdatedAt = Epoch()
  return true
end

function XPTooltip:RestoreJourneyBlocks()
  local journey = self:EnsureJourneyStorage()
  if not journey then return false end
  local count = 0
  for zoneKey, backup in pairs(journey.blockBackup or {}) do
    journey.blocks[zoneKey] = backup.block
    journey.blockIndex[zoneKey] = backup.index
    count = count + 1
  end
  self:ClearJourneyBlockCache()
  return count > 0, count
end

function XPTooltip:OnJourneySaveBlocked()
  local journey = self:EnsureJourneyStorage()
  if not journey then return end
  journey.saveBlocked = true
  journey.oversizeSeen = true
  journey.oversizeAt = Epoch()
end

function XPTooltip:ResetJourneySaveBlock()
  local journey = self:EnsureJourneyStorage()
  if not journey then return end
  journey.saveBlocked = false
end

function XPTooltip:GetJourneySaveState()
  local journey = self:EnsureJourneyStorage()
  if not journey then return nil end
  return {
    saveBlocked = journey.saveBlocked == true,
    oversizeSeen = journey.oversizeSeen == true,
    oversizeAt = tonumber(journey.oversizeAt) or 0,
    backupZones = journey.blockBackup and (function()
      local n = 0
      for _ in pairs(journey.blockBackup) do n = n + 1 end
      return n
    end)() or 0,
    storageMode = journey.storageMode,
  }
end

function XPTooltip:GetJourneyBlockData(zoneKey)
  local journey = self:EnsureJourneyStorage()
  if not journey then return nil, "no_journey" end
  local key = tostring(zoneKey or "")
  local cached = cacheGet(self, key)
  if cached then return cached end
  local block = journey.blocks[key]
  if type(block) ~= "table" or type(block.data) ~= "string" then
    return nil, "missing"
  end
  local ok, raw = pcall(base64Decode, block.data)
  if not ok or type(raw) ~= "string" then return nil, "decode" end
  if checksum(raw) ~= tonumber(block.checksum) then
    return nil, "checksum"
  end
  local decodedOk, zoneKeyOut, records, cells = pcall(decodeZone, raw)
  if not decodedOk or type(records) ~= "table" then return nil, "format" end
  local entry = {
    zoneKey = zoneKeyOut or key,
    records = records,
    cells = type(cells) == "table" and cells or {},
  }
  self.journeyDecodedBlocks = (self.journeyDecodedBlocks or 0) + 1
  cachePut(self, key, entry)
  return entry
end

function XPTooltip:GetJourneyBlock(zoneKey)
  local entry, err = self:GetJourneyBlockData(zoneKey)
  if not entry then return nil, err end
  return entry.records, nil, entry.cells
end

function XPTooltip:GetJourneyBlockMob(zoneKey, mobKey)
  local records, err = self:GetJourneyBlock(zoneKey)
  if not records then return nil, err end
  return records[tostring(mobKey or "")], nil
end

function XPTooltip:GetJourneyHeatmapCells(mapID)
  local key = tostring(mapID or "")
  if key:sub(1, 4) ~= "map:" then
    key = "map:" .. key
  end
  local entry, err = self:GetJourneyBlockData(key)
  if not entry then return nil, err end
  if next(entry.cells) == nil then return nil, "empty" end
  local total = 0
  for _, value in pairs(entry.cells) do
    total = total + (tonumber(value.kills) or 0)
  end
  return entry.cells, total
end

function XPTooltip:GetJourneyHeatmapZones()
  local journey = self:EnsureJourneyStorage()
  if not journey then return {} end
  local db = self.char
  local legacy = db and type(db.heatmaps) == "table" and db.heatmaps or nil
  local zones = {}
  for zoneKey, meta in pairs(journey.blockIndex or {}) do
    if type(zoneKey) == "string" and zoneKey:sub(1, 4) == "map:"
      and type(meta) == "table" and (tonumber(meta.heatmapKills) or 0) > 0 then
      local mapID = tonumber(zoneKey:sub(5))
      local retained = true
      if legacy then
        local entry = legacy[tostring(mapID)]
        retained = type(entry) == "table"
          and ((tonumber(entry.total) or 0) > 0
            or (type(entry.cells) == "table" and next(entry.cells) ~= nil))
      end
      if mapID and retained then
        zones[#zones + 1] = {
          mapID = mapID,
          key = zoneKey,
          gridSize = tonumber(XPTooltip.HEATMAP_GRID_SIZE) or 64,
          total = tonumber(meta.heatmapKills) or 0,
          lastSeen = tonumber(meta.lastSeen) or 0,
          cellCount = tonumber(meta.cellCount) or 0,
          source = "journey",
        }
      end
    end
  end
  table.sort(zones, function(a, b)
    if a.lastSeen ~= b.lastSeen then return a.lastSeen > b.lastSeen end
    if a.total ~= b.total then return a.total > b.total end
    return a.mapID < b.mapID
  end)
  return zones
end

function XPTooltip:GetJourneyMobZones(mobKey)
  local journey = self:EnsureJourneyStorage()
  local zones = journey and journey.mobZones and journey.mobZones[tostring(mobKey or "")]
  if type(zones) ~= "table" then return {} end
  local copy = {}
  for index = 1, #zones do copy[index] = zones[index] end
  return copy
end

function XPTooltip:GetJourneyMob(mobKey, zoneKey)
  local key = tostring(mobKey or "")
  local journey = self:EnsureJourneyStorage()
  local zones
  if zoneKey then
    zones = { tostring(zoneKey) }
  else
    zones = journey and journey.mobZones and journey.mobZones[key] or {}
  end
  for _, zone in ipairs(zones) do
    local record = self:GetJourneyBlockMob(zone, key)
    if record then return record, zone end
  end
  -- Legacy fallback while migration remains additive.
  local db = self.char
  local mob = db and db.mobs and db.mobs[key]
  if type(mob) == "table" then
    return {
      key = key, npcID = mob.npcID, name = mob.name,
      classification = mob.classification,
      kills = tonumber(mob.kills) or 0,
      xp = tonumber(mob.totalXP) or 0,
      mobLevelMin = 0, mobLevelMax = 0,
    }, nil
  end
  return nil, "missing"
end

function XPTooltip:ClearJourneyBlockCache()
  if self.journeyBlockCache then
    self.journeyBlockCache.map = {}
    self.journeyBlockCache.order = {}
  end
end
