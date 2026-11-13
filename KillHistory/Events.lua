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

function XPTooltip:OnUnitDied(event, guid)
  if not self:IsActive() then
    return
  end
  local ok, err = pcall(self.HandleUnitDied, self, guid)
  if not ok then
    self:ReportError("OnUnitDied", err)
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

function XPTooltip:OnZoneChanged(event)
  self.lastPool = self:GetRestedPool()
  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end

function XPTooltip:OnLevelUp(event, level)
  self.lastPool = self:GetRestedPool()
  self:SchedulePrune()
  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end

function XPTooltip:OnLogin(event)
  self:StartSession()
  self.lastXP = self:GetXP()
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
  self.lastXP = self:GetXP()
end

function XPTooltip:OnXPGainDisabled(event)
  self.lastXP = self:GetXP()
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
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      mob.sessionKills = 0
      mob.sessionXP = 0
    end
  end
end

function XPTooltip:SchedulePrune()
  if self.pruneScheduled then
    return
  end
  self.pruneScheduled = true
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 5, function()
      self.pruneScheduled = false
      if self:IsActive() then
        self:Prune()
      end
    end)
  else
    self.pruneScheduled = false
    self:Prune()
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
      mob.kills = math.max(0, tonumber(mob.kills) or 0)
      mob.sessionKills = math.max(0, tonumber(mob.sessionKills) or 0)
      if type(mob.name) ~= "string" then
        mob.name = "Unknown"
      elseif #mob.name > 80 then
        mob.name = mob.name:sub(1, 80)
      end
      mob.killsAtLevel = EnsureNumberMap(mob.killsAtLevel)
      mob.killsByMap = EnsureNumberMap(mob.killsByMap)
      mob.killsByAreaLevel = EnsureNumberMap(mob.killsByAreaLevel)
      mob.contexts = EnsureNumberMap(mob.contexts)
      mob.totalXP = tonumber(mob.totalXP) or 0
      mob.sessionXP = tonumber(mob.sessionXP) or 0

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
    table.sort(removable, function(a, b) return a.seen < b.seen end)
    for _, entry in ipairs(removable) do
      if mobCount <= MAX_MOBS then
        break
      end
      self:MarkMobDeleted(entry.key)
      db.mobs[entry.key] = nil
      if db.calibration and db.calibration.mobs then
        db.calibration.mobs[entry.key] = nil
      end
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
    table.sort(removable, function(a, b) return a.seen < b.seen end)
    for _, entry in ipairs(removable) do
      if mobCount <= MAX_MOBS then
        break
      end
      self:MarkMobDeleted(entry.key)
      db.mobs[entry.key] = nil
      if db.calibration and db.calibration.mobs then
        db.calibration.mobs[entry.key] = nil
      end
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
  if self.ui and self.ui:IsShown() then
    self:RequestUIUpdate()
  end
end
