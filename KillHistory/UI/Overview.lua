--[[---------------------------------------------------------------------------------
  KillHistory/UI/Overview.lua
  Overview cards, top-mob summary, and level-range panel.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local floor, min, max = math.floor, math.min, math.max
local CreateBackdropFrame = UI.CreateBackdropFrame
local FormatNumber = Util.FormatNumber
local FormatPercent = Util.FormatPercent
local FormatAgo = Util.FormatAgo
local FormatDuration = Util.FormatDuration
local FormatMoney = Util.FormatMoney
local Epoch = Util.Epoch

function XPTooltip:CreateOverviewPanel(frame)
  local panel = CreateBackdropFrame(frame)
  panel:SetPoint("TOPLEFT", 16, -90)
  panel:SetPoint("BOTTOMRIGHT", -16, 40)
  self:StylePanel(panel, "panel")
  panel.xpTooltipKind = "panel"
  frame.panels[#frame.panels + 1] = panel
  panel:Hide()

  local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 12, -10)
  header:SetText("Overview")

  local cards = {}
  local labels = {}
  local values = {}
  local accents = {}
  labels[#labels + 1] = header
  local contentWidth = (frame:GetWidth() or 1000) - 32
  local availableWidth = contentWidth - 24
  local cardGap = 8
  local cardWidth = floor((availableWidth - cardGap * 3) / 4)
  for index = 1, 4 do
    local card = CreateBackdropFrame(panel)
    card:SetSize(cardWidth, 78)
    card:SetPoint("TOPLEFT", 12 + (index - 1) * (cardWidth + cardGap), -42)
    self:StylePanel(card, "elevated")
    card.xpTooltipKind = "elevated"
    frame.panels[#frame.panels + 1] = card

    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 8, -1)
    accent:SetPoint("TOPRIGHT", -8, -1)
    accent:SetHeight(2)
    local theme = self:GetTheme()
    accent:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)
    card.accent = accent
    accents[#accents + 1] = accent

    local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetText("")
    labels[#labels + 1] = label

    local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    value:SetPoint("TOPLEFT", 10, -30)
    value:SetWidth(cardWidth - 20)
    value:SetWordWrap(true)
    value:SetText("0")
    values[#values + 1] = value

    cards[index] = { card = card, label = label, value = value }
  end

  local topPanel = CreateBackdropFrame(panel)
  topPanel:SetPoint("TOPLEFT", 12, -132)
  topPanel:SetSize(floor(availableWidth * 0.52), 180)
  self:StylePanel(topPanel, "elevated")
  topPanel.xpTooltipKind = "elevated"
  frame.panels[#frame.panels + 1] = topPanel

  local topTitle = topPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  topTitle:SetPoint("TOPLEFT", 10, -8)
  topTitle:SetText("Most killed")
  labels[#labels + 1] = topTitle

  local topMobsText = topPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  topMobsText:SetPoint("TOPLEFT", 10, -30)
  topMobsText:SetPoint("BOTTOMRIGHT", -10, 8)
  topMobsText:SetJustifyH("LEFT")
  topMobsText:SetJustifyV("TOP")
  topMobsText:SetWordWrap(true)
  topMobsText:SetText("")

  local levelPanel = CreateBackdropFrame(panel)
  levelPanel:SetPoint("TOPLEFT", topPanel, "TOPRIGHT", 10, 0)
  levelPanel:SetPoint("BOTTOMRIGHT", -12, 12)
  self:StylePanel(levelPanel, "elevated")
  levelPanel.xpTooltipKind = "elevated"
  frame.panels[#frame.panels + 1] = levelPanel

  local levelTitle = levelPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  levelTitle:SetPoint("TOPLEFT", 10, -8)
  levelTitle:SetText("Level range")
  labels[#labels + 1] = levelTitle

  local levelText = levelPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  levelText:SetPoint("TOPLEFT", 10, -30)
  levelText:SetPoint("BOTTOMRIGHT", -10, 10)
  levelText:SetJustifyH("LEFT")
  levelText:SetJustifyV("TOP")
  levelText:SetWordWrap(true)
  levelText:SetText("")

  frame.overview = {
    panel = panel,
    cards = cards,
    labels = labels,
    values = values,
    topMobsText = topMobsText,
    levelText = levelText,
    accents = accents,
  }
end

function XPTooltip:RefreshOverview()
  if not self.ui or not self.ui.overview then
    return
  end
  local db = self.char
  if not db then
    return
  end
  local overview = self.ui.overview
  local total = tonumber(db.totals.kills) or 0
  local session = tonumber(db.session.kills) or 0
  local unique = tonumber(db.totals.uniqueMobs) or 0

  local topMap, topMapKills = nil, 0
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > topMapKills then
      topMapKills = tonumber(kills) or 0
      topMap = mapKey
    end
  end

  overview.cards[1].label:SetText("Total kills")
  overview.cards[1].value:SetText(FormatNumber(total))
  overview.cards[2].label:SetText("This session")
  overview.cards[2].value:SetText(FormatNumber(session))
  overview.cards[3].label:SetText("Mobs tracked")
  overview.cards[3].value:SetText(FormatNumber(unique))
  overview.cards[4].label:SetText("Top area")
  overview.cards[4].value:SetText(topMap and self:GetMapName(topMap) or "None")

  local mobs = {}
  for mobKey, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" and (tonumber(mob.kills) or 0) > 0 then
      mobs[#mobs + 1] = { key = mobKey, mob = mob, kills = tonumber(mob.kills) or 0 }
    end
  end
  table.sort(mobs, function(a, b) return a.kills > b.kills end)
  local lines = {}
  for index = 1, min(#mobs, 8) do
    local entry = mobs[index]
    lines[#lines + 1] = string.format(
      "%d. %s  -  %s kills", index, tostring(entry.mob.name or "Unknown"), FormatNumber(entry.kills)
    )
  end
  if #lines == 0 then
    local profile = self:GetClientProfile()
    lines[1] = "No kills recorded yet.\n"
      .. (profile and profile:GetEmptyStateText() or "Kill a mob to start the history.")
  end
  overview.topMobsText:SetText(table.concat(lines, "\n"))

  local minLevel, maxLevel, topLevel, topLevelKills
  for levelKey, kills in pairs(db.levels or {}) do
    local level = tonumber(levelKey)
    local value = tonumber(kills) or 0
    if level and value > 0 then
      if not minLevel or level < minLevel then
        minLevel = level
      end
      if not maxLevel or level > maxLevel then
        maxLevel = level
      end
      if not topLevelKills or value > topLevelKills then
        topLevelKills = value
        topLevel = level
      end
    end
  end

  local levelLines = {}
  if minLevel then
    levelLines[#levelLines + 1] = "Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
    levelLines[#levelLines + 1] = "Most kills: level " .. tostring(topLevel) .. " (" .. FormatNumber(topLevelKills) .. ")"
  else
    levelLines[#levelLines + 1] = "No level data yet."
  end
  local questGains, questXP = self:GetQuestSummary()
  if questGains > 0 then
    levelLines[#levelLines + 1] = "Quest XP: " .. FormatNumber(questXP)
      .. " from " .. FormatNumber(questGains) .. " gains"
  end
  local settings = self:GetSettings()
  if settings and settings.showXPBonuses then
    local bonuses, _, totalPercent = self:GetActiveXPBonuses()
    local bonusText = self:FormatXPBonuses(bonuses, totalPercent)
    if bonusText then
      levelLines[#levelLines + 1] = "XP bonuses: " .. bonusText
    end
  end
  local _, _, remainingXP, remainingPercent = self:GetXPProgress()
  if remainingXP then
    levelLines[#levelLines + 1] = "XP remaining: " .. FormatNumber(remainingXP)
      .. " (" .. FormatPercent(remainingPercent) .. ")"
  end

  local rateWindow = (tonumber(settings and settings.rateWindowMinutes) or 10) * 60
  if settings and settings.showXPRate and type(self.GetXPRate) == "function" then
    local ok, xpPerHour, xpPerMinute = pcall(self.GetXPRate, self, rateWindow)
    if ok and xpPerHour then
      levelLines[#levelLines + 1] = "XP rate: " .. FormatNumber(xpPerHour) .. "/hr ("
        .. FormatNumber(xpPerMinute) .. "/min)"
    end
  end
  if settings and settings.showTimeToLevel and type(self.GetTimeToLevel) == "function" then
    local ok, seconds = pcall(self.GetTimeToLevel, self, rateWindow)
    if ok and seconds then
      levelLines[#levelLines + 1] = "Time to level: " .. FormatDuration(seconds)
    end
  end

  if settings and settings.showGrindingSpot and type(self.GetGrindingSpots) == "function" then
    local ok, spots = pcall(self.GetGrindingSpots, self, 1)
    local spot = ok and type(spots) == "table" and spots[1] or nil
    if type(spot) == "table" then
      local level = floor(tonumber(spot.level) or 0)
      local zone = type(spot.zone) == "string" and spot.zone or nil
      if not zone and type(spot.mapName) == "string" then
        zone = spot.mapName
      end
      if not zone and tonumber(spot.mapID) then
        zone = self:GetMapName(spot.mapID)
      end
      local xpPerHour = tonumber(spot.xpPerHour) or tonumber(spot.rate) or 0
      if zone and level > 0 then
        levelLines[#levelLines + 1] = "Grinding spot: " .. zone .. " (level " .. tostring(level)
          .. "), " .. FormatNumber(xpPerHour) .. "/hr"
      end
    end
  end

  local history = self:NormalizeLevelHistory()
  local now = Epoch()
  local supportsXP = self:Supports("hasPerMobXP")

  if settings and settings.showDungeonXP then
    local dungeon = db.dungeon
    if type(dungeon) == "table" then
      local dungeonXP = tonumber(dungeon.xp) or 0
      local dungeonKills = tonumber(dungeon.kills) or 0
      local sessionKills = tonumber(dungeon.sessionKills) or 0
      if dungeonKills > 0 or (supportsXP and dungeonXP > 0) then
        local text
        if supportsXP then
          text = "Dungeon: " .. FormatNumber(dungeonXP) .. " XP"
          local totalXP = (tonumber(db.totals.xp) or 0) + (tonumber(questXP) or 0)
          if totalXP > 0 then
            text = text .. " (" .. FormatPercent(dungeonXP / totalXP * 100) .. " of total)"
          end
          text = text .. ", " .. FormatNumber(dungeonKills) .. " kills ("
            .. FormatNumber(sessionKills) .. " this session)"
        else
          text = "Dungeon: " .. FormatNumber(dungeonKills) .. " kills ("
            .. FormatNumber(sessionKills) .. " this session)"
        end
        levelLines[#levelLines + 1] = text
      end
    end
  end

  local economy = db.economy
  if settings and settings.showEconomy and self:Supports("hasLootValue") and self.lootEventAvailable
    and type(economy) == "table" and (tonumber(economy.sessionItems) or 0) > 0 then
    levelLines[#levelLines + 1] = "Loot: " .. FormatMoney(economy.sessionLootValue)
      .. " (" .. FormatNumber(economy.sessionItems) .. " items)"
  end
  if settings and settings.showGoldPerHour and type(self.GetGoldPerHour) == "function" then
    local ok, goldPerHour = pcall(self.GetGoldPerHour, self)
    if ok and type(goldPerHour) == "number" then
      levelLines[#levelLines + 1] = "Gold/hour: " .. FormatMoney(goldPerHour * 10000)
    end
  end

  if settings and settings.showGoal then
    local goal = db.goal
    local targetLevel = type(goal) == "table" and (tonumber(goal.targetLevel) or 0) or 0
    if targetLevel > 0 then
      local currentLevel = self:GetPlayerLevel() or 0
      local levelsToGo = max(0, targetLevel - currentLevel)
      local text = "Goal: level " .. tostring(targetLevel)
      if levelsToGo <= 0 then
        text = text .. " (reached)"
      else
        text = text .. " (" .. tostring(levelsToGo) .. " levels to go)"
      end
      if supportsXP then
        local sinceSet = max(0, (tonumber(db.totals.xp) or 0) - (tonumber(goal.targetXP) or 0))
        text = text .. ", " .. FormatNumber(sinceSet) .. " XP since set"
        local _, _, remaining = self:GetXPProgress()
        if remaining then
          text = text .. ", " .. FormatNumber(remaining) .. " XP to next level"
        end
      end
      levelLines[#levelLines + 1] = text
    end
  end

  if settings and settings.showSplits then
    for index = #history, 1, -1 do
      local record = history[index]
      local level = tonumber(record.level) or 0
      if level > 0 then
        local duration = tonumber(record.duration) or 0
        if (tonumber(record.endedAt) or 0) == 0 then
          duration = max(0, now - (tonumber(record.startedAt) or now))
        end
        local text = "Last level: L" .. tostring(level) .. " " .. FormatDuration(duration)
        if supportsXP then
          text = text .. ", " .. FormatNumber(record.xpGained) .. " XP"
        end
        text = text .. ", " .. FormatNumber(record.kills) .. " kills"
        levelLines[#levelLines + 1] = text
        break
      end
    end
  end

  if #history > 0 then
    levelLines[#levelLines + 1] = ""
    levelLines[#levelLines + 1] = "Level history:"
    local shown = 0
    for index = #history, 1, -1 do
      if shown >= 3 then
        break
      end
      local record = history[index]
      local duration = tonumber(record.duration) or 0
      if (tonumber(record.endedAt) or 0) == 0 then
        duration = max(0, now - (tonumber(record.startedAt) or now))
      end
      local text = "  L" .. tostring(record.level) .. " " .. FormatDuration(duration)
      if supportsXP then
        text = text .. ", " .. FormatNumber(record.xpGained) .. " XP"
      end
      text = text .. ", " .. FormatNumber(record.kills) .. " kills"
      levelLines[#levelLines + 1] = text
      shown = shown + 1
    end
  end
  levelLines[#levelLines + 1] = ""
  levelLines[#levelLines + 1] = "Use the tabs above to browse mobs, areas, and levels."
  overview.levelText:SetText(table.concat(levelLines, "\n"))
end
