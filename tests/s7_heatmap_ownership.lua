-- DS-17.18 S7 heatmap ownership test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

module:ResetKills()
state.mapID = 12
state.mapX, state.mapY = 0.5, 0.5
state.now = 50
module:OnJourneyEnterWorld()

db.heatmaps = {
  ["12"] = {
    gridSize = 64,
    cells = { [1] = 5, [2] = 5, [3] = 9, [4] = 1, [5] = 2 },
    total = 22,
    lastSeen = 50,
  },
  ["13"] = {
    gridSize = 64,
    cells = { [10] = 3 },
    total = 3,
    lastSeen = 40,
  },
}
module:EnsureModelHeatmaps()

local heatmap = module:GetModelHeatmap(12)
assert(heatmap and heatmap.source == "v2", "heatmap source")
assert(heatmap.gridSize == 64, "heatmap grid")
assert(heatmap.total == 22 and heatmap.lastSeen == 50, "heatmap totals")
assert(heatmap.cells[3].kills == 9 and heatmap.cells[1].kills == 5,
  "heatmap cells")
assert(heatmap.killsCoverage == "exact", "heatmap kill coverage")
assert(heatmap.cellXpCoverage == "unavailable", "heatmap XP coverage")
assert(heatmap.cellTimeCoverage == "unavailable", "heatmap time coverage")
assert(heatmap.cells[3].xp == nil and heatmap.cells[3].presenceSeconds == nil,
  "heatmap invented per-cell XP/time")

-- Top-10 is deterministic: count descending, then cell ascending.
assert(#heatmap.top10 == 5, "heatmap top-10 size")
assert(heatmap.top10[1].cell == 3 and heatmap.top10[1].count == 9,
  "heatmap top-10 leader")
assert(heatmap.top10[2].cell == 1 and heatmap.top10[3].cell == 2,
  "heatmap top-10 tie order")
assert(heatmap.top10[4].cell == 5 and heatmap.top10[5].cell == 4,
  "heatmap top-10 tail")

-- Production kill capture updates legacy and v2 without double counting.
state.now = 1000
state.mapID = 12
assert(module:RecordHeatmapKill(12, 0.0, 0.0), "heatmap kill")
assert(db.heatmaps["12"].cells[1] == 6, "legacy cell update")
local afterKill = module:GetModelHeatmap(12)
assert(afterKill.cells[1].kills == 6, "v2 cell update")
assert(afterKill.total == 23 and db.heatmaps["12"].total == 23,
  "kill total parity")
assert(afterKill.lastSeen == 1760000000 + state.now, "kill lastSeen")
assert(afterKill.top10[1].cell == 3 and afterKill.top10[2].cell == 1,
  "kill top-10 update")

-- Bulk sync is idempotent.
module:SyncModelHeatmapsFromLegacy()
local onceTotal = module:GetModelHeatmap(12).total
module:SyncModelHeatmapsFromLegacy()
assert(module:GetModelHeatmap(12).total == onceTotal, "heatmap sync idempotence")

-- Deleted legacy maps are removed from v2.
db.heatmaps["13"] = nil
module:SyncModelHeatmapsFromLegacy()
assert(module:GetModelHeatmap(13) == nil, "deleted heatmap removed")

-- Clear owns both the legacy projection and v2.
assert(module:ClearHeatmaps(), "heatmap clear")
assert(next(db.heatmaps) == nil, "legacy heatmap clear")
assert(next(db.journey.heatmaps) == nil, "v2 heatmap clear")
assert(module:GetModelHeatmap(12) == nil, "cleared heatmap read")

-- Cap/prune sync keeps the model aligned with the 64-map legacy cap.
db.heatmaps = {}
for index = 1, 65 do
  local mapID = 1000 + index
  db.heatmaps[tostring(mapID)] = {
    gridSize = 64,
    cells = { [1] = 1 },
    total = 1,
    lastSeen = index,
  }
end
module:NormalizeHeatmaps()
module:SyncModelHeatmapsFromLegacy()
local legacyCount, modelCount = 0, 0
for _ in pairs(db.heatmaps) do legacyCount = legacyCount + 1 end
for _ in pairs(db.journey.heatmaps) do modelCount = modelCount + 1 end
assert(legacyCount == 64 and modelCount == 64, "heatmap cap parity")
assert(module:GetModelHeatmap(1001) == nil, "oldest heatmap pruned")

-- V2-only reads survive removing the legacy projection.
local survivor = module:GetModelHeatmap(1065)
db.heatmaps = nil
local v2Only = module:GetModelHeatmap(1065)
assert(v2Only and v2Only.total == 1 and v2Only.cells[1].kills == 1,
  "v2-only heatmap")
assert(survivor.top10[1].cell == 1, "v2 top-10 survives")
assert(module:GetModelHeatmap(2000) == nil, "missing heatmap")

print("S7 heatmap ownership passed")
