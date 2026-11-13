--[[---------------------------------------------------------------------------------
  KillHistory/Tracking.lua
  Client wrappers, buffs, kill recording, chat/death matching, and pruning.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util
local Formula = XPTooltip.Formula

local floor, min, max = math.floor, math.min, math.max
local MAX_PENDING_DEATHS = Util.MAX_PENDING_DEATHS
local IsSecret = Util.IsSecret
local SafeCall = Util.SafeCall
local SafeString = Util.SafeString
local SafeBool = Util.SafeBool
local Lower = Util.Lower
local CopyInfo = Util.CopyInfo
local Now = Util.Now
local Epoch = Util.Epoch
local ContextKey = Formula.ContextKey
local DEATH_COMMIT_DELAY = 2.5
local CHAT_MATCH_WINDOW = 3.0
local PENDING_CHAT_WINDOW = 4.5
local PENDING_CHAT_COMMIT_DELAY = 5.0
local LATE_CHAT_WINDOW = 6.0

--[[--------------------------------------------------------------------------------
  Buffs and rest
------------------------------------------------------------------------------------]]

function XPTooltip:RecordKill(info, totalXP, rawBase, buffedXP, source, skipObservation)
  if not info then
    return
  end
  local supportsPerMobXP = self:Supports("hasPerMobXP")
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
      local byArea = mob.killsByAreaLevel[mapKey]
      if type(byArea) ~= "table" then
        byArea = {}
        mob.killsByAreaLevel[mapKey] = byArea
      end
      byArea[levelKey] = (tonumber(byArea[levelKey]) or 0) + 1
    end
  end

  db.totals.kills = (tonumber(db.totals.kills) or 0) + 1
  db.session.kills = (tonumber(db.session.kills) or 0) + 1
  if totalXP and supportsPerMobXP then
    mob.totalXP = (tonumber(mob.totalXP) or 0) + totalXP
    mob.sessionXP = (tonumber(mob.sessionXP) or 0) + totalXP
    db.totals.xp = (tonumber(db.totals.xp) or 0) + totalXP
    db.session.xp = (tonumber(db.session.xp) or 0) + totalXP
  end

  if rawBase and rawBase > 0 and not skipObservation and supportsPerMobXP then
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
  return mob, mobKey
end

function XPTooltip:AddKillXP(entry, info, totalXP, rawBase, buffedXP, skipObservation)
  if not entry or not info or not totalXP then
    return false
  end
  local db = self.char
  local mobKey = entry.resolvedMobKey or info.mobKey
  local mob = mobKey and db and db.mobs and db.mobs[mobKey] or nil
  if type(mob) ~= "table" then
    if self.settings and self.settings.debug then
      AceM2L2:SafePrint(string.format(
        "Kill History: late XP %s has no surviving mob entry (%s); skipping.",
        tostring(totalXP), tostring(mobKey or "?")
      ))
    end
    return false
  end

  mob.totalXP = (tonumber(mob.totalXP) or 0) + totalXP
  mob.sessionXP = (tonumber(mob.sessionXP) or 0) + totalXP
  mob.lastSeen = Epoch()
  db.totals.xp = (tonumber(db.totals.xp) or 0) + totalXP
  db.session.xp = (tonumber(db.session.xp) or 0) + totalXP

  if rawBase and rawBase > 0 and not skipObservation then
    self:RecordObservation(mob, info, rawBase, buffedXP, totalXP)
  end

  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end

  if self.settings and self.settings.debug then
    AceM2L2:SafePrint(string.format(
      "Kill History: late XP %s added to %s (%s); kills unchanged.",
      tostring(totalXP), tostring(mob.name or mobKey), tostring(mobKey)
    ))
  end
  return true
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
    pcall(C_Timer.After, PENDING_CHAT_COMMIT_DELAY, function()
      local ok, err = pcall(self.CommitUnidentifiedKill, self, entry)
      if not ok then
        self:ReportError("CommitUnidentifiedKill", err)
      end
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
      and (now - (entry.at or 0)) <= PENDING_CHAT_WINDOW then
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

function XPTooltip:PrunePendingDeaths(now)
  local keep = {}
  for _, entry in ipairs(self.pendingDeaths or {}) do
    if type(entry) == "table" and not entry.expired then
      local age = now - (entry.at or 0)
      local window = entry.recordedKill and LATE_CHAT_WINDOW or CHAT_MATCH_WINDOW
      if age <= window then
        keep[#keep + 1] = entry
      else
        entry.expired = true
      end
    end
  end
  self.pendingDeaths = keep
end

function XPTooltip:PruneRecentChatKills(now)
  local keep = {}
  for _, entry in ipairs(self.recentChatKills or {}) do
    if type(entry) == "table" and (now - (entry.at or 0)) <= CHAT_MATCH_WINDOW then
      keep[#keep + 1] = entry
    end
  end
  self.recentChatKills = keep
end

function XPTooltip:MarkMobDeleted(mobKey)
  if not mobKey then
    return
  end
  self.deletedMobKeys = self.deletedMobKeys or {}
  self.deletedMobKeys[mobKey] = Now()
end

function XPTooltip:PruneDeletedMobKeys(now)
  local deleted = self.deletedMobKeys
  if type(deleted) ~= "table" then
    self.deletedMobKeys = {}
    return
  end
  for key, at in pairs(deleted) do
    if (now - (tonumber(at) or 0)) > CHAT_MATCH_WINDOW then
      deleted[key] = nil
    end
  end
end

function XPTooltip:IsMobRecentlyDeleted(mobKey, now)
  local deleted = self.deletedMobKeys
  if type(deleted) ~= "table" or not mobKey then
    return false
  end
  local at = tonumber(deleted[mobKey])
  if not at then
    return false
  end
  if (now - at) > CHAT_MATCH_WINDOW then
    deleted[mobKey] = nil
    return false
  end
  return true
end

local function NameMatches(left, right)
  if not left or not right then
    return true
  end
  return Lower(left) == Lower(right)
end

-- Returns `entry, mode` where mode is:
--   "record_xp" - no kill recorded yet; record a normal chat kill
--   "add_xp"    - a zero-XP kill was already recorded; add XP only
--   "duplicate" - this death already has its chat XP
--   nil         - no pending death; caller may use lastTarget/mouseover
-- The function does not mutate the entry; the caller commits the transition
-- after the record/add succeeds.
function XPTooltip:FindKillInfo(name, now)
  self:PrunePendingDeaths(now)
  local duplicate = false

  for _, entry in ipairs(self.pendingDeaths or {}) do
    if type(entry) == "table" and not entry.expired
      and entry.generation == self.dataGeneration then
      local pendingName = entry.info and entry.info.name
      if NameMatches(name, pendingName) then
        local age = now - (entry.at or 0)
        if entry.recordedKill and entry.xpApplied then
          duplicate = true
        elseif entry.recordedKill and not entry.xpApplied and age <= LATE_CHAT_WINDOW then
          return entry, "add_xp"
        elseif not entry.recordedKill and not entry.counted and age <= CHAT_MATCH_WINDOW then
          return entry, "record_xp"
        end
      end
    end
  end

  if duplicate then
    return nil, "duplicate"
  end

  local function matches(candidate)
    return candidate
      and (now - candidate.at) <= CHAT_MATCH_WINDOW
      and NameMatches(name, candidate.name)
  end

  if matches(self.lastTarget) then
    return self.lastTarget, "record_xp"
  end
  if matches(self.lastMouseover) then
    return self.lastMouseover, "record_xp"
  end
  return { name = name or "Unknown", mobKey = self:GetMobKey(name), at = now }, "record_xp"
end

function XPTooltip:HandleXPChat(message)
  if not self:Supports("hasPerMobXP") then
    return
  end
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
  local wellFed, wellRested, buffDetection, restedStacks = self:GetBuffInfo()
  local buffMultiplier = self:GetBuffMultiplier(wellFed, wellRested, restedStacks)
  local buffedXP = total
  local rawBase = buffedXP / buffMultiplier
  -- Do not use rested kills for calibration unless the chat text is known to
  -- expose the base/rested split. The total already includes rested, so only
  -- non-rested observations are clean.
  local skipObservation = (poolAfter > 0) or (poolBefore > poolAfter) or (not buffDetection)

  local source, mode = self:FindKillInfo(name, now)
  if mode == "duplicate" then
    self.lastPool = poolAfter
    return
  end

  local deathEntry = (mode and type(source) == "table" and source.info) and source or nil
  local infoSource = deathEntry and deathEntry.info or source
  local info = CopyInfo(infoSource) or {
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

  self:PruneDeletedMobKeys(now)
  if self:IsMobRecentlyDeleted(info.mobKey, now) then
    self.lastPool = poolAfter
    return
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

  if mode == "add_xp" then
    if self:AddKillXP(deathEntry, info, total, rawBase, buffedXP, skipObservation) then
      deathEntry.xpApplied = true
      deathEntry.counted = true
      deathEntry.resolvedMobKey = deathEntry.resolvedMobKey or info.mobKey
      self.recentChatKills[#self.recentChatKills + 1] = {
        mobKey = deathEntry.resolvedMobKey or info.mobKey,
        name = info.name,
        guid = info.guid,
        at = now,
        totalXP = total,
      }
      while #self.recentChatKills > MAX_PENDING_DEATHS do
        table.remove(self.recentChatKills, 1)
      end
    end
    self.lastPool = poolAfter
    return
  end

  local _, resolvedKey = self:RecordKill(info, total, rawBase, buffedXP, "chat", skipObservation)
  if deathEntry then
    deathEntry.counted = true
    deathEntry.recordedKill = true
    deathEntry.xpApplied = true
    deathEntry.resolvedMobKey = resolvedKey or info.mobKey
  end
  self.recentChatKills[#self.recentChatKills + 1] = {
    mobKey = resolvedKey or info.mobKey,
    name = info.name,
    guid = info.guid,
    at = now,
    totalXP = total,
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
  if guid and self.lastTarget and self.lastTarget.guid == guid then
    return self.lastTarget
  end
  if guid and self.lastMouseover and self.lastMouseover.guid == guid then
    return self.lastMouseover
  end

  -- Forever can fall back to the last target when the client clears its GUID on
  -- death. Counts-only clients cannot be corrected by XP chat, so only exact
  -- GUID matches are safe there.
  if not self:Supports("hasPerMobXP") then
    return nil
  end

  local targetDead = SafeBool(SafeCall(UnitIsDead, "target"))
  local mouseoverDead = SafeBool(SafeCall(UnitIsDead, "mouseover"))
  if targetDead and self.lastTarget and (now - self.lastTarget.at) <= 10 then
    return self.lastTarget
  end
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

  local now = Now()
  self:PrunePendingDeaths(now)
  self:PruneRecentChatKills(now)

  -- Ignore duplicate UNIT_DIED events for a death we already track.
  if safeGUID then
    for _, entry in ipairs(self.pendingDeaths or {}) do
      if type(entry) == "table" and not entry.expired and entry.guid == safeGUID
        and (now - (entry.at or 0)) <= CHAT_MATCH_WINDOW then
        return
      end
    end
  end

  -- Exact GUID matches always suppress a duplicate death.
  if safeGUID then
    for index = #self.recentChatKills, 1, -1 do
      local recent = self.recentChatKills[index]
      if recent and recent.guid == safeGUID
        and (now - (recent.at or 0)) <= CHAT_MATCH_WINDOW then
        table.remove(self.recentChatKills, index)
        return
      end
    end
  end

  -- Name-only matching is allowed only when it cannot hide a distinct spawn.
  local matchIndex
  local matchCount = 0
  for index = #self.recentChatKills, 1, -1 do
    local recent = self.recentChatKills[index]
    if recent and (now - (recent.at or 0)) <= CHAT_MATCH_WINDOW then
      local sameKey = recent.mobKey and candidate.mobKey and recent.mobKey == candidate.mobKey
      local bothKeysKnown = recent.mobKey and candidate.mobKey
      local sameName = recent.name and candidate.name and Lower(recent.name) == Lower(candidate.name)
      local recentNameOnly = type(recent.mobKey) == "string" and recent.mobKey:sub(1, 5) == "name:"
      local candidateNameOnly = type(candidate.mobKey) == "string" and candidate.mobKey:sub(1, 5) == "name:"
      local looksSame = sameKey
        or (sameName and (recentNameOnly or candidateNameOnly))
        or (not bothKeysKnown and sameName)
      if looksSame then
        -- A readable, different GUID is a different spawn; never suppress it.
        if safeGUID and recent.guid and recent.guid ~= safeGUID then
          looksSame = false
        elseif safeGUID and not recent.guid and not sameName then
          looksSame = false
        end
      end
      if looksSame then
        matchIndex = index
        matchCount = matchCount + 1
        if sameName and not sameKey and recent.mobKey and candidate.mobKey then
          if recentNameOnly then
            self:MergeMobEntries(recent.mobKey, candidate.mobKey)
          elseif candidateNameOnly then
            self:MergeMobEntries(candidate.mobKey, recent.mobKey)
          end
        end
      end
    end
  end
  if matchIndex and matchCount == 1 then
    table.remove(self.recentChatKills, matchIndex)
    return
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
    local _, resolvedKey = self:RecordKill(
      info, pendingXP.totalXP, pendingXP.rawBase, pendingXP.buffedXP,
      "chat", pendingXP.skipObservation
    )
    self.recentChatKills[#self.recentChatKills + 1] = {
      mobKey = resolvedKey or info.mobKey,
      name = info.name,
      guid = info.guid,
      at = now,
      totalXP = pendingXP.totalXP,
    }
    while #self.recentChatKills > MAX_PENDING_DEATHS do
      table.remove(self.recentChatKills, 1)
    end
    return
  end

  self.poolBeforeKill = self:GetRestedPool()

  local countZero = self.settings and self.settings.countZeroXPMobs
  if not self:Supports("hasPerMobXP") then
    -- UNIT_DIED is the only kill source on counts-only clients, so the setting
    -- that filters gray/zero-XP kills from the XP path must not suppress them.
    countZero = true
  end

  local entry = {
    info = candidate,
    guid = safeGUID,
    at = now,
    counted = false,
    recordedKill = false,
    xpApplied = false,
    expired = false,
    resolvedMobKey = nil,
    generation = self.dataGeneration,
    countZero = countZero,
  }
  self.pendingDeaths[#self.pendingDeaths + 1] = entry
  while #self.pendingDeaths > MAX_PENDING_DEATHS do
    table.remove(self.pendingDeaths, 1)
  end

  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, DEATH_COMMIT_DELAY, function()
      local ok, err = pcall(self.CommitPendingDeath, self, entry)
      if not ok then
        self:ReportError("CommitPendingDeath", err)
      end
    end)
  else
    self:CommitPendingDeath(entry)
  end
end

function XPTooltip:CommitPendingDeath(entry)
  if not entry or entry.expired or entry.counted or entry.recordedKill then
    return
  end
  if entry.generation ~= self.dataGeneration then
    entry.expired = true
    return
  end
  if not self:IsActive() then
    entry.expired = true
    return
  end

  local now = Now()
  self:PrunePendingDeaths(now)
  if entry.expired or entry.counted or entry.recordedKill then
    return
  end
  if (now - (entry.at or 0)) > CHAT_MATCH_WINDOW and not entry.countZero then
    entry.expired = true
    return
  end

  if entry.countZero or not self:Supports("hasPerMobXP") then
    local info = CopyInfo(entry.info) or { name = "Unknown", at = now }
    info.playerLevel = self:GetPlayerLevel() or 1
    info.level = info.level or info.playerLevel
    info.classification = info.classification or "normal"
    info.groupSize = self:GetGroupSize()
    info.mapID = info.mapID or self:GetMapID()
    info.buffSignature = self:GetBuffSignature()
    info.contextKey = ContextKey(
      info.playerLevel, info.level, info.groupSize, info.mapID, info.classification, info.buffSignature
    )
    local _, resolvedKey = self:RecordKill(info, nil, nil, nil, "death")
    entry.recordedKill = true
    entry.recordedAt = now
    entry.resolvedMobKey = resolvedKey or info.mobKey
    self.poolBeforeKill = nil
  end
end
