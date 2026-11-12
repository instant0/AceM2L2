-- Offline smoke test for the AceM2L2 XPTooltip module.
-- This is not a WoW client; it only catches Lua/nil-method regressions.

WOW_PROJECT_CAMELOT = 18
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_ID = 18

function issecretvalue(value)
  return false
end

local timers = {}
C_Timer = {
  After = function(delay, fn)
    timers[#timers + 1] = fn
  end,
}

local function RunTimers()
  local pending = timers
  timers = {}
  for _, fn in ipairs(pending) do
    fn()
  end
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
}

function GetTime()
  return state.now
end

function time()
  return 1760000000 + state.now
end

date = os.date

function GetBuildInfo()
  return "1.60.1", "1.60.1", "Nov 4 2026", 16001
end

function UnitXP(unit)
  return state.xp
end

function UnitXPMax(unit)
  return state.xpMax
end

function UnitLevel(unit)
  if unit == "player" then
    return state.playerLevel
  end
  return state.targetLevel
end

function UnitName(unit)
  if unit == "player" then
    return "Tester"
  end
  return "Defias Pillager", nil
end

function UnitGUID(unit)
  if unit == "player" then
    return "Player-1-00000001"
  end
  return "Creature-0-1-2-3-1234-00000001"
end

function UnitClassification(unit)
  return "normal"
end

function UnitCreatureType(unit)
  return "Humanoid", 7
end

function UnitExists(unit)
  return unit == "player" or unit == "target" or unit == "mouseover"
end

function UnitIsPlayer(unit)
  return unit == "player"
end

function UnitIsDead(unit)
  if unit == "target" then
    return state.targetDead
  end
  return false
end

function UnitPlayerControlled(unit)
  return false
end

function UnitCanAttack(a, b)
  return b == "target"
end

function GetXPExhaustion()
  return state.pool
end

function GetMaxPlayerLevel()
  return 60
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

-- Ace3 mock -------------------------------------------------------------------

local AceAddonProto = {}

function AceAddonProto:NewAddon(name)
  local addon = {
    name = name,
    modules = {},
    events = {},
  }
  setmetatable(addon, { __index = AceAddonProto })

  function addon:RegisterChatCommand() end
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
  Refresh = function() end,
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

dofile("ACEM2L2.lua")
dofile("XPTooltip.lua")
dofile("Bindings.lua")

AceM2L2:OnInitialize()

local module = AceM2L2:GetModule("XPTooltip")
assert(module, "module was not created")

module:OnInitialize()
module:OnEnable()

assert(module:IsActive(), "module should be active on Forever")
assert(module:GetSettings().theme == "aether", "default theme should be aether")

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

module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")

local db = AceM2L2CharDB.xpTooltip
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

