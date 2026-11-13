--[[---------------------------------------------------------------------------------
  KillHistory/World.lua
  Map position capture, death locations, respawn intervals, and grinding spots.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local min, max, floor = math.min, math.max, math.floor
local SafeCall = Util.SafeCall
local SafeNumber = Util.SafeNumber
local SafeString = Util.SafeString
local IsSecret = Util.IsSecret
local Lower = Util.Lower
local Trim = Util.Trim
local Now = Util.Now
local Epoch = Util.Epoch
local FormatNumber = Util.FormatNumber
local FormatAgo = Util.FormatAgo
local FormatDuration = Util.FormatDuration

local MAX_DEATHS = 100
local MAX_RESPAWN_NPCS = 300
local MAX_RESPAWN_SAMPLES = 20
local MIN_RESPAWN_SAMPLES = 3
local RESPAWN_MIN_SECONDS = 5
local RESPAWN_MAX_SECONDS = 3600
local MIN_SPOT_SAMPLES = 5
local MIN_SPOT_SECONDS = 120
local MAX_SPOT_RESULTS = 5
local SPOT_MAX_AGE = 3600

XPTooltip.MAX_DEATHS = MAX_DEATHS
XPTooltip.MAX_RESPAWN_NPCS = MAX_RESPAWN_NPCS
XPTooltip.MAX_RESPAWN_SAMPLES = MAX_RESPAWN_SAMPLES
XPTooltip.MIN_RESPAWN_SAMPLES = MIN_RESPAWN_SAMPLES
XPTooltip.RESPAWN_MIN_SECONDS = RESPAWN_MIN_SECONDS
XPTooltip.RESPAWN_MAX_SECONDS = RESPAWN_MAX_SECONDS
XPTooltip.MIN_SPOT_SAMPLES = MIN_SPOT_SAMPLES
XPTooltip.MIN_SPOT_SECONDS = MIN_SPOT_SECONDS
XPTooltip.MAX_SPOT_RESULTS = MAX_SPOT_RESULTS
XPTooltip.SPOT_MAX_AGE = SPOT_MAX_AGE

--[[--------------------------------------------------------------------------------
  Validation helpers
------------------------------------------------------------------------------------]]

local function BoxedNumber(value)
  local number = SafeNumber(value)
  if number == nil or number ~= number then
    return nil
  end
  return number
end

local function PositiveNumber(value)
  local number = BoxedNumber(value)
  if number == nil or number <= 0 then
    return nil
  end
  return number
end

local function NonNegativeNumber(value)
  local number = BoxedNumber(value)
  if number == nil or number < 0 then
    return nil
  end
  return number
end

local function UnitCoordinate(value)
  local number = BoxedNumber(value)
  if number == nil or number < 0 or number > 1 then
    return nil
  end
  return number
end

local function ReadPosition(raw)
  if raw == nil or IsSecret(raw) then
    return nil
  end

  local getXY
  local ok = pcall(function()
    getXY = raw.GetXY
  end)
  if ok and type(getXY) == "function" then
    local x, y = SafeCall(getXY, raw)
    x, y = UnitCoordinate(x), UnitCoordinate(y)
    if x and y then
      return x, y
    end
  end

  local x, y
  ok = pcall(function()
    x, y = raw.x, raw.y
  end)
  if not ok then
    return nil
  end
  x, y = UnitCoordinate(x), UnitCoordinate(y)
  if x and y then
    return x, y
  end
  return nil
end

--[[--------------------------------------------------------------------------------
  Map position
------------------------------------------------------------------------------------]]

function XPTooltip:HasMapPositionAPI()
  if C_Map and type(C_Map.GetPlayerMapPosition) == "function" then
    return true
  end
  return type(GetPlayerMapPosition) == "function"
end

function XPTooltip:GetPlayerMapPosition()
  if not self:HasMapPositionAPI() then
    return nil
  end
  local mapID = PositiveNumber(self:GetMapID())
  if not mapID then
    return nil
  end

  if C_Map and type(C_Map.GetPlayerMapPosition) == "function" then
    local position = SafeCall(C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y = ReadPosition(position)
    if x and y then
      return mapID, x, y
    end
  end

  if type(GetPlayerMapPosition) == "function" then
    local x, y = SafeCall(GetPlayerMapPosition, "player")
    x, y = UnitCoordinate(x), UnitCoordinate(y)
    -- Legacy clients return 0,0 when no position is known.
    if x and y and not (x == 0 and y == 0) then
      return mapID, x, y
    end
  end
  return nil
end

--[[--------------------------------------------------------------------------------
  Death locations
------------------------------------------------------------------------------------]]

local function NormalizeDeaths(list)
  local normalized = {}
  if type(list) ~= "table" then
    return normalized
  end
  for _, entry in ipairs(list) do
    if type(entry) == "table" then
      local at = PositiveNumber(entry.at)
      local mapID = PositiveNumber(entry.mapID)
      local x = UnitCoordinate(entry.x)
      local y = UnitCoordinate(entry.y)
      if at and mapID and x and y then
        normalized[#normalized + 1] = {
          at = at,
          mapID = mapID,
          x = x,
          y = y,
        }
      end
    end
  end
  table.sort(normalized, function(a, b)
    return a.at < b.at
  end)
  if #normalized > MAX_DEATHS then
    local newest = {}
    for index = #normalized - MAX_DEATHS + 1, #normalized do
      newest[#newest + 1] = normalized[index]
    end
    normalized = newest
  end
  return normalized
end

function XPTooltip:NormalizeDeaths(list)
  local db = self.char
  local source = list
  if source == nil then
    source = type(db) == "table" and db.deaths or {}
  end
  local normalized = NormalizeDeaths(source)
  if type(db) == "table" then
    db.deaths = normalized
  end
  return normalized
end

function XPTooltip:RecordDeath(mapID, x, y, at)
  if not self:Supports("hasMapPosition") then
    return false
  end
  local db = self.char
  if type(db) ~= "table" then
    return false
  end

  local id = PositiveNumber(mapID)
  local px = UnitCoordinate(x)
  local py = UnitCoordinate(y)
  local when
  if at == nil then
    when = PositiveNumber(Epoch())
  else
    when = PositiveNumber(at)
  end
  if not id or not px or not py or not when then
    return false
  end

  local deaths = self:NormalizeDeaths()
  local last = deaths[#deaths]
  if type(last) == "table" and math.abs(when - (tonumber(last.at) or 0)) < 5 then
    return false
  end

  deaths[#deaths + 1] = {
    at = when,
    mapID = id,
    x = px,
    y = py,
  }
  db.deaths = NormalizeDeaths(deaths)
  return true
end

function XPTooltip:HandlePlayerDeath()
  if not self:Supports("hasMapPosition") then
    return false
  end
  local mapID, x, y = self:GetPlayerMapPosition()
  if not mapID or not x or not y then
    return false
  end
  return self:RecordDeath(mapID, x, y, Epoch())
end

function XPTooltip:PrintDeaths(rest)
  if not self:Supports("hasMapPosition") or not self:HasMapPositionAPI() then
    AceM2L2:SafePrint("Kill Story: death locations are unavailable on this client.")
    return
  end
  local db = self.char
  if type(db) ~= "table" then
    return
  end

  local list = self:NormalizeDeaths()
  if #list == 0 then
    AceM2L2:SafePrint("Kill Story: no deaths recorded yet.")
    return
  end

  local requested = tonumber(rest) or 10
  local count = max(1, min(50, floor(requested)))
  local shown = min(count, #list)
  AceM2L2:SafePrint("Kill Story deaths (last " .. shown .. "):")
  for index = #list, #list - shown + 1, -1 do
    local entry = list[index]
    AceM2L2:SafePrint(string.format(
      "  %s  %s (%.1f, %.1f)",
      FormatAgo(entry.at),
      self:GetMapName(entry.mapID),
      entry.x * 100,
      entry.y * 100
    ))
  end
end

--[[--------------------------------------------------------------------------------
  Respawn intervals
------------------------------------------------------------------------------------]]

local function NormalizeRespawns(map)
  local normalized = {}
  if type(map) ~= "table" then
    return normalized
  end

  for key, value in pairs(map) do
    local npcID = tonumber(key)
    if npcID and npcID > 0 and type(value) == "table" then
      local intervals = {}
      local source = type(value.intervals) == "table" and value.intervals or {}
      for _, raw in ipairs(source) do
        local seconds = BoxedNumber(raw)
        if seconds then
          intervals[#intervals + 1] = max(
            RESPAWN_MIN_SECONDS,
            min(RESPAWN_MAX_SECONDS, seconds)
          )
        end
      end
      if #intervals > MAX_RESPAWN_SAMPLES then
        local newest = {}
        for index = #intervals - MAX_RESPAWN_SAMPLES + 1, #intervals do
          newest[#newest + 1] = intervals[index]
        end
        intervals = newest
      end

      if #intervals > 0 then
        local name = SafeString(value.name)
        if name and name == "" then
          name = nil
        elseif name and #name > 80 then
          name = name:sub(1, 80)
        end
        normalized[npcID] = {
          name = name,
          intervals = intervals,
          lastSeen = NonNegativeNumber(value.lastSeen) or 0,
          lastDeath = NonNegativeNumber(value.lastDeath) or 0,
        }
      end
    end
  end

  local keys = {}
  for npcID in pairs(normalized) do
    keys[#keys + 1] = npcID
  end
  table.sort(keys, function(a, b)
    local aSeen = normalized[a].lastSeen
    local bSeen = normalized[b].lastSeen
    if aSeen == bSeen then
      return a < b
    end
    return aSeen < bSeen
  end)

  local newest = {}
  local first = max(1, #keys - MAX_RESPAWN_NPCS + 1)
  for index = first, #keys do
    local npcID = keys[index]
    newest[npcID] = normalized[npcID]
  end
  return newest
end

function XPTooltip:NormalizeRespawns(map)
  local db = self.char
  local source = map
  if source == nil then
    source = type(db) == "table" and db.respawns or {}
  end
  local normalized = NormalizeRespawns(source)
  if type(db) == "table" then
    db.respawns = normalized
  end
  return normalized
end

function XPTooltip:RecordRespawnDeath(npcID, guid, mapID)
  local id = PositiveNumber(npcID)
  local identity = SafeString(guid)
  if not id or not identity or identity == "" then
    return false
  end
  if type(self.respawnWatches) ~= "table" then
    self.respawnWatches = {}
  end
  self.respawnWatches[tostring(id)] = {
    guid = identity,
    mapID = NonNegativeNumber(mapID) or 0,
    at = Now(),
  }
  return true
end

function XPTooltip:ObserveRespawn(info)
  if type(info) ~= "table" then
    return false
  end
  local npcID = PositiveNumber(info.npcID)
  local guid = SafeString(info.guid)
  if not npcID or not guid then
    return false
  end
  if type(self.respawnWatches) ~= "table" then
    return false
  end

  local watchKey = tostring(npcID)
  local watch = self.respawnWatches[watchKey]
  if type(watch) ~= "table" then
    return false
  end
  if SafeString(watch.guid) == guid then
    return false
  end

  local mapID = NonNegativeNumber(info.mapID) or 0
  local watchMapID = NonNegativeNumber(watch.mapID) or 0
  if mapID > 0 and watchMapID > 0 and mapID ~= watchMapID then
    return false
  end

  local age = (NonNegativeNumber(info.at) or Now())
    - (NonNegativeNumber(watch.at) or 0)
  if age < RESPAWN_MIN_SECONDS or age > RESPAWN_MAX_SECONDS then
    return false
  end

  local recorded = self:RecordRespawnInterval(npcID, info.name, age)
  if recorded then
    self.respawnWatches[watchKey] = nil
    return true
  end
  return false
end

function XPTooltip:RecordRespawnInterval(npcID, name, seconds)
  local id = PositiveNumber(npcID)
  local interval = BoxedNumber(seconds)
  if not id or not interval then
    return false
  end
  local db = self.char
  if type(db) ~= "table" then
    return false
  end
  interval = max(RESPAWN_MIN_SECONDS, min(RESPAWN_MAX_SECONDS, interval))

  if type(db.respawns) ~= "table" then
    db.respawns = {}
  end
  local entry = db.respawns[id]
  if type(entry) ~= "table" then
    entry = { intervals = {} }
    db.respawns[id] = entry
  end
  if type(entry.intervals) ~= "table" then
    entry.intervals = {}
  end

  local label = SafeString(name)
  if label and label ~= "" then
    if #label > 80 then
      label = label:sub(1, 80)
    end
    entry.name = label
  elseif not SafeString(entry.name) or entry.name == "" then
    entry.name = "NPC " .. tostring(id)
  end

  entry.intervals[#entry.intervals + 1] = interval
  if #entry.intervals > MAX_RESPAWN_SAMPLES then
    local newest = {}
    for index = #entry.intervals - MAX_RESPAWN_SAMPLES + 1, #entry.intervals do
      newest[#newest + 1] = entry.intervals[index]
    end
    entry.intervals = newest
  end

  local now = Epoch()
  entry.lastSeen = now
  entry.lastDeath = max(0, now - interval)
  self:NormalizeRespawns()
  return true
end

function XPTooltip:GetRespawnStats(npcID)
  local id = PositiveNumber(npcID)
  local db = self.char
  if not id or type(db) ~= "table" or type(db.respawns) ~= "table" then
    return nil, 0, 0, 0, 0
  end
  local entry = db.respawns[id]
  if type(entry) ~= "table" or type(entry.intervals) ~= "table" then
    return nil, 0, 0, 0, 0
  end

  local samples, total = 0, 0
  local minimum, maximum
  for _, raw in ipairs(entry.intervals) do
    local seconds = BoxedNumber(raw)
    if seconds then
      samples = samples + 1
      total = total + seconds
      if not minimum or seconds < minimum then
        minimum = seconds
      end
      if not maximum or seconds > maximum then
        maximum = seconds
      end
    end
  end
  if samples == 0 then
    return nil, 0, 0, 0, NonNegativeNumber(entry.lastSeen) or 0
  end

  local average
  if samples >= MIN_RESPAWN_SAMPLES then
    average = total / samples
  end
  return average, samples, minimum or 0, maximum or 0,
    NonNegativeNumber(entry.lastSeen) or 0
end

function XPTooltip:PrintRespawns(rest)
  if not self:Supports("hasKillTracking") or not self:Supports("hasGUIDIdentity") then
    AceM2L2:SafePrint("Kill Story: respawn tracking is unavailable on this client.")
    return
  end
  local db = self.char
  if type(db) ~= "table" or type(db.respawns) ~= "table" then
    return
  end

  local filter = Lower(Trim(rest))
  if filter == "" then
    filter = nil
  end

  local list = {}
  for key, entry in pairs(db.respawns) do
    if type(entry) == "table" then
      local npcID = tonumber(key)
      if npcID and npcID > 0 then
        local name = SafeString(entry.name)
        if not name or name == "" then
          name = "NPC " .. tostring(npcID)
        end
        if not filter or (Lower(name) or ""):find(filter, 1, true) then
          local average, samples = self:GetRespawnStats(npcID)
          list[#list + 1] = {
            npcID = npcID,
            name = name,
            average = average,
            samples = samples or 0,
            lastSeen = NonNegativeNumber(entry.lastSeen) or 0,
          }
        end
      end
    end
  end

  if #list == 0 then
    AceM2L2:SafePrint("Kill Story: no respawn intervals recorded yet.")
    return
  end

  table.sort(list, function(a, b)
    if a.samples ~= b.samples then
      return a.samples > b.samples
    end
    return a.name < b.name
  end)

  AceM2L2:SafePrint("Kill Story respawns:")
  for index = 1, min(#list, 15) do
    local entry = list[index]
    if entry.samples < MIN_RESPAWN_SAMPLES then
      AceM2L2:SafePrint(string.format(
        "  %s: %d sample(s), need %d for an average",
        entry.name,
        entry.samples,
        MIN_RESPAWN_SAMPLES
      ))
    else
      local average, _, minimum, maximum = self:GetRespawnStats(entry.npcID)
      AceM2L2:SafePrint(string.format(
        "  %s: %s average (%s-%s), %d samples, last %s",
        entry.name,
        FormatDuration(average or 0),
        FormatDuration(minimum or 0),
        FormatDuration(maximum or 0),
        entry.samples,
        FormatAgo(entry.lastSeen)
      ))
    end
  end
end

--[[--------------------------------------------------------------------------------
  Grinding spots
------------------------------------------------------------------------------------]]

function XPTooltip:GetGrindingSpots(limit)
  if not self:Supports("hasPerMobXP") then
    return {}
  end
  local db = self.char
  if type(db) ~= "table" or type(db.rates) ~= "table" then
    return {}
  end

  local groups = {}
  local now = Epoch()
  local cutoff = now > 0 and (now - SPOT_MAX_AGE) or nil
  for _, sample in ipairs(db.rates) do
    if type(sample) == "table" then
      local at = PositiveNumber(sample.at)
      local xp = PositiveNumber(sample.xp)
      local mapID = PositiveNumber(sample.mapID)
      local level = PositiveNumber(sample.level)
      local source = SafeString(sample.source)
      -- Grinding spots reflect kill XP only; quest turn-ins and stale samples
      -- would otherwise inflate or distort the zone rate.
      if at and xp and mapID and level and source == "kill"
        and (not cutoff or at >= cutoff) then
        local key = tostring(mapID) .. ":" .. tostring(level)
        local group = groups[key]
        if not group then
          group = { mapID = mapID, level = level, samples = {} }
          groups[key] = group
        end
        group.samples[#group.samples + 1] = { at = at, xp = xp }
      end
    end
  end

  local results = {}
  for _, group in pairs(groups) do
    local samples = group.samples
    table.sort(samples, function(a, b)
      return a.at < b.at
    end)
    local count = #samples
    if count >= MIN_SPOT_SAMPLES then
      local span = samples[count].at - samples[1].at
      if span >= MIN_SPOT_SECONDS and span > 0 then
        -- The first sample is the baseline; only later gains count toward the
        -- rate, matching GetXPRate's two-sample minimum.
        local gained = 0
        for index = 2, count do
          gained = gained + samples[index].xp
        end
        results[#results + 1] = {
          mapID = group.mapID,
          level = group.level,
          xpPerHour = gained / span * 3600,
          samples = count,
          seconds = span,
        }
      end
    end
  end

  table.sort(results, function(a, b)
    if a.xpPerHour ~= b.xpPerHour then
      return a.xpPerHour > b.xpPerHour
    end
    if a.samples ~= b.samples then
      return a.samples > b.samples
    end
    if a.level ~= b.level then
      return a.level < b.level
    end
    return a.mapID < b.mapID
  end)

  local requested = tonumber(limit)
  if not requested or requested ~= requested or requested < 1 then
    requested = MAX_SPOT_RESULTS
  end
  local maximum = min(MAX_SPOT_RESULTS, floor(requested))
  local clipped = {}
  for index = 1, min(#results, maximum) do
    clipped[#clipped + 1] = results[index]
  end
  return clipped
end

function XPTooltip:PrintSpots()
  if not self:Supports("hasPerMobXP") then
    AceM2L2:SafePrint("Kill Story: grinding spots are unavailable on this client.")
    return
  end

  local spots = self:GetGrindingSpots(MAX_SPOT_RESULTS)
  if #spots == 0 then
    AceM2L2:SafePrint("Kill Story: not enough XP samples for a grinding spot yet"
      .. " (need " .. MIN_SPOT_SAMPLES .. " samples over "
      .. floor(MIN_SPOT_SECONDS / 60) .. " minutes).")
    return
  end

  AceM2L2:SafePrint("Kill Story grinding spots:")
  for _, spot in ipairs(spots) do
    AceM2L2:SafePrint(string.format(
      "  %s (level %d): %s XP/hr from %d samples over %s",
      self:GetMapName(spot.mapID),
      spot.level,
      FormatNumber(spot.xpPerHour),
      spot.samples,
      FormatDuration(spot.seconds)
    ))
  end
end
