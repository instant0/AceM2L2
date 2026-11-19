--[[---------------------------------------------------------------------------------
  KillHistory/JourneyStorage.lua
  Per-zone/instance Journey block storage: base64, checksum, lazy decode, LRU.
  Additive storage only; existing UI/data remain active.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local STORAGE_SCHEMA = 3
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

local function numberOrZero(value)
  local number = tonumber(value)
  if not number or number ~= number
    or number == math.huge or number == -math.huge then
    return 0
  end
  return number
end

local function readCount(text, position, label)
  local count
  count, position = readVarint(text, position)
  if count > #text - position + 1 then
    error((label or "item") .. " count too large")
  end
  return count, position
end

local function levelSort(a, b)
  local left, right = tonumber(a), tonumber(b)
  if left and right and left ~= right then return left < right end
  return tostring(a) < tostring(b)
end

local function encodeLevelRecords(parts, records)
  local keys = {}
  for key, value in pairs(records or {}) do
    local record = type(value) == "table" and value or { kills = value }
    if numberOrZero(record.kills) > 0 or numberOrZero(record.xp) > 0
      or numberOrZero(record.samples) > 0
      or numberOrZero(record.presenceSeconds) > 0
      or numberOrZero(record.engagedSeconds) > 0 then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys, levelSort)
  parts[#parts + 1] = varint(#keys)
  for _, key in ipairs(keys) do
    local value = records[key]
    local record = type(value) == "table" and value or { kills = value }
    writeString(parts, tostring(key))
    parts[#parts + 1] = varint(record.kills)
    parts[#parts + 1] = varint(record.xp)
    parts[#parts + 1] = varint(record.samples or record.kills)
    parts[#parts + 1] = varint(record.presenceSeconds)
    parts[#parts + 1] = varint(record.engagedSeconds)
  end
end

local function decodeLevelRecords(text, position)
  local count
  count, position = readCount(text, position, "level")
  local records = {}
  for _ = 1, count do
    local key, kills, xp, samples, presenceSeconds, engagedSeconds
    key, position = readString(text, position)
    kills, position = readVarint(text, position)
    xp, position = readVarint(text, position)
    samples, position = readVarint(text, position)
    presenceSeconds, position = readVarint(text, position)
    engagedSeconds, position = readVarint(text, position)
    records[key] = {
      kills = kills, xp = xp, samples = samples,
      presenceSeconds = presenceSeconds,
      engagedSeconds = engagedSeconds,
    }
  end
  return records, position
end

local function writeOptionalNumber(parts, value)
  local number = tonumber(value)
  if not number or number ~= number
    or number == math.huge or number == -math.huge then
    parts[#parts + 1] = varint(0)
    return
  end
  parts[#parts + 1] = varint(1)
  parts[#parts + 1] = varint(number)
end

local function readOptionalNumber(text, position)
  local present
  present, position = readVarint(text, position)
  if present ~= 1 then return nil, position end
  local number
  number, position = readVarint(text, position)
  return number, position
end

local function encodeContext(parts, context)
  writeString(parts, context.key)
  parts[#parts + 1] = varint(context.playerLevel)
  parts[#parts + 1] = varint(context.mobLevel)
  parts[#parts + 1] = varint(context.groupSize)
  parts[#parts + 1] = varint(context.mapID)
  writeString(parts, context.instanceKey)
  writeString(parts, context.classification or "normal")
  writeString(parts, context.buffSig or "none")
  parts[#parts + 1] = varint(context.samples)
  parts[#parts + 1] = varint(context.sumBase)
  parts[#parts + 1] = varint(context.sumBuffed)
  parts[#parts + 1] = varint(context.sumTotal)
  writeOptionalNumber(parts, context.minBase)
  writeOptionalNumber(parts, context.maxBase)
  writeOptionalNumber(parts, context.deaths)
  parts[#parts + 1] = varint(context.lastSeen)
end

local function decodeContext(text, position)
  local key, instanceKey, classification, buffSig
  local playerLevel, mobLevel, groupSize, mapID
  local samples, sumBase, sumBuffed, sumTotal, lastSeen
  key, position = readString(text, position)
  playerLevel, position = readVarint(text, position)
  mobLevel, position = readVarint(text, position)
  groupSize, position = readVarint(text, position)
  mapID, position = readVarint(text, position)
  instanceKey, position = readString(text, position)
  classification, position = readString(text, position)
  buffSig, position = readString(text, position)
  samples, position = readVarint(text, position)
  sumBase, position = readVarint(text, position)
  sumBuffed, position = readVarint(text, position)
  sumTotal, position = readVarint(text, position)
  local minBase, maxBase, deaths
  minBase, position = readOptionalNumber(text, position)
  maxBase, position = readOptionalNumber(text, position)
  deaths, position = readOptionalNumber(text, position)
  lastSeen, position = readVarint(text, position)
  return {
    key = key,
    playerLevel = playerLevel,
    mobLevel = mobLevel,
    groupSize = groupSize,
    mapID = mapID,
    instanceKey = instanceKey ~= "" and instanceKey or nil,
    classification = classification ~= "" and classification or nil,
    buffSig = buffSig ~= "" and buffSig or nil,
    samples = samples,
    sumBase = sumBase,
    sumBuffed = sumBuffed,
    sumTotal = sumTotal,
    minBase = minBase,
    maxBase = maxBase,
    deaths = deaths,
    lastSeen = lastSeen,
  }, position
end

local function encodeContexts(parts, contexts)
  local list = {}
  for _, context in ipairs(contexts or {}) do
    if type(context) == "table" then list[#list + 1] = context end
  end
  parts[#parts + 1] = varint(#list)
  for _, context in ipairs(list) do encodeContext(parts, context) end
end

local function decodeContexts(text, position)
  local count
  count, position = readCount(text, position, "context")
  local contexts = {}
  for index = 1, count do
    local context
    context, position = decodeContext(text, position)
    contexts[index] = context
  end
  return contexts, position
end

local function deriveContextViews(contexts)
  local top8, other = {}, {
    key = "other", classification = "other", buffSig = "other",
    samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0,
    minBase = nil, maxBase = nil, lastSeen = 0,
  }
  for index, record in ipairs(contexts or {}) do
    if index <= 8 then
      top8[#top8 + 1] = record
    else
      other.samples = other.samples + numberOrZero(record.samples)
      other.sumBase = other.sumBase + numberOrZero(record.sumBase)
      other.sumBuffed = other.sumBuffed + numberOrZero(record.sumBuffed)
      other.sumTotal = other.sumTotal + numberOrZero(record.sumTotal)
      other.lastSeen = math.max(other.lastSeen, numberOrZero(record.lastSeen))
      if record.minBase and (not other.minBase or record.minBase < other.minBase) then
        other.minBase = record.minBase
      end
      if record.maxBase and (not other.maxBase or record.maxBase > other.maxBase) then
        other.maxBase = record.maxBase
      end
    end
  end
  local combat, xpContexts = {}, {}
  for index, record in ipairs(contexts or {}) do
    combat[index] = {
      key = record.key, playerLevel = record.playerLevel,
      mobLevel = record.mobLevel, groupSize = record.groupSize,
      mapID = record.mapID, instanceKey = record.instanceKey,
      classification = record.classification, buffSig = record.buffSig,
      samples = record.samples, healthKnown = false,
      deaths = record.deaths, lastSeen = record.lastSeen,
    }
    xpContexts[index] = {
      key = record.key, playerLevel = record.playerLevel,
      mobLevel = record.mobLevel, groupSize = record.groupSize,
      mapID = record.mapID, instanceKey = record.instanceKey,
      classification = record.classification, buffSig = record.buffSig,
      samples = record.samples, sumBase = record.sumBase,
      sumBuffed = record.sumBuffed, sumTotal = record.sumTotal,
      minBase = record.minBase, maxBase = record.maxBase,
      lastSeen = record.lastSeen,
    }
  end
  return combat, xpContexts, top8, other
end

local function deriveZoneXP(mob, kills)
  local totalKills = numberOrZero(mob.kills)
  local totalXP = numberOrZero(mob.xp)
  if totalKills <= 0 then return 0 end
  return math.floor(totalXP * kills / totalKills + 0.5)
end

local function mobContextsForMode(mob, contextMode)
  if contextMode ~= "collapsed" then return mob.contexts end
  local contexts = {}
  local top = type(mob.contextsTop8) == "table" and mob.contextsTop8 or {}
  for _, context in ipairs(top) do
    if type(context) == "table" then contexts[#contexts + 1] = context end
  end
  local other = mob.contextsOther
  if type(other) == "table" and numberOrZero(other.samples) > 0 then
    contexts[#contexts + 1] = other
  end
  if #contexts == 0 then return mob.contexts end
  return contexts
end

local function encodeMob(parts, record, contextMode)
  local mob = record.mob or {}
  writeString(parts, record.key)
  parts[#parts + 1] = varint(mob.npcID)
  writeString(parts, mob.name)
  writeString(parts, mob.classification or "normal")
  parts[#parts + 1] = varint(mob.kills)
  parts[#parts + 1] = varint(mob.xp)
  parts[#parts + 1] = varint(mob.mobLevelMin)
  parts[#parts + 1] = varint(mob.mobLevelMax)
  parts[#parts + 1] = varint(mob.mobLevelSamples)
  parts[#parts + 1] = varint(mob.firstSeen)
  parts[#parts + 1] = varint(mob.lastSeen)
  encodeLevelRecords(parts, mob.byPlayerLevel)
  parts[#parts + 1] = varint(record.kills)
  parts[#parts + 1] = varint(record.xp)
  encodeLevelRecords(parts, record.playerLevels)
  encodeContexts(parts, mobContextsForMode(mob, contextMode))
end

local function decodeMob(text, position)
  local key, npcID, name, classification
  local kills, xp, minLevel, maxLevel, levelSamples
  local firstSeen, lastSeen, zoneKills, zoneXP
  key, position = readString(text, position)
  npcID, position = readVarint(text, position)
  name, position = readString(text, position)
  classification, position = readString(text, position)
  kills, position = readVarint(text, position)
  xp, position = readVarint(text, position)
  minLevel, position = readVarint(text, position)
  maxLevel, position = readVarint(text, position)
  levelSamples, position = readVarint(text, position)
  firstSeen, position = readVarint(text, position)
  lastSeen, position = readVarint(text, position)
  local byPlayerLevel
  byPlayerLevel, position = decodeLevelRecords(text, position)
  zoneKills, position = readVarint(text, position)
  zoneXP, position = readVarint(text, position)
  local playerLevels
  playerLevels, position = decodeLevelRecords(text, position)
  local contexts
  contexts, position = decodeContexts(text, position)
  local combat, xpContexts, top8, other = deriveContextViews(contexts)
  return {
    key = key,
    npcID = npcID > 0 and npcID or nil,
    name = name ~= "" and name or nil,
    classification = classification ~= "" and classification or nil,
    kills = zoneKills,
    xp = zoneXP,
    totalKills = kills,
    totalXP = xp,
    mobLevelMin = minLevel,
    mobLevelMax = maxLevel,
    mobLevelSamples = levelSamples,
    firstSeen = firstSeen,
    lastSeen = lastSeen,
    byPlayerLevel = byPlayerLevel,
    playerLevels = playerLevels,
    contexts = contexts,
    combat = combat,
    xpContexts = xpContexts,
    contextsTop8 = top8,
    contextsOther = other,
  }, position
end

local function encodeHeatmap(parts, cellEntry)
  local cells = cellEntry and cellEntry.cells or {}
  local keys = {}
  for cell in pairs(cells) do keys[#keys + 1] = cell end
  table.sort(keys)
  parts[#parts + 1] = varint(#keys)
  for _, cell in ipairs(keys) do
    local value = cells[cell]
    local kills = type(value) == "table" and value.kills or value
    parts[#parts + 1] = varint(cell)
    parts[#parts + 1] = varint(kills)
  end
  parts[#parts + 1] = varint(cellEntry and cellEntry.total or 0)
  parts[#parts + 1] = varint(cellEntry and cellEntry.lastSeen or 0)
  parts[#parts + 1] = varint(cellEntry and cellEntry.gridSize or 0)
  writeString(parts, cellEntry and cellEntry.killsCoverage)
  writeString(parts, cellEntry and cellEntry.cellXpCoverage)
  writeString(parts, cellEntry and cellEntry.cellTimeCoverage)
end

local function decodeHeatmap(text, position)
  local cellCount
  cellCount, position = readCount(text, position, "cell")
  local cells = {}
  for _ = 1, cellCount do
    local cell, kills
    cell, position = readVarint(text, position)
    kills, position = readVarint(text, position)
    cells[cell] = { kills = kills }
  end
  local total, lastSeen, gridSize
  total, position = readVarint(text, position)
  lastSeen, position = readVarint(text, position)
  gridSize, position = readVarint(text, position)
  local killsCoverage, cellXpCoverage, cellTimeCoverage
  killsCoverage, position = readString(text, position)
  cellXpCoverage, position = readString(text, position)
  cellTimeCoverage, position = readString(text, position)
  return {
    cells = cells,
    total = total,
    lastSeen = lastSeen,
    gridSize = gridSize,
    killsCoverage = killsCoverage ~= "" and killsCoverage or nil,
    cellXpCoverage = cellXpCoverage ~= "" and cellXpCoverage or nil,
    cellTimeCoverage = cellTimeCoverage ~= "" and cellTimeCoverage or nil,
  }, position
end

local function mergeLevelMaps(primary, secondary)
  local merged = {}
  for key, value in pairs(primary or {}) do
    if type(value) == "table" then
      merged[key] = {
        kills = value.kills, xp = value.xp, samples = value.samples,
        presenceSeconds = value.presenceSeconds,
        engagedSeconds = value.engagedSeconds,
      }
    end
  end
  for key, value in pairs(secondary or {}) do
    if type(value) == "table" then
      local record = merged[key] or {}
      if numberOrZero(value.kills) > numberOrZero(record.kills) then
        record.kills = value.kills
      end
      if numberOrZero(value.xp) > numberOrZero(record.xp) then
        record.xp = value.xp
      end
      if numberOrZero(value.samples) > numberOrZero(record.samples) then
        record.samples = value.samples
      end
      if numberOrZero(value.presenceSeconds)
        > numberOrZero(record.presenceSeconds) then
        record.presenceSeconds = value.presenceSeconds
      end
      if numberOrZero(value.engagedSeconds)
        > numberOrZero(record.engagedSeconds) then
        record.engagedSeconds = value.engagedSeconds
      end
      merged[key] = record
    end
  end
  return merged
end

local function encodeZoneSummary(parts, zoneKey, zoneEntry)
  local record = zoneEntry and zoneEntry.record
  if type(record) ~= "table" then
    parts[#parts + 1] = varint(0)
    return
  end
  local kind = zoneEntry.kind or ""
  local mapID = numberOrZero(record.mapID)
  if mapID <= 0 and kind == "map" then
    mapID = numberOrZero(zoneKey:match("^map:(%d+)$"))
  end
  parts[#parts + 1] = varint(1)
  writeString(parts, kind)
  writeString(parts, record.name)
  writeString(parts, record.instanceType)
  parts[#parts + 1] = varint(record.instanceID)
  parts[#parts + 1] = varint(record.difficultyID)
  parts[#parts + 1] = varint(mapID)
  parts[#parts + 1] = varint(record.kills)
  parts[#parts + 1] = varint(record.killXP)
  parts[#parts + 1] = varint(record.questXP)
  parts[#parts + 1] = varint(record.otherXP)
  parts[#parts + 1] = varint(record.xp)
  parts[#parts + 1] = varint(record.presenceSeconds)
  parts[#parts + 1] = varint(record.engagedSeconds)
  parts[#parts + 1] = varint(record.deaths)
  parts[#parts + 1] = varint(record.sessions)
  parts[#parts + 1] = varint(record.uniqueMobs)
  parts[#parts + 1] = varint(record.firstSeen)
  parts[#parts + 1] = varint(record.lastSeen)
  parts[#parts + 1] = varint(record.killsExact == true and 1 or 0)
  writeString(parts, record.killXPCoverage)
  writeString(parts, record.questXPCoverage)
  writeString(parts, record.otherXPCoverage)
  writeString(parts, record.xpCoverage)
  writeString(parts, record.timeCoverage)
  writeString(parts, record.deathCoverage)
  writeString(parts, record.sessionCoverage)
  encodeLevelRecords(parts, mergeLevelMaps(record.playerLevels, record.levels))
end

local function decodeZoneSummary(text, position)
  local present
  present, position = readVarint(text, position)
  if present ~= 1 then return nil, position end
  local kind, name, instanceType
  local instanceID, difficultyID, mapID
  local kills, killXP, questXP, otherXP, xp
  local presenceSeconds, engagedSeconds, deaths, sessions, uniqueMobs
  local firstSeen, lastSeen, killsExact
  kind, position = readString(text, position)
  name, position = readString(text, position)
  instanceType, position = readString(text, position)
  instanceID, position = readVarint(text, position)
  difficultyID, position = readVarint(text, position)
  mapID, position = readVarint(text, position)
  kills, position = readVarint(text, position)
  killXP, position = readVarint(text, position)
  questXP, position = readVarint(text, position)
  otherXP, position = readVarint(text, position)
  xp, position = readVarint(text, position)
  presenceSeconds, position = readVarint(text, position)
  engagedSeconds, position = readVarint(text, position)
  deaths, position = readVarint(text, position)
  sessions, position = readVarint(text, position)
  uniqueMobs, position = readVarint(text, position)
  firstSeen, position = readVarint(text, position)
  lastSeen, position = readVarint(text, position)
  killsExact, position = readVarint(text, position)
  local killXPCoverage, questXPCoverage, otherXPCoverage
  local xpCoverage, timeCoverage, deathCoverage, sessionCoverage
  killXPCoverage, position = readString(text, position)
  questXPCoverage, position = readString(text, position)
  otherXPCoverage, position = readString(text, position)
  xpCoverage, position = readString(text, position)
  timeCoverage, position = readString(text, position)
  deathCoverage, position = readString(text, position)
  sessionCoverage, position = readString(text, position)
  local playerLevels
  playerLevels, position = decodeLevelRecords(text, position)
  return {
    kind = kind ~= "" and kind or nil,
    record = {
      name = name ~= "" and name or nil,
      instanceType = instanceType ~= "" and instanceType or nil,
      instanceID = instanceID > 0 and instanceID or nil,
      difficultyID = difficultyID,
      mapID = mapID,
      kills = kills,
      killXP = killXP,
      questXP = questXP,
      otherXP = otherXP,
      xp = xp,
      presenceSeconds = presenceSeconds,
      engagedSeconds = engagedSeconds,
      deaths = deaths,
      sessions = sessions,
      uniqueMobs = uniqueMobs,
      firstSeen = firstSeen,
      lastSeen = lastSeen,
      killsExact = killsExact == 1,
      killXPCoverage = killXPCoverage ~= "" and killXPCoverage or nil,
      questXPCoverage = questXPCoverage ~= "" and questXPCoverage or nil,
      otherXPCoverage = otherXPCoverage ~= "" and otherXPCoverage or nil,
      xpCoverage = xpCoverage ~= "" and xpCoverage or nil,
      timeCoverage = timeCoverage ~= "" and timeCoverage or nil,
      deathCoverage = deathCoverage ~= "" and deathCoverage or nil,
      sessionCoverage = sessionCoverage ~= "" and sessionCoverage or nil,
      playerLevels = playerLevels,
    },
  }, position
end

local function encodeZone(zoneKey, records, cellEntry, zoneEntry, contextMode)
  local parts = { varint(STORAGE_SCHEMA), varint(1) }
  writeString(parts, zoneKey)
  parts[#parts + 1] = varint(#records)
  for _, record in ipairs(records) do
    encodeMob(parts, record, contextMode)
  end
  encodeHeatmap(parts, cellEntry)
  encodeZoneSummary(parts, zoneKey, zoneEntry)
  return table.concat(parts)
end

local function buildModelMobZoneIndex(journey)
  local index = {}
  local function add(zoneKey, key, mob, zone)
    local kills = numberOrZero(zone.kills)
    if kills <= 0 then return end
    local list = index[zoneKey]
    if not list then list = {}; index[zoneKey] = list end
    list[#list + 1] = {
      key = key,
      mob = mob,
      kills = kills,
      xp = deriveZoneXP(mob, kills),
      playerLevels = type(zone.playerLevels) == "table"
        and zone.playerLevels or {},
    }
  end
  for key, mob in pairs(journey.mobs or {}) do
    if type(mob) == "table" then
      for mapKey, zone in pairs(mob.byZone or {}) do
        if type(zone) == "table" then
          add("map:" .. tostring(mapKey), key, mob, zone)
        end
      end
      for instanceKey, zone in pairs(mob.byInstance or {}) do
        if type(zone) == "table" then
          add("instance:" .. tostring(instanceKey), key, mob, zone)
        end
      end
    end
  end
  return index
end

local function buildModelHeatmapZoneIndex(journey)
  local index = {}
  for mapKey, entry in pairs(journey.heatmaps or {}) do
    if type(entry) == "table" and type(entry.cells) == "table" then
      local cells = {}
      local total = 0
      for cell, value in pairs(entry.cells) do
        local cellIndex = tonumber(cell) or 0
        local kills = type(value) == "table" and value.kills or value
        kills = numberOrZero(kills)
        if cellIndex > 0 and kills > 0 then
          cells[cellIndex] = { kills = kills }
          total = total + kills
        end
      end
      if total > 0 then
        index["map:" .. tostring(mapKey)] = {
          cells = cells,
          total = total,
          lastSeen = numberOrZero(entry.lastSeen),
          gridSize = numberOrZero(entry.gridSize),
          killsCoverage = entry.killsCoverage,
          cellXpCoverage = entry.cellXpCoverage,
          cellTimeCoverage = entry.cellTimeCoverage,
        }
      end
    end
  end
  return index
end

local function zoneHasData(record)
  if type(record) ~= "table" then return false end
  for _, field in ipairs({ "kills", "killXP", "questXP", "otherXP", "xp",
    "presenceSeconds", "engagedSeconds", "deaths", "sessions", "lastSeen" }) do
    if numberOrZero(record[field]) > 0 then return true end
  end
  return next(record.playerLevels or record.levels or {}) ~= nil
end

local function buildModelZoneIndex(journey)
  local index = {}
  for mapKey, zone in pairs(journey.zones or {}) do
    if zoneHasData(zone) then
      index["map:" .. tostring(mapKey)] = { kind = "map", record = zone }
    end
  end
  for instanceKey, instance in pairs(journey.instances or {}) do
    if zoneHasData(instance) then
      index["instance:" .. tostring(instanceKey)] = {
        kind = "instance", record = instance,
      }
    end
  end
  return index
end

local function ensureBlockModel(self, journey)
  if type(journey.mobs) ~= "table" or next(journey.mobs) == nil then
    if type(self.SyncModelMobsFromLegacy) == "function" then
      pcall(self.SyncModelMobsFromLegacy, self)
    end
  end
  if type(journey.zones) ~= "table" or next(journey.zones) == nil then
    if type(self.SyncModelZonesFromLegacy) == "function" then
      pcall(self.SyncModelZonesFromLegacy, self)
    end
  end
  if type(journey.instances) ~= "table" or next(journey.instances) == nil then
    if type(self.SyncModelInstancesFromLegacy) == "function" then
      pcall(self.SyncModelInstancesFromLegacy, self)
    end
  end
  if type(journey.heatmaps) ~= "table" or next(journey.heatmaps) == nil then
    if type(self.SyncModelHeatmapsFromLegacy) == "function" then
      pcall(self.SyncModelHeatmapsFromLegacy, self)
    end
  end
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
  if (schema ~= 1 and schema ~= 2 and schema ~= 3) or kind ~= 1 then
    error("unsupported block")
  end
  local zoneKey, count
  zoneKey, position = readString(text, position)
  count, position = readCount(text, position, "mob")
  local records = {}
  if schema >= 3 then
    for _ = 1, count do
      local record
      record, position = decodeMob(text, position)
      records[record.key] = record
    end
    local heatmap
    heatmap, position = decodeHeatmap(text, position)
    local zone
    zone, position = decodeZoneSummary(text, position)
    return schema, zoneKey, records, heatmap.cells, zone, heatmap
  end
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
    cellCount, position = readCount(text, position, "cell")
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
  return schema, zoneKey, records, cells, nil, nil
end

function XPTooltip:FlushJourneyBlocks()
  local db = self.char
  local journey = self:EnsureJourneyStorage()
  if not db or not journey then return false end
  if journey.saveBlocked then
    return false, "save_blocked"
  end
  ensureBlockModel(self, journey)
  local index = buildModelMobZoneIndex(journey)
  local heatmapIndex = buildModelHeatmapZoneIndex(journey)
  local zoneIndex = buildModelZoneIndex(journey)
  -- Rebuild the compact mob -> zone-key index from the v2 model. It is small
  -- (1-4 refs/mob) and avoids stale block references.
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
  local function addKey(zoneKey)
    if not seen[zoneKey] then seen[zoneKey] = true; keys[#keys + 1] = zoneKey end
  end
  if buildAll then
    for zoneKey in pairs(index) do addKey(zoneKey) end
    for zoneKey in pairs(heatmapIndex) do addKey(zoneKey) end
    for zoneKey in pairs(zoneIndex) do addKey(zoneKey) end
  else
    for zoneKey in pairs(dirty) do addKey(zoneKey) end
  end
  for _, zoneKey in ipairs(keys) do
    local records = index[zoneKey] or {}
    local cellEntry = heatmapIndex[zoneKey]
    local zoneEntry = zoneIndex[zoneKey]
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
    if #records > 0 or cellCount > 0 or zoneEntry then
      local now = Epoch()
      local zoneRecord = zoneEntry and zoneEntry.record
      local lastSeen = cellEntry and cellEntry.lastSeen or 0
      if zoneRecord and numberOrZero(zoneRecord.lastSeen) > lastSeen then
        lastSeen = numberOrZero(zoneRecord.lastSeen)
      end
      local tier, contextMode = "hot", "full"
      if type(self.GetBlockRetentionTier) == "function" then
        local ok, value = pcall(self.GetBlockRetentionTier, self, zoneKey, {
          lastSeen = lastSeen,
          updatedAt = now,
        })
        if ok and value then tier = value end
      end
      if tier ~= "hot" then contextMode = "collapsed" end
      local raw = encodeZone(zoneKey, records, cellEntry, zoneEntry, contextMode)
      local sum = checksum(raw)
      journey.blocks[zoneKey] = {
        data = base64Encode(raw),
        checksum = sum,
        schema = STORAGE_SCHEMA,
        count = #records,
        cellCount = cellCount,
        tier = tier,
        contextMode = contextMode,
        updatedAt = now,
      }
      journey.blockIndex[zoneKey] = {
        checksum = sum,
        count = #records,
        cellCount = cellCount,
        heatmapKills = cellEntry and cellEntry.total or 0,
        lastSeen = lastSeen,
        gridSize = cellEntry and cellEntry.gridSize or 0,
        zoneKind = zoneEntry and zoneEntry.kind or nil,
        zoneKills = zoneRecord and numberOrZero(zoneRecord.kills) or 0,
        zoneXP = zoneRecord and numberOrZero(zoneRecord.xp) or 0,
        hasZone = zoneEntry ~= nil,
        tier = tier,
        contextMode = contextMode,
        updatedAt = now,
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
  if type(self.UpdateJourneyHeatmapSummaries) == "function" then
    pcall(self.UpdateJourneyHeatmapSummaries, self)
  end
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
  local decodedOk, schema, zoneKeyOut, records, cells, zone, heatmap =
    pcall(decodeZone, raw)
  if not decodedOk or type(records) ~= "table" then return nil, "format" end
  local entry = {
    schema = schema,
    zoneKey = zoneKeyOut or key,
    records = records,
    cells = type(cells) == "table" and cells or {},
    zone = zone,
    heatmap = heatmap,
  }
  self.journeyDecodedBlocks = (self.journeyDecodedBlocks or 0) + 1
  cachePut(self, key, entry)
  return entry
end

function XPTooltip:GetJourneyBlock(zoneKey)
  local entry, err = self:GetJourneyBlockData(zoneKey)
  if not entry then return nil, err end
  return entry.records, nil, entry.cells, entry.zone
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
