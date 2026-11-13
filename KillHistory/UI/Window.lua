--[[---------------------------------------------------------------------------------
  KillHistory/UI/Window.lua
  Main window shell, tabs, search, panels, footer, and show/hide lifecycle.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local XPTooltip = AceM2L2.KillHistory
local UI = XPTooltip.UI
local Util = XPTooltip.Util

local floor, min, max = math.floor, math.min, math.max
local DEFAULT_UI = Util.DEFAULT_UI
local ROW_HEIGHT = Util.ROW_HEIGHT
local VISIBLE_ROWS = Util.VISIBLE_ROWS
local FormatNumber = Util.FormatNumber
local CreateBackdropFrame = UI.CreateBackdropFrame
local CreateTextButton = UI.CreateTextButton

function XPTooltip:CreateUI()
  if self.ui then
    return self.ui
  end

  local settings = self.settings or self:GetSettings()
  local uiSettings = settings and settings.ui or DEFAULT_UI
  local frame = CreateBackdropFrame(UIParent, "AceM2L2XPTooltipFrame")
  frame:SetSize(uiSettings.width or 1000, uiSettings.height or 680)
  frame.panels = {}
  if frame.SetScale then
    frame:SetScale((settings and settings.scale) or 1.0)
  end
  frame:SetPoint(
    uiSettings.point or "CENTER", UIParent, uiSettings.relativePoint or "CENTER",
    uiSettings.x or 0, uiSettings.y or 0
  )
  self:StylePanel(frame, "canvas")
  frame.panels[#frame.panels + 1] = frame
  frame.xpTooltipKind = "canvas"
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    self:SaveUIPosition()
  end)
  frame:SetScript("OnHide", function()
    self.modelDragging = false
    if self.ui and self.ui.model then
      self.ui.model.dragging = false
    end
  end)
  frame:SetScript("OnShow", function()
    self:SafeRefreshUI()
  end)

  self:CreateAmbient(frame)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText("ACE MOBS 2 LEVEL 2")
  frame.title = title

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  subtitle:SetText("KILL HISTORY")
  frame.subtitle = subtitle

  local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusText:SetPoint("TOPRIGHT", -200, -16)
  statusText:SetJustifyH("RIGHT")
  statusText:SetText("ACTIVE")
  frame.statusText = statusText

  local settingsButton = CreateTextButton(frame, "Settings", 80, 24)
  settingsButton:SetPoint("TOPRIGHT", -108, -10)
  settingsButton:SetScript("OnClick", function()
    AceM2L2:HandleSlashCommand("config")
  end)
  frame.settingsButton = settingsButton

  local closeButton = CreateTextButton(frame, "X", 24, 24)
  closeButton:SetPoint("TOPRIGHT", -6, -10)
  closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)
  frame.closeButton = closeButton

  if type(UISpecialFrames) == "table" and frame:GetName() then
    local found = false
    for _, name in ipairs(UISpecialFrames) do
      if name == frame:GetName() then
        found = true
        break
      end
    end
    if not found then
      UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
    end
  end

  local tabBar = CreateFrame("Frame", nil, frame)
  tabBar:SetPoint("TOPLEFT", 16, -54)
  tabBar:SetPoint("TOPRIGHT", -16, -54)
  tabBar:SetHeight(26)

  self.tabs = {}
  local tabDefinitions = {
    { key = "overview", label = "Overview" },
    { key = "mobs", label = "Mobs" },
    { key = "areas", label = "Areas" },
    { key = "levels", label = "Levels" },
  }
  local x = 0
  for _, definition in ipairs(tabDefinitions) do
    local button = CreateTextButton(tabBar, definition.label, 100, 26)
    button:SetPoint("TOPLEFT", x, 0)
    button:SetScript("OnClick", function()
      pcall(self.SetTab, self, definition.key)
    end)
    self.tabs[definition.key] = button
    x = x + 108
  end

  local sortButton = CreateTextButton(tabBar, "Sort: Kills", 120, 26)
  sortButton:SetPoint("TOPRIGHT", 0, 0)
  sortButton:SetScript("OnClick", function()
    pcall(self.CycleSort, self)
  end)
  frame.sortButton = sortButton

  local searchLabel = tabBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("RIGHT", sortButton, "LEFT", -158, 0)
  searchLabel:SetText("Search:")
  frame.searchLabel = searchLabel

  local theme = self:GetTheme()
  local searchBox = CreateFrame("EditBox", nil, tabBar)
  searchBox:SetSize(150, 26)
  searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 4, 0)
  searchBox:SetTextInsets(8, 8, 0, 0)
  searchBox:SetFontObject(GameFontHighlightSmall)
  if searchBox.SetTextColor then
    pcall(searchBox.SetTextColor, searchBox, theme.text[1], theme.text[2], theme.text[3])
  end
  searchBox:SetAutoFocus(false)
  searchBox:SetMaxLetters(40)
  searchBox:SetText("")

  local searchBorder = searchBox:CreateTexture(nil, "BACKGROUND", nil, 1)
  searchBorder:SetAllPoints()
  searchBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 1)
  local searchBg = searchBox:CreateTexture(nil, "BACKGROUND", nil, 2)
  searchBg:SetPoint("TOPLEFT", 1, -1)
  searchBg:SetPoint("BOTTOMRIGHT", -1, 1)
  searchBg:SetColorTexture(theme.elevated[1], theme.elevated[2], theme.elevated[3], 1)

  local searchPlaceholder = tabBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
  searchPlaceholder:SetText("Search mobs")
  frame.searchPlaceholder = searchPlaceholder
  frame.searchBg = searchBg
  frame.searchBorder = searchBorder

  searchBox:SetScript("OnTextChanged", function(box)
    self.searchText = box:GetText() or ""
    self.selectedIndex = 1
    self:ResetScroll()
    if self.ui and self.ui.searchPlaceholder then
      if self.searchText == "" then
        self.ui.searchPlaceholder:Show()
      else
        self.ui.searchPlaceholder:Hide()
      end
    end
    if self.tab ~= "mobs" then
      return
    end
    pcall(self.BuildList, self)
    pcall(self.UpdateRows, self)
    pcall(self.UpdateDetail, self)
  end)
  searchBox:SetScript("OnEscapePressed", function(box)
    box:ClearFocus()
  end)
  searchBox:SetScript("OnEnterPressed", function(box)
    box:ClearFocus()
  end)
  frame.searchBox = searchBox

  local detailPanel = CreateBackdropFrame(frame)
  detailPanel:SetPoint("TOPLEFT", 16, -90)
  detailPanel:SetPoint("BOTTOMLEFT", 16, 40)
  detailPanel:SetWidth(300)
  self:StylePanel(detailPanel, "panel")
  detailPanel.xpTooltipKind = "panel"
  frame.panels[#frame.panels + 1] = detailPanel
  frame.detailPanel = detailPanel

  local listPanel = CreateBackdropFrame(frame)
  listPanel:SetPoint("TOPLEFT", detailPanel, "TOPRIGHT", 12, 0)
  listPanel:SetPoint("BOTTOMRIGHT", -16, 40)
  self:StylePanel(listPanel, "panel")
  listPanel.xpTooltipKind = "panel"
  frame.panels[#frame.panels + 1] = listPanel
  frame.listPanel = listPanel

  local filterBar = CreateFrame("Frame", nil, listPanel)
  filterBar:SetPoint("TOPLEFT", 6, -6)
  filterBar:SetPoint("TOPRIGHT", -6, -6)
  filterBar:SetHeight(24)
  frame.filterBar = filterBar
  frame.filterButtons = {}
  self.filter = "all"
  local filterDefinitions = {
    { key = "all", label = "All" },
    { key = "level", label = "Level" },
    { key = "session", label = "Session" },
    { key = "elite", label = "Elite" },
  }
  local filterX = 0
  for _, definition in ipairs(filterDefinitions) do
    local button = CreateTextButton(filterBar, definition.label, 70, 22)
    button:SetPoint("TOPLEFT", filterX, 0)
    button:SetScript("OnClick", function()
      pcall(self.SetFilter, self, definition.key)
    end)
    frame.filterButtons[definition.key] = button
    filterX = filterX + 78
  end

  local listWidth = max(260, (frame:GetWidth() or 1000) - 16 - 300 - 12 - 16)
  local rowWidth = max(240, listWidth - 40)
  frame.rowWidth = rowWidth
  local scrollOK, scrollFrame = pcall(CreateFrame, "ScrollFrame", "AceM2L2XPTooltipScroll", listPanel, "UIPanelScrollFrameTemplate")
  if not scrollOK then
    scrollFrame = CreateFrame("ScrollFrame", nil, listPanel)
  end
  scrollFrame:SetPoint("TOPLEFT", 6, -34)
  scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(rowWidth, 1)
  scrollFrame:SetScrollChild(scrollChild)
  scrollFrame:SetScript("OnVerticalScroll", function()
    self:UpdateRows()
    if scrollFrame.UpdateScrollChildRect then
      pcall(scrollFrame.UpdateScrollChildRect, scrollFrame)
    end
  end)
  frame.scrollFrame = scrollFrame
  frame.scrollChild = scrollChild

  self.rows = {}
  for index = 1, VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetSize(rowWidth, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0.04)
    row.background = background

    local crest = row:CreateTexture(nil, "ARTWORK")
    crest:SetSize(18, 18)
    crest:SetPoint("LEFT", 8, 0)
    crest:SetColorTexture(0.85, 0.66, 0.31, 0.55)
    row.crest = crest

    local crestText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    crestText:SetPoint("CENTER", crest, "CENTER", 0, 0)
    crestText:SetJustifyH("CENTER")
    crestText:SetText("?")
    row.crestText = crestText

    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("BOTTOMLEFT", 4, 2)
    bar:SetHeight(2)
    bar:SetColorTexture(0.2, 0.6, 1, 0.45)
    bar:Hide()
    row.bar = bar

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 32, 0)
    text:SetWidth(max(110, rowWidth - 250))
    text:SetJustifyH("LEFT")
    row.text = text

    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", -8, 0)
    value:SetWidth(200)
    value:SetJustifyH("RIGHT")
    row.value = value

    row:SetScript("OnClick", function(clicked)
      pcall(self.SelectIndex, self, clicked.index)
    end)
    row:SetScript("OnEnter", function(entered)
      local theme = self:GetTheme()
      entered.background:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.16)
    end)
    row:SetScript("OnLeave", function(left)
      local theme = self:GetTheme()
      if left.index == self.selectedIndex then
        left.background:SetColorTexture(theme.accentSoft[1], theme.accentSoft[2], theme.accentSoft[3], theme.accentSoft[4])
      else
        left.background:SetColorTexture(1, 1, 1, 0.04)
      end
    end)

    self.rows[index] = row
  end

  local modelHolder = CreateBackdropFrame(detailPanel)
  modelHolder:SetPoint("TOPLEFT", 8, -8)
  modelHolder:SetPoint("TOPRIGHT", -8, -8)
  modelHolder:SetHeight(230)
  self:StylePanel(modelHolder, "elevated")
  modelHolder.xpTooltipKind = "elevated"
  frame.panels[#frame.panels + 1] = modelHolder
  frame.modelHolder = modelHolder

  local modelGlow = modelHolder:CreateTexture(nil, "BACKGROUND", nil, 1)
  modelGlow:SetPoint("TOPLEFT", 8, -8)
  modelGlow:SetPoint("BOTTOMRIGHT", -8, 8)
  local theme = self:GetTheme()
  modelGlow:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.10)
  modelHolder.glow = modelGlow

  local modelOK, model = pcall(CreateFrame, "PlayerModel", nil, modelHolder)
  if not modelOK then
    model = CreateFrame("Frame", nil, modelHolder)
  end
  model:SetPoint("TOPLEFT", 6, -6)
  model:SetPoint("BOTTOMRIGHT", -6, 6)
  model:EnableMouse(true)
  model:SetScript("OnMouseDown", function(clicked, button)
    if button == "LeftButton" then
      clicked.dragging = true
      clicked.dragStartX = select(1, GetCursorPosition())
      clicked.dragStartYaw = self.modelYaw or 0
    end
  end)
  model:SetScript("OnMouseUp", function(clicked)
    clicked.dragging = false
  end)
  model:SetScript("OnUpdate", function(clicked)
    if clicked.dragging then
      local x = select(1, GetCursorPosition())
      self.modelYaw = (clicked.dragStartYaw or 0) + (x - (clicked.dragStartX or x)) * 0.01
      pcall(clicked.SetRotation, clicked, self.modelYaw)
    end
  end)
  frame.model = model

  local fallbackIcon = modelHolder:CreateTexture(nil, "ARTWORK")
  fallbackIcon:SetSize(64, 64)
  fallbackIcon:SetPoint("CENTER", 0, 24)
  fallbackIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  fallbackIcon:Hide()
  frame.modelFallbackIcon = fallbackIcon

  local fallback = modelHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fallback:SetPoint("CENTER", 0, -24)
  fallback:SetText("")
  frame.modelFallback = fallback

  local heroName = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  heroName:SetPoint("TOPLEFT", 12, -240)
  heroName:SetPoint("TOPRIGHT", -12, -240)
  heroName:SetJustifyH("LEFT")
  heroName:SetText("")
  frame.heroName = heroName

  local heroSub = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  heroSub:SetPoint("TOPLEFT", heroName, "BOTTOMLEFT", 0, -2)
  heroSub:SetPoint("TOPRIGHT", -12, -260)
  heroSub:SetJustifyH("LEFT")
  heroSub:SetText("")
  frame.heroSub = heroSub

  local details = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  details:SetPoint("TOPLEFT", 12, -282)
  details:SetPoint("BOTTOMRIGHT", -12, 38)
  details:SetJustifyH("LEFT")
  details:SetJustifyV("TOP")
  details:SetWordWrap(true)
  details:SetText("")
  frame.details = details

  local deleteButton = CreateTextButton(detailPanel, "Remove", 96, 22)
  deleteButton:SetPoint("BOTTOMRIGHT", -8, 8)
  deleteButton:Hide()
  deleteButton:SetScript("OnClick", function()
    pcall(self.RequestDeleteSelected, self)
  end)
  frame.deleteButton = deleteButton

  self:CreateOverviewPanel(frame)

  local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  footer:SetPoint("BOTTOMLEFT", 16, 16)
  footer:SetPoint("BOTTOMRIGHT", -16, 16)
  footer:SetJustifyH("LEFT")
  footer:SetText("")
  frame.footer = footer

  self.ui = frame
  self:ApplyTheme()
  self:SetTab((settings and settings.startTab) or "overview")
  self:UpdateFooter()
  return frame
