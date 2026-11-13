-- Offline smoke test for the AceM2L2 XPTooltip module.
-- This is not a WoW client; it only catches Lua/nil-method regressions.
--
-- Usage:
--   lua tests/xptooltip_smoke.lua [forever|midnight|midnight_missing|
--                                 midnight_secret_identity|
--                                 midnight_secret_booleans|unknown]
--
-- Each scenario runs in its own process so project IDs, globals, and saved
-- variables cannot leak between clients.

local SCENARIO = (arg and arg[1]) or os.getenv("XPT_SCENARIO") or "forever"

local SCENARIOS = {
  forever = {
    projectID = 18, build = "1.60.1", interface = 16001, maxLevel = 60,
  },
  midnight = {
    projectID = 1, build = "12.1.5", interface = 120105, maxLevel = 90,
  },
  midnight_missing = {
    projectID = 1, build = "12.1.5", interface = 120105, maxLevel = 90,
    missingXP = true, missingTooltip = true,
  },
  midnight_secret_identity = {
    projectID = 1, build = "12.1.5", interface = 120105, maxLevel = 90,
    secretIdentity = true,
  },
  midnight_secret_booleans = {
    projectID = 1, build = "12.1.5", interface = 120105, maxLevel = 90,
    secretBooleans = true,
  },
  midnight_secret_name = {
    projectID = 1, build = "12.1.5", interface = 120105, maxLevel = 90,
    secretName = true,
  },
  unknown = {
    projectID = 99, build = "0.0.0", interface = 0, maxLevel = 60,
  },
}

local config = SCENARIOS[SCENARIO]
if not config then
  error("unknown smoke scenario: " .. tostring(SCENARIO))
end

WOW_PROJECT_CAMELOT = 18
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_ID = config.projectID

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

function issecretvalue(value)
  return value == SECRET
end

local state = {
  xp = 0,
  xpMax = 7600,
  playerLevel = 10,
  targetLevel = 10,
  targetDead = false,
  pool = 0,
  now = 1000,
  mapID = 12,
  groupSize = 1,
  tapped = false,
  critter = false,
  inInstance = false,
  instanceType = nil,
  mapX = 0.5,
  mapY = 0.5,
  money = 0,
}

state.targetName = "Defias Pillager"
state.targetGUID = "Creature-0-1-2-3-1234-00000001"
state.mouseoverName = nil
state.mouseoverGUID = nil
state.targetClassification = "normal"
state.className = "Mage"
state.classFile = "MAGE"
state.targetIsPlayer = false
state.targetControlled = false
state.targetCanAttack = true
state.mouseoverIsPlayer = false
state.mouseoverControlled = false
state.mouseoverCanAttack = true

local DEFAULT_CREATURE_GUID = "Creature-0-1-2-3-1234-00000001"

local function SetTarget(name, guid, level, classification)
  state.targetName = name or "Defias Pillager"
  state.targetGUID = guid or DEFAULT_CREATURE_GUID
  state.targetLevel = level or 10
  state.targetClassification = classification or "normal"
end

local function SetMouseover(name, guid, level, classification)
  state.mouseoverName = name
  state.mouseoverGUID = guid
  state.mouseoverLevel = level
  state.mouseoverClassification = classification
end

local function SetTargetFlags(flags)
  flags = flags or {}
  state.targetIsPlayer = flags.isPlayer == true
  state.targetControlled = flags.controlled == true
  state.targetCanAttack = flags.canAttack ~= false
end

local function SetMouseoverFlags(flags)
  flags = flags or {}
  state.mouseoverIsPlayer = flags.isPlayer == true
  state.mouseoverControlled = flags.controlled == true
  state.mouseoverCanAttack = flags.canAttack ~= false
end

local timers = {}
local nextTimerID = 0
C_Timer = {
  After = function(delay, fn)
    nextTimerID = nextTimerID + 1
    timers[#timers + 1] = {
      runAt = state.now + (tonumber(delay) or 0),
      id = nextTimerID,
      fn = fn,
    }
  end,
}

local function SortTimers()
  table.sort(timers, function(a, b)
    if a.runAt == b.runAt then
      return a.id < b.id
    end
    return a.runAt < b.runAt
  end)
end

-- Existing tests use this to run every queued callback immediately. It must
-- not advance the clock.
local function RunTimers()
  SortTimers()
  local pending = timers
  timers = {}
  for _, timer in ipairs(pending) do
    timer.fn()
  end
end

-- Run timers due within `delta` seconds, invoking each callback with the clock
-- set to that timer's own runAt. This lets callbacks read Now() accurately.
local function AdvanceTime(delta)
  local target = state.now + (tonumber(delta) or 0)
  SortTimers()
  while true do
    local index
    for i, timer in ipairs(timers) do
      if timer.runAt <= target then
        index = i
        break
      end
    end
    if not index then
      break
    end
    local timer = table.remove(timers, index)
    state.now = timer.runAt
    timer.fn()
  end
  state.now = target
  SortTimers()
