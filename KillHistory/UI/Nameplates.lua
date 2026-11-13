--[[---------------------------------------------------------------------------------
  KillHistory/UI/Nameplates.lua
  Optional level text above nameplates.

  Every C_NamePlate call is resolved at call time and guarded so a missing API,
  a secret token, or a recycled plate cannot raise an error. Nameplate sightings
  still reach CaptureUnit when the text setting is off, because respawn tracking
  uses the same event path.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local Util = XPTooltip.Util

local SafeCall = Util.SafeCall
local SafeNumber = Util.SafeNumber
local SafeString = Util.SafeString
local IsSecret = Util.IsSecret

local floor = math.floor

--[[--------------------------------------------------------------------------------
  Internal helpers
------------------------------------------------------------------------------------]]

local function GetNamePlateAPI(name)
  local namePlate = C_NamePlate
  if type(namePlate) ~= "table" or IsSecret(namePlate) then
    return nil
  end
  local fn = namePlate[name]
  if type(fn) ~= "function" then
    return nil
  end
  return fn
end

local function ResolveNamePlate(unit)
  local getFrame = GetNamePlateAPI("GetNamePlateForUnit")
  if not getFrame then
    return nil
  end
  local frame = SafeCall(getFrame, unit)
  if type(frame) ~= "table" or IsSecret(frame) then
    return nil
  end
  local unitFrame = frame.UnitFrame
  if type(unitFrame) ~= "table" or IsSecret(unitFrame) then
    unitFrame = frame
  end
  return frame, unitFrame
end

local function GetNamePlates()
  local getPlates = GetNamePlateAPI("GetNamePlates")
  if not getPlates then
    return nil
  end
  local plates = SafeCall(getPlates)
  if type(plates) ~= "table" or IsSecret(plates) then
    return nil
  end
  return plates
end

local function ShouldShowLevels(self)
  if type(self.GetSettings) ~= "function" then
    return false
  end
  local ok, settings = pcall(self.GetSettings, self)
  if not ok or type(settings) ~= "table" then
    return false
  end
  return settings.showNameplateLevel and true or false
end

local function HideLevelText(frame)
  if type(frame) ~= "table" or IsSecret(frame) then
    return
  end
  local text = frame.xpTooltipLevel
  if type(text) ~= "table" or IsSecret(text) then
    return
  end
  if type(text.Hide) == "function" then
    SafeCall(text.Hide, text)
  end
end

local function TrackFrame(self, frame)
  local tracked = self.nameplateLevelFrames
  if type(tracked) ~= "table" or IsSecret(tracked) then
    tracked = setmetatable({}, { __mode = "k" })
    self.nameplateLevelFrames = tracked
  end
  tracked[frame] = true
end

local function GetOrCreateLevelText(self, frame, unitFrame)
  local text = frame.xpTooltipLevel
  if type(text) == "table" and not IsSecret(text)
    and type(text.SetText) == "function"
    and type(text.Show) == "function" then
    TrackFrame(self, frame)
    return text
  end

  local create = unitFrame.CreateFontString
  if type(create) ~= "function" then
    return nil
  end
  local created = SafeCall(create, unitFrame, nil, "OVERLAY", "GameFontNormalSmall")
  if type(created) ~= "table" or IsSecret(created) then
    return nil
  end
  if type(created.SetPoint) ~= "function"
    or type(created.SetText) ~= "function"
    or type(created.Show) ~= "function" then
    return nil
  end

  frame.xpTooltipLevel = created
  SafeCall(created.SetPoint, created, "BOTTOM", unitFrame, "TOP", 0, 2)
  TrackFrame(self, frame)
  return created
end

--[[--------------------------------------------------------------------------------
  Nameplate hooks
------------------------------------------------------------------------------------]]

function XPTooltip:HandleNamePlate(unit)
  if not self:IsActive() then
    return
  end
  if not self.namePlateEventAvailable then
    return
  end
  local token = SafeString(unit)
  if not token or token == "" then
    return
  end

  -- Sightings feed respawn tracking even when the optional text is disabled.
  if type(self.CaptureUnit) == "function" then
    SafeCall(self.CaptureUnit, self, token)
  end

  if not ShouldShowLevels(self) then
    return
  end

  local frame, unitFrame = ResolveNamePlate(token)
  if not frame then
    return
  end

  -- Replace whatever a previous unit or session left above this plate.
  HideLevelText(frame)

  if not self:IsUnitEligible(token) then
    return
  end

  local level = SafeNumber(SafeCall(UnitLevel, token))
  local value
  if level == -1 then
    value = "??"
  elseif level and level > 0 then
    value = "L" .. tostring(floor(level))
  else
    return
  end

  local text = GetOrCreateLevelText(self, frame, unitFrame)
  if not text then
    return
  end
  SafeCall(text.SetText, text, value)
  SafeCall(text.Show, text)
end

function XPTooltip:HideNamePlateLevel(unit)
  local token = SafeString(unit)
  if not token or token == "" then
    return
  end
  local frame = ResolveNamePlate(token)
  if frame then
    HideLevelText(frame)
  end
end

function XPTooltip:RefreshNameplateLevels()
  if not ShouldShowLevels(self) then
    self:ClearNameplateLevels()
    return
  end

  local plates = GetNamePlates()
  if not plates then
    return
  end

  for _, frame in ipairs(plates) do
    if type(frame) == "table" and not IsSecret(frame) then
      local token = SafeString(frame.namePlateUnitToken)
      if token and token ~= "" then
        self:HandleNamePlate(token)
      end
    end
  end
end

function XPTooltip:ClearNameplateLevels()
  local plates = GetNamePlates()
  if plates then
    for _, frame in ipairs(plates) do
      HideLevelText(frame)
    end
  end

  -- Keep hiding frames that were touched before an API removal or frame recycle.
  local tracked = self.nameplateLevelFrames
  if type(tracked) == "table" and not IsSecret(tracked) then
    for frame in pairs(tracked) do
      HideLevelText(frame)
    end
  end
end