end

function XPTooltip:SaveUIPosition()
  if not self.ui then
    return
  end
  local settings = self:GetSettings()
  if not settings or type(settings.ui) ~= "table" then
    return
  end
  local point, _, relativePoint, x, y = self.ui:GetPoint(1)
  if not point then
    return
  end
  settings.ui.point = point or "CENTER"
  settings.ui.relativePoint = relativePoint or "CENTER"
  settings.ui.x = floor((x or 0) + 0.5)
  settings.ui.y = floor((y or 0) + 0.5)
end

function XPTooltip:SetTab(tab)
  if tab ~= "overview" and tab ~= "mobs" and tab ~= "areas" and tab ~= "levels" then
    tab = "overview"
  end
  self.tab = tab
  self.selectedIndex = 1
  self.filter = "all"
  if self.tab ~= "mobs" then
    self.searchText = ""
    if self.ui and self.ui.searchBox then
      self.ui.searchBox:SetText("")
    end
  end
  if self.ui and self.ui.scrollFrame then
    pcall(self.ui.scrollFrame.SetVerticalScroll, self.ui.scrollFrame, 0)
  end

  if self.ui and self.ui.overview then
    if self.tab == "overview" then
      self.ui.overview.panel:Show()
    else
      self.ui.overview.panel:Hide()
    end
  end
  if self.ui and self.ui.listPanel then
    if self.tab == "overview" then
      self.ui.listPanel:Hide()
    else
      self.ui.listPanel:Show()
    end
  end
  if self.ui and self.ui.detailPanel then
    if self.tab == "overview" then
      self.ui.detailPanel:Hide()
    else
      self.ui.detailPanel:Show()
    end
  end
  if self.ui and self.ui.filterBar then
    if self.tab == "mobs" then
      self.ui.filterBar:Show()
    else
      self.ui.filterBar:Hide()
    end
  end

  if self.tab == "overview" then
    self:RefreshOverview()
  else
    self:BuildList()
    self:UpdateRows()
    self:UpdateDetail()
  end
  self:UpdateFilterButtons()
  self:UpdateTabs()
  self:UpdateStatusChip()
  self:UpdateFooter()