end


function GetTime()
  return state.now
end

function time()
  return 1760000000 + state.now
end

date = os.date

function GetBuildInfo()
  return config.build, config.build, "Nov 4 2026", config.interface
end

function UnitXP(unit)
  if config.missingXP then
    return nil
  end
  return state.xp
end

function UnitXPMax(unit)
  if config.missingXP then
    return nil
  end
  return state.xpMax
end

function UnitLevel(unit)
  if unit == "player" then
    return state.playerLevel
  end
  if unit == "mouseover" then
    return state.mouseoverLevel or state.targetLevel
  end
  return state.targetLevel
end

function UnitName(unit)
  if unit == "player" then
    return "Tester"
  end
  if config.secretIdentity or config.secretName then
    return SECRET
  end
  if unit == "mouseover" then
    return state.mouseoverName or state.targetName
  end
  return state.targetName or "Defias Pillager", nil
end

function UnitGUID(unit)
  if unit == "player" then
    return "Player-1-00000001"
  end
  if config.secretIdentity then
    return SECRET
  end
  if unit == "mouseover" then
    return state.mouseoverGUID or state.targetGUID
  end
  return state.targetGUID or DEFAULT_CREATURE_GUID
end

function UnitClassification(unit)
  if unit == "mouseover" then
    return state.mouseoverClassification or state.targetClassification or "normal"
  end
  return state.targetClassification or "normal"
end

function UnitClass(unit)
  return state.className or "Mage", state.classFile or "MAGE"
end

RAID_CLASS_COLORS = {
  MAGE = { r = 0.25, g = 0.55, b = 0.95 },
}

function UnitCreatureType(unit)
  return "Humanoid", 7
end

function UnitExists(unit)
  return unit == "player" or unit == "target" or unit == "mouseover"
end

function UnitIsPlayer(unit)
  if unit == "player" then
    return true
  end
  if config.secretBooleans then
    return SECRET
  end
  if unit == "mouseover" then
    return state.mouseoverIsPlayer == true
  end
  return state.targetIsPlayer == true
end

function UnitIsDead(unit)
  if config.secretBooleans then
    return SECRET
  end
  if unit == "target" then
    return state.targetDead
  end
  return false
end

function UnitPlayerControlled(unit)
  if config.secretBooleans then
    return SECRET
  end
  if unit == "mouseover" then
    return state.mouseoverControlled == true
  end
  return state.targetControlled == true
end

function UnitIsTapDenied(unit)
  if config.secretBooleans then
    return SECRET
  end
  return state.tapped and unit == "target"
end

function UnitIsCritter(unit)
  if config.secretBooleans then
    return SECRET
  end
  return state.critter and unit == "target"
end

function UnitCanAttack(a, b)
  if config.secretBooleans then
    return SECRET
  end
  if b == "mouseover" then
    return state.mouseoverCanAttack ~= false
  end
  if b == "target" then
    return state.targetCanAttack ~= false
  end
  return false
end

function GetXPExhaustion()
  if config.missingXP then
    return nil
  end
  return state.pool
end

function GetMaxPlayerLevel()
  return config.maxLevel
end

function IsXPUserDisabled()
  return false
end

function IsInGroup()
  return false
end

function GetNumGroupMembers()
  return state.groupSize or 1
end

function IsInInstance()
  return state.inInstance == true, state.instanceType
end

function GetMoney()
  return state.money or 0
end

function UnitStat(unit, statIndex)
  if unit ~= "player" then
    return 0
  end
  if statIndex == 1 then
    return 100
  elseif statIndex == 2 then
    return 50
  elseif statIndex == 4 then
    return 25
  end
  return 0
end

function GetInventoryItemLink(unit, slot)
  return nil
end

function GetItemStats(link)
  return {}
end

function GetItemInfo(item)
  local id = tonumber(item) or 0
  return "Test Item",
    "|cff9d9d9d|Hitem:" .. tostring(id) .. "::::::::|h[Test Item]|h|r",
    1, 0, 0, "", "", 20, "", "Interface\\Icons\\INV_Misc_QuestionMark", 250
end

C_Map = {
  GetBestMapForUnit = function(unit)
    return state.mapID
  end,
  GetPlayerMapPosition = function(mapID, unit)
    return {
      GetXY = function()
        return state.mapX, state.mapY
      end,
    }
  end,
  GetMapInfo = function(mapID)
    if tonumber(mapID) == 12 then
      return { name = "Westfall", mapID = 12 }
    end
    return { name = "Map " .. tostring(mapID), mapID = mapID }
  end,
}

C_NamePlate = {
  GetNamePlateForUnit = function(unit)
    return nil
  end,
  GetNamePlates = function()
    return {}
  end,
}


