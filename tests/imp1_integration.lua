-- IMP-1 integration slice.
-- Connects v2 Journey fields, event-driven time, quest anchors, blocks, and queries.
-- Offline only; no production code.

local SAVE_PATH = "/mnt/r/AceM2L2.lua"
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, #B64 do B64_INDEX[B64:sub(i, i)] = i - 1 end
local function base64Encode(text)
  local out = {}
  for i = 1, #text, 3 do
    local a = string.byte(text, i) or 0
    local b = string.byte(text, i + 1) or 0
    local c = string.byte(text, i + 2) or 0
    local value = a * 65536 + b * 256 + c
    local c1 = math.floor(value / 262144) % 64
    local c2 = math.floor(value / 4096) % 64
    local c3 = math.floor(value / 64) % 64
    local c4 = value % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (i + 1 <= #text and B64:sub(c3 + 1, c3 + 1) or "=")
      .. (i + 2 <= #text and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end
local function base64Decode(text)
  text = text:gsub("[^" .. B64 .. "=]", "")
  local out = {}
  for i = 1, #text, 4 do
    local c1 = B64_INDEX[text:sub(i, i)] or 0
    local c2 = B64_INDEX[text:sub(i + 1, i + 1)] or 0
    local c3 = B64_INDEX[text:sub(i + 2, i + 2)]
    local c4 = B64_INDEX[text:sub(i + 3, i + 3)]
    local value = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
    out[#out + 1] = string.char(math.floor(value / 65536) % 256)
    if c3 then out[#out + 1] = string.char(math.floor(value / 256) % 256) end
    if c4 then out[#out + 1] = string.char(value % 256) end
  end
  return table.concat(out)
end
local function checksum(text)
  local sum = #text % 65521
  for i = 1, #text do sum = (sum + string.byte(text, i) * (i % 251 + 1)) % 65521 end
  return sum
end
local function clockMs() return os.clock() * 1000 end
local function countKeys(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end

local env = {}
local chunk, err = loadfile(SAVE_PATH, "t", env)
if not chunk then
  print("local_save=missing:" .. tostring(err))
  return
end
assert(pcall(chunk))
local db = env.AceM2L2CharDB.xpTooltip.clients[18]
if not db then print("local_save=no_client"); return end

-- ---------------------------------------------------------------------------
-- Build v2-ish mob records and per-zone blocks
-- ---------------------------------------------------------------------------

local mobs = {}
local blocks = {}
local mobBlock = {}
local zoneRecords = {}
for key, mob in pairs(db.mobs or {}) do
  local record = {
    key = tostring(key),
    npcID = mob.npcID,
    name = mob.name or ("NPC " .. tostring(mob.npcID or "?")),
    classification = mob.classification or "normal",
    kills = tonumber(mob.kills) or 0,
    xp = tonumber(mob.totalXP) or 0,
    zones = {},
  }
  for mapKey in pairs(mob.killsByMap or {}) do
    record.zones[#record.zones + 1] = "map:" .. tostring(mapKey)
  end
  for instanceKey in pairs(mob.killsByInstance or {}) do
    record.zones[#record.zones + 1] = "instance:" .. tostring(instanceKey)
  end
  if #record.zones > 4 then
    table.sort(record.zones)
    for i = #record.zones, 5, -1 do record.zones[i] = nil end
  end
  mobs[record.key] = record
  local mapKey = nil
  for ref in pairs(record.zones) do
    local refValue = record.zones[ref]
    if refValue:match("^map:") then mapKey = refValue:sub(5); break end
  end
  if mapKey then
    mobBlock[record.key] = mapKey
    blocks[mapKey] = blocks[mapKey] or {}
    blocks[mapKey][#blocks[mapKey] + 1] = record
    local zone = zoneRecords[mapKey] or { mapID = mapKey, mobs = 0, kills = 0, xp = 0 }
    zone.mobs = zone.mobs + 1
    zone.kills = zone.kills + record.kills
    zone.xp = zone.xp + record.xp
    zoneRecords[mapKey] = zone
  end
end

local encoded = {}
local encodedBytes = 0
for mapKey, list in pairs(blocks) do
  local parts = {}
  for _, record in ipairs(list) do
    parts[#parts + 1] = string.format("%s|%d|%d\n", record.key, record.kills, record.xp)
  end
  local raw = table.concat(parts)
  encoded[mapKey] = { base64 = base64Encode(raw), checksum = checksum(raw) }
  encodedBytes = encodedBytes + #encoded[mapKey].base64
end
print(string.format("local_mobs=%d zone_blocks=%d zone_mobs=%d encoded_kb=%.1f",
  countKeys(mobs), countKeys(blocks), (function()
    local n=0; for _, z in pairs(zoneRecords) do n=n+z.mobs end; return n
  end)(), encodedBytes / 1024))

-- Login loads encoded blocks but decodes none.
local decodedBlocks = 0
local function decodeZone(mapKey)
  local entry = encoded[mapKey]
  if not entry then return nil, "missing" end
  local raw = base64Decode(entry.base64)
  if checksum(raw) ~= entry.checksum then return nil, "checksum" end
  local records = {}
  for line in raw:gmatch("[^\n]+") do
    local key, kills, xp = line:match("^([^|]+)|(%d+)|(%d+)$")
    if key then records[key] = { kills = tonumber(kills), xp = tonumber(xp) } end
  end
  decodedBlocks = decodedBlocks + 1
  return records
end
print("login_decoded_blocks=0")

local selectedMap = "1424"
local start = clockMs()
local selected = decodeZone(selectedMap)
assert(selected)
local decodeMs = clockMs() - start
local lookupStart = clockMs()
local lookups = 0
for key, record in pairs(selected) do
  assert(mobs[key] and mobs[key].name)
  lookups = lookups + 1
end
local lookupMs = clockMs() - lookupStart
print(string.format("selected_zone=%s decode_ms=%.2f records=%d lookup_ms=%.2f decoded_blocks=%d",
  selectedMap, decodeMs, lookups, lookupMs, decodedBlocks))

-- ---------------------------------------------------------------------------
-- Event-driven time + quest anchor
-- ---------------------------------------------------------------------------

local function newTimeTracker(cap)
  return { presenceSeconds=0, engagedSeconds=0, lastEventAt=nil, lastKillAt=nil,
    zone=nil, level=nil, cap=cap or 60 }
end
local function closePresence(t, now)
  if t.lastEventAt and now >= t.lastEventAt then
    t.presenceSeconds = t.presenceSeconds + (now - t.lastEventAt)
  end
  t.lastEventAt = now
end
local function onZone(t, zone, level, now)
  closePresence(t, now); t.zone=zone; t.level=level; t.lastKillAt=now
end
local function onKill(t, now)
  closePresence(t, now)
  if t.lastKillAt then t.engagedSeconds = t.engagedSeconds + math.min(now - t.lastKillAt, t.cap) end
  t.lastKillAt = now
end
local function onQuestTurnIn(t, now, xp)
  closePresence(t, now) -- anchor presence only; not engaged kill time
  return tonumber(xp) or 0
end

local timeTracker = newTimeTracker(60)
onZone(timeTracker, "map:1424", 20, 100)
onKill(timeTracker, 110)
onKill(timeTracker, 170)
local questXP = onQuestTurnIn(timeTracker, 230, 1150)
onKill(timeTracker, 260)
print(string.format("event_time presence_s=%d engaged_s=%d quest_xp=%d timer_used=false",
  timeTracker.presenceSeconds, timeTracker.engagedSeconds, questXP))

-- ---------------------------------------------------------------------------
-- Best-zone XP/hour (total vs kill-only) with quest XP
-- ---------------------------------------------------------------------------

local zones = {
  { name="Zone A", level=20, killXP=100000, questXP=0, presenceSeconds=3600, engagedSeconds=3000, kills=500 },
  { name="Zone B", level=20, killXP=250000, questXP=0, presenceSeconds=7200, engagedSeconds=3600, kills=900 },
  { name="Zone C", level=20, killXP=50000, questXP=50000, presenceSeconds=1800, engagedSeconds=1200, kills=180 },
  { name="Zone D", level=20, killXP=500000, questXP=0, presenceSeconds=36000, engagedSeconds=30000, kills=3000 },
}
local function rank(mode)
  local rows = {}
  for _, zone in ipairs(zones) do
    local xp = mode == "kill" and zone.killXP or (zone.killXP + zone.questXP)
    local hours = zone.engagedSeconds / 3600
    rows[#rows + 1] = { name=zone.name, xph=xp/hours, mode=mode,
      killXph=zone.killXP/hours }
  end
  table.sort(rows, function(a,b) return a.xph > b.xph end)
  return rows
end
for _, mode in ipairs({"total","kill"}) do
  local rows = rank(mode)
  print(string.format("best_zone_mode=%s rank1=%s xp_per_hour=%.0f kill_xp_per_hour=%.0f",
    mode, rows[1].name, rows[1].xph, rows[1].killXph))
end

-- ---------------------------------------------------------------------------
-- Heatmap top cells from local data
-- ---------------------------------------------------------------------------

local mapID, heatmap = nil, nil
for key, value in pairs(db.heatmaps or {}) do
  if type(value.cells) == "table" and countKeys(value.cells) > 10 then mapID, heatmap = key, value; break end
end
if heatmap then
  local list = {}
  for cell, count in pairs(heatmap.cells) do list[#list+1]={cell=cell,count=tonumber(count) or 0} end
  table.sort(list, function(a,b) return a.count > b.count end)
  local top = 0
  for i=1,math.min(10,#list) do top = top + list[i].count end
  local total = 0; for _, v in pairs(heatmap.cells) do total = total + (tonumber(v) or 0) end
  print(string.format("heatmap_map=%s cells=%d top10_share=%.3f total=%d",
    tostring(mapID), #list, total > 0 and top/total or 0, total))
else
  print("heatmap_top=unavailable")
end

-- ---------------------------------------------------------------------------
-- Danger query by combat context
-- ---------------------------------------------------------------------------

local danger = {
  { context="solo healthy", kills=400, deaths=4 },
  { context="solo low health", kills=60, deaths=30 },
  { context="sparse", kills=2, deaths=0 },
}
for _, row in ipairs(danger) do
  local samples = row.kills + row.deaths
  local rate = samples > 0 and row.deaths/samples or 0
  local verdict = samples < 20 and "not_enough_data"
    or (rate > 0.2 and "dangerous" or (rate < 0.05 and "safe_or_slaughter" or "mixed"))
  print(string.format("danger_context=%s samples=%d death_rate=%.3f verdict=%s",
    row.context, samples, rate, verdict))
end

-- ---------------------------------------------------------------------------
-- Missing/corrupt fallback
-- ---------------------------------------------------------------------------

assert(decodeZone("9999") == nil)
local saved = encoded[selectedMap].base64
encoded[selectedMap].base64 = saved:sub(1, math.max(1,#saved-4)) .. "AAAA"
assert(decodeZone(selectedMap) == nil)
encoded[selectedMap].base64 = saved
print("missing_block_fallback=true corrupt_block_rejected=true no_full_scan=true")
print("quest_state_in_mob_context=false quest_anchor_engaged=false merge_implemented=false no_ui=true no_online=true")
