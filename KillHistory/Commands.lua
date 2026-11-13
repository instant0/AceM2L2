--[[--------------------------------------------------------------------------------
  KillHistory/Commands.lua
  Slash-command handling, chat output, resets, and entry deletion commands.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util
local UI = XPTooltip.UI

local floor, min, max = math.floor, math.min, math.max
local THEMES = UI.THEMES
local CALIBRATION_VERSION = Util.CALIBRATION_VERSION
local DEFAULT_MINIMAP = Util.DEFAULT_MINIMAP
local Trim = Util.Trim
local Lower = Util.Lower
local IsSecret = Util.IsSecret
local SafeCall = Util.SafeCall
local SafeBool = Util.SafeBool
local FormatNumber = Util.FormatNumber
local FormatPercent = Util.FormatPercent
local FormatAgo = Util.FormatAgo
local FormatDuration = Util.FormatDuration
local FormatDate = Util.FormatDate
local FormatMoney = Util.FormatMoney
local CopyTable = Util.CopyTable
local Epoch = Util.Epoch

function XPTooltip:PrintStatus()
  local compatible, reason, hasProcessor, hasHook = self:CheckCompatibility()
  local profile = self:GetClientProfile()
  AceM2L2:SafePrint("Kill Story: " .. self:GetStatusText())
  AceM2L2:SafePrint("  Client=" .. (profile and profile.id or "unknown")
    .. ", Project=" .. tostring(self:GetProjectID())
    .. ", Mode=" .. (profile and profile:GetStatusLabel() or "unavailable"))
  AceM2L2:SafePrint("  Interface=" .. tostring(AceM2L2:GetInterfaceVersion())
    .. ", supported=" .. tostring(compatible)
    .. ", processor=" .. tostring(hasProcessor)
    .. ", fallback=" .. tostring(hasHook))
  AceM2L2:SafePrint("  Kill tracking=" .. tostring(self:Supports("hasKillTracking"))
    .. ", formula=" .. tostring(self:Supports("hasXPFormula"))
    .. ", perMobXP=" .. tostring(self:Supports("hasPerMobXP"))
    .. ", tooltipXP=" .. tostring(self:Supports("hasTooltipXP")))
  AceM2L2:SafePrint("  Buff detection=" .. tostring(self:CanDetectBuffs()))
  if self.schemaBlocked then
    AceM2L2:SafePrint("  Schema: blocked ("
      .. tostring(self.schemaBlockedReason or "newer schema; read-only") .. ")")
  end
  local backup = self:GetMigrationBackup()
  if backup then
    AceM2L2:SafePrint("  Migration backup: yes (" .. FormatDate(backup.createdAt) .. ")")
  end
  local settings = self:GetSettings()
  local minimap = settings and settings.minimap or {}
  AceM2L2:SafePrint("  Minimap=" .. (minimap.hide and "hidden" or "shown"))
  if not compatible and reason and reason ~= "" then
    AceM2L2:SafePrint("  Reason: " .. reason)
  end
  if self.autoDisabled and self.autoDisableReason and self.autoDisableReason ~= reason then
    AceM2L2:SafePrint("  AutoDisable: " .. tostring(self.autoDisableReason))
  end
  if self.lastError then
    AceM2L2:SafePrint("  LastError: " .. tostring(self.lastError))
  end
end

local function ProbeValue(label, value)
  local text
  if value == nil then
    text = "<nil>"
  elseif IsSecret(value) then
    text = "<secret>"
  else
    text = tostring(value)
  end
  AceM2L2:SafePrint("  " .. label .. "=" .. text)
end

function XPTooltip:PrintProbe()
  local db = self.char
  local economy = db and type(db.economy) == "table" and db.economy or {}
  local profile = self:GetClientProfile()
  AceM2L2:SafePrint("Kill Story probe:")
  ProbeValue("projectID", self:GetProjectID())
  ProbeValue("interface", AceM2L2:GetInterfaceVersion())
  ProbeValue("profile", profile and profile.id or "unknown")
  ProbeValue("mode", profile and profile:GetStatusLabel() or "unavailable")
  ProbeValue("active", self:IsActive())
  ProbeValue("autoDisabled", self.autoDisabled)
  ProbeValue("schemaBlocked", self.schemaBlocked)
  ProbeValue("schemaBlockedReason", self.schemaBlockedReason)
  local backup = self:GetMigrationBackup()
  ProbeValue("migrationBackup", backup ~= nil)
  ProbeValue("migrationBackupAt", backup and backup.createdAt or nil)
  ProbeValue("migrationBackupHasMobs", backup and type(backup.data) == "table"
    and type(backup.data.mobs) == "table" or false)
  ProbeValue("tooltipHook", self.tooltipHookInstalled)

  AceM2L2:SafePrint("  Capabilities (" .. self:GetCapabilitySummary() .. ")")

  local apis = {
    "UnitExists", "UnitName", "UnitGUID", "UnitLevel", "UnitClassification",
    "UnitIsPlayer", "UnitIsDead", "UnitCanAttack", "UnitXP", "UnitXPMax",
    "GetXPExhaustion", "GetMaxPlayerLevel",
  }
  local parts = {}
  for _, name in ipairs(apis) do
    parts[#parts + 1] = name .. "=" .. (type(_G[name]) == "function" and "yes" or "no")
  end
  AceM2L2:SafePrint("  APIs: " .. table.concat(parts, " "))

  local unit
  if SafeBool(SafeCall(UnitExists, "target")) then
    unit = "target"
  elseif SafeBool(SafeCall(UnitExists, "mouseover")) then
    unit = "mouseover"
  end
  if unit then
    ProbeValue("unit", unit)
    ProbeValue("name", SafeCall(UnitName, unit))
    ProbeValue("guid", SafeCall(UnitGUID, unit))
    ProbeValue("level", SafeCall(UnitLevel, unit))
    ProbeValue("classification", SafeCall(UnitClassification, unit))
    ProbeValue("isPlayer", SafeCall(UnitIsPlayer, unit))
    ProbeValue("isDead", SafeCall(UnitIsDead, unit))
    ProbeValue("canAttack", SafeCall(UnitCanAttack, "player", unit))
    ProbeValue("eligible", self:IsUnitEligible(unit))
  else
    AceM2L2:SafePrint("  unit=<none>")
  end
  local currentMapID = self:GetMapID()
  local mapInfo = C_Map and type(C_Map.GetMapInfo) == "function"
    and SafeCall(C_Map.GetMapInfo, currentMapID) or nil
  local mapArtLayers = 0
  if C_Map and type(C_Map.GetMapArtLayers) == "function" then
    local ok, layers = pcall(C_Map.GetMapArtLayers, currentMapID)
    if ok and type(layers) == "table" then
      mapArtLayers = #layers
    end
  end
  ProbeValue("mapID", currentMapID)
  ProbeValue("mapName", self:GetMapName(currentMapID))
  ProbeValue("mapType", type(mapInfo) == "table" and mapInfo.mapType or nil)
  ProbeValue("parentMapID", type(mapInfo) == "table" and mapInfo.parentMapID or nil)
  ProbeValue("mapArtLayers", mapArtLayers)
  ProbeValue("isInDungeon", self:IsInDungeon())
  ProbeValue("groupSize", self:GetGroupSize())
  ProbeValue("maxLevel", self:GetMaxLevel())
  ProbeValue("xp", self:GetXP())
  ProbeValue("xpMax", self:GetXPMax())
  ProbeValue("xpRawDiagnostic", SafeCall(UnitXP, "player"))
  ProbeValue("xpMaxRawDiagnostic", SafeCall(UnitXPMax, "player"))
  ProbeValue("restedPool", self:GetRestedPool())
  ProbeValue("money", self:GetMoney())
  ProbeValue("moneyKnown", economy.moneyKnown)
  ProbeValue("sessionLootValue", economy.sessionLootValue)
  ProbeValue("goldPerHour", self:GetGoldPerHour())
  ProbeValue("lootEventAvailable", self.lootEventAvailable)
  ProbeValue("moneyEventAvailable", self.moneyEventAvailable)
  local deaths = db and type(db.deaths) == "table" and db.deaths or {}
  local respawns = db and type(db.respawns) == "table" and db.respawns or {}
  ProbeValue("deathCount", #deaths)
  local mapPosition
  if type(self.GetPlayerMapPosition) == "function" then
    local ok, _, x, y = pcall(self.GetPlayerMapPosition, self)
    x, y = tonumber(x), tonumber(y)
    if ok and x and y then
      mapPosition = string.format("%.0f,%.0f", x * 100, y * 100)
    end
  end
  ProbeValue("mapPosition", mapPosition)
  local hasMapPositionAPI = false
  if type(self.HasMapPositionAPI) == "function" then
    local ok, value = pcall(self.HasMapPositionAPI, self)
    hasMapPositionAPI = ok and value and true or false
  end
  ProbeValue("hasMapPositionAPI", hasMapPositionAPI)
  local respawnNpcCount = 0
  for _ in pairs(respawns) do
    respawnNpcCount = respawnNpcCount + 1
  end
  ProbeValue("respawnNpcCount", respawnNpcCount)
  local heatmaps = db and type(db.heatmaps) == "table" and db.heatmaps or {}
  local heatmapMaps, heatmapKills = 0, 0
  for _, zone in pairs(heatmaps) do
    if type(zone) == "table" then
      heatmapMaps = heatmapMaps + 1
      heatmapKills = heatmapKills + (tonumber(zone.total) or 0)
    end
  end
  ProbeValue("heatmapMaps", heatmapMaps)
  ProbeValue("heatmapKills", heatmapKills)
  ProbeValue("hasNamePlateAPI", self:Supports("hasNamePlateAPI"))
  ProbeValue("namePlateEventAvailable", self.namePlateEventAvailable)
end

function XPTooltip:PrintKills(filter)
  local db = self.char
  if not db then
    return
  end
  local list = {}
  local lowerFilter = Lower(filter)
  for mobKey, mob in pairs(db.mobs) do
    if type(mob) == "table" and (tonumber(mob.kills) or 0) > 0 then
      if not lowerFilter or lowerFilter == "" or (Lower(mob.name) or ""):find(lowerFilter, 1, true) then
        list[#list + 1] = { key = mobKey, mob = mob }
      end
    end
  end
  table.sort(list, function(a, b)
    return (tonumber(a.mob.kills) or 0) > (tonumber(b.mob.kills) or 0)
  end)

  if #list == 0 then
    AceM2L2:SafePrint("Kill Story: no kills recorded yet.")
    return
  end

  if lowerFilter and lowerFilter ~= "" then
    local entry = list[1]
    local mob = entry.mob
    AceM2L2:SafePrint(string.format("%s (%s)", tostring(mob.name or entry.key), tostring(entry.key)))
    AceM2L2:SafePrint("  Total kills: " .. FormatNumber(mob.kills))
    AceM2L2:SafePrint("  This session: " .. FormatNumber(mob.sessionKills or 0))
    if self:Supports("hasPerMobXP")
      and type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
      AceM2L2:SafePrint("  Avg base XP: " .. FormatNumber((mob.xp.sumBase or 0) / mob.xp.samples))
      AceM2L2:SafePrint("  Avg total XP: " .. FormatNumber((mob.xp.sumTotal or 0) / mob.xp.samples))
    end
    AceM2L2:SafePrint("  First seen: " .. FormatDate(mob.firstSeen))
    AceM2L2:SafePrint("  Last seen: " .. FormatAgo(mob.lastSeen))
    return
  end

  AceM2L2:SafePrint("Top mobs killed:")
  for index = 1, min(#list, 15) do
    local mob = list[index].mob
    local avg = ""
    if self:Supports("hasPerMobXP")
      and type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
      avg = "  avg " .. FormatNumber((mob.xp.sumBase or 0) / mob.xp.samples) .. " XP"
    end
    AceM2L2:SafePrint(string.format(
      "  %-24s %8s%s  (%s)", tostring(mob.name or "Unknown"), FormatNumber(mob.kills), avg, FormatAgo(mob.lastSeen)
    ))
  end
end

function XPTooltip:PrintQuests()
  if not self:Supports("hasPerMobXP") then
    AceM2L2:SafePrint("Kill Story: quest XP tracking is unavailable on this client.")
    return
  end
  local db = self.char
  if not db then
    return
  end
  local list = {}
  for key, quest in pairs(db.quests or {}) do
    if type(quest) == "table" and (tonumber(quest.count) or 0) > 0 then
      list[#list + 1] = { key = key, quest = quest }
    end
  end
  if #list == 0 then
    AceM2L2:SafePrint("Kill Story: no quest XP recorded yet.")
    return
  end
  table.sort(list, function(a, b)
    local ax = tonumber(a.quest.totalXP) or 0
    local bx = tonumber(b.quest.totalXP) or 0
    if ax == bx then
      return (tonumber(a.quest.count) or 0) > (tonumber(b.quest.count) or 0)
    end
    return ax > bx
  end)
  local count, xp = self:GetQuestSummary()
  AceM2L2:SafePrint("Quest XP: " .. FormatNumber(count) .. " gains, "
    .. FormatNumber(xp) .. " XP")
  for index = 1, min(#list, 15) do
    local entry = list[index]
    local quest = entry.quest
    AceM2L2:SafePrint(string.format(
      "  %-30s %6s gains  %10s XP  (%s)",
      tostring(quest.name or entry.key),
      FormatNumber(quest.count or 0),
      FormatNumber(quest.totalXP or 0),
      FormatAgo(quest.lastSeen)
    ))
  end
end

function XPTooltip:PrintHistory(filter)
  local db = self.char
  if not db then
    return
  end
  local levelFilter = tonumber(filter)
  local records = self:NormalizeLevelHistory()
  local list = {}
  for _, record in ipairs(records) do
    if not levelFilter or record.level == levelFilter then
      list[#list + 1] = record
    end
  end
  if #list == 0 then
    AceM2L2:SafePrint("Kill Story: no level history recorded yet.")
    return
  end
  local supportsXP = self:Supports("hasPerMobXP")
  local now = Epoch()
  AceM2L2:SafePrint("Level history"
    .. (levelFilter and (" (level " .. tostring(levelFilter) .. ")") or "") .. ":")
  for index = #list, 1, -1 do
    local record = list[index]
    local duration = tonumber(record.duration) or 0
    if (tonumber(record.endedAt) or 0) == 0 then
      duration = max(0, now - (tonumber(record.startedAt) or now))
    end
    local parts = {
      "Level " .. tostring(record.level),
      FormatDuration(duration),
    }
    if supportsXP then
      parts[#parts + 1] = FormatNumber(record.xpGained) .. " XP"
    end
    parts[#parts + 1] = FormatNumber(record.kills) .. " kills"
    local suffix = (tonumber(record.endedAt) or 0) == 0 and " (current)" or ""
    AceM2L2:SafePrint("  " .. table.concat(parts, " | ") .. suffix)
  end
end

function XPTooltip:PrintSplits()
  local db = self.char
  if not db then
    return
  end
  local supportsXP = self:Supports("hasPerMobXP")
  local now = Epoch()
  local eligible = {}
  for _, record in ipairs(self:NormalizeLevelHistory()) do
    local level = tonumber(record.level) or 0
    if level > 0 then
      local endedAt = tonumber(record.endedAt) or 0
      local duration = tonumber(record.duration) or 0
      local isCurrent = endedAt == 0
      if isCurrent then
        duration = max(0, now - (tonumber(record.startedAt) or now))
      end
      eligible[#eligible + 1] = {
        level = level,
        duration = max(0, duration),
        kills = tonumber(record.kills) or 0,
        xpGained = tonumber(record.xpGained) or 0,
        isCurrent = isCurrent,
      }
    end
  end

  if #eligible == 0 then
    AceM2L2:SafePrint("Kill Story: no level splits recorded yet.")
    return
  end

  AceM2L2:SafePrint("Kill Story level splits:")
  local shown = 0
  for index = #eligible, 1, -1 do
    if shown >= 10 then
      break
    end
    local record = eligible[index]
    local text = "L" .. tostring(record.level) .. "  " .. FormatDuration(record.duration)
    if supportsXP then
      text = text .. ", " .. FormatNumber(record.xpGained) .. " XP"
    end
    text = text .. ", " .. FormatNumber(record.kills) .. " kills"
    local suffix = record.isCurrent and " (current)" or ""
    AceM2L2:SafePrint("  " .. text .. suffix)
    shown = shown + 1
  end

  local latest = eligible[#eligible]
  if latest.duration <= 0 then
    AceM2L2:SafePrint("  No completed time to compare yet.")
    return
  end

  local bestDuration
  for index = 1, #eligible - 1 do
    local record = eligible[index]
    if record.level == latest.level and not record.isCurrent and record.duration > 0 then
      if not bestDuration or record.duration < bestDuration then
        bestDuration = record.duration
      end
    end
  end
  if not bestDuration then
    AceM2L2:SafePrint("  No previous level " .. tostring(latest.level) .. " record to compare.")
    return
  end

  local delta = latest.duration - bestDuration
  local comparison = "matched"
  if delta < 0 then
    comparison = "faster"
    delta = -delta
  elseif delta > 0 then
    comparison = "slower"
  else
    delta = 0
  end
  AceM2L2:SafePrint("  Best previous at level " .. tostring(latest.level) .. ": "
    .. FormatDuration(bestDuration) .. " (" .. FormatDuration(delta) .. " " .. comparison .. ")")
end

function XPTooltip:PrintEconomy()
  local db = self.char
  if not db then
    return
  end
  local supportsLoot = self:Supports("hasLootValue")
  local supportsMoney = self:Supports("hasMoney")
  if not supportsLoot and not supportsMoney then
    AceM2L2:SafePrint("Kill Story: economy tracking is unavailable on this client.")
    return
  end
  local economy = type(db.economy) == "table" and db.economy or {}
  AceM2L2:SafePrint("Kill Story economy:")
  if supportsLoot then
    if self.lootEventAvailable then
      AceM2L2:SafePrint("  Session loot: " .. FormatMoney(economy.sessionLootValue)
        .. " (" .. FormatNumber(economy.sessionItems or 0) .. " items)")
      AceM2L2:SafePrint("  Lifetime loot: " .. FormatMoney(economy.lootValue)
        .. " (" .. FormatNumber(economy.items or 0) .. " items)")
    else
      AceM2L2:SafePrint("  Loot tracking: unavailable on this client.")
    end
  end
  if supportsMoney then
    if economy.moneyKnown ~= true then
      AceM2L2:SafePrint("  Money: unavailable on this client.")
    else
      local goldPerHour, net, elapsed = self:GetGoldPerHour()
      if goldPerHour then
        AceM2L2:SafePrint("  Gold/hour: " .. FormatMoney(goldPerHour * 10000)
          .. " (net " .. FormatMoney(net) .. ", " .. FormatDuration(elapsed) .. ")")
      else
        AceM2L2:SafePrint("  Gold/hour: not enough session time yet.")
      end
    end
  end
  if not self:Supports("hasGearCompare") then
    AceM2L2:SafePrint("  Gear upgrades: unavailable on this client.")
  end
end

function XPTooltip:PrintAreas()
  local db = self.char
  if not db then
    return
  end
  local total = tonumber(db.totals and db.totals.kills) or 0
  local list = {}
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > 0 then
      list[#list + 1] = { mapID = mapKey, kills = tonumber(kills) or 0 }
    end
  end
  table.sort(list, function(a, b) return a.kills > b.kills end)
  if #list == 0 then
    AceM2L2:SafePrint("Kill Story: no area data yet.")
    return
  end
  AceM2L2:SafePrint("Kills by area:")
  for index = 1, min(#list, 15) do
    local entry = list[index]
    local percent = total > 0 and (entry.kills / total * 100) or 0
    AceM2L2:SafePrint(string.format(
      "  %-30s %8s  (%.1f%%)", self:GetMapName(entry.mapID), FormatNumber(entry.kills), percent
    ))
  end
end

function XPTooltip:PrintLevels()
  local db = self.char
  if not db then
    return
  end
  local total = tonumber(db.totals and db.totals.kills) or 0
  local list = {}
  for levelKey, kills in pairs(db.levels or {}) do
    if (tonumber(kills) or 0) > 0 then
      list[#list + 1] = { level = tonumber(levelKey) or 0, kills = tonumber(kills) or 0 }
    end
  end
  table.sort(list, function(a, b) return a.level < b.level end)
  if #list == 0 then
    AceM2L2:SafePrint("Kill Story: no level data yet.")
    return
  end
  AceM2L2:SafePrint("Kills by player level:")
  for _, entry in ipairs(list) do
    local percent = total > 0 and (entry.kills / total * 100) or 0
    AceM2L2:SafePrint(string.format("  Level %-3d %8s  (%.1f%%)", entry.level, FormatNumber(entry.kills), percent))
  end
end

function XPTooltip:PrintSession()
  local db = self.char
  if not db or not db.session then
    return
  end
  AceM2L2:SafePrint("Kill Story session:")
  AceM2L2:SafePrint("  Kills: " .. FormatNumber(db.session.kills or 0))
  if self:Supports("hasPerMobXP") then
    AceM2L2:SafePrint("  XP: " .. FormatNumber(db.session.xp or 0))
  end
  AceM2L2:SafePrint("  Started: " .. FormatAgo(db.session.startedAt or 0))
end

function XPTooltip:PrintDungeon()
  if not self:Supports("hasInstanceInfo") then
    AceM2L2:SafePrint("Kill Story: dungeon detection is unavailable on this client.")
    return
  end
  local db = self.char
  if not db then
    return
  end
  local dungeon = type(db.dungeon) == "table" and db.dungeon or {}
  local supportsXP = self:Supports("hasPerMobXP")
  local kills = tonumber(dungeon.kills) or 0
  local xp = tonumber(dungeon.xp) or 0
  if kills <= 0 and (not supportsXP or xp <= 0) then
    AceM2L2:SafePrint("Kill Story: no dungeon activity recorded yet.")
    return
  end
  AceM2L2:SafePrint("Kill Story dungeon:")
  AceM2L2:SafePrint("  Kills: " .. FormatNumber(kills)
    .. " (" .. FormatNumber(dungeon.sessionKills or 0) .. " this session)")
  if supportsXP then
    AceM2L2:SafePrint("  XP: " .. FormatNumber(xp)
      .. " (" .. FormatNumber(dungeon.sessionXP or 0) .. " this session)")
    local _, questXP = self:GetQuestSummary()
    local totalXP = (tonumber(db.totals and db.totals.xp) or 0)
      + (tonumber(questXP) or 0)
    if totalXP > 0 then
      AceM2L2:SafePrint("  Share of XP: "
        .. FormatPercent(xp / totalXP * 100) .. " of total")
    end
  end
  local lastInstance = tonumber(dungeon.lastInstance) or 0
  if lastInstance > 0 then
    AceM2L2:SafePrint("  Last instance: " .. self:GetMapName(lastInstance))
  end
end

function XPTooltip:PrintGoal(rest)
  local db = self.char
  if not db then
    return
  end
  local action, value = (rest or ""):match("^(%S*)%s*(.-)$")
  action = Lower(action) or ""
  value = Trim(value)

  if action == "" then
    local goal = type(db.goal) == "table" and db.goal or {}
    local targetLevel = tonumber(goal.targetLevel) or 0
    if targetLevel <= 0 then
      AceM2L2:SafePrint("Kill Story: no leveling goal set. Use /acem2l2 xpt goal set <level>.")
      return
    end
    local currentLevel = self:GetPlayerLevel() or 0
    local levelsToGo = max(0, targetLevel - currentLevel)
    AceM2L2:SafePrint("Kill Story leveling goal:")
    AceM2L2:SafePrint("  Target level: " .. FormatNumber(targetLevel))
    AceM2L2:SafePrint("  Current level: " .. FormatNumber(currentLevel))
    if levelsToGo <= 0 then
      AceM2L2:SafePrint("  Levels to go: goal reached")
    else
      AceM2L2:SafePrint("  Levels to go: " .. FormatNumber(levelsToGo))
    end
    AceM2L2:SafePrint("  Set: " .. FormatAgo(goal.createdAt or 0))
    if self:Supports("hasPerMobXP") then
      local totalXP = tonumber(db.totals and db.totals.xp) or 0
      local targetXP = tonumber(goal.targetXP) or 0
      AceM2L2:SafePrint("  XP since goal: " .. FormatNumber(max(0, totalXP - targetXP)))
      local _, _, remaining = self:GetXPProgress()
      if remaining then
        AceM2L2:SafePrint("  XP to next level: " .. FormatNumber(remaining))
      end
    end
    return
  end

  if action == "clear" then
    db.goal = { targetLevel = 0, targetXP = 0, createdAt = 0 }
    AceM2L2:SafePrint("Kill Story: leveling goal cleared.")
    return
  end

  if action == "set" then
    local currentLevel = self:GetPlayerLevel()
    local lowerBound = (currentLevel and currentLevel > 0) and floor(currentLevel) or 1
    local maxLevel = self:GetMaxLevel() or 60
    local level = tonumber(value)
    if level then
      level = floor(level)
    end
    if not level or level < lowerBound or level > maxLevel then
      AceM2L2:SafePrint("Kill Story: goal level must be between "
        .. FormatNumber(lowerBound) .. " and " .. FormatNumber(maxLevel) .. ".")
      return
    end
    db.goal = {
      targetLevel = level,
      targetXP = tonumber(db.totals and db.totals.xp) or 0,
      createdAt = Epoch(),
    }
    AceM2L2:SafePrint("Kill Story: leveling goal set to level " .. FormatNumber(level) .. ".")
    return
  end

  AceM2L2:SafePrint("Usage: /acem2l2 xpt goal [set <level>|clear]")
end

function XPTooltip:PrintRate(filter)
  if not self:Supports("hasPerMobXP") then
    AceM2L2:SafePrint("Kill Story: XP rate is unavailable on this client.")
    return
  end
  local settings = self:GetSettings()
  local minutes = tonumber(filter) or tonumber(settings.rateWindowMinutes) or 10
  minutes = floor(max(1, min(60, minutes)))
  local xpPerHour, xpPerMinute, elapsed, count = self:GetXPRate(minutes * 60)
  if not xpPerHour then
    AceM2L2:SafePrint("Kill Story: not enough XP samples yet.")
    return
  end
  AceM2L2:SafePrint(string.format(
    "Kill Story XP rate (%d min window): %s XP/hr (%s XP/min)",
    minutes, FormatNumber(xpPerHour), FormatNumber(xpPerMinute)
  ))
  AceM2L2:SafePrint("  Sample window: " .. FormatDuration(elapsed or 0)
    .. " over " .. FormatNumber(count or 0) .. " samples")
  local seconds = self:GetTimeToLevel(minutes * 60)
  if seconds then
    AceM2L2:SafePrint("  Time to level: " .. FormatDuration(seconds))
  end
end

function XPTooltip:PrintStats()
  self:PrintStatus()
  local db = self.char
  if not db then
    return
  end

  local mobCount = 0
  for _, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      mobCount = mobCount + 1
    end
  end

  local areaCount = 0
  for _, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > 0 then
      areaCount = areaCount + 1
    end
  end

  local levelCount = 0
  for _, kills in pairs(db.levels or {}) do
    if (tonumber(kills) or 0) > 0 then
      levelCount = levelCount + 1
    end
  end

  if self:Supports("hasPerMobXP") then
    AceM2L2:SafePrint("  Totals: kills=" .. FormatNumber(db.totals.kills or 0)
      .. ", xp=" .. FormatNumber(db.totals.xp or 0)
      .. ", uniqueMobs=" .. FormatNumber(db.totals.uniqueMobs or 0))
  else
    AceM2L2:SafePrint("  Totals: kills=" .. FormatNumber(db.totals.kills or 0)
      .. ", uniqueMobs=" .. FormatNumber(db.totals.uniqueMobs or 0))
  end
  AceM2L2:SafePrint("  DB: mobs=" .. FormatNumber(mobCount)
    .. ", areas=" .. FormatNumber(areaCount)
    .. ", levels=" .. FormatNumber(levelCount)
    .. ", sessionKills=" .. FormatNumber(db.session.kills or 0))

  local topMap, topMapKills = nil, 0
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > topMapKills then
      topMapKills = tonumber(kills) or 0
      topMap = mapKey
    end
  end
  if topMap then
    AceM2L2:SafePrint("  Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topMapKills) .. ")")
  end

  local deathCount = #(type(db.deaths) == "table" and db.deaths or {})
  local respawnCount = 0
  for _ in pairs(type(db.respawns) == "table" and db.respawns or {}) do
    respawnCount = respawnCount + 1
  end
  AceM2L2:SafePrint("  Deaths: " .. FormatNumber(deathCount)
    .. ", respawns: " .. FormatNumber(respawnCount))
end

function XPTooltip:PrintDump()
  local db = self.char
  if not db then
    return
  end
  local list = {}
  for mobKey, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      list[#list + 1] = { key = mobKey, mob = mob }
    end
  end
  table.sort(list, function(a, b)
    return (tonumber(a.mob.kills) or 0) > (tonumber(b.mob.kills) or 0)
  end)
  AceM2L2:SafePrint("Kill Story dump (" .. tostring(#list) .. " mobs):")
  for index = 1, min(#list, 50) do
    local entry = list[index]
    local mob = entry.mob
    local contextCount = 0
    if type(mob.contexts) == "table" then
      for _ in pairs(mob.contexts) do
        contextCount = contextCount + 1
      end
    end
    AceM2L2:SafePrint(string.format(
      "  %s | %s | kills=%s | npc=%s | contexts=%d | last=%s",
      tostring(entry.key),
      tostring(mob.name or "Unknown"),
      FormatNumber(mob.kills or 0),
      tostring(mob.npcID or "?"),
      contextCount,
      FormatAgo(mob.lastSeen)
    ))
  end
end

function XPTooltip:PrintTable()
  if not self:Supports("hasXPFormula") then
    AceM2L2:SafePrint("Kill Story: XP table is unavailable on this client.")
    return
  end
  local playerLevel = self:GetPlayerLevel()
  local xpMax = self:GetXPMax()
  local xpCurrent = self:GetXP()
  if not playerLevel or not xpMax or not xpCurrent then
    AceM2L2:SafePrint("Kill Story: player XP state is unavailable.")
    return
  end
  local remaining = max(0, xpMax - xpCurrent)
  local pool = self:GetRestedPool()
  local mapID = self:GetMapID()
  local groupSize = self:GetGroupSize()

  AceM2L2:SafePrint(string.format(
    "Player level %d: %s / %s XP (%s remaining)",
    playerLevel, FormatNumber(xpCurrent), FormatNumber(xpMax), FormatNumber(remaining)
  ))
  AceM2L2:SafePrint("Mob level | XP per kill | kills to level")
  local maxLevel = self:GetMaxLevel()
  for mobLevel = max(1, playerLevel - 3), min(maxLevel, playerLevel + 4) do
    local estimate = self:GetEstimate(playerLevel, mobLevel, "normal", mapID, groupSize, "npc:table", "none")
    if estimate > 0 then
      local kills = self:KillsToLevel(remaining, estimate, pool)
      AceM2L2:SafePrint(string.format(
        "  %-8d | ~%-11s | ~%s", mobLevel, FormatNumber(estimate), FormatNumber(kills)
      ))
    else
      AceM2L2:SafePrint(string.format("  %-8d | no XP       | -", mobLevel))
    end
  end
end

function XPTooltip:ResetKills()
  local db = self.char
  if not db then
    return
  end
  self:InvalidatePendingWork("reset kills", true)
  self.heatmapZoneKey = nil
  self.selectedIndex = 0
  self.pendingDeleteKey = nil
  self.pendingDeleteAt = nil
  if type(self.ResetScroll) == "function" then
    self:ResetScroll()
  end
  db.mobs = {}
  db.quests = {}
  db.areas = {}
  db.levels = {}
  db.areaLevels = {}
  db.calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} }
  db.calibrationVersion = CALIBRATION_VERSION
  db.totals = { kills = 0, xp = 0, uniqueMobs = 0 }
  db.session = { startedAt = Epoch(), kills = 0, xp = 0 }
  db.dungeon = { xp = 0, kills = 0, sessionXP = 0, sessionKills = 0, lastInstance = 0 }
  db.goal = { targetLevel = 0, targetXP = 0, createdAt = 0 }
  db.levelHistory = {}
  db.deaths = {}
  db.respawns = {}
  if type(self.ResetHeatmaps) == "function" then
    self:ResetHeatmaps()
  end
  self.respawnWatches = {}
  db.economy = {
    lootValue = 0,
    sessionLootValue = 0,
    items = 0,
    sessionItems = 0,
    goldStart = 0,
    goldGained = 0,
    goldSpent = 0,
    lastMoney = 0,
    moneyKnown = false,
  }
  self:ResetRates()
  self:RecordMoney(self:GetMoney())
  self:EnsureLevelHistory()
  AceM2L2:SafePrint("Kill Story reset.")
  self:RefreshUI()
end

function XPTooltip:DeleteMobEntry(mobKey)
  self:InvalidatePendingWork("delete mob", false)
  self:MarkMobDeleted(mobKey)
  local name, kills = self:RemoveMobEntry(mobKey)
  if not name then
    AceM2L2:SafePrint("Kill Story: that entry no longer exists.")
    return false
  end
  AceM2L2:SafePrint(string.format(
    "Kill Story: removed %s (%s kills).", name, FormatNumber(kills or 0)
  ))
  return true
end

function XPTooltip:DeleteMobByName(name, confirm)
  local target = Trim(name)
  if not target or target == "" then
    AceM2L2:SafePrint("Usage: /acem2l2 xpt delete <mob name>")
    return
  end
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return
  end

  local lower = Lower(target)
  local matches = {}
  for mobKey, mob in pairs(db.mobs) do
    if type(mob) == "table" and Lower(mob.name) == lower then
      matches[#matches + 1] = {
        key = mobKey,
        name = tostring(mob.name or mobKey),
        kills = tonumber(mob.kills) or 0,
      }
    end
  end

  if #matches == 0 then
    AceM2L2:SafePrint("Kill Story: no entry named " .. target .. ".")
    return
  end

  if not confirm then
    if #matches == 1 then
      AceM2L2:SafePrint(string.format(
        "Kill Story: %s has %s kills. Use /acem2l2 xpt delete confirm %s to remove it.",
        matches[1].name, FormatNumber(matches[1].kills), matches[1].name
      ))
    else
      AceM2L2:SafePrint(string.format(
        "Kill Story: %d entries are named %s. Use /acem2l2 xpt delete confirm %s to remove all of them.",
        #matches, target, target
      ))
    end
    return
  end

  local removed, kills = 0, 0
  self:InvalidatePendingWork("delete mob by name", false)
  for _, match in ipairs(matches) do
    self:MarkMobDeleted(match.key)
    local removedName, removedKills = self:RemoveMobEntry(match.key, true)
    if removedName then
      removed = removed + 1
      kills = kills + (removedKills or 0)
    end
  end
  if removed > 0 then
    self:RefreshAfterMobDelete()
  end
  AceM2L2:SafePrint(string.format(
    "Kill Story: removed %d entr%s named %s (%s kills).",
    removed, removed == 1 and "y" or "ies", target, FormatNumber(kills)
  ))
end

function XPTooltip:DeleteUnknownEntries()
  local db = self.char
  if not db or type(db.mobs) ~= "table" then
    return
  end
  local keys = {}
  for mobKey, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      local name = Lower(mob.name)
      if not name or name == "" or name == "unknown" then
        keys[#keys + 1] = mobKey
      end
    end
  end
  if #keys == 0 then
    AceM2L2:SafePrint("Kill Story: no Unknown entries to remove.")
    return
  end

  local removed, kills = 0, 0
  self:InvalidatePendingWork("delete unknown entries", false)
  for _, mobKey in ipairs(keys) do
    self:MarkMobDeleted(mobKey)
    local removedName, removedKills = self:RemoveMobEntry(mobKey, true)
    if removedName then
      removed = removed + 1
      kills = kills + (removedKills or 0)
    end
  end
  if removed > 0 then
    self:RefreshAfterMobDelete()
  end
  AceM2L2:SafePrint(string.format(
    "Kill Story: removed %d Unknown entr%s (%s kills).",
    removed, removed == 1 and "y" or "ies", FormatNumber(kills)
  ))
end

function XPTooltip:RefreshAfterMobDelete()
  self.pendingDeleteKey = nil
  self.pendingDeleteAt = nil
  if not self.ui then
    return
  end
  self:BuildList()
  if #self.currentList > 0 then
    self.selectedIndex = max(1, min(self.selectedIndex or 1, #self.currentList))
  else
    self.selectedIndex = 0
  end
  self:UpdateRows()
  self:UpdateDetail()
  self:RefreshOverview()
  self:UpdateFooter()
  self:UpdateStatusChip()
end

function XPTooltip:PrintHelp()
  AceM2L2:SafePrint("Kill Story commands:")
  AceM2L2:SafePrint("/acem2l2 xpt on|off")
  AceM2L2:SafePrint("/acem2l2 xpt status")
  AceM2L2:SafePrint("/acem2l2 xpt probe")
  AceM2L2:SafePrint("/acem2l2 xpt ui")
  AceM2L2:SafePrint("/acem2l2 xpt kills [name]")
  AceM2L2:SafePrint("/acem2l2 xpt deaths [count]")
  AceM2L2:SafePrint("/acem2l2 xpt respawns [name]")
  AceM2L2:SafePrint("/acem2l2 xpt spots")
  AceM2L2:SafePrint("/acem2l2 xpt quests")
  AceM2L2:SafePrint("/acem2l2 xpt history [level]")
  AceM2L2:SafePrint("/acem2l2 xpt splits")
  AceM2L2:SafePrint("/acem2l2 xpt economy")
  AceM2L2:SafePrint("/acem2l2 xpt areas")
  AceM2L2:SafePrint("/acem2l2 xpt heatmap [zone]")
  AceM2L2:SafePrint("/acem2l2 xpt levels")
  AceM2L2:SafePrint("/acem2l2 xpt session")
  AceM2L2:SafePrint("/acem2l2 xpt dungeon")
  AceM2L2:SafePrint("/acem2l2 xpt goal [set <level>|clear]")
  AceM2L2:SafePrint("/acem2l2 xpt rate [minutes]")
  AceM2L2:SafePrint("/acem2l2 xpt stats")
  AceM2L2:SafePrint("/acem2l2 xpt dump")
  AceM2L2:SafePrint("/acem2l2 xpt table")
  AceM2L2:SafePrint("/acem2l2 xpt theme aether|dark|midnight|class|contrast")
  AceM2L2:SafePrint("/acem2l2 xpt scale 80-120")
  AceM2L2:SafePrint("/acem2l2 xpt starttab overview|mobs|areas|levels|heatmap")
  AceM2L2:SafePrint("/acem2l2 xpt minimap on|off|reset|status")
  AceM2L2:SafePrint("/acem2l2 xpt debug on|off")
  AceM2L2:SafePrint("/acem2l2 xpt recalibrate confirm")
  AceM2L2:SafePrint("/acem2l2 xpt delete <mob name>")
  AceM2L2:SafePrint("/acem2l2 xpt delete confirm <mob name>")
  AceM2L2:SafePrint("/acem2l2 xpt deleteunknown confirm")
  AceM2L2:SafePrint("/acem2l2 xpt reset|resetkills confirm")
  AceM2L2:SafePrint("/acem2l2 xpt config")
end

function XPTooltip:HandleCommand(input)
  local arg = input or ""
  local command, rest = arg:match("^(%S*)%s*(.-)$")
  command = Lower(command) or ""
  rest = rest or ""

  if command == "" or command == "help" then
    self:PrintHelp()
  elseif command == "on" then
    self:SetUserEnabled(true)
    AceM2L2:SafePrint("Kill Story enabled.")
  elseif command == "off" then
    self:SetUserEnabled(false)
    AceM2L2:SafePrint("Kill Story disabled.")
  elseif command == "status" then
    self:PrintStatus()
  elseif command == "probe" then
    self:PrintProbe()
  elseif command == "ui" then
    self:OpenUI()
  elseif command == "kills" then
    self:PrintKills(rest)
  elseif command == "deaths" then
    self:PrintDeaths(rest)
  elseif command == "respawns" then
    self:PrintRespawns(rest)
  elseif command == "spots" then
    self:PrintSpots()
  elseif command == "quests" then
    self:PrintQuests()
  elseif command == "history" then
    self:PrintHistory(rest)
  elseif command == "areas" then
    self:PrintAreas()
  elseif command == "heatmap" then
    self:PrintHeatmap(rest)
  elseif command == "levels" then
    self:PrintLevels()
  elseif command == "session" then
    self:PrintSession()
  elseif command == "dungeon" then
    self:PrintDungeon()
  elseif command == "goal" then
    self:PrintGoal(rest)
  elseif command == "splits" then
    self:PrintSplits()
  elseif command == "economy" then
    self:PrintEconomy()
  elseif command == "rate" then
    self:PrintRate(rest)
  elseif command == "stats" then
    self:PrintStats()
  elseif command == "dump" then
    self:PrintDump()
  elseif command == "table" then
    self:PrintTable()
  elseif command == "theme" then
    local theme = Lower(rest) or ""
    if THEMES[theme] then
      local settings = self:GetSettings()
      settings.theme = theme
      self:ApplyTheme()
      AceM2L2:SafePrint("Kill Story theme: " .. theme)
    else
      AceM2L2:SafePrint("Themes: aether, dark, midnight, class, contrast")
    end
  elseif command == "scale" then
    local value = tonumber(rest)
    if value and value > 2 then
      value = value / 100
    end
    if value and value >= 0.8 and value <= 1.2 then
      local settings = self:GetSettings()
      settings.scale = value
      if self.ui and self.ui.SetScale then
        self.ui:SetScale(value)
      end
      AceM2L2:SafePrint(string.format("Kill Story scale: %.2f", value))
    else
      AceM2L2:SafePrint("Usage: /acem2l2 xpt scale 80-120")
    end
  elseif command == "starttab" then
    local tab = Lower(rest) or ""
    if tab == "overview" or tab == "mobs" or tab == "areas" or tab == "levels"
      or tab == "heatmap" then
      local settings = self:GetSettings()
      settings.startTab = tab
      if self.ui and self.ui:IsShown() then
        self:SetTab(tab)
      end
      AceM2L2:SafePrint("Kill Story start tab: " .. tab)
    else
      AceM2L2:SafePrint("Start tabs: overview, mobs, areas, levels, heatmap")
    end
  elseif command == "minimap" then
    local action = Lower(rest) or ""
    local settings = self:GetSettings()
    if type(settings.minimap) ~= "table" then
      settings.minimap = CopyTable(DEFAULT_MINIMAP)
    end
    if action == "off" then
      settings.minimap.hide = true
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill Story minimap icon hidden.")
    elseif action == "on" then
      settings.minimap.hide = false
      self:InitializeMinimap()
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill Story minimap icon shown.")
    elseif action == "reset" then
      settings.minimap.minimapPos = 200
      if self.minimapIcon and self.minimapIcon.Refresh then
        pcall(self.minimapIcon.Refresh, self.minimapIcon, "AceM2L2", settings.minimap)
      else
        self.minimapRegistered = false
        self:InitializeMinimap()
      end
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill Story minimap position reset.")
    elseif action == "status" or action == "" then
      self:PrintMinimapStatus()
    else
      AceM2L2:SafePrint("Usage: /acem2l2 xpt minimap on|off|reset|status")
    end
  elseif command == "debug" then
    local action = Lower(rest) or ""
    local settings = self:GetSettings()
    if action == "on" then
      settings.debug = true
      AceM2L2:SafePrint("Kill Story debug enabled.")
    elseif action == "off" then
      settings.debug = false
      AceM2L2:SafePrint("Kill Story debug disabled.")
    else
      AceM2L2:SafePrint("Usage: /acem2l2 xpt debug on|off")
    end
  elseif command == "config" then
    AceM2L2:HandleSlashCommand("config")
  elseif command == "recalibrate" then
    if Lower(rest) == "confirm" then
      self:ResetCalibration()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt recalibrate confirm to clear learned ratios.")
    end
  elseif command == "reset" then
    if Lower(rest) == "confirm" then
      self:ResetObservations()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt reset confirm to clear observations.")
    end
  elseif command == "resetkills" then
    if Lower(rest) == "confirm" then
      self:ResetKills()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt resetkills confirm to clear kill history.")
    end
  elseif command == "delete" then
    local target = Trim(rest)
    if not target or target == "" then
      AceM2L2:SafePrint("Usage: /acem2l2 xpt delete <mob name>")
      AceM2L2:SafePrint("Then: /acem2l2 xpt delete confirm <mob name>")
      return
    end
    local confirmName = target:match("^[Cc][Oo][Nn][Ff][Ii][Rr][Mm]%s+(.+)$")
    if confirmName then
      self:DeleteMobByName(confirmName, true)
    else
      self:DeleteMobByName(target, false)
    end
  elseif command == "deleteunknown" or command == "resetunknown" then
    if Lower(rest) == "confirm" then
      self:DeleteUnknownEntries()
    else
      AceM2L2:SafePrint("Use /acem2l2 xpt deleteunknown confirm to remove all Unknown entries.")
    end
  else
    self:PrintHelp()
  end
end
