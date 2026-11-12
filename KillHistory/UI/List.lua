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
local Lower = Util.Lower
local FormatNumber = Util.FormatNumber
local EnsureNumberMap = Util.EnsureNumberMap

function XPTooltip:BuildList()
  local list = {}
  local settings = self:GetSettings()
  local sortMode = settings and settings.ui and settings.ui.sort or "kills"
  local db = self.char
  if not db then
    self.currentList = list
    return
  end

  if self.tab == "areas" then
    for mapKey, kills in pairs(db.areas or {}) do
      local value = tonumber(kills) or 0
      if value > 0 then
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
    table.sort(list, function(a, b) return a.sortValue > b.sortValue end)
    local totalKills = tonumber(db.totals.kills) or 0
    for _, item in ipairs(list) do
      item.bar = totalKills > 0 and (item.kills / totalKills) or 0
    end
  elseif self.tab == "levels" then
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
          local value = tonumber(mob.kills) or 0
          local rowValue = FormatNumber(value) .. " kills"
          if type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) > 0 then
            local avg = FormatNumber((tonumber(mob.xp.sumBase) or 0) / mob.xp.samples)
            rowValue = rowValue .. "  |  avg " .. avg .. " XP"
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
    local label = sortMode == "lastSeen" and "Recent" or (sortMode == "name" and "Name" or "Kills")
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
  local startIndex = floor(offset / ROW_HEIGHT) + 1
  local theme = self:GetTheme()
  local eliteColor = { 1.00, 0.82, 0.20 }
  local bossColor = { 0.90, 0.30, 0.30 }
  local rareColor = { 0.30, 0.65, 0.95 }

  for index = 1, #self.rows do
    local row = self.rows[index]
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
  if self.tab ~= "mobs" then
    return
  end
  local settings = self:GetSettings()
  if not settings or type(settings.ui) ~= "table" then
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
  if self.ui and self.ui.sortButton then
    self.ui.sortButton:SetText("Sort: " .. (nextSort == "lastSeen" and "Recent" or (nextSort == "name" and "Name" or "Kills")))
  end
  self:BuildList()
  self:UpdateRows()
  self:UpdateDetail()
end
