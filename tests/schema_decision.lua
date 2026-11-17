-- Focused test for H64-10 legacy heatmap inference and schema decision.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

-- Pre-2.2.0 32x32 save without gridSize is inferred as 16x16. The ambiguity is
-- documented; the total is preserved while geometry is coarser.
db.heatmaps = { ["12"] = { cells = { [256] = 16 } } }
module:InvalidateHeatmapCache()
local zones = module:GetHeatmapZones()
assert(#zones == 1, "legacy ambiguous zone missing")
assert(zones[1].gridSize == 64, "legacy inference did not upscale")
assert(zones[1].total == 16, "legacy inference lost kills")
local upgraded = 0
for _ in pairs(zones[1].cells) do upgraded = upgraded + 1 end
assert(upgraded == 16, "legacy inference did not split to 4x4 blocks")

-- Explicit 32x32 still migrates as 32x32.
db.heatmaps = { ["12"] = { gridSize = 32, cells = { [1] = 4 } } }
module:InvalidateHeatmapCache()
zones = module:GetHeatmapZones()
assert(zones[1].total == 4 and zones[1].cells[1] == 1
  and zones[1].cells[2] == 1 and zones[1].cells[65] == 1
  and zones[1].cells[66] == 1, "32x32 migration changed")

-- Modern 64x64 saves carry gridSize and pass through unchanged.
db.heatmaps = { ["12"] = { gridSize = 64, cells = { [4096] = 3 } } }
module:InvalidateHeatmapCache()
zones = module:GetHeatmapZones()
assert(zones[1].total == 3 and zones[1].cells[4096] == 3,
  "64x64 save changed")

-- The per-client data schema remains 1; 64x64 is expressed by gridSize.
local root = AceM2L2CharDB and AceM2L2CharDB.xpTooltip
local client = root and root.clients and root.clients[module:GetProjectID()]
assert(client and client.dataSchema == 1, "per-client data schema bumped")

print("Schema decision passed")
