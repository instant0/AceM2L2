--[[---------------------------------------------------------------------------------
  KillHistory/Heatmap.lua
  Zone kill heatmap data, normalization, capture, reset, and command output.
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
local Epoch = Util.Epoch
local FormatNumber = Util.FormatNumber
local FormatPercent = Util.FormatPercent
local FormatAgo = Util.FormatAgo

local HEATMAP_GRID_SIZE = 16
local HEATMAP_CELLS = HEATMAP_GRID_SIZE * HEATMAP_GRID_SIZE
local MAX_HEATMAP_MAPS = 40
local MAX_HEATMAP_COUNT = 1000000

XPTooltip.HEATMAP_GRID_SIZE = HEATMAP_GRID_SIZE
XPTooltip.HEATMAP_CELLS = HEATMAP_CELLS
XPTooltip.MAX_HEATMAP_MAPS = MAX_HEATMAP_MAPS
XPTooltip.MAX_HEATMAP_COUNT = MAX_HEATMAP_COUNT

--[[--------------------------------------------------------------------------------
  Validation helpers
------------------------------------------------------------------------------------]]

local function FiniteNumber(value)
  if value == nil or IsSecret(value) then
    return nil
  end
  local number = SafeNumber(value)
  if number == nil or number ~= number
    or number == math.huge or number == -math.huge then
    return nil
  end
  return number
end

local function NormalizeMapID(value)
  if value == nil or IsSecret(value) then
    return nil
  end
  local number
  if type(value) == "number" then
    number = value
  elseif type(value) == "string" then
    -- Map keys persist as strings, so accept a numeric string and merge it
    -- with the same ID stored under a numeric key.
    number = tonumber(value)
  else
    return nil
  end
  if number == nil or number ~= number
    or number == math.huge or number == -math.huge then
    return nil
  end
  if number <= 0 then
    return nil
  end
  local mapID = floor(number + 0.5)
  if mapID <= 0 then
    return nil
  end
  return mapID
end

local function UnitCoordinate(value)
  local number = FiniteNumber(value)
  if number == nil or number < 0 or number > 1 then
    return nil
  end
  return number
end

-- A cell count must be a positive whole number. Fractions are floored and the
-- result is capped so a single cell can never exceed MAX_HEATMAP_COUNT.
local function NormalizeCellCount(value)
  local number = FiniteNumber(value)
  if number == nil or number <= 0 then
    return nil
  end
  local count = floor(number)
  if count <= 0 then
    return nil
  end
  return min(MAX_HEATMAP_COUNT, count)
end

local function SortZones(list)
  table.sort(list, function(a, b)
    if a.lastSeen ~= b.lastSeen then
      return a.lastSeen > b.lastSeen
    end
    if a.total ~= b.total then
      return a.total > b.total
    end
    return a.mapID < b.mapID
  end)
end

local function CountCells(cells)
  local count = 0
  if type(cells) ~= "table" then
    return count
  end
  for _, value in pairs(cells) do
    if (FiniteNumber(value) or 0) > 0 then
      count = count + 1
    end
  end
  return count
end

--[[--------------------------------------------------------------------------------
  Normalization
------------------------------------------------------------------------------------]]

-- Merge one stored map entry into an accumulator. Cells are the source of truth;
-- duplicate numeric/string map keys therefore simply add their cell counts.
local function MergeMapEntry(source, target)
  if type(source) ~= "table" then
    return
  end

  local cells = type(source.cells) == "table" and source.cells or nil
  if cells then
    for cellKey, cellValue in pairs(cells) do
      if not IsSecret(cellKey) and not IsSecret(cellValue) then
        local cell = tonumber(cellKey)
        if cell and cell == floor(cell) and cell >= 1 and cell <= HEATMAP_CELLS then
          local count = NormalizeCellCount(cellValue)
          if count then
            local merged = (target.cells[cell] or 0) + count
            target.cells[cell] = min(MAX_HEATMAP_COUNT, merged)
          end
        end
      end
    end
  end

  local lastSeen = FiniteNumber(source.lastSeen)
  if lastSeen and lastSeen > target.lastSeen then
    target.lastSeen = lastSeen
  end
end

function XPTooltip:NormalizeHeatmaps(target)
  if target == nil then
    target = self.char
  end
  if type(target) ~= "table" then
    return {}
  end

  local source = type(target.heatmaps) == "table" and target.heatmaps or {}
  local merged = {}

  for key, value in pairs(source) do
    if not IsSecret(key) and type(value) == "table" then
      local mapID = NormalizeMapID(key)
      if mapID then
        local mapKey = tostring(mapID)
        local entry = merged[mapKey]
        if type(entry) ~= "table" then
          entry = { mapID = mapID, cells = {}, lastSeen = 0 }
          merged[mapKey] = entry
        end
        MergeMapEntry(value, entry)
      end
    end
  end

  local list = {}
  for mapKey, entry in pairs(merged) do
    local total = 0
    for _, count in pairs(entry.cells) do
      total = total + count
    end
    if total > 0 then
      entry.key = mapKey
      entry.total = total
      entry.lastSeen = max(0, entry.lastSeen)
      list[#list + 1] = entry
    end
  end

  SortZones(list)

  local heatmaps = {}
  for index = 1, min(#list, MAX_HEATMAP_MAPS) do
    local entry = list[index]
    heatmaps[entry.key] = {
      cells = entry.cells,
      total = entry.total,
      lastSeen = entry.lastSeen,
    }
  end

  target.heatmaps = heatmaps
  return heatmaps
end

function XPTooltip:ResetHeatmaps()
  local db = self.char
  if type(db) == "table" then
    db.heatmaps = {}
    return db.heatmaps
  end
  return {}
end

-- Return the normalized zones as an ordered list. Both the UI and the print
-- helper use this list so zones are sorted exactly once.
function XPTooltip:GetHeatmapZones()
  local heatmaps = self:NormalizeHeatmaps()
  local zones = {}
  for key, entry in pairs(heatmaps) do
    if type(entry) == "table" then
      local mapID = NormalizeMapID(key)
      if mapID then
        zones[#zones + 1] = {
          mapID = mapID,
          key = key,
          total = entry.total,
          lastSeen = entry.lastSeen,
          cells = entry.cells,
        }
      end
    end
  end
  SortZones(zones)
  return zones
end

--[[--------------------------------------------------------------------------------
  Capture
------------------------------------------------------------------------------------]]

-- Drop the least recently seen map. Equal timestamps prefer the smaller total,
-- then the lexicographically larger key for a deterministic result.
local function DropOldestMap(heatmaps)
  local oldestKey, oldestSeen, oldestTotal
  for key, entry in pairs(heatmaps) do
    if type(entry) == "table" then
      local seen = FiniteNumber(entry.lastSeen) or 0
      local total = FiniteNumber(entry.total) or 0
      if oldestKey == nil
        or seen < oldestSeen
        or (seen == oldestSeen and total < oldestTotal)
        or (seen == oldestSeen and total == oldestTotal and key > oldestKey) then
        oldestKey, oldestSeen, oldestTotal = key, seen, total
      end
    end
  end
  if oldestKey == nil then
    return false
  end
  heatmaps[oldestKey] = nil
  return true
end

function XPTooltip:RecordHeatmapKill(mapID, x, y)
  if not self:Supports("hasMapPosition") then
    return false
  end

  local id = NormalizeMapID(mapID)
  local px = UnitCoordinate(x)
  local py = UnitCoordinate(y)
  if not id or not px or not py then
    return false
  end

  local db = self.char
  if type(db) ~= "table" then
    return false
  end

  local heatmaps = db.heatmaps
  if type(heatmaps) ~= "table" then
    heatmaps = self:NormalizeHeatmaps(db)
  end
  local key = tostring(id)
  local entry = heatmaps[key]
  if type(entry) ~= "table" then
    entry = { cells = {}, total = 0, lastSeen = 0 }
    heatmaps[key] = entry
  end
  if type(entry.cells) ~= "table" then
    entry.cells = {}
  end

  local col = max(1, min(HEATMAP_GRID_SIZE, floor(px * HEATMAP_GRID_SIZE) + 1))
  local row = max(1, min(HEATMAP_GRID_SIZE, floor(py * HEATMAP_GRID_SIZE) + 1))
  local cell = (row - 1) * HEATMAP_GRID_SIZE + col

  local count = FiniteNumber(entry.cells[cell]) or 0
  if count < MAX_HEATMAP_COUNT then
    entry.cells[cell] = count + 1
    entry.total = (FiniteNumber(entry.total) or 0) + 1
  end
  entry.lastSeen = max(0, Epoch())

  local mapCount = 0
  for _ in pairs(heatmaps) do
    mapCount = mapCount + 1
  end
  while mapCount > MAX_HEATMAP_MAPS do
    if not DropOldestMap(heatmaps) then
      break
    end
    mapCount = mapCount - 1
  end

  return true
end

--[[--------------------------------------------------------------------------------
  Command output
------------------------------------------------------------------------------------]]

local function ZoneName(owner, mapID)
  local name = SafeString(SafeCall(owner.GetMapName, owner, mapID))
  if name and name ~= "" then
    return name
  end
  return "Map " .. tostring(mapID)
end

function XPTooltip:PrintHeatmap(rest)
  if not self:Supports("hasMapPosition") then
    AceM2L2:SafePrint("Kill Story: heatmap is unavailable on this client.")
    return
  end

  local zones = self:GetHeatmapZones()
  if #zones == 0 then
    AceM2L2:SafePrint("Kill Story: no heatmap data recorded yet.")
    return
  end

  local requested = Trim(rest)
  if requested == "" then
    requested = nil
  end

  if requested then
    local needle = Lower(requested) or ""
    local zone
    for _, candidate in ipairs(zones) do
      local name = Lower(ZoneName(self, candidate.mapID)) or ""
      if name:find(needle, 1, true) then
        zone = candidate
        break
      end
    end

    if not zone then
      AceM2L2:SafePrint("Kill Story: no heatmap zone matching "
        .. requested .. ".")
      return
    end

    local cellCount = CountCells(zone.cells)
    AceM2L2:SafePrint(string.format(
      "Kill Story heatmap: %s (%s kills, %s cells)",
      ZoneName(self, zone.mapID),
      FormatNumber(zone.total),
      FormatNumber(cellCount)
    ))

    local cells = {}
    for cell, count in pairs(zone.cells) do
      local number = FiniteNumber(cell)
      local value = FiniteNumber(count)
      if number and value and value > 0 then
        cells[#cells + 1] = { cell = number, count = value }
      end
    end
    table.sort(cells, function(a, b)
      if a.count ~= b.count then
        return a.count > b.count
      end
      return a.cell < b.cell
    end)

    for index = 1, min(#cells, 10) do
      local item = cells[index]
      local col = (item.cell - 1) % HEATMAP_GRID_SIZE + 1
      local row = floor((item.cell - 1) / HEATMAP_GRID_SIZE) + 1
      local xPercent = floor((col - 0.5) * 100 / HEATMAP_GRID_SIZE + 0.5)
      local yPercent = floor((row - 0.5) * 100 / HEATMAP_GRID_SIZE + 0.5)
      local share = zone.total > 0 and item.count / zone.total * 100 or 0
      AceM2L2:SafePrint(string.format(
        "  %d%%, %d%%: %s kills (%s of zone)",
        xPercent,
        yPercent,
        FormatNumber(item.count),
        FormatPercent(share)
      ))
    end
    return
  end

  AceM2L2:SafePrint("Kill Story heatmaps:")
  for index = 1, min(#zones, 10) do
    local zone = zones[index]
    AceM2L2:SafePrint(string.format(
      "  %s: %s kills in %s cells (%s)",
      ZoneName(self, zone.mapID),
      FormatNumber(zone.total),
      FormatNumber(CountCells(zone.cells)),
      FormatAgo(zone.lastSeen)
    ))
  end
end
