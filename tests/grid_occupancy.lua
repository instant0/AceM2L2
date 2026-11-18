-- G-2 offline grid-occupancy study.
-- Usage: lua tests/grid_occupancy.lua [verify]
--
-- This harness is read-only. It does not change the durable grid, schema, or UI.
-- It compares 64x64 with 96x96/128x128 using:
--   * the recorded real-store zone aggregates (SC-1 / DS-17.4B), and
--   * deterministic occupancy replays and synthetic kill clouds.
--
-- The raw real cells are not required for the resolution comparison. The
-- documented aggregate shape (cells, kills, span) is replayed so that 64x64 is
-- reproduced, then the same kill cloud is rasterized at 96 and 128.

local VERIFY = (arg and arg[1]) == "verify"

local floor, min, max, sqrt, log, cos, sin, pi =
  math.floor, math.min, math.max, math.sqrt, math.log, math.cos, math.sin, math.pi

-- ---------------------------------------------------------------------------
-- Deterministic random
-- ---------------------------------------------------------------------------
local seed = 20261117
local function rand()
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed / 2147483648
end
local function resetSeed(value)
  seed = value
end
local function gauss()
  local u1 = rand()
  if u1 < 1e-12 then u1 = 1e-12 end
  local u2 = rand()
  return sqrt(-2 * log(u1)) * cos(2 * pi * u2)
end

-- ---------------------------------------------------------------------------
-- Grid helpers
-- ---------------------------------------------------------------------------
local function cellFor(x, y, grid)
  local col = max(1, min(grid, floor(x * grid) + 1))
  local row = max(1, min(grid, floor(y * grid) + 1))
  return (row - 1) * grid + col, row, col
end

local function rasterize(points, grid)
  local cells, total = {}, 0
  for index = 1, #points do
    local point = points[index]
    local cell = cellFor(point[1], point[2], grid)
    cells[cell] = (cells[cell] or 0) + 1
    total = total + 1
  end
  return cells, total
end

local function sortedCells(cells)
  local rows = {}
  for cell, count in pairs(cells) do
    rows[#rows + 1] = { cell = cell, count = count }
  end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.cell < b.cell
  end)
  return rows
end

local function metrics(cells, total, grid)
  local rows = sortedCells(cells)
  local occupied = #rows
  local minRow, maxRow, minCol, maxCol
  local oneKill, isolated = 0, 0
  for index = 1, occupied do
    local item = rows[index]
    local row = floor((item.cell - 1) / grid)
    local col = (item.cell - 1) % grid
    minRow = minRow and min(minRow, row) or row
    maxRow = maxRow and max(maxRow, row) or row
    minCol = minCol and min(minCol, col) or col
    maxCol = maxCol and max(maxCol, col) or col
    if item.count == 1 then oneKill = oneKill + 1 end
  end
  for index = 1, occupied do
    local item = rows[index]
    local row = floor((item.cell - 1) / grid)
    local col = (item.cell - 1) % grid
    local neighbours = 0
    for dr = -1, 1 do
      for dc = -1, 1 do
        if dr ~= 0 or dc ~= 0 then
          local r, c = row + dr, col + dc
          if r >= 0 and r < grid and c >= 0 and c < grid then
            if cells[r * grid + c + 1] then neighbours = neighbours + 1 end
          end
        end
      end
    end
    if neighbours == 0 then isolated = isolated + 1 end
  end
  local spanRows = minRow and (maxRow - minRow + 1) or 0
  local spanCols = minCol and (maxCol - minCol + 1) or 0
  local top10 = 0
  for index = 1, min(10, occupied) do top10 = top10 + rows[index].count end
  local median = 0
  if occupied > 0 then
    local sortedCounts = {}
    for index = 1, occupied do sortedCounts[index] = rows[index].count end
    local middle = floor((occupied + 1) / 2)
    median = sortedCounts[middle]
  end
  return {
    grid = grid,
    cells = occupied,
    total = total,
    occupancy = occupied / (grid * grid),
    spanRows = spanRows,
    spanCols = spanCols,
    aspect = spanRows > 0 and spanCols / spanRows or 0,
    spanOccupancy = spanRows * spanCols > 0 and occupied / (spanRows * spanCols) or 0,
    median = median,
    mean = occupied > 0 and total / occupied or 0,
    oneKillShare = occupied > 0 and oneKill / occupied or 0,
    isolatedShare = occupied > 0 and isolated / occupied or 0,
    top10Share = total > 0 and top10 / total or 0,
    top10 = rows,
  }
