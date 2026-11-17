-- Focused test for the hot context cap and age pruning.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char
local now = module.Util.Epoch()
state.now = 1000

local mob = {
  npcID = 1, name = "Context Mob", classification = "normal",
  kills = 1, sessionKills = 1, totalXP = 100, sessionXP = 100,
  sessionXPKnown = true, firstSeen = now - 1000, lastSeen = now,
  killsAtLevel = { ["10"] = 1 }, killsByMap = {}, killsByAreaLevel = {},
  killsByInstance = {}, killsByInstanceLevel = {}, contexts = {},
  xp = { samples = 1, sumBase = 100, sumBuffed = 100, sumTotal = 100 },
}
db.mobs = { ["npc:1"] = mob }
for index = 1, 20 do
  mob.contexts["context:" .. tostring(index)] = {
    playerLevel = 10, mobLevel = 10, groupSize = 1, mapID = 12,
    classification = "normal", buffSig = "none",
    samples = index, sumBase = index * 10, sumTotal = index * 10,
    lastSeen = now - index,
  }
end
db.mobs["npc:2"] = {
  npcID = 2, name = "Old Context Mob", classification = "normal",
  kills = 1, sessionKills = 0, totalXP = 0, sessionXP = 0,
  firstSeen = now - 200000, lastSeen = now,
  killsAtLevel = {}, killsByMap = {}, killsByAreaLevel = {},
  killsByInstance = {}, killsByInstanceLevel = {},
  contexts = {
    old = {
      samples = 1, sumBase = 1, sumTotal = 1,
      lastSeen = now - module.Util.CONTEXT_MAX_AGE - 1,
    },
  },
  xp = { samples = 0 },
}

module:Prune()

local contextCount = 0
for _ in pairs(mob.contexts) do contextCount = contextCount + 1 end
assert(contextCount == module.Util.MAX_CONTEXTS_PER_MOB, "context cap not enforced")
assert(mob.contexts["context:1"] and not mob.contexts["context:20"],
  "context pruning kept the wrong entries")
local oldMob = db.mobs["npc:2"]
assert(oldMob and next(oldMob.contexts) == nil, "expired context not removed")

print("Context cap passed")
