-- Focused UI-5 test: heatmap zone/instance selector model and popup.
-- Usage: lua tests/heatmap_selector.lua forever

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local function heatmap(total, lastSeen, cells)
  return {
    gridSize = 64,
    cells = cells or { [1] = total },
    total = total,
    lastSeen = lastSeen or 1,
  }
end

state.now = 1000
db.heatmaps = {
  ["1421"] = heatmap(10, 50, { [1] = 3, [2] = 7 }),
  ["1424"] = heatmap(5, 40, { [1] = 5 }),
  ["1234"] = heatmap(7, 60, { [1] = 4, [2] = 3 }),
  ["1420"] = heatmap(2, 30, { [1] = 2 }),
}
for index = 1, 8 do
  db.heatmaps[tostring(1400 + index)] = heatmap(1, 10 + index)
end
db.areas = {
  ["1421"] = 20, ["1424"] = 12, ["1420"] = 2,
}
db.areaLevels = {
  ["1421"] = { ["10"] = 5, ["12"] = 15 },
  ["1424"] = { ["8"] = 12 },
}
db.instances = {
  ["id:555:1"] = {
    name = "Test Dungeon", mapID = 1234, kills = 7,
    killsAtLevel = { ["20"] = 7 }, lastSeen = 60,
  },
  ["id:555:2"] = {
    name = "Test Dungeon Heroic", mapID = 1234, kills = 3,
    killsAtLevel = { ["22"] = 3 }, lastSeen = 70,
  },
  ["id:9999:1"] = {
    name = "No Heatmap Instance", mapID = 947, kills = 4,
    killsAtLevel = { ["30"] = 4 }, lastSeen = 80,
  },
}
module:SyncModelZonesFromLegacy()
module:SyncModelInstancesFromLegacy()
module:SyncModelHeatmapsFromLegacy()
module:InvalidateHeatmapCache()
module:InvalidateHeatmapZoneCache()

module:OpenUI()
module:SetTab("heatmap")
assert(module.ui and module.ui.heatmap, "heatmap UI missing")
local heatmapUI = module.ui.heatmap
assert(heatmapUI.selectorMenu, "selector menu missing")
assert(heatmapUI.selectorRows and #heatmapUI.selectorRows == 10,
  "selector row pool mismatch")

