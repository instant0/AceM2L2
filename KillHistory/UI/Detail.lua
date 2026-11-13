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

local function TopMobsByField(db, field, key, limit)
  local top = {}
  for _, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" and type(mob[field]) == "table" then
      local value = tonumber(mob[field][key]) or 0
      if value > 0 then
        top[#top + 1] = { name = mob.name or "Unknown", kills = value }
      end
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
  elseif selected.kind == "area" then
    self:HideModel("")
    self:UpdateAreaDetail(selected.key)
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

function XPTooltip:UpdateMobDetail(mobKey)
  self:SetDetailMode(true)
  local mob = self.char and self.char.mobs[mobKey]
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
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateAreaDetail(mapKey)
  self:SetDetailMode(false)
  local db = self.char
  local kills = tonumber(db.areas[mapKey]) or 0
  local total = tonumber(db.totals.kills) or 0
  local percent = total > 0 and (kills / total * 100) or 0
  self.ui.heroName:SetText(self:GetMapName(mapKey))
  self.ui.heroSub:SetText(
    "Kills: " .. FormatNumber(kills) .. "  ·  " .. string.format("%.1f%%", percent) .. " of total"
  )

  local top = TopMobsByField(db, "killsByMap", mapKey)
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
  self.ui.details:SetText(table.concat(lines, "\n"))
end

function XPTooltip:UpdateLevelDetail(levelKey)
  self:SetDetailMode(false)
  local db = self.char
  local kills = tonumber(db.levels[levelKey]) or 0
  local total = tonumber(db.totals.kills) or 0
  local percent = total > 0 and (kills / total * 100) or 0
  self.ui.heroName:SetText("Player level " .. tostring(levelKey))
  self.ui.heroSub:SetText(
    "Kills: " .. FormatNumber(kills) .. "  ·  " .. string.format("%.1f%%", percent) .. " of total"
  )

  local top = TopMobsByField(db, "killsAtLevel", levelKey)
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
