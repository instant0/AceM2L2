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
}

state.targetName = "Defias Pillager"
state.targetGUID = "Creature-0-1-2-3-1234-00000001"
state.mouseoverName = nil
state.mouseoverGUID = nil
state.targetClassification = "normal"

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
  return false
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
  return false
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
  return b == "target"
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

C_Map = {
  GetBestMapForUnit = function(unit)
    return state.mapID
  end,
  GetMapInfo = function(mapID)
    if tonumber(mapID) == 12 then
      return { name = "Westfall", mapID = 12 }
    end
    return { name = "Map " .. tostring(mapID), mapID = mapID }
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

LoadAddonFromToc()

AceM2L2:OnInitialize()
AceM2L2:OnEnable()
assert(AceM2L2.chatCommands["acem2l2"], "acem2l2 chat command was not registered")
assert(AceM2L2.chatCommands["am2"], "am2 chat alias was not registered")
assert(AceM2L2.events["CHAT_MSG_COMBAT_XP_GAIN"], "core XP event was not registered")
assert(AceM2L2.events["PLAYER_XP_UPDATE"], "core XP update event was not registered")
assert(AceM2L2.events["FACTION_STANDING_CHANGED"], "core reputation event was not registered")

local module = AceM2L2:GetModule("XPTooltip")
assert(module, "module was not created")

module:OnInitialize()
module:OnEnable()

if SCENARIO == "forever" then
assert(module:IsActive(), "module should be active on Forever")
assert(module:GetSettings().theme == "aether", "default theme should be aether")
assert(AceM2L2CharDB.xpTooltip.storageSchema == 2, "storage schema was not migrated")
assert(AceM2L2CharDB.xpTooltip.clients[18] == module.char, "Forever data is not in clients[18]")

-- Legacy dark default migrates to Aether Blue once, explicit dark later sticks.
AceM2L2DB.profile.xpTooltip.theme = "dark"
AceM2L2DB.profile.xpTooltip.aetherThemeMigration = nil
AceM2L2:SanitizeXPTooltipSettings()
assert(AceM2L2DB.profile.xpTooltip.theme == "aether", "legacy dark theme did not migrate")
AceM2L2DB.profile.xpTooltip.theme = "dark"
AceM2L2:SanitizeXPTooltipSettings()
assert(AceM2L2DB.profile.xpTooltip.theme == "dark", "explicit dark theme was overwritten")
AceM2L2DB.profile.xpTooltip.theme = "aether"
AceM2L2:SanitizeXPTooltipSettings()
assert(minimapMock.registered, "minimap icon did not register")
assert(minimapMock.name == "AceM2L2", "minimap data object name mismatch")

assert(AceM2L2:ParseXPMessage("You have discovered Westfall. You gain 100 experience.") == nil,
  "exploration XP must not parse as a kill")
AceM2L2:HandleXPText("You have discovered Westfall. You gain 100 experience.")
assert(AceM2L2.lastXPSource == nil, "exploration XP must not set a kill source")

local savedXPValue = state.xp
local savedLastXP = AceM2L2.lastXP
AceM2L2.xpSamples = {}
AceM2L2.lastXP = savedXPValue
AceM2L2.lastXPInfoTime = 0
state.xp = savedXPValue + 100
AceM2L2:HandlePlayerXPUpdate()
assert(#AceM2L2.xpSamples == 0, "unknown XP source entered the rolling average")
state.xp = savedXPValue
AceM2L2.lastXP = savedLastXP

local groupName, groupTotal = AceM2L2:ParseXPMessage(
  "Defias Pillager dies, you gain 22 experience. (+2 group bonus)")
assert(groupName == "Defias Pillager" and groupTotal == 22,
  "group XP should use the first amount, not the sum")
local precisionName, precisionTotal = AceM2L2:ParseXPMessage(
  "Defias Pillager dies, you gain 95.50 experience.")
assert(precisionName == "Defias Pillager" and precisionTotal and math.abs(precisionTotal - 95.5) < 0.001,
  "width/precision XP format failed")

module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")

local db = module.char
local mob = db.mobs["npc:1234"]
assert(mob, "mob was not recorded")
assert(mob.kills == 1, "expected 1 kill, got " .. tostring(mob.kills))
assert(db.totals.kills == 1, "expected 1 total kill")
assert(db.areas["12"] == 1, "expected 1 kill in map 12")
assert(db.levels["10"] == 1, "expected 1 kill at level 10")
assert(mob.killsByMap["12"] == 1, "expected 1 kill in mob map 12")
assert(mob.killsAtLevel["10"] == 1, "expected 1 kill in mob level 10")

-- Tooltip
GameTooltip.lines = {}
module:AddTooltipLines(GameTooltip, nil)
assert(#GameTooltip.lines > 0, "tooltip lines were not added")
local tooltipText = table.concat(GameTooltip.lines, "\n")
assert(tooltipText:find("XP:", 1, true), "tooltip missing XP line: " .. tooltipText)
assert(tooltipText:find("Kills to level:", 1, true), "tooltip missing kills line: " .. tooltipText)
assert(tooltipText:find("Killed:", 1, true), "tooltip missing kill count: " .. tooltipText)
assert(not tooltipText:find("~95", 1, true), "exact observation should not use a tilde: " .. tooltipText)

-- Group tooltip must show the player's share and the solo comparison.
state.groupSize = 2
assert(module:GetGroupSize() == 2, "group size must come from GetNumGroupMembers")
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local groupTooltipText = table.concat(GameTooltip.lines, "\n")
assert(groupTooltipText:find("group share; solo", 1, true), "group tooltip missing share/solo: " .. groupTooltipText)
state.groupSize = 1
assert(module:GetGroupSize() == 1, "solo group size should be 1")

local savedTooltipSettings = module.settings
module.settings.showXP = false
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local hiddenXPText = table.concat(GameTooltip.lines, "\n")
assert(not hiddenXPText:find("XP:", 1, true), "showXP=false still rendered the XP line")
module.settings.showXP = true
module.settings.showPercent = false
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local noPercentText = table.concat(GameTooltip.lines, "\n")
assert(not noPercentText:find("% of level", 1, true), "showPercent=false still rendered the percent")
module.settings = savedTooltipSettings

-- Chat first, then death: must not double count.
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
RunTimers()
assert(mob.kills == 1, "chat+death double counted: " .. tostring(mob.kills))

-- Death first, then chat: must count exactly once.
module:ResetKills()
mob = nil
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
assert(#module.pendingDeaths == 1, "death was not queued")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
RunTimers()
db = module.char
mob = db.mobs["npc:1234"]
assert(mob and mob.kills == 1, "death+chat did not count exactly once")

-- Death commits first, late chat must not add a second kill.
module:ResetKills()
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
RunTimers()
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
RunTimers()
db = module.char
assert(db.mobs["npc:1234"] and db.mobs["npc:1234"].kills == 1, "committed death + late chat double counted")

-- P0-1: death -> chat -> second same-name death with a different GUID.
module:ResetKills()
local GUID_A = "Creature-0-1-2-3-1234-00000001"
local GUID_B = "Creature-0-1-2-3-1234-00000002"
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(0.5)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
SetTarget("Defias Pillager", GUID_B)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_B)
AdvanceTime(2.5)
db = module.char
mob = db.mobs["npc:1234"]
assert(mob and mob.kills == 2, "same-name different-GUID deaths were merged")
assert(mob.totalXP == 95, "same-name different-GUID XP mismatch")
assert((mob.xp.samples or 0) == 1, "same-name different-GUID sample mismatch")
assert(db.totals.kills == 2, "same-name different-GUID total mismatch")
assert(db.totals.xp == 95, "same-name different-GUID total XP mismatch")
assert(db.session.xp == 95, "same-name different-GUID session XP mismatch")

-- P0-1: duplicate UNIT_DIED for the same GUID must count once.
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
assert(module.char.totals.kills == 1, "duplicate UNIT_DIED counted twice")

-- P0-1: countZeroXPMobs=false must not lose a late chat.
local savedCountZero = module:GetSettings().countZeroXPMobs
module:GetSettings().countZeroXPMobs = false
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
assert(module.char.totals.kills == 0, "countZeroXPMobs=false counted a zero-XP death")
AdvanceTime(0.1)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
db = module.char
mob = db.mobs["npc:1234"]
assert(mob and mob.kills == 1, "late chat after countZeroXPMobs=false was lost")
assert(mob.totalXP == 95, "late chat XP after countZeroXPMobs=false was lost")

-- P0-1: a committed zero-XP death must accept late chat without a second kill.
module:GetSettings().countZeroXPMobs = true
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
db = module.char
mob = db.mobs["npc:1234"]
assert(mob and mob.kills == 1 and (mob.totalXP or 0) == 0, "zero-XP death did not commit")
AdvanceTime(0.6)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
db = module.char
mob = db.mobs["npc:1234"]
assert(mob.kills == 1, "late chat created a second kill")
assert(mob.totalXP == 95, "late chat XP was not added to the existing kill")
assert((mob.xp.samples or 0) == 1, "late chat observation was not recorded")
assert(db.totals.xp == 95, "late chat total XP mismatch")

-- P0-1: duplicate chat for a tombstone must not add XP twice.
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
AdvanceTime(0.6)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
db = module.char
mob = db.mobs["npc:1234"]
assert(mob.kills == 1, "duplicate tombstone chat changed the kill count")
assert(mob.totalXP == 95, "duplicate tombstone chat added XP twice")
assert((mob.xp.samples or 0) == 1, "duplicate tombstone chat added an extra sample")

-- P0-2: a late chat must not resurrect a deleted mob.
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
assert(module.char.totals.kills == 1, "delete tombstone setup did not count")
module:DeleteMobEntry("npc:1234")
AdvanceTime(0.1)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
assert(module.char.mobs["npc:1234"] == nil, "late chat resurrected a deleted mob")
assert(module.char.totals.kills == 0, "late chat re-added a deleted kill")

-- P0-2: disable/re-enable must cancel a pending death.
module:GetSettings().countZeroXPMobs = true
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
module:SetUserEnabled(false)
module:SetUserEnabled(true)
AdvanceTime(5)
assert(module.char.totals.kills == 0, "pending death committed after re-enable")

-- P0-2: an active config refresh must not cancel legitimate pending work.
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
module:Refresh()
AdvanceTime(2.5)
assert(module.char.totals.kills == 1, "active refresh canceled pending death")

-- P0-2: the circuit breaker must cancel a pending death.
module:ResetKills()
SetTarget("Defias Pillager", GUID_A)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_A)
module.circuitErrors = 4
module.lastErrorTime = GetTime()
module:ReportError("test", "failure")
assert(module.autoDisabled, "circuit breaker did not auto-disable")
AdvanceTime(5)
assert(module.char.totals.kills == 0, "pending death committed after circuit breaker")
module.circuitErrors = 0
module:SetUserEnabled(true)
assert(module:IsActive(), "module did not recover after circuit breaker test")
module:GetSettings().countZeroXPMobs = savedCountZero

-- Exact GUID identity survives a long fight.
module:ResetKills()
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
assert(module.lastTarget, "target was not captured for long-fight test")
module.lastTarget.at = GetTime() - 120
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
RunTimers()
db = module.char
assert(db.mobs["npc:1234"] and db.mobs["npc:1234"].kills == 1, "long-fight GUID identity was lost")

-- Gray death with no XP chat: count after timer.
module:ResetKills()
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
RunTimers()
db = module.char
assert(db.mobs["npc:1234"] and db.mobs["npc:1234"].kills == 1, "zero-XP death was not counted")

-- Unnamed XP chat must wait for the death GUID instead of recording Unknown.
module:ResetKills()
module.pendingChatXP = {}
module.pendingDeaths = {}
module.lastMouseover = nil
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
assert(module.lastTarget, "target was not captured")
module.lastTarget.at = GetTime() - 10
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "You gain 55 experience.")
assert(#module.pendingChatXP == 1, "unnamed chat was not queued")
db = module.char
assert(next(db.mobs) == nil, "unnamed chat recorded before identity was known")
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
db = module.char
assert(not db.mobs["name:unknown"], "unnamed kill was recorded as Unknown")
assert(db.mobs["npc:1234"], "unnamed kill was not attributed to the NPC")
assert(db.mobs["npc:1234"].kills == 1, "unnamed kill count mismatch")
assert(db.mobs["npc:1234"].xp.samples == 1, "unnamed kill lost its XP sample")
RunTimers()
assert(db.mobs["npc:1234"].kills == 1, "unnamed kill counted twice")
assert(#module.pendingChatXP == 0, "consumed unnamed kill stayed queued")

-- Clearing target on death must keep the last valid identity for UNIT_DIED.
module:ResetKills()
module.lastTarget = nil
module.lastMouseover = nil
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
local retainedTarget = module.lastTarget
assert(retainedTarget, "target was not captured before clearing")
state.targetDead = true
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
state.targetDead = false
assert(module.lastTarget == retainedTarget, "last target identity was dropped on clear")
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
RunTimers()
db = module.char
assert(db.mobs["npc:1234"] and db.mobs["npc:1234"].kills == 1, "cleared target lost the death identity")

-- A pending death must not survive resetkills.
module:ResetKills()
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
assert(#module.pendingDeaths == 1, "death was not queued before reset")
module:ResetKills()
RunTimers()
assert(next(module.char.mobs) == nil, "pending death added a kill after reset")

-- Target info must be copied, not mutated in place.
module:ResetKills()
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
assert(module.lastTarget.playerLevel == nil, "target info was mutated by the observation")

-- Search and bars.
module:OpenUI()
module:SetTab("mobs")
module.searchText = "defias"
module:BuildList()
assert(#module.currentList == 1, "search did not find the mob")
assert(module.currentList[1].bar == 1, "top mob bar should be full width")
module:UpdateRows()
assert(module.rows[1].bar.width == module.rows[1]:GetWidth() - 8, "bar texture width was not applied")
module.searchText = "zzzz"
module:BuildList()
assert(#module.currentList == 0, "search should return no rows")
module.searchText = ""
module:BuildList()

-- Command smoke tests.
module:HandleCommand("stats")
module:HandleCommand("probe")
module:HandleCommand("dump")
module:HandleCommand("table")

-- Class calibration.
local calibration = module.char.calibration
calibration.classes.elite = { ratio = 1.1, samples = 5, updated = 0 }
local eliteEstimate = module:GetEstimate(10, 10, "elite", 12, 1, "npc:9999", "none")
assert(eliteEstimate > 190, "class calibration did not adjust elite XP")
calibration.classes.elite = nil

-- Single correction by specificity: mob > class > zone, never multiplied.
calibration.mobs["npc:9999"] = { ratio = 0.8, samples = 5, updated = 0 }
calibration.classes.normal = { ratio = 1.2, samples = 5, updated = 0 }
calibration.zones["12"] = { ratio = 1.1, samples = 5, updated = 0 }
local singleCorrection = module:GetEstimate(10, 10, "normal", 12, 1, "npc:9999", "none")
assert(singleCorrection == 86, "expected mob-only correction 86, got " .. tostring(singleCorrection))
calibration.mobs["npc:9999"] = nil
calibration.classes.normal = nil
calibration.zones["12"] = nil

-- Group calibration and prior.
local soloEstimate = module:GetEstimate(10, 10, "normal", 12, 1, "npc:9999", "none")
local groupEstimate = module:GetEstimate(10, 10, "normal", 12, 2, "npc:9999", "none")
assert(groupEstimate < soloEstimate, "group prior did not reduce XP")
calibration.groups["2"] = { ratio = 0.5, samples = 10, updated = 0 }
local ignoredGroup = module:GetEstimate(10, 10, "normal", 12, 2, "npc:9999", "none")
assert(ignoredGroup == groupEstimate, "group calibration should be disabled until verified")
calibration.groups["2"] = nil

-- UI creation and model selection.
module:OpenUI()
assert(module.ui, "UI was not created")
assert(module.ui:IsShown(), "UI was not shown")
assert(module.ui.model.creatureID == 1234, "model creature was not set")
module.ui.model:Show()
module.modelNPCID = nil
module:ShowModel(nil)
assert(not module.ui.model:IsShown(), "model should hide when the mob has no NPC ID")
assert(module.ui.modelFallback:IsShown(), "model fallback should show when the mob has no NPC ID")
assert(module.ui.modelFallback.text == "No model data", "model fallback text mismatch")
module:ShowModel(1234)
module:SetTab("overview")
assert(module.tab == "overview", "overview tab did not activate")
assert(module.tabs.overview.selected == true, "active tab not highlighted")
assert(module.tabs.mobs.selected == false, "inactive tab should not be highlighted")
assert(module.ui.overview.panel:IsShown(), "overview panel not shown")
assert(module.ui.overview.cards[1].value.text == "1", "overview total kills mismatch")
assert(module.ui.overview.topMobsText.text:find("Defias", 1, true), "overview top mobs missing")
module:SetTab("mobs")
module:SetFilter("elite")
module:BuildList()
assert(#module.currentList == 0, "elite filter should hide normal mobs")
assert(module.ui.filterButtons.elite.selected == true, "elite filter not highlighted")
assert(module.ui.filterButtons.all.selected == false, "all filter should not be highlighted")
module:SetFilter("all")
module:BuildList()
assert(#module.currentList >= 1, "all filter lost the mob")
assert(module.ui.filterButtons.all.selected == true, "all filter not highlighted")
module:SelectIndex(1)
assert(module.ui.heroName.text == "Defias Pillager", "mob hero name mismatch")
assert(module.ui.modelHolder.shown, "model holder should be visible on the mobs tab")
assert(module.ui.deleteButton.shown, "delete button should show for mob rows")
module:SetTab("areas")
module:SelectIndex(1)
assert(not module.ui.modelHolder.shown, "model holder should hide on areas")
assert(not module.ui.deleteButton.shown, "delete button should hide on areas")
assert(module.ui.heroName.text ~= "", "area hero name missing")
module:SetTab("levels")
module:SelectIndex(1)
assert(not module.ui.modelHolder.shown, "model holder should hide on levels")
assert(not module.ui.deleteButton.shown, "delete button should hide on levels")
assert(module.ui.heroName.text ~= "", "level hero name missing")
module:SetTab("mobs")
module:HandleCommand("theme midnight")
assert(module:GetSettings().theme == "midnight", "theme command failed")
module:HandleCommand("scale 90")
assert(math.abs(module:GetSettings().scale - 0.9) < 0.001, "scale command failed")
module:HandleCommand("minimap off")
assert(module:GetSettings().minimap.hide == true, "minimap off failed")
assert(minimapMock.hidden == true, "minimap icon did not hide")
module:HandleCommand("minimap on")
assert(module:GetSettings().minimap.hide == false, "minimap on failed")
assert(minimapMock.hidden == false, "minimap icon did not show")
module:SetTab("areas")
module:SetTab("levels")
module:CycleSort()
module:SelectIndex(1)
module:SetTab("mobs")
module:HandleCommand("areas")
module:HandleCommand("levels")
module:HandleCommand("session")
module:HandleCommand("kills")
module:HandleCommand("status")

-- Keybind/compartment toggle path.
assert(module.ui and module.ui:IsShown(), "UI should be open before toggle test")
AceM2L2_ToggleXPTooltip()
assert(not module.ui:IsShown(), "keybind toggle did not close the UI")
AceM2L2_ToggleXPTooltip()
assert(module.ui:IsShown(), "keybind toggle did not open the UI")

AceM2L2_OnCompartmentClick()
assert(not module.ui:IsShown(), "compartment click did not close the UI")
AceM2L2_OnCompartmentClick()
assert(module.ui:IsShown(), "compartment click did not open the UI")

-- Formula baseline (level 10 vs level 10 = 95).
local expectedXP = {
  [5] = 20, [6] = 32, [7] = 46, [8] = 61, [9] = 77,
  [10] = 95, [11] = 100, [12] = 104, [13] = 109, [14] = 114,
}
for mobLevel, expected in pairs(expectedXP) do
  local estimate = module:GetEstimate(10, mobLevel, "normal", 12, 1, "npc:9999", "none")
  assert(estimate == expected, string.format("level 10 vs %d expected %d, got %s", mobLevel, expected, tostring(estimate)))
end
assert(module:GetEstimate(10, 4, "normal", 12, 1, "npc:9999", "none") == 0, "gray mob should give 0")
assert(module:GetEstimate(10, 10, "elite", 12, 1, "npc:9999", "none") == 190, "elite should double")
assert(module:GetEstimate(11, 8, "normal", 12, 1, "npc:vampiric", "none") == 49, "level 11 vs 8 should be 49")
assert(module:GetEstimate(11, 9, "normal", 12, 1, "npc:friar", "none") == 64, "level 11 vs 9 should be 64")
for level = 1, 60 do
  local estimate = module:GetEstimate(level, level, "normal", 12, 1, "npc:leveltest", "none")
  assert(estimate and estimate > 0, "formula returned zero at level " .. tostring(level))
end

assert(module:KillsToLevel(7600, 95, 0) == 80, "unrested kills-to-level should be 80")
assert(module:KillsToLevel(7600, 95, 10000) == 40, "fully rested kills-to-level should be 40")
local buffMultiplier = module:GetBuffMultiplier(true, true)
assert(math.abs(buffMultiplier - 1.0815) < 0.0001, "Well Fed + Well-Rested should be 1.0815")
assert(math.abs(module:GetBuffMultiplier(true, true, 2) - 1.071) < 0.0001,
  "two Well-Rested stacks should use 2%")

local oldFindAura = AuraUtil.FindAuraByName
AuraUtil.FindAuraByName = function(name)
  if name == "Well Fed" then
    return { name = "Well Fed" }
  elseif name == "Well-Rested" then
    return { name = "Well-Rested", applications = 2 }
  end
end
module.buffCacheTime = 0
local testWellFed, testWellRested, _, testStacks = module:GetBuffInfo()
assert(testWellFed and testWellRested and testStacks == 2, "buff stack detection failed")
AuraUtil.FindAuraByName = oldFindAura
module.buffCacheTime = 0

-- XP update must not add a second kill.
local beforeXPUpdate = module.char.totals.kills
module:OnPlayerXPUpdate("PLAYER_XP_UPDATE")
assert(module.char.totals.kills == beforeXPUpdate, "XP update double counted")

-- TooltipDataProcessor hook path.
local processorHookInstalled = false
TooltipDataProcessor = {
  AddTooltipPostCall = function(_, dataType, callback)
    processorHookInstalled = true
    module.processorCallback = callback
  end,
}
Enum = { TooltipDataType = { Unit = 1 } }
module.tooltipHookInstalled = false
module.hasProcessor = true
module:InstallTooltipHook()
assert(processorHookInstalled, "TooltipDataProcessor hook was not installed")

-- User disable.
module:SetUserEnabled(false)
assert(not module:IsActive(), "module should be inactive after disable")
assert(module:GetStatusText() == "disabled by user", "unexpected status: " .. module:GetStatusText())
module:SetUserEnabled(true)
assert(module:IsActive(), "module should be active after re-enable")

-- Legacy inflated calibration must be cleared on load.
local legacy = module.char
legacy.calibrationVersion = nil
legacy.calibration.zones["12"] = { ratio = 1.6, samples = 10 }
module:EnsureDB()
assert(next(legacy.calibration.zones) == nil, "legacy calibration was not cleared")
assert(legacy.calibrationVersion == 2, "calibration version was not bumped")

-- Manual recalibration clears ratios but not kills.
legacy.calibration.zones["12"] = { ratio = 1.6, samples = 10 }
module:ResetCalibration()
assert(next(legacy.calibration.zones) == nil, "recalibrate did not clear ratios")
assert(legacy.calibrationVersion == 2, "recalibrate did not preserve calibration version")

legacy.mobs["npc:55556"] = {
  name = "Context Keep Test",
  kills = 1,
  sessionKills = 0,
  killsAtLevel = {},
  killsByMap = {},
  contexts = { ["test"] = { samples = 1 } },
  xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 },
  firstSeen = 1,
  lastSeen = 2,
  classification = "normal",
}
module:ResetCalibration()
assert(legacy.mobs["npc:55556"].contexts["test"], "recalibrate should keep exact contexts")
legacy.calibrationVersion = 1
module:EnsureDB()
assert(not legacy.mobs["npc:55556"].contexts["test"], "calibration version bump did not clear exact contexts")
legacy.mobs["npc:55556"] = nil

-- Name-only duplicates from early chat kills merge into the NPC entry.
local mergeDB = module.char
local npcKey = "npc:1234"
local mergedMob = mergeDB.mobs[npcKey]
assert(mergedMob, "expected NPC mob for merge test")
local killsBeforeMerge = tonumber(mergedMob.kills) or 0
mergeDB.mobs["name:defias pillager"] = {
  name = "Defias Pillager",
  kills = 3,
  sessionKills = 1,
  killsAtLevel = { ["10"] = 3 },
  killsByMap = { ["12"] = 3 },
  contexts = {},
  xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 },
  firstSeen = 1,
  lastSeen = 2,
  classification = "normal",
}
mergeDB.totals.uniqueMobs = (mergeDB.totals.uniqueMobs or 0) + 1
mergeDB.calibration.mobs["name:defias pillager"] = { ratio = 1.2, samples = 2, updated = 1 }
module:ConsolidateNameOnlyMobs()
assert(mergeDB.mobs["name:defias pillager"] == nil, "name-only mob was not consolidated")
assert((tonumber(mergedMob.kills) or 0) == killsBeforeMerge + 3, "merged kills were not added")
assert(module:GetMobKey("Defias Pillager") == npcKey, "name lookup did not resolve to the NPC key")
assert(mergeDB.calibration.mobs["name:defias pillager"] == nil, "name-only calibration key remained")
assert(type(mergeDB.calibration.mobs[npcKey]) == "table", "calibration key was not migrated")
module:SetTab("mobs")
module:SetFilter("all")
module:BuildList()
local defiasRows = 0
for _, item in ipairs(module.currentList) do
  if item.label == "Defias Pillager" then
    defiasRows = defiasRows + 1
    assert(item.value:find("kills", 1, true), "mob row should label the kill count")
  end
end
assert(defiasRows == 1, "duplicate Defias Pillager rows remained")

-- A late NPC-ID kill must fold an earlier name-only kill into one entry.
local ancestorBase = {
  name = "Wailing Ancestor",
  playerLevel = 10,
  level = 10,
  classification = "normal",
  groupSize = 1,
  mapID = 12,
  buffSignature = "none",
  contextKey = "10|10|1|12|normal|none",
}
local nameOnlyInfo = {
  name = ancestorBase.name,
  mobKey = "name:wailing ancestor",
  playerLevel = ancestorBase.playerLevel,
  level = ancestorBase.level,
  classification = ancestorBase.classification,
  groupSize = ancestorBase.groupSize,
  mapID = ancestorBase.mapID,
  buffSignature = ancestorBase.buffSignature,
  contextKey = ancestorBase.contextKey,
}
module:RecordKill(nameOnlyInfo, 50, 50, 50, "chat", false)
assert(module.char.mobs["name:wailing ancestor"], "name-only ancestor was not recorded")
local npcInfo = {
  name = ancestorBase.name,
  npcID = 99999,
  mobKey = "npc:99999",
  playerLevel = ancestorBase.playerLevel,
  level = ancestorBase.level,
  classification = ancestorBase.classification,
  groupSize = ancestorBase.groupSize,
  mapID = ancestorBase.mapID,
  buffSignature = ancestorBase.buffSignature,
  contextKey = ancestorBase.contextKey,
}
module:RecordKill(npcInfo, 60, 60, 60, "death", false)
assert(not module.char.mobs["name:wailing ancestor"], "late NPC kill left a name-only duplicate")
assert(module.char.mobs["npc:99999"], "late NPC kill did not create the NPC entry")
assert((tonumber(module.char.mobs["npc:99999"].kills) or 0) == 2, "late NPC kill did not preserve both kills")
assert((tonumber(module.char.mobs["npc:99999"].xp.samples) or 0) == 2, "late NPC kill lost XP samples")

-- Overlapping chat/death duplicates must not be double-counted on migration.
local dupDB = module.char
local dupTotalBefore = tonumber(dupDB.totals.kills) or 0
local dupLevelBefore = tonumber(dupDB.levels["10"]) or 0
local dupAreaBefore = tonumber(dupDB.areas["12"]) or 0
local dupUniqueBefore = tonumber(dupDB.totals.uniqueMobs) or 0
local dupXPBefore = tonumber(dupDB.totals.xp) or 0
local dupAreaLevelBefore = tonumber(dupDB.areaLevels["12"] and dupDB.areaLevels["12"]["10"]) or 0
dupDB.mobs["name:chat death split test"] = {
  name = "Chat Death Split Test",
  kills = 14,
  sessionKills = 0,
  totalXP = 756,
  sessionXP = 0,
  killsAtLevel = { ["10"] = 14 },
  killsByMap = { ["12"] = 14 },
  killsByAreaLevel = { ["12"] = { ["10"] = 14 } },
  contexts = {},
  xp = { samples = 14, sumBase = 756, sumBuffed = 756, sumTotal = 756, minBase = 54, maxBase = 54, lastBase = 54, lastTotal = 54 },
  firstSeen = 1000,
  lastSeen = 2000,
  classification = "normal",
}
dupDB.mobs["npc:88888"] = {
  name = "Chat Death Split Test",
  npcID = 88888,
  kills = 16,
  sessionKills = 0,
  totalXP = 500,
  sessionXP = 0,
  killsAtLevel = { ["10"] = 16 },
  killsByMap = { ["12"] = 16 },
  killsByAreaLevel = { ["12"] = { ["10"] = 16 } },
  contexts = {},
  xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 },
  firstSeen = 900,
  lastSeen = 2100,
  classification = "normal",
}
dupDB.totals.kills = dupTotalBefore + 30
dupDB.totals.xp = dupXPBefore + 1256
dupDB.levels["10"] = dupLevelBefore + 30
dupDB.areas["12"] = dupAreaBefore + 30
dupDB.areaLevels["12"] = dupDB.areaLevels["12"] or {}
dupDB.areaLevels["12"]["10"] = dupAreaLevelBefore + 30
dupDB.totals.uniqueMobs = dupUniqueBefore + 2
module:ConsolidateNameOnlyMobs()
assert(not dupDB.mobs["name:chat death split test"], "overlapping duplicate was not consolidated")
local dupMob = dupDB.mobs["npc:88888"]
assert(dupMob, "overlapping duplicate lost the NPC entry")
assert((tonumber(dupMob.kills) or 0) == 16, "overlapping duplicate double-counted kills")
assert((tonumber(dupMob.xp.samples) or 0) == 14, "overlapping duplicate lost XP samples")
assert((tonumber(dupMob.totalXP) or 0) == 756, "overlapping duplicate XP was not deduplicated")
assert((tonumber(dupDB.totals.xp) or 0) == dupXPBefore + 756, "overall XP was not deduplicated")
assert((tonumber(dupDB.areaLevels["12"]["10"]) or 0) == dupAreaLevelBefore + 16, "area-level count was not deduplicated")
assert((tonumber(dupDB.totals.kills) or 0) == dupTotalBefore + 16, "overall kill total was not deduplicated")
assert((tonumber(dupDB.levels["10"]) or 0) == dupLevelBefore + 16, "level kill total was not deduplicated")
assert((tonumber(dupDB.areas["12"]) or 0) == dupAreaBefore + 16, "area kill total was not deduplicated")
assert((tonumber(dupDB.totals.uniqueMobs) or 0) == dupUniqueBefore + 1, "unique mob total was not corrected")

-- Deleting one entry adjusts totals, levels, areas, session, and unique count.
local deleteDB = module.char
local deleteBase = {
  kills = tonumber(deleteDB.totals.kills) or 0,
  xp = tonumber(deleteDB.totals.xp) or 0,
  level = tonumber(deleteDB.levels["10"]) or 0,
  area = tonumber(deleteDB.areas["12"]) or 0,
  areaLevel = tonumber(deleteDB.areaLevels["12"] and deleteDB.areaLevels["12"]["10"]) or 0,
  sessionKills = tonumber(deleteDB.session.kills) or 0,
  sessionXP = tonumber(deleteDB.session.xp) or 0,
  unique = tonumber(deleteDB.totals.uniqueMobs) or 0,
}
deleteDB.mobs["npc:77777"] = {
  name = "Delete Test",
  npcID = 77777,
  kills = 3,
  sessionKills = 3,
  totalXP = 300,
  sessionXP = 300,
  killsAtLevel = { ["10"] = 3 },
  killsByMap = { ["12"] = 3 },
  killsByAreaLevel = { ["12"] = { ["10"] = 3 } },
  contexts = {},
  xp = { samples = 3, sumBase = 300, sumBuffed = 300, sumTotal = 300, minBase = 100, maxBase = 100, lastBase = 100, lastTotal = 100 },
  firstSeen = 1000,
  lastSeen = 2000,
  classification = "normal",
}
deleteDB.totals.kills = deleteBase.kills + 3
deleteDB.totals.xp = deleteBase.xp + 300
deleteDB.levels["10"] = deleteBase.level + 3
deleteDB.areas["12"] = deleteBase.area + 3
deleteDB.areaLevels["12"] = deleteDB.areaLevels["12"] or {}
deleteDB.areaLevels["12"]["10"] = deleteBase.areaLevel + 3
deleteDB.session.kills = deleteBase.sessionKills + 3
deleteDB.session.xp = deleteBase.sessionXP + 300
deleteDB.totals.uniqueMobs = deleteBase.unique + 1
local removedName, removedKills = module:RemoveMobEntry("npc:77777")
assert(removedName == "Delete Test" and removedKills == 3, "single entry delete did not remove the mob")
assert(deleteDB.mobs["npc:77777"] == nil, "deleted mob remained in the list")
assert((tonumber(deleteDB.totals.kills) or 0) == deleteBase.kills, "delete did not restore total kills")
assert((tonumber(deleteDB.totals.xp) or 0) == deleteBase.xp, "delete did not restore total XP")
assert((tonumber(deleteDB.levels["10"]) or 0) == deleteBase.level, "delete did not restore level kills")
assert((tonumber(deleteDB.areas["12"]) or 0) == deleteBase.area, "delete did not restore area kills")
assert((tonumber(deleteDB.areaLevels["12"]["10"]) or 0) == deleteBase.areaLevel, "delete did not restore area-level kills")
assert((tonumber(deleteDB.session.kills) or 0) == deleteBase.sessionKills, "delete did not restore session kills")
assert((tonumber(deleteDB.session.xp) or 0) == deleteBase.sessionXP, "delete did not restore session XP")
assert((tonumber(deleteDB.totals.uniqueMobs) or 0) == deleteBase.unique, "delete did not restore unique mob count")

-- Delete only Unknown entries without touching the rest.
local unknownBase = {
  kills = tonumber(deleteDB.totals.kills) or 0,
  xp = tonumber(deleteDB.totals.xp) or 0,
  level = tonumber(deleteDB.levels["10"]) or 0,
  area = tonumber(deleteDB.areas["12"]) or 0,
  sessionKills = tonumber(deleteDB.session.kills) or 0,
  sessionXP = tonumber(deleteDB.session.xp) or 0,
  unique = tonumber(deleteDB.totals.uniqueMobs) or 0,
}
deleteDB.mobs["name:unknown"] = {
  name = "Unknown",
  kills = 2,
  sessionKills = 2,
  killsAtLevel = { ["10"] = 2 },
  killsByMap = { ["12"] = 2 },
  contexts = {},
  xp = { samples = 2, sumBase = 200, sumBuffed = 200, sumTotal = 200, minBase = 100, maxBase = 100, lastBase = 100, lastTotal = 100 },
  firstSeen = 1000,
  lastSeen = 2000,
  classification = "normal",
}
deleteDB.mobs["npc:66666"] = {
  name = "Unknown",
  npcID = 66666,
  kills = 1,
  sessionKills = 1,
  killsAtLevel = { ["10"] = 1 },
  killsByMap = { ["12"] = 1 },
  contexts = {},
  xp = { samples = 1, sumBase = 100, sumBuffed = 100, sumTotal = 100, minBase = 100, maxBase = 100, lastBase = 100, lastTotal = 100 },
  firstSeen = 1000,
  lastSeen = 2000,
  classification = "normal",
}
deleteDB.totals.kills = unknownBase.kills + 3
deleteDB.totals.xp = unknownBase.xp + 300
deleteDB.levels["10"] = unknownBase.level + 3
deleteDB.areas["12"] = unknownBase.area + 3
deleteDB.session.kills = unknownBase.sessionKills + 3
deleteDB.session.xp = unknownBase.sessionXP + 300
deleteDB.totals.uniqueMobs = unknownBase.unique + 2
module:DeleteUnknownEntries()
assert(deleteDB.mobs["name:unknown"] == nil, "Unknown name entry remained")
assert(deleteDB.mobs["npc:66666"] == nil, "Unknown NPC entry remained")
assert((tonumber(deleteDB.totals.kills) or 0) == unknownBase.kills, "Unknown delete did not restore total kills")
assert((tonumber(deleteDB.totals.xp) or 0) == unknownBase.xp, "Unknown delete did not restore total XP")
assert((tonumber(deleteDB.levels["10"]) or 0) == unknownBase.level, "Unknown delete did not restore level kills")
assert((tonumber(deleteDB.areas["12"]) or 0) == unknownBase.area, "Unknown delete did not restore area kills")
assert((tonumber(deleteDB.session.kills) or 0) == unknownBase.sessionKills, "Unknown delete did not restore session kills")
assert((tonumber(deleteDB.session.xp) or 0) == unknownBase.sessionXP, "Unknown delete did not restore session XP")
assert((tonumber(deleteDB.totals.uniqueMobs) or 0) == unknownBase.unique, "Unknown delete did not restore unique mob count")

-- Command and settings fallback regressions.
assert(pcall(function() module:HandleCommand("kills Defias") end), "filtered kills command failed")
local savedSettings = AceM2L2DB.profile.xpTooltip
AceM2L2DB.profile.xpTooltip = nil
module.settings = nil
local recoveredSettings = module:GetSettings()
assert(type(recoveredSettings) == "table", "GetSettings fallback did not return a table")
assert(recoveredSettings.theme == "aether", "GetSettings fallback lost the default theme")
AceM2L2DB.profile.xpTooltip = savedSettings
module.settings = savedSettings


-- Partial settings must merge every default.
local partialSettings = { theme = "dark" }
AceM2L2DB.profile.xpTooltip = partialSettings
module.settings = nil
local mergedSettings = module:GetSettings()
assert(mergedSettings.enabled == true and mergedSettings.showXP == true,
  "partial settings did not receive tooltip defaults")
assert(type(mergedSettings.ui) == "table" and mergedSettings.ui.width == 1000,
  "partial settings did not receive UI defaults")
assert(type(mergedSettings.minimap) == "table" and mergedSettings.minimap.hide == false,
  "partial settings did not receive minimap defaults")
AceM2L2DB.profile.xpTooltip = savedSettings
module.settings = savedSettings

-- Low-confidence identity must not downgrade a known elite name/classification.
local identityDB = module.char
identityDB.mobs["npc:55555"] = {
  name = "Known Elite",
  npcID = 55555,
  classification = "elite",
  kills = 1,
  sessionKills = 0,
  killsAtLevel = {},
  killsByMap = {},
  contexts = {},
}
module:EnsureMob("npc:55555", "Unknown", 55555, "normal")
assert(identityDB.mobs["npc:55555"].name == "Known Elite", "known mob name was downgraded")
assert(identityDB.mobs["npc:55555"].classification == "elite", "known elite classification was downgraded")

-- Tap-denied and critter units are not eligible.
state.tapped = true
assert(module:CaptureUnit("target") == nil, "tap-denied target was captured")
state.tapped = false
state.critter = true
assert(module:CaptureUnit("target") == nil, "critter target was captured")
state.critter = false

-- Debug command and start-tab behavior.
module:HandleCommand("debug on")
assert(module:GetSettings().debug == true, "xpt debug on failed")
module:HandleCommand("debug off")
assert(module:GetSettings().debug == false, "xpt debug off failed")
module:GetSettings().startTab = "areas"
module:OpenUI()
assert(module.tab == "areas", "startTab was not applied on reopen")
module:GetSettings().startTab = "overview"

-- EnsureDB recomputes uniqueMobs from the actual table.
local uniqueActual = 0
for _ in pairs(identityDB.mobs) do
  uniqueActual = uniqueActual + 1
end
identityDB.totals.uniqueMobs = 999
module:EnsureDB()
assert(identityDB.totals.uniqueMobs == uniqueActual, "EnsureDB did not recompute uniqueMobs")

-- Circuit breaker decays and hides the minimap icon.
module.circuitErrors = 4
module.lastErrorTime = GetTime() - 120
module:ReportError("test", "decayed")
assert(module.circuitErrors == 1, "circuit error counter did not decay")
for _ = 1, 4 do
  module:ReportError("test", "failure")
end
assert(module.autoDisabled, "circuit breaker did not auto-disable")
assert(minimapMock.hidden, "circuit breaker did not hide the minimap icon")

-- Unknown clients stay auto-disabled.
WOW_PROJECT_ID = 99
module:Refresh()
assert(not module:IsActive(), "module should be inactive on an unknown client")
assert(module.autoDisabled, "module should auto-disable on an unknown client")
assert(module:GetStatusText():find("auto-disabled", 1, true), "missing auto-disable status")
WOW_PROJECT_ID = 18
module:Refresh()
assert(module:IsActive(), "module should re-activate on Forever")

assert(pcall(function() AceM2L2:HandleSlashCommand("window 7") end), "window size command failed")
assert(AceM2L2DB.profile.rollingXPWindow == 7, "window size command did not apply")
assert(pcall(function() AceM2L2:HandleSlashCommand("window") end), "window open command failed")

local minimapSettings = module:GetSettings()
local savedMinimapSettings = minimapSettings.minimap
minimapSettings.minimap = nil
assert(pcall(function() module:InitializeMinimap() end), "minimap fallback failed")
minimapSettings.minimap = savedMinimapSettings

-- Replacing the minimap settings table must Refresh, not re-register.
minimapMock.refreshed = false
minimapSettings.minimap = { hide = false, minimapPos = 120, lock = false }
assert(pcall(function() module:InitializeMinimap() end), "minimap refresh failed")
assert(minimapMock.refreshed, "minimap settings table change did not Refresh")
minimapSettings.minimap = savedMinimapSettings
module:InitializeMinimap()

-- The core reset command must be safe after the split.
assert(pcall(function() AceM2L2:HandleSlashCommand("reset") end), "core reset command failed")


-- Legacy root-format data migrates into clients[18] once and stays isolated.
local savedRoot = AceM2L2CharDB.xpTooltip
local legacyRoot = {
  schema = 1,
  mobs = {
    ["npc:4242"] = {
      name = "Legacy Mob",
      kills = 7,
      sessionKills = 2,
      killsAtLevel = { ["10"] = 7 },
      killsByMap = { ["12"] = 7 },
      killsByAreaLevel = { ["12"] = { ["10"] = 7 } },
      contexts = {
        ["p10-m10-g1-z12-cnormal-bnone"] = {
          samples = 2, sumBase = 190, sumBuffed = 190, sumTotal = 190,
          minBase = 95, maxBase = 95, lastSeen = 1,
        },
      },
      xp = {
        samples = 2, sumBase = 190, sumBuffed = 190, sumTotal = 190,
        minBase = 95, maxBase = 95, lastBase = 95, lastTotal = 95,
      },
      firstSeen = 1,
      lastSeen = 2,
      classification = "normal",
    },
  },
  areas = { ["12"] = 7 },
  levels = { ["10"] = 7 },
  areaLevels = { ["12"] = { ["10"] = 7 } },
  totals = { kills = 7, xp = 700, uniqueMobs = 1 },
  session = { startedAt = 1, kills = 2, xp = 200 },
  calibration = {
    zones = { ["12"] = { ratio = 1.05, samples = 3 } },
    levels = {},
    groups = {},
    classes = {},
    mobs = {},
  },
  calibrationVersion = 2,
}
AceM2L2CharDB.xpTooltip = legacyRoot
module.char = nil
module:EnsureDB()
local migrated = AceM2L2CharDB.xpTooltip
assert(migrated.storageSchema == 2, "legacy root migration did not set storageSchema")
assert(migrated.mobs == nil, "legacy root data was not moved")
assert(migrated.clients[18], "legacy data was not moved to clients[18]")
assert(migrated.clients[18].mobs["npc:4242"].kills == 7, "legacy kills were lost")
assert(migrated.clients[18].totals.xp == 700, "legacy XP was lost")
assert(migrated.clients[18].session.kills == 2, "legacy session was lost")
assert(migrated.clients[18].session.xp == 200, "legacy session XP was lost")
assert(migrated.clients[18].mobs["npc:4242"].xp.samples == 2, "legacy XP samples were lost")
assert(migrated.clients[18].mobs["npc:4242"].contexts["p10-m10-g1-z12-cnormal-bnone"],
  "legacy contexts were lost")
assert(migrated.clients[18].calibration.zones["12"].samples == 3, "legacy calibration was lost")
assert(migrated.clients[18].areaLevels["12"]["10"] == 7, "legacy area-level counts were lost")

-- Running migration again must be idempotent.
module:EnsureDB()
assert(AceM2L2CharDB.xpTooltip.clients[18].mobs["npc:4242"].kills == 7,
  "migration was not idempotent")

-- Root data must never be merged into an existing clients table.
migrated.mobs = { ["npc:4243"] = { name = "Root Only", kills = 99 } }
module:EnsureDB()
assert(migrated.clients[18].mobs["npc:4243"] == nil, "root data leaked into clients[18]")
assert(migrated.mobs["npc:4243"].kills == 99, "coexistence root fixture was mutated")

-- An existing but empty clients table is still treated as unmigrated.
AceM2L2CharDB.xpTooltip = {
  clients = {},
  mobs = { ["npc:4244"] = { name = "Empty Clients", kills = 2 } },
  totals = { kills = 2, xp = 190, uniqueMobs = 1 },
}
module.char = nil
module:EnsureDB()
assert(AceM2L2CharDB.xpTooltip.clients[18].mobs["npc:4244"],
  "empty clients table blocked legacy migration")

AceM2L2CharDB.xpTooltip = savedRoot
module:EnsureDB()
assert(module.char == AceM2L2CharDB.xpTooltip.clients[18], "data namespace was not restored")

else
  local function RunMidnightChecks()
    assert(module:IsActive(), "Midnight Kill History should be active")
    assert(module:Supports("hasKillTracking"), "Midnight should support kill tracking")
    assert(not module:Supports("hasXPFormula"), "Midnight must not claim an XP formula")
    assert(not module:Supports("hasTooltipXP"), "Midnight must not show XP tooltip lines")
    assert(not module:Supports("hasKillsToLevel"), "Midnight must not claim kills-to-level")
    assert(module:GetStatusText():find("Midnight", 1, true), "status missing Midnight: " .. module:GetStatusText())
    assert(module.char == AceM2L2CharDB.xpTooltip.clients[1], "Midnight data is not in clients[1]")
    assert(AceM2L2CharDB.xpTooltip.storageSchema == 2, "storage schema is not 2")
    assert(module.char.dataSchema == 1, "client data schema is not 1")
    assert(module:GetCapabilitySummary():find("killTracking=yes", 1, true), "capability summary missing tracking")
    assert(module:GetCapabilitySummary():find("formula=no", 1, true), "capability summary claims a formula")
    assert(module:GetCapabilitySummary():find("perMobXP=no", 1, true), "capability summary claims per-mob XP")
    assert(module:GetXP() == nil and module:GetXPMax() == nil,
      "Midnight should not expose player XP state through the capability-gated helpers")
    assert(next(module.char.calibration.zones) == nil, "Midnight calibration should start empty")
    assert(next(module.char.calibration.mobs) == nil, "Midnight mob calibration should start empty")

    if config.missingTooltip then
      assert(not module.tooltipHookInstalled, "missing tooltip hook should stay uninstalled")
      assert(module:GetStatusText():find("no tooltip hook", 1, true),
        "status should report the missing tooltip hook: " .. module:GetStatusText())
    end

    module:ResetKills()
    module:OnTargetChanged("PLAYER_TARGET_CHANGED")

    local expectedName = config.secretName and "NPC 1234" or "Defias Pillager"

    if not config.secretIdentity then
      assert(module.lastTarget, "target was not captured on Midnight")
      module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
      RunTimers()
      local mob = module.char.mobs["npc:1234"]
      assert(mob and mob.kills == 1, "Midnight death was not counted")
      assert(mob.name == expectedName, "Midnight identity name mismatch: " .. tostring(mob.name))
      assert(module.char.totals.kills == 1, "Midnight total kills mismatch")
      assert(module.char.areas["12"] == 1, "Midnight area count mismatch")
      assert(module.char.levels["10"] == 1, "Midnight level count mismatch")
      assert(type(mob.xp) == "table" and (tonumber(mob.xp.samples) or 0) == 0,
        "Midnight recorded an XP sample")
      assert((tonumber(mob.totalXP) or 0) == 0, "Midnight recorded XP")
      assert(next(mob.contexts or {}) == nil, "Midnight recorded an observation context")
      assert(module.char.calibration.mobs["npc:1234"] == nil, "Midnight recorded calibration")
      assert((tonumber(module.char.totals.xp) or 0) == 0, "Midnight total XP is non-zero")
      assert((tonumber(module.char.session.xp) or 0) == 0, "Midnight session XP is non-zero")

      -- PLAYER_XP_UPDATE must not create an observation on counts-only clients.
      module:OnPlayerXPUpdate("PLAYER_XP_UPDATE")
      assert((tonumber(mob.xp.samples) or 0) == 0, "PLAYER_XP_UPDATE created a Midnight sample")

      -- Counts-only mode ignores XP chat rather than inventing a second kill.
      module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
      assert(module.char.totals.kills == 1, "Midnight XP chat added a kill")

      -- The count-zero setting is a Forever XP-path filter; Midnight must still
      -- count readable deaths when it is off.
      module:GetSettings().countZeroXPMobs = false
      module:ResetKills()
      module:OnTargetChanged("PLAYER_TARGET_CHANGED")
      module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
      RunTimers()
      assert(module.char.totals.kills == 1, "countZeroXPMobs=false suppressed Midnight kills")
      module:GetSettings().countZeroXPMobs = true
      mob = module.char.mobs["npc:1234"]
      assert(mob and mob.kills == 1, "Midnight recount did not produce a mob")

      GameTooltip.lines = {}
      GameTooltip.xpTooltipSignature = nil
      module:AddTooltipLines(GameTooltip, nil)
      local text = table.concat(GameTooltip.lines, "\n")
      assert(text:find("Killed:", 1, true), "Midnight tooltip missing kill count: " .. text)
      assert(not text:find("XP:", 1, true), "Midnight tooltip claimed XP: " .. text)
      assert(not text:find("Kills to level:", 1, true), "Midnight tooltip claimed kills-to-level: " .. text)

      module:OpenUI()
      assert(module.ui and module.ui:IsShown(), "Midnight UI did not open")
      module:SetTab("mobs")
      module:BuildList()
      local rowFound = false
      for _, item in ipairs(module.currentList) do
        if item.kind == "mob" and item.label == expectedName then
          rowFound = true
          assert(not item.value:find("avg", 1, true), "Midnight list row claimed average XP: " .. item.value)
        end
      end
      assert(rowFound, "Midnight list row missing")
      module:SelectIndex(1)
      assert(module.ui.heroName.text == expectedName, "Midnight detail name mismatch")
      assert(not module.ui.details.text:find("Avg base XP", 1, true),
        "Midnight detail claimed average XP")
      assert(module.ui.details.text:find("Total kills:", 1, true), "Midnight detail missing counts")

      if config.secretName then
        module:DeleteUnknownEntries()
        assert(module.char.mobs["npc:1234"], "identified NPC was removed as Unknown")
      end
    else
      assert(module.lastTarget == nil, "secret identity was captured")
      module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
      RunTimers()
      assert(next(module.char.mobs) == nil, "secret identity created a fake kill")
      assert(module.char.totals.kills == 0, "secret identity changed the kill total")
      GameTooltip.lines = {}
      GameTooltip.xpTooltipSignature = nil
      module:AddTooltipLines(GameTooltip, nil)
      assert(#GameTooltip.lines == 0, "secret identity produced tooltip lines")
      module:OpenUI()
      module:SetTab("mobs")
      assert(module.ui.heroName.text == "No kill data", "secret identity empty state mismatch")
    end

    assert(module:GetRestedPool() == 0, "Midnight should not read a rested pool")
    assert(module:CanReadRested() == false, "Midnight should not claim rested readability")
    assert(module:GetBuffMultiplier(true, true) == 1, "Midnight should not apply buff multipliers")
    assert(module:GetEstimate(10, 10, "normal", 12, 1, "npc:1234", "none") == 0,
      "Midnight should not produce formula estimates")

    assert(pcall(function() module:HandleCommand("status") end), "Midnight status command failed")
    assert(pcall(function() module:HandleCommand("probe") end), "Midnight probe command failed")
    assert(pcall(function() module:HandleCommand("session") end), "Midnight session command failed")
    assert(pcall(function() module:HandleCommand("stats") end), "Midnight stats command failed")
    assert(pcall(function() module:HandleCommand("table") end), "Midnight table command failed")
    assert(pcall(function() module:HandleCommand("kills") end), "Midnight kills command failed")

    -- Forever data must stay isolated from Midnight data, including mutations.
    AceM2L2CharDB.xpTooltip.clients[18] = {
      mobs = { ["npc:999"] = { name = "ForeverOnly", kills = 9 } },
      totals = { kills = 9, xp = 900, uniqueMobs = 1 },
      session = { startedAt = 1, kills = 7, xp = 700 },
    }
    module:EnsureDB()
    assert(module.char == AceM2L2CharDB.xpTooltip.clients[1], "Midnight data switched clients")
    assert(module.char.mobs["npc:999"] == nil, "Forever data leaked into Midnight")
    module:ResetKills()
    assert(AceM2L2CharDB.xpTooltip.clients[18].totals.kills == 9,
      "Midnight reset changed Forever kills")
    module:StartSession()
    assert(AceM2L2CharDB.xpTooltip.clients[18].session.kills == 7,
      "Midnight session reset changed Forever session")
  end

  if SCENARIO == "unknown" then
    assert(not module:IsActive(), "unknown client should be inactive")
    assert(module.autoDisabled, "unknown client should auto-disable")
    assert(module:GetStatusText():find("auto-disabled", 1, true), "missing auto-disable status")
    assert(module:GetClientProfile() == nil, "unknown client resolved a profile")
    local compatible, reason = module:CheckCompatibility()
    assert(not compatible, "unknown client reported compatible")
    assert(reason:find("unsupported client", 1, true), "unknown client reason mismatch: " .. tostring(reason))
    assert(module:GetCapabilitySummary() == "none", "unknown client exposed capabilities")
    assert(pcall(function() module:HandleCommand("status") end), "unknown status command failed")
    assert(pcall(function() module:HandleCommand("probe") end), "unknown probe command failed")
    assert(pcall(function() module:HandleCommand("table") end), "unknown table command failed")
  else
    RunMidnightChecks()
  end
end

print("XPTooltip smoke test passed")
