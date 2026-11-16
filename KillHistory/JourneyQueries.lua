--[[---------------------------------------------------------------------------------
  KillHistory/JourneyQueries.lua
  Read-only Journey queries over the additive db.journey instrumentation.
  No storage migration, no blocks, no UI work.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory

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
  local db = self.char or {}
  local legacyKills = tonumber((db.areas or {})[tostring(zoneKey)]) or 0
  return {
    zoneKey = tostring(zoneKey),
    kills = finite(record.kills) + legacyKills,
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

function XPTooltip:GetHeatmapTopCells(mapID, count)
  local db = self.char
  local heatmaps = db and db.heatmaps
  local heatmap = heatmaps and heatmaps[tostring(mapID)]
  if type(heatmap) ~= "table" or type(heatmap.cells) ~= "table" then
    return {}
  end
  local list = {}
  local total = 0
  for cell, value in pairs(heatmap.cells) do
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

function XPTooltip:GetMobJourneySummary(mobKey)
  local db = self.char
  local mob = db and db.mobs and db.mobs[mobKey]
  if type(mob) == "table" then
    local zones = {}
    for mapKey in pairs(mob.killsByMap or {}) do zones[#zones + 1] = "map:" .. tostring(mapKey) end
    for instanceKey in pairs(mob.killsByInstance or {}) do zones[#zones + 1] = "instance:" .. tostring(instanceKey) end
    return {
      key = tostring(mobKey),
      npcID = mob.npcID,
      name = mob.name,
      classification = mob.classification,
      kills = finite(mob.kills),
      xp = finite(mob.totalXP),
      zones = zones,
      lastSeen = finite(mob.lastSeen),
    }
  end
  if self.GetJourneyMob then
    local blockMob = self:GetJourneyMob(mobKey)
    if blockMob then
      return {
        key = tostring(mobKey),
        npcID = blockMob.npcID,
        name = blockMob.name,
        classification = blockMob.classification,
        kills = finite(blockMob.kills),
        xp = finite(blockMob.xp),
        zones = self.GetJourneyMobZones and self:GetJourneyMobZones(mobKey) or {},
        lastSeen = 0,
        source = "block",
      }
    end
  end
  return nil
end

function XPTooltip:GetQuestAnchor(questID)
  local db = self.char
  local key = questID and ("quest:" .. tostring(questID)) or "quest:unknown"
  local quest = db and db.quests and db.quests[key]
  if type(quest) ~= "table" then
    return nil
  end
  return {
    key = key,
    id = quest.id,
    name = quest.name,
    count = finite(quest.count),
    xp = finite(quest.totalXP),
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
