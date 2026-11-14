-- Focused offline smoke suite for AceM2L2.
-- Replaces the former 2,369-line monolithic test with shared fixtures and
-- high-value behavior checks.

local F = dofile("tests/fixtures.lua")
local module = F.Init()

local SCENARIO = F.SCENARIO
local config = F.config
local state = F.state
local SetTarget = F.SetTarget
local SetTargetFlags = F.SetTargetFlags
local RunTimers = F.RunTimers
local AdvanceTime = F.AdvanceTime
local GameTooltip = F.GameTooltip
local DEFAULT_CHAT_FRAME = F.DEFAULT_CHAT_FRAME
local minimapMock = F.minimapMock
local SetMouseover = F.SetMouseover

local GUID_A = "Creature-0-1-2-3-1234-00000001"
local GUID_B = "Creature-0-1-2-3-1234-00000002"

assert(AceM2L2.chatCommands["acem2l2"], "acem2l2 command missing")
assert(AceM2L2.chatCommands["am2"], "am2 alias missing")
assert(AceM2L2.events["CHAT_MSG_COMBAT_XP_GAIN"], "core XP event missing")
assert(AceM2L2.events["PLAYER_XP_UPDATE"], "core XP event missing")
assert(AceM2L2.events["FACTION_STANDING_CHANGED"], "core reputation event missing")
assert(module, "Kill Story module missing")

local function AssertInactiveUnknown()
  assert(not module:IsActive(), "unknown client should be inactive")
  assert(module.autoDisabled, "unknown client should auto-disable")
  assert(module:GetStatusText():find("auto-disabled", 1, true), "missing auto-disable status")
  assert(module:GetClientProfile() == nil, "unknown client resolved a profile")
  assert(module:GetCapabilitySummary() == "none", "unknown client exposed capabilities")
  assert(pcall(function() module:HandleCommand("status") end), "unknown status failed")
  assert(pcall(function() module:HandleCommand("probe") end), "unknown probe failed")
end

local function AssertAggregateInvariant(label)
  local db = module.char
  local kills, xp, sessionKills, sessionXP, unique = 0, 0, 0, 0, 0
  local levels, areas, areaLevels = {}, {}, {}
  for _, mob in pairs(db.mobs or {}) do
    if type(mob) == "table" then
      unique = unique + 1
      kills = kills + (tonumber(mob.kills) or 0)
      xp = xp + (tonumber(mob.totalXP) or 0)
      sessionKills = sessionKills + (tonumber(mob.sessionKills) or 0)
      sessionXP = sessionXP + (tonumber(mob.sessionXP) or 0)
      for key, value in pairs(mob.killsAtLevel or {}) do
        levels[key] = (levels[key] or 0) + (tonumber(value) or 0)
      end
      for key, value in pairs(mob.killsByMap or {}) do
        areas[key] = (areas[key] or 0) + (tonumber(value) or 0)
      end
      for mapKey, byLevel in pairs(mob.killsByAreaLevel or {}) do
        if type(byLevel) == "table" then
          areaLevels[mapKey] = areaLevels[mapKey] or {}
          for levelKey, value in pairs(byLevel) do
            areaLevels[mapKey][levelKey] = (areaLevels[mapKey][levelKey] or 0) + (tonumber(value) or 0)
          end
        end
      end
    end
  end
  assert((tonumber(db.totals.kills) or 0) == kills, label .. ": kills")
  assert((tonumber(db.totals.xp) or 0) == xp, label .. ": xp")
  assert((tonumber(db.session.kills) or 0) == sessionKills, label .. ": session kills")
  assert((tonumber(db.session.xp) or 0) == sessionXP, label .. ": session xp")
  assert((tonumber(db.totals.uniqueMobs) or 0) == unique, label .. ": unique")
  for key, value in pairs(levels) do
    assert((tonumber(db.levels[key]) or 0) == value, label .. ": level " .. key)
  end
  for key, value in pairs(areas) do
    assert((tonumber(db.areas[key]) or 0) == value, label .. ": area " .. key)
  end
  for mapKey, byLevel in pairs(areaLevels) do
    for levelKey, value in pairs(byLevel) do
      local actual = db.areaLevels[mapKey] and tonumber(db.areaLevels[mapKey][levelKey]) or 0
      assert(actual == value, label .. ": area-level " .. mapKey .. "/" .. levelKey)
    end
  end
end

local function ResetTarget()
  SetTargetFlags({})
  SetTarget("Defias Pillager", GUID_A)
  module:OnTargetChanged("PLAYER_TARGET_CHANGED")
end

if SCENARIO == "unknown" then
  AssertInactiveUnknown()
  print("Focused smoke test passed (unknown)")
  return
end

