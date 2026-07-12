local unpack = unpack or table.unpack

local BASE_WIDTH = 242
local BASE_HEIGHT = 100
local MIN_SCALE = 0.75
local MAX_SCALE = 1.75
local ROW_HEIGHT = 22
local BAR_WIDTH = 140
local BAR_HEIGHT = 12

function BareNecessities:CreateUi()
  local frame = CreateFrame("Frame", "BareNecessitiesFrame", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetSize(BASE_WIDTH, BASE_HEIGHT)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetMinResize(BASE_WIDTH * MIN_SCALE, BASE_HEIGHT * MIN_SCALE)
  frame:SetMaxResize(BASE_WIDTH * MAX_SCALE, BASE_HEIGHT * MAX_SCALE)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.64)
  frame:SetBackdropBorderColor(0.72, 0.72, 0.72, 0.72)
  self.frame = frame

  local content = CreateFrame("Frame", nil, frame)
  content:SetSize(BASE_WIDTH, BASE_HEIGHT)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  self.content = content
  self:AttachDragScripts(frame)

  for index, resource in ipairs(self.resource_order) do
    self.ui_rows[resource.key] = self:CreateResourceRow(content, resource, index)
  end

  self:CreateResizeHandle(frame)
  frame:SetScript("OnSizeChanged", function(_, width)
    if self.is_resizing and not self.applying_scale then
      self:ApplyScale(width / BASE_WIDTH)
    end
  end)

  self:RestorePosition()
  self:ApplyScale(self.settings.scale)
  self:RefreshVisibility()
  self:RefreshDisplays()
end

function BareNecessities:CreateResourceRow(parent, resource, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(BASE_WIDTH - 20, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -6 - ((index - 1) * ROW_HEIGHT))
  row:EnableMouse(true)
  self:AttachDragScripts(row)

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", row, "LEFT", 2, 0)
  label:SetText(resource.label)

  local bar = CreateFrame("StatusBar", nil, row)
  bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  bar:SetMinMaxValues(0, resource.max_value)
  bar:SetValue(0)
  bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
  bar:SetPoint("LEFT", row, "LEFT", 80, 0)
  bar:SetStatusBarColor(unpack(resource.bar_color))

  local bar_background = bar:CreateTexture(nil, "BACKGROUND")
  bar_background:SetAllPoints()
  bar_background:SetTexture(0.05, 0.05, 0.05, 0.82)
  self:CreateSegmentDividers(bar)

  row:SetScript("OnEnter", function()
    self:ShowResourceTooltip(row, resource)
  end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return { frame = row, label = label, bar = bar }
end

function BareNecessities:CreateSegmentDividers(bar)
  for index = 1, 4 do
    local divider = bar:CreateTexture(nil, "OVERLAY")
    divider:SetTexture(0, 0, 0, 0.86)
    divider:SetSize(1, BAR_HEIGHT)
    divider:SetPoint("LEFT", bar, "LEFT", (BAR_WIDTH / 5) * index, 0)
  end
end

function BareNecessities:CreateResizeHandle(frame)
  local handle = CreateFrame("Button", nil, frame)
  handle:SetSize(13, 13)
  handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

  local texture = handle:CreateTexture(nil, "OVERLAY")
  texture:SetAllPoints()
  texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  texture:SetAlpha(0.72)

  handle:SetScript("OnMouseDown", function()
    if not self.settings.locked then
      self.is_resizing = true
      frame:StartSizing("BOTTOMRIGHT")
    end
  end)
  handle:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    self.is_resizing = false
    self:ApplyScale(self.settings.scale)
    self:SavePosition()
  end)
  self.resize_handle = handle
end

function BareNecessities:ApplyScale(scale)
  scale = self:ClampValue(scale or 1, MAX_SCALE)
  if scale < MIN_SCALE then
    scale = MIN_SCALE
  end

  self.settings.scale = scale
  self.applying_scale = true
  self.content:SetScale(scale)
  self.frame:SetSize(BASE_WIDTH * scale, BASE_HEIGHT * scale)
  self.applying_scale = false
end

function BareNecessities:AttachDragScripts(target)
  target:RegisterForDrag("LeftButton")
  target:SetScript("OnDragStart", function()
    if not self.settings.locked and not self.is_resizing then
      self.frame:StartMoving()
    end
  end)
  target:SetScript("OnDragStop", function()
    self.frame:StopMovingOrSizing()
    self:SavePosition()
  end)
end

function BareNecessities:RefreshDisplays()
  if not self.frame then
    return
  end

  for _, resource in ipairs(self.resource_order) do
    local row = self.ui_rows[resource.key]
    local value = self.values[resource.key]
    if value == nil then
      row.frame:Hide()
    else
      row.frame:Show()
      self:UpdateResourceRow(resource, row, value)
    end
  end
end

function BareNecessities:UpdateResourceRow(resource, row, value)
  local ratio = self:GetRatio(resource, value) or 0
  row.bar:SetMinMaxValues(0, resource.max_value)
  row.bar:SetValue(value or 0)

  if ratio <= 0.1 then
    row.label:SetTextColor(1, 0.1, 0.1)
  elseif ratio <= 0.2 then
    row.label:SetTextColor(1, 0.82, 0)
  else
    row.label:SetTextColor(0.9, 0.9, 0.9)
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
  if self.resize_handle then
    if self.settings.visible and not self.settings.locked then
      self.resize_handle:Show()
    else
      self.resize_handle:Hide()
    end
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
    self:Print("HUD unlocked; drag to move or use the corner grip to resize.")
  elseif command == "reset" then
    self.settings.point = nil
    self.settings.relative_point = nil
    self.settings.x = nil
    self.settings.y = nil
    self.settings.scale = 1
    self.settings.visible = true
    self:RestorePosition()
    self:ApplyScale(1)
    self:Print("HUD position and size reset.")
  elseif command == "" then
    self.settings.visible = not self.settings.visible
  else
    self:Print("Commands: show, hide, lock, unlock, reset")
    return
  end
  self:RefreshVisibility()
end
