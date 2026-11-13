--[[---------------------------------------------------------------------------------
  KillHistory/Calibration.lua
  XP correction stores, observations, estimates, and reset/migration helpers.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util
local Formula = XPTooltip.Formula

local floor, min, max = math.floor, math.min, math.max
local CALIBRATION_VERSION = Util.CALIBRATION_VERSION
local Clamp = Util.Clamp
local Epoch = Util.Epoch
local EnsureNumberMap = Util.EnsureNumberMap
local ContextKey = Formula.ContextKey

local function GetProfile(self)
  return self.clientProfile or self:GetClientProfile()
end

local function ProfileFormula(self, playerLevel, mobLevel, classification)
  local profile = GetProfile(self)
  if not profile or not profile:Supports("hasXPFormula") then
    return nil
  end
  return profile:GetFormula(playerLevel, mobLevel, classification)
end

local function ProfileRound(self, value)
  local profile = GetProfile(self)
  if profile and profile.Round then
    return profile:Round(value)
  end
  return Formula.Round(value)
end

function XPTooltip:UpdateRatio(store, key, ratio)
  if not store or not key then
    return
  end
  local entry = store[key]
  if type(entry) ~= "table" then
    entry = { ratio = ratio, samples = 0, updated = Epoch() }
    store[key] = entry
  end
  entry.samples = (tonumber(entry.samples) or 0) + 1
  local alpha = entry.samples <= 5 and 0.5 or 0.15
  entry.ratio = (tonumber(entry.ratio) or 1) + (ratio - (tonumber(entry.ratio) or 1)) * alpha
  entry.ratio = Clamp(entry.ratio, 0.5, 2.0)
  entry.updated = Epoch()
end

function XPTooltip:EffectiveRatio(entry)
  if type(entry) ~= "table" then
    return 1
  end
  local samples = tonumber(entry.samples) or 0
  if samples < 1 then
    return 1
  end
  local weight = min(samples, 10) / 10
  return 1 + ((tonumber(entry.ratio) or 1) - 1) * weight
end

function XPTooltip:HasRatioSamples(entry, minimum)
  return type(entry) == "table" and (tonumber(entry.samples) or 0) >= minimum
end

function XPTooltip:GetEstimate(playerLevel, mobLevel, classification, mapID, groupSize, mobKey, buffSignature)
  local profile = GetProfile(self)
  if not profile or not profile:Supports("hasXPFormula") then
    return 0
  end
  local base = ProfileFormula(self, playerLevel, mobLevel, classification)
  if not base or base <= 0 then
    return 0
  end

  local wellFed, wellRested, _, restedStacks = self:GetBuffInfo()
  local buffed = ProfileRound(self, base * self:GetBuffMultiplier(wellFed, wellRested, restedStacks))

  local calibration = self.char and self.char.calibration
  local groupRatio
  if groupSize and groupSize > 1 then
    if profile:UsesGroupLearning() then
      local groupEntry = calibration and calibration.groups[tostring(groupSize)]
      if self:HasRatioSamples(groupEntry, 5) then
        groupRatio = self:EffectiveRatio(groupEntry)
      else
        groupRatio = profile:GetGroupPrior(groupSize)
      end
    else
      groupRatio = profile:GetGroupPrior(groupSize)
    end
  else
    groupRatio = 1
  end

  local correction = 1
  if calibration then
    local function pick(entry, minimum)
      if not self:HasRatioSamples(entry, minimum) then
        return nil
      end
      local value = self:EffectiveRatio(entry)
      if math.abs(value - 1) < 0.02 then
        return nil
      end
      return value
    end

    local mobEntry = calibration.mobs[mobKey]
    local classEntry = calibration.classes[classification]
    local levelEntry = calibration.levels[tostring(playerLevel)]
    local zoneEntry = calibration.zones[tostring(mapID)]
    local picked = pick(mobEntry, 5)
      or pick(classEntry, 5)
      or pick(levelEntry, 5)
      or pick(zoneEntry, 3)
    if picked then
      correction = picked
    end
  end

  return ProfileRound(self, buffed * groupRatio * correction)
end

function XPTooltip:KillsToLevel(remaining, killXP, pool)
  if not remaining or remaining <= 0 or not killXP or killXP <= 0 then
    return 0
  end
  if not pool or pool <= 0 then
    return math.ceil(remaining / killXP)
  end

  local kills = 0
  while remaining > 0 and kills < 100000 do
    local bonus = min(killXP, floor(pool / 2))
    remaining = remaining - (killXP + bonus)
    pool = max(0, pool - 2 * bonus)
    kills = kills + 1
  end
  return kills
end

function XPTooltip:RecordObservation(mob, info, rawBase, buffedXP, totalXP)
  if not mob or not info or not rawBase or rawBase <= 0 then
    return
  end
  local profile = GetProfile(self)
  if not profile or not profile:Supports("hasXPFormula")
    or not profile:Supports("hasPerMobXP") or not profile:Supports("hasObservedXP") then
    return
  end
  local playerLevel = info.playerLevel or self:GetPlayerLevel()
  local mobLevel = info.level
  if not playerLevel or not mobLevel then
    return
  end

  local classification = info.classification or mob.classification or "normal"
  local formula = ProfileFormula(self, playerLevel, mobLevel, classification)
  if not formula or formula <= 0 then
    return
  end

  local contextKey = info.contextKey or ContextKey(
    playerLevel, mobLevel, info.groupSize or 1, info.mapID or 0, classification, info.buffSignature or "none"
  )
  local context = mob.contexts[contextKey]
  if type(context) ~= "table" then
    context = {
      playerLevel = playerLevel,
      mobLevel = mobLevel,
      groupSize = info.groupSize or 1,
      mapID = info.mapID or 0,
      classification = classification,
      buffSig = info.buffSignature or "none",
      samples = 0,
      sumBase = 0,
      sumBuffed = 0,
      sumTotal = 0,
      minBase = 0,
      maxBase = 0,
      lastSeen = 0,
    }
    mob.contexts[contextKey] = context
  end

  context.samples = (context.samples or 0) + 1
  context.sumBase = (context.sumBase or 0) + rawBase
  context.sumBuffed = (context.sumBuffed or 0) + (buffedXP or rawBase)
  context.sumTotal = (context.sumTotal or 0) + (totalXP or buffedXP or rawBase)
  context.lastSeen = Epoch()
  if context.minBase == 0 or rawBase < context.minBase then
    context.minBase = rawBase
  end
  if rawBase > (context.maxBase or 0) then
    context.maxBase = rawBase
  end

  local xp = mob.xp
  if type(xp) ~= "table" then
    xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 }
    mob.xp = xp
  end
  xp.samples = (xp.samples or 0) + 1
  xp.sumBase = (xp.sumBase or 0) + rawBase
  xp.sumBuffed = (xp.sumBuffed or 0) + (buffedXP or rawBase)
  xp.sumTotal = (xp.sumTotal or 0) + (totalXP or buffedXP or rawBase)
  xp.lastBase = rawBase
  xp.lastTotal = totalXP or buffedXP or rawBase
  if xp.minBase == 0 or rawBase < xp.minBase then
    xp.minBase = rawBase
  end
  if rawBase > (xp.maxBase or 0) then
    xp.maxBase = rawBase
  end

  local calibration = self.char.calibration
  local mapID = info.mapID or 0

  if info.groupSize and info.groupSize > 1 then
    -- Group observations are disabled until the live chat amount is verified.
    return
  end

  -- Each key stores the same observed/formula ratio. The estimator picks ONE
  -- correction by specificity (mob > class > level > zone), so the ratios are
  -- never multiplied together and cannot over-correct the same observation.
  local ratio = rawBase / formula
  if mapID and mapID > 0 then
    self:UpdateRatio(calibration.zones, tostring(mapID), ratio)
  end
  self:UpdateRatio(calibration.levels, tostring(playerLevel), ratio)
  self:UpdateRatio(calibration.classes, classification, ratio)
  self:UpdateRatio(calibration.mobs, info.mobKey or self:GetMobKey(info.name, info.npcID), ratio)
end

function XPTooltip:ResetObservations()
  local db = self.char
  if not db then
    return
  end
  self:InvalidatePendingWork("reset observations", false)
  for _, mob in pairs(db.mobs) do
    if type(mob) == "table" then
      mob.contexts = {}
      mob.xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 }
    end
  end
  db.calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} }
  db.calibrationVersion = CALIBRATION_VERSION
  AceM2L2:SafePrint("Kill Story observations reset.")
  self:RefreshUI()
end

function XPTooltip:ResetCalibration()
  local db = self.char
  if not db then
    return
  end
  self:InvalidatePendingWork("reset calibration", false)
  -- Aggregate calibration only; exact per-mob observations are cleared by
  -- ResetObservations, not by recalibrate.
  db.calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} }
  db.calibrationVersion = CALIBRATION_VERSION
  AceM2L2:SafePrint("Kill Story calibration reset (observations kept).")
  self:RefreshUI()
end