end

function XPTooltip:UpdateTabs()
  if not self.tabs then
    return
  end
  for key, button in pairs(self.tabs) do
    if button.SetButtonState then
      button:SetButtonState("PUSHED", key == self.tab)
    end
  end
  if self.ui then
    local isMobs = self.tab == "mobs"
    if self.ui.sortButton and self.ui.sortButton.SetShown then
      self.ui.sortButton:SetShown(isMobs)
    end
    if self.ui.searchBox and self.ui.searchBox.SetShown then
      self.ui.searchBox:SetShown(isMobs)
    end
    if self.ui.searchLabel and self.ui.searchLabel.SetShown then
      self.ui.searchLabel:SetShown(isMobs)
    end
    if self.ui.searchPlaceholder then
      self.ui.searchPlaceholder:SetShown(isMobs and (self.searchText or "") == "")
    end
    if self.ui.filterBar and self.ui.filterBar.SetShown then
      self.ui.filterBar:SetShown(isMobs)
    end
  end
end

function XPTooltip:UpdateFooter()
  if not self.ui or not self.ui.footer then
    return
  end
  local db = self.char
  if not db then
    self.ui.footer:SetText("")
    return
  end
  local total = tonumber(db.totals.kills) or 0
  local session = tonumber(db.session.kills) or 0
  local unique = tonumber(db.totals.uniqueMobs) or 0

  local topMap, topMapKills = nil, 0
  for mapKey, kills in pairs(db.areas or {}) do
    if (tonumber(kills) or 0) > topMapKills then
      topMapKills = tonumber(kills) or 0
      topMap = mapKey
    end
  end

  local minLevel, maxLevel
  for levelKey, kills in pairs(db.levels or {}) do
    local level = tonumber(levelKey)
    if level and (tonumber(kills) or 0) > 0 then
      if not minLevel or level < minLevel then
        minLevel = level
      end
      if not maxLevel or level > maxLevel then
        maxLevel = level
      end
    end
  end

  local text = "Total kills: " .. FormatNumber(total)
    .. "   Session: " .. FormatNumber(session)
    .. "   Mobs tracked: " .. FormatNumber(unique)
  if topMap then
    text = text .. "   Top area: " .. self:GetMapName(topMap) .. " (" .. FormatNumber(topMapKills) .. ")"
  end
  if minLevel then
    text = text .. "   Level range: " .. tostring(minLevel) .. "-" .. tostring(maxLevel)
  end
  self.ui.footer:SetText(text)
