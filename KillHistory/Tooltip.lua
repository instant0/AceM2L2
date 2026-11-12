--[[---------------------------------------------------------------------------------
  KillHistory/Tooltip.lua
  Tooltip hook installation, unit filtering, and tooltip line rendering.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util
local Formula = XPTooltip.Formula

local floor, min, max = math.floor, math.min, math.max
local IsSecret = Util.IsSecret
local SafeCall = Util.SafeCall
local SafeNumber = Util.SafeNumber
local SafeString = Util.SafeString
local SafeBool = Util.SafeBool
local Trim = Util.Trim
local ContextKey = Formula.ContextKey
local RoundForever = Formula.RoundForever
local FormatNumber = Util.FormatNumber
local FormatPercent = Util.FormatPercent

function XPTooltip:InstallTooltipHook()
  if self.tooltipHookInstalled then
    return
  end
  self.tooltipHookInstalled = true

  local installed = false
  if self.hasProcessor then
    local ok = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tooltip, data)
      self:OnTooltip(tooltip, data)
    end)
    installed = ok
  end

  if not installed and GameTooltip and GameTooltip.HookScript then
    local ok = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tooltip)
      self:OnTooltip(tooltip, nil)
    end)
    installed = ok
    if ok then
      self.hasProcessor = false
    end
  end

  if not installed then
    self.tooltipHookInstalled = false
    self:ReportError("tooltip hook", "no usable tooltip hook")
  end

  if GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(tooltip)
      tooltip.xpTooltipSignature = nil
    end)
  end
end

function XPTooltip:OnTooltip(tooltip, data)
  if not self:IsActive() then
    return
  end
  if not tooltip or tooltip ~= GameTooltip then
    return
  end

  local ok, err = pcall(self.AddTooltipLines, self, tooltip, data)
  if not ok then
    self:ReportError("tooltip", err)
  end
end

function XPTooltip:IsTooltipCandidate(unit)
  if not unit or type(unit) ~= "string" or IsSecret(unit) then
    return false
  end
  if not UnitExists(unit) then
    return false
  end
  local isPlayer = SafeBool(SafeCall(UnitIsPlayer, unit))
  if isPlayer == nil or isPlayer then
    return false
  end
  local isDead = SafeBool(SafeCall(UnitIsDead, unit))
  if isDead == nil or isDead then
    return false
  end
  local controlled = SafeBool(SafeCall(UnitPlayerControlled, unit))
  if controlled == nil or controlled then
    return false
  end
  local creatureType = SafeCall(UnitCreatureType, unit)
  if creatureType == "Critter" then
    return false
  end
  local canAttack = SafeBool(SafeCall(UnitCanAttack, "player", unit))
  return canAttack == true
end

