--[[---------------------------------------------------------------------------------
  KillHistory/UI/Widgets.lua
  Reusable frame, button, and gradient helpers.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI

local function CreateBackdropFrame(parent, name)
  local frameName = name
  if frameName and _G[frameName] then
    frameName = nil
  end
  local ok, frame = pcall(CreateFrame, "Frame", frameName, parent, "BackdropTemplate")
  if not ok then
    frame = CreateFrame("Frame", nil, parent)
  end
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  end
  return frame
end

local function CreateTextButton(parent, text, width, height)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width or 100, height or 24)
  button:EnableMouse(true)

  local border = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  border:SetAllPoints()
  button.border = border

  local bg = button:CreateTexture(nil, "BACKGROUND", nil, 2)
  bg:SetPoint("TOPLEFT", 1, -1)
  bg:SetPoint("BOTTOMRIGHT", -1, 1)
  button.bg = bg

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("CENTER", 0, 0)
  label:SetJustifyH("CENTER")
  button.label = label

  button.hover = false
  button.selected = false

  function button:ApplyStyle()
    local theme = XPTooltip:GetTheme()
    local fill = theme.elevated
    local edge = theme.border
    local textColor = theme.muted
    if self.selected then
      fill = { theme.accent[1], theme.accent[2], theme.accent[3], 0.34 }
      edge = theme.accent
      textColor = theme.text
    elseif self.hover then
      fill = { theme.accent[1], theme.accent[2], theme.accent[3], 0.18 }
      edge = theme.border
      textColor = theme.text
    end
    self.bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
    self.border:SetColorTexture(edge[1], edge[2], edge[3], edge[4] or 1)
    self.label:SetTextColor(textColor[1], textColor[2], textColor[3])
  end

  function button:SetText(value)
    self.label:SetText(value or "")
  end

  function button:SetButtonState(state, active)
    if active ~= nil then
      self.selected = active and true or false
    else
      self.selected = state == "PUSHED"
    end
    self:ApplyStyle()
  end

  function button:SetSelected(value)
    self.selected = value and true or false
    self:ApplyStyle()
  end

  button:SetScript("OnEnter", function(self)
    self.hover = true
    self:ApplyStyle()
  end)
  button:SetScript("OnLeave", function(self)
    self.hover = false
    self:ApplyStyle()
  end)

  button:SetText(text or "")
  button:ApplyStyle()
  return button
end

local function SetGradientTexture(texture, orientation, topColor, bottomColor)
  if texture.SetGradient and CreateColor then
    local ok = pcall(texture.SetGradient, texture, orientation,
      CreateColor(topColor[1], topColor[2], topColor[3], topColor[4] or 1),
      CreateColor(bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1))
    if ok then
      return
    end
  end
  texture:SetColorTexture(topColor[1], topColor[2], topColor[3], topColor[4] or 1)
end

UI.CreateBackdropFrame = CreateBackdropFrame
UI.CreateTextButton = CreateTextButton
UI.SetGradientTexture = SetGradientTexture