local isMidnight = config.projectID == 1
if isMidnight then
  assert(module:IsActive(), "Midnight should be active")
  assert(module:Supports("hasKillTracking"), "Midnight tracking missing")
  assert(not module:Supports("hasXPFormula"), "Midnight must not claim a formula")
  assert(not module:Supports("hasTooltipXP"), "Midnight must not claim tooltip XP")
  assert(module.char == AceM2L2CharDB.xpTooltip.clients[1], "Midnight namespace missing")
  assert(AceM2L2CharDB.xpTooltip.storageSchema == 2, "storage schema mismatch")
  assert(module.char.dataSchema == 1, "client data schema mismatch")
  if config.missingTooltip then
    assert(not module.tooltipHookInstalled, "missing tooltip hook should stay uninstalled")
    assert(module:GetStatusText():find("no tooltip hook", 1, true),
      "missing tooltip hook not reported")
  end

  -- Eligibility matrix.
  SetTarget("Enemy Player", "Player-1-00000002")
  SetTargetFlags({})
  assert(not module:CaptureUnit("target"), "Midnight accepted Player-*")
  SetTarget("Pet", "Pet-0-1234-5678")
  assert(not module:CaptureUnit("target"), "Midnight accepted Pet-*")
  SetTarget("Defias Pillager", GUID_A)
  SetTargetFlags({})
  if config.secretIdentity then
    assert(not module:CaptureUnit("target"), "secret identity captured")
  else
    assert(module:CaptureUnit("target"), "Midnight rejected a creature")
    if not config.secretBooleans then
      SetTargetFlags({ controlled = true })
      assert(not module:CaptureUnit("target"), "Midnight accepted controlled unit")
      SetTargetFlags({ canAttack = false })
      assert(not module:CaptureUnit("target"), "Midnight accepted unattackable unit")
      SetTargetFlags({ isPlayer = true })
      assert(not module:CaptureUnit("target"), "Midnight accepted player flag")
    end
  end
  SetTargetFlags({})

  module:ResetKills()
  if config.secretIdentity then
    module.lastTarget = nil
    module.lastMouseover = nil
    SetTarget("Defias Pillager", GUID_A)
    assert(not module:CaptureUnit("target"), "secret identity was captured")
    module:OnUnitDied("UNIT_DIED", GUID_A)
    AdvanceTime(2.5)
    assert(next(module.char.mobs) == nil, "secret identity created a kill")
    assert(module.char.totals.kills == 0, "secret identity changed totals")
    GameTooltip.lines = {}
    GameTooltip.xpTooltipSignature = nil
    module:AddTooltipLines(GameTooltip, nil)
    assert(#GameTooltip.lines == 0, "secret identity produced tooltip lines")
    module:OpenUI()
    module:SetTab("mobs")
    assert(module.ui.heroName.text == "No kill data", "secret identity empty state mismatch")
  else
    ResetTarget()
    module:OnUnitDied("UNIT_DIED", GUID_A)
    AdvanceTime(2.5)
    local mob = module.char.mobs["npc:1234"]
    assert(mob and mob.kills == 1, "Midnight death not counted")
    assert(module.char.areas["12"] == 1, "Midnight area missing")
    assert(module.char.levels["10"] == 1, "Midnight level missing")
    assert((tonumber(mob.totalXP) or 0) == 0, "Midnight recorded XP")
    assert((tonumber(mob.xp.samples) or 0) == 0, "Midnight recorded samples")
    assert(next(mob.contexts or {}) == nil, "Midnight recorded contexts")

    local levelRecord = module:GetCurrentLevelRecord(false)
    assert(levelRecord and levelRecord.level == 10 and levelRecord.kills == 1,
      "Midnight level history missing kill")
    assert(levelRecord.xpGained == 0, "Midnight level history recorded XP")
    state.playerLevel = 11
    module:OnLevelUp("PLAYER_LEVEL_UP", 11)
    local levelRecords = module:NormalizeLevelHistory()
    local finishedLevel = levelRecords[#levelRecords - 1]
    assert(finishedLevel.level == 10 and finishedLevel.endedAt > 0
      and finishedLevel.kills == 1 and finishedLevel.xpGained == 0,
      "Midnight level history finalization mismatch")
    local midnightHistory = {}
    local savedHistoryPrint = AceM2L2.Print
    AceM2L2.Print = function(_, message)
      midnightHistory[#midnightHistory + 1] = tostring(message)
    end
    module:HandleCommand("history")
    AceM2L2.Print = savedHistoryPrint
    local midnightHistoryText = table.concat(midnightHistory, "\n")
    assert(midnightHistoryText:find("Level 10", 1, true)
      and midnightHistoryText:find("kills", 1, true),
      "Midnight history command missing kills")
    assert(not midnightHistoryText:find(" XP", 1, true),
      "Midnight history command claimed XP")
    state.playerLevel = 10
    module:EnsureLevelHistory()

    module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
    assert(module.char.totals.kills == 1, "Midnight chat added a kill")

    GameTooltip.lines = {}
    GameTooltip.xpTooltipSignature = nil
    module:AddTooltipLines(GameTooltip, nil)
    local tooltipText = table.concat(GameTooltip.lines, "\n")
    assert(tooltipText:find("Killed:", 1, true), "Midnight tooltip missing kill count")
    assert(not tooltipText:find("XP:", 1, true), "Midnight tooltip claimed XP")
    assert(not tooltipText:find("Kills to level:", 1, true), "Midnight tooltip claimed kills-to-level")
    assert(not tooltipText:find("XP remaining:", 1, true), "Midnight tooltip claimed remaining XP")
    assert(tooltipText:find("Level:", 1, true), "Midnight tooltip missing mob level")
    assert(not tooltipText:find("XP bonuses:", 1, true), "Midnight tooltip claimed XP bonuses")

    module:OpenUI()
    module:SetTab("mobs")
    module:SelectIndex(1)
    assert(module.ui.heroName.text == (config.secretName and "NPC 1234" or "Defias Pillager"),
      "Midnight detail name mismatch")
    assert(not module.ui.details.text:find("Avg base XP", 1, true), "Midnight detail claimed XP")
  end

  assert(module:GetRestedPool() == 0, "Midnight read rested pool")
  assert(module:GetBuffMultiplier(true, true) == 1, "Midnight applied buff multiplier")
  local midnightBonuses = module:GetActiveXPBonuses()
  assert(#midnightBonuses == 0, "Midnight exposed XP bonuses")
  assert(module:GetEstimate(10, 10, "normal", 12, 1, "npc:1234", "none") == 0,
    "Midnight produced formula estimate")

  local savedXP = state.xp
  AceM2L2.lastXP = savedXP
  AceM2L2.lastCreatureName = nil
  AceM2L2.lastXPSource = nil
  AceM2L2.lastXPInfoTime = 0
  AceM2L2.lastChatXPAmount = nil
  AceM2L2:OnQuestTurnedIn("QUEST_TURNED_IN", 42, 100)
  state.xp = savedXP + 100
  AceM2L2:HandleXPText("You gain 100 experience.")
  AceM2L2:HandlePlayerXPUpdate()
  RunTimers()
  assert(not module.char.quests or next(module.char.quests) == nil,
    "Midnight recorded quest XP")
  state.xp = savedXP
  AceM2L2.lastXP = savedXP
  AceM2L2:ClearQuestXPWindow()
  assert(pcall(function() module:HandleCommand("status") end), "Midnight status failed")
  assert(pcall(function() module:HandleCommand("probe") end), "Midnight probe failed")
  assert(pcall(function() module:HandleCommand("table") end), "Midnight table failed")

  print("Focused smoke test passed (" .. SCENARIO .. ")")
  return
end

-- Forever ---------------------------------------------------------------------

assert(module:IsActive(), "Forever module should be active")
assert(module:GetSettings().theme == "aether", "default theme mismatch")
assert(AceM2L2CharDB.xpTooltip.storageSchema == 2, "storage schema mismatch")
assert(module.char == AceM2L2CharDB.xpTooltip.clients[18], "Forever namespace missing")

-- Core parser and quest XP.
assert(AceM2L2:ParseXPMessage("You have discovered Westfall. You gain 100 experience.") == nil,
  "exploration XP parsed as kill")
local groupName, groupTotal = AceM2L2:ParseXPMessage(
  "Defias Pillager dies, you gain 22 experience. (+2 group bonus)")
assert(groupName == "Defias Pillager" and groupTotal == 22, "group XP amount mismatch")

AceM2L2.xpSamples = {}
AceM2L2:AddSampleXP(100)
AceM2L2:AddSampleXP(200)
assert(AceM2L2:GetAverageXP() == 150, "rolling XP average mismatch")
AceM2L2.xpSamples = {}

local savedPrint = AceM2L2.Print
local helpMessages = {}
AceM2L2.Print = function(_, message)
  helpMessages[#helpMessages + 1] = tostring(message)
end
AceM2L2:PrintHelp()
local helpText = table.concat(helpMessages, "\n")
assert(helpText:find("xpt probe", 1, true), "core help missing xpt probe")
assert(helpText:find("xpt reset confirm", 1, true), "core help missing reset confirm")
AceM2L2.Print = savedPrint

local savedQuestState = {
  xp = state.xp,
  lastXP = AceM2L2.lastXP,
  samples = AceM2L2.xpSamples,
  counter = AceM2L2.xpKillCounter,
}
DEFAULT_CHAT_FRAME.messages = {}
AceM2L2.xpSamples = {}
AceM2L2.xpKillCounter = 0
AceM2L2.lastXP = state.xp
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
AceM2L2:OnQuestTurnedIn("QUEST_TURNED_IN", 1234, 100)
state.xp = state.xp + 100
AceM2L2:HandleXPText("You gain 100 experience.")
AceM2L2:HandlePlayerXPUpdate()
RunTimers()
local questText = table.concat(DEFAULT_CHAT_FRAME.messages, "\n")
assert(questText:find("quests to level", 1, true), "quest XP not labeled as quest")
assert(not questText:find("kills to level", 1, true), "quest XP labeled as kills")
assert(#AceM2L2.xpSamples == 0, "quest XP entered kill average")

DEFAULT_CHAT_FRAME.messages = {}
AceM2L2.lastXP = state.xp
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
AceM2L2.questXPWindowUntil = 0
AceM2L2.questXPAmount = nil
state.xp = state.xp + 50
AceM2L2:HandleXPText("You gain 50 experience.")
AceM2L2:HandlePlayerXPUpdate()
RunTimers()
assert(#DEFAULT_CHAT_FRAME.messages == 0, "ambiguous XP printed a message")

DEFAULT_CHAT_FRAME.messages = {}
AceM2L2.lastXP = state.xp
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
state.xp = state.xp + 95
AceM2L2:HandleXPText("Defias Pillager dies, you gain 95 experience.")
AceM2L2:HandlePlayerXPUpdate()
RunTimers()
assert(table.concat(DEFAULT_CHAT_FRAME.messages, "\n"):find("kills to level", 1, true),
  "named kill XP not labeled as kill")

DEFAULT_CHAT_FRAME.messages = {}
AceM2L2.lastXP = state.xp
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
AceM2L2:OnQuestTurnedIn("QUEST_TURNED_IN", 1235, 120)
AceM2L2:HandleXPText("Defias Pillager dies, you gain 95 experience.")
state.xp = state.xp + 120
AceM2L2:HandlePlayerXPUpdate()
RunTimers()
local mixedText = table.concat(DEFAULT_CHAT_FRAME.messages, "\n")
assert(mixedText:find("quests to level", 1, true), "mixed quest reward not labeled quest")
assert(not mixedText:find("Defias Pillager", 1, true), "mixed quest reused kill name")
local mixedQuest = module.char.quests and module.char.quests["quest:1235"]
assert(mixedQuest and mixedQuest.count == 1 and mixedQuest.totalXP == 120,
  "mixed quest reward not recorded")

state.xp = savedQuestState.xp
AceM2L2.lastXP = savedQuestState.lastXP
AceM2L2.xpSamples = savedQuestState.samples
AceM2L2.xpKillCounter = savedQuestState.counter
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
AceM2L2:ClearQuestXPWindow()

-- Quest XP ledger (P-3).
module:ResetKills()
DEFAULT_CHAT_FRAME.messages = {}
AceM2L2.lastXP = state.xp
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
AceM2L2:OnQuestTurnedIn("QUEST_TURNED_IN", 4321, 250)
state.xp = state.xp + 250
AceM2L2:HandleXPText("You gain 250 experience.")
AceM2L2:HandlePlayerXPUpdate()
RunTimers()
local questGains, questXP = module:GetQuestSummary()
assert(questGains == 1 and questXP == 250, "quest summary mismatch")
local questEntry = module.char.quests and module.char.quests["quest:4321"]
assert(questEntry and questEntry.id == 4321, "quest ID not recorded")
assert(questEntry.count == 1 and questEntry.totalXP == 250 and questEntry.lastXP == 250,
  "quest totals mismatch")
assert(questEntry.name == "Unknown quest", "quest fallback name mismatch")
assert(type(questEntry.firstSeen) == "number" and questEntry.firstSeen > 0,
  "quest firstSeen missing")
assert(AceM2L2CharDB.xpTooltip.quests == nil, "quest data leaked to root namespace")
assert(module.char.quests == AceM2L2CharDB.xpTooltip.clients[18].quests,
  "quest data not stored per client")

AceM2L2.lastXP = state.xp
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
AceM2L2:OnQuestTurnedIn("QUEST_TURNED_IN", nil, 80)
state.xp = state.xp + 80
AceM2L2:HandleXPText("You gain 80 experience.")
AceM2L2:HandlePlayerXPUpdate()
RunTimers()
local unknownQuest = module.char.quests and module.char.quests["quest:unknown"]
assert(unknownQuest and unknownQuest.count == 1 and unknownQuest.totalXP == 80,
  "unknown quest not bucketed")
questGains, questXP = module:GetQuestSummary()
assert(questGains == 2 and questXP == 330, "mixed quest summary mismatch")

local savedPrint = AceM2L2.Print
local questMessages = {}
AceM2L2.Print = function(_, message)
  questMessages[#questMessages + 1] = tostring(message)
end
module:HandleCommand("quests")
AceM2L2.Print = savedPrint
assert(table.concat(questMessages, "\n"):find("Quest XP:", 1, true),
  "quest command missing summary")

module:ResetKills()
assert(next(module.char.quests) == nil, "reset did not clear quest XP ledger")

-- Kill tracking and reconciliation.
module:ResetKills()
ResetTarget()
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
local db = module.char
local mob = db.mobs["npc:1234"]
assert(mob and mob.kills == 1, "chat kill not recorded")
assert(db.totals.kills == 1 and db.areas["12"] == 1 and db.levels["10"] == 1,
  "chat kill aggregates mismatch")
AssertAggregateInvariant("chat kill")

module:ResetKills()
ResetTarget()
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
assert(module.char.mobs["npc:1234"] and module.char.mobs["npc:1234"].kills == 1,
  "death kill not recorded")

module:ResetKills()
ResetTarget()
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(0.5)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
SetTarget("Defias Pillager", GUID_B)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnUnitDied("UNIT_DIED", GUID_B)
AdvanceTime(2.5)
mob = module.char.mobs["npc:1234"]
assert(mob.kills == 2, "same-name different-GUID deaths merged")
assert(mob.totalXP == 95, "same-name different-GUID XP mismatch")

local savedCountZero = module:GetSettings().countZeroXPMobs
module:GetSettings().countZeroXPMobs = false
module:ResetKills()
ResetTarget()
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
assert(module.char.totals.kills == 0, "countZero=false counted a death")
AdvanceTime(0.1)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
mob = module.char.mobs["npc:1234"]
assert(mob and mob.kills == 1 and mob.totalXP == 95, "late chat XP lost")

module:GetSettings().countZeroXPMobs = true
module:ResetKills()
ResetTarget()
module:OnUnitDied("UNIT_DIED", GUID_A)
AdvanceTime(2.5)
AdvanceTime(0.6)
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
mob = module.char.mobs["npc:1234"]
assert(mob.kills == 1 and mob.totalXP == 95, "late chat created a second kill")
assert((mob.xp.samples or 0) == 1, "late chat sample missing")

module:ResetKills()
ResetTarget()
module:OnUnitDied("UNIT_DIED", GUID_A)
module:SetUserEnabled(false)
module:SetUserEnabled(true)
AdvanceTime(5)
assert(module.char.totals.kills == 0, "pending death committed after re-enable")
module:GetSettings().countZeroXPMobs = savedCountZero

-- Accounting: prune/delete/merge invariants.
module:ResetKills()
local mergeDB = module.char
for index = 1, 2002 do
  local key = string.format("npc:%05d", index)
  mergeDB.mobs[key] = {
    name = "Prune Mob " .. index,
    npcID = index,
    classification = "normal",
    kills = 1, sessionKills = 1, totalXP = 95, sessionXP = 95, sessionXPKnown = true,
    killsAtLevel = { ["10"] = 1 }, killsByMap = { ["12"] = 1 },
    killsByAreaLevel = { ["12"] = { ["10"] = 1 } },
    contexts = {}, xp = { samples = 1, sumBase = 95, sumBuffed = 95, sumTotal = 95 },
    firstSeen = 1, lastSeen = 1,
  }
end
mergeDB.totals = { kills = 2002, xp = 2002 * 95, uniqueMobs = 2002 }
mergeDB.session = { startedAt = 1, kills = 2002, xp = 2002 * 95 }
mergeDB.levels = { ["10"] = 2002 }
mergeDB.areas = { ["12"] = 2002 }
mergeDB.areaLevels = { ["12"] = { ["10"] = 2002 } }
AssertAggregateInvariant("prune setup")
module:Prune()
assert(mergeDB.totals.uniqueMobs == 2000, "prune cap mismatch")
assert(mergeDB.mobs["npc:00001"] == nil and mergeDB.mobs["npc:00002"] == nil,
  "prune eviction not deterministic")
AssertAggregateInvariant("after prune")

module:ResetKills()
local deleteDB = module.char
deleteDB.mobs["npc:90001"] = {
  name = "Delete", npcID = 90001, classification = "normal",
  kills = 2, sessionKills = 2, totalXP = 200, sessionXP = 200, sessionXPKnown = true,
  killsAtLevel = { ["10"] = 2 }, killsByMap = { ["12"] = 2 },
  killsByAreaLevel = { ["12"] = { ["10"] = 2 } },
  contexts = {}, xp = { samples = 2, sumBase = 200, sumBuffed = 200, sumTotal = 200 },
  firstSeen = 1, lastSeen = 1,
}
deleteDB.totals = { kills = 2, xp = 200, uniqueMobs = 1 }
deleteDB.session = { startedAt = 1, kills = 2, xp = 200 }
deleteDB.levels = { ["10"] = 2 }
deleteDB.areas = { ["12"] = 2 }
deleteDB.areaLevels = { ["12"] = { ["10"] = 2 } }
module:RemoveMobEntry("npc:90001")
assert(deleteDB.totals.kills == 0 and deleteDB.totals.xp == 0, "delete totals mismatch")
assert(deleteDB.levels["10"] == 0 and deleteDB.areas["12"] == 0, "delete breakdown mismatch")
AssertAggregateInvariant("after delete")

-- Tooltip and UI.
module:ResetKills()
ResetTarget()
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local tooltip = table.concat(GameTooltip.lines, "\n")
assert(tooltip:find("XP:", 1, true), "Forever tooltip missing XP")
assert(tooltip:find("Killed:", 1, true), "Forever tooltip missing kill count")
assert(tooltip:find("Kills to level:", 1, true), "Forever tooltip missing kills-to-level")
assert(tooltip:find("XP remaining:", 1, true), "Forever tooltip missing XP remaining")
assert(tooltip:find("Level:", 1, true), "Forever tooltip missing mob level")
local savedShowMobLevel = module:GetSettings().showMobLevel
module:GetSettings().showMobLevel = false
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
assert(not table.concat(GameTooltip.lines, "\n"):find("Level:", 1, true),
  "showMobLevel=false still rendered mob level")
module:GetSettings().showMobLevel = savedShowMobLevel
local savedShowXPRemaining = module:GetSettings().showXPRemaining
module:GetSettings().showXPRemaining = false
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
assert(not table.concat(GameTooltip.lines, "\n"):find("XP remaining:", 1, true),
  "showXPRemaining=false still rendered remaining XP")
module:GetSettings().showXPRemaining = savedShowXPRemaining

module:RecordQuestXP(777, "Test Quest", 300)
module:OpenUI()
module:SetTab("overview")
assert(module.ui.overview.levelText.text:find("Quest XP:", 1, true),
  "Overview missing quest XP summary")
assert(module.ui.overview.levelText.text:find("XP remaining:", 1, true),
  "Overview missing XP remaining")
module:SetTab("mobs")
module:BuildList()
assert(#module.currentList >= 1, "mob list empty")
module:SelectIndex(1)
assert(module.ui.heroName.text == "Defias Pillager", "mob detail name mismatch")
assert(module.ui.modelHolder.shown, "mob model holder hidden")
module:SetTab("areas")
module:SelectIndex(1)
assert(not module.ui.modelHolder.shown, "area model holder shown")
module:SetTab("levels")
module:SelectIndex(1)
assert(not module.ui.modelHolder.shown, "level model holder shown")

assert(pcall(function() module:HandleCommand("status") end), "status command failed")
assert(pcall(function() module:HandleCommand("probe") end), "probe command failed")
assert(pcall(function() module:HandleCommand("stats") end), "stats command failed")
assert(pcall(function() module:HandleCommand("table") end), "table command failed")

-- Buffs, group tooltip, calibration, settings, minimap, cleanup.
assert(math.abs(module:GetBuffMultiplier(true, true) - 1.0815) < 0.0001,
  "Well Fed + Well-Rested multiplier mismatch")
assert(math.abs(module:GetBuffMultiplier(true, true, 2) - 1.071) < 0.0001,
  "Well-Rested stack multiplier mismatch")

-- XP bonus panel (P-4).
local savedFindAura = AuraUtil.FindAuraByName
module.buffCacheTime = nil
local noBonuses = module:GetActiveXPBonuses()
assert(#noBonuses == 0, "inactive XP bonuses displayed")
assert(module:FormatXPBonuses(noBonuses, 0) == nil, "empty bonus text rendered")

AuraUtil.FindAuraByName = function(name)
  if name == "Well Fed" then
    return { name = "Well Fed" }
  end
  if name == "Well-Rested" then
    return { name = "Well-Rested", applications = 2 }
  end
  return nil
end
module.buffCacheTime = nil
local bonuses, bonusMultiplier, bonusPercent = module:GetActiveXPBonuses()
assert(#bonuses == 2, "expected Well Fed and Well-Rested bonuses")
assert(bonuses[1].id == "wellFed" and bonuses[1].percent == 5, "Well Fed bonus mismatch")
assert(bonuses[2].id == "wellRested" and bonuses[2].percent == 2, "Well-Rested stack mismatch")
assert(math.abs(bonusMultiplier - (1.05 * 1.02)) < 0.0001, "bonus multiplier mismatch")
assert(math.abs(bonusPercent - 7.1) < 0.0001, "bonus total percent mismatch")
local bonusText = module:FormatXPBonuses(bonuses, bonusPercent)
assert(bonusText:find("Well Fed +5%", 1, true), "bonus text missing Well Fed")
assert(bonusText:find("Well-Rested +2%", 1, true), "bonus text missing Well-Rested")
assert(bonusText:find("total +7.10%", 1, true), "bonus text missing total")

module:GetSettings().manualXPBonus = 10
local allBonuses, allMultiplier = module:GetActiveXPBonuses()
assert(#allBonuses == 3 and allBonuses[3].id == "manual" and allBonuses[3].percent == 10,
  "manual bonus missing")
assert(math.abs(allMultiplier - (1.05 * 1.02 * 1.10)) < 0.0001,
  "manual bonus multiplier mismatch")
module:GetSettings().manualXPBonus = 0

GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
assert(table.concat(GameTooltip.lines, "\n"):find("XP bonuses:", 1, true),
  "tooltip missing XP bonuses")
module:OpenUI()
module:SetTab("overview")
assert(module.ui.overview.levelText.text:find("XP bonuses:", 1, true),
  "overview missing XP bonuses")

local savedShowXPBonuses = module:GetSettings().showXPBonuses
module:GetSettings().showXPBonuses = false
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
assert(not table.concat(GameTooltip.lines, "\n"):find("XP bonuses:", 1, true),
  "showXPBonuses=false still rendered bonuses")
module:GetSettings().showXPBonuses = savedShowXPBonuses
AuraUtil.FindAuraByName = savedFindAura
module.buffCacheTime = nil

-- Food/camping IDs verified online (P-5).
local Util = AceM2L2.KillHistory.Util
assert(Util.VERIFIED_BUFF_IDS.wellFedXP == 1243969, "Well Fed XP Boost ID mismatch")
assert(Util.VERIFIED_BUFF_IDS.wellRested == 429959, "Well-Rested ID mismatch")
assert(Util.VERIFIED_BUFF_IDS.campTent == 1307230, "Camp Tent ID mismatch")
assert(Util.VERIFIED_BUFF_IDS.boostedRest == 1229451, "Boosted Rest ID mismatch")
assert(not module:Supports("hasCozySleepingBag") and not module:Supports("hasCampfireBonus"),
  "removed speculative food/camping capabilities returned true")

-- Forever food uses a distinct aura name; match it by the verified spell ID.
AuraUtil.FindAuraByName = function(name)
  if name == "Well Fed" then
    return { name = "Well Fed XP Boost", spellId = 1243969 }
  end
  return nil
end
module.buffCacheTime = nil
local foodBonuses, foodMultiplier = module:GetActiveXPBonuses()
assert(#foodBonuses == 1 and foodBonuses[1].id == "wellFed"
  and foodBonuses[1].percent == 5, "Well Fed XP Boost not detected by spell ID")
assert(math.abs(foodMultiplier - 1.05) < 0.0001, "Well Fed XP Boost multiplier mismatch")

-- Cozy Sleeping Bag grants the same Well-Rested aura, so it must appear once.
AuraUtil.FindAuraByName = function(name)
  if name == "Well-Rested" then
    return { name = "Well-Rested", spellId = 429959, applications = 3 }
  end
  return nil
end
module.buffCacheTime = nil
local restedBonuses = module:GetActiveXPBonuses()
assert(#restedBonuses == 1 and restedBonuses[1].id == "wellRested"
  and restedBonuses[1].percent == 3, "Cozy/Well-Rested double count")
AuraUtil.FindAuraByName = savedFindAura
module.buffCacheTime = nil

module:ResetKills()
ResetTarget()
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
state.groupSize = 2
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
assert(table.concat(GameTooltip.lines, "\n"):find("group share; solo", 1, true),
  "group tooltip missing share/solo")
state.groupSize = 1

local calibration = module.char.calibration
local baseEstimate = module:GetEstimate(10, 10, "normal", 12, 1, "npc:none", "none")
calibration.mobs["npc:9999"] = { ratio = 0.8, samples = 5, updated = 0 }
calibration.classes.normal = { ratio = 1.2, samples = 5, updated = 0 }
local corrected = module:GetEstimate(10, 10, "normal", 12, 1, "npc:9999", "none")
assert(corrected < baseEstimate, "mob calibration not applied")
calibration.mobs["npc:9999"] = nil
calibration.classes.normal = nil

local savedSettings = AceM2L2DB.profile.xpTooltip
AceM2L2DB.profile.xpTooltip = { theme = "dark" }
module.settings = nil
local mergedSettings = module:GetSettings()
assert(mergedSettings.enabled == true and mergedSettings.ui.width == 1150,
  "partial settings did not merge defaults")
assert(type(mergedSettings.minimap) == "table" and mergedSettings.minimap.hide == false,
  "partial settings did not merge minimap defaults")
AceM2L2DB.profile.xpTooltip = savedSettings
module.settings = savedSettings

-- Settings page organization and the mob-level toggle.
local savedSettingsGlobal = Settings
local savedHeaderGlobal = CreateSettingsListSectionHeaderInitializer
local savedOptionsCategory = AceM2L2.optionsCategory
local savedOptionSettings = AceM2L2.optionSettings
local savedOptionsFailed = AceM2L2.optionsFailed
local settingsMock = { categories = {}, settings = {} }
local function NewMockCategory(name, parent)
  local category = { name = name, parent = parent, controls = {} }
  local layout = { initializers = {} }
  function layout:AddInitializer(initializer)
    self.initializers[#self.initializers + 1] = initializer
  end
  category.layout = layout
  settingsMock.categories[#settingsMock.categories + 1] = category
  return category, layout
end
Settings = {
  RegisterVerticalLayoutCategory = function(name)
    return NewMockCategory(name)
  end,
  RegisterVerticalLayoutSubcategory = function(parent, name)
    return NewMockCategory(name, parent)
  end,
  RegisterAddOnCategory = function(category)
    category.registered = true
  end,
  RegisterProxySetting = function(category, variable, valueType, name, defaultValue, getter, setter)
    local setting = {
      category = category, variable = variable, valueType = valueType, name = name,
      defaultValue = defaultValue, getter = getter, setter = setter,
    }
    function setting:GetVariable() return self.variable end
    category.controls[#category.controls + 1] = setting
    settingsMock.settings[#settingsMock.settings + 1] = setting
    return setting
  end,
  CreateCheckbox = function(category, setting, tooltip)
    local initializer = { kind = "checkbox", setting = setting, tooltip = tooltip, tags = {} }
    function initializer:AddSearchTags(...)
      for index = 1, select("#", ...) do
        self.tags[#self.tags + 1] = select(index, ...)
      end
    end
    category.controls[#category.controls + 1] = initializer
    return initializer
  end,
  CreateSliderOptions = function(minValue, maxValue, step)
    return {
      minValue = minValue, maxValue = maxValue, step = step,
      SetLabelFormatter = function() end,
    }
  end,
  CreateSlider = function(category, setting, options, tooltip)
    local initializer = { kind = "slider", setting = setting, options = options, tooltip = tooltip }
    category.controls[#category.controls + 1] = initializer
    return initializer
  end,
  NotifyUpdate = function() end,
}
CreateSettingsListSectionHeaderInitializer = function(text)
  return { kind = "header", text = text }
end

AceM2L2.optionsCategory = nil
AceM2L2.optionSettings = nil
AceM2L2.optionsFailed = false
AceM2L2:CreateOptionsPanel()
local mainCategory = settingsMock.categories[1]
assert(mainCategory and mainCategory.name == "Ace Mobs 2 Level 2 - Kill Story", "options main category missing")
assert(AceM2L2.optionsCategory == mainCategory, "options category not stored")
local tooltipCategory
for _, category in ipairs(settingsMock.categories) do
  if category.name == "Tooltip" then
    tooltipCategory = category
  end
end
assert(tooltipCategory and tooltipCategory.parent == mainCategory, "tooltip subcategory missing")
assert(tooltipCategory.registered, "tooltip subcategory not registered")
local heatmapCategory
for _, category in ipairs(settingsMock.categories) do
  if category.name == "Heatmap" then
    heatmapCategory = category
  end
end
assert(heatmapCategory and heatmapCategory.parent == mainCategory,
  "heatmap subcategory missing")
assert(heatmapCategory.registered, "heatmap subcategory not registered")

local function HasHeader(category, text)
  for _, initializer in ipairs(category.layout.initializers) do
    if initializer.text == text then
      return true
    end
  end
  return false
end
assert(HasHeader(mainCategory, "Chat messages"), "missing Chat messages header")
assert(HasHeader(mainCategory, "Kill Story"), "missing Kill Story header")
assert(HasHeader(mainCategory, "Diagnostics"), "missing Diagnostics header")
assert(HasHeader(tooltipCategory, "XP lines"), "missing XP lines header")
assert(HasHeader(tooltipCategory, "Kill lines"), "missing Kill lines header")
assert(HasHeader(tooltipCategory, "Rested and bonuses"), "missing Rested header")
assert(HasHeader(tooltipCategory, "Edge cases"), "missing Edge cases header")
assert(HasHeader(heatmapCategory, "Display"), "missing heatmap display header")
local function FindSetting(name)
  for _, setting in ipairs(settingsMock.settings) do
    if setting.name == name then
      return setting
    end
  end
end
for _, name in ipairs({ "Show heatmap tab", "Reveal unexplored areas",
  "Heatmap intensity", "Warm heat colors" }) do
  local setting = FindSetting(name)
  assert(setting and setting.category == heatmapCategory,
    name .. " is not on the Heatmap page")
end
if SCENARIO == "forever" then
  local grindingSetting = FindSetting("Show grinding spot")
  assert(grindingSetting and grindingSetting.category == tooltipCategory,
    "grinding spot setting should remain on the Tooltip page")
end

local mobLevelSetting, mobLevelInitializer
for _, setting in ipairs(settingsMock.settings) do
  if setting.name == "Show mob level" then
    mobLevelSetting = setting
  end
end
for _, control in ipairs(tooltipCategory.controls) do
  if control.kind == "checkbox" and control.setting == mobLevelSetting then
    mobLevelInitializer = control
  end
end
assert(mobLevelSetting and mobLevelSetting.category == tooltipCategory,
  "Show mob level setting missing or on wrong page")
assert(mobLevelInitializer, "Show mob level checkbox missing")
assert(mobLevelInitializer.tags[1] == "mob level", "mob level search tag missing")
assert(mobLevelSetting.getter() == true, "mob level default mismatch")
mobLevelSetting.setter(false)
assert(module:GetSettings().showMobLevel == false, "mob level setting did not persist")
mobLevelSetting.setter(true)

Settings = savedSettingsGlobal
CreateSettingsListSectionHeaderInitializer = savedHeaderGlobal
AceM2L2.optionsCategory = savedOptionsCategory
AceM2L2.optionSettings = savedOptionSettings
AceM2L2.optionsFailed = savedOptionsFailed

module:HandleCommand("minimap off")
assert(module:GetSettings().minimap.hide == true and minimapMock.hidden == true,
  "minimap off failed")
module:HandleCommand("minimap on")
assert(module:GetSettings().minimap.hide == false and minimapMock.hidden == false,
  "minimap on failed")

module.char.mobs["name:unknown"] = {
  name = "Unknown", kills = 0, sessionKills = 0, totalXP = 0, sessionXP = 0,
  killsAtLevel = {}, killsByMap = {}, killsByAreaLevel = {}, contexts = {},
  xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0 },
  firstSeen = 1, lastSeen = 1,
}
module:DeleteUnknownEntries()
assert(module.char.mobs["name:unknown"] == nil, "Unknown cleanup failed")

local savedUnitName, savedUnitToken = GameTooltip.unitName, GameTooltip.unitToken
GameTooltip.unitName, GameTooltip.unitToken = nil, nil
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, { unitToken = "target" })
assert(#GameTooltip.lines > 0, "tooltip did not use data.unitToken")
SetMouseover("Defias Pillager", GUID_A)
module.lastMouseover = module:CaptureUnit("mouseover")
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, { guid = "Creature-0-1-2-3-1234-99999999" })
assert(#GameTooltip.lines == 0, "tooltip fell back to mouseover without a unit token")
GameTooltip.unitName, GameTooltip.unitToken = savedUnitName, savedUnitToken
module.lastMouseover = nil

-- Overlapping merge keeps counts and observations consistent.
module:ResetKills()
local merge = module.char
merge.mobs["name:merge"] = {
  name = "Merge", kills = 10, sessionKills = 0, totalXP = 1000, sessionXP = 0,
  sessionXPKnown = false, killsAtLevel = { ["10"] = 10 }, killsByMap = { ["12"] = 10 },
  killsByAreaLevel = { ["12"] = { ["10"] = 10 } }, contexts = {},
  xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0 },
  firstSeen = 100, lastSeen = 200, classification = "normal",
}
merge.mobs["npc:91001"] = {
  name = "Merge", npcID = 91001, kills = 10, sessionKills = 0, totalXP = 1000, sessionXP = 0,
  sessionXPKnown = false, killsAtLevel = { ["11"] = 10 }, killsByMap = { ["12"] = 10 },
  killsByAreaLevel = { ["12"] = { ["11"] = 10 } }, contexts = {},
  xp = { samples = 0, sumBase = 0, sumBuffed = 0, sumTotal = 0 },
  firstSeen = 150, lastSeen = 250, classification = "normal",
}
merge.totals = { kills = 20, xp = 2000, uniqueMobs = 2 }
merge.session = { startedAt = 1, kills = 0, xp = 0 }
merge.levels = { ["10"] = 10, ["11"] = 10 }
merge.areas = { ["12"] = 20 }
merge.areaLevels = { ["12"] = { ["10"] = 10, ["11"] = 10 } }
module:MergeMobEntries("name:merge", "npc:91001", true)
local merged = merge.mobs["npc:91001"]
assert(merged and merged.kills == 10, "merge kill mismatch")
assert((tonumber(merge.levels["10"]) or 0) == 0, "merge kept losing level")
assert((tonumber(merge.levels["11"]) or 0) == 10, "merge lost winner level")
AssertAggregateInvariant("after merge")

-- Forever and Midnight data stay isolated.
AceM2L2CharDB.xpTooltip.clients[1] = {
  dataSchema = 1, mobs = { ["npc:1"] = { name = "Midnight Only", kills = 1 } },
  totals = { kills = 1, xp = 0, uniqueMobs = 1 }, session = { kills = 1, xp = 0 },
  levels = { ["10"] = 1 }, areas = { ["12"] = 1 }, areaLevels = { ["12"] = { ["10"] = 1 } },
  calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} },
  calibrationVersion = 2,
}
module:EnsureDB()
assert(module.char == AceM2L2CharDB.xpTooltip.clients[18], "client data switched")
assert(module.char.mobs["npc:1"] == nil, "Midnight data leaked into Forever")

-- Malformed legacy fields are normalized without key conversion.
local savedMalformedRoot = AceM2L2CharDB.xpTooltip
AceM2L2CharDB.xpTooltip = {
  storageSchema = 2,
  clients = {
    [18] = {
      dataSchema = 1,
      calibrationVersion = 2,
      mobs = { ["npc:1"] = { name = "Malformed", kills = "3", totalXP = "50" } },
    },
  },
}
module.char = nil
module:EnsureDB()
local malformed = module.char.mobs["npc:1"]
assert(malformed.kills == 3 and malformed.totalXP == 50, "malformed counters not normalized")
assert(type(malformed.killsAtLevel) == "table" and type(malformed.contexts) == "table",
  "malformed maps not normalized")
assert(module.char.mobs["npc:1"] ~= nil, "mob key was converted")
AceM2L2CharDB.xpTooltip = savedMalformedRoot
module.char = nil
module:EnsureDB()

-- Migration and backup.
local savedRoot = AceM2L2CharDB.xpTooltip
local legacy = {
  schema = 1,
  mobs = { ["npc:4242"] = {
    name = "Legacy", kills = 7, sessionKills = 2, totalXP = 700, sessionXP = 200,
    sessionXPKnown = true, killsAtLevel = { ["10"] = 7 }, killsByMap = { ["12"] = 7 },
    killsByAreaLevel = { ["12"] = { ["10"] = 7 } }, contexts = {},
    xp = { samples = 2, sumBase = 190, sumBuffed = 190, sumTotal = 190 },
    firstSeen = 1, lastSeen = 2, classification = "normal",
  } },
  areas = { ["12"] = 7 }, levels = { ["10"] = 7 }, areaLevels = { ["12"] = { ["10"] = 7 } },
  totals = { kills = 7, xp = 700, uniqueMobs = 1 },
  session = { startedAt = 1, kills = 2, xp = 200 },
  calibration = { zones = {}, levels = {}, groups = {}, classes = {}, mobs = {} },
  calibrationVersion = 2,
}
AceM2L2CharDB.xpTooltip = legacy
module.char = nil
module:EnsureDB()
local migrated = AceM2L2CharDB.xpTooltip
assert(migrated.storageSchema == 2, "migration storage schema missing")
assert(migrated.clients[18].mobs["npc:4242"].kills == 7, "migration lost kills")
assert(module:HasMigrationBackup(), "migration backup missing")
local backup = module:GetMigrationBackup()
assert(backup.data.mobs["npc:4242"].kills == 7, "backup data missing")
local backupAt = backup.createdAt
module:EnsureDB()
assert(module:GetMigrationBackup() == backup and backup.createdAt == backupAt,
  "migration backup not idempotent")

-- Future schema is read-only.
local future = { storageSchema = 3, clients = { [18] = { dataSchema = 2, mobs = {} } } }
AceM2L2CharDB.xpTooltip = future
module.char = nil
module:EnsureDB()
assert(module.schemaBlocked, "future schema not blocked")
assert(future.storageSchema == 3, "future storage schema rewritten")
assert(module:GetStatusText():find("blocked", 1, true), "blocked status missing")

AceM2L2CharDB.xpTooltip = savedRoot
module.char = nil
module:EnsureDB()
assert(not module.schemaBlocked, "schema block not cleared")

-- Level history (P-6).
state.playerLevel = 10
module:ResetKills()
local levelRecord = module:GetCurrentLevelRecord(false)
assert(levelRecord and levelRecord.level == 10 and levelRecord.endedAt == 0,
  "level history did not start a current record")
assert(levelRecord.xpGained == 0 and levelRecord.kills == 0,
  "level history current record not empty")

ResetTarget()
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
levelRecord = module:GetCurrentLevelRecord(false)
assert(levelRecord.kills == 1 and levelRecord.xpGained == 95,
  "level history kill XP mismatch")

AceM2L2.lastXP = state.xp
AceM2L2.lastCreatureName = nil
AceM2L2.lastXPSource = nil
AceM2L2.lastXPInfoTime = 0
AceM2L2.lastChatXPAmount = nil
AceM2L2:OnQuestTurnedIn("QUEST_TURNED_IN", 5150, 55)
state.xp = state.xp + 55
AceM2L2:HandleXPText("You gain 55 experience.")
AceM2L2:HandlePlayerXPUpdate()
RunTimers()
levelRecord = module:GetCurrentLevelRecord(false)
assert(levelRecord.xpGained == 150, "level history quest XP mismatch")

AdvanceTime(65)
state.playerLevel = 11
module:OnLevelUp("PLAYER_LEVEL_UP", 11)
local levelRecords = module:NormalizeLevelHistory()
local finishedLevel = levelRecords[#levelRecords - 1]
local activeLevel = levelRecords[#levelRecords]
assert(activeLevel.level == 11 and activeLevel.endedAt == 0, "level-up did not open a record")
assert(finishedLevel.level == 10 and finishedLevel.endedAt > 0,
  "level-up did not finalize the record")
assert(finishedLevel.duration >= 60, "level history duration missing")
assert(finishedLevel.kills == 1 and finishedLevel.xpGained == 150,
  "finalized level history totals mismatch")

local historyMessages = {}
local savedHistoryPrint = AceM2L2.Print
AceM2L2.Print = function(_, message)
  historyMessages[#historyMessages + 1] = tostring(message)
end
module:HandleCommand("history")
module:HandleCommand("history 10")
AceM2L2.Print = savedHistoryPrint
local historyText = table.concat(historyMessages, "\n")
assert(historyText:find("Level 10", 1, true), "history command missing level")
assert(historyText:find("150 XP", 1, true), "history command missing XP")
assert(historyText:find("Level history (level 10)", 1, true),
  "history level filter missing")

module:OpenUI()
module:SetTab("overview")
assert(module.ui.overview.levelText.text:find("Level history:", 1, true),
  "overview missing level history")
assert(module.ui.overview.levelText.text:find("150 XP", 1, true),
  "overview level history missing XP")

module:ResetKills()
levelRecords = module:NormalizeLevelHistory()
assert(#levelRecords == 1 and levelRecords[1].level == 11 and levelRecords[1].endedAt == 0,
  "reset did not restart level history")
state.playerLevel = 10
module:EnsureLevelHistory()

-- Rates, dungeon classification, goals, economy, world data, and nameplates.
state.money = 0
module:ResetKills()

local savedTestXP, savedTestXPMax = state.xp, state.xpMax
state.xp, state.xpMax = 0, 7600
module:ResetRates()
module:RecordRateSample(100, "kill")
AdvanceTime(60)
module:RecordRateSample(200, "kill")
local xpPerHour, xpPerMinute, rateElapsed = module:GetXPRate(600)
assert(xpPerHour and math.abs(xpPerHour - 12000) < 0.001
  and math.abs(xpPerMinute - 200) < 0.001 and rateElapsed == 60,
  "rate sample aggregation mismatch")
local secondsToLevel = module:GetTimeToLevel(600)
assert(secondsToLevel and math.abs(secondsToLevel - 2280) < 0.001,
  "time-to-level from XP rate mismatch")
state.xp, state.xpMax = savedTestXP, savedTestXPMax

state.inInstance, state.instanceType = true, "party"
ResetTarget()
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
local dungeon = module.char.dungeon
assert(dungeon.kills == 1 and dungeon.xp == 95 and dungeon.lastInstance == 12,
  "dungeon kill not classified")
state.inInstance, state.instanceType = false, nil
SetTarget("Defias Pillager", GUID_B)
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
assert(dungeon.kills == 1 and dungeon.xp == 95 and module.char.totals.kills == 2,
  "world kill entered the dungeon bucket")

module:HandleCommand("goal set 20")
assert(module.char.goal.targetLevel == 20
  and module.char.goal.targetXP == module.char.totals.xp,
  "leveling goal not set")
module:HandleCommand("goal clear")
assert(module.char.goal.targetLevel == 0 and module.char.goal.createdAt == 0,
  "leveling goal not cleared")

state.money = 50000
module:HandleMoneyChanged()
state.money = 20000
module:HandleMoneyChanged()
local economy = module.char.economy
assert(economy.goldGained == 50000 and economy.goldSpent == 30000,
  "money delta tracking mismatch")
module:HandleLootMessage(
  "You receive loot: |cff9d9d9d|Hitem:12345::::::::|h[Test Item]|h|r x2.",
  "Tester")
economy = module.char.economy
assert(economy.lootValue == 500 and economy.items == 2,
  "loot value tracking mismatch")

module:ResetKills()
state.mapID, state.mapX, state.mapY = 12, 0.1, 0.9
module:HandlePlayerDeath()
local deaths = module.char.deaths
assert(#deaths == 1 and deaths[1].mapID == 12
  and math.abs(deaths[1].x - 0.1) < 0.001 and math.abs(deaths[1].y - 0.9) < 0.001,
  "death location not recorded")
module:RecordRespawnInterval(1234, "Defias Pillager", 300)
module:RecordRespawnInterval(1234, "Defias Pillager", 300)
module:RecordRespawnInterval(1234, "Defias Pillager", 300)
local averageRespawn, respawnSamples = module:GetRespawnStats(1234)
assert(respawnSamples == 3 and averageRespawn == 300,
  "respawn interval not recorded")

assert(module.HEATMAP_GRID_SIZE == 64 and module.HEATMAP_CELLS == 4096,
  "heatmap grid is not 64x64")
module:ResetHeatmaps()
assert(module:RecordHeatmapKill(12, 0.25, 0.75), "heatmap kill not captured")
local heatmapZones = module:GetHeatmapZones()
assert(#heatmapZones == 1 and heatmapZones[1].mapID == 12
  and heatmapZones[1].total == 1, "heatmap zones mismatch")
assert(heatmapZones[1].gridSize == 64, "heatmap gridSize not stored")
local expectedHeatCell = math.floor(0.75 * 64) * 64 + math.floor(0.25 * 64) + 1
assert(heatmapZones[1].cells[expectedHeatCell] == 1,
  "heatmap cell was not captured at 64x64")
local cachedHeatmaps = module:NormalizeHeatmaps()
assert(module:NormalizeHeatmaps() == cachedHeatmaps,
  "normalized heatmap view was not reused")

-- 32x32 data must split into 2x2 blocks at 64x64.
module:ResetHeatmaps()
module.char.heatmaps["12"] = {
  gridSize = 32,
  cells = { [1] = 4 },
  total = 4,
  lastSeen = 1,
}
module:InvalidateHeatmapCache()
heatmapZones = module:GetHeatmapZones()
assert(heatmapZones[1].gridSize == 64 and heatmapZones[1].total == 4,
  "32x32 heatmap migration metadata mismatch")
for _, cell in ipairs({ 1, 2, 65, 66 }) do
  assert(heatmapZones[1].cells[cell] == 1,
    "32x32 heatmap migration lost cell " .. tostring(cell))
end

-- Legacy 16x16 data must split into 4x4 blocks at 64x64.
module:ResetHeatmaps()
module.char.heatmaps["12"] = {
  cells = { [1] = 16 },
  total = 16,
  lastSeen = 1,
}
module:InvalidateHeatmapCache()
heatmapZones = module:GetHeatmapZones()
assert(heatmapZones[1].gridSize == 64 and heatmapZones[1].total == 16,
  "legacy heatmap migration metadata mismatch")
local legacyCells = 0
for cell, count in pairs(heatmapZones[1].cells) do
  local row = math.floor((cell - 1) / 64)
  local col = (cell - 1) % 64
  assert(row >= 0 and row < 4 and col >= 0 and col < 4,
    "legacy heatmap migration placed a cell outside the 4x4 block")
  assert(count == 1, "legacy heatmap migration split count incorrectly")
  legacyCells = legacyCells + 1
end
assert(legacyCells == 16, "legacy heatmap migration cell count mismatch")

-- A 64x64 entry must copy through unchanged.
module:ResetHeatmaps()
module.char.heatmaps["12"] = {
  gridSize = 64,
  cells = { [4096] = 3 },
  total = 3,
  lastSeen = 1,
}
module:InvalidateHeatmapCache()
heatmapZones = module:GetHeatmapZones()
assert(heatmapZones[1].cells[4096] == 3 and heatmapZones[1].total == 3,
  "64x64 heatmap data was not preserved")

-- Legacy remainder distribution: 17 kills in one 16x16 cell must split into
-- sixteen 64x64 cells (one of them holding the extra kill), not lose a kill.
module:ResetHeatmaps()
module.char.heatmaps["12"] = {
  gridSize = 16,
  cells = { [1] = 17 },
  lastSeen = 1,
}
module:InvalidateHeatmapCache()
local splitZone = module:GetHeatmapZones()[1]
local splitSum, splitCells, splitDoubled = 0, 0, 0
for _, count in pairs(splitZone.cells) do
  splitSum = splitSum + count
  splitCells = splitCells + 1
  if count == 2 then
    splitDoubled = splitDoubled + 1
  end
end
assert(splitZone.total == 17 and splitSum == 17 and splitCells == 16
  and splitDoubled == 1, "legacy heatmap remainder distribution mismatch")

-- Duplicate numeric/string map keys merge into one zone; lastSeen keeps the
-- newest sighting and cells add together.
module:ResetHeatmaps()
module.char.heatmaps[12] = {
  gridSize = 64,
  cells = { [5] = 2 },
  lastSeen = 10,
}
module.char.heatmaps["12"] = {
  gridSize = 64,
  cells = { [5] = 3, [6] = 1 },
  lastSeen = 20,
}
module:InvalidateHeatmapCache()
local mergedZones = module:GetHeatmapZones()
assert(#mergedZones == 1 and mergedZones[1].total == 6,
  "duplicate heatmap map keys did not merge")
assert(mergedZones[1].cells[5] == 5 and mergedZones[1].cells[6] == 1,
  "duplicate heatmap cells did not add")
assert(mergedZones[1].lastSeen == 20,
  "duplicate heatmap map keys did not keep the newest lastSeen")

-- The normalized store keeps only the newest MAX_HEATMAP_MAPS zones.
module:ResetHeatmaps()
for mapID = 100, 140 do
  module.char.heatmaps[tostring(mapID)] = {
    gridSize = 64,
    cells = { [1] = 1 },
    total = 1,
    lastSeen = mapID,
  }
end
module:InvalidateHeatmapCache()
local capped = module:NormalizeHeatmaps()
local cappedCount = 0
for _ in pairs(capped) do
  cappedCount = cappedCount + 1
end
assert(cappedCount == module.MAX_HEATMAP_MAPS,
  "heatmap map cap not enforced")
assert(capped["100"] == nil and capped["140"] ~= nil,
  "heatmap map cap kept the wrong zones")

-- Resetting the store must invalidate the normalized cache so a later kill
-- does not resurrect the previous zones.
module:ResetHeatmaps()
assert(module:RecordHeatmapKill(17, 0.5, 0.5), "post-reset heatmap kill failed")
assert(#module:GetHeatmapZones() == 1, "post-reset heatmap zone missing")
module:ResetHeatmaps()
local afterReset = 0
for _ in pairs(module:NormalizeHeatmaps()) do
  afterReset = afterReset + 1
end
assert(afterReset == 0, "heatmap cache survived reset")
assert(module:RecordHeatmapKill(18, 0.5, 0.5), "second post-reset kill failed")
local refreshedZones = module:GetHeatmapZones()
assert(#refreshedZones == 1 and refreshedZones[1].mapID == 18,
  "heatmap cache did not refresh after reset")

-- The UI creates heat cells lazily and reuses them incrementally. Map 13 is
-- used so the refresh is a full zone change after the migration fixtures.
module:ResetHeatmaps()
assert(module:RecordHeatmapKill(13, 0.25, 0.75), "UI heatmap seed kill failed")
module:OpenUI()
module:SetTab("heatmap")
module:RefreshHeatmap()
local heatmapUI = module.ui and module.ui.heatmap
assert(heatmapUI and heatmapUI.cellCount < module.HEATMAP_CELLS,
  "heatmap UI preallocated the full 64x64 cell grid")
local initialCellCount = heatmapUI.cellCount
local renderedCount = 0
for _ in pairs(heatmapUI.renderedCounts) do
  renderedCount = renderedCount + 1
end
assert(renderedCount == 1 and heatmapUI.renderedCounts[expectedHeatCell] == 1,
  "heatmap UI did not render only the active cell")
assert(module:RecordHeatmapKill(13, 0.25, 0.75), "UI heatmap repeat kill failed")
module:RefreshHeatmap()
assert(heatmapUI.cellCount == initialCellCount
  and heatmapUI.renderedCounts[expectedHeatCell] == 2,
  "heatmap UI did not update the existing cell incrementally")
assert(module:RecordHeatmapKill(13, 0.75, 0.25), "UI heatmap second-cell kill failed")
module:RefreshHeatmap()
assert(heatmapUI.cellCount == initialCellCount + 1,
  "heatmap UI did not create the second active cell lazily")

-- A cell removed from the store is hidden by the incremental path without a
-- full rebuild, so stale heat cannot linger on the map.
module:ResetHeatmaps()
module.char.heatmaps["13"] = {
  gridSize = 64,
  cells = { [1] = 3, [2] = 3, [3] = 1 },
  total = 7,
  lastSeen = 1,
}
module:InvalidateHeatmapCache()
module.heatmapZoneKey = "13"
module:RefreshHeatmap()
local staleCell = heatmapUI.cells[3]
assert(heatmapUI.renderedCounts[3] == 1 and staleCell and staleCell:IsShown(),
  "stale-cell fixture did not render")
module.char.heatmaps["13"].cells[3] = nil
module.char.heatmaps["13"].total = 6
module:InvalidateHeatmapCache()
module:RefreshHeatmap()
assert(heatmapUI.renderedCounts[3] == nil and not staleCell:IsShown(),
  "incremental refresh did not hide a removed cell")

-- Explored-map overlays must be drawn above the base zone art; mouseover-only
-- highlight overlays must not be baked into the static heatmap background.
local savedMapArtLayers = C_Map.GetMapArtLayers
local savedMapArtLayerTextures = C_Map.GetMapArtLayerTextures
local savedExplorationInfo = C_MapExplorationInfo
local savedGetMapArtID = C_Map.GetMapArtID
local savedMapOverlayData = module.MapOverlayData
assert(type(savedMapOverlayData) == "table", "generated map overlay data missing")
C_Map.GetMapArtLayers = function()
  return {
    { layerWidth = 256, layerHeight = 256, tileWidth = 128, tileHeight = 128 },
  }
end
C_Map.GetMapArtLayerTextures = function()
  return { 1001, 1002, 1003, 1004 }
end
C_MapExplorationInfo = {
  GetExploredMapTextures = function()
    return {
      {
        textureWidth = 128,
        textureHeight = 128,
        offsetX = 64,
        offsetY = 64,
        fileDataIDs = { 2001 },
        isShownByMouseOver = false,
      },
      {
        textureWidth = 128,
        textureHeight = 128,
        offsetX = 0,
        offsetY = 0,
        fileDataIDs = { 2002 },
        isShownByMouseOver = true,
      },
    }
  end,
}
module:ResetHeatmaps()
assert(module:RecordHeatmapKill(14, 0.5, 0.5), "explored-art heatmap seed failed")
module:SetTab("heatmap")
module:RefreshHeatmap()
heatmapUI = module.ui and module.ui.heatmap
local shownArt, foundExplored, foundMouseover = 0, false, false
for _, tile in ipairs(heatmapUI.artTiles or {}) do
  if tile and tile.shown then
    shownArt = shownArt + 1
    if tile.texture == 2001 then
      foundExplored = true
    elseif tile.texture == 2002 then
      foundMouseover = true
    end
  end
end
assert(shownArt == 5 and foundExplored and not foundMouseover,
  "explored map overlays were not composited correctly")
C_MapExplorationInfo.GetExploredMapTextures = function()
  return {
    {
      textureWidth = 128,
      textureHeight = 128,
      offsetX = 64,
      offsetY = 64,
      fileDataIDs = { 2001 },
      isShownByMouseOver = false,
    },
    {
      textureWidth = 128,
      textureHeight = 128,
      offsetX = 0,
      offsetY = 64,
      fileDataIDs = { 2003 },
      isShownByMouseOver = false,
    },
  }
end
module:RefreshHeatmap()
local updatedArt, foundNewExplored = 0, false
for _, tile in ipairs(heatmapUI.artTiles or {}) do
  if tile and tile.shown then
    updatedArt = updatedArt + 1
    if tile.texture == 2003 then
      foundNewExplored = true
    end
  end
end
assert(updatedArt == 6 and foundNewExplored,
  "newly explored overlay did not rebuild the map art")

-- Generated full-overlay data must reveal undiscovered areas and must not
-- duplicate overlays that the official explored API already returned.
local projectID = module.projectID or 18
C_Map.GetMapArtID = function()
  return 9999
end
module.MapOverlayData = {
  [projectID] = {
    [9999] = {
      { 128, 128, 0, 0, "3001" },
      { 128, 128, 128, 0, "3002" },
    },
  },
}
module.mapOverlayCache = nil
C_MapExplorationInfo.GetExploredMapTextures = function()
  return nil
end
module:ResetHeatmaps()
assert(module:RecordHeatmapKill(15, 0.5, 0.5), "full-overlay heatmap seed failed")
module:SetTab("heatmap")
module:RefreshHeatmap()
heatmapUI = module.ui and module.ui.heatmap
local staticArt, foundStatic1, foundStatic2 = 0, false, false
for _, tile in ipairs(heatmapUI.artTiles or {}) do
  if tile and tile.shown then
    staticArt = staticArt + 1
    if tile.texture == 3001 then
      foundStatic1 = true
    elseif tile.texture == 3002 then
      foundStatic2 = true
    end
  end
end
assert(staticArt == 6 and foundStatic1 and foundStatic2,
  "full-overlay data did not reveal missing map art")
C_MapExplorationInfo.GetExploredMapTextures = function()
  return {
    {
      textureWidth = 128,
      textureHeight = 128,
      offsetX = 0,
      offsetY = 0,
      fileDataIDs = { 4001 },
      isShownByMouseOver = false,
    },
  }
end
module:RefreshHeatmap()
local overlapArt, foundExplored4001, foundStatic3001 = 0, false, false
for _, tile in ipairs(heatmapUI.artTiles or {}) do
  if tile and tile.shown then
    overlapArt = overlapArt + 1
    if tile.texture == 4001 then
      foundExplored4001 = true
    elseif tile.texture == 3001 then
      foundStatic3001 = true
    end
  end
end
assert(overlapArt == 6 and foundExplored4001 and not foundStatic3001,
  "explored overlay was duplicated by the full-overlay data")
local savedRevealUnexplored = module:GetSettings().revealUnexplored
module:GetSettings().revealUnexplored = false
module:RefreshHeatmap()
local revealOffArt, foundRevealOffStatic = 0, false
for _, tile in ipairs(heatmapUI.artTiles or {}) do
  if tile and tile.shown then
    revealOffArt = revealOffArt + 1
    if tile.texture == 3002 then
      foundRevealOffStatic = true
    end
  end
end
assert(revealOffArt == 5 and not foundRevealOffStatic,
  "reveal-unexplored setting did not disable generated overlay data")
module:GetSettings().revealUnexplored = savedRevealUnexplored
module.MapOverlayData = savedMapOverlayData
module.mapOverlayCache = nil
C_Map.GetMapArtID = savedGetMapArtID
C_Map.GetMapArtLayers = savedMapArtLayers
C_Map.GetMapArtLayerTextures = savedMapArtLayerTextures
C_MapExplorationInfo = savedExplorationInfo

local heatSettings = module:GetSettings()
assert(heatSettings.heatmapIntensity == 100 and heatSettings.heatmapWarmColors == false,
  "heatmap appearance defaults mismatch")
assert(type(module.GetHeatColor) == "function", "heat colour ramp is not exposed")

-- The ramp must change hue as well as alpha, keep the weakest cell clearly
-- weaker than the hottest, and not flatten when intensity is raised.
local themeAccent = { 0.25, 0.55, 0.95 }
local lowHeat = module.GetHeatColor(1, 13, 1.0, false, themeAccent)
local midHeat = module.GetHeatColor(4, 13, 1.0, false, themeAccent)
local highHeat = module.GetHeatColor(13, 13, 1.0, false, themeAccent)
assert(lowHeat[4] < midHeat[4] and midHeat[4] < highHeat[4],
  "heat alpha is not monotonic")
assert(lowHeat[4] < 0.6 and highHeat[4] == 1,
  "weakest heat cell is not clearly weaker than the hottest")
assert(lowHeat[1] ~= highHeat[1] or lowHeat[2] ~= highHeat[2]
  or lowHeat[3] ~= highHeat[3], "heat ramp still uses a single colour")
local lowHeat200 = module.GetHeatColor(1, 13, 2.0, false, themeAccent)
local highHeat200 = module.GetHeatColor(13, 13, 2.0, false, themeAccent)
assert(lowHeat200[4] < 0.5 and highHeat200[4] == 1,
  "200% intensity collapsed the heat ramp")
local warmLow = module.GetHeatColor(1, 13, 1.0, true, themeAccent)
local warmHigh = module.GetHeatColor(13, 13, 1.0, true, themeAccent)
assert(warmLow[1] > 0.5 and warmHigh[1] < warmLow[1]
  and warmHigh[3] < warmLow[3], "warm heat gradient mismatch")

-- Render a known 1..13 spread and verify the UI and legend use the ramp.
module:ResetHeatmaps()
module.char.heatmaps["21"] = {
  gridSize = 64,
  cells = { [1] = 1, [2] = 4, [3] = 8, [4] = 13 },
  total = 26,
  lastSeen = 1,
}
module:InvalidateHeatmapCache()
module.heatmapZoneKey = "21"
module:SetTab("heatmap")
module:RefreshHeatmap()
local gradientUI = module.ui and module.ui.heatmap
local lowCell = gradientUI and gradientUI.cells[1]
local midCell = gradientUI and gradientUI.cells[2]
local highCell = gradientUI and gradientUI.cells[4]
assert(lowCell and midCell and highCell and lowCell:IsShown()
  and midCell:IsShown() and highCell:IsShown(), "gradient heat cells missing")
assert(lowCell.color[4] < midCell.color[4] and midCell.color[4] < highCell.color[4],
  "UI heat cells do not use the alpha ramp")
assert(lowCell.color[1] ~= highCell.color[1]
  or lowCell.color[2] ~= highCell.color[2]
  or lowCell.color[3] ~= highCell.color[3],
  "UI heat cells do not use the colour ramp")
local swatches = gradientUI.gradientSwatches
assert(type(swatches) == "table" and #swatches > 1,
  "heat gradient legend swatches missing")
local firstSwatch, lastSwatch = swatches[1], swatches[#swatches]
assert(firstSwatch.color and lastSwatch.color
  and (firstSwatch.color[1] ~= lastSwatch.color[1]
    or firstSwatch.color[2] ~= lastSwatch.color[2]
    or firstSwatch.color[3] ~= lastSwatch.color[3]),
  "heat gradient legend is not a gradient")

heatSettings.heatmapWarmColors = true
module:RefreshHeatmap()
assert(highCell.color[1] > 0.5 and highCell.color[2] < 0.1,
  "warm heat palette not applied to the top cell")
heatSettings.heatmapWarmColors = false
heatSettings.heatmapIntensity = 200
module:RefreshHeatmap()
assert(lowCell.color[4] < 0.5,
  "200% intensity flattened the weakest UI heat cell")
heatSettings.heatmapIntensity = 100
module:RefreshHeatmap()

local dataStats = module:GetDataStats()
assert(type(dataStats) == "table" and dataStats.maxMobs == 2000
  and dataStats.maxHeatmapZones == 40 and dataStats.estimatedBytes > 0,
  "data diagnostics stats mismatch")
assert(dataStats.heatmapZones >= 1 and type(dataStats.heatmapCells) == "number",
  "data diagnostics did not count heatmap storage")
module:ToggleDiagnosticsUI()
assert(module.diagnosticsUI,
  "diagnostics UI was not created")
assert(pcall(module.RefreshDiagnosticsUI, module),
  "diagnostics UI refresh failed")
module:ToggleDiagnosticsUI()

local savedNamePlate = C_NamePlate
local savedNamePlateAvailable = module.namePlateEventAvailable
local savedShowNameplateLevel = module:GetSettings().showNameplateLevel
C_NamePlate = nil
module.namePlateEventAvailable = true
module:GetSettings().showNameplateLevel = true
local namePlateOK = pcall(function()
  module:HandleNamePlate("nameplate1")
  module:RefreshNameplateLevels()
  module:HideNamePlateLevel("nameplate1")
  module:ClearNameplateLevels()
end)
C_NamePlate = savedNamePlate
module.namePlateEventAvailable = savedNamePlateAvailable
module:GetSettings().showNameplateLevel = savedShowNameplateLevel
assert(namePlateOK, "nameplate handler raised without C_NamePlate")

print("Focused smoke test passed (" .. SCENARIO .. ")")