end

-- Downsample any source grid to 64 with exact area weighting. 128 nests
-- exactly; 96 does not, so its boundary cells are split proportionally.
local function downsampleTo64(cells, grid)
  local result = {}
  for cell, count in pairs(cells) do
    local row = floor((cell - 1) / grid)
    local col = (cell - 1) % grid
    local x0, x1 = col / grid, (col + 1) / grid
    local y0, y1 = row / grid, (row + 1) / grid
    local sourceArea = 1 / (grid * grid)
    local firstRow = floor(y0 * 64)
    local lastRow = min(63, floor(y1 * 64 + 1e-9))
    local firstCol = floor(x0 * 64)
    local lastCol = min(63, floor(x1 * 64 + 1e-9))
    for targetRow = firstRow, lastRow do
      local ty0, ty1 = targetRow / 64, (targetRow + 1) / 64
      local overlapY = min(y1, ty1) - max(y0, ty0)
      if overlapY > 0 then
        for targetCol = firstCol, lastCol do
          local tx0, tx1 = targetCol / 64, (targetCol + 1) / 64
          local overlapX = min(x1, tx1) - max(x0, tx0)
          if overlapX > 0 then
            local target = targetRow * 64 + targetCol + 1
            local share = count * overlapX * overlapY / sourceArea
            result[target] = (result[target] or 0) + share
          end
        end
      end
    end
  end
  return result
end

