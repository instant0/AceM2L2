--[[---------------------------------------------------------------------------------
  KillHistory/UI/Minimap.lua
  LibDataBroker launcher and LibDBIcon lifecycle.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local FormatNumber = Util.FormatNumber
local FormatAgo = Util.FormatAgo
local DEFAULT_MINIMAP = Util.DEFAULT_MINIMAP
local CopyTable = Util.CopyTable

function XPTooltip:InitializeMinimap()
  if not self:IsActive() then
    self:HideMinimapIcon()
    return
  end
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  local icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not ldb or type(ldb.NewDataObject) ~= "function"
    or not icon or type(icon.Register) ~= "function" then
    return
  end
  local settings = self:GetSettings()
  if type(settings.minimap) ~= "table" then
    settings.minimap = CopyTable(DEFAULT_MINIMAP)
  end
  if self.minimapObject and self.minimapIcon and self.minimapRegistered then
    if self.minimapSettingsTable ~= settings.minimap then
      self.minimapSettingsTable = settings.minimap
      if type(self.minimapIcon.Refresh) == "function" then
        pcall(self.minimapIcon.Refresh, self.minimapIcon, "AceM2L2", settings.minimap)
      end
    end
    self:UpdateMinimapVisibility()
    return
  end
  if not self.minimapSettingsTable then
    self.minimapSettingsTable = settings.minimap
  end
  if not self.minimapObject then
    self.minimapObject = ldb:NewDataObject("AceM2L2", {
      type = "launcher",
      icon = "Interface\\AddOns\\AceM2L2\\Textures\\AceM2L2-icon.tga",
      iconR = 1.00,
      iconG = 1.00,
      iconB = 1.00,
      OnClick = function(_, button)
        self:OnMinimapClick(button)
      end,
      OnTooltipShow = function(tooltip)
        self:OnMinimapTooltip(tooltip)
      end,
    })
  end
  if not self.minimapRegistered then
    local ok = pcall(icon.Register, icon, "AceM2L2", self.minimapObject, settings.minimap)
    if not ok then
      return
    end
    self.minimapRegistered = true
  end
  self.minimapIcon = icon
  self:UpdateMinimapVisibility()
end

function XPTooltip:HideMinimapIcon()
  if self.minimapIcon and self.minimapRegistered then
    pcall(self.minimapIcon.Hide, self.minimapIcon, "AceM2L2")
  end
end

function XPTooltip:UpdateMinimapVisibility()
  if not self.minimapIcon or not self.minimapRegistered then
    return
  end
  local settings = self:GetSettings()
  local hidden = settings and settings.minimap and settings.minimap.hide
  if hidden or not self:IsActive() then
    pcall(self.minimapIcon.Hide, self.minimapIcon, "AceM2L2")
  else
    pcall(self.minimapIcon.Show, self.minimapIcon, "AceM2L2")
  end
end

function XPTooltip:OnMinimapClick(button)
  if button == "RightButton" then
    AceM2L2:HandleSlashCommand("config")
  else
    self:ToggleUI()
  end
end

function XPTooltip:OnMinimapTooltip(tooltip)
  if not tooltip then
    return
  end
  local theme = self:GetTheme()
  tooltip:AddLine("Ace Mobs 2 Level 2 - Kill Story", theme.text[1], theme.text[2], theme.text[3])
  tooltip:AddLine(self:GetStatusText(), theme.muted[1], theme.muted[2], theme.muted[3])
  local db = self.char
  if db then
    tooltip:AddLine(
      "Kills: " .. FormatNumber(db.totals.kills or 0)
        .. "   Session: " .. FormatNumber(db.session.kills or 0),
      theme.muted[1], theme.muted[2], theme.muted[3]
    )
    local topMap, topKills = nil, 0
    for mapKey, kills in pairs(db.areas or {}) do
      if (tonumber(kills) or 0) > topKills then
        topKills = tonumber(kills) or 0
        topMap = mapKey
      end
    end
    if topMap then
      tooltip:AddLine(
        "Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topKills) .. ")",
        theme.muted[1], theme.muted[2], theme.muted[3]
      )
    end
  end
  tooltip:AddLine("Left-click: open   Right-click: settings", theme.muted[1], theme.muted[2], theme.muted[3])
end

function XPTooltip:PrintMinimapStatus()
  local settings = self:GetSettings()
  local minimap = settings and settings.minimap or {}
  local state = "shown"
  if minimap.hide then
    state = "hidden"
  elseif not self:IsActive() then
    state = "inactive (module disabled)"
  end
  AceM2L2:SafePrint("Kill Story minimap icon: " .. state)
end
