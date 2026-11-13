--[[---------------------------------------------------------------------------------
  KillHistory/Events.lua
  Event entry points, session lifecycle, and scheduled pruning.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local MAX_MOBS = Util.MAX_MOBS
local MAX_CONTEXTS_PER_MOB = Util.MAX_CONTEXTS_PER_MOB
local CONTEXT_MAX_AGE = Util.CONTEXT_MAX_AGE
local Now = Util.Now
local Epoch = Util.Epoch
local EnsureNumberMap = Util.EnsureNumberMap

function XPTooltip:OnXPChat(event, message)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleXPChat, self, message)
  if not ok then
    self:ReportError("OnXPChat", err)
  end
end

function XPTooltip:OnPlayerXPUpdate(event)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandlePlayerXPUpdate, self)
  if not ok then
    self:ReportError("OnPlayerXPUpdate", err)
  end
end

function XPTooltip:OnMoneyChanged(event)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleMoneyChanged, self)
  if not ok then
    self:ReportError("OnMoneyChanged", err)
  end
end

function XPTooltip:OnLootMessage(event, message, sender)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleLootMessage, self, message, sender)
  if not ok then
    self:ReportError("OnLootMessage", err)
  end
end

function XPTooltip:OnUnitDied(event, guid)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleUnitDied, self, guid)
  if not ok then
    self:ReportError("OnUnitDied", err)
  end
end

function XPTooltip:OnPlayerDied(event)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandlePlayerDeath, self)
  if not ok then
    self:ReportError("OnPlayerDied", err)
  end
end

function XPTooltip:OnTargetChanged(event)
  if not self:IsActive() then
    return
  end
  local captured = self:CaptureUnit("target")
  if captured then
    self.lastTarget = captured
  elseif self.lastTarget and (Now() - (self.lastTarget.at or 0)) > 60 then
    self.lastTarget = nil
  end
end

function XPTooltip:OnMouseoverChanged(event)
  if not self:IsActive() then
    return
  end
  local captured = self:CaptureUnit("mouseover")
  if captured then
    self.lastMouseover = captured
  elseif self.lastMouseover and (Now() - (self.lastMouseover.at or 0)) > 60 then
    self.lastMouseover = nil
  end
end

function XPTooltip:OnNamePlateAdded(event, unit)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleNamePlate, self, unit)
  if not ok then
    self:ReportError("OnNamePlateAdded", err)
  end
end

function XPTooltip:OnNamePlateRemoved(event, unit)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HideNamePlateLevel, self, unit)
  if not ok then
    self:ReportError("OnNamePlateRemoved", err)
  end
end

function XPTooltip:OnZoneChanged(event)
  self.lastPool = self:GetRestedPool()
  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end

function XPTooltip:OnLevelUp(event, level)
  self:FinalizeLevelHistory(level)
  self:ResetRates()
  self.lastPool = self:GetRestedPool()
  self:SchedulePrune()
  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end

function XPTooltip:OnLogin(event)
  self:StartSession()
  self:EnsureLevelHistory()
  self.lastPool = self:GetRestedPool()
  self:SchedulePrune()
end

function XPTooltip:OnEnteringWorld(event)
  self.lastPool = self:GetRestedPool()
  if not self.active then
    self:Refresh()
  end
end

function XPTooltip:OnXPGainEnabled(event)
end

function XPTooltip:OnXPGainDisabled(event)
end

function XPTooltip:OnMaxLevelUpdate(event)
  self.lastPool = self:GetRestedPool()
end

function XPTooltip:StartSession()
  local db = self.char
  if type(db.session) ~= "table" then
    db.session = {}
  end
  db.session.startedAt = Epoch()
  db.session.kills = 0
  db.session.xp = 0
  local dungeon = db.dungeon
  if type(dungeon) ~= "table" then
    dungeon = {}
    db.dungeon = dungeon
  end
  dungeon.sessionXP = 0
  dungeon.sessionKills = 0
  local economy = db.economy
  if type(economy) ~= "table" then
    economy = {}
    db.economy = economy
  end
  economy.sessionLootValue = 0
  economy.sessionItems = 0
  economy.goldGained = 0
  economy.goldSpent = 0
  economy.moneyKnown = false
  self:RecordMoney(self:GetMoney())
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      mob.sessionKills = 0
      mob.sessionXP = 0
      mob.sessionXPKnown = false
    end
  end
  self:ResetRates()
end