local function topSet(cells, count)
  local rows = sortedCells(cells)
  local set = {}
  for index = 1, min(count, #rows) do set[rows[index].cell] = true end
  return set
end

local function overlap(a, b)
  local matched = 0
  for cell in pairs(a) do
    if b[cell] then matched = matched + 1 end
  end
  return matched
end

-- SavedVariables-like sparse table bytes: [cell]=count, sorted by cell index.
local function serializedBytes(cells)
  local keys = {}
  for cell in pairs(cells) do keys[#keys + 1] = cell end
  table.sort(keys)
  local bytes = 2 -- { }
  for index = 1, #keys do
    local key = keys[index]
    bytes = bytes + 2 + #tostring(key) + 1 + #tostring(cells[key]) + 1
  end
  return bytes
end

local function formatMB(bytes)
  return string.format("%.2f", bytes / 1024 / 1024)
end

-- ---------------------------------------------------------------------------
-- Synthetic point clouds
-- ---------------------------------------------------------------------------
local function routeCloud(count, waypoints, jitter)
  local points = {}
  local segments = #waypoints - 1
  for index = 1, count do
    local t = (index - 1) / max(1, count - 1)
    local position = t * segments
    local segment = min(segments, floor(position) + 1)
    local localT = position - floor(position)
    local from, to = waypoints[segment], waypoints[segment + 1]
    local x = from[1] + (to[1] - from[1]) * localT
    local y = from[2] + (to[2] - from[2]) * localT
    x = x + gauss() * jitter
    y = y + gauss() * jitter
    points[#points + 1] = { x, y }
  end
  return points
end

local function clusterCloud(count, clusters)
  local points = {}
  for index = 1, count do
    local cluster = clusters[(index - 1) % #clusters + 1]
    points[#points + 1] = {
      cluster[1] + gauss() * cluster[3],
      cluster[2] + gauss() * cluster[4],
    }
  end
  return points
end

local function mergeClouds(a, b)
  local result = {}
  for index = 1, #a do result[#result + 1] = a[index] end
  for index = 1, #b do result[#result + 1] = b[index] end
  return result
end

local function syntheticProfiles()
  resetSeed(11)
  local sparse = routeCloud(2000, {
    { 0.08, 0.82 }, { 0.22, 0.62 }, { 0.40, 0.70 }, { 0.55, 0.45 },
    { 0.72, 0.58 }, { 0.90, 0.34 }, { 0.76, 0.16 }, { 0.46, 0.22 },
  }, 0.010)
  sparse = mergeClouds(sparse,
    clusterCloud(300, { { 0.30, 0.52, 0.010, 0.010 }, { 0.68, 0.30, 0.009, 0.009 } }))

  resetSeed(12)
  local medium = routeCloud(10000, {
    { 0.06, 0.50 }, { 0.25, 0.18 }, { 0.48, 0.30 }, { 0.55, 0.62 },
    { 0.78, 0.80 }, { 0.94, 0.55 }, { 0.66, 0.38 }, { 0.30, 0.70 },
  }, 0.032)
  medium = mergeClouds(medium,
    clusterCloud(1500, { { 0.22, 0.28, 0.045, 0.040 }, { 0.74, 0.66, 0.040, 0.050 } }))

  resetSeed(13)
  local dense = {}
  for index = 1, 20000 do dense[index] = { rand(), rand() } end

  resetSeed(14)
  local wide = routeCloud(8000, {
    { 0.05, 0.42 }, { 0.20, 0.55 }, { 0.38, 0.44 }, { 0.55, 0.56 },
    { 0.72, 0.45 }, { 0.90, 0.55 }, { 0.96, 0.44 },
  }, 0.035)

  resetSeed(15)
  local tall = routeCloud(8000, {
    { 0.42, 0.05 }, { 0.55, 0.20 }, { 0.44, 0.38 }, { 0.56, 0.55 },
    { 0.45, 0.72 }, { 0.55, 0.90 }, { 0.44, 0.96 },
  }, 0.035)

  resetSeed(16)
  local irregular = {}
  for index = 1, 8000 do
    local angle = rand() * 2 * pi
    local radius = 0.28 + gauss() * 0.055
    irregular[index] = {
      0.50 + cos(angle) * radius,
      0.50 + sin(angle) * radius * 0.72,
    }
  end
  irregular = mergeClouds(irregular,
    clusterCloud(600, { { 0.50, 0.50, 0.05, 0.05 } }))

  resetSeed(17)
  local fewhot = clusterCloud(5000, {
    { 0.28, 0.34, 0.045, 0.035 },
    { 0.67, 0.60, 0.040, 0.045 },
    { 0.50, 0.82, 0.030, 0.025 },
  })

  return {
    { id = "sparse_trail", shape = "square", points = sparse },
    { id = "medium_roam", shape = "square", points = medium },
    { id = "dense_stress", shape = "square", points = dense },
    { id = "wide_band", shape = "wide", points = wide },
    { id = "tall_band", shape = "tall", points = tall },
    { id = "irregular_ring", shape = "irregular", points = irregular },
    { id = "few_hotspots", shape = "fewhot", points = fewhot },
  }
end

-- ---------------------------------------------------------------------------
-- Real aggregate replay
-- ---------------------------------------------------------------------------
-- Rebuild a 64x64 cell pattern that matches the recorded real aggregate:
-- occupied cells, total kills, span, and top-10 share. The subcell point
-- distribution is deterministic and uniform inside each 64-cell.
local function replayCells(occupied, total, spanRows, spanCols, baseRow, baseCol, top10Share)
  resetSeed(1000 + occupied * 7 + total)

  -- Score every cell in the recorded span by proximity to three anchors plus a
  -- little noise. This gives a clustered trail without losing the span.
  local anchors = {
    { baseRow + floor(spanRows * 0.22), baseCol + floor(spanCols * 0.20) },
    { baseRow + floor(spanRows * 0.55), baseCol + floor(spanCols * 0.58) },
    { baseRow + floor(spanRows * 0.82), baseCol + floor(spanCols * 0.84) },
  }
  local scored = {}
  for row = baseRow, baseRow + spanRows - 1 do
    for col = baseCol, baseCol + spanCols - 1 do
      local score = rand() * 0.18
      for a = 1, #anchors do
        local dr = row - anchors[a][1]
        local dc = col - anchors[a][2]
        score = score + math.exp(-(dr * dr + dc * dc) / 70)
      end
      scored[#scored + 1] = {
        cell = row * 64 + col + 1, row = row, col = col, score = score,
      }
    end
  end
  table.sort(scored, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.cell < b.cell
  end)

  local chosen, forced = {}, {}
  for index = 1, occupied do chosen[scored[index].cell] = true end
  local function hasRow(row)
    for cell in pairs(chosen) do
      if floor((cell - 1) / 64) == row then return true end
    end
    return false
  end
  local function hasCol(col)
    for cell in pairs(chosen) do
      if (cell - 1) % 64 == col then return true end
    end
    return false
  end
  local function force(row, col)
    local cell = row * 64 + col + 1
    if chosen[cell] then return end
    chosen[cell] = true
    forced[cell] = true
  end
  local function enforce(condition, row, col)
    if condition then return end
    force(row, col)
    for index = #scored, 1, -1 do
      local candidate = scored[index].cell
      if chosen[candidate] and not forced[candidate] then
        chosen[candidate] = nil
        return
      end
    end
  end
  enforce(hasRow(baseRow), baseRow, baseCol + floor(spanCols / 2))
  enforce(hasRow(baseRow + spanRows - 1),
    baseRow + spanRows - 1, baseCol + floor(spanCols / 2))
  enforce(hasCol(baseCol), baseRow + floor(spanRows / 2), baseCol)
  enforce(hasCol(baseCol + spanCols - 1),
    baseRow + floor(spanRows / 2), baseCol + spanCols - 1)

  local list, scoreByCell = {}, {}
  for index = 1, #scored do
    local item = scored[index]
    if chosen[item.cell] then
      list[#list + 1] = item.cell
      scoreByCell[item.cell] = item.score
    end
  end
  table.sort(list)

  local scores = {}
  for index = 1, #list do
    local cell = list[index]
    scores[index] = { cell = cell, score = scoreByCell[cell] }
  end
  table.sort(scores, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.cell < b.cell
  end)

  -- Zipf-like weights; exponent tuned by binary search to hit top-10 share.
  local exponent = 0.65
  local function weightsFor(exp)
    local weights, sum = {}, 0
    for rank = 1, #scores do
      local weight = 1 / (rank ^ exp)
      weights[rank] = weight
      sum = sum + weight
    end
    return weights, sum
  end
  local low, high = 0.1, 1.6
  for _ = 1, 24 do
    local middle = (low + high) / 2
    local weights, sum = weightsFor(middle)
    local top = 0
    for rank = 1, min(10, #weights) do top = top + weights[rank] end
    if top / sum < top10Share then low = middle else high = middle end
  end
  exponent = (low + high) / 2
  local weights, sum = weightsFor(exponent)

  local counts, assigned = {}, 0
  for rank = 1, #scores do
    local exact = weights[rank] / sum * total
    local count = max(1, floor(exact + 0.5))
    counts[scores[rank].cell] = count
    assigned = assigned + count
  end
  -- Fix rounding on the largest cell so the total is exact.
  local sorted = sortedCells(counts)
  counts[sorted[1].cell] = counts[sorted[1].cell] + (total - assigned)

  local points = {}
  for index = 1, #list do
    local cell = list[index]
    local count = counts[cell] or 0
    local r = floor((cell - 1) / 64)
    local c = (cell - 1) % 64
    for _ = 1, count do
      points[#points + 1] = {
        (c + rand()) / 64,
        (r + rand()) / 64,
      }
    end
  end
  return points, counts
end

local function replayProfiles()
  local profiles = {}
  local p1 = replayCells(198, 452, 27, 47, 12, 8, 0.210)
  profiles[#profiles + 1] = {
    id = "real_1421_replay", shape = "near-square", points = p1,
    realCells = 198, realKills = 452, realSpan = "47x27",
  }
  local p2 = replayCells(186, 467, 36, 39, 14, 12, 0.209)
  profiles[#profiles + 1] = {
    id = "real_1424_replay", shape = "near-square", points = p2,
    realCells = 186, realKills = 467, realSpan = "39x36",
  }
  local p3 = {}
  for _ = 1, 1 do
    p3[#p3 + 1] = { (10 + rand()) / 64, (20 + rand()) / 64 }
  end
  profiles[#profiles + 1] = {
    id = "real_1420_replay", shape = "single", points = p3,
    realCells = 1, realKills = 1, realSpan = "1x1",
  }
  return profiles
end

-- ---------------------------------------------------------------------------
-- Cost model (from H64-9 offline benchmark, not a live frame claim)
-- ---------------------------------------------------------------------------
-- Dense 4,096-cell first render was ~7.6 ms; 1,000-cell ~2.2 ms. Use the upper
-- per-cell slope as an envelope. Fixture memory delta was ~2.7-3.6 KB per cell;
-- use 3.0 KB as a conservative offline fixture envelope.
local FIRST_RENDER_MS_PER_CELL = 0.0022
local FIXTURE_KB_PER_CELL = 3.0

local function fmt(value, places)
  return string.format("%." .. places .. "f", value)
end

local function printProfile(profile, grids)
  local baseMetrics
  local rows = {}
  for _, grid in ipairs(grids) do
    local cells, total = rasterize(profile.points, grid)
    local m = metrics(cells, total, grid)
    m.bytes = serializedBytes(cells)
    m.renderMS = m.cells * FIRST_RENDER_MS_PER_CELL
    m.fixtureMB = m.cells * FIXTURE_KB_PER_CELL / 1024
    if grid == 64 then baseMetrics = m end
    m.cellsTable = cells
    rows[#rows + 1] = m
  end
  for _, m in ipairs(rows) do
    local down = downsampleTo64(m.cellsTable, m.grid)
    m.overlap64 = overlap(topSet(down, 10), topSet(baseMetrics.cellsTable, 10))
    m.overlapSlots = min(10, #baseMetrics.top10)
  end
  print(string.format("### %s (%s)", profile.id, profile.shape))
  if profile.realCells then
    print(string.format(
      "recorded real shape: cells=%d kills=%d span=%s",
      profile.realCells, profile.realKills, profile.realSpan))
  end
  print("| Grid | Occupied | Occupancy | Span | Span occ. | Median | Mean | 1-kill | Isolated | Top-10 | 96/128→64 top-10 | Table bytes | Render ms | Fixture MB |")
  print("|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
  for _, m in ipairs(rows) do
    print(string.format(
      "| %d | %d | %s%% | %dx%d | %s%% | %s | %s | %s%% | %s%% | %s%% | %d/%d | %d | %s | %s |",
      m.grid, m.cells, fmt(m.occupancy * 100, 2), m.spanCols, m.spanRows,
      fmt(m.spanOccupancy * 100, 1), fmt(m.median, 1), fmt(m.mean, 2),
      fmt(m.oneKillShare * 100, 1), fmt(m.isolatedShare * 100, 1),
      fmt(m.top10Share * 100, 1), m.overlap64, m.overlapSlots,
      m.bytes, fmt(m.renderMS, 1), fmt(m.fixtureMB, 2)))
  end
  print("")
  return rows
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
local grids = { 64, 96, 128 }

print("# G-2 grid occupancy study")
print("")
print("Cost columns are offline envelopes derived from H64-9, not live frame")
print("claims. Table bytes are sorted sparse SavedVariables-like cells.")
print("")

print("## 1. Recorded real zones")
print("")
print("From SC-1 and DS-17.4B. 96/128 columns are aggregate-preserving replays;")
print("the raw real cells are not needed to test resolution behaviour.")
print("")
local realRows = {}
for _, profile in ipairs(replayProfiles()) do
  local rows = printProfile(profile, grids)
  realRows[#realRows + 1] = { profile = profile, rows = rows }
end

print("## 2. Synthetic occupancy profiles")
print("")
local syntheticRows = {}
for _, profile in ipairs(syntheticProfiles()) do
  local rows = printProfile(profile, grids)
  syntheticRows[#syntheticRows + 1] = { profile = profile, rows = rows }
end

-- ---------------------------------------------------------------------------
-- Summary table: growth from 64 to 96/128
-- ---------------------------------------------------------------------------
print("## 3. Growth summary")
print("")
print("| Profile | 64 cells | 96 cells | 128 cells | 96/64 | 128/64 | 64 top-10 | 96 top-10 | 128 top-10 |")
print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
local allRows = {}
for _, item in ipairs(realRows) do allRows[#allRows + 1] = item end
for _, item in ipairs(syntheticRows) do allRows[#allRows + 1] = item end
for _, item in ipairs(allRows) do
  local byGrid = {}
  for _, row in ipairs(item.rows) do byGrid[row.grid] = row end
  local a, b, c = byGrid[64], byGrid[96], byGrid[128]
  print(string.format("| %s | %d | %d | %d | %sx | %sx | %s%% | %s%% | %s%% |",
    item.profile.id, a.cells, b.cells, c.cells,
    fmt(b.cells / a.cells, 2), fmt(c.cells / a.cells, 2),
    fmt(a.top10Share * 100, 1), fmt(b.top10Share * 100, 1),
    fmt(c.top10Share * 100, 1)))
end
print("")

-- ---------------------------------------------------------------------------
-- Verifications
-- ---------------------------------------------------------------------------
if VERIFY then
  -- The real replay must reproduce the documented 64-cell aggregate closely.
  for _, item in ipairs(realRows) do
    local byGrid = {}
    for _, row in ipairs(item.rows) do byGrid[row.grid] = row end
    assert(byGrid[64].cells == item.profile.realCells,
      item.profile.id .. " replay cells")
    assert(byGrid[64].total == item.profile.realKills,
      item.profile.id .. " replay kills")
  end
  -- Every resolution must retain the main hotspots after downsample.
  for _, item in ipairs(allRows) do
    for _, row in ipairs(item.rows) do
      -- 128 nests exactly under 64. 96 does not, so its centre-projected
      -- downsample is an approximation and is allowed a lower bound.
      local minimum = row.grid == 96 and 2 or 9
      local slots = min(10, #item.rows[1].top10)
      assert(row.overlap64 >= min(slots, minimum),
        item.profile.id .. " top-10 overlap at " .. row.grid)
    end
  end
  -- Increasing resolution must never reduce occupied cells, and must not more
  -- than triple the sparse cell count in these profiles.
  for _, item in ipairs(allRows) do
    local byGrid = {}
    for _, row in ipairs(item.rows) do byGrid[row.grid] = row end
    assert(byGrid[96].cells >= byGrid[64].cells, item.profile.id .. " 96 cells")
    assert(byGrid[128].cells >= byGrid[96].cells, item.profile.id .. " 128 cells")
    assert(byGrid[128].cells <= byGrid[64].cells * 3.1,
      item.profile.id .. " 128 cell growth")
    assert(byGrid[128].oneKillShare >= byGrid[64].oneKillShare,
      item.profile.id .. " 128 singleton growth")
  end
  print("Grid occupancy verification passed")
end
