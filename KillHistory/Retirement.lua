--[[---------------------------------------------------------------------------------
  KillHistory/Retirement.lua
  Offline retirement readiness inventory and live-gate blockers.
  S10C-1 does not remove writes; it proves what remains before live removal.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory

local LIVE_GATES = { "v2a", "v2b", "v2c", "v2d" }

local function countKeys(value)
  local count = 0
  if type(value) == "table" then
    for _ in pairs(value) do count = count + 1 end
  end
  return count
end

local function countArray(value)
  return type(value) == "table" and #value or 0
end

function XPTooltip:GetRetirementRootInventory()
  local db = type(self.char) == "table" and self.char or {}
  local journey = type(db.journey) == "table" and db.journey or {}
  local legacy = {
    mobs = countKeys(db.mobs),
    zones = countKeys(db.areas),
    levels = countKeys(db.levels),
    instances = countKeys(db.instances),
    deaths = countArray(db.deaths),
    quests = countKeys(db.quests),
    respawns = countKeys(db.respawns),
    heatmaps = countKeys(db.heatmaps),
  }
  local v2 = {
    mobs = countKeys(journey.mobs),
    zones = countKeys(journey.zones),
    levels = countKeys(journey.levels),
    instances = countKeys(journey.instances),
    deaths = countArray(journey.deaths),
    quests = countKeys(journey.quests),
    respawns = countKeys(journey.respawns),
    heatmaps = countKeys(journey.heatmaps),
  }
  local legacyTotal, v2Total = 0, 0
  for _, key in ipairs({ "mobs", "zones", "levels", "instances",
    "deaths", "quests", "respawns", "heatmaps" }) do
    legacyTotal = legacyTotal + legacy[key]
    v2Total = v2Total + v2[key]
  end
  return {
    legacy = legacy,
    v2 = v2,
    legacyTotal = legacyTotal,
    v2Total = v2Total,
    blocks = countKeys(journey.blocks),
    blockIndex = countKeys(journey.blockIndex),
  }
end

function XPTooltip:GetRetirementRestorePath()
  local backup = type(self.GetMigrationBackup) == "function"
    and self:GetMigrationBackup() or nil
  if type(backup) ~= "table" then
    return { hasBackup = false, restorable = false }
  end
  return {
    hasBackup = true,
    restorable = type(backup.data) == "table" and next(backup.data) ~= nil,
    createdAt = tonumber(backup.createdAt) or 0,
    storageSchema = tonumber(backup.storageSchema) or 0,
    stranded = backup.stranded == true,
  }
end

function XPTooltip:GetRetirementReadiness()
  local journey = type(self.char) == "table"
    and type(self.char.journey) == "table" and self.char.journey or {}
  local evidence = type(journey.retirementEvidence) == "table"
    and journey.retirementEvidence or {}
  local live = type(journey.liveEvidence) == "table"
    and journey.liveEvidence or {}
  local roots = self:GetRetirementRootInventory()
  local restore = self:GetRetirementRestorePath()
  local gates, blockers = {}, {}
  for _, key in ipairs(LIVE_GATES) do
    local captured = type(live[key]) == "table" and tonumber(live[key].at) or nil
    gates[key] = evidence[key] == true or captured ~= nil
    if not gates[key] then blockers[#blockers + 1] = "live:" .. key end
  end
  if roots.legacyTotal > 0 then blockers[#blockers + 1] = "legacy-roots-present" end
  if not restore.hasBackup then blockers[#blockers + 1] = "migration-backup-missing" end
  blockers[#blockers + 1] = "dual-writes-active"
  blockers[#blockers + 1] = "quest-name-ledger"
  return {
    ready = false,
    stage = "S10C-1",
    nextStage = "S10C-2",
    gates = gates,
    blockers = blockers,
    roots = roots,
    restore = restore,
    questNameSource = "legacy-ledger",
  }
end
