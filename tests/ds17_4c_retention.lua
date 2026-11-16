-- DS-17.4C retention/aggregation compatibility prototype.
-- Offline only. No network, no production code.

local function clockMs() return os.clock() * 1000 end
local function countKeys(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

local function varint(value)
  value = math.floor(tonumber(value) or 0)
  if value < 0 then value = 0 end
  local parts = {}
  repeat
    local byte = value % 128
    value = math.floor(value / 128)
    if value > 0 then byte = byte + 128 end
    parts[#parts + 1] = string.char(byte)
  until value == 0
  return table.concat(parts)
end

local function readVarint(text, position)
  local value, shift = 0, 1
  while true do
    local byte = string.byte(text, position)
    if not byte then error("truncated varint") end
    position = position + 1
    value = value + (byte % 128) * shift
    if byte < 128 then return value, position end
    shift = shift * 128
    if shift > 2 ^ 52 then error("varint too large") end
  end
end

local function checksum(text)
  local sum = #text % 65521
  for index = 1, #text do
    sum = (sum + string.byte(text, index) * (index % 251 + 1)) % 65521
  end
  return sum
end

local function classCode(name)
  local map = { normal = 1, elite = 2, rare = 3, worldboss = 4 }
  return map[name] or 0
end

-- ---------------------------------------------------------------------------
-- Build synthetic mob contexts
-- ---------------------------------------------------------------------------

local MOBS = 10000
local PER_MOB = 12

local function buildMobs()
  local mobs = {}
  local totalKills, totalXP = 0, 0
  for mobIndex = 1, MOBS do
    local contexts = {}
    local mobKills, mobXP = 0, 0
    for contextIndex = 1, PER_MOB do
      local common = contextIndex <= 6
      local playerLevel = common and (10 + contextIndex % 50) or (1 + (mobIndex + contextIndex) % 60)
      local mobLevel = common and (10 + mobIndex % 10) or (1 + (mobIndex + contextIndex * 3) % 60)
      local healthBand = common and (contextIndex % 2 + 4) or (1 + contextIndex % 5)
      local buffSig = common and ("b" .. (contextIndex % 2 + 1)) or ("b" .. (contextIndex % 8 + 1))
      local groupSize = common and (contextIndex % 2 + 1) or (1 + contextIndex % 5)
      local classification = common and "normal" or ({"normal", "elite", "rare", "worldboss"})[1 + contextIndex % 4]
      local difficulty = common and 1 or (1 + contextIndex % 3)
      local kills = common and (10 + contextIndex * 3) or (1 + (mobIndex + contextIndex) % 5)
      local deaths = (contextIndex % 7 == 0) and 1 or 0
      local xp = kills * (40 + mobLevel)
      contexts[#contexts + 1] = {
        playerLevel = playerLevel, mobLevel = mobLevel, healthBand = healthBand,
        buffSig = buffSig, groupSize = groupSize, classification = classification,
        difficulty = difficulty, kills = kills, deaths = deaths, xp = xp,
        healthLost = (contextIndex % 5) * 0.1, timeToKill = 5 + contextIndex,
      }
      mobKills = mobKills + kills
      mobXP = mobXP + xp
    end
    mobs[#mobs + 1] = {
      key = "npc:" .. (100000 + mobIndex * 3),
      name = string.format("Mob %06d", mobIndex),
      levelMin = 10 + mobIndex % 10, levelMax = 12 + mobIndex % 10,
      zones = { "map:" .. (mobIndex % 200 + 1) },
      contexts = contexts, kills = mobKills, xp = mobXP,
    }
    totalKills = totalKills + mobKills
    totalXP = totalXP + mobXP
  end
  return mobs, totalKills, totalXP
end

local function sortContexts(contexts)
  local list = {}
  for _, context in ipairs(contexts) do list[#list + 1] = context end
  table.sort(list, function(a, b) return (a.kills or 0) > (b.kills or 0) end)
  return list
end

local function otherAggregate(contexts)
  local other = {
    playerLevel = 0, mobLevel = 0, healthBand = 0, buffSig = "other",
    groupSize = 0, classification = "mixed", difficulty = 0,
    kills = 0, deaths = 0, xp = 0, healthLost = 0, timeToKill = 0,
    samples = 0,
  }
  local healthWeighted, timeWeighted = 0, 0
  for _, context in ipairs(contexts) do
    other.kills = other.kills + (context.kills or 0)
    other.deaths = other.deaths + (context.deaths or 0)
    other.xp = other.xp + (context.xp or 0)
    healthWeighted = healthWeighted + (context.healthLost or 0) * (context.kills or 0)
    timeWeighted = timeWeighted + (context.timeToKill or 0) * (context.kills or 0)
    other.samples = other.samples + (context.kills or 0) + (context.deaths or 0)
  end
  if other.kills > 0 then
    other.healthLost = healthWeighted / other.kills
    other.timeToKill = timeWeighted / other.kills
  end
  return other
end

local function retain(mobs, topN, withOther)
  local retained = {}
  for _, mob in ipairs(mobs) do
    local sorted = sortContexts(mob.contexts)
    local keep = {}
    for index = 1, math.min(topN, #sorted) do keep[index] = sorted[index] end
    if withOther and #sorted > topN then
      local tail = {}
      for index = topN + 1, #sorted do tail[#tail + 1] = sorted[index] end
      keep[#keep + 1] = otherAggregate(tail)
    end
    retained[#retained + 1] = { key = mob.key, contexts = keep }
  end
  return retained
end

local function coverage(mobs, retained)
  local totalKills, totalXP, keptKills, keptXP = 0, 0, 0, 0
  local detailKills, detailXP = 0, 0
  for index, mob in ipairs(mobs) do
    totalKills = totalKills + mob.kills
    totalXP = totalXP + mob.xp
    for _, context in ipairs(retained[index].contexts) do
      keptKills = keptKills + (context.kills or 0)
      keptXP = keptXP + (context.xp or 0)
      if context.buffSig ~= "other" then
        detailKills = detailKills + (context.kills or 0)
        detailXP = detailXP + (context.xp or 0)
      end
    end
  end
  return totalKills, totalXP, keptKills, keptXP, detailKills, detailXP
end

local function aggregateDanger(mob)
  local kills, deaths, healthWeighted, timeWeighted = 0, 0, 0, 0
  for _, context in ipairs(mob.contexts or mob) do
    kills = kills + (context.kills or 0)
    deaths = deaths + (context.deaths or 0)
    healthWeighted = healthWeighted + (context.healthLost or 0) * (context.kills or 0)
    timeWeighted = timeWeighted + (context.timeToKill or 0) * (context.kills or 0)
  end
  return kills, deaths,
    kills > 0 and healthWeighted / kills or 0,
    kills > 0 and timeWeighted / kills or 0
end

local function dangerVerdict(kills, deaths, healthLost)
  local samples = kills + deaths
  if samples < 20 then return "not_enough_data" end
  local rate = samples > 0 and deaths / samples or 0
  if rate > 0.2 then return "dangerous" end
  if rate < 0.05 and healthLost < 0.2 then return "safe_or_slaughter" end
  return "mixed"
end

-- ---------------------------------------------------------------------------
-- Table retention
-- ---------------------------------------------------------------------------

collectgarbage("collect")
local buildStart = clockMs()
local mobs, totalKills, totalXP = buildMobs()
local buildMs = clockMs() - buildStart

local function heapOf(fn)
  collectgarbage("collect")
  local before = collectgarbage("count")
  local value = fn()
  collectgarbage("collect")
  local after = collectgarbage("count")
  return (after - before) / 1024, value
end

print(string.format("mobs=%d contexts_per_mob=%d total_kills=%d total_xp=%d build_ms=%.1f",
  MOBS, PER_MOB, totalKills, totalXP, buildMs))

local variants = {
  { name = "full", topN = PER_MOB, other = false },
  { name = "top8", topN = 8, other = false },
  { name = "top8_other", topN = 8, other = true },
  { name = "top4", topN = 4, other = false },
  { name = "top4_other", topN = 4, other = true },
}

for _, variant in ipairs(variants) do
  local heap, retained = heapOf(function() return retain(mobs, variant.topN, variant.other) end)
  local tKills, tXP, keptKills, keptXP, detailKills, detailXP = coverage(mobs, retained)
  local dangerMatches, dangerChecked = 0, 0
  for index = 1, math.min(1000, #mobs) do
    local fk, fd, fh = aggregateDanger(mobs[index].contexts)
    local rk, rd, rh = aggregateDanger(retained[index].contexts)
    if dangerVerdict(fk, fd, fh) == dangerVerdict(rk, rd, rh) then
      dangerMatches = dangerMatches + 1
    end
    dangerChecked = dangerChecked + 1
  end
  print(string.format("retention=%s heap_mb=%.2f total_coverage_kills=%.3f total_coverage_xp=%.3f detail_coverage_kills=%.3f detail_coverage_xp=%.3f danger_verdict_match=%.3f",
    variant.name, heap,
    tKills > 0 and keptKills / tKills or 0,
    tXP > 0 and keptXP / tXP or 0,
    tKills > 0 and detailKills / tKills or 0,
    tXP > 0 and detailXP / tXP or 0,
    dangerChecked > 0 and dangerMatches / dangerChecked or 0))
  retained = nil
  collectgarbage("collect")
end

-- ---------------------------------------------------------------------------
-- Packed context retention
-- ---------------------------------------------------------------------------

local function encodeContexts(contexts)
  local parts = { varint(#contexts) }
  for _, context in ipairs(contexts) do
    parts[#parts + 1] = varint(context.playerLevel or 0)
    parts[#parts + 1] = varint(context.mobLevel or 0)
    parts[#parts + 1] = varint(context.healthBand or 0)
    local buff = context.buffSig or ""
    parts[#parts + 1] = varint(#buff); parts[#parts + 1] = buff
    parts[#parts + 1] = varint(context.groupSize or 0)
    parts[#parts + 1] = varint(classCode(context.classification))
    parts[#parts + 1] = varint(context.difficulty or 0)
    parts[#parts + 1] = varint(context.kills or 0)
    parts[#parts + 1] = varint(context.deaths or 0)
    parts[#parts + 1] = varint(context.xp or 0)
    parts[#parts + 1] = varint(math.floor((context.healthLost or 0) * 100))
    parts[#parts + 1] = varint(context.timeToKill or 0)
  end
  return table.concat(parts)
end

local function encodeMobs(mobs, topN, withOther)
  local parts = { varint(#mobs), varint(topN), varint(withOther and 1 or 0) }
  for _, mob in ipairs(mobs) do
    local sorted = sortContexts(mob.contexts)
    local keep = {}
    for index = 1, math.min(topN, #sorted) do keep[#keep + 1] = sorted[index] end
    if withOther and #sorted > topN then
      local tail = {}
      for index = topN + 1, #sorted do tail[#tail + 1] = sorted[index] end
      keep[#keep + 1] = otherAggregate(tail)
    end
    parts[#parts + 1] = varint(#mob.key); parts[#parts + 1] = mob.key
    parts[#parts + 1] = encodeContexts(keep)
  end
  return table.concat(parts)
end

for _, variant in ipairs({
  { name = "packed_full", topN = PER_MOB, other = false },
  { name = "packed_top8_other", topN = 8, other = true },
}) do
  local start = clockMs()
  local packed = encodeMobs(mobs, variant.topN, variant.other)
  local encodeMs = clockMs() - start
  local checksumStart = clockMs()
  local sum = checksum(packed)
  local checksumMs = clockMs() - checksumStart
  local middle = math.max(1, math.floor(#packed / 2))
  local byte = string.byte(packed, middle)
  local corrupted = packed:sub(1, middle - 1) .. string.char((byte + 1) % 256) .. packed:sub(middle + 1)
  assert(checksum(corrupted) ~= sum, "corruption not detected")
  local ok = pcall(function() return readVarint(packed, #packed + 1) end)
  print(string.format("retention=%s packed_bytes=%d packed_mb=%.2f encode_ms=%.1f checksum_ms=%.1f corruption_detected=true truncation_detected=%s",
    variant.name, #packed, #packed / 1024 / 1024, encodeMs, checksumMs, tostring(not ok)))
end

-- ---------------------------------------------------------------------------
-- Zone/level active-time preservation
-- ---------------------------------------------------------------------------

local zones = {
  { name = "Zone A", levels = {
    [20] = { kills = 500, xp = 100000, activeSeconds = 3600, deaths = 2 },
    [21] = { kills = 400, xp = 80000, activeSeconds = 3000, deaths = 1 },
  } },
  { name = "Zone B", levels = {
    [20] = { kills = 900, xp = 200000, activeSeconds = 7200, deaths = 4 },
  } },
}
local function zoneTotals(zonesData)
  local kills, xp, active, deaths = 0, 0, 0, 0
  for _, zone in ipairs(zonesData) do
    for _, row in pairs(zone.levels) do
      kills = kills + row.kills; xp = xp + row.xp
      active = active + row.activeSeconds; deaths = deaths + row.deaths
    end
  end
  return kills, xp, active, deaths
end
local k1, x1, a1, d1 = zoneTotals(zones)
local copied = {}
for _, zone in ipairs(zones) do
  local entry = { name = zone.name, levels = {} }
  for level, row in pairs(zone.levels) do
    entry.levels[level] = { kills = row.kills, xp = row.xp,
      activeSeconds = row.activeSeconds, deaths = row.deaths }
  end
  copied[#copied + 1] = entry
end
local k2, x2, a2, d2 = zoneTotals(copied)
print(string.format("zone_preserved=%s kills=%d->%d xp=%d->%d active=%d->%d deaths=%d->%d",
  tostring(k1 == k2 and x1 == x2 and a1 == a2 and d1 == d2), k1, k2, x1, x2, a1, a2, d1, d2))

-- ---------------------------------------------------------------------------
-- Heatmap retention: sparse normal + dense stress
-- ---------------------------------------------------------------------------

local function makeGrid(size, density)
  local cells = {}
  local target = math.max(1, math.floor(size * size * density))
  local total = 0
  local index = 0
  while index < target do
    index = index + 1
    local cell = (index * 37 + index * index * 13) % (size * size) + 1
    local value = (index % 20) + 1
    cells[cell] = (cells[cell] or 0) + value
    total = total + value
  end
  return cells, total
end

local function topCells(cells, limit)
  local list = {}
  for cell, value in pairs(cells) do list[#list + 1] = { cell = cell, value = value } end
  table.sort(list, function(a, b) return a.value > b.value end)
  local top = {}
  for index = 1, math.min(limit, #list) do top[list[index].cell] = index end
  return top
end

local function downsample(cells, fromSize, toSize)
  local result = {}
  local ratio = fromSize / toSize
  for cell, value in pairs(cells) do
    local x = (cell - 1) % fromSize
    local y = math.floor((cell - 1) / fromSize)
    local tx = math.floor(x / ratio)
    local ty = math.floor(y / ratio)
    local target = ty * toSize + tx + 1
    result[target] = (result[target] or 0) + value
  end
  return result
end

for _, density in ipairs({0.005, 0.03, 0.05, 0.15, 0.30}) do
  local cells, total = makeGrid(64, density)
  local occupied = countKeys(cells)
  local top = topCells(cells, 10)
  local overlap32, overlap16
  local reduced32 = downsample(cells, 64, 32)
  local reduced16 = downsample(cells, 64, 16)
  local top32 = topCells(reduced32, 10)
  local top16 = topCells(reduced16, 10)
  local c32, c16 = 0, 0
  for cell in pairs(top) do
    local x = (cell - 1) % 64
    local y = math.floor((cell - 1) / 64)
    local t32 = math.floor(y / 2) * 32 + math.floor(x / 2) + 1
    local t16 = math.floor(y / 4) * 16 + math.floor(x / 4) + 1
    if top32[t32] then c32 = c32 + 1 end
    if top16[t16] then c16 = c16 + 1 end
  end
  local sum32, sum16 = 0, 0
  for _, value in pairs(reduced32) do sum32 = sum32 + value end
  for _, value in pairs(reduced16) do sum16 = sum16 + value end
  print(string.format("heatmap_density=%.3f occupied=%d total=%d cells32=%d sum32=%d cells16=%d sum16=%d top10_overlap32=%d top10_overlap16=%d",
    density, occupied, total, countKeys(reduced32), sum32, countKeys(reduced16), sum16, c32, c16))
end

-- ---------------------------------------------------------------------------
-- Aggregation compatibility
-- ---------------------------------------------------------------------------

local knowledgeKills, knowledgeXP = 0, 0
for _, mob in ipairs(mobs) do
  knowledgeKills = knowledgeKills + mob.kills
  knowledgeXP = knowledgeXP + mob.xp
end
print(string.format("knowledge_from_cold_kills=%d/%d xp=%d/%d ok=%s",
  knowledgeKills, totalKills, knowledgeXP, totalXP,
  tostring(knowledgeKills == totalKills and knowledgeXP == totalXP)))
print("backup_restore_required=true downgrade_blocks_newer_schema=true")
print("no_merge_implemented=true no_ui=true no_online=true")