-- Chat first, then death: must not double count.
module.settings.debug = true
print("recent before death", #module.recentChatKills, module.recentChatKills[1] and module.recentChatKills[1].mobKey)
local deathCandidate = module:FindDeathCandidate("Creature-0-1-2-3-1234-00000001")
print("death candidate", deathCandidate and deathCandidate.mobKey, deathCandidate and deathCandidate.name, deathCandidate and deathCandidate.guid)
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
print("recent after death", #module.recentChatKills, "pending", #module.pendingDeaths, "kills", mob.kills)
RunTimers()
assert(mob.kills == 1, "chat+death double counted: " .. tostring(mob.kills))

-- Death first, then chat: must count exactly once.
module:ResetKills()
mob = nil
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
assert(#module.pendingDeaths == 1, "death was not queued")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
RunTimers()
db = AceM2L2CharDB.xpTooltip
mob = db.mobs["npc:1234"]
assert(mob and mob.kills == 1, "death+chat did not count exactly once")

-- Gray death with no XP chat: count after timer.
module:ResetKills()
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
RunTimers()
db = AceM2L2CharDB.xpTooltip
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
db = AceM2L2CharDB.xpTooltip
assert(next(db.mobs) == nil, "unnamed chat recorded before identity was known")
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
db = AceM2L2CharDB.xpTooltip
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
db = AceM2L2CharDB.xpTooltip
assert(db.mobs["npc:1234"] and db.mobs["npc:1234"].kills == 1, "cleared target lost the death identity")

-- A pending death must not survive resetkills.
module:ResetKills()
module:OnUnitDied("UNIT_DIED", "Creature-0-1-2-3-1234-00000001")
assert(#module.pendingDeaths == 1, "death was not queued before reset")
module:ResetKills()
RunTimers()
assert(next(AceM2L2CharDB.xpTooltip.mobs) == nil, "pending death added a kill after reset")

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
module:HandleCommand("dump")
module:HandleCommand("table")

-- Class calibration.
local calibration = AceM2L2CharDB.xpTooltip.calibration
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

assert(module:KillsToLevel(7600, 95, 0) == 80, "unrested kills-to-level should be 80")
assert(module:KillsToLevel(7600, 95, 10000) == 40, "fully rested kills-to-level should be 40")
local buffMultiplier = module:GetBuffMultiplier(true, true)
assert(math.abs(buffMultiplier - 1.0815) < 0.0001, "Well Fed + Well-Rested should be 1.0815")

-- XP update must not add a second kill.
local beforeXPUpdate = AceM2L2CharDB.xpTooltip.totals.kills
module:OnPlayerXPUpdate("PLAYER_XP_UPDATE")
assert(AceM2L2CharDB.xpTooltip.totals.kills == beforeXPUpdate, "XP update double counted")

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
local legacy = AceM2L2CharDB.xpTooltip
legacy.calibrationVersion = nil
legacy.calibration.zones["12"] = { ratio = 1.6, samples = 10 }
module:EnsureDB()
assert(next(legacy.calibration.zones) == nil, "legacy calibration was not cleared")
assert(legacy.calibrationVersion == 2, "calibration version was not bumped")

-- Manual recalibration clears ratios but not kills.
legacy.calibration.zones["12"] = { ratio = 1.6, samples = 10 }
module:ResetCalibration()
assert(next(legacy.calibration.zones) == nil, "recalibrate did not clear ratios")

-- Name-only duplicates from early chat kills merge into the NPC entry.
local mergeDB = AceM2L2CharDB.xpTooltip
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
local dupDB = AceM2L2CharDB.xpTooltip
local dupTotalBefore = tonumber(dupDB.totals.kills) or 0
local dupLevelBefore = tonumber(dupDB.levels["10"]) or 0
local dupAreaBefore = tonumber(dupDB.areas["12"]) or 0
local dupUniqueBefore = tonumber(dupDB.totals.uniqueMobs) or 0
dupDB.mobs["name:chat death split test"] = {
  name = "Chat Death Split Test",
  kills = 14,
  sessionKills = 0,
  killsAtLevel = { ["10"] = 14 },
  killsByMap = { ["12"] = 14 },
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
  killsAtLevel = { ["10"] = 16 },
  killsByMap = { ["12"] = 16 },
  contexts = {},
  xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0, minBase = 0, maxBase = 0, lastBase = 0, lastTotal = 0 },
  firstSeen = 900,
  lastSeen = 2100,
  classification = "normal",
}
dupDB.totals.kills = dupTotalBefore + 30
dupDB.levels["10"] = dupLevelBefore + 30
dupDB.areas["12"] = dupAreaBefore + 30
dupDB.totals.uniqueMobs = dupUniqueBefore + 2
module:ConsolidateNameOnlyMobs()
assert(not dupDB.mobs["name:chat death split test"], "overlapping duplicate was not consolidated")
local dupMob = dupDB.mobs["npc:88888"]
assert(dupMob, "overlapping duplicate lost the NPC entry")
assert((tonumber(dupMob.kills) or 0) == 16, "overlapping duplicate double-counted kills")
assert((tonumber(dupMob.xp.samples) or 0) == 14, "overlapping duplicate lost XP samples")
assert((tonumber(dupDB.totals.kills) or 0) == dupTotalBefore + 16, "overall kill total was not deduplicated")
assert((tonumber(dupDB.levels["10"]) or 0) == dupLevelBefore + 16, "level kill total was not deduplicated")
assert((tonumber(dupDB.areas["12"]) or 0) == dupAreaBefore + 16, "area kill total was not deduplicated")
assert((tonumber(dupDB.totals.uniqueMobs) or 0) == dupUniqueBefore + 1, "unique mob total was not corrected")

-- Deleting one entry adjusts totals, levels, areas, session, and unique count.
local deleteDB = AceM2L2CharDB.xpTooltip
local deleteBase = {
  kills = tonumber(deleteDB.totals.kills) or 0,
  xp = tonumber(deleteDB.totals.xp) or 0,
  level = tonumber(deleteDB.levels["10"]) or 0,
  area = tonumber(deleteDB.areas["12"]) or 0,
  sessionKills = tonumber(deleteDB.session.kills) or 0,
  sessionXP = tonumber(deleteDB.session.xp) or 0,
  unique = tonumber(deleteDB.totals.uniqueMobs) or 0,
}
deleteDB.mobs["npc:77777"] = {
  name = "Delete Test",
  npcID = 77777,
  kills = 3,
  sessionKills = 3,
  killsAtLevel = { ["10"] = 3 },
  killsByMap = { ["12"] = 3 },
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

-- Midnight auto-disable.
WOW_PROJECT_ID = 1
module:Refresh()
assert(not module:IsActive(), "module should be inactive on Midnight")
assert(module.autoDisabled, "module should auto-disable on Midnight")
assert(module:GetStatusText():find("auto-disabled", 1, true), "missing auto-disable status")
WOW_PROJECT_ID = 18
module:Refresh()
assert(module:IsActive(), "module should re-activate on Forever")

print("XPTooltip smoke test passed")