AuraUtil = {
  FindAuraByName = function()
    return nil
  end,
}

_G.COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
_G.COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience."
_G.COMBATLOG_XPGAIN_EXPLORATION = "You have discovered %s. You gain %d experience."
_G.COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = "%s dies, you gain %d experience. (+%d group bonus)"
_G.COMBATLOG_XPGAIN_EXHAUSTION1_GROUP = "%s dies, you gain %0.2f experience."
_G.COMBATLOG_XPGAIN_QUEST = "You gain %d experience."

-- Generic UI object mock -------------------------------------------------------

local function NewObject(kind, name)
  local obj = {
    kind = kind,
    name = name,
    shown = true,
    scripts = {},
    width = 0,
    height = 0,
    text = "",
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
  }

  function obj:SetSize(width, height)
    self.width = width
    self.height = height
  end

  function obj:SetWidth(width) self.width = width end
  function obj:SetHeight(height) self.height = height end
  function obj:GetWidth() return self.width end
  function obj:GetHeight() return self.height end

  function obj:SetPoint(point, relativeTo, relativePoint, x, y)
    self.point = point
    self.relativePoint = relativePoint or point
    self.x = x or 0
    self.y = y or 0
  end

  function obj:GetPoint(index)
    return self.point, nil, self.relativePoint, self.x, self.y
  end

  function obj:ClearAllPoints() end
  function obj:SetFrameStrata() end
  function obj:SetClampedToScreen() end
  function obj:SetMovable() end
  function obj:EnableMouse() end
  function obj:RegisterForDrag() end
  function obj:SetAllPoints() end
  function obj:SetBackdrop() end
  function obj:SetBackdropColor() end
  function obj:SetBackdropBorderColor() end
  function obj:SetColorTexture() end
  function obj:SetTexture() end
  function obj:SetJustifyH() end
  function obj:SetJustifyV() end
  function obj:SetWordWrap() end
  function obj:SetTextColor() end
  function obj:SetScale() end
  function obj:SetShown(shown) if shown then self:Show() else self:Hide() end end
  function obj:SetAutoFocus() end
  function obj:SetMaxLetters() end
  function obj:SetTextInsets() end
  function obj:SetFontObject() end
  function obj:ClearFocus() end
  function obj:GetText() return self.text or "" end
  function obj:SetButtonState(state) self.buttonState = state end
  function obj:SetScrollChild(child) self.scrollChild = child end
  function obj:GetVerticalScroll() return 0 end
  function obj:SetVerticalScroll() end
  function obj:UpdateScrollChildRect() end
  function obj:StartMoving() end
  function obj:StopMovingOrSizing() end
  function obj:Raise() end
  function obj:EnableKeyboard() end
  function obj:SetPropagateKeyboardInput() end

  function obj:SetScript(event, fn)
    self.scripts[event] = fn
  end

  function obj:Show()
    self.shown = true
    if self.scripts.OnShow then
      self.scripts.OnShow(self)
    end
  end

  function obj:Hide()
    self.shown = false
    if self.scripts.OnHide then
      self.scripts.OnHide(self)
    end
  end

  function obj:IsShown()
    return self.shown
  end

  function obj:GetName()
    return self.name
  end

  function obj:SetText(text)
    self.text = text or ""
  end

  function obj:CreateFontString()
    local font = NewObject("FontString")
    function font:SetText(value) self.text = value or "" end
    return font
  end

  function obj:CreateTexture()
    local texture = NewObject("Texture")
    function texture:SetTexture(value) self.texture = value end
    function texture:SetColorTexture(...) self.color = { ... } end
    return texture
  end

  if kind == "ScrollFrame" then
    function obj:SetScrollChild(child) self.scrollChild = child end
    function obj:GetVerticalScroll() return self.offset or 0 end
    function obj:SetVerticalScroll(offset) self.offset = offset end
    function obj:UpdateScrollChildRect() end
  end

  if kind == "PlayerModel" then
    function obj:SetCreature(creatureID)
      self.creatureID = creatureID
    end
    function obj:SetRotation(value) self.rotation = value end
    function obj:SetCamDistanceScale(value) self.camDistance = value end
    function obj:SetAnimation(value) self.animation = value end
  end

  return obj
end

