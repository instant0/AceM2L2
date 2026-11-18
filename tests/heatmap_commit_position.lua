-- Focused G-1B test: heatmap kill coordinates use a same-map commit-time
-- refresh, replace-only, without changing attribution.
-- Usage: lua tests/heatmap_commit_position.lua forever

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local function reset()
  module:ResetKills()
  state.now = 1000
  state.groupSize = 1
  state.mapID = 12
  state.mapX, state.mapY = 0.5, 0.5
  state.inInstance = false
  state.instanceType = nil
  state.instanceName = nil
  state.instanceMapID = nil
  state.difficultyID = 0
  module:RefreshInstanceState()
end

local function kill(name, npcID, mapID, x, y)
  return module:RecordKill({
    name = name,
    npcID = npcID,
    guid = "Creature-0-0-0-0-" .. tostring(npcID) .. "-00000001",
    mapID = mapID,
    x = x,
    y = y,
    playerLevel = 10,
    level = 10,
    classification = "normal",
    groupSize = state.groupSize or 1,
    buffSignature = "none",
  }, 0, 0, 0, "test")
end

local function cellKey(x, y)
  local col = math.floor(x * 64) + 1
  local row = math.floor(y * 64) + 1
  return (row - 1) * 64 + col
end

local function cellCount(mapID, x, y)
  local entry = db.heatmaps and db.heatmaps[tostring(mapID)]
  if type(entry) ~= "table" or type(entry.cells) ~= "table" then
    return 0
  end
  return tonumber(entry.cells[cellKey(x, y)]) or 0
end

local function heatmapTotal(mapID)
  local entry = db.heatmaps and db.heatmaps[tostring(mapID)]
  if type(entry) ~= "table" then
    return 0
  end
  return tonumber(entry.total) or 0
end

-- Same map: the acquisition snapshot is replaced by the commit position.
reset()
state.mapX, state.mapY = 0.9, 0.1
kill("Mover", 2001, 12, 0.1, 0.1)
assert(cellCount(12, 0.9, 0.1) == 1, "commit position was not used")
assert(cellCount(12, 0.1, 0.1) == 0, "stale acquisition position was used")
assert(db.areas["12"] == 1, "area attribution changed")
assert(db.mobs["npc:2001"].killsByMap["12"] == 1, "mob map attribution changed")

-- Cross-map: skip the cell, keep the original kill attribution.
reset()
state.mapID = 13
state.mapX, state.mapY = 0.9, 0.1
kill("CrossMap", 2002, 12, 0.1, 0.1)
assert(heatmapTotal(12) == 0 and heatmapTotal(13) == 0,
  "cross-map heatmap cell was written")
assert(db.areas["12"] == 1, "cross-map kill lost its area attribution")
assert(db.areas["13"] == nil, "cross-map kill moved to the fresh map")

-- Fresh read unavailable: keep the same-map snapshot.
reset()
local originalPosition = module.GetPlayerMapPosition
module.GetPlayerMapPosition = function()
  return nil
end
local ok, err = pcall(kill, "NoFresh", 2003, 12, 0.25, 0.75)
module.GetPlayerMapPosition = originalPosition
assert(ok, err)
assert(cellCount(12, 0.25, 0.75) == 1, "snapshot fallback failed")

-- Replace-only: no snapshot means no cell even when a fresh position exists.
reset()
state.mapX, state.mapY = 0.9, 0.1
kill("NoSnapshot", 2004, 12, nil, nil)
assert(heatmapTotal(12) == 0, "missing snapshot created a cell")

-- Invalid snapshot coordinates are not used.
reset()
state.mapX, state.mapY = 0.9, 0.1
kill("BadSnapshot", 2005, 12, 1.2, 0.5)
assert(heatmapTotal(12) == 0, "out-of-range snapshot created a cell")

-- Late-chat XP must not write a second heatmap cell.
reset()
state.mapX, state.mapY = 0.9, 0.1
local _, mobKey = kill("LateXP", 2006, 12, 0.1, 0.1)
local before = heatmapTotal(12)
module:AddKillXP(
  { resolvedMobKey = mobKey },
  { name = "LateXP", playerLevel = 10, mapID = 12 },
  50, 50, 50, true
)
assert(heatmapTotal(12) == before, "add_xp wrote a second heatmap cell")
assert(cellCount(12, 0.9, 0.1) == 1, "add_xp changed the committed cell")

-- Group kills keep the local player position and do not query the group.
reset()
state.groupSize = 3
state.mapX, state.mapY = 0.9, 0.1
kill("GroupMob", 2007, 12, 0.1, 0.1)
assert(cellCount(12, 0.9, 0.1) == 1, "group kill did not use player position")

-- Non-attributable instance: no world-map cell.
reset()
state.inInstance = true
state.instanceType = "party"
state.instanceName = "Test Instance"
state.instanceMapID = 947
state.difficultyID = 0
state.mapID = 947
module:RefreshInstanceState()
kill("InstanceMob", 2008, 0, 0.5, 0.5)
assert(heatmapTotal(12) == 0, "non-attributable instance leaked to world map")
assert(not (db.heatmaps and db.heatmaps["947"]),
  "non-attributable instance got a heatmap entry")

-- Stale open-world snapshot must not become a world-map cell after zoning.
reset()
state.inInstance = true
state.instanceType = "party"
state.instanceName = "Test Instance"
state.instanceMapID = 947
state.difficultyID = 0
state.mapID = 947
module:RefreshInstanceState()
kill("StaleWorld", 2009, 12, 0.1, 0.1)
assert(heatmapTotal(12) == 0, "stale world snapshot leaked into instance")

-- Attributable instance maps keep their own heatmap entry.
reset()
state.inInstance = true
state.instanceType = "party"
state.instanceName = "Test Dungeon"
state.instanceMapID = 555
state.difficultyID = 1
state.mapID = 1234
module:RefreshInstanceState()
state.mapX, state.mapY = 0.75, 0.25
kill("DungeonMob", 2010, 1234, 0.25, 0.75)
assert(cellCount(1234, 0.75, 0.25) == 1,
  "attributable instance heatmap was not refreshed")
assert(db.areas["1234"] == nil, "instance map was counted as an area")

-- Death coordinates are independent and still captured at death time.
reset()
state.mapID = 12
state.mapX, state.mapY = 0.2, 0.8
assert(module:HandlePlayerDeath(), "player death was not recorded")
local death = db.deaths[#db.deaths]
assert(death.x == 0.2 and death.y == 0.8, "death position changed")

-- Quest anchors remain turn-in positions.
reset()
state.mapID = 12
state.mapX, state.mapY = 0.3, 0.7
module:OnJourneyQuestTurnIn(999, "Anchor Quest", 100)
local journey = module:EnsureJourney()
local anchor = journey.questAnchors[#journey.questAnchors]
assert(anchor and anchor.x == 0.3 and anchor.y == 0.7,
  "quest anchor position changed")

print("Heatmap commit position passed")
