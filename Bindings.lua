-- AceM2L2 bindings and addon-compartment entry points.

BINDING_HEADER_ACEM2L2 = "Ace Mobs 2 Level 2"
BINDING_NAME_ACEM2L2_XPTOOLTIP = "Toggle Kill Story"

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

function AceM2L2_ToggleXPTooltip()
  ToggleXPTooltip()
end

function AceM2L2_OnCompartmentClick()
  ToggleXPTooltip()
end
