--[[---------------------------------------------------------------------------------
  Core/XP.lua
  XP parsing, rolling samples, chat printing, and player XP updates.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Util = AceM2L2.Util

local SafeNumber = Util.SafeNumber
local SafeString = Util.SafeString
local SafeCall = Util.SafeCall
local IsSecretValue = Util.IsSecretValue
local Trim = Util.Trim
local StripColorCodes = Util.StripColorCodes
local NormalizeNumber = Util.NormalizeNumber
local ParseFormatted = Util.ParseFormatted
local GetSafeTime = Util.GetSafeTime
local GetUnitXP = Util.GetUnitXP
local GetUnitXPMax = Util.GetUnitXPMax
local GetUnitLevel = Util.GetUnitLevel
local AddChatMessage = Util.AddChatMessage
local SanitizeLabel = Util.SanitizeLabel

function AceM2L2:RoundFormatted(number)
  local value = SafeNumber(number)
  if not value then
    return "?"
  end
  local precision = self:GetNumberSetting("precision", 2, 0, 4, true)
  return string.format("%0." .. precision .. "f", value)
end

function AceM2L2:AddSampleXP(xp)
  local value = SafeNumber(xp)
  if not value or value <= 0 then
    return
  end

  self.xpSamples = self.xpSamples or {}
  table.insert(self.xpSamples, value)
  local maxSamples = math.max(1, self:GetNumberSetting("rollingXPWindow", 5, 1, 100, true))
  while #self.xpSamples > maxSamples do
    table.remove(self.xpSamples, 1)
  end
end

function AceM2L2:GetAverageXP()
  local samples = self.xpSamples or {}
  if #samples == 0 then
    return nil
  end

  local total = 0
  for _, value in ipairs(samples) do
    total = total + value
  end

  return total / #samples
end

function AceM2L2:ShouldPrintXPMsg(estimatedKills)
  if not self.db.xpEnabled then
    return false
  end

  self.xpKillCounter = (self.xpKillCounter or 0) + 1
  local everyN = self:GetNumberSetting("xpEveryNKills", 1, 1, 1000, true)
  if self.xpKillCounter % everyN ~= 0 then
    return false
  end

  local minRemaining = self:GetNumberSetting("xpMinKillsRemaining", 0, 0, nil, true)
  return estimatedKills >= minRemaining
end

function AceM2L2:GetXPFmts()
  if self.xpFmts then
    return self.xpFmts
  end

  local formats = {}
  for key, value in pairs(_G) do
    if type(key) == "string" and type(value) == "string" and key:match("^COMBATLOG_XPGAIN_") then
      local hasName = true
      if key:find("_UNNAMED", 1, true) or key:find("_QUEST", 1, true) then
        hasName = false
      end
      formats[#formats + 1] = {
        key = key,
        fmt = value,
        hasName = hasName,
      }
    end
  end

  table.sort(formats, function(a, b)
    return #a.key > #b.key
  end)

  self.xpFmts = formats
  return formats
end

function AceM2L2:ParseXPMessage(message)
  if not message or IsSecretValue(message) then
    return nil
  end

  local text = StripColorCodes(message) or message
  for _, info in ipairs(self:GetXPFmts()) do
    local _, ordered = ParseFormatted(text, info.fmt)
    if ordered then
      local name = nil
      local total = 0
      local foundNumber = false

      for _, item in ipairs(ordered) do
        if item.kind == "s" and info.hasName and not name then
          name = Trim(item.value)
        elseif item.kind == "d" or item.kind == "f" then
          local number = NormalizeNumber(item.value, item.kind)
          if number then
            total = total + number
            foundNumber = true
          end
        end
      end

      if foundNumber and total > 0 then
        return name, total, info.key
      end
    end
  end

  return nil
end

function AceM2L2:C(_, message)
  self:SafeInvoke("CHAT_MSG_COMBAT_XP_GAIN", "HandleXPText", message)
end

function AceM2L2:HandleXPText(message)
  if not self.db.xpEnabled then
    return
  end

  -- The amount comes from PLAYER_XP_UPDATE.  The chat event supplies the
  -- creature name and whether the gain was a quest, which the XP event does
  -- not carry.
  if IsSecretValue(message) then
    self.lastCreatureName = nil
    self.lastXPSource = nil
    self.lastXPInfoTime = GetSafeTime()
    return
  end

  local name, _, key = self:ParseXPMessage(message)
  if not key then
    self.lastCreatureName = nil
    self.lastXPSource = nil
    self.lastXPInfoTime = GetSafeTime()
    return
  end

  local isQuest = key:find("_QUEST", 1, true) ~= nil
  self.lastCreatureName = name
  self.lastXPSource = isQuest and "quest" or "kill"
  self.lastXPInfoTime = GetSafeTime()

  if self.db.debug then
    self:SafePrint("XP source: " .. tostring(name or (isQuest and "quest" or "mob")) .. " [" .. tostring(key) .. "]")
  end
end

function AceM2L2:HandleXPGain(creatureName, xp, isQuest)
  local value = SafeNumber(xp)
  if not value or value <= 0 then
    return
  end

  if not isQuest then
    self:AddSampleXP(value)
  end

  local levelAtGain = GetUnitLevel()
  local function printEstimate()
    if not self:IsEnabled() then
      return
    end
    if levelAtGain and GetUnitLevel() ~= levelAtGain then
      return
    end
    self:SafeInvoke("PrintXPEstimate", "PrintXPEstimate", creatureName, value, isQuest)
  end

  if C_Timer and C_Timer.After then
    local ok = pcall(C_Timer.After, 0, printEstimate)
    if not ok then
      printEstimate()
    end
  else
    printEstimate()
  end
end

function AceM2L2:PrintXPEstimate(creatureName, xp, isQuest)
  local xpMax = GetUnitXPMax()
  local xpCurrent = GetUnitXP()
  if not xpMax or not xpCurrent or xpMax <= 0 or xpCurrent >= xpMax then
    return
  end

  local xpPerKill = SafeNumber(xp)
  if self.db.useRollingXP and not isQuest then
    xpPerKill = self:GetAverageXP() or xpPerKill
  end
  xpPerKill = SafeNumber(xpPerKill)
  if not xpPerKill or xpPerKill <= 0 then
    return
  end

  local remaining = xpMax - xpCurrent
  if remaining <= 0 then
    return
  end

  local mobsToLevel = math.max(1, math.ceil(remaining / xpPerKill))
  if not self:ShouldPrintXPMsg(mobsToLevel) then
    return
  end

  local label = SanitizeLabel(creatureName) or (isQuest and "Quest" or "Mob")
  local suffix = isQuest and "quests to level" or "kills to level"
  AddChatMessage(
    "|cFFFFFFFF[|r|cff00FF00" .. mobsToLevel .. "|r|cFFFFFFFF] [|r" ..
    "|cff00FF00" .. label .. "|r|cFFFFFFFF] " .. suffix .. "|r"
  )
end

function AceM2L2:OnPlayerXPUpdate()
  self:SafeInvoke("PLAYER_XP_UPDATE", "HandlePlayerXPUpdate")
end

function AceM2L2:HandlePlayerXPUpdate()
  local current = GetUnitXP()
  if not current then
    return
  end

  if self.lastXP == nil then
    self.lastXP = current
    return
  end

  local delta = current - self.lastXP
  self.lastXP = current
  if delta <= 0 then
    return
  end

  local now = GetSafeTime()
  local isQuest = false
  local name = nil
  if self.lastXPInfoTime and self.lastXPInfoTime > 0 and (now - self.lastXPInfoTime) < 2 then
    isQuest = self.lastXPSource == "quest"
    name = self.lastCreatureName
  end

  self.lastCreatureName = nil
  self.lastXPSource = nil
  self.lastXPInfoTime = 0

  self:HandleXPGain(name, delta, isQuest)
end
