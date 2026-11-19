-- Focused production test for index-backed command output parity.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

db.journey = db.journey or {}
db.journey.indexViews = nil

db.mobs = {
  ["npc:101"] = {
    npcID = 101, name = "Alpha", classification = "normal",
    kills = 20, sessionKills = 5, firstSeen = 0, lastSeen = 0,
    xp = { samples = 2, sumBase = 100, sumTotal = 120 },
    contexts = {
      a = { samples = 1, playerLevel = 10, mobLevel = 10 },
      b = { samples = 1, playerLevel = 10, mobLevel = 11 },
    },
  },
  ["npc:102"] = {
    npcID = 102, name = "Beta", classification = "elite",
    kills = 15, sessionKills = 0, firstSeen = 0, lastSeen = 0,
    xp = { samples = 0 }, contexts = {},
  },
  ["npc:103"] = {
    npcID = 103, name = "Gamma", classification = "normal",
    kills = 15, sessionKills = 2, firstSeen = 0, lastSeen = 0,
    xp = { samples = 1, sumBase = 55 }, contexts = {},
  },
  ["npc:104"] = {
    npcID = 104, name = "Delta", classification = "rare",
    kills = 0, sessionKills = 0, firstSeen = 0, lastSeen = 0,
    xp = { samples = 0 }, contexts = {},
  },
}
module:SyncModelMobsFromLegacy()
module:InvalidateMobIndex()

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

local function compare(label, fn)
  db.journey.indexViews = false
  local legacy = capture(function() fn(module) end)
  db.journey.indexViews = true
  local indexed = capture(function() fn(module) end)
  assert(legacy == indexed, string.format(
    "%s command parity failed\nlegacy:\n%s\nindexed:\n%s", label, legacy, indexed
  ))
  return indexed
end

compare("kills", function(m) m:PrintKills(nil) end)
compare("kills filter", function(m) m:PrintKills("alpha") end)
compare("kills empty", function(m) m:PrintKills("zzz") end)
local dump = compare("dump", function(m) m:PrintDump() end)
assert(dump:find("Kill Story dump (4 mobs):", 1, true), "dump count mismatch")
assert(dump:find("Delta", 1, true), "dump omitted a zero-kill mob")

-- One index build serves repeated command output.
module.journeyMobIndexBuilds = 0
module:InvalidateJourneyMobIndex()
db.journey.indexViews = true
capture(function() module:PrintKills(nil) end)
assert(module.journeyMobIndexBuilds == 1, "first command should build once")
capture(function() module:PrintDump() end)
capture(function() module:PrintKills("alpha") end)
assert(module.journeyMobIndexBuilds == 1, "repeated commands rebuilt the index")

-- A mutation invalidates and the next command rebuilds once.
db.mobs["npc:101"].kills = 40
module:SyncModelMobsFromLegacy()
module:InvalidateMobIndex()
local updated = capture(function() module:PrintKills(nil) end)
assert(module.journeyMobIndexBuilds == 2, "mutation did not rebuild once")
assert(updated:find("Alpha", 1, true), "updated command output missing Alpha")
assert(updated:find("40", 1, true), "updated command output is stale")

-- Rollback returns to legacy scans without building the index.
db.journey.indexViews = false
module.journeyMobIndexBuilds = 0
capture(function() module:PrintKills(nil) end)
capture(function() module:PrintDump() end)
assert(module.journeyMobIndexBuilds == 0, "rollback unexpectedly built the index")

print("Command index switch passed")
