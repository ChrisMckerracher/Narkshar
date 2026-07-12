local unpack = unpack or table.unpack

local FRAME_WIDTH = 154
local ROW_HEIGHT = 22
local ROW_STEP = 24
local ICON_SIZE = 20
local BAR_LEFT = 28
local SEGMENT_WIDTH = 23
local SEGMENT_HEIGHT = 12
local SEGMENT_GAP = 2
local BAR_TEXTURE = "Interface\\TARGETINGFRAME\\UI-StatusBar"

function BareNecessities:CreateUi()
  local frame = CreateFrame("Frame", "BareNecessitiesFrame", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetSize(FRAME_WIDTH, ROW_STEP * 4)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  self.frame = frame
  self:AttachDragScripts(frame)

  for _, resource in ipairs(self.resource_order) do
    self.ui_rows[resource.key] = self:CreateResourceRow(frame, resource)
  end

  self:RestorePosition()
  self:RefreshVisibility()
  self:RefreshDisplays()
end

function BareNecessities:CreateResourceRow(parent, resource)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(FRAME_WIDTH, ROW_HEIGHT)
  row:EnableMouse(true)
  self:AttachDragScripts(row)

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("LEFT", row, "LEFT", 1, 0)
  icon:SetTexture(resource.icon)
  icon:SetTexCoord(0.09, 0.91, 0.09, 0.91)

  local icon_border = row:CreateTexture(nil, "OVERLAY")
  icon_border:SetSize(29, 29)
  icon_border:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon_border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

  local empty_segments = {}
  local filled_segments = {}
  for index = 1, 5 do
    local x = BAR_LEFT + ((index - 1) * (SEGMENT_WIDTH + SEGMENT_GAP))

    local empty = row:CreateTexture(nil, "BACKGROUND")
    self:ConfigureSegment(empty, row, x, resource.bar_color)
    empty:SetAlpha(0.18)
    empty_segments[index] = empty

    local filled = row:CreateTexture(nil, "ARTWORK")
    self:ConfigureSegment(filled, row, x, resource.bar_color)
    filled:SetAlpha(0.95)
    filled_segments[index] = filled
  end

  row:SetScript("OnEnter", function()
    self:ShowResourceTooltip(row, resource)
  end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return {
    frame = row,
    icon = icon,
    empty_segments = empty_segments,
    filled_segments = filled_segments,
  }
end

function BareNecessities:ConfigureSegment(texture, row, x, color)
  texture:SetSize(SEGMENT_WIDTH, SEGMENT_HEIGHT)
  texture:SetPoint("LEFT", row, "LEFT", x, 0)
  texture:SetTexture(BAR_TEXTURE)
  texture:SetVertexColor(unpack(color))
end

function BareNecessities:AttachDragScripts(target)
  target:RegisterForDrag("LeftButton")
  target:SetScript("OnDragStart", function()
    if not self.settings.locked then
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

  local visible_count = 0
  for _, resource in ipairs(self.resource_order) do
    local value = self.values[resource.key]
    local row = self.ui_rows[resource.key]
    if value == nil then
      row.frame:Hide()
    else
      row.frame:ClearAllPoints()
      row.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(visible_count * ROW_STEP))
      row.frame:Show()
      self:UpdateResourceRow(resource, row, value)
      visible_count = visible_count + 1
    end
  end

  self.frame:SetHeight(math.max(1, visible_count * ROW_STEP))
end

function BareNecessities:UpdateResourceRow(resource, row, value)
  local level = self:GetDisplayLevel(resource, value) or 0
  for index, segment in ipairs(row.filled_segments) do
    if index <= level then
      segment:Show()
    else
      segment:Hide()
    end
  end

  row.icon:SetDesaturated(level == 0)
  row.icon:SetAlpha(level == 0 and 0.58 or 1)
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
    self:Print("Meters locked.")
  elseif command == "unlock" then
    self.settings.locked = false
    self:Print("Meters unlocked; drag any row to move them.")
  elseif command == "reset" then
    self.settings.point = nil
    self.settings.relative_point = nil
    self.settings.x = nil
    self.settings.y = nil
    self.settings.visible = true
    self:RestorePosition()
    self:Print("Meter position reset.")
  elseif command == "" then
    self.settings.visible = not self.settings.visible
  else
    self:Print("Commands: show, hide, lock, unlock, reset")
    return
  end
  self:RefreshVisibility()
end
