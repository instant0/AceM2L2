-- Focused test for bounded capacity self-assessment and hysteresis.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
module:GetDataStats() -- establish initial pressure state

local function statsWith(ratio)
  local value = math.floor(1000 * ratio)
  return {
    mobs = value, maxMobs = 1000,
    quests = 0, maxQuests = 500,
    deaths = 0, maxDeaths = 100,
    respawnNpcs = 0, maxRespawnNpcs = 4000,
    heatmapZones = 0, maxHeatmapZones = 64,
    levelRecords = 0, maxLevelRecords = 200,
    rateSamples = 0, maxRateSamples = 240,
    instances = 0, maxInstances = 100,
  }
end

local low = module:GetCapacityAssessment(statsWith(0.10))
assert(low.pressure == "low" and low.store == "mobs", "low pressure")
assert(low.reason:find("10%", 1, true), "pressure reason")
assert(type(low.luaHeapKB) == "number" and low.luaHeapKB > 0, "Lua heap")
assert(tonumber(low.blockBytes) == 0, "block bytes")

local normal = module:GetCapacityAssessment(statsWith(0.70))
assert(normal.pressure == "normal", "normal pressure")

local high = module:GetCapacityAssessment(statsWith(0.92))
assert(high.pressure == "high", "high pressure")

local critical = module:GetCapacityAssessment(statsWith(0.99))
assert(critical.pressure == "critical", "critical pressure")
assert(critical.recommendation:find("compaction", 1, true), "critical action")

-- Hysteresis: drop only after the release threshold is crossed.
module:GetCapacityAssessment(statsWith(0.99))
local held = module:GetCapacityAssessment(statsWith(0.92))
assert(held.pressure == "critical", "critical pressure released too early")
local cooled = module:GetCapacityAssessment(statsWith(0.75))
assert(cooled.pressure == "normal", "pressure did not cool after release threshold")

-- GetDataStats exposes the assessment.
local stats = module:GetDataStats()
assert(type(stats.capacity) == "table"
  and type(stats.capacity.pressure) == "string", "stats capacity missing")

print("Capacity assessment passed")
