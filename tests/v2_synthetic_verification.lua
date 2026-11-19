-- V-2 synthetic verification: simulate implemented V-2 paths offline.
-- This does not replace live evidence and never unlocks retirement.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char
local report = { "V-2 synthetic verification" }

local function pass(name, detail)
  report[#report + 1] = string.format("%s=pass%s", name,
    detail and (" (" .. detail .. ")") or "")
end

local function unavailable(name)
  report[#report + 1] = name .. "=unavailable"
end

-- V-2A: API/field probe surface.
local probe = module:CollectV2Probe()
assert(type(probe.apis) == "table" and type(probe.fields) == "table",
  "probe shape")
assert(probe.fields.deathAttribution == false, "unimplemented field claimed")
pass("v2a_probe", "synthetic API matrix")

-- V-2B: event-driven timing and implemented capture.
module:ResetKills()
state.mapID = 12
state.playerLevel = 10
state.now = 100
module:OnJourneyEnterWorld()
state.now = 110
module:OnJourneyKill({ mapID = 12, playerLevel = 10 }, 100)
state.now = 170
module:OnJourneyKill({ mapID = 12, playerLevel = 10 }, 50)
state.now = 230
module:RecordQuestXP(123, "Synthetic Quest", 500)
state.now = 300
module:OnJourneyLogout()
local journey = assert(db.journey)
local zone = assert(journey.zones["12"])
assert(zone.presenceSeconds == 200, "synthetic presence")
assert(zone.engagedSeconds == 130, "synthetic engaged")
assert(zone.killXP == 150 and zone.questXP == 500, "synthetic XP split")
pass("v2b_presence_engaged", "200/130 seconds")
pass("v2b_xp_split", "kill/quest")

-- Death capture: exact position, unimplemented attribution/health absent.
db.deaths = {}
module:RecordDeath(12, 0.1, 0.9, 400)
local death = module:GetModelDeath(1)
assert(death and death.x == 0.1 and death.y == 0.9, "death position")
assert(death.mobKey == nil and death.health == nil, "death field invented")
assert(death.attributionCoverage == "unavailable", "death attribution claim")
unavailable("v2b_death_attribution")
unavailable("v2b_death_health")

-- Heatmap capture: kills only; XP/time remain unavailable.
assert(module:RecordHeatmapKill(12, 0.25, 0.75), "heatmap capture")
local heatmap = module:GetModelHeatmap(12)
assert(heatmap and heatmap.total >= 1, "heatmap total")
local top = module:GetHeatmapTopCells(12, 1)
assert(#top == 1 and top[1].kills >= 1, "heatmap cell")
assert(top[1].xp == 0 and top[1].presenceSeconds == 0,
  "heatmap cell XP/time claimed")
unavailable("v2b_heatmap_cell_xp")
unavailable("v2b_heatmap_cell_time")
pass("v2b_heatmap_kills", "64x64 sparse")

-- Context shape from implemented migration/capture path.
db.mobs = {
  ["npc:77"] = {
    npcID = 77, name = "Synthetic Context Mob", classification = "elite",
    kills = 2, totalXP = 200, killsByMap = { ["12"] = 2 },
    killsAtLevel = { ["10"] = 2 }, killsByInstance = {},
    contexts = {
      synthetic = {
        playerLevel = 10, mobLevel = 11, groupSize = 1, mapID = 12,
        classification = "elite", buffSig = "none", samples = 2,
        sumBase = 40, sumBuffed = 60, sumTotal = 100,
        minBase = 20, maxBase = 20, lastSeen = 300,
      },
    },
  },
}
module:SyncModelMobsFromLegacy()
local mob = assert(module:GetModelMob("npc:77"))
assert(#mob.contexts == 1 and #mob.combat == 1 and #mob.xpContexts == 1,
  "context views")
assert(mob.combat[1].healthKnown == false, "context health claim")
pass("v2b_context_shape", "combat/XP/top8")

-- V-2C: block round-trip, checksum, backup/restore, save guard.
journey.mobs["npc:77"].byZone["12"].kills = 2
journey.zones["12"].kills = 2
module:MarkJourneyDirty({ mapID = 12 })
assert(module:FlushJourneyBlocks(), "synthetic flush")
module:ClearJourneyBlockCache()
local block = assert(module:GetJourneyBlockData("map:12"))
assert(block.schema == 3 and block.records["npc:77"], "block round-trip")
assert(block.zone and block.zone.record.kills == 2, "zone round-trip")
pass("v2c_block_roundtrip", "schema 3")

local saved = journey.blocks["map:12"]
module:OnJourneySaveBlocked()
local ok, reason = module:FlushJourneyBlocks()
assert(ok == false and reason == "save_blocked", "save guard")
module:ResetJourneySaveBlock()
assert(module:FlushJourneyBlocks(), "save guard recovery")
pass("v2c_save_guard", "blocked/recovered")

journey.mobs["npc:77"].byZone["12"].kills = 3
journey.zones["12"].kills = 3
module:MarkJourneyDirty({ mapID = 12 })
assert(module:FlushJourneyBlocks(), "backup flush")
local restored = module:RestoreJourneyBlocks()
assert(restored, "block restore")
module:ClearJourneyBlockCache()
local old = assert(module:GetJourneyBlockData("map:12"))
assert(old.records["npc:77"].kills == 2, "restored block content")
pass("v2c_backup_restore", "previous block")
assert(saved == nil or type(saved) == "table", "block reference")

-- V-2D: deterministic data/visual inputs, not frame appearance.
local colors = {}
for count = 1, 13 do colors[count] = module:GetHeatColor(count, 13, 1.0) end
local monotonic = true
for index = 2, #colors do
  if colors[index][4] < colors[index - 1][4] then monotonic = false end
end
assert(monotonic, "heat alpha is not monotonic")
pass("v2d_heat_ramp", "monotonic data")
report[#report + 1] = "v2d_frame_appearance=live-only"
report[#report + 1] = "v2c_real_savedvariables_timing=live-only"
report[#report + 1] = "v2b_real_event_order=live-only"

-- Synthetic evidence is deliberately not recorded as live evidence.
assert(not module:GetV2Evidence("v2b"), "synthetic run wrote live evidence")
local readiness = module:GetRetirementReadiness()
assert(readiness.ready == false, "synthetic run unlocked retirement")
report[#report + 1] = "retirement_gate=blocked"

print(table.concat(report, "\n"))
print("V-2 synthetic verification passed")
