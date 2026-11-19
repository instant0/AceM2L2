-- V-2A probe/evidence harness test.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char

local probe = module:CollectV2Probe()
assert(type(probe) == "table" and type(probe.at) == "number", "probe timestamp")
assert(type(probe.apis) == "table" and type(probe.fields) == "table",
  "probe sections")
assert(probe.fields.deathAttribution == false, "unimplemented death claim")
assert(probe.fields.heatmapCellXP == false, "unimplemented heatmap XP claim")
assert(probe.values.groupSize and probe.values.groupSize >= 1, "group probe")

assert(module:RecordV2Evidence("v2a", probe), "record evidence")
assert(module:GetV2Evidence("v2a") == probe, "evidence lookup")

local readiness = module:GetRetirementReadiness()
assert(readiness.gates.v2a == true, "captured V-2A not accepted")
assert(readiness.gates.v2b == false, "V-2B accepted without evidence")
assert(readiness.ready == false, "capture alone unlocked retirement")
assert(readiness.nextStage == "S10C-2", "next stage")

assert(pcall(module.HandleCommand, module, "v2probe"), "v2probe command failed")
assert(module:GetV2Evidence("v2a"), "command did not store evidence")

print("V-2A probe harness passed")
