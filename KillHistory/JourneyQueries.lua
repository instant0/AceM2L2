--[[---------------------------------------------------------------------------------
  KillHistory/JourneyQueries.lua
  Read-only Journey queries over the additive db.journey instrumentation.
  No storage migration, no blocks, no UI work.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util
local IsAttributableMapID = Util and Util.IsAttributableMapID

local function finite(value)
  local number = tonumber(value)
  if not number or number ~= number or number == math.huge or number == -math.huge then
    return 0
  end
  return number
end

local function zoneRecord(self, zoneKey)
  local db = self.char
  local journey = db and db.journey
  local zones = journey and journey.zones
  local record = zones and zones[tostring(zoneKey or "")]
  return type(record) == "table" and record or nil
end

local function levelRecord(zone, level)
  local levels = zone and zone.levels
  local record = levels and levels[tostring(level or "")]
  return type(record) == "table" and record or nil
end

function XPTooltip:GetJourneyZoneStats(zoneKey)
  local record = zoneRecord(self, zoneKey)
  if not record then
    return nil
  end
  return {
    zoneKey = tostring(zoneKey),
    kills = finite(record.kills),
    killXP = finite(record.killXP),
    questXP = finite(record.questXP),
    otherXP = finite(record.otherXP),
    xp = finite(record.xp),
    presenceSeconds = finite(record.presenceSeconds),
    engagedSeconds = finite(record.engagedSeconds),
    deaths = finite(record.deaths),
    sessions = finite(record.sessions),
  }
end

function XPTooltip:GetJourneyLevelStats(level)
  local db = self.char
  local journey = db and db.journey
  local record = journey and journey.levels and journey.levels[tostring(level or "")]
  if type(record) ~= "table" then
    return nil
  end
  return {
    level = tonumber(level) or 0,
    kills = finite(record.kills),
    killXP = finite(record.killXP),
    questXP = finite(record.questXP),
    otherXP = finite(record.otherXP),
    xp = finite(record.xp),
    presenceSeconds = finite(record.presenceSeconds),
    engagedSeconds = finite(record.engagedSeconds),
  }
end

-- Area rows read the v2 zone and instance records. They never read legacy
-- area/instance aggregates.
function XPTooltip:GetAreaRows()
  local db = self.char
  if type(db) ~= "table" then
    return {}
  end
  local journey = db.journey or {}
  local rows = {}
  for mapKey, zone in pairs(journey.zones or {}) do
    local value = type(zone) == "table" and finite(zone.kills) or 0
    if value > 0
      and (not IsAttributableMapID or IsAttributableMapID(mapKey)) then
      rows[#rows + 1] = {
        kind = "area",
        key = tostring(mapKey),
        mapID = mapKey,
        label = self:GetMapName(mapKey),
        kills = value,
      }
    end
  end
  for instanceKey, instance in pairs(journey.instances or {}) do
    if type(instance) == "table" then
      local value = finite(instance.kills)
      if value > 0 then
        rows[#rows + 1] = {
          kind = "instance",
          key = tostring(instanceKey),
          instanceKey = instanceKey,
          label = instance.name or "Unknown instance",
          kills = value,
        }
      end
    end
  end
  return rows
end

-- Level rows read v2 level records only.
function XPTooltip:GetLevelRows()
  local db = self.char
  if type(db) ~= "table" then
    return {}
  end
  local journey = db.journey or {}
  local rows = {}
  for levelKey, record in pairs(journey.levels or {}) do
    local level = tonumber(levelKey) or 0
    local value = type(record) == "table" and finite(record.kills) or 0
    if level > 0 and value > 0 then
      rows[#rows + 1] = {
        kind = "level",
        key = tostring(levelKey),
        level = level,
        label = "Level " .. tostring(level),
        kills = value,
      }
    end
  end
  return rows
end

function XPTooltip:GetTopAreaSummary()
  local topKey, topKills, topLabel
  local rows = self:GetAreaRows()
  for index = 1, #rows do
    local row = rows[index]
    if row.kind == "area"
      and (not topKills or row.kills > topKills
        or (row.kills == topKills and tostring(row.key) < tostring(topKey))) then
      topKey, topKills, topLabel = row.key, row.kills, row.label
    end
  end
  if topKills then
    return topKills, topKey, topLabel
  end
  return nil
end

function XPTooltip:GetLevelSummary()
  local minLevel, maxLevel, topLevel, topKills
  local function add(level, value)
    if level and value > 0 then
      if not minLevel or level < minLevel then minLevel = level end
      if not maxLevel or level > maxLevel then maxLevel = level end
      if not topKills or value > topKills
        or (value == topKills and level < topLevel) then
        topKills, topLevel = value, level
      end
    end
  end
  local rows = self:GetLevelRows()
  for index = 1, #rows do
    local row = rows[index]
    add(row.level, row.kills)
  end
  return minLevel, maxLevel, topLevel, topKills
end

function XPTooltip:GetAreaKillCount(areaKey)
  local key = tostring(areaKey or "")
  local rows = self:GetAreaRows()
  for index = 1, #rows do
    local row = rows[index]
    if row.kind == "area" and row.key == key then return row.kills end
  end
  return 0
end

function XPTooltip:GetLevelKillCount(levelKey)
  local key = tostring(levelKey or "")
  local rows = self:GetLevelRows()
  for index = 1, #rows do
    local row = rows[index]
    if row.key == key or tostring(row.level) == key then return row.kills end
  end
  return 0
end

-- mode = "total" (default) or "kill".
function XPTooltip:GetBestZonesForLevel(level, mode)
  local db = self.char
  local journey = db and db.journey
  local zones = journey and journey.zones or {}
  local rows = {}
  for zoneKey, zone in pairs(zones) do
    local record = levelRecord(zone, level)
    if record then
      local engaged = finite(record.engagedSeconds)
      local presence = finite(record.presenceSeconds)
      local seconds = engaged > 0 and engaged or presence
      if seconds > 0 then
        local xp = mode == "kill" and finite(record.killXP) or finite(record.xp)
        local killXP = finite(record.killXP)
        local hours = seconds / 3600
        local confidence = "low"
        if seconds >= 1800 then
          confidence = "medium"
        end
        if seconds >= 7200 then
          confidence = "high"
        end
        rows[#rows + 1] = {
          zoneKey = tostring(zoneKey),
          level = tonumber(level) or 0,
          mode = mode or "total",
          xp = xp,
          killXP = killXP,
          seconds = seconds,
          xpPerHour = xp / hours,
          killXPPerHour = killXP / hours,
          confidence = confidence,
        }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.xpPerHour == b.xpPerHour then
      return a.zoneKey < b.zoneKey
    end
    return a.xpPerHour > b.xpPerHour
  end)
  return rows
end

local function TopHeatmapCells(cells, count)
  local list = {}
  local total = 0
  for cell, value in pairs(cells or {}) do
    local kills = type(value) == "table" and finite(value.kills) or finite(value)
    if kills > 0 then
      list[#list + 1] = { cell = tonumber(cell) or 0, kills = kills,
        xp = type(value) == "table" and finite(value.xp) or 0,
        presenceSeconds = type(value) == "table" and finite(value.presenceSeconds) or 0,
        engagedSeconds = type(value) == "table" and finite(value.engagedSeconds) or 0 }
      total = total + kills
    end
  end
  table.sort(list, function(a, b)
    if a.kills == b.kills then return a.cell < b.cell end
    return a.kills > b.kills
  end)
  local result = {}
  local limit = math.max(1, math.min(tonumber(count) or 10, #list))
  for index = 1, limit do
    local row = list[index]
    row.share = total > 0 and row.kills / total or 0
    result[index] = row
  end
  return result
end

function XPTooltip:GetHeatmapTopCells(mapID, count)
  local heatmap = type(self.GetModelHeatmap) == "function"
    and self:GetModelHeatmap(mapID) or nil
  if type(heatmap) == "table" and type(heatmap.cells) == "table" then
    return TopHeatmapCells(heatmap.cells, count)
  end
  return {}
end

function XPTooltip:GetMobJourneySummary(mobKey)
  local mob = type(self.GetModelMob) == "function"
    and self:GetModelMob(mobKey) or nil
  if type(mob) ~= "table" then return nil end
  local zones = {}
  for mapKey in pairs(mob.byZone or {}) do
    zones[#zones + 1] = "map:" .. tostring(mapKey)
  end
  for instanceKey in pairs(mob.byInstance or {}) do
    zones[#zones + 1] = "instance:" .. tostring(instanceKey)
  end
  table.sort(zones)
  return {
    key = tostring(mobKey),
    npcID = mob.npcID,
    name = mob.name,
    classification = mob.classification,
    kills = finite(mob.kills),
    xp = finite(mob.xp),
    zones = zones,
    lastSeen = finite(mob.lastSeen),
    source = "v2",
  }
end

function XPTooltip:GetQuestAnchors(mapID, count)
  local db = self.char
  local journey = db and db.journey
  local anchors = journey and journey.questAnchors
  if type(anchors) ~= "table" then return {} end
  local wanted = mapID and tostring(mapID) or nil
  local rows = {}
  for index = 1, #anchors do
    local anchor = anchors[index]
    if type(anchor) == "table" and (not wanted or tostring(anchor.mapID) == wanted) then
      local questID = tonumber(anchor.questID)
      local key = questID and ("quest:" .. tostring(questID)) or "quest:unknown"
      local quest = questID and type(self.GetModelQuest) == "function"
        and self:GetModelQuest(questID) or nil
      local name = quest and Util.SafeString(quest.name) or nil
      if not name or name == "" then
        name = questID and ("Quest " .. tostring(questID)) or "Unknown quest"
      end
      rows[#rows + 1] = {
        questID = questID,
        key = key,
        name = name,
        mapID = tonumber(anchor.mapID) or 0,
        x = tonumber(anchor.x),
        y = tonumber(anchor.y),
        at = finite(anchor.at),
        playerLevel = finite(anchor.playerLevel),
        xp = finite(anchor.xp),
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.at ~= b.at then return a.at > b.at end
    if (a.questID or 0) ~= (b.questID or 0) then
      return (a.questID or 0) > (b.questID or 0)
    end
    return a.name < b.name
  end)
  local limit = math.max(1, math.min(tonumber(count) or 10, #rows))
  local result = {}
  for index = 1, limit do result[index] = rows[index] end
  return result
end

function XPTooltip:GetQuestAnchor(questID)
  local key = questID and ("quest:" .. tostring(questID)) or "quest:unknown"
  local quest = type(self.GetModelQuest) == "function"
    and self:GetModelQuest(questID) or nil
  if type(quest) ~= "table" then return nil end
  return {
    key = key,
    id = quest.id,
    name = quest.name,
    count = finite(quest.count),
    xp = finite(quest.xp),
    lastTurnInAt = finite(quest.lastTurnInAt or quest.lastSeen),
    mapID = finite(quest.mapID),
    playerLevel = finite(quest.playerLevel),
  }
end

function XPTooltip:GetJourneyTimeSummary()
  local db = self.char
  local journey = db and db.journey
  if type(journey) ~= "table" or type(journey.time) ~= "table" then
    return nil
  end
  return {
    zone = journey.time.zone,
    level = journey.time.level,
    lastEventAt = finite(journey.time.lastEventAt),
    lastKillAt = finite(journey.time.lastKillAt),
    cap = finite(journey.time.cap),
  }
end