end

function XPTooltip:RefreshUI()
  if not self.ui or not self.ui:IsShown() then
    return
  end
  if not self:IsActive() then
    self.ui:Hide()
    return
  end
  if self.tab == "overview" then
    self:RefreshOverview()
  else
    self:BuildList()
    self:UpdateRows()
    self:UpdateDetail()
  end
  self:UpdateFilterButtons()
  self:UpdateTabs()
  self:UpdateStatusChip()
  self:UpdateFooter()
end

function XPTooltip:SafeRefreshUI()
  local ok, err = pcall(self.RefreshUI, self)
  if not ok then
    self:ReportError("RefreshUI", err)
  end
end

function XPTooltip:RequestUIUpdate()
  if self.uiRefreshPending then
    return
  end
  self.uiRefreshPending = true
  if C_Timer and C_Timer.After then
    pcall(C_Timer.After, 0.25, function()
      self.uiRefreshPending = false
      if self:IsActive() then
        self:SafeRefreshUI()
      end
    end)
  else
    self.uiRefreshPending = false
    self:SafeRefreshUI()
  end
end

function XPTooltip:OpenUI()
  if not self:IsActive() then
    self:PrintStatus()
    return
  end
  local ok, frame = pcall(self.CreateUI, self)
  if not ok or not frame then
    self:ReportError("CreateUI", frame or "no frame")
    return
  end
  local showOK, err = pcall(frame.Show, frame)
  if not showOK then
    self:ReportError("ShowUI", err)
    return
  end
  local currentSettings = self:GetSettings()
  if currentSettings and currentSettings.scale and frame.SetScale then
    pcall(frame.SetScale, frame, currentSettings.scale)
  end
  self:ApplyTheme()
  pcall(frame.Raise, frame)
  local settings = self:GetSettings()
  if settings and settings.sound and type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then
    pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPEN)
  end
  if type(UIFrameFadeIn) == "function" then
    pcall(UIFrameFadeIn, frame, 0.15, 0, 1)
  end
  if settings and settings.startTab then
    self:SetTab(settings.startTab)
  else
    self:SafeRefreshUI()
  end
end

function XPTooltip:CloseUI()
  if self.ui and self.ui.Hide then
    local settings = self:GetSettings()
    if settings and settings.sound and type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE then
      pcall(PlaySound, SOUNDKIT.IG_MAINMENU_CLOSE)
    end
    pcall(self.ui.Hide, self.ui)
  end
end
