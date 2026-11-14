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

local HEATMAP_GRID_SIZE = 64
local HEATMAP_CELLS = HEATMAP_GRID_SIZE * HEATMAP_GRID_SIZE
local LEGACY_GRID_SIZE = 16
local LEGACY_32_GRID_SIZE = 32
local MAX_HEATMAP_MAPS = 40
local MAX_HEATMAP_COUNT = 1000000

XPTooltip.HEATMAP_GRID_SIZE = HEATMAP_GRID_SIZE
XPTooltip.HEATMAP_CELLS = HEATMAP_CELLS
XPTooltip.MAX_HEATMAP_MAPS = MAX_HEATMAP_MAPS
XPTooltip.MAX_HEATMAP_COUNT = MAX_HEATMAP_COUNT

local function IsHeatmapEnabled(owner)
  if type(owner.GetSettings) ~= "function" then
    return true
  end
  local ok, settings = pcall(owner.GetSettings, owner)
  if not ok or type(settings) ~= "table" then
    return true
  end
  return settings.heatmapEnabled ~= false
end

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

local function IsZoneMap(mapID)
  if not C_Map or type(C_Map.GetMapInfo) ~= "function" then
    return true
  end
  local ok, info = pcall(C_Map.GetMapInfo, mapID)
  if not ok or type(info) ~= "table" then
    return true
  end
  local mapType = tonumber(info.mapType)
  if not mapType then
    return true
  end
  return mapType ~= 0 and mapType ~= 1 and mapType ~= 2
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

local function AddCell(target, cell, count)
  if cell < 1 or cell > HEATMAP_CELLS then
    return
  end
  local current = FiniteNumber(target.cells[cell]) or 0
  target.cells[cell] = min(MAX_HEATMAP_COUNT, current + count)
end

local function MaxCellIndex(cells)
  local maxCell = 0
  for cellKey in pairs(cells) do
    local cell = tonumber(cellKey)
    if cell and cell == floor(cell) and cell > maxCell then
      maxCell = cell
    end
  end
  return maxCell
end

-- Prefer the stored grid size. Legacy saves have no gridSize field, so infer
-- from the largest cell index: 16x16, 32x32, or the current 64x64 grid.
local function DetectSourceGrid(source, cells)
  local grid = floor(tonumber(source.gridSize) or 0)
  if grid >= 1 and grid <= HEATMAP_GRID_SIZE
    and HEATMAP_GRID_SIZE % grid == 0 then
    return grid
  end

  local maxCell = MaxCellIndex(cells)
  if maxCell <= 0 then
    return HEATMAP_GRID_SIZE
  elseif maxCell > LEGACY_32_GRID_SIZE * LEGACY_32_GRID_SIZE then
    return HEATMAP_GRID_SIZE
  elseif maxCell > LEGACY_GRID_SIZE * LEGACY_GRID_SIZE then
    return LEGACY_32_GRID_SIZE
  end
  return LEGACY_GRID_SIZE
end

local function UpgradeCells(sourceCells, target, sourceGrid)
  local ratio = floor(HEATMAP_GRID_SIZE / sourceGrid)
  if ratio < 1 then
    return
  end
  local targetCellsPerSource = ratio * ratio

  for cellKey, cellValue in pairs(sourceCells) do
    if not IsSecret(cellKey) and not IsSecret(cellValue) then
      local cell = tonumber(cellKey)
      if cell and cell == floor(cell) and cell >= 1
        and cell <= sourceGrid * sourceGrid then
        local count = NormalizeCellCount(cellValue)
        if count then
          if ratio == 1 then
            AddCell(target, cell, count)
          else
            local oldRow = floor((cell - 1) / sourceGrid)
            local oldCol = (cell - 1) % sourceGrid
            local baseRow = oldRow * ratio
            local baseCol = oldCol * ratio
            local share = floor(count / targetCellsPerSource)
            local remainder = count % targetCellsPerSource
            local index = 0
            for rowOffset = 0, ratio - 1 do
              for colOffset = 0, ratio - 1 do
                index = index + 1
                local add = share + (index <= remainder and 1 or 0)
                if add > 0 then
                  local targetCell = (baseRow + rowOffset) * HEATMAP_GRID_SIZE
                    + (baseCol + colOffset) + 1
                  AddCell(target, targetCell, add)
                end
              end
            end
          end
        end
      end
    end
  end
end

local function MergeCells(source, target)
  local cells = type(source.cells) == "table" and source.cells or nil
  if not cells then
    return
  end
  local sourceGrid = DetectSourceGrid(source, cells)
  if not sourceGrid then
    return
  end
  UpgradeCells(cells, target, sourceGrid)
end

-- Merge one stored map entry into an accumulator. Cells are the source of truth;
-- duplicate numeric/string map keys therefore simply add their cell counts.
local function MergeMapEntry(source, target)
  if type(source) ~= "table" then
    return
  end

  target.gridSize = HEATMAP_GRID_SIZE
  MergeCells(source, target)

  local lastSeen = FiniteNumber(source.lastSeen)
  if lastSeen and lastSeen > target.lastSeen then
    target.lastSeen = lastSeen
  end
