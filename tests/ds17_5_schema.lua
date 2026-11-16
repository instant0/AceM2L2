-- DS-17.5 schema/migration prototype.
-- Migrates the local v1 character save to the proposed v2 Journey shape.
-- Offline only; no production code, no network.

local SAVE_PATH = "/mnt/r/AceM2L2.lua"
local NEW_SCHEMA = 2

local function countKeys(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function copyTable(source)
  local target = {}
  for key, value in pairs(source or {}) do
    target[key] = type(value) == "table" and copyTable(value) or value
  end
  return target
end
local function sumValues(t)
  local total = 0
  for _, value in pairs(t or {}) do total = total + (tonumber(value) or 0) end
  return total
end
local function sortedNumberKeys(t)
  local keys = {}
  for key in pairs(t or {}) do keys[#keys + 1] = tonumber(key) or 0 end
  table.sort(keys)
  return keys
end
local function sortedStringKeys(t)
  local keys = {}
  for key in pairs(t or {}) do keys[#keys + 1] = tostring(key) end
  table.sort(keys)
  return keys
end
local function minMaxLevels(mob)
  local minLevel, maxLevel, samples
  for _, context in pairs(mob.contexts or {}) do
    local level = tonumber(context.mobLevel)
    if level and level > 0 then
      samples = (samples or 0) + 1
      if not minLevel or level < minLevel then minLevel = level end
      if not maxLevel or level > maxLevel then maxLevel = level end
    end
  end
  return minLevel or 0, maxLevel or 0, samples or 0
end
local function migrateContexts(mob)
  local list = {}
  for key, context in pairs(mob.contexts or {}) do
    list[#list + 1] = {
      key = tostring(key),
      playerLevel = tonumber(context.playerLevel) or 0,
      mobLevel = tonumber(context.mobLevel) or 0,
      healthBand = 0,
      buffSignature = tostring(context.buffSig or ""),
      groupSize = tonumber(context.groupSize) or 0,
      classification = tostring(context.classification or "normal"),
      difficulty = 0,
      samples = tonumber(context.samples) or 0,
      xpSamples = tonumber(context.samples) or 0,
      sumBase = tonumber(context.sumBase) or 0,
      sumBuffed = tonumber(context.sumBuffed) or 0,
      sumTotal = tonumber(context.sumTotal) or 0,
      minBase = tonumber(context.minBase) or 0,
      maxBase = tonumber(context.maxBase) or 0,
      firstSeen = 0,
      lastSeen = tonumber(context.lastSeen) or 0,
      kills = 0,
      deaths = 0,
      healthLostSum = 0,
      timeToKillSum = 0,
    }
  end
  return list
end

local function loadLocal()
  local env = {}
  local chunk, err = loadfile(SAVE_PATH, "t", env)
  if not chunk then return nil, err end
  local ok, loadErr = pcall(chunk)
  if not ok then return nil, loadErr end
  local root = env.AceM2L2CharDB
  if type(root) ~= "table" or type(root.xpTooltip) ~= "table" then
    return nil, "unexpected shape"
  end
  for id, db in pairs(root.xpTooltip.clients or {}) do
    if type(db) == "table" and type(db.mobs) == "table" then
      return { id = id, db = db, root = root }
    end
  end
  return nil, "no client"
end

local localData, localErr = loadLocal()
print("local_save=" .. (localData and "loaded" or ("missing:" .. tostring(localErr))))
if not localData then
  print("cannot_migrate=true")
  return
end

local db = localData.db
local projectID = localData.id
local sourceCounts = {
  mobs = countKeys(db.mobs),
  areas = countKeys(db.areas),
  areaLevels = countKeys(db.areaLevels),
  instances = countKeys(db.instances),
  levels = countKeys(db.levels),
  deaths = countKeys(db.deaths),
  quests = countKeys(db.quests),
  respawns = countKeys(db.respawns),
  heatmapCells = 0,
  kills = sumValues(db.levels), -- current levels table is kill counts by player level
  mobKills = 0,
  mobXP = 0,
}

local function migrate(db, projectID)
  local mobs = {}
  local zoneMobs = {}
  local instanceMobs = {}
  local mobLevelKnown, zoneOverflow = 0, 0
  local mobKills, mobXP = 0, 0
  for key, mob in pairs(db.mobs or {}) do
    local minLevel, maxLevel, levelSamples = minMaxLevels(mob)
    if levelSamples > 0 then mobLevelKnown = mobLevelKnown + 1 end

    local byPlayerLevel = copyTable(mob.killsAtLevel)
    local byZone = {}
    for _, mapID in ipairs(sortedNumberKeys(mob.killsByMap)) do
      local mapKey = tostring(mapID)
      byZone[mapKey] = {
        kills = tonumber(mob.killsByMap[mapID]) or 0,
        playerLevels = copyTable((mob.killsByAreaLevel or {})[mapID]),
      }
      zoneMobs[mapKey] = (zoneMobs[mapKey] or 0) + 1
    end
    local byInstance = {}
    for _, instanceKey in ipairs(sortedStringKeys(mob.killsByInstance)) do
      byInstance[instanceKey] = {
        kills = tonumber(mob.killsByInstance[instanceKey]) or 0,
        playerLevels = copyTable((mob.killsByInstanceLevel or {})[instanceKey]),
      }
      instanceMobs[instanceKey] = (instanceMobs[instanceKey] or 0) + 1
    end

    local zones = {}
    for mapKey in pairs(byZone) do zones[#zones + 1] = "map:" .. mapKey end
    for instanceKey in pairs(byInstance) do zones[#zones + 1] = "instance:" .. instanceKey end
    if #zones > 4 then
      zoneOverflow = zoneOverflow + 1
      table.sort(zones)
      for index = #zones, 5, -1 do zones[index] = nil end
    end

    local kills = tonumber(mob.kills) or 0
    local xp = tonumber(mob.totalXP) or 0
    mobKills = mobKills + kills
    mobXP = mobXP + xp

    local respawn = nil
    if mob.npcID and type(db.respawns) == "table" and type(db.respawns[mob.npcID]) == "table" then
      respawn = copyTable(db.respawns[mob.npcID])
    end

    mobs[key] = {
      npcID = mob.npcID,
      name = mob.name,
      classification = mob.classification or "normal",
      mobLevelMin = minLevel,
      mobLevelMax = maxLevel,
      mobLevelSamples = levelSamples,
      firstSeen = mob.firstSeen or 0,
      lastSeen = mob.lastSeen or 0,
      kills = kills,
      killXP = xp,
      questXP = 0,
      otherXP = 0,
      xp = xp,
      sessionKills = tonumber(mob.sessionKills) or 0,
      sessionXP = tonumber(mob.sessionXP) or 0,
      sessionXPKnown = mob.sessionXPKnown == true,
      byPlayerLevel = byPlayerLevel,
      byZone = byZone,
      byInstance = byInstance,
      zones = zones,
      contexts = migrateContexts(mob),
      combat = {},
      xpContexts = {},
      presenceSeconds = 0,
      engagedSeconds = 0,
      respawn = respawn,
      migration = {
        sourceKey = tostring(key),
        sourceLevelRangeKnown = levelSamples > 0,
        sourceZoneRefs = #zones,
      },
    }
  end

  local zones = {}
  for _, mapID in ipairs(sortedNumberKeys(db.areas)) do
    local mapKey = tostring(mapID)
    zones[mapKey] = {
      kills = tonumber(db.areas[mapID]) or 0,
      killXP = 0,
      questXP = 0,
      otherXP = 0,
      xp = 0,
      presenceSeconds = 0,
      engagedSeconds = 0,
      deaths = 0,
      sessions = 0,
      uniqueMobs = zoneMobs[mapKey] or 0,
      playerLevels = copyTable((db.areaLevels or {})[mapID]),
    }
  end

  local instances = {}
  for key, instance in pairs(db.instances or {}) do
    instances[tostring(key)] = {
      key = tostring(key),
      name = instance.name,
      instanceID = instance.instanceID,
      mapID = instance.mapID,
      difficultyID = instance.difficultyID,
      instanceType = instance.instanceType,
      kills = tonumber(instance.kills) or 0,
      killXP = tonumber(instance.xp) or 0,
      questXP = 0,
      otherXP = 0,
      xp = tonumber(instance.xp) or 0,
      presenceSeconds = 0,
      engagedSeconds = 0,
      deaths = 0,
      sessions = 0,
      uniqueMobs = instanceMobs[tostring(key)] or 0,
      playerLevels = copyTable(instance.killsAtLevel),
    }
  end

  local levelHistory = {}
  for _, record in pairs(db.levelHistory or {}) do
    local level = tonumber(record.level)
    if level then levelHistory[level] = record end
  end
  local levels = {}
  for _, level in ipairs(sortedNumberKeys(db.levels)) do
    local history = levelHistory[level] or {}
    levels[tostring(level)] = {
      kills = tonumber(db.levels[level]) or 0,
      killXP = 0,
      questXP = 0,
      otherXP = tonumber(history.xpGained) or 0,
      xp = tonumber(history.xpGained) or 0,
      presenceSeconds = tonumber(history.duration) or 0,
      engagedSeconds = 0,
      deaths = 0,
      startedAt = tonumber(history.startedAt) or 0,
      endedAt = tonumber(history.endedAt) or 0,
    }
  end

  local sessions = {}
  if type(db.session) == "table" then
    sessions[1] = {
      startedAt = tonumber(db.session.startedAt) or 0,
      endedAt = 0,
      activeSeconds = 0,
      kills = tonumber(db.session.kills) or 0,
      xp = tonumber(db.session.xp) or 0,
      deaths = 0,
    }
  end

  local heatmaps = {}
  local heatmapCells = 0
  for mapID, heatmap in pairs(db.heatmaps or {}) do
    local cells = {}
    for cell, count in pairs(heatmap.cells or {}) do
      heatmapCells = heatmapCells + 1
      cells[cell] = { kills = tonumber(count) or 0, xp = 0,
        presenceSeconds = 0, engagedSeconds = 0, lastSeen = 0 }
    end
    heatmaps[tostring(mapID)] = {
      gridSize = tonumber(heatmap.gridSize) or 64,
      total = tonumber(heatmap.total) or 0,
      lastSeen = tonumber(heatmap.lastSeen) or 0,
      cells = cells,
    }
  end

  local deaths = {}
  for key, death in pairs(db.deaths or {}) do
    deaths[tostring(key)] = {
      at = tonumber(death.at) or 0,
      mapID = tonumber(death.mapID) or 0,
      x = tonumber(death.x) or 0,
      y = tonumber(death.y) or 0,
      mobKey = nil,
      npcID = nil,
      playerLevel = 0,
      playerHealth = 0,
      playerHealthMax = 0,
      healthBand = 0,
      buffSignature = "",
      groupSize = 0,
      classification = "unknown",
      difficulty = 0,
      combatContextKey = nil,
    }
  end

  local quests = {}
  for key, quest in pairs(db.quests or {}) do
    quests[tostring(key)] = {
      id = quest.id,
      name = quest.name,
      xp = tonumber(quest.totalXP) or 0,
      count = tonumber(quest.count) or 0,
      level = 0,
      mapID = 0,
      playerLevel = 0,
      firstSeen = quest.firstSeen or 0,
      lastSeen = quest.lastSeen or 0,
      lastTurnInAt = quest.lastSeen or 0,
    }
  end

  local respawns = {}
  for key, respawn in pairs(db.respawns or {}) do
    respawns[tostring(key)] = copyTable(respawn)
  end

  return {
    schema = NEW_SCHEMA,
    projectID = projectID,
    interface = 16001,
    mode = "leveling",
    levelCap = 0,
    character = {
      level = 0,
      maxLevel = 0,
      class = nil,
      race = nil,
      faction = nil,
      createdAt = 0,
      playtime = 0,
    },
    journey = {
      mobs = mobs,
      zones = zones,
      instances = instances,
      levels = levels,
      sessions = sessions,
      heatmaps = heatmaps,
      deaths = deaths,
      quests = quests,
      respawns = respawns,
    },
    totals = copyTable(db.totals),
    migration = {
      fromSchema = 1,
      toSchema = NEW_SCHEMA,
      sourceCounts = sourceCounts,
      mobKills = mobKills,
      mobXP = mobXP,
      mobLevelKnown = mobLevelKnown,
      zoneOverflow = zoneOverflow,
      heatmapCells = heatmapCells,
    },
  }
end

collectgarbage("collect")
local heapBefore = collectgarbage("count")
local migrationStart = os.clock() * 1000
local migrated = migrate(db, projectID)
local migrationMs = os.clock() * 1000 - migrationStart
collectgarbage("collect")
local v2HeapMB = (collectgarbage("count") - heapBefore) / 1024
local migratedAgain = migrate(db, projectID)

local function countJourney(record)
  return {
    mobs = countKeys(record.journey.mobs),
    zones = countKeys(record.journey.zones),
    instances = countKeys(record.journey.instances),
    levels = countKeys(record.journey.levels),
    deaths = countKeys(record.journey.deaths),
    quests = countKeys(record.journey.quests),
    respawns = countKeys(record.journey.respawns),
    heatmapCells = (function()
      local n = 0
      for _, heatmap in pairs(record.journey.heatmaps) do n = n + countKeys(heatmap.cells) end
      return n
    end)(),
    mobKills = record.migration.mobKills,
    mobXP = record.migration.mobXP,
  }
end

local a = countJourney(migrated)
local b = countJourney(migratedAgain)
local function same(a, b)
  for key, value in pairs(a) do if b[key] ~= value then return false end end
  return true
end

print(string.format("migrated_schema=%d project=%s migration_ms=%.1f v2_heap_mb=%.2f",
  migrated.schema, tostring(migrated.projectID), migrationMs, v2HeapMB))
print(string.format("source_mobs=%d target_mobs=%d source_areas=%d target_zones=%d source_instances=%d target_instances=%d",
  sourceCounts.mobs, a.mobs, sourceCounts.areas, a.zones, sourceCounts.instances, a.instances))
print(string.format("source_deaths=%d target_deaths=%d source_quests=%d target_quests=%d source_respawns=%d target_respawns=%d heatmap_cells=%d",
  sourceCounts.deaths, a.deaths, sourceCounts.quests, a.quests, sourceCounts.respawns, a.respawns, a.heatmapCells))
print(string.format("mob_kills=%d mob_xp=%d mob_level_known=%d zone_overflow=%d",
  a.mobKills, a.mobXP, migrated.migration.mobLevelKnown, migrated.migration.zoneOverflow))
print(string.format("idempotent=%s", tostring(same(a, b))))
print(string.format("missing_after_migration=presenceSeconds;engagedSeconds;combat;xpContexts;deathAttribution;deathHealth;deathBuffs;deathGroup;heatmapXPTime;characterClassRaceFaction"))

-- Downgrade/future-schema guard prototype.
local function accepts(schema, current)
  return type(schema) == "number" and schema <= current
end
print(string.format("schema2_accepted=%s schema3_rejected=%s",
  tostring(accepts(2, NEW_SCHEMA)), tostring(not accepts(3, NEW_SCHEMA))))

-- Account Knowledge target: defined, not populated.
local knowledge = {
  schema = 1,
  projectID = projectID,
  interface = 16001,
  levelCap = 0,
  mode = "leveling",
  mobs = {},
  zones = {},
  instances = {},
  heatmaps = {},
  quests = {},
}
print(string.format("knowledge_target_defined=true mobs=%d zones=%d heatmaps=%d merge_implemented=false",
  countKeys(knowledge.mobs), countKeys(knowledge.zones), countKeys(knowledge.heatmaps)))
print("backup_required=true downgrade_blocks_newer_schema=true no_production_code=true no_online=true")
