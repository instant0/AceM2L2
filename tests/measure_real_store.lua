-- Read-only real SavedVariables measurement for SC-1.
-- Usage: lua tests/measure_real_store.lua [/path/to/AceM2L2.lua]

local path = arg[1] or "/mnt/r/AceM2L2.lua"

local env = {}
local chunk = assert(loadfile(path, "t", env))
chunk()
local root = env.AceM2L2CharDB
assert(type(root) == "table", "AceM2L2CharDB missing")

local function countKeys(value)
  local total = 0
  if type(value) == "table" then
    for _ in pairs(value) do total = total + 1 end
  end
  return total
end

local function number(value)
  return tonumber(value) or 0
end

local function serialize(value, seen)
  local kind = type(value)
  if kind == "table" then
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
      return tostring(a) < tostring(b)
    end)
    local parts = {}
    for index = 1, #keys do
      local key = keys[index]
      parts[#parts + 1] = "[" .. serialize(key, seen) .. "]="
        .. serialize(value[key], seen) .. ","
    end
    seen[value] = nil
    return "{" .. table.concat(parts) .. "}"
  elseif kind == "string" then
    return string.format("%q", value)
  elseif kind == "number" or kind == "boolean" then
    return tostring(value)
  end
  return "nil"
end

local function bytes(value)
  return #serialize(value, {})
end

local function fileBytes(filePath)
  local file = assert(io.open(filePath, "rb"))
  local size = file:seek("end")
  file:close()
  return size
end

local function spans(cells, gridSize)
  local minRow, maxRow, minCol, maxCol
  for key in pairs(cells or {}) do
    local index = tonumber(key) or 0
    local row = math.floor((index - 1) / gridSize)
    local col = (index - 1) % gridSize
    minRow = minRow and math.min(minRow, row) or row
    maxRow = maxRow and math.max(maxRow, row) or row
    minCol = minCol and math.min(minCol, col) or col
    maxCol = maxCol and math.max(maxCol, col) or col
  end
  return minRow, maxRow, minCol, maxCol
end

local tooltip = root.xpTooltip or {}
local clients = tooltip.clients or {}
local clientID, client
for id, value in pairs(clients) do
  clientID, client = id, value
  break
end
assert(type(client) == "table", "no per-client store")

local sections = {
  "mobs", "quests", "deaths", "respawns", "instances", "areas",
  "areaLevels", "levels", "heatmaps", "levelHistory", "rates",
  "calibration", "goal", "session", "economy", "dungeon", "totals",
}
local rootBytes = bytes(root)
local clientBytes = bytes(client)
local totalKills, totalXP = 0, 0
local npcMobs, nameMobs, contextCount = 0, 0, 0
local maxZones, maxKills, maxContexts = 0, 0, 0
local zoneRefs, instanceRefs = {}, {}
for key, mob in pairs(client.mobs or {}) do
  if type(mob) == "table" then
    local kills = number(mob.kills)
    totalKills = totalKills + kills
    totalXP = totalXP + number(mob.totalXP)
    if mob.npcID then npcMobs = npcMobs + 1 else nameMobs = nameMobs + 1 end
    local contexts = countKeys(mob.contexts)
    contextCount = contextCount + contexts
    maxContexts = math.max(maxContexts, contexts)
    local zones = countKeys(mob.killsByMap) + countKeys(mob.killsByInstance)
    maxZones = math.max(maxZones, zones)
    maxKills = math.max(maxKills, kills)
    for mapKey in pairs(mob.killsByMap or {}) do zoneRefs[mapKey] = true end
    for instanceKey in pairs(mob.killsByInstance or {}) do instanceRefs[instanceKey] = true end
  end
end

local respawnSamples = 0
for _, entry in pairs(client.respawns or {}) do
  if type(entry) == "table" and type(entry.intervals) == "table" then
    respawnSamples = respawnSamples + #entry.intervals
  end
end
local questGains, questXP = 0, 0
for _, entry in pairs(client.quests or {}) do
  if type(entry) == "table" then
    questGains = questGains + number(entry.count)
    questXP = questXP + number(entry.totalXP)
  end
end
local heatmapZones, heatmapCells, heatmapKills = 0, 0, 0
local maxZoneCells, maxZoneOcc = 0, 0
local heatmapRows = {}
for mapID, entry in pairs(client.heatmaps or {}) do
  if type(entry) == "table" then
    local gridSize = number(entry.gridSize)
    if gridSize <= 0 then gridSize = 64 end
    local cellCount = countKeys(entry.cells)
    heatmapZones = heatmapZones + 1
    heatmapCells = heatmapCells + cellCount
    heatmapKills = heatmapKills + number(entry.total)
    maxZoneCells = math.max(maxZoneCells, cellCount)
    maxZoneOcc = math.max(maxZoneOcc, cellCount / (gridSize * gridSize))
    local minRow, maxRow, minCol, maxCol = spans(entry.cells, gridSize)
    local rows = minRow and (maxRow - minRow + 1) or 0
    local cols = minCol and (maxCol - minCol + 1) or 0
    heatmapRows[#heatmapRows + 1] = string.format(
      "heatmap=%s grid=%d cells=%d total=%d grid_occ=%.3f span=%dx%d span_occ=%.3f",
      tostring(mapID), gridSize, cellCount, number(entry.total),
      cellCount / (gridSize * gridSize), rows, cols,
      rows * cols > 0 and cellCount / (rows * cols) or 0
    )
  end
end
table.sort(heatmapRows)

print("file=" .. path)
print("file_bytes=" .. tostring(fileBytes(path)))
print("root_serialized_bytes=" .. tostring(rootBytes))
print("client_serialized_bytes=" .. tostring(clientBytes))
print("project=" .. tostring(clientID))
print("sections=" .. tostring(#sections))
for _, name in ipairs(sections) do
  local value = client[name]
  print(string.format("section=%s entries=%d bytes=%d share=%.3f",
    name, countKeys(value), bytes(value), clientBytes > 0 and bytes(value) / clientBytes or 0))
end
print("mobs=" .. tostring(countKeys(client.mobs)))
print("mobs_npc=" .. tostring(npcMobs))
print("mobs_name_only=" .. tostring(nameMobs))
print("kills=" .. tostring(totalKills))
print("mob_total_xp=" .. tostring(totalXP))
print("contexts=" .. tostring(contextCount))
print("max_contexts_per_mob=" .. tostring(maxContexts))
print("max_zones_per_mob=" .. tostring(maxZones))
print("max_kills_per_mob=" .. tostring(maxKills))
print("zone_refs=" .. tostring(countKeys(zoneRefs)))
print("instance_refs=" .. tostring(countKeys(instanceRefs)))
print("quests=" .. tostring(countKeys(client.quests)))
print("quest_gains=" .. tostring(questGains))
print("quest_xp=" .. tostring(questXP))
print("deaths=" .. tostring(#(client.deaths or {})))
print("respawns=" .. tostring(countKeys(client.respawns)))
print("respawn_samples=" .. tostring(respawnSamples))
print("instances=" .. tostring(countKeys(client.instances)))
print("areas=" .. tostring(countKeys(client.areas)))
print("levels=" .. tostring(countKeys(client.levels)))
print("level_history=" .. tostring(countKeys(client.levelHistory)))
print("rates=" .. tostring(countKeys(client.rates)))
print("heatmap_zones=" .. tostring(heatmapZones))
print("heatmap_cells=" .. tostring(heatmapCells))
print("heatmap_kills=" .. tostring(heatmapKills))
print("heatmap_max_cells_zone=" .. tostring(maxZoneCells))
print(string.format("heatmap_max_zone_occupancy=%.3f", maxZoneOcc))
for _, line in ipairs(heatmapRows) do print(line) end
local calibration = type(client.calibration) == "table" and client.calibration or {}
for _, key in ipairs({ "zones", "levels", "groups", "classes", "mobs" }) do
  print("calibration_" .. key .. "=" .. tostring(countKeys(calibration[key])))
end
