local unpack = unpack or table.unpack

local COLORS = {
  healthy = { 0.85, 0.86, 0.80 },
  warning = { 1.00, 0.72, 0.18 },
  critical = { 1.00, 0.22, 0.18 },
  unavailable = { 0.43, 0.43, 0.43 },
}

local function set_font_color(font_string, color)
  font_string:SetTextColor(color[1], color[2], color[3])
end

function BareNecessities:CreateUi()
  local frame = CreateFrame("Frame", "BareNecessitiesFrame", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetSize(264, 184)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 13,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0.03, 0.035, 0.04, 0.94)
  frame:SetBackdropBorderColor(0.54, 0.46, 0.32, 0.95)

  frame:SetScript("OnDragStart", function(panel)
    if not self.settings.locked then
      panel:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(panel)
    panel:StopMovingOrSizing()
    self:SavePosition()
  end)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -11)
  title:SetText("SURVIVAL")
  title:SetTextColor(0.91, 0.73, 0.38)

  local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  summary:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  summary:SetJustifyH("LEFT")
  summary:SetText("Waiting for status...")
  self.summary = summary

  for index, resource in ipairs(self.resource_order) do
    self.ui_rows[resource.key] = self:CreateResourceRow(frame, resource, index)
  end

  self.frame = frame
  self:RestorePosition()
  self:RefreshVisibility()
  self:RefreshDisplays()
end

