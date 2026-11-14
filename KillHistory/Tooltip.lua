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
local FormatNumber = Util.FormatNumber
local FormatPercent = Util.FormatPercent

function XPTooltip:InstallTooltipHook()
  if self.tooltipHookInstalled then
    return
  end
  if not self:Supports("hasTooltipHook") then
    self.tooltipHookInstalled = false
    return
  end
  self.tooltipHookInstalled = true

  local processor = TooltipDataProcessor
  local canAddProcessor = self.hasProcessor
    and type(processor) == "table"
    and type(processor.AddTooltipPostCall) == "function"
    and Enum
    and Enum.TooltipDataType
    and Enum.TooltipDataType.Unit ~= nil

  local installed = false
  if self.tooltipScriptHooked then
    -- HookScript callbacks cannot be removed. Reuse the existing one and keep
    -- it inert through OnTooltip's IsActive check while the module is inactive.
    installed = true
    self.hasProcessor = false
  elseif canAddProcessor then
    if self.tooltipProcessorCallback and self.tooltipProcessorHooked then
      -- A previous RemoveTooltipPostCall was unavailable; the tracked callback
      -- is still registered, so reusing it avoids a duplicate callback.
      installed = true
    else
      local dataType = Enum.TooltipDataType.Unit
      local callback = function(tooltip, data)
        self:OnTooltip(tooltip, data)
      end
      local ok = pcall(processor.AddTooltipPostCall, dataType, callback)
      if ok then
        self.tooltipProcessorCallback = callback
        self.tooltipProcessorType = dataType
        self.tooltipProcessorHooked = true
        installed = true
      end
    end
  end

  if not installed and GameTooltip and GameTooltip.HookScript then
    local ok = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tooltip)
      self:OnTooltip(tooltip, nil)
    end)
    installed = ok
    if ok then
      self.hasProcessor = false
      self.tooltipScriptHooked = true
    end
  end

  if not installed then
    self.tooltipHookInstalled = false
    self.hasProcessor = false
    self:ReportError("tooltip hook", "no usable tooltip hook", false)
  end

  if GameTooltip and GameTooltip.HookScript and not self.tooltipClearedHooked then
    local ok = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(tooltip)
      tooltip.xpTooltipSignature = nil
    end)
    if ok then
      self.tooltipClearedHooked = true
    end
  end
end

function XPTooltip:UninstallTooltipHook()
  local callback = self.tooltipProcessorCallback
  local dataType = self.tooltipProcessorType
  if callback and dataType ~= nil then
    local remove = TooltipDataProcessor and TooltipDataProcessor.RemoveTooltipPostCall
    if type(remove) == "function" then
      local ok = pcall(remove, dataType, callback)
      if not ok then
        -- Keep the tracked callback so a later InstallTooltipHook can reuse it
        -- instead of registering a duplicate.
        self.tooltipHookInstalled = false
        return
      end
    else
      -- No removal API is available; the callback stays registered but inert
      -- while IsActive is false and can be reused on the next install.
      self.tooltipHookInstalled = false
      return
    end
  end

  self.tooltipProcessorCallback = nil
  self.tooltipProcessorType = nil
  self.tooltipProcessorHooked = false
  self.tooltipHookInstalled = false
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
  return self:IsUnitEligible(unit)
end

function XPTooltip:AddTooltipKillCount(tooltip, mob, playerLevel, settings)
  if not settings or not settings.showKillCount then
    return false
  end
  local killsTotal = tonumber(mob and mob.kills) or 0
  local killsAtLevel = 0
  if mob and playerLevel and type(mob.killsAtLevel) == "table" then
    killsAtLevel = tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0
  end
  tooltip:AddDoubleLine(
    "|cffaaaaaaKilled:|r",
    "|cffffffff" .. FormatNumber(killsTotal) .. "|r |cffaaaaaa(this level: " .. FormatNumber(killsAtLevel) .. ")|r"
  )
  return true
end

function XPTooltip:AddTooltipMobLevel(tooltip, level, settings)
  if not settings or not settings.showMobLevel then
    return false
  end
  local text
  if level == -1 then
    text = "??"
  elseif level and level > 0 then
    text = tostring(level)
  else
    return false
  end
  tooltip:AddDoubleLine("|cffaaaaaaLevel:|r", "|cffffffff" .. text .. "|r")
  return true
end

