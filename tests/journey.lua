-- Focused production test for event-driven Journey instrumentation.
-- No timer; exercises zone/kill/quest/logout events directly.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()

assert(module:IsActive(), "Forever module should be active")
assert(type(module.OnJourneyKill) == "function", "Journey kill hook missing")
assert(type(module.OnJourneyQuestTurnIn) == "function", "Journey quest hook missing")

state.mapID = 12
state.playerLevel = 10
state.now = 100
module:OnJourneyEnterWorld()
local journey = module.char.journey
assert(type(journey) == "table", "Journey table missing")
assert(journey.schema == 1, "Journey schema mismatch")

state.now = 110
module:OnJourneyKill({ mapID = 12, playerLevel = 10 }, 100)
local zone = journey.zones["12"]
assert(zone, "zone time record missing")
assert(zone.presenceSeconds == 10, "presence after first kill")
assert(zone.engagedSeconds == 10, "engaged after first kill")
assert(zone.killXP == 100, "kill XP after first kill")

state.now = 170
module:OnJourneyKill({ mapID = 12, playerLevel = 10 }, 50)
assert(zone.presenceSeconds == 70, "presence after second kill")
assert(zone.engagedSeconds == 70, "engaged after second kill")
assert(zone.killXP == 150, "kill XP after second kill")

state.now = 230
module:RecordQuestXP(123, "Journey Test", 500)
assert(zone.presenceSeconds == 130, "quest should close presence")
assert(zone.engagedSeconds == 70, "quest must not add engaged time")
assert(zone.questXP == 500, "quest XP split")
local quest = module.char.quests["quest:123"]
assert(type(quest) == "table", "quest record missing")
assert(quest.lastTurnInAt and quest.lastTurnInAt > 0, "quest turn-in timestamp")
assert(quest.mapID == 12 and quest.playerLevel == 10, "quest anchor location")

state.now = 260
module:OnJourneyKill({ mapID = 12, playerLevel = 10 }, 25)
assert(zone.presenceSeconds == 160, "presence after post-quest kill")
assert(zone.engagedSeconds == 100, "engaged after quest reset")
assert(zone.killXP == 175, "kill XP after post-quest kill")

state.now = 300
module:OnJourneyLogout()
assert(zone.presenceSeconds == 200, "presence at logout")
assert(zone.engagedSeconds == 140, "engaged at logout")
assert(journey.time.lastEventAt == 0, "logout should close segment")

local level = journey.levels["10"]
assert(level, "level time record missing")
assert(level.presenceSeconds == 200, "level presence")
assert(level.engagedSeconds == 140, "level engaged")
assert(level.killXP == 175 and level.questXP == 500, "level XP split")

print("Journey instrumentation passed")
