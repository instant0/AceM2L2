--[[---------------------------------------------------------------------------------
  KillHistory/UI/List.lua
  List model, filtering, sorting, row rendering, and selection.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local floor, min, max = math.floor, math.min, math.max
local ROW_HEIGHT = Util.ROW_HEIGHT
local VISIBLE_ROWS = Util.VISIBLE_ROWS
local SafeNumber = Util.SafeNumber
local SafeString = Util.SafeString
local Lower = Util.Lower
local FormatNumber = Util.FormatNumber
local FormatDuration = Util.FormatDuration
local FormatAgo = Util.FormatAgo
local IsAttributableMapID = Util.IsAttributableMapID

local HISTORY_DEATH_LIMIT = 25
local HISTORY_RESPAWN_LIMIT = 50
local MIN_RESPAWN_SAMPLES = XPTooltip.MIN_RESPAWN_SAMPLES or 3
local QUEST_LEDGER_LIMIT = 100

function XPTooltip:ResetScroll()
  if self.ui and self.ui.scrollFrame and self.ui.scrollFrame.SetVerticalScroll then
    pcall(self.ui.scrollFrame.SetVerticalScroll, self.ui.scrollFrame, 0)
  end
end

local function BuildHistoryRows(self, list, sortMode, search)
  local db = self.char
  if type(db) ~= "table" then
    return
  end
  local deathsAvailable, respawnsAvailable = self:GetHistoryAvailability()

  if deathsAvailable then
    local deaths = self:NormalizeDeaths()
    local first = max(1, #deaths - HISTORY_DEATH_LIMIT + 1)
    for index = first, #deaths do
      local entry = deaths[index]
      local label = "Death · " .. self:GetMapName(entry.mapID)
      local haystack = Lower(label) or ""
      if search == "" or haystack:find(search, 1, true) then
        list[#list + 1] = {
          kind = "death",
          key = "death:" .. tostring(index),
          label = label,
          value = FormatAgo(entry.at) .. "  ·  "
            .. string.format("%.1f, %.1f", entry.x * 100, entry.y * 100),
          sortAt = tonumber(entry.at) or 0,
          sortName = haystack,
          mapID = entry.mapID,
          x = entry.x,
          y = entry.y,
          at = entry.at,
        }
      end
    end
  end

  if respawnsAvailable then
    local entries = {}
    for key, entry in pairs(db.respawns or {}) do
      if type(entry) == "table" then
        local npcID = tonumber(key)
        if npcID and npcID > 0 then
          local name = SafeString(entry.name)
          if not name or name == "" then
            name = "NPC " .. tostring(npcID)
          end
          local average, samples, minimum, maximum, lastSeen =
            self:GetRespawnStats(npcID)
          samples = samples or 0
          if samples > 0 then
            local haystack = Lower(name) or ""
            if search == "" or haystack:find(search, 1, true) then
              entries[#entries + 1] = {
                npcID = npcID,
                name = name,
                haystack = haystack,
                average = average,
                samples = samples,
                minimum = minimum or 0,
                maximum = maximum or 0,
                lastSeen = lastSeen or 0,
              }
            end
          end
        end
      end
    end
    table.sort(entries, function(a, b)
      if a.samples ~= b.samples then
        return a.samples > b.samples
      end
      return a.haystack < b.haystack
    end)
    for index = 1, min(#entries, HISTORY_RESPAWN_LIMIT) do
      local entry = entries[index]
      local value
      if entry.samples >= MIN_RESPAWN_SAMPLES and entry.average then
        value = FormatDuration(entry.average) .. " avg  ·  "
          .. FormatNumber(entry.samples) .. " samples"
      else
        value = FormatNumber(entry.samples) .. " samples (need "
          .. tostring(MIN_RESPAWN_SAMPLES) .. ")"
      end
      list[#list + 1] = {
        kind = "respawn",
        key = "respawn:" .. tostring(entry.npcID),
        label = entry.name,
        name = entry.name,
        value = value,
        sortAt = entry.lastSeen,
        sortName = entry.haystack,
        npcID = entry.npcID,
        average = entry.average,
        samples = entry.samples,
        minimum = entry.minimum,
        maximum = entry.maximum,
        lastSeen = entry.lastSeen,
        hasAverage = entry.samples >= MIN_RESPAWN_SAMPLES and entry.average ~= nil,
      }
    end
  end

  if sortMode == "name" then
    table.sort(list, function(a, b)
      if a.sortName == b.sortName then
        return a.sortAt > b.sortAt
      end
      return a.sortName < b.sortName
    end)
  else
    table.sort(list, function(a, b)
      if a.sortAt == b.sortAt then
        return a.sortName < b.sortName
      end
      return a.sortAt > b.sortAt
    end)
  end
end

local function BuildQuestRows(self, list, sortMode, search)
  if not self:Supports("hasPerMobXP") then
    return
  end
  local db = self.char
  if type(db) ~= "table" then
    return
  end
  local entries = {}
  for key, quest in pairs(db.quests or {}) do
    if type(quest) == "table" then
      local count = tonumber(quest.count) or 0
      if count > 0 then
        local name = SafeString(quest.name)
        if not name or name == "" then
          name = tostring(key)
        end
        local haystack = Lower(name) or ""
        local keyText = Lower(tostring(key)) or ""
        if search == "" or haystack:find(search, 1, true)
          or keyText:find(search, 1, true) then
          entries[#entries + 1] = {
            key = key,
            name = name,
            haystack = haystack,
            count = count,
            totalXP = tonumber(quest.totalXP) or 0,
            lastSeen = tonumber(quest.lastSeen) or 0,
            firstSeen = tonumber(quest.firstSeen) or 0,
            questID = tonumber(quest.id),
          }
        end
      end
    end
  end

  table.sort(entries, function(a, b)
    if sortMode == "count" then
      if a.count ~= b.count then return a.count > b.count end
      if a.totalXP ~= b.totalXP then return a.totalXP > b.totalXP end
    elseif sortMode == "name" then
      if a.haystack ~= b.haystack then return a.haystack < b.haystack end
    elseif sortMode == "recent" then
      if a.lastSeen ~= b.lastSeen then return a.lastSeen > b.lastSeen end
    else
      if a.totalXP ~= b.totalXP then return a.totalXP > b.totalXP end
      if a.count ~= b.count then return a.count > b.count end
    end
    return a.haystack < b.haystack
  end)

  for index = 1, min(#entries, QUEST_LEDGER_LIMIT) do
    local entry = entries[index]
    list[#list + 1] = {
      kind = "quest",
      key = entry.key,
      label = entry.name,
      value = FormatNumber(entry.totalXP) .. " XP  ·  "
        .. FormatNumber(entry.count) .. " gains",
      sortXP = entry.totalXP,
      sortCount = entry.count,
      sortName = entry.haystack,
      sortLastSeen = entry.lastSeen,
      count = entry.count,
      totalXP = entry.totalXP,
      lastSeen = entry.lastSeen,
      firstSeen = entry.firstSeen,
      questID = entry.questID,
    }
  end
end

function XPTooltip:BuildList()
  local list = {}
  local settings = self:GetSettings()
  local sortMode = settings and settings.ui and settings.ui.sort or "kills"
  local historySort = settings and settings.ui and settings.ui.historySort or "recent"
  local questSort = settings and settings.ui and settings.ui.questSort or "xp"
  local db = self.char
  if not db then
    self.currentList = list
    return
  end

  if self.tab == "quests" then
    BuildQuestRows(self, list, questSort, Lower(self.searchText) or "")
  elseif self.tab == "deaths" then
    BuildHistoryRows(self, list, historySort, Lower(self.searchText) or "")
  elseif self.tab == "areas" then
    if self:UseJourneyIndexViews() then
      local rows = self:GetAreaRows()
      for index = 1, #rows do
        local row = rows[index]
        list[#list + 1] = {
          kind = row.kind,
          key = row.key,
          label = row.label,
          value = FormatNumber(row.kills) .. " kills",
          sortValue = row.kills,
          kills = row.kills,
        }
      end
    else
      for mapKey, kills in pairs(db.areas or {}) do
        local value = tonumber(kills) or 0
        if value > 0 and (not IsAttributableMapID or IsAttributableMapID(mapKey)) then
          list[#list + 1] = {
            kind = "area",
            key = mapKey,
            label = self:GetMapName(mapKey),
            value = FormatNumber(value) .. " kills",
            sortValue = value,
            kills = value,
          }
        end
      end
      for instanceKey, instance in pairs(db.instances or {}) do
        if type(instance) == "table" then
          local value = tonumber(instance.kills) or 0
          if value > 0 then
            list[#list + 1] = {
              kind = "instance",
              key = instanceKey,
              label = instance.name or "Unknown instance",
              value = FormatNumber(value) .. " kills",
              sortValue = value,
              kills = value,
            }
          end
        end
      end
    end
    table.sort(list, function(a, b)
      if a.sortValue == b.sortValue then
        return tostring(a.key) < tostring(b.key)
      end
      return a.sortValue > b.sortValue
    end)
    local totalKills = tonumber(db.totals.kills) or 0
    for _, item in ipairs(list) do
      item.bar = totalKills > 0 and (item.kills / totalKills) or 0
    end
  elseif self.tab == "levels" then
    if self:UseJourneyIndexViews() then
      local rows = self:GetLevelRows()
      for index = 1, #rows do
        local row = rows[index]
        list[#list + 1] = {
          kind = row.kind,
          key = row.key,
          label = row.label,
          value = FormatNumber(row.kills) .. " kills",
          sortValue = row.level,
          kills = row.kills,
        }
      end
    else
      for levelKey, kills in pairs(db.levels or {}) do
        local level = tonumber(levelKey) or 0
        local value = tonumber(kills) or 0
        if level > 0 and value > 0 then
          list[#list + 1] = {
            kind = "level",
            key = levelKey,
            label = "Level " .. tostring(level),
            value = FormatNumber(value) .. " kills",
            sortValue = level,
            kills = value,
          }
        end
      end
    end
    table.sort(list, function(a, b) return a.sortValue < b.sortValue end)
    local maxKills = 0
    for _, item in ipairs(list) do
      if item.kills > maxKills then
        maxKills = item.kills
      end
    end
    for _, item in ipairs(list) do
      item.bar = maxKills > 0 and (item.kills / maxKills) or 0
    end
  else
    local search = Lower(self.searchText) or ""
    local playerLevel = self:GetPlayerLevel()
    local function appendMob(mobKey, mob)
      if type(mob) ~= "table" or (tonumber(mob.kills) or 0) <= 0 then
        return
      end
      local value = tonumber(mob.kills) or 0
      local rowValue = FormatNumber(value) .. " kills"
      if self:Supports("hasPerMobXP")
        and type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
        local avg = FormatNumber((tonumber(mob.xp.sumBase) or 0) / mob.xp.samples)
        rowValue = rowValue .. " | avg " .. avg .. " XP"
      end
      list[#list + 1] = {
        kind = "mob",
        key = mobKey,
        label = tostring(mob.name or "Unknown"),
        value = rowValue,
        sortKills = value,
        sortName = Lower(mob.name) or "",
        sortSeen = tonumber(mob.lastSeen) or 0,
        classification = mob.classification,
      }
    end

    if self:UseJourneyIndexViews() then
      local rows = self:GetJourneyMobsForFilter(self.filter, search)
      for index = 1, #rows do
        local row = rows[index]
        appendMob(row.key, row.mob)
      end
    else
      for mobKey, mob in pairs(db.mobs or {}) do
        if type(mob) == "table" and (tonumber(mob.kills) or 0) > 0 then
          local name = Lower(mob.name) or ""
          local include = true
          if self.filter == "level" then
            include = playerLevel
              and type(mob.killsAtLevel) == "table"
              and (tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0) > 0
          elseif self.filter == "session" then
            include = (tonumber(mob.sessionKills) or 0) > 0
          elseif self.filter == "elite" then
            include = mob.classification == "elite"
              or mob.classification == "rareelite"
              or mob.classification == "worldboss"
          end
          if include and (search == "" or name:find(search, 1, true)) then
            appendMob(mobKey, mob)
          end
        end
      end
    end
    local maxKills = 0
    for _, item in ipairs(list) do
      if item.sortKills > maxKills then
        maxKills = item.sortKills
      end
    end
    for _, item in ipairs(list) do
      item.bar = maxKills > 0 and (item.sortKills / maxKills) or 0
    end
    if sortMode == "name" then
      table.sort(list, function(a, b) return a.sortName < b.sortName end)
    elseif sortMode == "lastSeen" then
      table.sort(list, function(a, b) return a.sortSeen > b.sortSeen end)
    else
      table.sort(list, function(a, b)
        if a.sortKills == b.sortKills then
          return a.sortName < b.sortName
        end
        return a.sortKills > b.sortKills
      end)
    end
  end

  self.currentList = list
  if self.ui and self.ui.scrollChild then
    if type(self.UpdateListLayout) == "function" then
      pcall(self.UpdateListLayout, self)
    end
    self.ui.scrollChild:SetSize(self.ui.rowWidth or 390, math.max(1, #list * ROW_HEIGHT))
    if self.ui.scrollFrame and self.ui.scrollFrame.UpdateScrollChildRect then
      pcall(self.ui.scrollFrame.UpdateScrollChildRect, self.ui.scrollFrame)
    end
  end
  if #list > 0 then
    self.selectedIndex = max(1, min(self.selectedIndex or 1, #list))
  else
    self.selectedIndex = 0
  end
  if self.ui and self.ui.sortButton then
    local label
    if self.tab == "deaths" then
      label = historySort == "name" and "Name" or "Recent"
    elseif self.tab == "quests" then
      local labels = { xp = "XP", count = "Count", name = "Name", recent = "Recent" }
      label = labels[questSort] or "XP"
    else
      label = sortMode == "lastSeen" and "Recent" or (sortMode == "name" and "Name" or "Kills")
    end
    self.ui.sortButton:SetText("Sort: " .. label)
  end
end

function XPTooltip:UpdateRows()
  if not self.rows or not self.ui or not self.ui.scrollChild then
    return
  end
  local list = self.currentList or {}
  local offset = 0
  if self.ui and self.ui.scrollFrame then
    offset = SafeNumber(self.ui.scrollFrame:GetVerticalScroll()) or 0
  end
  if type(self.UpdateListLayout) == "function" then
    pcall(self.UpdateListLayout, self)
  end
  local visibleRows = self.ui.visibleRows or VISIBLE_ROWS
  local startIndex = floor(offset / ROW_HEIGHT) + 1
  local theme = self:GetTheme()
  local eliteColor = { 1.00, 0.82, 0.20 }
  local bossColor = { 0.90, 0.30, 0.30 }
  local rareColor = { 0.30, 0.65, 0.95 }

  for index = 1, visibleRows do
    local row = self.rows[index]
    if not row and type(self.EnsureListRow) == "function" then
      row = self:EnsureListRow(index)
    end
    if not row then
      break
    end
    local data = list[startIndex + index - 1]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.ui.scrollChild, "TOPLEFT", 0, -((startIndex + index - 2) * ROW_HEIGHT))
    if data then
      row.index = startIndex + index - 1
      row.text:SetText(data.label or "")
      row.value:SetText(data.value or "")
      local label = data.label or "?"
      if row.crestText then
        row.crestText:SetText(label:sub(1, 1):upper())
        if row.crestText.SetTextColor then
          row.crestText:SetTextColor(0.05, 0.05, 0.05)
        end
      end
      local crestColor = theme.accent
      if data.classification == "elite" or data.classification == "rareelite" then
        crestColor = eliteColor
      elseif data.classification == "worldboss" then
        crestColor = bossColor
      elseif data.classification == "rare" then
        crestColor = rareColor
      end
      if row.crest then
        row.crest:SetColorTexture(crestColor[1], crestColor[2], crestColor[3], 0.55)
      end
      row:Show()
      if data.bar and data.bar > 0 then
        row.bar:SetWidth(max(1, (row:GetWidth() - 8) * min(data.bar, 1)))
        row.bar:SetColorTexture(theme.bar[1], theme.bar[2], theme.bar[3], theme.bar[4])
        row.bar:Show()
      else
        row.bar:Hide()
      end
      if row.index == self.selectedIndex then
        row.background:SetColorTexture(theme.accentSoft[1], theme.accentSoft[2], theme.accentSoft[3], theme.accentSoft[4])
      else
        row.background:SetColorTexture(1, 1, 1, 0.04)
      end
    else
      row.index = nil
      row.bar:Hide()
      row:Hide()
    end
  end
  for index = visibleRows + 1, #self.rows do
    local row = self.rows[index]
    if row then
      row.index = nil
      row.bar:Hide()
      row:Hide()
    end
  end
end

function XPTooltip:SelectIndex(index)
  if not index or index <= 0 then
    return
  end
  self.selectedIndex = index
  self:UpdateRows()
  self:UpdateDetail()
end

function XPTooltip:GetSelected()
  if not self.currentList or not self.selectedIndex then
    return nil
  end
  return self.currentList[self.selectedIndex]
end

function XPTooltip:SetFilter(filter)
  if filter ~= "all" and filter ~= "level" and filter ~= "session" and filter ~= "elite" then
    return
  end
  self.filter = filter
  self.selectedIndex = 1
  self:ResetScroll()
  self:UpdateFilterButtons()
  self:BuildList()
  self:UpdateRows()
  self:UpdateDetail()
end

function XPTooltip:UpdateFilterButtons()
  if not self.ui or not self.ui.filterButtons then
    return
  end
  for key, button in pairs(self.ui.filterButtons) do
    if button.SetButtonState then
      button:SetButtonState("PUSHED", key == self.filter)
    end
  end
end

function XPTooltip:CycleSort()
  local settings = self:GetSettings()
  if not settings or type(settings.ui) ~= "table" then
    return
  end
  if self.tab == "deaths" then
    settings.ui.historySort = settings.ui.historySort == "name" and "recent" or "name"
    self.selectedIndex = 1
    self:ResetScroll()
    if self.ui and self.ui.sortButton then
      self.ui.sortButton:SetText("Sort: "
        .. (settings.ui.historySort == "name" and "Name" or "Recent"))
    end
    self:BuildList()
    self:UpdateRows()
    self:UpdateDetail()
    return
  end
  if self.tab == "quests" then
    local order = { "xp", "count", "name", "recent" }
    local labels = { xp = "XP", count = "Count", name = "Name", recent = "Recent" }
    local current = settings.ui.questSort or "xp"
    local nextSort = "xp"
    for index, value in ipairs(order) do
      if current == value then
        nextSort = order[(index % #order) + 1]
        break
      end
    end
    settings.ui.questSort = nextSort
    self.selectedIndex = 1
    self:ResetScroll()
    if self.ui and self.ui.sortButton then
      self.ui.sortButton:SetText("Sort: " .. (labels[nextSort] or "XP"))
    end
    self:BuildList()
    self:UpdateRows()
    self:UpdateDetail()
    return
  end
  if self.tab ~= "mobs" then
    return
  end
  local order = { "kills", "name", "lastSeen" }
  local nextSort = "kills"
  for index, value in ipairs(order) do
    if settings.ui.sort == value then
      nextSort = order[(index % #order) + 1]
      break
    end
  end
  settings.ui.sort = nextSort
  self.selectedIndex = 1
  self:ResetScroll()
  if self.ui and self.ui.sortButton then
    self.ui.sortButton:SetText("Sort: " .. (nextSort == "lastSeen" and "Recent" or (nextSort == "name" and "Name" or "Kills")))
  end
  self:BuildList()
  self:UpdateRows()
  self:UpdateDetail()
end