end

function XPTooltip:InvalidateHeatmapCache()
  self.heatmapGeneration = (self.heatmapGeneration or 0) + 1
  self.heatmapNormalizeCache = nil
end

function XPTooltip:NormalizeHeatmaps(target)
  if not IsHeatmapEnabled(self) then
    return {}
  end
  if target == nil then
    target = self.char
  end
  if type(target) ~= "table" then
    return {}
  end

  local generation = self.heatmapGeneration or 0
  local cache = self.heatmapNormalizeCache
  if cache and cache.target == target and cache.generation == generation
    and cache.heatmaps == target.heatmaps then
    return cache.heatmaps
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
      gridSize = HEATMAP_GRID_SIZE,
      cells = entry.cells,
      total = entry.total,
      lastSeen = entry.lastSeen,
    }
  end

  target.heatmaps = heatmaps
  self.heatmapNormalizeCache = {
    target = target,
    generation = generation,
    heatmaps = heatmaps,
  }
  return heatmaps
end

function XPTooltip:ResetHeatmaps()
  local db = self.char
  if type(db) == "table" then
    db.heatmaps = {}
    self:InvalidateHeatmapCache()
    return db.heatmaps
  end
  self:InvalidateHeatmapCache()
  return {}
end

-- Return the normalized zones as an ordered list. Both the UI and the print
-- helper use this list so zones are sorted exactly once.
function XPTooltip:GetHeatmapZones()
  if not IsHeatmapEnabled(self) then
    return {}
  end
  local heatmaps = self:NormalizeHeatmaps()
  local zones = {}
  for key, entry in pairs(heatmaps) do
    if type(entry) == "table" then
      local mapID = NormalizeMapID(key)
      if mapID and IsZoneMap(mapID) then
        zones[#zones + 1] = {
          mapID = mapID,
          key = key,
          gridSize = entry.gridSize or HEATMAP_GRID_SIZE,
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
  if not IsHeatmapEnabled(self) or not self:Supports("hasMapPosition") then
    return false
  end

  local id = NormalizeMapID(mapID)
  local px = UnitCoordinate(x)
  local py = UnitCoordinate(y)
  if not id or not px or not py or not IsZoneMap(id) then
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
    entry = { gridSize = HEATMAP_GRID_SIZE, cells = {}, total = 0, lastSeen = 0 }
    heatmaps[key] = entry
  end
  entry.gridSize = HEATMAP_GRID_SIZE
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

  -- The entry lives in the cached normalized table, so the cache already sees
  -- this in-place update. Invalidating here would force a full copy of every
  -- zone on the next UI refresh, once per kill.
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

function XPTooltip:ClearHeatmaps()
  local db = type(self.char) == "table" and self.char or nil
  if db then
    db.heatmaps = {}
  end
  self:InvalidateHeatmapCache()
  self.heatmapZoneKey = nil
  if type(self.RefreshHeatmap) == "function" then
    pcall(self.RefreshHeatmap, self)
  end
  if type(self.RefreshUI) == "function" then
    pcall(self.RefreshUI, self)
  end
  if type(self.RefreshDiagnosticsUI) == "function" then
    pcall(self.RefreshDiagnosticsUI, self)
  end
  return true
end

function XPTooltip:RequestClearHeatmaps()
  local function clear()
    self:ClearHeatmaps()
  end
  if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
    StaticPopupDialogs["ACEM2L2_CLEAR_HEATMAP"] = {
      text = "Clear all stored heatmap data for this character?",
      button1 = YES or "Yes",
      button2 = NO or "No",
      OnAccept = clear,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    if pcall(StaticPopup_Show, "ACEM2L2_CLEAR_HEATMAP") then
      return
    end
  end
  clear()
end

function XPTooltip:PrintHeatmap(rest)
  local requested = Trim(rest)
  if requested and (Lower(requested) or "") == "clear" then
    if type(self.RequestClearHeatmaps) == "function" then
      self:RequestClearHeatmaps()
    else
      self:ClearHeatmaps()
    end
    AceM2L2:SafePrint("Kill Story: heatmap clear requested.")
    return
  end
  if not IsHeatmapEnabled(self) then
    AceM2L2:SafePrint("Kill Story: heatmap collection is disabled.")
    return
  end
  if not self:Supports("hasMapPosition") then
    AceM2L2:SafePrint("Kill Story: heatmap is unavailable on this client.")
    return
  end

  local zones = self:GetHeatmapZones()
  if #zones == 0 then
    AceM2L2:SafePrint("Kill Story: no heatmap data recorded yet.")
    return
  end

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
    local gridSize = floor(tonumber(zone.gridSize) or HEATMAP_GRID_SIZE)
    if gridSize < 1 or gridSize > HEATMAP_GRID_SIZE then
      gridSize = HEATMAP_GRID_SIZE
    end
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
      local col = (item.cell - 1) % gridSize + 1
      local row = floor((item.cell - 1) / gridSize) + 1
      local xPercent = floor((col - 0.5) * 100 / gridSize + 0.5)
      local yPercent = floor((row - 0.5) * 100 / gridSize + 0.5)
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
