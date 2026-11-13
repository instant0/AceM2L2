-- Deterministic behavior snapshot for refactor comparisons.
-- Usage: lua tests/snapshot.lua [forever]

local F = dofile("tests/fixtures.lua")
local module = F.Init()
local SetTarget = F.SetTarget
local RunTimers = F.RunTimers
local GameTooltip = F.GameTooltip

if F.SCENARIO ~= "forever" then
  print("snapshot: only the forever scenario is supported")
  return
end

module:ResetKills()
SetTarget("Defias Pillager", "Creature-0-1-2-3-1234-00000001")
module:OnTargetChanged("PLAYER_TARGET_CHANGED")
module:OnXPChat("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pillager dies, you gain 95 experience.")
RunTimers()

local profile = module:GetClientProfile()
print("project=" .. tostring(WOW_PROJECT_ID))
print("profile=" .. tostring(profile and profile.id or "none"))
print("active=" .. tostring(module:IsActive()))
print("status=" .. tostring(module:GetStatusText()))
print("capabilities=" .. tostring(module:GetCapabilitySummary()))
print("theme=" .. tostring(module:GetSettings().theme))

local mob = module.char.mobs["npc:1234"]
print("mob.kills=" .. tostring(mob and mob.kills or 0))
print("mob.totalXP=" .. tostring(mob and mob.totalXP or 0))
print("mob.samples=" .. tostring(mob and mob.xp and mob.xp.samples or 0))
print("totals.kills=" .. tostring(module.char.totals.kills))
print("totals.xp=" .. tostring(module.char.totals.xp))
print("levels.10=" .. tostring(module.char.levels["10"]))
print("areas.12=" .. tostring(module.char.areas["12"]))

GameTooltip.lines = {}
GameTooltip.xpTooltipSignature = nil
module:AddTooltipLines(GameTooltip, nil)
for index, line in ipairs(GameTooltip.lines) do
  print("tooltip." .. tostring(index) .. "=" .. tostring(line))
end
