-- Focused test for active vs historical mob presentation.

local F = dofile("tests/fixtures.lua")
local state = F.state
local GameTooltip = F.GameTooltip
local module = F.Init()
local db = module.char

state.now = 1000
local now = module.Util.Epoch()
db.mobs = {
  ["npc:1234"] = {
    npcID = 1234, name = "Defias Pillager", classification = "rare",
    kills = 50, sessionKills = 4, totalXP = 1000, sessionXP = 80,
    firstSeen = now - 10000, lastSeen = now - 100,
    killsAtLevel = { ["10"] = 10, ["60"] = 1 },
    killsByMap = { ["12"] = 50 },
    killsByInstance = {}, killsByAreaLevel = {}, killsByInstanceLevel = {},
    contexts = {
      historical = {
        playerLevel = 10, mobLevel = 10, groupSize = 1, mapID = 12,
        classification = "rare", buffSig = "none", samples = 10,
        sumBase = 200, sumTotal = 200, lastSeen = now - 100,
      },
    },
    xp = { samples = 10, sumBase = 200, sumTotal = 200 },
  },
}
F.SetTarget("Defias Pillager", "Creature-0-1-2-3-1234-00000001")
state.mapID = 12
state.targetLevel = 10

-- Outleveled: history, no XP advice.
state.playerLevel = 60
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local historical = table.concat(GameTooltip.lines, "\n")
assert(historical:find("Killed:", 1, true), "historical tooltip kills")
assert(historical:find("Historical content", 1, true), "historical tooltip marker")
assert(historical:find("Last seen:", 1, true), "historical last seen")
assert(not historical:find("XP:", 1, true), "historical tooltip claimed XP")
assert(not historical:find("Kills to level:", 1, true), "historical tooltip claimed kills to level")
assert(not historical:find("this level:", 1, true), "historical tooltip claimed this-level kills")

module:OpenUI()
module:UpdateMobDetail("npc:1234")
local historicalDetail = module.ui.details.text
assert(historicalDetail:find("Historical content", 1, true), "historical detail marker")
assert(historicalDetail:find("Total kills: 50", 1, true), "historical detail kills")
assert(not historicalDetail:find("This session:", 1, true), "historical detail claimed session")
assert(not historicalDetail:find("Avg base XP:", 1, true), "historical detail claimed XP")

-- Within the content band: normal XP behavior remains.
state.playerLevel = 12
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local active = table.concat(GameTooltip.lines, "\n")
assert(active:find("XP:", 1, true) or active:find("Kills to level:", 1, true),
  "active tooltip lost XP")
assert(not active:find("Historical content", 1, true), "active tooltip marked historical")

module:UpdateMobDetail("npc:1234")
local activeDetail = module.ui.details.text
assert(activeDetail:find("This session:", 1, true), "active detail lost session")
assert(activeDetail:find("Avg base XP:", 1, true), "active detail lost XP")
assert(not activeDetail:find("Historical content", 1, true), "active detail marked historical")

print("Historical relevance passed")
