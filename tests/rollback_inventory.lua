-- Static lock for the two rollout flags before final retirement.

local function read(path)
  local file = assert(io.open(path, "r"), "missing " .. path)
  local text = file:read("*a")
  file:close()
  return text
end

local function count(text, needle)
  local total, start = 0, 1
  while true do
    local first, last = text:find(needle, start, true)
    if not first then break end
    total = total + 1
    start = last + 1
  end
  return total
end

local expected = {
  ["KillHistory/JourneyIndex.lua"] = { indexViews = 2, useIndex = 1 },
  ["KillHistory/JourneyStorage.lua"] = { blockFallback = 2 },
  ["KillHistory/Tooltip.lua"] = { blockFallback = 1 },
  ["KillHistory/UI/Detail.lua"] = { blockFallback = 1, useIndex = 1 },
  ["KillHistory/Commands.lua"] = { useIndex = 5 },
  ["KillHistory/Heatmap.lua"] = { useIndex = 2 },
  ["KillHistory/JourneyQueries.lua"] = { useIndex = 5 },
  ["KillHistory/UI/List.lua"] = { useIndex = 3 },
  ["KillHistory/UI/Overview.lua"] = { useIndex = 1 },
}

local seenFiles = {}
local handle = assert(io.popen("find KillHistory -type f -name '*.lua'"))
for path in handle:lines() do
  local text = read(path)
  local indexViews = count(text, "indexViews")
  local blockFallback = count(text, "blockReadFallback")
  local useIndex = count(text, "UseJourneyIndexViews")
  if indexViews > 0 or blockFallback > 0 or useIndex > 0 then
    seenFiles[path] = {
      indexViews = indexViews,
      blockFallback = blockFallback,
      useIndex = useIndex,
    }
  end
  for name in text:gmatch("journey%.([%a_][%w_]*[Ff]allback)") do
    assert(name == "blockReadFallback",
      "unexpected Journey fallback flag in " .. path .. ": " .. name)
  end
end
handle:close()

for path, expectedCounts in pairs(expected) do
  local actual = seenFiles[path]
  assert(actual, "expected flag references missing from " .. path)
  for key, value in pairs(expectedCounts) do
    assert(actual[key] == value, string.format(
      "%s %s count changed: expected %d, got %d",
      path, key, value, actual[key] or 0
    ))
  end
end

for path in pairs(seenFiles) do
  assert(expected[path], "unexpected flag reference in " .. path)
end

print("Rollback inventory passed")
