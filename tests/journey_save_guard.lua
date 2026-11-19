-- Focused production test for Journey block backup and oversize save guard.

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local db = module.char
local state = F.state

db.mobs = {
  ["npc:2001"] = {
    npcID = 2001, name = "Guard Mob", classification = "normal",
    kills = 3, totalXP = 300, killsByMap = { ["12"] = 3 },
    killsByInstance = {}, contexts = {},
  },
}
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()
assert(module:FlushJourneyBlocks())
module:ClearJourneyBlockCache()
local before = assert(module:GetJourneyBlock("map:12"))
assert(before["npc:2001"].kills == 3, "initial block")

-- Backup before a dirty rewrite.
local modelMob = db.journey.mobs["npc:2001"]
modelMob.kills = 7
modelMob.byZone["12"].kills = 7
module:MarkJourneyDirty({ mapID = 12 })
assert(module:FlushJourneyBlocks())
local saveState = module:GetJourneySaveState()
assert(saveState.backupZones >= 1, "block backup missing")
module:ClearJourneyBlockCache()
local after = assert(module:GetJourneyBlock("map:12"))
assert(after["npc:2001"].kills == 7, "updated block")

-- Restore the previous block.
local restored, count = module:RestoreJourneyBlocks()
assert(restored and count >= 1, "restore failed")
module:ClearJourneyBlockCache()
local old = assert(module:GetJourneyBlock("map:12"))
assert(old["npc:2001"].kills == 3, "restored block content")

-- Oversize event from another addon must be ignored.
module:OnSavedVariablesTooLarge("SAVED_VARIABLES_TOO_LARGE", "OtherAddon")
assert(module:GetJourneySaveState().saveBlocked == false, "foreign oversize ignored")

-- Oversize event for AceM2L2 blocks further block writes.
module:OnSavedVariablesTooLarge("SAVED_VARIABLES_TOO_LARGE", "AceM2L2")
assert(module:GetJourneySaveState().saveBlocked == true, "save should block")
modelMob.kills = 9
modelMob.byZone["12"].kills = 9
module:MarkJourneyDirty({ mapID = 12 })
local ok, reason = module:FlushJourneyBlocks()
assert(ok == false and reason == "save_blocked", "blocked flush should refuse")
module:ClearJourneyBlockCache()
local blocked = assert(module:GetJourneyBlock("map:12"))
assert(blocked["npc:2001"].kills == 3, "blocked flush must not overwrite")

-- Recovery path can resume after explicit reset.
module:ResetJourneySaveBlock()
assert(module:GetJourneySaveState().saveBlocked == false, "reset save block")
assert(module:FlushJourneyBlocks())
module:ClearJourneyBlockCache()
local resumed = assert(module:GetJourneyBlock("map:12"))
assert(resumed["npc:2001"].kills == 9, "resumed flush content")

print("Journey save guard passed")
