--[[--------------------------------------------------------------------------------
  Core/Reputation.lua
  Reputation parsing, faction cache, standing capture, and reputation chat output.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Util = AceM2L2.Util

local IsSecretValue = Util.IsSecretValue
local SafeBoolean = Util.SafeBoolean
local SafeNumber = Util.SafeNumber
local SafeLower = Util.SafeLower
local Trim = Util.Trim
local StripColorCodes = Util.StripColorCodes
local NormalizeNumber = Util.NormalizeNumber
local NormalizeFaction = Util.NormalizeFaction
local ParseFormatted = Util.ParseFormatted
local GetSafeTime = Util.GetSafeTime
local GetPlayerGuildName = Util.GetPlayerGuildName
local AddChatMessage = Util.AddChatMessage
local SanitizeLabel = Util.SanitizeLabel

--[[--------------------------------------------------------------------------------
  Restricted API access
  C_Reputation/C_MajorFactions members can be protected or secret on restricted
  clients, so resolve them through pcall instead of direct table indexing.
------------------------------------------------------------------------------------]]

local function SafeGlobal(name)
  local ok, value = pcall(function()
    return _G[name]
  end)
  if not ok then
    return nil
  end
  return value
end

local function SafeGlobalFunction(name)
  local value = SafeGlobal(name)
  if type(value) ~= "function" then
    return nil
  end
  return value
end

local function SafeTableFunction(tableName, field)
  local tbl = SafeGlobal(tableName)
  if type(tbl) ~= "table" then
    return nil
  end
  local ok, fn = pcall(function()
    return tbl[field]
  end)
  if not ok or type(fn) ~= "function" then
    return nil
  end
  return fn
end

function AceM2L2:ShouldPrintRepMsg(remaining)
  if not self.db.repEnabled then
    return false
  end

  self.repGainCounter = (self.repGainCounter or 0) + 1
  local everyN = self:GetNumberSetting("repEveryNGains", 1, 1, 1000, true)
  if self.repGainCounter % everyN ~= 0 then
    return false
  end

  local minRemaining = self:GetNumberSetting("repMinRemaining", 0, 0, nil, true)
  return remaining >= minRemaining
end

function AceM2L2:GetRepFmts()
  if self.repFmts then
    return self.repFmts
  end

  local formats = {}
  for key, value in pairs(_G) do
    if type(key) == "string" and type(value) == "string" and key:match("^FACTION_STANDING_INCREASED") then
      formats[#formats + 1] = {
        key = key,
        fmt = value,
      }
    end
  end

  table.sort(formats, function(a, b)
    return #a.key > #b.key
  end)

  self.repFmts = formats
  return formats
end

function AceM2L2:ParseRepMessage(message)
  if not message or IsSecretValue(message) then
    return nil
  end

  local text = StripColorCodes(message) or message
  for _, info in ipairs(self:GetRepFmts()) do
    local _, ordered = ParseFormatted(text, info.fmt)
    if ordered then
      local factionName = nil
      local gain = nil

      for _, item in ipairs(ordered) do
        if item.kind == "s" and not factionName then
          factionName = Trim(item.value)
        elseif item.kind == "d" or item.kind == "f" then
          local number = NormalizeNumber(item.value, item.kind)
          if number and not gain then
            -- Reputation chat formats normally contain one amount. If a
            -- localized format includes extra numbers, the first is the gain.
            gain = number
          end
        end
      end

      if factionName and gain and gain > 0 then
        return factionName, gain, info.key
      end
    end
  end

  return nil
end

function AceM2L2:GetNumFactions()
  local getNumFactions = SafeTableFunction("C_Reputation", "GetNumFactions")
  if getNumFactions then
    local ok, num = pcall(getNumFactions)
    num = SafeNumber(num)
    if ok and num then
      return num
    end
  end

  local legacyGetNumFactions = SafeGlobalFunction("GetNumFactions")
  if legacyGetNumFactions then
    local ok, num = pcall(legacyGetNumFactions)
    num = SafeNumber(num)
    if ok and num then
      return num
    end
  end

  return 0
end

function AceM2L2:GetFactionDataByIndex(index)
  local getFactionData = SafeTableFunction("C_Reputation", "GetFactionDataByIndex")
  if getFactionData then
    local ok, data = pcall(getFactionData, index)
    if ok and data then
      local faction = NormalizeFaction(data)
      if faction then
        faction.index = index
      end
      return faction
    end
  end

  local getFactionInfo = SafeGlobalFunction("GetFactionInfo")
  if getFactionInfo then
    local ok, name, _, standingID, minVal, maxVal, curVal, _, _, isHeader, _, hasRep, _, isChild, factionID = pcall(getFactionInfo, index)
    if ok and name then
      local faction = NormalizeFaction({
        name = name,
        currentReactionThreshold = minVal,
        nextReactionThreshold = maxVal,
        currentStanding = curVal,
        standingID = standingID,
        factionID = factionID,
        isHeader = isHeader,
        isHeaderWithRep = hasRep,
        isChild = isChild,
      })
      if faction then
        faction.index = index
      end
      return faction
    end
  end

  return nil
end

function AceM2L2:GetFactionDataByID(factionID)
  local id = SafeNumber(factionID)
  if not id then
    return nil
  end

  local getFactionData = SafeTableFunction("C_Reputation", "GetFactionDataByID")
  if getFactionData then
    local ok, data = pcall(getFactionData, id)
    if ok and data then
      return NormalizeFaction(data)
    end
  end

  -- Fallback for clients/builds without GetFactionDataByID.
  local numFactions = self:GetNumFactions()
  for index = 1, numFactions do
    local faction = self:GetFactionDataByIndex(index)
    if faction and SafeNumber(faction.factionID) == id then
      return faction
    end
  end

  return nil
end

function AceM2L2:RefreshFactionData(faction)
  if not faction then
    return nil
  end

  local refreshed = self:GetFactionDataByID(faction.factionID)
  if not refreshed and faction.index then
    refreshed = self:GetFactionDataByIndex(faction.index)
  end
  return refreshed or faction
end

function AceM2L2:GetGuildFactionData()
  local getGuildFactionData = SafeTableFunction("C_Reputation", "GetGuildFactionData")
  if getGuildFactionData then
    local ok, data = pcall(getGuildFactionData)
    if ok and data then
      return NormalizeFaction(data)
    end
  end
  return nil
end

function AceM2L2:RebuildFactionCache()
  local cache = {}
  local numFactions = self:GetNumFactions()

  for index = 1, numFactions do
    local faction = self:GetFactionDataByIndex(index)
    local isHeader = faction and SafeBoolean(faction.isHeader) == true
    local isHeaderWithRep = faction and SafeBoolean(faction.isHeaderWithRep) == true
    if faction and faction.name and (not isHeader or isHeaderWithRep) then
      local key = SafeLower(faction.name)
      if key and not cache[key] then
        cache[key] = faction
      end
    end
  end

  self.factionCache = cache
  self.factionCacheTime = GetSafeTime()
end

function AceM2L2:GetFactionRecordByName(factionName)
  local key = SafeLower(factionName)
  if not key then
    return nil
  end

  local now = GetSafeTime()
  if not self.factionCache or (now - (self.factionCacheTime or 0)) > 2 then
    self:RebuildFactionCache()
    self.factionCacheTime = now
  end

  if self.factionCache then
    return self.factionCache[key]
  end
  return nil
end

function AceM2L2:GetReputationProgress(faction)
  if not faction then
    return nil
  end

  local factionID = SafeNumber(faction.factionID)
  local minVal = SafeNumber(faction.currentReactionThreshold) or 0
  local maxVal = SafeNumber(faction.nextReactionThreshold) or 0
  local curVal = SafeNumber(faction.currentStanding) or 0

  if factionID then
    local isFactionParagon = SafeTableFunction("C_Reputation", "IsFactionParagon")
    local getFactionParagonInfo = SafeTableFunction("C_Reputation", "GetFactionParagonInfo")
    if isFactionParagon and getFactionParagonInfo then
      local ok, isParagon = pcall(isFactionParagon, factionID)
      if ok and SafeBoolean(isParagon) then
        local ok2, value, threshold = pcall(getFactionParagonInfo, factionID)
        value = SafeNumber(value)
        threshold = SafeNumber(threshold)
        if ok2 and value and threshold and threshold > 0 then
          return 0, threshold, value % threshold
        end
      end
    end
  end

  local getMajorFactionData = factionID
    and SafeTableFunction("C_MajorFactions", "GetMajorFactionData")
  if getMajorFactionData then
    local isMajor = true
    local isMajorFaction = SafeTableFunction("C_Reputation", "IsMajorFaction")
    if isMajorFaction then
      local ok, major = pcall(isMajorFaction, factionID)
      if ok and SafeBoolean(major) == false then
        isMajor = false
      end
    end

    if isMajor then
      local ok, earned, threshold = pcall(function()
        local major = getMajorFactionData(factionID)
        if type(major) ~= "table" then
          return nil
        end
        return SafeNumber(major.renownReputationEarned), SafeNumber(major.renownLevelThreshold)
      end)
      earned = SafeNumber(earned)
      threshold = SafeNumber(threshold)
      if ok and earned and threshold and threshold > 0 then
        return 0, threshold, earned
      end
    end
  end

  if maxVal <= minVal then
    return nil
  end

  return minVal, maxVal, curVal
end

function AceM2L2:HandleRepGain(factionName, faction, gain)
  if not faction then
    return
  end
  if SafeBoolean(faction.isHeader) == true and SafeBoolean(faction.isHeaderWithRep) ~= true then
    return
  end

  local value = SafeNumber(gain)
  if not value or value <= 0 then
    return
  end

  faction = self:RefreshFactionData(faction) or faction

  local _, maxVal, curVal = self:GetReputationProgress(faction)
  maxVal = SafeNumber(maxVal)
  curVal = SafeNumber(curVal)
  if not maxVal or not curVal then
    return
  end

  local remaining = maxVal - curVal
  if remaining < 0 then
    remaining = 0
  end

  if not self:ShouldPrintRepMsg(remaining) then
    return
  end

  local repeats = remaining / value
  local label = SanitizeLabel(factionName) or SanitizeLabel(faction.name) or "faction"
  AddChatMessage(
    "|cFFFFFFFF[|r|cff00FF00" .. self:RoundFormatted(remaining) .. "|r|cFFFFFFFF] to go with [|r" ..
    "|cff00FF00" .. label .. "|r|cFFFFFFFF] = [|r" ..
    "|cff00FF00" .. self:RoundFormatted(repeats) .. "|r|cFFFFFFFF] repeats (kills/quests)|r"
  )
end

function AceM2L2:RF(_, message)
  self:SafeInvoke("CHAT_MSG_COMBAT_FACTION_CHANGE", "HandleFactionText", message)
end

function AceM2L2:HandleFactionText(message)
  -- FACTION_STANDING_CHANGED is the primary, locale-independent source.
  -- Keep the chat parser only as a fallback for clients where that event is
  -- unavailable.
  if self.useStandingEvent or not self.db.repEnabled then
    return
  end

  local factionName, gain, key = self:ParseRepMessage(message)
  if not factionName or not gain or gain <= 0 then
    return
  end

  factionName = Trim(factionName) or factionName

  if self.db.debug then
    self:SafePrint("Rep parsed: " .. (SanitizeLabel(factionName) or "faction") .. " +" .. tostring(gain) .. " [" .. tostring(key) .. "]")
  end

  local faction = self:GetFactionRecordByName(factionName)

  if not faction then
    local guildName = GetPlayerGuildName()
    if guildName and SafeLower(guildName) == SafeLower(factionName) then
      faction = self:GetGuildFactionData()
    end
  end

  if not faction and (factionName == (GUILD_REPUTATION or "") or factionName == (GUILD or "")) then
    faction = self:GetGuildFactionData()
  end

  if not faction then
    return
  end

  self:HandleRepGain(factionName, faction, gain)
end

function AceM2L2:CaptureFactionStandings()
  local standings = {}
  local numFactions = self:GetNumFactions()

  for index = 1, numFactions do
    local faction = self:GetFactionDataByIndex(index)
    local factionID = faction and SafeNumber(faction.factionID)
    local isHeader = faction and SafeBoolean(faction.isHeader) == true
    local isHeaderWithRep = faction and SafeBoolean(faction.isHeaderWithRep) == true
    if faction and factionID and (not isHeader or isHeaderWithRep) then
      local standing = SafeNumber(faction.currentStanding)
      if standing then
        standings[factionID] = standing
      end
    end
  end

  local guild = self:GetGuildFactionData()
  local guildID = guild and SafeNumber(guild.factionID)
  if guild and guildID and standings[guildID] == nil then
    local standing = SafeNumber(guild.currentStanding)
    if standing then
      standings[guildID] = standing
    end
  end

  return standings
end

function AceM2L2:OnFactionStandingChanged(_, factionID, updatedStanding)
  self:SafeInvoke("FACTION_STANDING_CHANGED", "HandleFactionStandingChanged", factionID, updatedStanding)
end

function AceM2L2:HandleFactionStandingChanged(factionID, updatedStanding)
  local id = NormalizeNumber(factionID)
  local newValue = NormalizeNumber(updatedStanding)
  if not id or not newValue then
    return
  end

  self.factionStandings = self.factionStandings or {}
  local oldValue = self.factionStandings[id]
  self.factionStandings[id] = newValue

  -- Keep the baseline fresh even while output is disabled, otherwise the
  -- first gain after re-enabling would appear much larger than it is.
  if not self.db.repEnabled then
    return
  end

  -- No baseline means the faction was not present when we logged in/zoned in.
  -- Seed it and wait for the next gain.
  if oldValue == nil then
    return
  end

  local gain = newValue - oldValue
  if gain <= 0 then
    -- Reputation loss, or a paragon/renown threshold reset.  The next gain
    -- will be reported normally.
    return
  end

  local faction = self:GetFactionDataByID(id)
  if not faction then
    local guild = self:GetGuildFactionData()
    if guild and SafeNumber(guild.factionID) == id then
      faction = guild
    end
  end
  if not faction then
    return
  end

  if self.db.debug then
    self:SafePrint("Rep standing changed: " .. (SanitizeLabel(faction.name) or "faction") .. " +" .. tostring(gain))
  end

  self:HandleRepGain(faction.name, faction, gain)
end

function AceM2L2:RefreshFactionBaseline()
  local captured = self:CaptureFactionStandings()
  if next(captured) ~= nil then
    self.factionStandings = captured
  elseif not self.factionStandings then
    self.factionStandings = {}
  end
  self:ScheduleFactionBaselineRetry()
end

function AceM2L2:EnsureFactionBaseline()
  local captured = self:CaptureFactionStandings()
  self.factionStandings = self.factionStandings or {}
  for factionID, standing in pairs(captured) do
    if self.factionStandings[factionID] == nil then
      self.factionStandings[factionID] = standing
    end
  end
end

function AceM2L2:ScheduleFactionBaselineRetry()
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 2, function()
      if self:IsEnabled() then
        self:SafeInvoke("EnsureFactionBaseline", "EnsureFactionBaseline")
      end
    end)
  end
end
