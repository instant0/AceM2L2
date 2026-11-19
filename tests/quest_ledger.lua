-- Focused production test for the quest XP ledger view.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

state.now = 1000
local now = module.Util.Epoch()
db.quests = {
  ["quest:1"] = {
    id = 1, name = "Alpha Quest", count = 3, totalXP = 900,
    firstSeen = now - 900, lastSeen = now - 300, lastXP = 300,
  },
  ["quest:2"] = {
    id = 2, name = "Beta Quest", count = 5, totalXP = 1000,
    firstSeen = now - 1000, lastSeen = now - 100, lastXP = 200,
  },
  ["quest:3"] = {
    id = 3, name = "Gamma Quest", count = 1, totalXP = 200,
    firstSeen = now - 50, lastSeen = now - 200, lastXP = 200,
  },
  ["quest:4"] = {
    id = 4, name = "Ignored Quest", count = 0, totalXP = 0,
    firstSeen = now, lastSeen = now,
  },
}
module:SyncModelQuestsFromLegacy()

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
module:SetTab("quests")
module:BuildList()
assert(module.tabs.quests, "quest tab missing")
assert(#module.currentList == 3, "quest ledger row count")
assert(module.currentList[1].label == "Beta Quest", "quest default XP sort")

module.searchText = "Alpha"
module:BuildList()
assert(#module.currentList == 1 and module.currentList[1].label == "Alpha Quest",
  "quest search")
module.searchText = ""
module:BuildList()

module:GetSettings().ui.questSort = "count"
module:BuildList()
assert(module.currentList[1].label == "Beta Quest"
  and module.currentList[2].label == "Alpha Quest", "quest count sort")
module:GetSettings().ui.questSort = "name"
module:BuildList()
assert(module.currentList[1].label == "Alpha Quest", "quest name sort")
module:GetSettings().ui.questSort = "recent"
module:BuildList()
assert(module.currentList[1].label == "Beta Quest", "quest recent sort")
module:GetSettings().ui.questSort = "xp"
module:BuildList()

-- Detail matches the command values.
for index, row in ipairs(module.currentList) do
  if row.label == "Alpha Quest" then
    module.selectedIndex = index
    break
  end
end
module:UpdateDetail()
assert(module.ui.heroName.text == "Alpha Quest", "quest detail title")
assert(module.ui.heroSub.text:find("3 gains", 1, true), "quest detail gains")
assert(module.ui.details.text:find("Total XP: 900", 1, true), "quest detail XP")
assert(module.ui.details.text:find("Average per gain: 300", 1, true),
  "quest detail average")

local commandOutput = capture(function() module:PrintQuests() end)
assert(commandOutput:find("Quest XP: 9 gains, 2100 XP", 1, true),
  "quest command summary parity")
assert(commandOutput:find("Beta Quest", 1, true)
  and commandOutput:find("5 gains", 1, true)
  and commandOutput:find("1000 XP", 1, true), "quest command row parity")

-- Empty state.
db.quests = {}
module:SyncModelQuestsFromLegacy()
module:SetTab("quests")
module:UpdateDetail()
assert(module.ui.heroName.text == "Quest XP ledger", "quest empty title")
assert(module.ui.heroSub.text:find("No quest XP recorded", 1, true),
  "quest empty state")

-- Midnight / unsupported state is explicit.
local originalSupports = module.Supports
module.Supports = function(self, key)
  if key == "hasPerMobXP" then return false end
  return originalSupports(self, key)
end
module:SetTab("quests")
module:BuildList()
module:UpdateDetail()
assert(module.ui.heroSub.text:find("not tracked on this client", 1, true),
  "quest unsupported state")
module.Supports = originalSupports

-- Displayed rows are capped, not the stored ledger.
db.quests = {}
for index = 1, 150 do
  db.quests["quest:" .. tostring(index)] = {
    id = index, name = "Quest " .. tostring(index), count = 1,
    totalXP = index * 10, firstSeen = now - index, lastSeen = now - index,
  }
end
module:SyncModelQuestsFromLegacy()
module:SetTab("quests")
module:BuildList()
assert(#module.currentList == 100, "quest displayed row cap")

print("Quest ledger passed")
