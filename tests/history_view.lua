-- Focused production test for the Deaths/Respawns history view.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

state.now = 1000
local now = module.Util.Epoch()
db.deaths = {}
db.respawns = {}
assert(module:RecordDeath(12, 0.1, 0.9, now - 120), "death 12")
assert(module:RecordDeath(13, 0.5, 0.5, now - 60), "death 13")
assert(module:RecordRespawnInterval(1234, "Defias Pillager", 300), "respawn 1")
assert(module:RecordRespawnInterval(1234, "Defias Pillager", 300), "respawn 2")
assert(module:RecordRespawnInterval(1234, "Defias Pillager", 300), "respawn 3")
assert(module:RecordRespawnInterval(5678, "Gnoll", 600), "respawn 4")

local originalPrint = AceM2L2.Print
local function capture(fn)
  local lines = {}
  AceM2L2.Print = function(_, text) lines[#lines + 1] = tostring(text) end
  local ok, err = pcall(fn)
  AceM2L2.Print = originalPrint
  assert(ok, err)
  return table.concat(lines, "\n")
end

module:OpenUI()
module:SetTab("deaths")
module:BuildList()
assert(#module.currentList == 4, "history row count")

local deaths, respawns = {}, {}
for index, row in ipairs(module.currentList) do
  if row.kind == "death" then
    deaths[row.mapID] = index
  elseif row.kind == "respawn" then
    respawns[row.npcID] = index
  end
end
assert(deaths[12] and deaths[13], "death rows missing")
assert(respawns[1234] and respawns[5678], "respawn rows missing")

-- Search filters deaths by map name and respawns by NPC name.
module.searchText = "Westfall"
module:BuildList()
assert(#module.currentList == 1 and module.currentList[1].kind == "death"
  and module.currentList[1].mapID == 12, "history search by map")
module.searchText = "Defias"
module:BuildList()
assert(#module.currentList == 1 and module.currentList[1].npcID == 1234,
  "history search by NPC")
module.searchText = ""
module:BuildList()

-- Name sort is deterministic.
module:GetSettings().ui.historySort = "name"
module:BuildList()
local previous = ""
for _, row in ipairs(module.currentList) do
  local current = tostring(row.label):lower()
  assert(current >= previous, "history name sort")
  previous = current
end
module:GetSettings().ui.historySort = "recent"
module:BuildList()
deaths, respawns = {}, {}
for index, row in ipairs(module.currentList) do
  if row.kind == "death" then
    deaths[row.mapID] = index
  elseif row.kind == "respawn" then
    respawns[row.npcID] = index
  end
end

-- Death detail matches the command values.
module.selectedIndex = deaths[12]
module:UpdateDetail()
local deathText = module.ui.details.text
assert(module.ui.heroName.text == "Player death", "death detail title")
assert(deathText:find("Westfall", 1, true), "death detail map")
assert(deathText:find("10.0, 90.0", 1, true), "death detail coordinates")

-- Respawn detail matches the command values.
module.selectedIndex = respawns[1234]
module:UpdateDetail()
local respawnText = module.ui.details.text
assert(module.ui.heroName.text == "Defias Pillager", "respawn detail title")
assert(respawnText:find("Average: 5m", 1, true), "respawn average")
assert(respawnText:find("Range: 5m - 5m", 1, true), "respawn range")
assert(respawnText:find("Samples: 3", 1, true), "respawn samples")

module.selectedIndex = respawns[5678]
module:UpdateDetail()
assert(module.ui.details.text:find("needs 3 samples (1 recorded)", 1, true),
  "respawn low-sample state")

local deathOutput = capture(function() module:PrintDeaths(nil) end)
local respawnOutput = capture(function() module:PrintRespawns(nil) end)
assert(deathOutput:find("Westfall (10.0, 90.0)", 1, true), "death command parity")
assert(deathOutput:find("Map 13 (50.0, 50.0)", 1, true), "death command parity 2")
assert(respawnOutput:find("Defias Pillager: 5m average (5m-5m), 3 samples", 1, true),
  "respawn command parity")
assert(respawnOutput:find("Gnoll: 1 sample(s), need 3 for an average", 1, true),
  "respawn low-sample command parity")

-- Empty state is explicit.
db.deaths, db.respawns = {}, {}
module:SetTab("deaths")
module:UpdateDetail()
assert(module.ui.heroName.text == "Death & respawn history", "history empty title")
assert(module.ui.heroSub.text:find("No death or respawn history", 1, true),
  "history empty state")

-- Unavailable state is explicit, not a false empty record.
local originalSupports = module.Supports
module.Supports = function(self, key)
  if key == "hasMapPosition" or key == "hasGUIDIdentity" then
    return false
  end
  return originalSupports(self, key)
end
module:SetTab("deaths")
module:UpdateDetail()
assert(module.ui.heroSub.text:find("unavailable on this client", 1, true),
  "history unavailable state")
module.Supports = originalSupports

-- Displayed rows are capped, not the stored data.
db.deaths = {}
for index = 1, 100 do
  db.deaths[#db.deaths + 1] = {
    at = now - index * 10, mapID = 12, x = 0.5, y = 0.5,
  }
end
db.respawns = {}
for index = 1, 60 do
  db.respawns[index] = {
    name = "NPC " .. tostring(index),
    intervals = { 300, 300, 300 },
    lastSeen = now - index,
    lastDeath = now - index - 300,
  }
end
module:SetTab("deaths")
module:BuildList()
assert(#module.currentList == 75, "history displayed row cap")

print("History view passed")
