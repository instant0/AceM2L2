--[[---------------------------------------------------------------------------------
  KillHistory/UI/Theme.lua
  Palette definitions, panel styling, ambient gradients, and status coloring.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local CopyTable = Util.CopyTable
local SafeCall = Util.SafeCall

local THEMES = {
  aether = {
    canvas = { 0.027, 0.067, 0.122, 1.00 },
    panel = { 0.047, 0.106, 0.165, 0.94 },
    elevated = { 0.063, 0.149, 0.227, 0.96 },
    border = { 0.165, 0.337, 0.478, 1.00 },
    text = { 0.918, 0.965, 1.000 },
    muted = { 0.616, 0.722, 0.800 },
    accent = { 0.310, 0.765, 0.969 },
    accentSoft = { 0.310, 0.765, 0.969, 0.20 },
    bar = { 0.310, 0.765, 0.969, 0.50 },
    success = { 0.360, 0.840, 0.660 },
    warning = { 0.950, 0.760, 0.310 },
    danger = { 0.940, 0.440, 0.440 },
  },
  dark = {
    canvas = { 0.035, 0.055, 0.065, 1.00 },
    panel = { 0.055, 0.090, 0.100, 0.94 },
    elevated = { 0.075, 0.120, 0.135, 0.96 },
    border = { 0.180, 0.245, 0.270, 1.00 },
    text = { 0.910, 0.880, 0.810 },
    muted = { 0.620, 0.690, 0.670 },
    accent = { 0.850, 0.660, 0.310 },
    accentSoft = { 0.850, 0.660, 0.310, 0.22 },
    bar = { 0.850, 0.660, 0.310, 0.45 },
    success = { 0.500, 0.820, 0.550 },
  },
  midnight = {
    canvas = { 0.018, 0.040, 0.075, 1.00 },
    panel = { 0.040, 0.060, 0.095, 0.94 },
    elevated = { 0.060, 0.090, 0.135, 0.96 },
    border = { 0.160, 0.220, 0.320, 1.00 },
    text = { 0.880, 0.900, 0.940 },
    muted = { 0.580, 0.660, 0.780 },
    accent = { 0.300, 0.650, 0.920 },
    accentSoft = { 0.300, 0.650, 0.920, 0.22 },
    bar = { 0.300, 0.650, 0.920, 0.45 },
    success = { 0.450, 0.820, 0.700 },
  },
  class = {
    canvas = { 0.030, 0.050, 0.055, 1.00 },
    panel = { 0.055, 0.080, 0.085, 0.94 },
    elevated = { 0.075, 0.105, 0.110, 0.96 },
    border = { 0.180, 0.230, 0.240, 1.00 },
    text = { 0.930, 0.910, 0.870 },
    muted = { 0.650, 0.700, 0.690 },
    accent = { 0.850, 0.660, 0.310 },
    accentSoft = { 0.850, 0.660, 0.310, 0.22 },
    bar = { 0.850, 0.660, 0.310, 0.45 },
    success = { 0.500, 0.820, 0.550 },
  },
  contrast = {
    canvas = { 0.000, 0.000, 0.000, 1.00 },
    panel = { 0.010, 0.010, 0.010, 0.98 },
    elevated = { 0.040, 0.040, 0.040, 0.99 },
    border = { 0.700, 0.700, 0.700, 1.00 },
    text = { 1.000, 1.000, 1.000 },
    muted = { 0.850, 0.850, 0.850 },
    accent = { 1.000, 0.850, 0.250 },
    accentSoft = { 1.000, 0.850, 0.250, 0.28 },
    bar = { 1.000, 0.850, 0.250, 0.60 },
    success = { 0.500, 1.000, 0.500 },
  },
}

UI.THEMES = THEMES



function XPTooltip:GetTheme()
  local settings = self.settings or self:GetSettings()
  local key = settings and settings.theme or "dark"
  local base = THEMES[key] or THEMES.aether
  local theme = CopyTable(base)

  if key == "class" then
    local _, classFile = SafeCall(UnitClass, "player")
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color and classFile and C_ClassColor and C_ClassColor.GetClassColor then
      color = SafeCall(C_ClassColor.GetClassColor, classFile)
    end
    if color then
      theme.accent = { color.r, color.g, color.b }
      theme.accentSoft = { color.r, color.g, color.b, 0.22 }
      theme.bar = { color.r, color.g, color.b, 0.45 }
    end
  end
  return theme
end

function XPTooltip:StylePanel(frame, kind)
  if not frame or not frame.SetBackdropColor then
    return
  end
  local theme = self:GetTheme()
  local color
  if kind == "canvas" then
    color = theme.canvas or theme.panel
  elseif kind == "elevated" then
    color = theme.elevated
  else
    color = theme.panel
  end
  frame:SetBackdropColor(color[1], color[2], color[3], color[4])
  frame:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
end

function XPTooltip:ApplyTheme()
  if not self.ui then
    return
  end
  local theme = self:GetTheme()
  for _, panel in ipairs(self.ui.panels or {}) do
    self:StylePanel(panel, panel.xpTooltipKind or "panel")
  end
  if self.ui.title then
    self.ui.title:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
  end
  if self.ui.subtitle then
    self.ui.subtitle:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.heroName then
    self.ui.heroName:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
  end
  if self.ui.heroSub then
    self.ui.heroSub:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.modelHolder and self.ui.modelHolder.glow then
    self.ui.modelHolder.glow:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.10)
  end
  if self.ui.details then
    self.ui.details:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.footer then
    self.ui.footer:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  if self.ui.overview and self.ui.overview.labels then
    for _, label in ipairs(self.ui.overview.labels) do
      label:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
    end
  end
  if self.ui.overview and self.ui.overview.values then
    for _, value in ipairs(self.ui.overview.values) do
      value:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
    end
  end
  if self.ui.overview and self.ui.overview.accents then
    for _, accent in ipairs(self.ui.overview.accents) do
      accent:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)
    end
  end
  local function refreshButton(button)
    if button and button.ApplyStyle then
      button:ApplyStyle()
    end
  end
  for _, button in pairs(self.ui.tabs or {}) do
    refreshButton(button)
  end
  for _, button in pairs(self.ui.filterButtons or {}) do
    refreshButton(button)
  end
  refreshButton(self.ui.sortButton)
  refreshButton(self.ui.settingsButton)
  refreshButton(self.ui.closeButton)
  refreshButton(self.ui.deleteButton)
  if self.ui.searchBorder then
    self.ui.searchBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 1)
  end
  if self.ui.searchBg then
    self.ui.searchBg:SetColorTexture(theme.elevated[1], theme.elevated[2], theme.elevated[3], 1)
  end
  if self.ui.searchBox and self.ui.searchBox.SetTextColor then
    pcall(self.ui.searchBox.SetTextColor, self.ui.searchBox, theme.text[1], theme.text[2], theme.text[3])
  end
  if self.ui.searchPlaceholder then
    self.ui.searchPlaceholder:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3])
  end
  self:UpdateAmbient()
  self:UpdateStatusChip()
  self:UpdateRows()