function BareNecessities:CreateResourceRow(parent, resource, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(240, 32)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -43 - ((index - 1) * 33))
  row:EnableMouse(true)

  local wash = row:CreateTexture(nil, "BACKGROUND")
  wash:SetAllPoints()
  wash:SetTexture(1, 1, 1, 0.035)

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(25, 25)
  icon:SetPoint("LEFT", row, "LEFT", 2, 0)
  icon:SetTexture(resource.icon)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local icon_border = row:CreateTexture(nil, "OVERLAY")
  icon_border:SetSize(36, 36)
  icon_border:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon_border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 35, -1)
  label:SetText(resource.label)
  label:SetTextColor(0.94, 0.92, 0.85)

  local state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  state:SetPoint("LEFT", label, "RIGHT", 7, 0)
  state:SetText("Unavailable")

  local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  value:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -1)
  value:SetJustifyH("RIGHT")
  value:SetText("--")

  local bar = CreateFrame("StatusBar", nil, row)
  bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  bar:SetMinMaxValues(0, resource.max_value)
  bar:SetValue(0)
  bar:SetSize(201, 8)
  bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 35, 4)

  local bar_bg = bar:CreateTexture(nil, "BACKGROUND")
  bar_bg:SetAllPoints()
  bar_bg:SetTexture(0.025, 0.025, 0.025, 0.92)

  self:CreateSegmentDividers(bar)
  row:SetScript("OnEnter", function()
    self:ShowResourceTooltip(row, resource)
  end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return {
    frame = row,
    icon = icon,
    label = label,
    state = state,
    value = value,
    bar = bar,
    wash = wash,
  }
end

function BareNecessities:CreateSegmentDividers(bar)
  for index = 1, 4 do
    local divider = bar:CreateTexture(nil, "OVERLAY")
    divider:SetTexture(0.02, 0.02, 0.02, 0.9)
    divider:SetSize(1, 8)
    divider:SetPoint("LEFT", bar, "LEFT", (bar:GetWidth() / 5) * index, 0)
  end
end

function BareNecessities:RefreshDisplays()
  if not self.frame then
    return
  end

  local lowest_resource
  local lowest_ratio
  for _, resource in ipairs(self.resource_order) do
    local value = self.values[resource.key]
    local ratio = self:GetRatio(resource, value)
    self:UpdateRow(resource, self.ui_rows[resource.key], value, ratio)
    if ratio and (not lowest_ratio or ratio < lowest_ratio) then
      lowest_resource = resource
      lowest_ratio = ratio
    end
  end

  self:UpdateSummary(lowest_resource, lowest_ratio)
end

function BareNecessities:UpdateRow(resource, row, value, ratio)
  local state_text, severity = self:GetState(ratio)
  local state_color = COLORS[severity]
  row.bar:SetMinMaxValues(0, resource.max_value)
  row.bar:SetValue(value or 0)
  row.value:SetText(self:FormatValue(resource, value))
  row.state:SetText(state_text)
  set_font_color(row.state, state_color)

  if severity == "warning" or severity == "critical" then
    row.bar:SetStatusBarColor(unpack(COLORS[severity]))
    row.wash:SetTexture(unpack(COLORS[severity]))
    row.wash:SetAlpha(severity == "critical" and 0.12 or 0.07)
  else
    row.bar:SetStatusBarColor(unpack(resource.bar_color))
    row.wash:SetTexture(1, 1, 1, severity == "unavailable" and 0.018 or 0.035)
  end

  row.icon:SetDesaturated(severity == "unavailable")
  row.icon:SetAlpha(severity == "unavailable" and 0.38 or 1)
  row.value:SetTextColor(unpack(state_color))
end

function BareNecessities:UpdateSummary(resource, ratio)
  if not resource or ratio == nil then
    self.summary:SetText("Waiting for status...")
    set_font_color(self.summary, COLORS.unavailable)
  elseif ratio <= 0 then
    self.summary:SetText(resource.urgent_text)
    set_font_color(self.summary, COLORS.critical)
  elseif ratio < 0.4 then
    self.summary:SetText(resource.label .. " is critical")
    set_font_color(self.summary, COLORS.critical)
  elseif ratio < 0.6 then
    self.summary:SetText(resource.label .. " is running low")
    set_font_color(self.summary, COLORS.warning)
  elseif ratio < 0.8 then
    self.summary:SetText("Keep an eye on " .. string.lower(resource.label))
    set_font_color(self.summary, COLORS.healthy)
  else
    self.summary:SetText("All needs are steady")
    set_font_color(self.summary, COLORS.healthy)
  end
end

function BareNecessities:ShowResourceTooltip(owner, resource)
  local value = self.values[resource.key]
  local ratio = self:GetRatio(resource, value)
  local state = self:GetState(ratio)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(resource.label, 1, 0.82, 0)
  GameTooltip:AddLine(state .. "  " .. self:FormatValue(resource, value), 1, 1, 1)
  GameTooltip:AddLine(resource.hint, 0.75, 0.75, 0.75, true)
  GameTooltip:Show()
end

function BareNecessities:SavePosition()
  local point, _, relative_point, x, y = self.frame:GetPoint(1)
  self.settings.point = point
  self.settings.relative_point = relative_point
  self.settings.x = math.floor((x or 0) + 0.5)
  self.settings.y = math.floor((y or 0) + 0.5)
end

function BareNecessities:RestorePosition()
  self.frame:ClearAllPoints()
  self.frame:SetPoint(
    self.settings.point or "CENTER",
    UIParent,
    self.settings.relative_point or "CENTER",
    self.settings.x or 0,
    self.settings.y or 110
  )
end

function BareNecessities:RefreshVisibility()
  if self.settings.visible then
    self.frame:Show()
  else
    self.frame:Hide()
  end
end

function BareNecessities:RegisterSlashCommands()
  SLASH_CHUMBADDONNEEDS1 = "/needs"
  SLASH_CHUMBADDONNEEDS2 = "/survival"
  SlashCmdList.CHUMBADDONNEEDS = function(message)
    self:HandleSlashCommand(message)
  end
end

function BareNecessities:HandleSlashCommand(message)
  local command = string.lower(string.match(message or "", "^%s*(.-)%s*$"))
  if command == "show" then
    self.settings.visible = true
  elseif command == "hide" then
    self.settings.visible = false
  elseif command == "lock" then
    self.settings.locked = true
    self:Print("HUD locked.")
  elseif command == "unlock" then
    self.settings.locked = false
    self:Print("HUD unlocked; drag it with the left mouse button.")
  elseif command == "reset" then
    self.settings.point = nil
    self.settings.relative_point = nil
    self.settings.x = nil
    self.settings.y = nil
    self.settings.visible = true
    self:RestorePosition()
    self:Print("HUD position reset.")
  elseif command == "" then
    self.settings.visible = not self.settings.visible
  else
    self:Print("Commands: show, hide, lock, unlock, reset")
    return
  end
  self:RefreshVisibility()
end
