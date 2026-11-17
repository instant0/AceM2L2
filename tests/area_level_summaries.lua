-- Focused parity test for remaining area/level summary reads.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

db.journey = db.journey or {}
db.journey.indexViews = nil

db.areas = { ["12"] = 10, ["13"] = 10, ["947"] = 5 }
db.instances = {
  ["id:555:1"] = { name = "Test Dungeon", kills = 10 },
  ["id:555:2"] = { name = "Second Instance", kills = 5 },
}
db.levels = { ["10"] = 5, ["11"] = 10, ["12"] = 10 }
db.areaLevels = { ["12"] = { ["10"] = 5, ["11"] = 5 } }
db.mobs = {
  ["npc:1"] = {
    npcID = 1, name = "Alpha", classification = "normal", kills = 10,
    totalXP = 1000, firstSeen = 0, lastSeen = 0,
    killsByMap = { ["12"] = 10 }, killsByInstance = {},
    killsAtLevel = { ["10"] = 5, ["11"] = 5 }, xp = { samples = 0 },
    contexts = {},
  },
  ["npc:2"] = {
    npcID = 2, name = "Beta", classification = "normal", kills = 8,
    totalXP = 800, firstSeen = 0, lastSeen = 0,
    killsByMap = { ["13"] = 8 }, killsByInstance = {},
    killsAtLevel = { ["11"] = 8 }, xp = { samples = 0 },
    contexts = {},
  },
  ["npc:3"] = {
    npcID = 3, name = "Gamma", classification = "normal", kills = 5,
    totalXP = 500, firstSeen = 0, lastSeen = 0,
    killsByMap = { ["12"] = 5 }, killsByInstance = {},
    killsAtLevel = { ["10"] = 5 }, xp = { samples = 0 },
    contexts = {},
  },
  ["npc:4"] = {
    npcID = 4, name = "Delta", classification = "normal", kills = 0,
    totalXP = 0, firstSeen = 0, lastSeen = 0,
    killsByMap = {}, killsByInstance = {}, killsAtLevel = {},
    xp = { samples = 0 }, contexts = {},
  },
}
db.totals = { kills = 50, xp = 1000, uniqueMobs = 4 }
module:InvalidateMobIndex()
module:OpenUI()

local originalPrint = AceM2L2.Print
local function capture(fn)
  local lines = {}
  AceM2L2.Print = function(_, text) lines[#lines + 1] = tostring(text) end
  local ok, err = pcall(fn)
  AceM2L2.Print = originalPrint
  assert(ok, err)
  return table.concat(lines, "\n")
end

local function withView(indexViews, fn)
  db.journey.indexViews = indexViews
  return fn()
end

local function compare(label, read)
  local legacy = withView(false, read)
  local indexed = withView(true, read)
  assert(legacy == indexed, string.format(
    "%s parity failed\nlegacy:\n%s\nindexed:\n%s", label, legacy, indexed
  ))
end

compare("overview", function()
  module.tab = "overview"
  module:RefreshOverview()
  local text = module.ui.overview.levelText.text or ""
  local levelLines = text:match("^(Level range:[^\n]*\nMost kills:[^\n]*)") or text
  return table.concat({
    tostring(module.ui.overview.cards[4].value.text),
    levelLines,
  }, "\n")
end)

compare("footer", function()
  module:UpdateFooter()
  return tostring(module.ui.footer.text)
end)

compare("minimap", function()
  local tooltip = { lines = {} }
  function tooltip:AddLine(text) self.lines[#self.lines + 1] = tostring(text) end
  module:OnMinimapTooltip(tooltip)
  return table.concat(tooltip.lines, "\n")
end)

compare("area detail", function()
  module:UpdateAreaDetail("12")
  return table.concat({
    tostring(module.ui.heroName.text),
    tostring(module.ui.heroSub.text),
    tostring(module.ui.details.text),
  }, "\n")
end)

compare("level detail", function()
  module:UpdateLevelDetail("11")
  return table.concat({
    tostring(module.ui.heroName.text),
    tostring(module.ui.heroSub.text),
    tostring(module.ui.details.text),
  }, "\n")
end)

compare("stats", function()
  return capture(function() module:PrintStats() end)
end)

-- Empty states match as well.
local savedAreas, savedInstances, savedLevels, savedMobs = db.areas, db.instances, db.levels, db.mobs
db.areas, db.instances, db.levels, db.mobs = {}, {}, {}, {}
module:InvalidateMobIndex()
compare("empty overview", function()
  module.tab = "overview"
  module:RefreshOverview()
  local text = module.ui.overview.levelText.text or ""
  local levelLine = text:match("^([^\n]*)") or text
  return table.concat({
    tostring(module.ui.overview.cards[4].value.text),
    levelLine,
  }, "\n")
end)
compare("empty footer", function()
  module:UpdateFooter()
  return tostring(module.ui.footer.text)
end)
db.areas, db.instances, db.levels, db.mobs = savedAreas, savedInstances, savedLevels, savedMobs
module:InvalidateMobIndex()

print("Area/Level summaries passed")