end

function XPTooltip:RegisterPanel(panel, kind)
  if not self.ui then
    return
  end
  panel.xpTooltipKind = kind or "panel"
  self.ui.panels[#self.ui.panels + 1] = panel
  self:StylePanel(panel, kind)
end

function XPTooltip:CreateAmbient(frame)
  local theme = self:GetTheme()

  local canvas = frame:CreateTexture(nil, "BACKGROUND", nil, 5)
  canvas:SetAllPoints()
  canvas:SetTexture("Interface\\Buttons\\WHITE8X8")
  UI.SetGradientTexture(canvas, "VERTICAL",
    { theme.canvas[1], theme.canvas[2], theme.canvas[3], 1 },
    { 0.008, 0.020, 0.040, 1 })
  frame.ambientCanvas = canvas

  local top = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(80)
  UI.SetGradientTexture(top, "VERTICAL", { 0, 0, 0, 0.55 }, { 0, 0, 0, 0 })
  frame.ambientTop = top

  local bottom = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(80)
  UI.SetGradientTexture(bottom, "VERTICAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.65 })
  frame.ambientBottom = bottom

  local left = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMLEFT")
  left:SetWidth(60)
  UI.SetGradientTexture(left, "HORIZONTAL", { 0, 0, 0, 0.45 }, { 0, 0, 0, 0 })
  frame.ambientLeft = left

  local right = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
  right:SetPoint("TOPRIGHT")
  right:SetPoint("BOTTOMRIGHT")
  right:SetWidth(60)
  UI.SetGradientTexture(right, "HORIZONTAL", { 0, 0, 0, 0 }, { 0, 0, 0, 0.45 })
  frame.ambientRight = right
end

function XPTooltip:UpdateAmbient()
  if not self.ui then
    return
  end
  local theme = self:GetTheme()
  if self.ui.ambientCanvas then
    UI.SetGradientTexture(self.ui.ambientCanvas, "VERTICAL",
      { theme.canvas[1], theme.canvas[2], theme.canvas[3], 1 },
      { 0.008, 0.020, 0.040, 1 })
  end
end

function XPTooltip:UpdateStatusChip()
  if not self.ui or not self.ui.statusText then
    return
  end
  local theme = self:GetTheme()
  local text = self:GetStatusText()
  local color = theme.muted
  if self:IsActive() then
    color = theme.success or theme.accent
  elseif self.autoDisabled then
    color = theme.danger or theme.warning or theme.accent
  end
  self.ui.statusText:SetText(text:upper())
  self.ui.statusText:SetTextColor(color[1], color[2], color[3])
end
