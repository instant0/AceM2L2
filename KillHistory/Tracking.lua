--[[---------------------------------------------------------------------------------
  KillHistory/Tracking.lua
  Client wrappers, buffs, kill recording, chat/death matching, and pruning.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util
local Formula = XPTooltip.Formula

local floor, min, max = math.floor, math.min, math.max
local MAX_MOBS = Util.MAX_MOBS
local MAX_PENDING_DEATHS = Util.MAX_PENDING_DEATHS
local MAX_CONTEXTS_PER_MOB = Util.MAX_CONTEXTS_PER_MOB
local CONTEXT_MAX_AGE = Util.CONTEXT_MAX_AGE
local IsSecret = Util.IsSecret
local SafeCall = Util.SafeCall
local SafeNumber = Util.SafeNumber
local SafeString = Util.SafeString
local SafeBool = Util.SafeBool
local Trim = Util.Trim
local Lower = Util.Lower
local CopyTable = Util.CopyTable
local CopyInfo = Util.CopyInfo
local Now = Util.Now
local Epoch = Util.Epoch
local EnsureNumberMap = Util.EnsureNumberMap
local ContextKey = Formula.ContextKey

--[[--------------------------------------------------------------------------------
  Buffs and rest
------------------------------------------------------------------------------------]]

local function HasAura(name)
  if type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function" then
    local ok, aura = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
    if ok and aura and not IsSecret(aura) then
      return true
    end
  end
  if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
    for index = 1, 40 do
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
      if not ok or not aura then
        break
      end
      if not IsSecret(aura) then
        local auraName = aura.name
        if not IsSecret(auraName) and auraName == name then
          return true
        end
      end
    end
  end
  return false
end

function XPTooltip:RecordKill(info, totalXP, rawBase, buffedXP, source, skipObservation)
  if not info then
    return
  end
  local db = self.char
  local playerLevel = info.playerLevel or self:GetPlayerLevel() or 0
  local mapID = info.mapID or self:GetMapID() or 0
  local mobKey = info.mobKey or self:GetMobKey(info.name, info.npcID)
  local lowerName = Lower(info.name)
  local nameKey = lowerName and ("name:" .. lowerName) or nil
  if info.npcID then
    local targetKey = "npc:" .. tostring(info.npcID)
    if nameKey and nameKey ~= targetKey and type(db.mobs) == "table" and db.mobs[nameKey] then
      self:MergeMobEntries(nameKey, targetKey)
    end
    mobKey = targetKey
  else
    local knownKey = type(mobKey) == "string" and mobKey:sub(1, 4) == "npc:" and mobKey
      or self:FindNPCKeyByName(info.name)
    if knownKey then
      if nameKey and nameKey ~= knownKey and type(db.mobs) == "table" and db.mobs[nameKey] then
        self:MergeMobEntries(nameKey, knownKey)
      end
      mobKey = knownKey
    elseif nameKey then
      mobKey = nameKey
    end
  end
  info.mobKey = mobKey
  local mob = self:EnsureMob(mobKey, info.name, info.npcID, info.classification)
  local now = Epoch()

  mob.kills = (tonumber(mob.kills) or 0) + 1
  mob.sessionKills = (tonumber(mob.sessionKills) or 0) + 1
  mob.lastSeen = now
  if playerLevel > 0 then
    local levelKey = tostring(playerLevel)
    mob.killsAtLevel[levelKey] = (tonumber(mob.killsAtLevel[levelKey]) or 0) + 1
    db.levels[levelKey] = (tonumber(db.levels[levelKey]) or 0) + 1
  end
  if mapID > 0 then
    local mapKey = tostring(mapID)
    mob.killsByMap[mapKey] = (tonumber(mob.killsByMap[mapKey]) or 0) + 1
    db.areas[mapKey] = (tonumber(db.areas[mapKey]) or 0) + 1
    if playerLevel > 0 then
      local areaLevels = db.areaLevels[mapKey]
      if type(areaLevels) ~= "table" then
        areaLevels = {}
        db.areaLevels[mapKey] = areaLevels
      end
      local levelKey = tostring(playerLevel)
      areaLevels[levelKey] = (tonumber(areaLevels[levelKey]) or 0) + 1
    end
  end

  db.totals.kills = (tonumber(db.totals.kills) or 0) + 1
  db.session.kills = (tonumber(db.session.kills) or 0) + 1
  if totalXP then
    db.totals.xp = (tonumber(db.totals.xp) or 0) + totalXP
    db.session.xp = (tonumber(db.session.xp) or 0) + totalXP
  end

  if rawBase and rawBase > 0 and not skipObservation then
    self:RecordObservation(mob, info, rawBase, buffedXP, totalXP)
  end

  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end

  if self.settings and self.settings.debug then
    AceM2L2:SafePrint(string.format(
      "Kill History: kill %s (%s) total=%s base=%s source=%s",
      tostring(mob.name or mobKey), tostring(mobKey), tostring(totalXP or "?"),
      tostring(rawBase or "?"), tostring(source or "?")
    ))
  end
end

function XPTooltip:QueueUnidentifiedKill(info, totalXP, rawBase, buffedXP, skipObservation)
  if not self.pendingChatXP then
    self.pendingChatXP = {}
  end
  local stored = {}
  for key, value in pairs(info or {}) do
    stored[key] = value
  end
  local entry = {
    info = stored,
    totalXP = totalXP,
    rawBase = rawBase,
    buffedXP = buffedXP,
    skipObservation = skipObservation and true or false,
    at = Now(),
    generation = self.dataGeneration,
    consumed = false,
    canceled = false,
  }
  self.pendingChatXP[#self.pendingChatXP + 1] = entry
  if self.settings and self.settings.debug then
    AceM2L2:SafePrint(string.format(
      "Kill History: XP %s has no creature name yet; waiting for UNIT_DIED.",
      tostring(totalXP or "?")
    ))
  end
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 3.0, function()
      self:CommitUnidentifiedKill(entry)
    end)
  else
    self:CommitUnidentifiedKill(entry)
  end
  return entry
end

function XPTooltip:RemovePendingChatKill(entry)
  if not self.pendingChatXP then
    return
  end
  for index = #self.pendingChatXP, 1, -1 do
    if self.pendingChatXP[index] == entry then
      table.remove(self.pendingChatXP, index)
    end
  end
end

function XPTooltip:TakePendingChatKill(now)
  if not self.pendingChatXP then
    return nil
  end
  for index = 1, #self.pendingChatXP do
    local entry = self.pendingChatXP[index]
    if entry and not entry.consumed and not entry.canceled
      and entry.generation == self.dataGeneration
      and (now - (entry.at or 0)) <= 4 then
      entry.consumed = true
      table.remove(self.pendingChatXP, index)
      return entry
    end
  end
  return nil
end

function XPTooltip:CommitUnidentifiedKill(entry)
  if not entry or entry.consumed or entry.canceled then
    return
  end
  entry.consumed = true
  self:RemovePendingChatKill(entry)
  if entry.generation ~= self.dataGeneration or not self:IsActive() then
    return
  end
  local info = entry.info or { name = "Unknown" }
  info.playerLevel = info.playerLevel or self:GetPlayerLevel() or 1
  info.level = info.level or info.playerLevel
  info.classification = info.classification or "normal"
  info.groupSize = info.groupSize or self:GetGroupSize()
  info.mapID = info.mapID or self:GetMapID()
  info.buffSignature = info.buffSignature or self:GetBuffSignature()
  info.contextKey = ContextKey(
    info.playerLevel, info.level, info.groupSize, info.mapID,
    info.classification, info.buffSignature
  )
  if not info.mobKey then
    info.mobKey = self:GetMobKey(info.name, info.npcID)
  end
  if self.settings and self.settings.debug then
    AceM2L2:SafePrint(string.format(
      "Kill History: no death identity for XP %s; recording as %s.",
      tostring(entry.totalXP or "?"), tostring(info.name or "Unknown")
    ))
  end
  self:RecordKill(info, entry.totalXP, entry.rawBase, entry.buffedXP, "chat", entry.skipObservation)
  self.lastPool = self:GetRestedPool()
end

function XPTooltip:FindKillInfo(name, now)
  for index = #self.pendingDeaths, 1, -1 do
    local pending = self.pendingDeaths[index]
    if pending and not pending.counted then
      local pendingName = pending.info and pending.info.name
      if (now - pending.at) <= 3 and (not name or not pendingName or Lower(name) == Lower(pendingName)) then
        pending.counted = true
        return pending.info
      end
    end
  end

  local function matches(candidate)
    return candidate
      and (now - candidate.at) <= 3
      and (not name or not candidate.name or Lower(name) == Lower(candidate.name))
  end

  if matches(self.lastTarget) then
    return self.lastTarget
  end
  if matches(self.lastMouseover) then
    return self.lastMouseover
  end
  return { name = name or "Unknown", mobKey = self:GetMobKey(name), at = now }
end

function XPTooltip:HandleXPChat(message)
  if IsSecret(message) then
    return
  end

  local name, total, key = AceM2L2:ParseXPMessage(message)
  if not key or not total or total <= 0 then
    return
  end
  if key:find("_QUEST", 1, true) then
    return
  end

  local now = Now()
  self.lastXPChatAt = now
  local poolAfter = self:GetRestedPool()
  local poolBefore = self.poolBeforeKill or self.lastPool or poolAfter
  self.poolBeforeKill = nil
  local wellFed, wellRested, buffDetection = self:GetBuffInfo()
  local buffMultiplier = self:GetBuffMultiplier(wellFed, wellRested)
  local buffedXP = total
  local rawBase = buffedXP / buffMultiplier
  -- Do not use rested kills for calibration unless the chat text is known to
  -- expose the base/rested split. The total already includes rested, so only
  -- non-rested observations are clean.
  local skipObservation = (poolAfter > 0) or (poolBefore > poolAfter) or (not buffDetection)

  local source = self:FindKillInfo(name, now)
  local info = CopyInfo(source) or {
    name = name or "Unknown",
    mobKey = self:GetMobKey(name),
    at = now,
  }
  local playerLevel = self:GetPlayerLevel() or 1
  local mobLevel = info.level
  if not mobLevel or mobLevel == 0 then
    mobLevel = playerLevel
  end
  local classification = info.classification or "normal"
  local groupSize = self:GetGroupSize()
  local mapID = self:GetMapID()
  local buffSignature = self:GetBuffSignature()
  if buffSignature ~= "none" then
    skipObservation = true
  end
  if groupSize > 1 then
    -- Until the live chat amount is verified for group kills, use the classic
    -- group prior for display and do not train a group ratio from a possibly
    -- summed "base + party bonus" text.
    skipObservation = true
  end
  if not self:CanReadRested() then
    skipObservation = true
  end

  info.playerLevel = playerLevel
  info.level = mobLevel
  info.classification = classification
  info.groupSize = groupSize
  info.mapID = mapID
  info.buffSignature = buffSignature
  info.contextKey = ContextKey(playerLevel, mobLevel, groupSize, mapID, classification, buffSignature)
  if not info.mobKey then
    info.mobKey = self:GetMobKey(info.name, info.npcID)
  end

  local resolvedName = Lower(info.name)
  if (not name or name == "" or Lower(name) == "unknown")
    and (not resolvedName or resolvedName == "" or resolvedName == "unknown") then
    -- Some XP messages omit the creature name. Wait briefly for UNIT_DIED so
    -- the guid/target path can identify the mob instead of recording "Unknown".
    self.lastPool = poolAfter
    self:QueueUnidentifiedKill(info, total, rawBase, buffedXP, skipObservation)
    return
  end

  self:RecordKill(info, total, rawBase, buffedXP, "chat", skipObservation)
  self.recentChatKills[#self.recentChatKills + 1] = {
    mobKey = info.mobKey,
    name = info.name,
    at = now,
  }
  while #self.recentChatKills > MAX_PENDING_DEATHS do
    table.remove(self.recentChatKills, 1)
  end
  self.lastPool = poolAfter
end

function XPTooltip:HandlePlayerXPUpdate()
  local current = self:GetXP()
  if not current then
    return
  end

  self.lastXP = current
  self.lastPool = self:GetRestedPool()
  self.lastXPUpdateAt = Now()
end

function XPTooltip:FindDeathCandidate(guid)
  local now = Now()
  -- Exact GUID matches are safe even if the target was acquired long ago.
  -- Target units are often cleared as soon as a mob dies, so keep the last
  -- valid hostile target briefly instead of dropping its identity.
  if guid and self.lastTarget and self.lastTarget.guid == guid
    and (now - (self.lastTarget.at or 0)) <= 60 then
    return self.lastTarget
  end
  if guid and self.lastMouseover and self.lastMouseover.guid == guid
    and (now - (self.lastMouseover.at or 0)) <= 60 then
    return self.lastMouseover
  end

  local targetDead = SafeBool(SafeCall(UnitIsDead, "target"))
  if targetDead and self.lastTarget and (now - self.lastTarget.at) <= 10 then
    return self.lastTarget
  end
  local mouseoverDead = SafeBool(SafeCall(UnitIsDead, "mouseover"))
  if mouseoverDead and self.lastMouseover and (now - self.lastMouseover.at) <= 10 then
    return self.lastMouseover
  end

  return nil
end

function XPTooltip:HandleUnitDied(guid)
  local safeGUID = SafeString(guid)
  local candidate = self:FindDeathCandidate(safeGUID)
  if not candidate then
    return
  end

  -- The XP chat event can arrive before UNIT_DIED. If we already counted this
  -- kill from chat, do not queue a second zero-XP death for it.
  local now = Now()
  for index = #self.recentChatKills, 1, -1 do
    local recent = self.recentChatKills[index]
    if recent and (now - (recent.at or 0)) <= 3 then
      local sameKey = recent.mobKey and candidate.mobKey and recent.mobKey == candidate.mobKey
      local bothKeysKnown = recent.mobKey and candidate.mobKey
      local sameName = recent.name and candidate.name and Lower(recent.name) == Lower(candidate.name)
      local recentNameOnly = type(recent.mobKey) == "string" and recent.mobKey:sub(1, 5) == "name:"
      local candidateNameOnly = type(candidate.mobKey) == "string" and candidate.mobKey:sub(1, 5) == "name:"
      if sameKey or (sameName and (recentNameOnly or candidateNameOnly))
        or (not bothKeysKnown and sameName) then
        if sameName and not sameKey and recent.mobKey and candidate.mobKey then
          if recentNameOnly then
            self:MergeMobEntries(recent.mobKey, candidate.mobKey)
          elseif candidateNameOnly then
            self:MergeMobEntries(candidate.mobKey, recent.mobKey)
          end
        end
        table.remove(self.recentChatKills, index)
        return
      end
    end
  end

  local pendingXP = self:TakePendingChatKill(now)
  if pendingXP then
    local info = CopyInfo(candidate) or {}
    local stored = pendingXP.info or {}
    info.name = info.name or stored.name
    info.guid = info.guid or stored.guid
    info.npcID = info.npcID or stored.npcID
    info.mobKey = info.mobKey or self:GetMobKey(info.name, info.npcID)
    info.level = info.level or stored.level
    info.classification = info.classification or stored.classification
    info.playerLevel = stored.playerLevel or self:GetPlayerLevel() or 1
    info.groupSize = stored.groupSize or self:GetGroupSize()
    info.mapID = stored.mapID or self:GetMapID()
    info.buffSignature = stored.buffSignature or self:GetBuffSignature()
    info.contextKey = ContextKey(
      info.playerLevel, info.level or info.playerLevel, info.groupSize, info.mapID,
      info.classification or "normal", info.buffSignature
    )
    self:RecordKill(info, pendingXP.totalXP, pendingXP.rawBase, pendingXP.buffedXP, "chat", pendingXP.skipObservation)
    return
  end

  self.poolBeforeKill = self:GetRestedPool()

  local entry = {
    info = candidate,
    at = Now(),
    counted = false,
    committed = false,
    generation = self.dataGeneration,
    countZero = self.settings and self.settings.countZeroXPMobs,
  }
  self.pendingDeaths[#self.pendingDeaths + 1] = entry
  while #self.pendingDeaths > MAX_PENDING_DEATHS do
    table.remove(self.pendingDeaths, 1)
  end

  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 2.5, function()
      self:CommitPendingDeath(entry)
    end)
  else
    self:CommitPendingDeath(entry)
  end
end

function XPTooltip:CommitPendingDeath(entry)
  if not entry or entry.counted or entry.committed then
    return
  end
  if entry.generation ~= self.dataGeneration then
    return
  end
  entry.committed = true
  if not self:IsActive() then
    return
  end
  if entry.countZero then
    local info = CopyInfo(entry.info) or { name = "Unknown", at = Now() }
    info.playerLevel = self:GetPlayerLevel() or 1
    info.level = info.level or info.playerLevel
    info.classification = info.classification or "normal"
    info.groupSize = self:GetGroupSize()
    info.mapID = info.mapID or self:GetMapID()
    info.buffSignature = self:GetBuffSignature()
    info.contextKey = ContextKey(
      info.playerLevel, info.level, info.groupSize, info.mapID, info.classification, info.buffSignature
    )
    self:RecordKill(info, nil, nil, nil, "death")
  end
  self.poolBeforeKill = nil
end