function XPTooltip.AddTooltipLines(self, tooltip, data)
  local unit
  if tooltip and type(tooltip.GetUnit) == "function" then
    local ok, _, token = pcall(tooltip.GetUnit, tooltip)
    if ok then
      unit = token
    end
  end
  if not unit and data then
    unit = SafeString(data.unitToken) or SafeString(data.unit)
    if not unit then
      local guid = SafeString(data.guid)
      if guid and self.lastTarget and self.lastTarget.guid == guid then
        unit = "target"
      elseif guid and self.lastMouseover and self.lastMouseover.guid == guid then
        unit = "mouseover"
      end
    end
  end
  -- Do not fall back to mouseover when the tooltip unit is unknown. Showing
  -- mouseover counts on a target tooltip is worse than showing no line.
  if not self:IsTooltipCandidate(unit) then
    return
  end

  local settings = self.settings or self:GetSettings()
  if not settings then
    return
  end

  local name = Trim(SafeCall(UnitName, unit))
  local guid = SafeString(SafeCall(UnitGUID, unit))
  local npcID = guid and self:ParseNPCID(guid) or nil
  local mobKey = self:GetMobKey(name, npcID)
  local mob = self.char and self.char.mobs and self.char.mobs[mobKey] or nil
  local playerLevel = self:GetPlayerLevel()

  local killsTotal = tonumber(mob and mob.kills) or 0
  local killsAtLevel = 0
  if mob and playerLevel and type(mob.killsAtLevel) == "table" then
    killsAtLevel = tonumber(mob.killsAtLevel[tostring(playerLevel)]) or 0
  end

  local rawMobLevel = SafeNumber(SafeCall(UnitLevel, unit))
  local supportsXP = self:Supports("hasTooltipXP")
  local xpMax = supportsXP and self:GetXPMax() or nil
  local xpCurrent = supportsXP and self:GetXP() or nil
  local maxLevel = supportsXP and self:GetMaxLevel() or nil
  local xpDisabled = supportsXP and self:IsXPDisabled() or false
  local xpAvailable = supportsXP and playerLevel and xpMax and xpCurrent
    and xpMax > 0 and maxLevel and playerLevel < maxLevel and not xpDisabled

  -- Counts-only clients and missing XP state still get the kill-count line.
  if not xpAvailable then
    local signature = table.concat({
      tostring(unit), tostring(guid or ""), tostring(playerLevel),
      tostring(rawMobLevel), tostring(settings.showMobLevel),
      "counts", tostring(killsTotal), tostring(killsAtLevel),
    }, ":")
    if tooltip.xpTooltipSignature == signature then
      return
    end
    tooltip.xpTooltipSignature = signature
    self:AddTooltipMobLevel(tooltip, rawMobLevel, settings)
    self:AddTooltipKillCount(tooltip, mob, playerLevel, settings)
    return
  end

  local mobLevel
  if rawMobLevel == nil or rawMobLevel == 0 then
    mobLevel = playerLevel
  else
    mobLevel = rawMobLevel
  end
  local classification = SafeString(SafeCall(UnitClassification, unit)) or "normal"
  local mapID = self:GetMapID()
  local groupSize = self:GetGroupSize()
  local buffSignature = self:GetBuffSignature()
  local state = type(self.GetInstanceState) == "function" and self:GetInstanceState() or nil
  local contextKey = ContextKey(
    playerLevel, mobLevel, groupSize, mapID, classification, buffSignature,
    state and state.key
  )

  local profile = self.clientProfile or self:GetClientProfile()
  local function round(value)
    if profile and profile.Round then
      return profile:Round(value)
    end
    return Formula.Round(value)
  end

  local exact = false
  local estimate
  if (not groupSize or groupSize <= 1) and type(mob) == "table" and type(mob.contexts) == "table" then
    local context = mob.contexts[contextKey]
    if type(context) == "table" and (tonumber(context.samples) or 0) >= 1 then
      estimate = round((tonumber(context.sumBuffed) or 0) / context.samples)
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

  local signature = tostring(unit) .. ":" .. tostring(guid or "") .. ":" .. tostring(playerLevel)
    .. ":" .. tostring(mobLevel) .. ":" .. tostring(rawMobLevel) .. ":" .. tostring(settings.showMobLevel)
    .. ":" .. tostring(settings.showXPBonuses)
    .. ":" .. tostring(estimate) .. ":" .. tostring(soloEstimate)
    .. ":" .. tostring(groupSize) .. ":" .. tostring(buffSignature)
    .. ":" .. tostring(killsTotal) .. ":" .. tostring(killsAtLevel)
  if tooltip.xpTooltipSignature == signature then
    return
  end
  tooltip.xpTooltipSignature = signature

  self:AddTooltipMobLevel(tooltip, rawMobLevel, settings)

  if not estimate or estimate <= 0 then
    if settings.showUnknown then
      tooltip:AddLine("|cffaaaaaaXP: no XP from this mob|r")
    end
    self:AddTooltipKillCount(tooltip, mob, playerLevel, settings)
    return
  end

  local pool = self:GetRestedPool()
  local restedBonus = min(estimate, floor(pool / 2))
  local totalXP = estimate + restedBonus
  local percent = totalXP / xpMax * 100
  local remaining = xpMax - xpCurrent
  local kills = self:KillsToLevel(remaining, estimate, pool)
  local prefix = exact and "" or "~"

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

  if settings.showXPBonuses then
    local bonuses, _, totalPercent = self:GetActiveXPBonuses()
    local bonusText = self:FormatXPBonuses(bonuses, totalPercent)
    if bonusText then
      tooltip:AddDoubleLine("|cffaaaaaaXP bonuses:|r", "|cff55ff55" .. bonusText .. "|r")
    end
  end

  if settings.showXPRemaining then
    local _, _, remainingXP, remainingPercent = self:GetXPProgress()
    if remainingXP then
      tooltip:AddDoubleLine(
        "|cffaaaaaaXP remaining:|r",
        "|cffffffff" .. FormatNumber(remainingXP) .. "|r |cffaaaaaa("
          .. FormatPercent(remainingPercent) .. ")|r"
      )
    end
  end

  if settings.showRested and pool > 0 and restedBonus > 0 then
    tooltip:AddDoubleLine(
      "|cffaaaaaaRested bonus:|r",
      "|cff55ff55+" .. FormatNumber(restedBonus) .. "|r |cffaaaaaa(pool " .. FormatNumber(pool) .. ")|r"
    )
  end

  if settings.showKillsToLevel and self:Supports("hasKillsToLevel") and kills and kills > 0 then
    local suffix = ""
    if pool > 0 and settings.showRested then
      suffix = " |cffaaaaaa(while rested)|r"
    end
    tooltip:AddDoubleLine("|cffaaaaaaKills to level:|r", "|cffffffff" .. prefix .. FormatNumber(kills) .. suffix)
  end

  self:AddTooltipKillCount(tooltip, mob, playerLevel, settings)

  if groupSize and groupSize > 1 and settings.showXP then
    tooltip:AddLine("|cffaaaaaaGroup kills split XP; the XP line is your share.|r")
  end
end
