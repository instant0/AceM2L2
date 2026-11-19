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
module:SyncModelZonesFromLegacy()
module:SyncModelInstancesFromLegacy()

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
local savedZones = db.journey.zones
local savedInstances = db.journey.instances
local savedLevels = db.journey.levels
local savedAreas, savedLegacyInstances, savedLegacyLevels =
  db.areas, db.instances, db.levels
db.journey.zones, db.journey.instances, db.journey.levels = {}, {}, {}
db.areas, db.instances, db.levels = {}, {}, {}
compareList("empty areas", "areas")
compareList("empty levels", "levels")
compareCommand("empty areas", function(m) m:PrintAreas() end)
compareCommand("empty levels", function(m) m:PrintLevels() end)
db.journey.zones, db.journey.instances, db.journey.levels =
  savedZones, savedInstances, savedLevels
db.areas, db.instances, db.levels =
  savedAreas, savedLegacyInstances, savedLegacyLevels

-- Zone/level Journey stats are separate from legacy counts, not added.
db.journey.zones = {
  ["12"] = {
    kills = 3, killXP = 300, questXP = 0, otherXP = 0, xp = 300,
    presenceSeconds = 0, engagedSeconds = 0, deaths = 0, sessions = 0, levels = {},
  },
}
local zone = module:GetJourneyZoneStats("12")
assert(zone.kills == 3, "Journey zone kills")
db.journey.levels = {
  ["10"] = {
    kills = 4, killXP = 400, questXP = 0, otherXP = 0, xp = 400,
    presenceSeconds = 0, engagedSeconds = 0, deaths = 0,
  },
}
local level = module:GetJourneyLevelStats(10)
assert(level.kills == 4, "Journey level kills")

-- Query rows are v2-only; the legacy rollback flag does not resurrect
-- legacy aggregate roots.
db.journey.indexViews = false
assert(#module:GetAreaRows() == 3, "area rows depend on legacy flag")
assert(#module:GetLevelRows() == 1, "level rows depend on legacy flag")

-- The query rows themselves are v2-only even when legacy roots disappear.
local queryAreas, queryInstances, queryLevels = db.areas, db.instances, db.levels
db.areas, db.instances, db.levels = nil, nil, nil
assert(#module:GetAreaRows() == 3, "area rows read legacy roots")
assert(module:GetAreaKillCount("12") == 3, "area kill count read legacy")
assert(#module:GetLevelRows() == 1, "level rows read legacy roots")
assert(module:GetLevelKillCount("10") == 4, "level kill count read legacy")
db.areas, db.instances, db.levels = queryAreas, queryInstances, queryLevels

-- Reset clears Journey history and block state as well as legacy history.
db.journey = { zones = { ["12"] = { kills = 3 } }, blocks = { ["map:12"] = {} } }
module.journeyMobIndex = { rows = { {} } }
capture(function() module:ResetKills() end)
assert(db.journey == nil, "reset left Journey history")
assert(module.journeyMobIndex == nil, "reset left the Journey mob index")

print("Areas/Levels parity passed")
