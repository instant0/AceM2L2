--[[---------------------------------------------------------------------------------
  Core/XP.lua
  XP parsing, rolling samples, chat printing, and player XP updates.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Util = AceM2L2.Util

local SafeNumber = Util.SafeNumber
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

local KILL_XP_KEYS = {
  COMBATLOG_XPGAIN_FIRSTPERSON = true,
  COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = true,
  COMBATLOG_XPGAIN_FIRSTPERSON_RAID = true,
  COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = true,
  COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_GROUP = true,
  COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_RAID = true,
}

local function IsSupportedXPSource(key)
  if key == "COMBATLOG_XPGAIN_QUEST" or KILL_XP_KEYS[key] then
    return true
  end
  return key:match("^COMBATLOG_XPGAIN_EXHAUSTION%d+$") ~= nil
    or key:match("^COMBATLOG_XPGAIN_EXHAUSTION%d+_GROUP$") ~= nil
    or key:match("^COMBATLOG_XPGAIN_EXHAUSTION%d+_RAID$") ~= nil
end

function AceM2L2:GetXPFmts()
  if self.xpFmts then
    return self.xpFmts
  end

  local formats = {}
  for key, value in pairs(_G) do
    if type(key) == "string" and type(value) == "string" and IsSupportedXPSource(key) then
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

local function SelectXPAmount(numbers, key)
  if #numbers == 0 then
    return nil
  end
  if #numbers == 1 then
    return numbers[1]
  end
  -- Group/raid text can contain a personal share plus a party bonus. Use the
  -- first captured amount rather than inflating it by summing every number.
  if key:find("_GROUP", 1, true) or key:find("_RAID", 1, true) then
    return numbers[1]
  end
  -- Rested/exhaustion text may expose base and rested amounts separately.
  if key:find("_EXHAUSTION", 1, true) then
    local total = 0
    for _, value in ipairs(numbers) do
      total = total + value
    end
    return total
  end
  return numbers[1]
end

function AceM2L2:ParseXPMessage(message)
  if not message or IsSecretValue(message) then
    return nil
  end

  local text = StripColorCodes(message) or message
  local matches = {}
  for _, info in ipairs(self:GetXPFmts()) do
    local _, ordered = ParseFormatted(text, info.fmt)
    if ordered then
      local name = nil
      local numbers = {}

      for _, item in ipairs(ordered) do
        if item.kind == "s" and info.hasName and not name then
          name = Trim(item.value)
        elseif item.kind == "d" or item.kind == "f" then
          local number = NormalizeNumber(item.value, item.kind)
          if number then
            numbers[#numbers + 1] = number
          end
        end
      end

      local total = SelectXPAmount(numbers, info.key)
      if total and total > 0 then
        matches[#matches + 1] = {
          name = name,
          total = total,
          key = info.key,
        }
      end
    end
  end

  if #matches == 0 then
    return nil
  end

  local first = matches[1]
  local ambiguousQuest = false
  if not first.key:find("_QUEST", 1, true) then
    for index = 2, #matches do
      if matches[index].key:find("_QUEST", 1, true) then
        ambiguousQuest = true
        break
      end
    end
  end
  return first.name, first.total, first.key, ambiguousQuest
end

function AceM2L2:C(_, message)
  self:SafeInvoke("CHAT_MSG_COMBAT_XP_GAIN", "HandleXPText", message)
end

function AceM2L2:IsQuestXPWindowActive()
  local untilTime = tonumber(self.questXPWindowUntil) or 0
  return untilTime > 0 and GetSafeTime() <= untilTime
end

function AceM2L2:ClearQuestXPWindow()
  self.questXPWindowUntil = 0
  self.questXPAmount = nil
end

function AceM2L2:OnQuestTurnedIn(event, questID, xpReward)
  local now = GetSafeTime()
  local reward = SafeNumber(xpReward)
  local questName
  if questID and C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
    questName = Trim(SafeCall(C_QuestLog.GetTitleForQuestID, questID))
  end
  self.pendingQuestID = tonumber(questID)
  self.pendingQuestName = questName
  self.pendingQuestAt = now
  self.questXPWindowUntil = now + 5
  self.questXPAmount = reward and reward > 0 and reward or nil
  self.lastCreatureName = nil
  self.lastXPSource = "quest"
  self.lastXPInfoTime = now
  self.lastChatXPAmount = nil
  if self.db and self.db.debug then
    self:SafePrint("XP source: quest turn-in [" .. tostring(questID)
      .. ", reward=" .. tostring(xpReward) .. "]")
  end
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

  local name, total, key, ambiguousQuest = self:ParseXPMessage(message)
  if not key then
    self.lastCreatureName = nil
    self.lastXPSource = nil
    self.lastXPInfoTime = GetSafeTime()
    self.lastChatXPAmount = nil
    return
  end

  local isQuest = key:find("_QUEST", 1, true) ~= nil
  if not isQuest and ambiguousQuest then
    if self:IsQuestXPWindowActive() then
      isQuest = true
    else
      -- Quest and unnamed-kill formats can be identical. Without a quest
      -- turn-in signal, suppress instead of claiming this was a mob kill.
      self.lastCreatureName = nil
      self.lastXPSource = nil
      self.lastXPInfoTime = GetSafeTime()
      self.lastChatXPAmount = nil
      if self.db.debug then
        self:SafePrint("XP source: ambiguous quest/unnamed gain suppressed ["
          .. tostring(key) .. "]")
      end
      return
    end
  end

  self.lastCreatureName = name
  self.lastXPSource = isQuest and "quest" or "kill"
  self.lastXPInfoTime = GetSafeTime()
  self.lastChatXPAmount = total
  if isQuest then
    self:ClearQuestXPWindow()
  end

  if self.db.debug then
    self:SafePrint("XP source: " .. tostring(name or (isQuest and "quest" or "mob"))
      .. (ambiguousQuest and " (ambiguous)" or "") .. " [" .. tostring(key) .. "]")
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

function AceM2L2:RecordQuestGain(xp)
  local now = GetSafeTime()
  local questID = self.pendingQuestID
  local questName = self.pendingQuestName
  local pendingAt = tonumber(self.pendingQuestAt) or 0
  if pendingAt == 0 or (now - pendingAt) > 5 then
    -- Drop stale turn-in metadata instead of attributing a later gain to it.
    questID, questName = nil, nil
  end
  self.pendingQuestID = nil
  self.pendingQuestName = nil
  self.pendingQuestAt = 0
  local kh = self.KillHistory
  if kh and type(kh.RecordQuestXP) == "function" and kh:IsActive() then
    kh:RecordQuestXP(questID, questName, xp)
    if type(kh.AddLevelHistoryXP) == "function" then
      kh:AddLevelHistoryXP(xp)
    end
    if type(kh.RecordRateSample) == "function" then
      kh:RecordRateSample(xp, "quest")
    end
    if type(kh.RecordDungeonXP) == "function" then
      kh:RecordDungeonXP(xp)
    end
  end
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
  local questWindow = self:IsQuestXPWindowActive()
  local hasInfo = self.lastXPInfoTime and self.lastXPInfoTime > 0
    and (now - self.lastXPInfoTime) < 2
  if not hasInfo or not self.lastXPSource then
    if questWindow then
      local questXP = delta
      self:ClearQuestXPWindow()
      self.lastCreatureName = nil
      self.lastXPSource = nil
      self.lastXPInfoTime = 0
      self.lastChatXPAmount = nil
      self:RecordQuestGain(questXP)
      self:HandleXPGain(nil, questXP, true)
      return
    end
    -- An XP delta without a recognized kill/quest chat source (for example
    -- exploration or bonus XP) must not enter the rolling kill average.
    self.lastCreatureName = nil
    self.lastXPSource = nil
    self.lastXPInfoTime = 0
    self.lastChatXPAmount = nil
    return
  end

  local isQuest = self.lastXPSource == "quest"
  local chatXPAmount = self.lastChatXPAmount
  local questAmount = self.questXPAmount
  if not isQuest and questWindow and questAmount
    and math.abs(delta - questAmount) <= 1
    and not (chatXPAmount and math.abs(delta - chatXPAmount) <= 1) then
    -- A quest reward can follow a kill chat in the same window. Prefer the
    -- quest source when the delta matches the turn-in reward and not the
    -- last chat amount.
    isQuest = true
  end
  local name = self.lastCreatureName
  if isQuest then
    -- A quest gain must not reuse a stale kill creature name.
    name = nil
  end

  self.lastCreatureName = nil
  self.lastXPSource = nil
  self.lastXPInfoTime = 0
  self.lastChatXPAmount = nil
  if isQuest then
    self:ClearQuestXPWindow()
    self:RecordQuestGain(delta)
  end

  self:HandleXPGain(name, delta, isQuest)
end
