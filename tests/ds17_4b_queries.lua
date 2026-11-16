-- DS-17.4B danger, best-zone XP/hour, and heatmap hotspot prototype.
-- Offline only. Uses the local save for heatmaps when present.

local SAVE_PATH = "/mnt/r/AceM2L2.lua"

local function clockMs() return os.clock() * 1000 end
local function countKeys(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

local function wilson(deaths, samples, z)
  z = z or 1.96
  if samples <= 0 then return 0, 1 end
  local p = deaths / samples
  local denom = 1 + z * z / samples
  local center = (p + z * z / (2 * samples)) / denom
  local margin = z * math.sqrt((p * (1 - p) + z * z / (4 * samples)) / samples) / denom
  local lower = math.max(0, center - margin)
  local upper = math.min(1, center + margin)
  return lower, upper
end

local function confidence(samples)
  if samples < 20 then return "low" end
  if samples < 100 then return "medium" end
  return "high"
end

-- ---------------------------------------------------------------------------
-- Danger by combat context
-- ---------------------------------------------------------------------------

local dangerContexts = {
  { name = "solo healthy normal", kills = 400, deaths = 4, healthLost = 0.08, timeToKill = 8 },
  { name = "solo low health", kills = 60, deaths = 30, healthLost = 0.72, timeToKill = 18 },
  { name = "group healthy normal", kills = 200, deaths = 2, healthLost = 0.04, timeToKill = 5 },
  { name = "elite low health", kills = 30, deaths = 15, healthLost = 0.90, timeToKill = 32 },
  { name = "sparse observation", kills = 2, deaths = 0, healthLost = 0.10, timeToKill = 9 },
}

print("danger_contexts")
for _, context in ipairs(dangerContexts) do
  local samples = context.kills + context.deaths
  local lower, upper = wilson(context.deaths, samples)
  local verdict
  if samples < 20 then
    verdict = "not_enough_data"
  elseif lower > 0.20 then
    verdict = "dangerous"
  elseif upper < 0.05 then
    verdict = "safe_or_slaughter"
  else
    verdict = "mixed"
  end
  print(string.format("  %s kills=%d deaths=%d samples=%d death_rate=%.3f wilson=%.3f..%.3f confidence=%s healthLost=%.2f timeToKill=%d verdict=%s",
    context.name, context.kills, context.deaths, samples,
    samples > 0 and context.deaths / samples or 0,
    lower, upper, confidence(samples), context.healthLost, context.timeToKill,
    verdict))
end
print("danger_quest_state_included=false danger_health_buff_group=true")

-- ---------------------------------------------------------------------------
-- Best zone by XP/hour at current level
-- ---------------------------------------------------------------------------

local zones = {
  { name = "Zone A", level = 20, xp = 100000, activeSeconds = 3600, kills = 500, sessions = 4, deaths = 2 },
  { name = "Zone B", level = 20, xp = 200000, activeSeconds = 7200, kills = 900, sessions = 6, deaths = 4 },
  { name = "Zone C", level = 20, xp = 50000, activeSeconds = 900, kills = 180, sessions = 2, deaths = 1 },
  { name = "Zone D", level = 20, xp = 500000, activeSeconds = 36000, kills = 3000, sessions = 12, deaths = 30 },
  { name = "Zone E", level = 20, xp = 80000, activeSeconds = 600, kills = 100, sessions = 1, deaths = 0 },
  { name = "Zone F", level = 30, xp = 300000, activeSeconds = 7200, kills = 1200, sessions = 5, deaths = 5 },
}

local function rankZones(level, minActiveSeconds)
  local rows = {}
  for _, zone in ipairs(zones) do
    if zone.level == level and zone.activeSeconds >= minActiveSeconds then
      local xpPerHour = zone.xp / (zone.activeSeconds / 3600)
      local killsPerHour = zone.kills / (zone.activeSeconds / 3600)
      local conf = confidence(zone.sessions * 20)
      if zone.activeSeconds < 1800 or zone.sessions < 3 then conf = "low" end
      rows[#rows + 1] = { zone = zone, xpPerHour = xpPerHour,
        killsPerHour = killsPerHour, confidence = conf }
    end
  end
  table.sort(rows, function(a, b) return a.xpPerHour > b.xpPerHour end)
  return rows
end

for _, level in ipairs({20, 30}) do
  print(string.format("best_zone_level=%d min_active=600", level))
  for index, row in ipairs(rankZones(level, 600)) do
    print(string.format("  rank=%d zone=%s xp_per_hour=%.0f kills_per_hour=%.0f active_s=%d sessions=%d confidence=%s",
      index, row.zone.name, row.xpPerHour, row.killsPerHour,
      row.zone.activeSeconds, row.zone.sessions, row.confidence))
  end
end
print("best_zone_metric=xp_per_hour not=kills")

-- ---------------------------------------------------------------------------
-- Heatmap hotspots and downsampling
-- ---------------------------------------------------------------------------

local function loadHeatmaps()
  local env = {}
  local chunk, err = loadfile(SAVE_PATH, "t", env)
  if not chunk then return nil, err end
  local ok, loadErr = pcall(chunk)
  if not ok then return nil, loadErr end
  local db = env.AceM2L2CharDB and env.AceM2L2CharDB.xpTooltip
    and env.AceM2L2CharDB.xpTooltip.clients and env.AceM2L2CharDB.xpTooltip.clients[18]
  if not db or type(db.heatmaps) ~= "table" then return nil, "no heatmaps" end
  return db.heatmaps
end

local function topCells(cells, count)
  local list = {}
  for cell, value in pairs(cells or {}) do
    list[#list + 1] = { cell = cell, value = tonumber(value) or 0 }
  end
  table.sort(list, function(a, b) return a.value > b.value end)
  local top = {}
  for index = 1, math.min(count, #list) do top[list[index].cell] = index end
  return top, list
end

local function shareTop(cells, topCount)
  local _, list = topCells(cells, topCount)
  local total, kept = 0, 0
  for _, row in ipairs(list) do total = total + row.value end
  for index = 1, math.min(topCount, #list) do kept = kept + list[index].value end
  return total > 0 and kept / total or 0
end

local function downsample(cells, fromSize, toSize)
  local result = {}
  local ratio = fromSize / toSize
  for cell, value in pairs(cells or {}) do
    local x = (cell - 1) % fromSize
    local y = math.floor((cell - 1) / fromSize)
    local nx = math.floor(x / ratio)
    local ny = math.floor(y / ratio)
    local target = ny * toSize + nx + 1
    result[target] = (result[target] or 0) + (tonumber(value) or 0)
  end
  return result
end

local heatmaps, heatErr = loadHeatmaps()
if heatmaps then
  for mapID, heatmap in pairs(heatmaps) do
    local grid = tonumber(heatmap.gridSize) or 64
    local cells = heatmap.cells or {}
    local occupied = countKeys(cells)
    local totalCells = grid * grid
    local topSource = topCells(cells, 10)
    print(string.format("heatmap_map=%s grid=%d occupied=%d occupancy=%.2f%% total=%s top1=%.3f top5=%.3f top10=%.3f",
      tostring(mapID), grid, occupied, occupied / totalCells * 100,
      tostring(heatmap.total), shareTop(cells, 1), shareTop(cells, 5), shareTop(cells, 10)))
    for _, targetSize in ipairs({32, 16}) do
      local reduced = downsample(cells, grid, targetSize)
      local topTarget = topCells(reduced, 10)
      local overlap = 0
      for sourceCell in pairs(topSource) do
        local x = (sourceCell - 1) % grid
        local y = math.floor((sourceCell - 1) / grid)
        local ratio = grid / targetSize
        local tx = math.floor(x / ratio)
        local ty = math.floor(y / ratio)
        local targetCell = ty * targetSize + tx + 1
        if topTarget[targetCell] then overlap = overlap + 1 end
      end
      print(string.format("  downsample_%d cells=%d top10_overlap=%d/10",
        targetSize, countKeys(reduced), overlap))
    end
  end
else
  print("heatmap_load=missing:" .. tostring(heatErr))
end
print("heatmap_sparse_note=local occupancy is 4.5-4.8%, not 4096 saturated cells")
print("missing_for_heatmap_xp_hour=cell_xp;cell_activeSeconds")

-- ---------------------------------------------------------------------------
-- Gaps
-- ---------------------------------------------------------------------------

print("gap_killer_attribution=true gap_death_health_buffs_group=true gap_active_seconds=true gap_no_per_kill_log=true")
print("no_merge_implemented=true no_ui=true")
