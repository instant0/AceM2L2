-- Focused test for overlap-safe Areas/Levels rows and rollback.

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
db.totals = { kills = 50, xp = 0, uniqueMobs = 0 }

local originalPrint = AceM2L2.Print
local function capture(fn)
  local lines = {}
  AceM2L2.Print = function(_, text)
    lines[#lines + 1] = tostring(text)
  end
  local ok, err = pcall(fn)
  AceM2L2.Print = originalPrint
  assert(ok, err)
  return table.concat(lines, "\n")
end

local function listSnapshot(indexViews, tab)
  db.journey.indexViews = indexViews
  module.tab = tab
  module:BuildList()
  local lines = {}
  for index = 1, #(module.currentList or {}) do
    local row = module.currentList[index]
    lines[#lines + 1] = table.concat({
      tostring(row.kind), tostring(row.key), tostring(row.label),
      tostring(row.value), tostring(row.sortValue), tostring(row.kills),
      tostring(row.bar),
    }, "|")
  end
  return table.concat(lines, "\n")
end

local function compareList(label, tab)
  local legacy = listSnapshot(false, tab)
  local indexed = listSnapshot(true, tab)
  assert(legacy == indexed, string.format(
    "%s list parity failed\nlegacy:\n%s\nindexed:\n%s", label, legacy, indexed
  ))
end

local function compareCommand(label, fn)
  db.journey.indexViews = false
  local legacy = capture(function() fn(module) end)
  db.journey.indexViews = true
  local indexed = capture(function() fn(module) end)
  assert(legacy == indexed, string.format(
    "%s command parity failed\nlegacy:\n%s\nindexed:\n%s", label, legacy, indexed
  ))
end

compareList("areas", "areas")
compareList("levels", "levels")
compareCommand("areas", function(m) m:PrintAreas() end)
compareCommand("levels", function(m) m:PrintLevels() end)

-- Instance rows and names survive the switch.
local areas = listSnapshot(true, "areas")
assert(areas:find("Test Dungeon", 1, true), "instance row missing")
assert(areas:find("Second Instance", 1, true), "second instance row missing")
assert(not areas:find("Azeroth", 1, true), "Azeroth leaked into Areas")

-- Empty states match.
local savedAreas, savedInstances, savedLevels = db.areas, db.instances, db.levels
db.areas, db.instances, db.levels = {}, {}, {}
compareList("empty areas", "areas")
compareList("empty levels", "levels")
compareCommand("empty areas", function(m) m:PrintAreas() end)
compareCommand("empty levels", function(m) m:PrintLevels() end)
db.areas, db.instances, db.levels = savedAreas, savedInstances, savedLevels

-- Zone/level Journey stats are separate from legacy counts, not added.
db.journey.zones = {
  ["12"] = {
    kills = 3, killXP = 300, questXP = 0, otherXP = 0, xp = 300,
    presenceSeconds = 0, engagedSeconds = 0, deaths = 0, sessions = 0, levels = {},
  },
}
local zone = module:GetJourneyZoneStats("12")
assert(zone.kills == 3, "Journey zone kills were added to legacy")
assert(zone.legacyKills == 10, "legacy zone kills not reported")
db.journey.levels = {
  ["10"] = {
    kills = 4, killXP = 400, questXP = 0, otherXP = 0, xp = 400,
    presenceSeconds = 0, engagedSeconds = 0, deaths = 0,
  },
}
local level = module:GetJourneyLevelStats(10)
assert(level.kills == 4, "Journey level kills")
assert(level.legacyKills == 5, "legacy level kills not reported")

-- The flag really selects the shared row path; false never calls it.
local originalAreaRows = module.GetAreaRows
local originalLevelRows = module.GetLevelRows
local areaCalls, levelCalls = 0, 0
module.GetAreaRows = function(self)
  areaCalls = areaCalls + 1
  return originalAreaRows(self)
end
module.GetLevelRows = function(self)
  levelCalls = levelCalls + 1
  return originalLevelRows(self)
end
db.journey.indexViews = false
module.tab = "areas"
module:BuildList()
module.tab = "levels"
module:BuildList()
assert(areaCalls == 0 and levelCalls == 0, "rollback called the shared rows")
db.journey.indexViews = true
module.tab = "areas"
module:BuildList()
assert(areaCalls == 1, "Areas did not use GetAreaRows")
module.tab = "levels"
module:BuildList()
assert(levelCalls == 1, "Levels did not use GetLevelRows")
module.GetAreaRows = originalAreaRows
module.GetLevelRows = originalLevelRows

-- Reset clears Journey history and block state as well as legacy history.
db.journey = { zones = { ["12"] = { kills = 3 } }, blocks = { ["map:12"] = {} } }
module.journeyMobIndex = { rows = { {} } }
capture(function() module:ResetKills() end)
assert(db.journey == nil, "reset left Journey history")
assert(module.journeyMobIndex == nil, "reset left the Journey mob index")

print("Areas/Levels parity passed")
