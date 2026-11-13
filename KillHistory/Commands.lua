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
local FormatAgo = Util.FormatAgo
local FormatDate = Util.FormatDate
local CopyTable = Util.CopyTable
local Epoch = Util.Epoch

function XPTooltip:PrintStatus()
  local compatible, reason, hasProcessor, hasHook = self:CheckCompatibility()
  local profile = self:GetClientProfile()
  AceM2L2:SafePrint("Kill History: " .. self:GetStatusText())
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
  local profile = self:GetClientProfile()
  AceM2L2:SafePrint("Kill History probe:")
  ProbeValue("projectID", self:GetProjectID())
  ProbeValue("interface", AceM2L2:GetInterfaceVersion())
  ProbeValue("profile", profile and profile.id or "unknown")
  ProbeValue("mode", profile and profile:GetStatusLabel() or "unavailable")
  ProbeValue("active", self:IsActive())
  ProbeValue("autoDisabled", self.autoDisabled)
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
  ProbeValue("mapID", self:GetMapID())
  ProbeValue("mapName", self:GetMapName(self:GetMapID()))
  ProbeValue("groupSize", self:GetGroupSize())
  ProbeValue("maxLevel", self:GetMaxLevel())
  ProbeValue("xp", self:GetXP())
  ProbeValue("xpMax", self:GetXPMax())
  ProbeValue("xpRaw", SafeCall(UnitXP, "player"))
  ProbeValue("xpMaxRaw", SafeCall(UnitXPMax, "player"))
  ProbeValue("restedPool", self:GetRestedPool())
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
    AceM2L2:SafePrint("Kill History: no kills recorded yet.")
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
    AceM2L2:SafePrint("Kill History: no area data yet.")
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
    AceM2L2:SafePrint("Kill History: no level data yet.")
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
  AceM2L2:SafePrint("Kill History session:")
  AceM2L2:SafePrint("  Kills: " .. FormatNumber(db.session.kills or 0))
  if self:Supports("hasPerMobXP") then
    AceM2L2:SafePrint("  XP: " .. FormatNumber(db.session.xp or 0))
  end
  AceM2L2:SafePrint("  Started: " .. FormatAgo(db.session.startedAt or 0))
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
  AceM2L2:SafePrint("Kill History dump (" .. tostring(#list) .. " mobs):")
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
    AceM2L2:SafePrint("Kill History: XP table is unavailable on this client.")
    return
  end
  local playerLevel = self:GetPlayerLevel()
  local xpMax = self:GetXPMax()
  local xpCurrent = self:GetXP()
  if not playerLevel or not xpMax or not xpCurrent then
    AceM2L2:SafePrint("Kill History: player XP state is unavailable.")
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
  self.dataGeneration = (self.dataGeneration or 0) + 1
  self.pendingDeaths = {}
  self.recentChatKills = {}
  self.pendingChatXP = {}
  db.mobs = {}
  db.areas = {}
  db.levels = {}
  db.areaLevels = {}
  db.calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} }
  db.calibrationVersion = CALIBRATION_VERSION
  db.totals = { kills = 0, xp = 0, uniqueMobs = 0 }
  db.session = { startedAt = Epoch(), kills = 0, xp = 0 }
  AceM2L2:SafePrint("Kill History reset.")
  self:RefreshUI()
end

