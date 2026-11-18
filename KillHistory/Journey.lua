--[[---------------------------------------------------------------------------------
  KillHistory/Journey.lua
  Event-driven Journey instrumentation: presence/engaged time, quest anchors,
  and XP splits. No timer, no OnUpdate, no per-kill log.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

-- Data-model revision. Storage schema 2 is authoritative; keep this aligned.
local JOURNEY_SCHEMA = 2
local MAX_QUEST_ANCHORS = 5000
local ENGAGED_GAP_CAP = 60

local function Epoch()
  return Util.Epoch and Util.Epoch() or 0
end

local function zoneKeyFor(self, mapID)
  local id = tonumber(mapID) or 0
  if id <= 0 then
    id = tonumber(self:GetMapID()) or 0
  end
  return id > 0 and tostring(id) or "0"
end

local function playerLevelFor(self, level)
  local value = tonumber(level)
  if value and value > 0 then
    return value
  end
  return tonumber(self:GetPlayerLevel()) or 0
end

function XPTooltip:EnsureJourney()
  local db = self.char
  if type(db) ~= "table" then
    return nil
  end
  local journey = type(db.journey) == "table" and db.journey or {}
  journey.schema = JOURNEY_SCHEMA
  journey.projectID = self:GetProjectID()
  journey.mode = journey.mode or "leveling"
  journey.zones = type(journey.zones) == "table" and journey.zones or {}
  journey.levels = type(journey.levels) == "table" and journey.levels or {}
  local anchors = type(journey.questAnchors) == "table" and journey.questAnchors or {}
  if #anchors > MAX_QUEST_ANCHORS then
    table.sort(anchors, function(a, b)
      local aAt = type(a) == "table" and tonumber(a.at) or 0
      local bAt = type(b) == "table" and tonumber(b.at) or 0
      return aAt < bAt
    end)
    local trimmed = {}
    for index = #anchors - MAX_QUEST_ANCHORS + 1, #anchors do
      trimmed[#trimmed + 1] = anchors[index]
    end
    anchors = trimmed
  end
  journey.questAnchors = anchors
  local time = type(journey.time) == "table" and journey.time or {}
  time.cap = ENGAGED_GAP_CAP
  time.zone = time.zone
  time.level = time.level
  time.lastEventAt = tonumber(time.lastEventAt) or 0
  time.lastKillAt = tonumber(time.lastKillAt) or 0
  journey.time = time
  db.journey = journey
  return journey
end

local function ensureZone(journey, key)
  local zone = journey.zones[key]
  if type(zone) ~= "table" then
    zone = {
      kills = 0, killXP = 0, questXP = 0, otherXP = 0, xp = 0,
      presenceSeconds = 0, engagedSeconds = 0,
      deaths = 0, sessions = 0, levels = {},
    }
    journey.zones[key] = zone
  end
  if type(zone.levels) ~= "table" then zone.levels = {} end
  return zone
end

local function ensureZoneLevel(zone, level)
  local key = tostring(level or 0)
  local record = zone.levels[key]
  if type(record) ~= "table" then
    record = { kills = 0, killXP = 0, questXP = 0, otherXP = 0, xp = 0,
      presenceSeconds = 0, engagedSeconds = 0, deaths = 0 }
    zone.levels[key] = record
  end
  return record
end

local function ensureLevel(journey, level)
  local key = tostring(level or 0)
  local record = journey.levels[key]
  if type(record) ~= "table" then
    record = {
      kills = 0, killXP = 0, questXP = 0, otherXP = 0, xp = 0,
      presenceSeconds = 0, engagedSeconds = 0, deaths = 0,
    }
    journey.levels[key] = record
  end
  return record
end

local function addPresence(journey, seconds)
  if seconds <= 0 then
    return
  end
  local time = journey.time
  local zone = ensureZone(journey, time.zone or "0")
  local level = ensureLevel(journey, time.level or 0)
  zone.presenceSeconds = zone.presenceSeconds + seconds
  level.presenceSeconds = level.presenceSeconds + seconds
  local zoneLevel = ensureZoneLevel(zone, time.level or 0)
  zoneLevel.presenceSeconds = zoneLevel.presenceSeconds + seconds
end

local function addEngaged(journey, seconds)
  if seconds <= 0 then
    return
  end
  local time = journey.time
  local capped = math.min(seconds, time.cap or ENGAGED_GAP_CAP)
  local zone = ensureZone(journey, time.zone or "0")
  local level = ensureLevel(journey, time.level or 0)
  zone.engagedSeconds = zone.engagedSeconds + capped
  level.engagedSeconds = level.engagedSeconds + capped
  local zoneLevel = ensureZoneLevel(zone, time.level or 0)
  zoneLevel.engagedSeconds = zoneLevel.engagedSeconds + capped
end

local function closePresence(journey, now)
  local time = journey.time
  if time.lastEventAt and time.lastEventAt > 0 and now >= time.lastEventAt then
    addPresence(journey, now - time.lastEventAt)
  end
  time.lastEventAt = now
end

local function switchContext(journey, now, zone, level)
  local time = journey.time
  local changed = time.zone ~= zone or time.level ~= level
  closePresence(journey, now)
  if changed then
    time.zone = zone
    time.level = level
    time.lastKillAt = now
  end
end

local function addXP(journey, zoneKey, level, field, amount)
  local value = tonumber(amount) or 0
  if value <= 0 then
    return
  end
  local zone = ensureZone(journey, zoneKey)
  local levelRecord = ensureLevel(journey, level)
  zone[field] = (zone[field] or 0) + value
  zone.xp = (zone.xp or 0) + value
  levelRecord[field] = (levelRecord[field] or 0) + value
  levelRecord.xp = (levelRecord.xp or 0) + value
  local zoneLevel = ensureZoneLevel(zone, level)
  zoneLevel[field] = (zoneLevel[field] or 0) + value
  zoneLevel.xp = (zoneLevel.xp or 0) + value
end

local function addQuestAnchor(journey, anchor)
  local anchors = journey.questAnchors
  anchors[#anchors + 1] = anchor
  while #anchors > MAX_QUEST_ANCHORS do
    table.remove(anchors, 1)
  end
end

local function addEvent(journey, key, count)
  local zone = ensureZone(journey, journey.time.zone or "0")
  local level = ensureLevel(journey, journey.time.level or 0)
  zone[key] = (zone[key] or 0) + (count or 1)
  level[key] = (level[key] or 0) + (count or 1)
  local zoneLevel = ensureZoneLevel(zone, journey.time.level or 0)
  zoneLevel[key] = (zoneLevel[key] or 0) + (count or 1)
end

function XPTooltip:OnJourneyEnterWorld()
  if not self:IsActive() then
    return
  end
  local journey = self:EnsureJourney()
  if not journey then
    return
  end
  local now = Epoch()
  journey.time.zone = zoneKeyFor(self, 0)
  journey.time.level = playerLevelFor(self, 0)
  journey.time.lastEventAt = now
  journey.time.lastKillAt = now
end

function XPTooltip:OnJourneyZoneChanged()
  if not self:IsActive() then
    return
  end
  local journey = self:EnsureJourney()
  if not journey then
    return
  end
  local now = Epoch()
  switchContext(journey, now, zoneKeyFor(self, 0), journey.time.level)
  journey.time.lastEventAt = now
end

function XPTooltip:OnJourneyLevelUp(level)
  if not self:IsActive() then
    return
  end
  local journey = self:EnsureJourney()
  if not journey then
    return
  end
  local now = Epoch()
  switchContext(journey, now, journey.time.zone or zoneKeyFor(self, 0),
    playerLevelFor(self, level))
  journey.time.lastEventAt = now
end

function XPTooltip:OnJourneyKill(info, totalXP)
  if not self:IsActive() then
    return
  end
  local journey = self:EnsureJourney()
  if not journey then
    return
  end
  local now = Epoch()
  local zone = zoneKeyFor(self, info and info.mapID or 0)
  local level = playerLevelFor(self, info and info.playerLevel or 0)
  local changed = journey.time.zone ~= zone or journey.time.level ~= level
  switchContext(journey, now, zone, level)
  if not changed and journey.time.lastKillAt and journey.time.lastKillAt > 0 then
    addEngaged(journey, now - journey.time.lastKillAt)
  end
  journey.time.lastKillAt = now
  journey.time.lastEventAt = now
  addEvent(journey, "kills", 1)
  addXP(journey, zone, level, "killXP", totalXP)
  if self.MarkJourneyDirty then
    self:MarkJourneyDirty(info)
  end
  if self.InvalidateJourneyMobIndex then
    self:InvalidateJourneyMobIndex()
  end
end

function XPTooltip:OnJourneyKillXP(totalXP, info)
  if not self:IsActive() then
    return
  end
  local journey = self:EnsureJourney()
  if not journey then
    return
  end
  addXP(journey, zoneKeyFor(self, info and info.mapID or 0),
    playerLevelFor(self, info and info.playerLevel or 0), "killXP", totalXP)
end

function XPTooltip:OnJourneyQuestTurnIn(questID, questName, xpReward)
  if not self:IsActive() then
    return
  end
  local journey = self:EnsureJourney()
  if not journey then
    return
  end
  local now = Epoch()
  local mapID = tonumber(self:GetMapID()) or 0
  local x, y
  if type(self.GetPlayerMapPosition) == "function" then
    local ok, positionMapID, px, py = pcall(self.GetPlayerMapPosition, self)
    if ok and tonumber(positionMapID) then
      mapID = tonumber(positionMapID) or mapID
      x, y = tonumber(px), tonumber(py)
    end
  end
  local level = playerLevelFor(self, 0)
  local zone = zoneKeyFor(self, mapID)
  switchContext(journey, now, zone, level)
  journey.time.lastKillAt = now
  journey.time.lastEventAt = now
  addXP(journey, zone, level, "questXP", xpReward)
  addEvent(journey, "quests", 1)
  local anchor = {
    questID = tonumber(questID),
    mapID = mapID,
    at = now,
    playerLevel = level,
    xp = tonumber(xpReward) or 0,
  }
  if x and y then
    anchor.x = x
    anchor.y = y
  end
  addQuestAnchor(journey, anchor)
  if self.MarkJourneyDirty then
    self:MarkJourneyDirty({ mapID = mapID })
  end
  if self.InvalidateJourneyMobIndex then
    self:InvalidateJourneyMobIndex()
  end
  local key = questID and ("quest:" .. tostring(questID)) or "quest:unknown"
  local quest = self.char and self.char.quests and self.char.quests[key]
  if type(quest) == "table" then
    quest.lastTurnInAt = now
    quest.mapID = mapID
    quest.playerLevel = level
  end
end

function XPTooltip:ResetJourneyData()
  if self.char then
    self.char.journey = nil
  end
  if self.ClearJourneyBlockCache then
    self:ClearJourneyBlockCache()
  end
  self.journeyMobIndex = nil
  if self.InvalidateJourneyMobIndex then
    self:InvalidateJourneyMobIndex()
  end
end

function XPTooltip:OnJourneyLogout()
  if not self:IsActive() then
    return
  end
  local journey = self:EnsureJourney()
  if not journey then
    return
  end
  local now = Epoch()
  closePresence(journey, now)
  if journey.time.lastKillAt and journey.time.lastKillAt > 0 then
    addEngaged(journey, now - journey.time.lastKillAt)
  end
  journey.time.lastEventAt = 0
  journey.time.lastKillAt = 0
  if self.FlushJourneyBlocks then
    self:FlushJourneyBlocks()
  end
end