local function RunPruneSafely(self)
  self.pruneScheduled = false
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.Prune, self)
  if not ok then
    self:ReportError("Prune", err)
  end
end

function XPTooltip:SchedulePrune()
  if self.pruneScheduled then
    return
  end
  self.pruneScheduled = true
  if C_Timer and C_Timer.After then
    local scheduled = pcall(C_Timer.After, 5, function()
      RunPruneSafely(self)
    end)
    if not scheduled then
      self.pruneScheduled = false
    end
  else
    RunPruneSafely(self)
  end
end

function XPTooltip:Prune()
  local db = self.char
  if not db then
    return
  end
  local now = Epoch()
  local mobCount = 0

  for mobKey, mob in pairs(db.mobs) do
    if type(mob) ~= "table" then
      db.mobs[mobKey] = nil
    else
      mobCount = mobCount + 1
      self:NormalizeMobFields(mob)
      if type(mob.name) ~= "string" then
        mob.name = "Unknown"
      elseif #mob.name > 80 then
        mob.name = mob.name:sub(1, 80)
      end

      local contextCount = 0
      local oldestKey, oldestSeen
      for contextKey, context in pairs(mob.contexts) do
        if type(context) ~= "table" then
          mob.contexts[contextKey] = nil
        else
          local lastSeen = tonumber(context.lastSeen) or 0
          if lastSeen > 0 and (now - lastSeen) > CONTEXT_MAX_AGE then
            mob.contexts[contextKey] = nil
          else
            contextCount = contextCount + 1
            if not oldestSeen or lastSeen < oldestSeen then
              oldestSeen = lastSeen
              oldestKey = contextKey
            end
          end
        end
      end
      while contextCount > MAX_CONTEXTS_PER_MOB and oldestKey do
        mob.contexts[oldestKey] = nil
        contextCount = contextCount - 1
        oldestKey, oldestSeen = nil, nil
        for contextKey, context in pairs(mob.contexts) do
          local lastSeen = tonumber(context.lastSeen) or 0
          if not oldestSeen or lastSeen < oldestSeen then
            oldestSeen = lastSeen
            oldestKey = contextKey
          end
        end
      end
    end
  end

  if mobCount > MAX_MOBS then
    local removable = {}
    for mobKey, mob in pairs(db.mobs) do
      if type(mob) == "table" and (tonumber(mob.kills) or 0) <= 0 then
        removable[#removable + 1] = { key = mobKey, seen = tonumber(mob.lastSeen) or 0 }
      end
    end
    table.sort(removable, function(a, b)
      if a.seen == b.seen then
        return a.key < b.key
      end
      return a.seen < b.seen
    end)
    for _, entry in ipairs(removable) do
      if mobCount <= MAX_MOBS then
        break
      end
      self:MarkMobDeleted(entry.key)
      self:RemoveMobEntry(entry.key, true)
      mobCount = mobCount - 1
    end
  end

  if mobCount > MAX_MOBS then
    local removable = {}
    for mobKey, mob in pairs(db.mobs) do
      if type(mob) == "table" then
        removable[#removable + 1] = { key = mobKey, seen = tonumber(mob.lastSeen) or 0 }
      end
    end
    table.sort(removable, function(a, b)
      if a.seen == b.seen then
        return a.key < b.key
      end
      return a.seen < b.seen
    end)
    for _, entry in ipairs(removable) do
      if mobCount <= MAX_MOBS then
        break
      end
      self:MarkMobDeleted(entry.key)
      self:RemoveMobEntry(entry.key, true)
      mobCount = mobCount - 1
    end
  end

  local actual = 0
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      actual = actual + 1
    end
  end
  db.totals.uniqueMobs = actual
  self:TrimLevelHistory()
  self:NormalizeRates()
  if type(self.NormalizeDeaths) == "function" then
    self:NormalizeDeaths()
  end
  if type(self.NormalizeRespawns) == "function" then
    self:NormalizeRespawns()
  end
  if type(self.NormalizeHeatmaps) == "function" then
    self:NormalizeHeatmaps()
  end

  -- Respawn watches are transient GetTime() sightings; anything older than an
  -- hour is no longer a credible respawn.
  local watches = self.respawnWatches
  if type(watches) == "table" then
    local watchNow = Now()
    for key, watch in pairs(watches) do
      local at = type(watch) == "table" and tonumber(watch.at) or nil
      if not at or (watchNow - at) > 3600 then
        watches[key] = nil
      end
    end
  end

  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end
