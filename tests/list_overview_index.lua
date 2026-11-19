-- Focused production test for the Mobs list/Overview Journey-index switch.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

db.journey = db.journey or {}
db.journey.indexViews = nil
state.playerLevel = 10

db.mobs = {
  ["npc:101"] = {
    npcID = 101, name = "Alpha", classification = "normal",
    kills = 20, sessionKills = 5, lastSeen = 100,
    killsAtLevel = { ["10"] = 3 }, xp = { samples = 2, sumBase = 100 },
  },
  ["npc:102"] = {
    npcID = 102, name = "Beta", classification = "elite",
    kills = 15, sessionKills = 0, lastSeen = 300,
    killsAtLevel = { ["10"] = 0 }, xp = { samples = 0 },
  },
  ["npc:103"] = {
    npcID = 103, name = "Gamma", classification = "normal",
    kills = 10, sessionKills = 2, lastSeen = 200,
    killsAtLevel = { ["11"] = 4 }, xp = { samples = 1, sumBase = 55 },
  },
  ["npc:104"] = {
    npcID = 104, name = "Epsilon", classification = "worldboss",
    kills = 5, sessionKills = 0, lastSeen = 50, xp = { samples = 0 },
  },
  ["npc:105"] = {
    npcID = 105, name = "Delta", classification = "rare",
    kills = 0, sessionKills = 0, lastSeen = 0, xp = { samples = 0 },
  },
}
module:SyncModelMobsFromLegacy()
module:InvalidateMobIndex()

local function snapshot(indexViews, filter, search, sort)
  db.journey.indexViews = indexViews
  module.tab = "mobs"
  module.filter = filter or "all"
  module.searchText = search or ""
  module:GetSettings().ui.sort = sort or "kills"
  module:BuildList()
  local lines = {}
  for index = 1, #(module.currentList or {}) do
    local row = module.currentList[index]
    lines[#lines + 1] = table.concat({
      tostring(row.kind), tostring(row.key), tostring(row.label),
      tostring(row.value), tostring(row.sortKills), tostring(row.sortName),
      tostring(row.sortSeen), tostring(row.classification), tostring(row.bar),
    }, "|")
  end
  return table.concat(lines, "\n")
end

local cases = {
  { filter = "all", search = "", sort = "kills" },
  { filter = "all", search = "", sort = "name" },
  { filter = "all", search = "", sort = "lastSeen" },
  { filter = "level", search = "", sort = "kills" },
  { filter = "session", search = "", sort = "kills" },
  { filter = "elite", search = "", sort = "kills" },
  { filter = "all", search = "amm", sort = "kills" },
}
for _, case in ipairs(cases) do
  local legacy = snapshot(false, case.filter, case.search, case.sort)
  local indexed = snapshot(true, case.filter, case.search, case.sort)
  assert(legacy == indexed, string.format(
    "Mobs list parity failed for filter=%s search=%s sort=%s\nlegacy:\n%s\nindexed:\n%s",
    case.filter, case.search, case.sort, legacy, indexed
  ))
end

-- Overview top mobs must match the legacy output for distinct kill counts.
module:OpenUI()
db.journey.indexViews = false
module:RefreshOverview()
local legacyOverview = module.ui.overview.topMobsText.text
db.journey.indexViews = true
module:RefreshOverview()
local indexedOverview = module.ui.overview.topMobsText.text
assert(legacyOverview == indexedOverview, "Overview top-mob parity failed")
assert(indexedOverview:find("1. Alpha", 1, true), "Overview top mob missing")

-- Repeated refreshes reuse one index build.
module.journeyMobIndexBuilds = 0
db.journey.indexViews = true
module:InvalidateJourneyMobIndex()
module.tab = "mobs"
module.filter = "all"
module.searchText = ""
module:GetSettings().ui.sort = "kills"
module:BuildList()
assert(module.journeyMobIndexBuilds == 1, "first list refresh should build once")
module:BuildList()
module:RefreshOverview()
assert(module.journeyMobIndexBuilds == 1, "repeated refreshes rebuilt the index")

-- A mutation invalidates and the next view rebuilds exactly once.
db.mobs["npc:101"].kills = 40
module:SyncModelMobsFromLegacy()
module:InvalidateMobIndex()
module:BuildList()
assert(module.journeyMobIndexBuilds == 2, "mutation did not rebuild once")
assert(module.currentList[1].key == "npc:101", "rebuilt list is stale")

-- The retired rollback flag does not select a legacy mob scan.
db.journey.indexViews = false
module.journeyMobIndexBuilds = 0
module:InvalidateJourneyMobIndex()
module:BuildList()
module:RefreshOverview()
assert(module.journeyMobIndexBuilds == 1, "v2 list did not build the index")

print("Mobs list/Overview index switch passed")