module:RefreshHeatmapSelector()
local entries = heatmapUI.selectorEntries
assert(#entries == 12, "selector row count: " .. tostring(#entries))
local dungeonRows = 0
for _, entry in ipairs(entries) do
  if entry.mapID == 1234 then dungeonRows = dungeonRows + 1 end
end
assert(dungeonRows == 1, "instance map ID was duplicated")

local function entryByName(name)
  for _, entry in ipairs(entries) do
    if entry.name == name then return entry end
  end
end

local hillsbrad = entryByName("Hillsbrad Foothills")
local westfall = entryByName("Map 1424")
local dungeon = entryByName("Test Dungeon Heroic")
local tirisfal = entryByName("Tirisfal Glades")
assert(hillsbrad and westfall and dungeon and tirisfal, "expected rows missing")
assert(entryByName("No Heatmap Instance") == nil, "non-heatmap instance listed")

-- Alphabetical order, case-insensitive.
local previous = ""
for _, entry in ipairs(entries) do
  local name = string.lower(entry.name)
  assert(name >= previous, "selector is not alphabetical: " .. entry.name)
  previous = name
end
assert(entries[1].name == "Hillsbrad Foothills", "first row")
assert(entries[2].name:find("Map 1401", 1, true), "second row")

-- Kills are heatmap kills; levels are recorded player levels.
assert(hillsbrad.kills == 10, "heatmap kills used")
assert(hillsbrad.minLevel == 10 and hillsbrad.maxLevel == 12,
  "zone level range")
assert(westfall.kills == 5 and westfall.minLevel == 8
  and westfall.maxLevel == 8, "single-level range")
assert(tirisfal.minLevel == nil and tirisfal.maxLevel == nil,
  "missing level range invented")
assert(dungeon.instance == true, "instance row not tagged")
assert(dungeon.kills == 7, "instance heatmap kills")
assert(dungeon.minLevel == 20 and dungeon.maxLevel == 22,
  "merged instance level range")

-- Visual rows show the expected columns.
assert(heatmapUI.selectorRows[1].nameLabel.text == "Hillsbrad Foothills",
  "visual name")
assert(heatmapUI.selectorRows[1].killsLabel.text == "10", "visual kills")
assert(heatmapUI.selectorRows[1].levelLabel.text == "10-12", "visual levels")
local dungeonRow
for index = 1, #entries do
  if entries[index].name == "Test Dungeon Heroic" then dungeonRow = index end
end
module:SetHeatmapSelectorOffset(dungeonRow - 1)
local visible
for index = 1, #heatmapUI.selectorRows do
  if heatmapUI.selectorRows[index].entry == dungeon then
    visible = heatmapUI.selectorRows[index]
  end
end
assert(visible and visible.tagLabel.text == "Dungeon", "visual dungeon tag")

-- Popup open/close and selection.
assert(module:OpenHeatmapSelector(), "selector did not open")
assert(heatmapUI.selectorMenu.shown, "selector menu hidden")
assert(heatmapUI.selectorCatcher.shown, "outside-click catcher hidden")
assert(heatmapUI.selectorPage.text:find("of 12", 1, true), "page count")

module:SetHeatmapSelectorOffset(0)
local firstRow = heatmapUI.selectorRows[1]
firstRow.scripts.OnClick(firstRow)
assert(module.heatmapZoneKey == hillsbrad.key, "selection did not update key")
assert(not heatmapUI.selectorMenu.shown, "selector did not close on select")
assert(heatmapUI.renderedZoneKey == hillsbrad.key, "heatmap did not refresh")

-- Arrows still page through zones.
local before = module.heatmapZoneKey
module:SelectHeatmapZone(1)
assert(module.heatmapZoneKey ~= before, "arrow paging stopped working")

-- Close on tab change.
module:SetTab("heatmap")
assert(module:OpenHeatmapSelector(), "selector reopen failed")
module:SetTab("overview")
assert(not heatmapUI.selectorMenu.shown, "selector stayed open after tab change")

-- Close on window hide.
module:SetTab("heatmap")
assert(module:OpenHeatmapSelector(), "selector reopen 2 failed")
module.ui:Hide()
assert(not heatmapUI.selectorMenu.shown, "selector stayed open after window hide")

-- Close on outside click and on resource release.
module.ui:Show()
module:SetTab("heatmap")
assert(module:OpenHeatmapSelector(), "selector reopen 3 failed")
heatmapUI.selectorCatcher.scripts.OnClick(heatmapUI.selectorCatcher)
assert(not heatmapUI.selectorMenu.shown, "outside click did not close selector")
assert(module:OpenHeatmapSelector(), "selector reopen 4 failed")
module:ReleaseHeatmapUIResources()
assert(not heatmapUI.selectorMenu.shown, "release did not close selector")

-- The Select button toggles the menu.
local selectButton = heatmapUI.selectButton
selectButton.scripts.OnClick(selectButton)
assert(heatmapUI.selectorMenu.shown, "Select button did not open")
selectButton.scripts.OnClick(selectButton)
assert(not heatmapUI.selectorMenu.shown, "Select button did not close")

-- Escape frame is registered for the named menu.
local registered = false
for _, name in ipairs(UISpecialFrames or {}) do
  if name == heatmapUI.selectorMenu.name then registered = true end
end
assert(registered, "selector menu not registered for Escape")

-- Metadata building must not decode Journey blocks.
module.ui:Show()
module:SetTab("heatmap")
module.journeyDecodedBlocks = 0
module:RefreshHeatmapSelector()
assert(module.journeyDecodedBlocks == 0, "selector decoded a block")

print("Heatmap selector passed")
