-- Focused production test for tooltip/Detail block fallback and call budget.

local F = dofile("tests/fixtures.lua")
local state = F.state
local GameTooltip = F.GameTooltip
local module = F.Init()
local db = module.char

local GUID = "Creature-0-1-2-3-1234-00000001"
F.SetTarget("Defias Pillager", GUID)
state.mapID = 12
state.playerLevel = 10

db.mobs = {
  ["npc:1234"] = {
    npcID = 1234, name = "Defias Pillager", classification = "normal",
    kills = 42, totalXP = 4200, sessionKills = 7,
    killsAtLevel = { ["10"] = 9 },
    killsByMap = { ["12"] = 42 },
    killsByInstance = {}, contexts = {},
    firstSeen = 1000, lastSeen = 2000,
    xp = { samples = 2, sumBase = 100, sumTotal = 120 },
  },
}

assert(module:FlushJourneyBlocks(), "flush")
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local legacyText = table.concat(GameTooltip.lines, "\n")
assert(legacyText:find("Killed:", 1, true), "legacy tooltip missing kills")
assert(legacyText:find("this level:", 1, true), "legacy tooltip missing level kills")
assert(module.journeyDecodedBlocks == 0, "legacy tooltip should not decode blocks")

-- Remove the v2 mob; tooltip should use one cold block decode.
db.journey.mobs = {}
db.mobs = {}
module:InvalidateJourneyMobIndex()
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
local blockText = table.concat(GameTooltip.lines, "\n")
assert(blockText:find("Killed:", 1, true), "block tooltip missing kills")
assert(not blockText:find("this level:", 1, true), "block fallback must not fake this-level kills")
assert(module.journeyDecodedBlocks == 1, "cold block tooltip should decode once")

-- Cache hit: clear signature but keep block cache.
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
assert(module.journeyDecodedBlocks == 1, "cached tooltip should not decode again")

-- Detail fallback uses the block and marks unavailable sections.
module:OpenUI()
module:UpdateMobDetail("npc:1234")
assert(module.ui.heroName.text == "Defias Pillager", "detail block name")
assert(module.ui.details.text:find("Block detail", 1, true), "detail block note")
assert(not module.ui.details.text:find("This session:", 1, true), "detail must not fake session")

-- Rollback flag disables block fallback.
db.journey.blockReadFallback = false
module:ClearJourneyBlockCache()
module.journeyDecodedBlocks = 0
GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
assert(module.journeyDecodedBlocks == 0, "rollback should not decode blocks")

print("Tooltip/Detail fallback passed")