function XPTooltip.AddTooltipLines(self, tooltip, data)
  local unit = select(2, tooltip:GetUnit())
  if not unit and data then
    local guid = SafeString(data.guid)
    if guid and self.lastTarget and self.lastTarget.guid == guid then
      unit = "target"
    elseif guid and self.lastMouseover and self.lastMouseover.guid == guid then
      unit = "mouseover"
    end
  end
  if not unit and UnitExists("mouseover") then
    unit = "mouseover"
  end
  if not self:IsTooltipCandidate(unit) then
    return
  end

  local playerLevel = self:GetPlayerLevel()
  local xpMax = self:GetXPMax()
  local xpCurrent = self:GetXP()
  if not playerLevel or not xpMax or not xpCurrent or xpMax <= 0 then
    return
  end
  local maxLevel = self:GetMaxLevel()
  if playerLevel >= maxLevel or self:IsXPDisabled() then
    return
  end

  local name = Trim(SafeCall(UnitName, unit))
  name = Trim(name)
  local guid = SafeString(SafeCall(UnitGUID, unit))
  local npcID = guid and self:ParseNPCID(guid) or nil
  local rawMobLevel = SafeNumber(SafeCall(UnitLevel, unit))
  local mobLevel
  if rawMobLevel == nil or rawMobLevel == 0 then
    mobLevel = playerLevel
  else
    mobLevel = rawMobLevel
  end
  local classification = SafeString(SafeCall(UnitClassification, unit)) or "normal"
  local mobKey = self:GetMobKey(name, npcID)
  local mapID = self:GetMapID()
  local groupSize = self:GetGroupSize()
  local buffSignature = self:GetBuffSignature()
  local contextKey = ContextKey(playerLevel, mobLevel, groupSize, mapID, classification, buffSignature)

  local mob = self.char and self.char.mobs[mobKey] or nil
  local exact = false
  local estimate
  if (not groupSize or groupSize <= 1) and type(mob) == "table" and type(mob.contexts) == "table" then
    local context = mob.contexts[contextKey]
    if type(context) == "table" and (tonumber(context.samples) or 0) >= 1 then
      estimate = RoundForever((tonumber(context.sumBuffed) or 0) / context.samples)
      exact = true
    end
  end
  if not estimate or estimate <= 0 then
    estimate = self:GetEstimate(playerLevel, mobLevel, classification, mapID, groupSize, mobKey, buffSignature)
  end
  local soloEstimate = estimate
  if groupSize and groupSize > 1 then
    soloEstimate = self:GetEstimate(playerLevel, mobLevel, classification, mapID, 1, mobKey, buffSignature)
  end
  if not estimate or estimate <= 0 then
    if self.settings.showUnknown then
      tooltip:AddLine("|cffaaaaaaXP: no XP from this mob|r")
    end
    return
  end

  local signature = tostring(unit) .. ":" .. tostring(guid or "") .. ":" .. tostring(playerLevel)
    .. ":" .. tostring(mobLevel) .. ":" .. tostring(estimate) .. ":" .. tostring(soloEstimate)
    .. ":" .. tostring(groupSize) .. ":" .. tostring(buffSignature)
  if tooltip.xpTooltipSignature == signature then
    return
  end
  tooltip.xpTooltipSignature = signature

  local pool = self:GetRestedPool()
  local restedBonus = min(estimate, floor(pool / 2))
  local totalXP = estimate + restedBonus
  local percent = totalXP / xpMax * 100
  local remaining = xpMax - xpCurrent
  local kills = self:KillsToLevel(remaining, estimate, pool)
  local prefix = exact and "" or "~"
  local settings = self.settings

  if settings.showXP then
    local value = prefix .. FormatNumber(totalXP)
    if settings.showPercent then
      value = value .. " (" .. FormatPercent(percent) .. " of level)"
    end
    if groupSize and groupSize > 1 then
      value = value .. " |cffaaaaaa(group share; solo " .. prefix .. FormatNumber(soloEstimate) .. ")|r"
    end
    tooltip:AddDoubleLine("|cffaaaaaaXP:|r", "|cffffffff" .. value .. "|r")
  end

  if settings.showRested and pool > 0 and restedBonus > 0 then
    tooltip:AddDoubleLine(
      "|cffaaaaaaRested bonus:|r",
      "|cff55ff55+" .. FormatNumber(restedBonus) .. "|r |cffaaaaaa(pool " .. FormatNumber(pool) .. ")|r"
    )
  end

  if settings.showKillsToLevel and kills and kills > 0 then
    local suffix = ""
    if pool > 0 and settings.showRested then
      suffix = " |cffaaaaaa(while rested)|r"
    end
    tooltip:AddDoubleLine("|cffaaaaaaKills to level:|r", "|cffffffff" .. prefix .. FormatNumber(kills) .. suffix)
  end

  if settings.showKillCount then
    local killsTotal = tonumber(mob and mob.kills) or 0
    local killsAtLevel = 0
    if mob and type(mob.killsAtLevel) == "table" then
      killsAtLevel = tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0
    end
    tooltip:AddDoubleLine(
      "|cffaaaaaaKilled:|r",
      "|cffffffff" .. FormatNumber(killsTotal) .. "|r |cffaaaaaa(this level: " .. FormatNumber(killsAtLevel) .. ")|r"
    )
  end

  if groupSize and groupSize > 1 and settings.showXP then
    tooltip:AddLine("|cffaaaaaaGroup kills split XP; the XP line is your share.|r")
  end
end
