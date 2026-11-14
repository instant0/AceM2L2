-- AceM2L2 addon-compartment entry point.
-- The Kill Story window is opened from the minimap icon, the addon
-- compartment, or the /acem2l2 commands. There is no key binding.

local function ToggleXPTooltip()
  local addon = _G.AceM2L2
  if not addon or type(addon.GetXPTooltipModule) ~= "function" then
    return
  end
  local module = addon:GetXPTooltipModule()
  if module and type(module.ToggleUI) == "function" then
    module:ToggleUI()
  end
end

function AceM2L2_OnCompartmentClick()
  ToggleXPTooltip()
end
