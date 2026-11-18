-- Focused test for historical Area Detail overlays and toggles.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

state.now = 1000
local now = module.Util.Epoch()
db.areas = { ["12"] = 10, ["13"] = 5 }
db.instances = {}
db.totals = { kills = 15, xp = 0, uniqueMobs = 3 }
db.areaLevels = { ["12"] = { ["10"] = 10 }, ["13"] = { ["11"] = 5 } }
db.deaths = {
  { at = now - 60, mapID = 12, x = 0.1, y = 0.9 },
  { at = now - 120, mapID = 12, x = 0.2, y = 0.8 },
  { at = now - 30, mapID = 13, x = 0.5, y = 0.5 },
}
db.mobs = {
  ["npc:1"] = {
    npcID = 1, name = "Rare Westfall", classification = "rare",
    kills = 4, killsByMap = { ["12"] = 4 }, contexts = {},
  },
  ["npc:2"] = {
    npcID = 2, name = "Rare Darkshore", classification = "rareelite",
    kills = 3, killsByMap = { ["13"] = 3 }, contexts = {},
  },
  ["npc:3"] = {
    npcID = 3, name = "Normal Westfall", classification = "normal",
    kills = 6, killsByMap = { ["12"] = 6 }, contexts = {},
  },
}
db.quests = {
  ["quest:1"] = {
    id = 1, name = "Westfall Quest", count = 1, mapID = 12,
    lastTurnInAt = now - 40,
  },
  ["quest:2"] = {
    id = 2, name = "Darkshore Quest", count = 1, mapID = 13,
    lastTurnInAt = now - 20,
  },
}
db.heatmaps = {
  ["12"] = { gridSize = 64, total = 10, cells = { [1] = 5, [2] = 5 }, lastSeen = now },
}
module:InvalidateMobIndex()
module:InvalidateHeatmapCache()

module:OpenUI()
module:SetTab("areas")
module.tab = "areas"
module:BuildList()
module:SelectIndex(1)
local details = module.ui.details.text
assert(details:find("Notable deaths:", 1, true), "area deaths section")
assert(details:find("Rare/elite mobs:", 1, true), "area rares section")
assert(details:find("Latest quest anchors:", 1, true), "area quests section")
assert(details:find("Heatmap: 2 cells, 10 kills", 1, true), "area heatmap section")
assert(not details:find("Avg base XP", 1, true), "area detail claimed XP")
assert(module.ui.historyBar.shown, "history toggle bar hidden")

-- Select the other area: records must not leak.
module:SelectIndex(2)
details = module.ui.details.text
assert(details:find("Rare Darkshore", 1, true), "area 13 rare")
assert(details:find("Darkshore Quest", 1, true), "area 13 quest")
assert(not details:find("Rare Westfall", 1, true), "area 12 rare leaked")
assert(not details:find("Westfall Quest", 1, true), "area 12 quest leaked")

-- Toggle one overlay off and back on.
module:ToggleHistoryOverlay("deaths")
assert(not module.ui.details.text:find("Notable deaths:", 1, true), "death toggle off")
assert(module:GetHistoryOverlaySettings().deaths == false, "death setting")
assert(module.ui.historyButtons.deaths.buttonState == "UNPUSHED"
  or module.ui.historyButtons.deaths.buttonState == nil, "death button state")
module:ToggleHistoryOverlay("deaths")
assert(module.ui.details.text:find("Notable deaths:", 1, true), "death toggle on")

-- Heatmap toggle removes only the heatmap summary.
module:ToggleHistoryOverlay("heatmap")
assert(not module.ui.details.text:find("Heatmap:", 1, true), "heatmap toggle off")
assert(module:GetHistoryOverlaySettings().heatmap == false, "heatmap setting")

-- Toggle row is Areas-only.
module:SetTab("mobs")
assert(not module.ui.historyBar.shown, "history bar visible outside Areas")

-- No block decode is needed for the area summaries.
module:SetTab("areas")
module.journeyDecodedBlocks = 0
module:UpdateAreaDetail("12")
assert(module.journeyDecodedBlocks == 0, "area detail decoded blocks")

print("Historical zone passed")
