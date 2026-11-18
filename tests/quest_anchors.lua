-- Focused test for bounded quest-turn-in anchors.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

state.mapID = 12
state.mapX = 0.25
state.mapY = 0.75
state.playerLevel = 10
state.now = 100
module:OnJourneyEnterWorld()
local journey = module:EnsureJourney()

module:RecordQuestXP(123, "Anchor Quest", 500)
local anchor = journey.questAnchors[1]
assert(anchor and anchor.questID == 123 and anchor.mapID == 12,
  "quest anchor identity")
assert(anchor.x == 0.25 and anchor.y == 0.75, "quest anchor coordinates")
assert(anchor.at == 1760000100, "quest anchor timestamp")
assert(anchor.playerLevel == 10 and anchor.xp == 500, "quest anchor level/xp")
assert(anchor.name == nil, "quest anchor duplicated the quest name")

-- Missing map-position API stores no fake coordinates.
local originalPosition = module.GetPlayerMapPosition
module.GetPlayerMapPosition = function() return nil end
state.now = 200
module:RecordQuestXP(124, "No Position", 100)
module.GetPlayerMapPosition = originalPosition
local noPosition = journey.questAnchors[2]
assert(noPosition and noPosition.questID == 124 and noPosition.mapID == 12,
  "fallback map missing")
assert(noPosition.x == nil and noPosition.y == nil, "fake coordinates invented")

-- Map filtering and name resolution from the quest ledger.
state.mapID = 13
state.mapX = 0.5
state.mapY = 0.5
state.now = 300
module:RecordQuestXP(125, "Other Map", 200)
local map12 = module:GetQuestAnchors(12, 10)
local map13 = module:GetQuestAnchors(13, 10)
assert(#map12 == 2 and #map13 == 1, "quest anchor map filtering")
assert(map12[1].name == "No Position" and map12[2].name == "Anchor Quest",
  "quest anchor names")
assert(map13[1].name == "Other Map", "other-map anchor name")

-- The loaded anchor list is capped deterministically by timestamp.
journey.questAnchors = {}
for index = 1, 5001 do
  journey.questAnchors[index] = {
    questID = index, mapID = 12, at = index, playerLevel = 10, xp = 0,
  }
end
journey = module:EnsureJourney()
assert(#journey.questAnchors == 5000, "quest anchor cap")
assert(journey.questAnchors[1].at == 2
  and journey.questAnchors[#journey.questAnchors].at == 5001,
  "quest anchor pruning order")

-- Area Detail prefers anchors when present.
db.areas = { ["12"] = 2 }
db.areaLevels = { ["12"] = { ["10"] = 2 } }
db.totals = { kills = 2, xp = 0, uniqueMobs = 0 }
state.now = 100
journey.questAnchors = {
  { questID = 123, mapID = 12, x = 0.25, y = 0.75, at = 1760000100,
    playerLevel = 10, xp = 500 },
}
module:OpenUI()
module.journeyDecodedBlocks = 0
module:UpdateAreaDetail("12")
local text = module.ui.details.text
assert(text:find("Latest quest anchors:", 1, true), "area anchor section")
assert(text:find("Anchor Quest", 1, true), "area anchor name")
assert(text:find("25.0, 75.0", 1, true), "area anchor coordinates")
assert(module.journeyDecodedBlocks == 0, "area anchor decoded blocks")

print("Quest anchors passed")
