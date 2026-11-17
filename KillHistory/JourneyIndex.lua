--[[---------------------------------------------------------------------------------
  KillHistory/JourneyIndex.lua
  Compact global mob index for list/overview queries. Built lazily from the
  current authoritative mob data; invalidated on kill/prune changes.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory

function XPTooltip:InvalidateJourneyMobIndex()
  self.journeyMobIndexDirty = true
end

-- List/Overview may be rolled back to their legacy scans by setting
-- char.journey.indexViews = false. Missing data keeps the index enabled.
function XPTooltip:UseJourneyIndexViews()
  local db = self.char
  if type(db) ~= "table" then
    return false
  end
  local journey = db.journey
  if type(journey) ~= "table" then
    return true
  end
  return journey.indexViews ~= false
end

local function makeRow(key, mob)
  return {
    key = key,
    mob = mob,
    npcID = mob.npcID,
    name = mob.name or "Unknown",
    classification = mob.classification or "normal",
    kills = tonumber(mob.kills) or 0,
    sessionKills = tonumber(mob.sessionKills) or 0,
    killsAtLevel = mob.killsAtLevel,
    xp = mob.xp,
    lastSeen = tonumber(mob.lastSeen) or 0,
    killsByMap = mob.killsByMap,
    killsByInstance = mob.killsByInstance,
  }
end

function XPTooltip:EnsureJourneyMobIndex()
  local db = self.char
  if type(db) ~= "table" then
    return { rows = {}, byKey = {} }
  end
  if self.journeyMobIndex and not self.journeyMobIndexDirty then
    return self.journeyMobIndex
  end
  local allRows, rows, byKey = {}, {}, {}
  for key, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      local row = makeRow(key, mob)
      allRows[#allRows + 1] = row
      if row.kills > 0 then
        rows[#rows + 1] = row
        byKey[key] = row
      end
    end
  end
  self.journeyMobIndex = { rows = rows, allRows = allRows, byKey = byKey }
  self.journeyMobIndexDirty = false
  self.journeyMobIndexBuilds = (tonumber(self.journeyMobIndexBuilds) or 0) + 1
  return self.journeyMobIndex
end

function XPTooltip:GetJourneyMobRows()
  return self:EnsureJourneyMobIndex().rows
end

function XPTooltip:GetJourneyAllMobRows()
  local index = self:EnsureJourneyMobIndex()
  return index.allRows or index.rows
end

function XPTooltip:GetJourneyMobRow(mobKey)
  local key = tostring(mobKey or "")
  return self:EnsureJourneyMobIndex().byKey[key]
end

function XPTooltip:GetJourneyMobCount()
  return #self:EnsureJourneyMobIndex().rows
end

function XPTooltip:GetJourneyTopMobs(limit)
  local rows = self:EnsureJourneyMobIndex().rows
  local sorted = {}
  for index = 1, #rows do sorted[index] = rows[index] end
  table.sort(sorted, function(a, b)
    if a.kills == b.kills then
      return tostring(a.name) < tostring(b.name)
    end
    return a.kills > b.kills
  end)
  local result = {}
  local count = math.max(0, math.min(tonumber(limit) or 10, #sorted))
  for index = 1, count do result[index] = sorted[index] end
  return result
end

function XPTooltip:GetJourneyMobsForFilter(filter, searchText)
  local rows = self:EnsureJourneyMobIndex().rows
  local playerLevel = self:GetPlayerLevel()
  local search = searchText and searchText:lower() or ""
  local result = {}
  for index = 1, #rows do
    local row = rows[index]
    local include = true
    if filter == "level" then
      include = playerLevel and type(row.killsAtLevel) == "table"
        and (tonumber(row.killsAtLevel[tostring(playerLevel)]) or 0) > 0
    elseif filter == "session" then
      include = row.sessionKills > 0
    elseif filter == "elite" then
      include = row.classification == "elite"
        or row.classification == "rareelite"
        or row.classification == "worldboss"
    end
    if include and (search == "" or tostring(row.name):lower():find(search, 1, true)) then
      result[#result + 1] = row
    end
  end
  return result
end
