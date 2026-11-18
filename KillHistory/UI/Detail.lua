--[[---------------------------------------------------------------------------------
  KillHistory/UI/Detail.lua
  Hero card, 3D model, mob/area/level detail, and single-entry deletion UI.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local floor, min, max = math.floor, math.min, math.max
local Now = Util.Now
local FormatNumber = Util.FormatNumber
local FormatDate = Util.FormatDate
local FormatAgo = Util.FormatAgo
local FormatDuration = Util.FormatDuration
local MIN_RESPAWN_SAMPLES = XPTooltip.MIN_RESPAWN_SAMPLES or 3

local function TopMobsByField(module, db, field, key, limit)
  local top = {}
  local function add(mob)
    if type(mob) == "table" and type(mob[field]) == "table" then
      local value = tonumber(mob[field][key]) or 0
      if value > 0 then
        top[#top + 1] = { name = mob.name or "Unknown", kills = value }
      end
    end
  end
  if module:UseJourneyIndexViews() then
    local rows = module:GetJourneyAllMobRows()
    for index = 1, #rows do
      add(rows[index].mob)
    end
  else
    for _, mob in pairs(db.mobs or {}) do
      add(mob)
    end
  end
  table.sort(top, function(a, b)
    if a.kills == b.kills then
      return tostring(a.name) < tostring(b.name)
    end
    return a.kills > b.kills
  end)
  return top, limit
end

local function LevelRange(areaLevels)
  local minLevel, maxLevel
  if type(areaLevels) == "table" then
    for levelKey, count in pairs(areaLevels) do
      local level = tonumber(levelKey)
      if level and (tonumber(count) or 0) > 0 then
        if not minLevel or level < minLevel then
          minLevel = level
        end
        if not maxLevel or level > maxLevel then
          maxLevel = level
        end
      end
    end
  end
  return minLevel, maxLevel
end

function XPTooltip:ShowModel(npcID)
  if not self.ui or not self.ui.model or not self.ui.modelFallback then
    return
  end
  if not self:Supports("hasModel") then
    self:HideModel("")
    return
  end
  if not npcID then
    self:HideModel("No model data")
    return
  end
  if self.modelNPCID == npcID and self.ui.model then
    self.ui.model:Show()
    self.ui.modelFallback:Hide()
    self.ui.modelFallbackIcon:Hide()
    return
  end
  if not self.ui.model.SetCreature then
    self:HideModel("No model support")
    return
  end
  local ok = pcall(self.ui.model.SetCreature, self.ui.model, npcID)
  if not ok then
    self:HideModel("No model data")
    return
  end
  self.ui.model:Show()
  self.ui.modelFallback:Hide()
  self.ui.modelFallbackIcon:Hide()
  self.modelNPCID = npcID
  pcall(self.ui.model.SetRotation, self.ui.model, self.modelYaw or 0)
  if self.ui.model.SetCamDistanceScale then
    pcall(self.ui.model.SetCamDistanceScale, self.ui.model, 1.15)
  end
  if self.ui.model.SetAnimation then
    pcall(self.ui.model.SetAnimation, self.ui.model, 0)
  end
end

function XPTooltip:HideModel(text)
  if not self.ui or not self.ui.model or not self.ui.modelFallback then
    return
  end
  self.modelNPCID = nil
  self.ui.model:Hide()
  self.ui.modelFallback:SetText(text or "")
  if text and text ~= "" then
    self.ui.modelFallback:Show()
    self.ui.modelFallbackIcon:Show()
  else
    self.ui.modelFallback:Hide()
    self.ui.modelFallbackIcon:Hide()
  end
end

function XPTooltip:UpdateDetail()
  if not self.ui or not self.ui.details then
    return
  end
  local selected = self:GetSelected()
  self:UpdateDeleteButton(selected)
  if not selected then
    if self.tab == "deaths" then
      self:UpdateHistoryEmptyDetail()
      return
    elseif self.tab == "quests" then
      self:UpdateQuestEmptyDetail()
      return
    end
    self:SetDetailMode(false)
    self:HideModel("No kill data yet")
    if self.ui.heroName then
      self.ui.heroName:SetText("No kill data")
    end
    if self.ui.heroSub then
      local profile = self:GetClientProfile()
      self.ui.heroSub:SetText(profile and profile:GetEmptyStateText() or "Kill a mob to start the history.")
    end
    self.ui.details:SetText("")
    return
  end

  if selected.kind == "mob" then
    self:UpdateMobDetail(selected.key)
  elseif selected.kind == "death" then
    self:UpdateDeathDetail(selected)
  elseif selected.kind == "respawn" then
    self:UpdateRespawnDetail(selected)
  elseif selected.kind == "quest" then
    self:UpdateQuestDetail(selected)
  elseif selected.kind == "area" then
    self:HideModel("")
    self:UpdateAreaDetail(selected.key)
  elseif selected.kind == "instance" then
    self:HideModel("")
    self:UpdateInstanceDetail(selected.key)
  else
    self:HideModel("")
    self:UpdateLevelDetail(selected.key)
  end
end

function XPTooltip:SetDetailMode(showModel)
  if not self.ui or not self.ui.heroName or not self.ui.heroSub or not self.ui.details then
    return
  end
  if self.ui.modelHolder then
    if showModel then
      self.ui.modelHolder:Show()
    else
      self.ui.modelHolder:Hide()
    end
  end
  local top = showModel and -240 or -12
  self.ui.heroName:ClearAllPoints()
  self.ui.heroName:SetPoint("TOPLEFT", 12, top)
  self.ui.heroName:SetPoint("TOPRIGHT", -12, top)
  self.ui.heroSub:ClearAllPoints()
  self.ui.heroSub:SetPoint("TOPLEFT", 12, top - 22)
  self.ui.heroSub:SetPoint("TOPRIGHT", -12, top - 22)
  self.ui.details:ClearAllPoints()
  self.ui.details:SetPoint("TOPLEFT", 12, showModel and -282 or -60)
  self.ui.details:SetPoint("BOTTOMRIGHT", -12, 10)
end

function XPTooltip:UpdateHistoryEmptyDetail()
  self:SetDetailMode(false)
  self:HideModel("")
  local _, _, reason = self:GetHistoryAvailability()
  if self.ui.heroName then
    self.ui.heroName:SetText("Death & respawn history")
  end
  if self.ui.heroSub then
    self.ui.heroSub:SetText(reason or "No death or respawn history recorded yet.")
  end
  if self.ui.details then
    self.ui.details:SetText(
      "Deaths: /acem2l2 xpt deaths [count]\n"
      .. "Respawns: /acem2l2 xpt respawns [name]"
    )
  end
end

function XPTooltip:UpdateDeathDetail(entry)
  self:SetDetailMode(false)
  self:HideModel("")
  local mapName = self:GetMapName(entry.mapID)
  self.ui.heroName:SetText("Player death")
  self.ui.heroSub:SetText(string.format(
    "%s  ·  %.1f, %.1f", mapName, (entry.x or 0) * 100, (entry.y or 0) * 100
  ))
  self.ui.details:SetText(table.concat({
    "Time: " .. FormatDate(entry.at),
    "Age: " .. FormatAgo(entry.at),
    "Map: " .. mapName .. " (" .. tostring(entry.mapID) .. ")",
    string.format("Coordinates: %.1f, %.1f", (entry.x or 0) * 100, (entry.y or 0) * 100),
    "",
    "Command: /acem2l2 xpt deaths",
  }, "\n"))
end

function XPTooltip:UpdateRespawnDetail(entry)
  self:SetDetailMode(false)
  self:HideModel("")
  local samples = tonumber(entry.samples) or 0
  self.ui.heroName:SetText(tostring(entry.name or ("NPC " .. tostring(entry.npcID))))
  self.ui.heroSub:SetText("NPC " .. tostring(entry.npcID)
    .. "  ·  " .. FormatNumber(samples) .. " samples")

  local lines = {}
  if entry.hasAverage and entry.average then
    lines[#lines + 1] = "Average: " .. FormatDuration(entry.average)
    lines[#lines + 1] = "Range: " .. FormatDuration(entry.minimum or 0)
      .. " - " .. FormatDuration(entry.maximum or 0)
  else
    lines[#lines + 1] = "Average: needs " .. tostring(MIN_RESPAWN_SAMPLES)
      .. " samples (" .. FormatNumber(samples) .. " recorded)"
  end
  lines[#lines + 1] = "Samples: " .. FormatNumber(samples)
  lines[#lines + 1] = "Last seen: " .. FormatAgo(entry.lastSeen or 0)
  lines[#lines + 1] = "NPC ID: " .. tostring(entry.npcID)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Command: /acem2l2 xpt respawns <name>"
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateQuestEmptyDetail()
  self:SetDetailMode(false)
  self:HideModel("")
  if self.ui.heroName then
    self.ui.heroName:SetText("Quest XP ledger")
  end
  if self.ui.heroSub then
    if not self:Supports("hasPerMobXP") then
      self.ui.heroSub:SetText("Quest XP is not tracked on this client.")
    else
      self.ui.heroSub:SetText("No quest XP recorded yet.")
    end
  end
  if self.ui.details then
    if not self:Supports("hasPerMobXP") then
      self.ui.details:SetText("Quest XP is only available on Forever clients.")
    else
      self.ui.details:SetText("Command: /acem2l2 xpt quests")
    end
  end
end

function XPTooltip:UpdateQuestDetail(entry)
  self:SetDetailMode(false)
  self:HideModel("")
  local count = tonumber(entry.count) or 0
  local totalXP = tonumber(entry.totalXP) or 0
  self.ui.heroName:SetText(tostring(entry.label or entry.key or "Quest"))
  self.ui.heroSub:SetText(FormatNumber(count) .. " gains  ·  "
    .. FormatNumber(totalXP) .. " XP")
  local lines = {
    "Quest ID: " .. tostring(entry.questID or entry.key),
    "Total XP: " .. FormatNumber(totalXP),
    "Gains: " .. FormatNumber(count),
  }
  if count > 0 then
    lines[#lines + 1] = "Average per gain: " .. FormatNumber(totalXP / count)
  end
  lines[#lines + 1] = "First seen: " .. FormatDate(entry.firstSeen)
  lines[#lines + 1] = "Last seen: " .. FormatAgo(entry.lastSeen)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Command: /acem2l2 xpt quests"
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateMobDetail(mobKey)
  self:SetDetailMode(true)
  local legacy = self.char and self.char.mobs and self.char.mobs[mobKey]
  local mob = legacy
  local blockFallback = false
  if type(mob) ~= "table" then
    local journey = self.char and self.char.journey
    if (not journey or journey.blockReadFallback ~= false)
      and type(self.GetJourneyMob) == "function" then
      local record = self:GetJourneyMob(mobKey)
      if type(record) == "table" then
        mob = record
        blockFallback = true
      end
    end
  end
  if type(mob) ~= "table" then
    self:HideModel("No model data")
    if self.ui.heroName then self.ui.heroName:SetText("Mob data unavailable") end
    if self.ui.heroSub then self.ui.heroSub:SetText("") end
    self.ui.details:SetText("")
    return
  end

  self:ShowModel(mob.npcID)
  self.ui.heroName:SetText(tostring(mob.name or "Unknown"))
  self.ui.heroSub:SetText(
    string.upper(tostring(mob.classification or "normal"))
      .. "  ·  NPC " .. tostring(mob.npcID or "unknown")
  )

  local lines = {}
  lines[#lines + 1] = "Total kills: " .. FormatNumber(mob.kills or 0)
  local historical = self:GetMobRelevance(mob, nil, self:GetPlayerLevel()) == "historical"
  if historical then
    local minLevel, maxLevel = self:GetMobLevelRange(mob)
    if minLevel then
      lines[#lines + 1] = "Mob level range: " .. tostring(minLevel)
        .. "-" .. tostring(maxLevel or minLevel)
    end
    local topMap, topKills
    for mapKey, kills in pairs(type(mob.killsByMap) == "table" and mob.killsByMap or {}) do
      if not topKills or (tonumber(kills) or 0) > topKills then
        topMap, topKills = mapKey, tonumber(kills) or 0
      end
    end
    if topMap and topKills and topKills > 0 then
      lines[#lines + 1] = "Top area: " .. self:GetMapName(topMap)
        .. " (" .. FormatNumber(topKills) .. ")"
    end
    local levelMin, levelMax
    for levelKey, kills in pairs(type(mob.killsAtLevel) == "table" and mob.killsAtLevel or {}) do
      local level = tonumber(levelKey)
      if level and (tonumber(kills) or 0) > 0 then
        levelMin = levelMin and min(levelMin, level) or level
        levelMax = levelMax and max(levelMax, level) or level
      end
    end
    if levelMin then
      lines[#lines + 1] = "Level range: " .. tostring(levelMin) .. "-" .. tostring(levelMax)
    end
    lines[#lines + 1] = "First seen: " .. FormatDate(mob.firstSeen)
    lines[#lines + 1] = "Last seen: " .. FormatAgo(mob.lastSeen)
    if blockFallback then
      lines[#lines + 1] = "|cffaaaaaaBlock detail: session/XP context unavailable.|r"
    end
    lines[#lines + 1] = "|cffaaaaaaHistorical content: XP context hidden.|r"
  elseif blockFallback then
    if tonumber(mob.mobLevelMin) and tonumber(mob.mobLevelMin) > 0 then
      lines[#lines + 1] = "Mob level range: " .. tostring(mob.mobLevelMin)
        .. "-" .. tostring(mob.mobLevelMax or mob.mobLevelMin)
    end
    lines[#lines + 1] = "|cffaaaaaaBlock detail: session/area/XP context unavailable.|r"
  else
    lines[#lines + 1] = "This session: " .. FormatNumber(mob.sessionKills or 0)
    local playerLevel = self:GetPlayerLevel()
    if playerLevel then
      local atLevel = mob.killsAtLevel and tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0
      lines[#lines + 1] = "This level: " .. FormatNumber(atLevel)
    end

    if self:Supports("hasPerMobXP")
      and type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
      lines[#lines + 1] = "Avg base XP: " .. FormatNumber((tonumber(mob.xp.sumBase) or 0) / mob.xp.samples)
      lines[#lines + 1] = "Avg total XP: " .. FormatNumber((tonumber(mob.xp.sumTotal) or 0) / mob.xp.samples)
    end

    local topMap, topMapKills = nil, 0
    if type(mob.killsByMap) == "table" then
      for mapKey, kills in pairs(mob.killsByMap) do
        if (tonumber(kills) or 0) > topMapKills then
          topMapKills = tonumber(kills) or 0
          topMap = mapKey
        end
      end
    end
    if topMap then
      lines[#lines + 1] = "Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topMapKills) .. ")"
    end

    local minLevel, maxLevel
    if type(mob.killsAtLevel) == "table" then
      for levelKey, kills in pairs(mob.killsAtLevel) do
        local level = tonumber(levelKey)
        if level and (tonumber(kills) or 0) > 0 then
          if not minLevel or level < minLevel then
            minLevel = level
          end
          if not maxLevel or level > maxLevel then
            maxLevel = level
          end
        end
      end
    end
    if minLevel then
      lines[#lines + 1] = "Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
    end

    lines[#lines + 1] = "First seen: " .. FormatDate(mob.firstSeen)
    lines[#lines + 1] = "Last seen: " .. FormatAgo(mob.lastSeen)
  end
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateInstanceDetail(instanceKey)
  self:SetDetailMode(false)
  local db = self.char
  local instance = db.instances and db.instances[instanceKey]
  if type(instance) ~= "table" then
    return
  end
  local kills = tonumber(instance.kills) or 0
  local total = tonumber(db.totals.kills) or 0
  local percent = total > 0 and (kills / total * 100) or 0
  self.ui.heroName:SetText(instance.name or "Unknown instance")
  local subtitle = "Kills: " .. FormatNumber(kills)
    .. "  ·  " .. string.format("%.1f%%", percent) .. " of total"
  if self:Supports("hasPerMobXP") and (tonumber(instance.xp) or 0) > 0 then
    subtitle = subtitle .. "  ·  XP: " .. FormatNumber(instance.xp)
  end
  if instance.instanceType and instance.instanceType ~= "unknown" then
    subtitle = subtitle .. "  ·  " .. tostring(instance.instanceType)
  end
  self.ui.heroSub:SetText(subtitle)

  local top = TopMobsByField(self, db, "killsByInstance", instanceKey)
  local lines = { "Top mobs:" }
  for index = 1, min(#top, 6) do
    lines[#lines + 1] = "  " .. tostring(top[index].name) .. " - "
      .. FormatNumber(top[index].kills) .. " kills"
  end

  local minLevel, maxLevel = LevelRange(instance.killsAtLevel)
  if minLevel then
    lines[#lines + 1] = "Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
  end
  lines[#lines + 1] = "Last seen: " .. FormatAgo(instance.lastSeen)
  self.ui.details:SetText(table.concat(lines, "\n"))
end

local HISTORY_OVERLAY_KEYS = {
  deaths = true,
  rares = true,
  quests = true,
  heatmap = true,
}

function XPTooltip:GetHistoryOverlaySettings()
  local settings = self:GetSettings()
  local ui = settings and settings.ui
  if type(ui) ~= "table" then
    return { deaths = true, rares = true, quests = true, heatmap = true }
  end
  local overlays = ui.historyOverlays
  if type(overlays) ~= "table" then
    overlays = {}
    ui.historyOverlays = overlays
  end
  for key in pairs(HISTORY_OVERLAY_KEYS) do
    if overlays[key] == nil then overlays[key] = true end
  end
  return overlays
end

function XPTooltip:UpdateHistoryOverlayButtons()
  if not self.ui or not self.ui.historyButtons then return end
  local overlays = self:GetHistoryOverlaySettings()
  for key, button in pairs(self.ui.historyButtons) do
    if button.SetButtonState then
      button:SetButtonState("PUSHED", overlays[key] ~= false)
    end
  end
end

function XPTooltip:ToggleHistoryOverlay(key)
  if not HISTORY_OVERLAY_KEYS[key] then return end
  local overlays = self:GetHistoryOverlaySettings()
  overlays[key] = not (overlays[key] ~= false)
  self:UpdateHistoryOverlayButtons()
  if type(self.UpdateDetail) == "function" then
    self:UpdateDetail()
  end
end

local function AppendAreaDeaths(module, lines, mapKey)
  local deaths = module:NormalizeDeaths()
  local matches = {}
  for index = #deaths, 1, -1 do
    local entry = deaths[index]
    if tostring(entry.mapID) == tostring(mapKey) then
      matches[#matches + 1] = entry
    end
  end
  if #matches == 0 then return end
  lines[#lines + 1] = "Notable deaths:"
  for index = 1, min(#matches, 3) do
    local entry = matches[index]
    lines[#lines + 1] = "  " .. FormatAgo(entry.at) .. "  "
      .. string.format("%.1f, %.1f", (entry.x or 0) * 100, (entry.y or 0) * 100)
  end
end

local function AppendAreaRares(module, lines, mapKey)
  local matches = {}
  if module:UseJourneyIndexViews() then
    local rows = module:GetJourneyMobRows()
    for index = 1, #rows do
      local row = rows[index]
      local mob = row.mob
      local kills = type(mob) == "table" and type(mob.killsByMap) == "table"
        and tonumber(mob.killsByMap[tostring(mapKey)]) or 0
      local classification = tostring(row.classification or "")
      if kills > 0 and (classification == "elite" or classification == "rare"
        or classification == "rareelite" or classification == "worldboss") then
        matches[#matches + 1] = {
          name = tostring(row.name or "Unknown"), kills = kills,
        }
      end
    end
  else
    for _, mob in pairs(module.char.mobs or {}) do
      local kills = type(mob) == "table" and type(mob.killsByMap) == "table"
        and tonumber(mob.killsByMap[tostring(mapKey)]) or 0
      local classification = tostring(type(mob) == "table" and mob.classification or "")
      if kills > 0 and (classification == "elite" or classification == "rare"
        or classification == "rareelite" or classification == "worldboss") then
        matches[#matches + 1] = {
          name = tostring(mob.name or "Unknown"), kills = kills,
        }
      end
    end
  end
  if #matches == 0 then return end
  table.sort(matches, function(a, b)
    if a.kills == b.kills then return a.name < b.name end
    return a.kills > b.kills
  end)
  lines[#lines + 1] = "Rare/elite mobs:"
  for index = 1, min(#matches, 3) do
    local entry = matches[index]
    lines[#lines + 1] = "  " .. entry.name .. " - " .. FormatNumber(entry.kills) .. " kills"
  end
end

local function AppendAreaQuests(module, lines, mapKey)
  if type(module.GetQuestAnchors) == "function" then
    local anchors = module:GetQuestAnchors(mapKey, 3)
    if #anchors > 0 then
      lines[#lines + 1] = "Latest quest anchors:"
      for index = 1, #anchors do
        local anchor = anchors[index]
        local text = "  " .. tostring(anchor.name) .. " - " .. FormatAgo(anchor.at)
        if anchor.x and anchor.y then
          text = text .. string.format("  (%.1f, %.1f)",
            anchor.x * 100, anchor.y * 100)
        end
        lines[#lines + 1] = text
      end
      return
    end
  end
  local matches = {}
  for _, quest in pairs(module.char.quests or {}) do
    if type(quest) == "table" and tostring(quest.mapID or "") == tostring(mapKey)
      and (tonumber(quest.count) or 0) > 0 then
      matches[#matches + 1] = quest
    end
  end
  if #matches == 0 then return end
  table.sort(matches, function(a, b)
    return (tonumber(a.lastTurnInAt) or 0) > (tonumber(b.lastTurnInAt) or 0)
  end)
  lines[#lines + 1] = "Latest quest anchors:"
  for index = 1, min(#matches, 3) do
    local quest = matches[index]
    lines[#lines + 1] = "  " .. tostring(quest.name or "Unknown stake")
      .. " - " .. FormatAgo(quest.lastTurnInAt or 0)
  end
end

local function AppendAreaHeatmap(module, lines, mapKey)
  local total, cells
  if type(module.GetJourneyHeatmapZones) == "function" then
    local zones = module:GetJourneyHeatmapZones()
    for index = 1, #zones do
      local zone = zones[index]
      if tostring(zone.mapID) == tostring(mapKey) then
        total, cells = tonumber(zone.total) or 0, tonumber(zone.cellCount) or 0
        break
      end
    end
  end
  if not total then
    local heatmap = module.char.heatmaps and module.char.heatmaps[tostring(mapKey)]
    if type(heatmap) == "table" and type(heatmap.cells) == "table" then
      total = tonumber(heatmap.total) or 0
      cells = 0
      for _ in pairs(heatmap.cells) do cells = cells + 1 end
    end
  end
  if not total or total <= 0 then return end
  lines[#lines + 1] = "Heatmap: " .. FormatNumber(cells or 0) .. " cells, "
    .. FormatNumber(total) .. " kills"
end

function XPTooltip:UpdateAreaDetail(mapKey)
  self:SetDetailMode(false)
  local db = self.char
  local kills = self:GetAreaKillCount(mapKey)
  local total = tonumber(db.totals.kills) or 0
  local percent = total > 0 and (kills / total * 100) or 0
  self.ui.heroName:SetText(self:GetMapName(mapKey))
  self.ui.heroSub:SetText(
    "Kills: " .. FormatNumber(kills) .. "  ·  " .. string.format("%.1f%%", percent) .. " of total"
  )

  local top = TopMobsByField(self, db, "killsByMap", mapKey)
  local lines = {}
  lines[#lines + 1] = "Top mobs:"
  for index = 1, min(#top, 6) do
    lines[#lines + 1] = "  " .. tostring(top[index].name) .. " - " .. FormatNumber(top[index].kills) .. " kills"
  end

  local areaLevels = db.areaLevels and db.areaLevels[mapKey]
  local minLevel, maxLevel = LevelRange(areaLevels)
  if minLevel then
    lines[#lines + 1] = "Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
  end

  self:UpdateHistoryOverlayButtons()
  local overlays = self:GetHistoryOverlaySettings()
  if overlays.deaths then AppendAreaDeaths(self, lines, mapKey) end
  if overlays.rares then AppendAreaRares(self, lines, mapKey) end
  if overlays.quests then AppendAreaQuests(self, lines, mapKey) end
  if overlays.heatmap then AppendAreaHeatmap(self, lines, mapKey) end

  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateLevelDetail(levelKey)
  self:SetDetailMode(false)
  local db = self.char
  local kills = self:GetLevelKillCount(levelKey)
  local total = tonumber(db.totals.kills) or 0
  local percent = total > 0 and (kills / total * 100) or 0
  self.ui.heroName:SetText("Player level " .. tostring(levelKey))
  self.ui.heroSub:SetText(
    "Kills: " .. FormatNumber(kills) .. "  ·  " .. string.format("%.1f%%", percent) .. " of total"
  )

  local top = TopMobsByField(self, db, "killsAtLevel", levelKey)
  local lines = {}
  lines[#lines + 1] = "Top mobs:"
  for index = 1, min(#top, 8) do
    lines[#lines + 1] = "  " .. tostring(top[index].name) .. " - " .. FormatNumber(top[index].kills) .. " kills"
  end
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateDeleteButton(selected)
  local button = self.ui and self.ui.deleteButton
  if not button then
    return
  end
  local isMob = selected and selected.kind == "mob"
  button:SetShown(isMob and true or false)
  if isMob then
    local confirm = self.pendingDeleteKey == selected.key
      and (Now() - (self.pendingDeleteAt or 0)) <= 5
    button:SetText(confirm and "Confirm" or "Remove")
  end
end

function XPTooltip:RequestDeleteSelected()
  local selected = self:GetSelected()
  if not selected or selected.kind ~= "mob" then
    return
  end
  local now = Now()
  if self.pendingDeleteKey == selected.key
    and (now - (self.pendingDeleteAt or 0)) <= 5 then
    self:DeleteMobEntry(selected.key)
    return
  end
  self.pendingDeleteKey = selected.key
  self.pendingDeleteAt = now
  self:UpdateDeleteButton(selected)
  AceM2L2:SafePrint("Kill Story: click Remove again within 5 seconds to delete this entry.")
end