function XPTooltip:DeleteMobEntry(mobKey)
  self.dataGeneration = (self.dataGeneration or 0) + 1
  local name, kills = self:RemoveMobEntry(mobKey)
  if not name then
    AceM2L2:SafePrint("Kill History: that entry no longer exists.")
    return false
  end
  AceM2L2:SafePrint(string.format(
    "Kill History: removed %s (%s kills).", name, FormatNumber(kills or 0)
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
    AceM2L2:SafePrint("Kill History: no entry named " .. target .. ".")
    return
  end

  if not confirm then
    if #matches == 1 then
      AceM2L2:SafePrint(string.format(
        "Kill History: %s has %s kills. Use /acem2l2 xpt delete confirm %s to remove it.",
        matches[1].name, FormatNumber(matches[1].kills), matches[1].name
      ))
    else
      AceM2L2:SafePrint(string.format(
        "Kill History: %d entries are named %s. Use /acem2l2 xpt delete confirm %s to remove all of them.",
        #matches, target, target
      ))
    end
    return
  end

  local removed, kills = 0, 0
  self.dataGeneration = (self.dataGeneration or 0) + 1
  for _, match in ipairs(matches) do
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
    "Kill History: removed %d entr%s named %s (%s kills).",
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
    AceM2L2:SafePrint("Kill History: no Unknown entries to remove.")
    return
  end

  local removed, kills = 0, 0
  self.dataGeneration = (self.dataGeneration or 0) + 1
  for _, mobKey in ipairs(keys) do
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
    "Kill History: removed %d Unknown entr%s (%s kills).",
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
  AceM2L2:SafePrint("Kill History commands:")
  AceM2L2:SafePrint("/acem2l2 xpt on|off")
  AceM2L2:SafePrint("/acem2l2 xpt status")
  AceM2L2:SafePrint("/acem2l2 xpt probe")
  AceM2L2:SafePrint("/acem2l2 xpt ui")
  AceM2L2:SafePrint("/acem2l2 xpt kills [name]")
  AceM2L2:SafePrint("/acem2l2 xpt areas")
  AceM2L2:SafePrint("/acem2l2 xpt levels")
  AceM2L2:SafePrint("/acem2l2 xpt session")
  AceM2L2:SafePrint("/acem2l2 xpt stats")
  AceM2L2:SafePrint("/acem2l2 xpt dump")
  AceM2L2:SafePrint("/acem2l2 xpt table")
  AceM2L2:SafePrint("/acem2l2 xpt theme aether|dark|midnight|class|contrast")
  AceM2L2:SafePrint("/acem2l2 xpt scale 80-120")
  AceM2L2:SafePrint("/acem2l2 xpt starttab overview|mobs|areas|levels")
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
    AceM2L2:SafePrint("Kill History enabled.")
  elseif command == "off" then
    self:SetUserEnabled(false)
    AceM2L2:SafePrint("Kill History disabled.")
  elseif command == "status" then
    self:PrintStatus()
  elseif command == "probe" then
    self:PrintProbe()
  elseif command == "ui" then
    self:OpenUI()
  elseif command == "kills" then
    self:PrintKills(rest)
  elseif command == "areas" then
    self:PrintAreas()
  elseif command == "levels" then
    self:PrintLevels()
  elseif command == "session" then
    self:PrintSession()
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
      AceM2L2:SafePrint("Kill History theme: " .. theme)
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
      AceM2L2:SafePrint(string.format("Kill History scale: %.2f", value))
    else
      AceM2L2:SafePrint("Usage: /acem2l2 xpt scale 80-120")
    end
  elseif command == "starttab" then
    local tab = Lower(rest) or ""
    if tab == "overview" or tab == "mobs" or tab == "areas" or tab == "levels" then
      local settings = self:GetSettings()
      settings.startTab = tab
      if self.ui and self.ui:IsShown() then
        self:SetTab(tab)
      end
      AceM2L2:SafePrint("Kill History start tab: " .. tab)
    else
      AceM2L2:SafePrint("Start tabs: overview, mobs, areas, levels")
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
      AceM2L2:SafePrint("Kill History minimap icon hidden.")
    elseif action == "on" then
      settings.minimap.hide = false
      self:InitializeMinimap()
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill History minimap icon shown.")
    elseif action == "reset" then
      settings.minimap.minimapPos = 200
      if self.minimapIcon and self.minimapIcon.Refresh then
        pcall(self.minimapIcon.Refresh, self.minimapIcon, "AceM2L2", settings.minimap)
      else
        self.minimapRegistered = false
        self:InitializeMinimap()
      end
      self:UpdateMinimapVisibility()
      AceM2L2:SafePrint("Kill History minimap position reset.")
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
      AceM2L2:SafePrint("Kill History debug enabled.")
    elseif action == "off" then
      settings.debug = false
      AceM2L2:SafePrint("Kill History debug disabled.")
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
