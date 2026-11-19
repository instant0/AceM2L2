-- DS-17.23 S10C-1 retirement readiness test.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char
local state = F.state

state.now = 1000
local now = module.Util.Epoch()
db.journey = db.journey or {}
db.journey.mobs = {
  ["npc:1"] = {
    npcID = 1, name = "Ready Mob", classification = "normal",
    kills = 5, xp = 500, sessionKills = 1,
    byPlayerLevel = { ["10"] = { kills = 5, xp = 500, samples = 5 } },
    byZone = { ["12"] = { kills = 5, playerLevels = { ["10"] = { kills = 5 } } } },
    byInstance = {}, contexts = {}, firstSeen = now - 100, lastSeen = now,
  },
}
db.journey.zones = {
  ["12"] = {
    kills = 5, killXP = 500, questXP = 0, otherXP = 0, xp = 500,
    presenceSeconds = 60, engagedSeconds = 30, deaths = 0, sessions = 1,
    playerLevels = { ["10"] = { kills = 5 } },
  },
}
db.journey.levels = {
  ["10"] = {
    kills = 5, killXP = 500, questXP = 0, otherXP = 0, xp = 500,
    presenceSeconds = 60, engagedSeconds = 30,
  },
}
db.journey.instances = {}
db.journey.deaths = { { at = now - 10, mapID = 12, x = 0.1, y = 0.9 } }
db.journey.quests = {
  ["quest:1"] = {
    id = 1, count = 1, xp = 50, lastSeen = now, lastTurnInAt = now,
    mapID = 12, playerLevel = 10,
  },
}
db.journey.respawns = {
  ["1234"] = { name = "Ready NPC", intervals = { 300 }, lastSeen = now },
}
db.journey.heatmaps = {
  ["12"] = {
    mapID = 12, gridSize = 64, total = 5,
    cells = { [1] = { kills = 5 } }, lastSeen = now,
  },
}
db.mobs = {
  ["npc:1"] = { npcID = 1, name = "Ready Mob", kills = 5, totalXP = 500,
    killsByMap = { ["12"] = 5 }, killsByInstance = {}, contexts = {} },
}
db.areas = { ["12"] = 5 }
db.levels = { ["10"] = 5 }
db.instances = {}
db.deaths = { { at = now - 10, mapID = 12, x = 0.1, y = 0.9 } }
db.quests = { ["quest:1"] = { id = 1, name = "Ready Quest", count = 1, totalXP = 50 } }
db.respawns = { ["1234"] = { name = "Ready NPC", intervals = { 300 }, lastSeen = now } }
db.heatmaps = { ["12"] = { cells = { [1] = 5 }, total = 5, lastSeen = now } }

local readiness = module:GetRetirementReadiness()
assert(readiness.ready == false, "S10C-1 claimed retirement ready")
assert(readiness.stage == "S10C-1" and readiness.nextStage == "S10C-2",
  "retirement stage")
assert(readiness.gates.v2a == false and readiness.gates.v2b == false
  and readiness.gates.v2c == false and readiness.gates.v2d == false,
  "live gates defaulted ready")

local blockers = {}
for _, blocker in ipairs(readiness.blockers) do blockers[blocker] = true end
assert(blockers["live:v2a"] and blockers["live:v2c"], "live gate blocker")
assert(blockers["dual-writes-active"], "dual-write blocker")
assert(blockers["quest-name-ledger"], "quest ledger blocker")
assert(blockers["legacy-roots-present"], "legacy root blocker")

local inventory = readiness.roots
assert(inventory.legacy.mobs == 1 and inventory.v2.mobs == 1, "mob inventory")
assert(inventory.legacy.heatmaps == 1 and inventory.v2.heatmaps == 1,
  "heatmap inventory")
assert(inventory.v2Total > 0, "v2 inventory empty")
assert(readiness.restore.hasBackup == false, "unexpected migration backup")
assert(readiness.questNameSource == "legacy-ledger", "quest name source")

-- Live evidence alone cannot make S10C-1 ready while writes remain.
db.journey.retirementEvidence = { v2a = true, v2b = true, v2c = true, v2d = true }
readiness = module:GetRetirementReadiness()
blockers = {}
for _, blocker in ipairs(readiness.blockers) do blockers[blocker] = true end
assert(readiness.ready == false, "readiness ignored write/quest blockers")
assert(not blockers["live:v2a"], "live gate not accepted as evidence")
assert(blockers["dual-writes-active"], "write blocker cleared too early")
assert(blockers["quest-name-ledger"], "quest blocker cleared too early")

-- V2-only replay works while the retirement gate stays closed.
db.mobs, db.areas, db.levels, db.instances = nil, nil, nil, nil
db.deaths, db.respawns, db.heatmaps = nil, nil, nil
module:InvalidateJourneyMobIndex()
assert(module:GetMobJourneySummary("npc:1").kills == 5, "v2 mob replay")
assert(module:GetAreaKillCount(12) == 5, "v2 zone replay")
assert(module:GetLevelKillCount(10) == 5, "v2 level replay")
assert(#module:GetModelDeathList() == 1, "v2 death replay")
local _, respawnSamples = module:GetRespawnStats(1234)
assert(respawnSamples == 1, "v2 respawn replay")
assert(module:GetHeatmapTopCells(12, 1)[1].kills == 5, "v2 heatmap replay")

local stats = module:GetDataStats()
assert(stats.retirement and stats.retirement.stage == "S10C-1",
  "diagnostics retirement readiness")

print("S10C retirement readiness passed")
