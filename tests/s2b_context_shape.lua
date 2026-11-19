-- DS-17.12 S2B context shape test.

local F = dofile("tests/fixtures.lua")
local state = F.state
local module = F.Init()
local db = module.char

local function context(samples, xp)
  return {
    playerLevel = 20, mobLevel = 10, groupSize = 1, mapID = 12,
    classification = "normal", buffSig = "none",
    samples = samples, sumBase = xp, sumBuffed = xp, sumTotal = xp,
    minBase = 10, maxBase = 20, lastSeen = samples,
  }
end

local function mob(name, kills, contexts)
  return {
    name = name, classification = "normal",
    kills = kills, totalXP = kills * 10,
    firstSeen = 1, lastSeen = 20,
    killsAtLevel = { ["20"] = kills },
    killsByMap = { ["12"] = kills },
    killsByAreaLevel = {}, killsByInstance = {}, killsByInstanceLevel = {},
    contexts = contexts or {},
  }
end

module:ResetKills()
state.mapID = 12
state.playerLevel = 20
state.now = 100
module:OnJourneyEnterWorld()

local legacyContexts = {}
for index = 1, 10 do
  legacyContexts["ctx" .. index] = context(index, index * 10)
end
db.mobs["npc:5001"] = mob("Context Mob", 10, legacyContexts)
module:EnsureModelMobs()

local record = module:GetModelMob("npc:5001")
assert(record and record.source == "v2", "v2 context mob")
assert(#record.contexts == 10, "context array length")
assert(record.contexts[1].key == "ctx10", "context sample sort")
assert(#record.combat == 10 and #record.xpContexts == 10, "context views")
assert(record.combat[1].healthKnown == false, "combat health unknown")
assert(record.combat[1].deaths == nil, "combat deaths invented")
assert(#record.contextsTop8 == 8, "top8 length")
assert(record.contextsOther.key == "other", "other key")
assert(record.contextsOther.samples == 3, "other samples")
assert(record.contextsOther.sumBase == 30, "other sum")
local totalSamples = 0
for _, contextRecord in ipairs(record.contexts) do
  totalSamples = totalSamples + contextRecord.samples
end
assert(totalSamples == 55, "context total samples")
assert(totalSamples == (function()
  local top = 0
  for _, contextRecord in ipairs(record.contextsTop8) do
    top = top + contextRecord.samples
  end
  return top + record.contextsOther.samples
end)(), "top8+other total")

-- Context-only sync preserves v2-only fields.
db.mobs["npc:5001"].contexts["ctx11"] = context(20, 200)
module:SyncModelMobContextsFromLegacy("npc:5001")
local synced = module:GetModelMob("npc:5001")
assert(#synced.contexts == 11, "context sync length")
assert(synced.contexts[1].key == "ctx11", "context sync sort")
assert(synced.kills == 10, "context sync lost kills")
assert(synced.mobLevelSamples == 10, "context sync lost level samples")

-- Observation hook syncs the context shape.
local observationMob = db.mobs["npc:5001"]
module:RecordObservation(observationMob, {
  mobKey = "npc:5001", name = "Context Mob", playerLevel = 20, level = 10,
  groupSize = 1, mapID = 12, classification = "normal",
  buffSignature = "none", contextKey = "obs",
}, 10, 10, 10)
local observed = module:GetModelMob("npc:5001")
assert(#observed.contexts >= 11, "observation hook")

-- Merge/delete sync rebuild contexts from final legacy state.
db.mobs["name:other"] = mob("Other", 1, { merge = context(5, 50) })
module:EnsureModelMobs()
module:MergeMobEntries("name:other", "npc:5001", false)
local merged = module:GetModelMob("npc:5001")
assert(merged and #merged.contexts >= 12, "merge context sync")
module:RemoveMobEntry("npc:5001", true)
assert(module:GetModelMob("npc:5001") == nil, "delete context sync")

-- Bulk sync is idempotent and v2-only reads survive legacy removal.
db.mobs["npc:5002"] = mob("Bulk", 2, { bulk = context(2, 20) })
module:SyncModelMobsFromLegacy()
local first = #module:GetModelMob("npc:5002").contexts
module:SyncModelMobsFromLegacy()
assert(#module:GetModelMob("npc:5002").contexts == first, "bulk idempotence")
db.mobs = nil
assert(module:GetModelMob("npc:5002").contexts[1].key == "bulk", "v2-only contexts")

print("S2B context shape passed")
