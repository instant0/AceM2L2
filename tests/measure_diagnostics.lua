-- HC-5 helper: compare GetDataStats() with a SavedVariables file.
-- Usage: lua tests/measure_diagnostics.lua [forever|midnight] <SavedVariables file>

local scenario = arg[1] or "forever"
local path = arg[2]
if not path then
  print("usage: lua tests/measure_diagnostics.lua [forever|midnight] <SavedVariables file>")
  return
end
arg[1] = scenario

local F = dofile("tests/fixtures.lua")
local module = F.Init()
dofile(path)
module:EnsureDB()

local handle = assert(io.open(path, "rb"))
local actual = #handle:read("*a")
handle:close()

local stats = module:GetDataStats()
print(string.format("actual_bytes=%d estimated_bytes=%d ratio=%.3f truncated=%s",
  actual, stats.estimatedBytes, stats.estimatedBytes / actual,
  tostring(stats.estimateTruncated)))
for _, key in ipairs({
  "mobs", "quests", "deaths", "respawnNpcs", "respawnSamples",
  "heatmapZones", "heatmapCells", "heatmapEnabled", "estimatedHeatmapBytes",
  "instances", "instanceKills", "levelRecords", "rateSamples", "contexts",
  "calibrationEntries", "totalTracked",
}) do
  print(string.format("%s=%s", key, tostring(stats[key])))
end