UIParent = NewObject("Frame", "UIParent")
UISpecialFrames = {}
DEFAULT_CHAT_FRAME = {
  messages = {},
  AddMessage = function(self, message)
    self.messages[#self.messages + 1] = tostring(message)
  end,
}

local function CreateFrameMock(frameType, name, parent, template)
  local object = NewObject(frameType, name)
  object.parent = parent
  object.template = template
  if template == "UIPanelButtonTemplate" or template == "UIPanelCloseButton" then
    function object:SetText(text) self.text = text or "" end
    function object:SetButtonState(state) self.buttonState = state end
  elseif template == "UIPanelScrollFrameTemplate" then
    function object:SetScrollChild(child) self.scrollChild = child end
    function object:GetVerticalScroll() return self.offset or 0 end
    function object:SetVerticalScroll(offset) self.offset = offset end
    function object:UpdateScrollChildRect() end
  end
  return object
end

CreateFrame = CreateFrameMock

GameTooltip = NewObject("GameTooltip", "GameTooltip")
GameTooltip.lines = {}
GameTooltip.hooks = {}
GameTooltip.unitName = "Defias Pillager"
GameTooltip.unitToken = "target"

function GameTooltip:HookScript(event, fn)
  self.hooks[event] = fn
end

function GameTooltip:GetUnit()
  return self.unitName, self.unitToken
end

function GameTooltip:AddDoubleLine(left, right)
  self.lines[#self.lines + 1] = tostring(left) .. " " .. tostring(right)
end

function GameTooltip:AddLine(text)
  self.lines[#self.lines + 1] = tostring(text)
end

function GameTooltip:ClearLines()
  self.lines = {}
end

if config.missingTooltip then
  GameTooltip.HookScript = nil
  TooltipDataProcessor = nil
  Enum = nil
end

-- Ace3 mock -------------------------------------------------------------------

local AceAddonProto = {}

function AceAddonProto:NewAddon(name)
  local addon = {
    name = name,
    modules = {},
    events = {},
    chatCommands = {},
  }
  setmetatable(addon, { __index = AceAddonProto })

  function addon:RegisterChatCommand(command, method)
    self.chatCommands[command] = method
  end
  function addon:IsEnabled() return true end
  function addon:Print(...) print("[AceM2L2]", ...) end

  function addon:RegisterEvent(event)
    self.events[event] = true
  end

  function addon:UnregisterEvent(event)
    self.events[event] = nil
  end

  function addon:UnregisterAllEvents()
    self.events = {}
  end

  function addon:GetModule(moduleName)
    return self.modules[moduleName]
  end

  function addon:NewModule(moduleName)
    local module = {
      name = moduleName,
      events = {},
    }
    setmetatable(module, { __index = AceAddonProto })

    function module:IsEnabled() return true end
    function module:RegisterEvent(event, method)
      self.events[event] = method
    end

    function module:UnregisterEvent(event)
      self.events[event] = nil
    end

    function module:UnregisterAllEvents()
      self.events = {}
    end

    self.modules[moduleName] = module
    return module
  end

  return addon
end

local minimapMock = {
  registered = false,
  hidden = false,
  name = nil,
}
local ldbMock = {
  NewDataObject = function(_, name, object)
    return object
  end,
}
local dbiconMock = {
  Register = function(self, name, object, db)
    self.name = name
    self.object = object
    self.db = db
    self.registered = true
    minimapMock.registered = true
    minimapMock.name = name
  end,
  Show = function(self, name)
    self.hidden = false
    minimapMock.hidden = false
  end,
  Hide = function(self, name)
    self.hidden = true
    minimapMock.hidden = true
  end,
  Refresh = function(self, name, db)
    self.db = db
    minimapMock.refreshed = true
  end,
}

function LibStub(name)
  if name == "LibDataBroker-1.1" then
    return ldbMock
  end
  if name == "LibDBIcon-1.0" then
    return dbiconMock
  end
  return {
    NewAddon = function(_, addonName)
      return AceAddonProto:NewAddon(addonName)
    end,
  }
end

-- Load the addon --------------------------------------------------------------

AceM2L2DB = {}
AceM2L2CharDB = {}

local function LoadAddonFromToc()
  local toc = assert(io.open("AceM2L2.toc", "r"))
  for line in toc:lines() do
    line = line:gsub("\r$", "")
    if line ~= "" and not line:match("^#") and line:match("%.lua$") then
      dofile((line:gsub("\\", "/")))
    end
  end
  toc:close()
end

local function Init()
  LoadAddonFromToc()
  AceM2L2:OnInitialize()
  AceM2L2:OnEnable()
  local module = AceM2L2:GetModule("XPTooltip")
  assert(module, "XPTooltip module was not created")
  module:OnInitialize()
  module:OnEnable()
  return module
end

return {
  SCENARIO = SCENARIO,
  config = config,
  state = state,
  Init = Init,
  LoadAddonFromToc = LoadAddonFromToc,
  SetTarget = SetTarget,
  SetTargetFlags = SetTargetFlags,
  SetMouseover = SetMouseover,
  SetMouseoverFlags = SetMouseoverFlags,
  RunTimers = RunTimers,
  AdvanceTime = AdvanceTime,
  GameTooltip = GameTooltip,
  DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME,
  minimapMock = minimapMock,
  defaultCreatureGUID = DEFAULT_CREATURE_GUID,
}
