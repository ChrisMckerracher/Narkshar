local unpack = unpack or table.unpack

local GAUGE_SIZE = 54
local GAUGE_STEP = 56
local RING_TEXTURE = "Interface\\AddOns\\Chumbaddon\\Media\\SurvivalRing"
local RING_CELLS = {
  { 0 / 8, 1 / 8, 0, 1 },
  { 1 / 8, 2 / 8, 0, 1 },
  { 2 / 8, 3 / 8, 0, 1 },
  { 3 / 8, 4 / 8, 0, 1 },
  { 4 / 8, 5 / 8, 0, 1 },
}

function BareNecessities:CreateUi()
  local frame = CreateFrame("Frame", "BareNecessitiesFrame", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetSize(GAUGE_STEP * 4, GAUGE_SIZE)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  self.frame = frame
  self:AttachDragScripts(frame)

  for _, resource in ipairs(self.resource_order) do
    self.ui_rows[resource.key] = self:CreateGauge(frame, resource)
  end

  self:RestorePosition()
  self:RefreshVisibility()
  self:RefreshDisplays()
end

function BareNecessities:CreateGauge(parent, resource)
  local gauge = CreateFrame("Frame", nil, parent)
  gauge:SetSize(GAUGE_SIZE, GAUGE_SIZE)
  gauge:EnableMouse(true)
  self:AttachDragScripts(gauge)

  local icon = gauge:CreateTexture(nil, "ARTWORK")
  icon:SetSize(27, 27)
  icon:SetPoint("CENTER", gauge, "CENTER", 0, 0)
  icon:SetTexture(resource.icon)
  icon:SetTexCoord(0.09, 0.91, 0.09, 0.91)

  local empty_segments = {}
  local filled_segments = {}
  for index, coordinates in ipairs(RING_CELLS) do
    local empty = gauge:CreateTexture(nil, "BACKGROUND")
    self:ConfigureRingSegment(empty, coordinates)
    empty:SetVertexColor(0.18, 0.18, 0.18)
    empty:SetAlpha(0.72)
    empty_segments[index] = empty

    local filled = gauge:CreateTexture(nil, "OVERLAY")
    self:ConfigureRingSegment(filled, coordinates)
    filled:SetVertexColor(unpack(resource.bar_color))
    filled:SetBlendMode("ADD")
    filled_segments[index] = filled
  end

  gauge:SetScript("OnEnter", function()
    self:ShowResourceTooltip(gauge, resource)
  end)
  gauge:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return {
    frame = gauge,
    icon = icon,
    empty_segments = empty_segments,
    filled_segments = filled_segments,
  }
end

function BareNecessities:ConfigureRingSegment(texture, coordinates)
  texture:SetSize(52, 52)
  texture:SetPoint("CENTER", texture:GetParent(), "CENTER", 0, 0)
  texture:SetTexture(RING_TEXTURE)
  texture:SetTexCoord(unpack(coordinates))
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
    local gauge = self.ui_rows[resource.key]
    if value == nil then
      gauge.frame:Hide()
    else
      gauge.frame:ClearAllPoints()
      gauge.frame:SetPoint("LEFT", self.frame, "LEFT", visible_count * GAUGE_STEP, 0)
      gauge.frame:Show()
      self:UpdateGauge(resource, gauge, value)
      visible_count = visible_count + 1
    end
  end

  self.frame:SetWidth(math.max(1, visible_count * GAUGE_STEP))
end

function BareNecessities:UpdateGauge(resource, gauge, value)
  local level = self:GetDisplayLevel(resource, value) or 0
  for index, segment in ipairs(gauge.filled_segments) do
    if index <= level then
      segment:Show()
    else
      segment:Hide()
    end
  end

  gauge.icon:SetDesaturated(level == 0)
  gauge.icon:SetAlpha(level == 0 and 0.52 or 1)
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
    self:Print("Gauges locked.")
  elseif command == "unlock" then
    self.settings.locked = false
    self:Print("Gauges unlocked; drag any icon to move them.")
  elseif command == "reset" then
    self.settings.point = nil
    self.settings.relative_point = nil
    self.settings.x = nil
    self.settings.y = nil
    self.settings.visible = true
    self:RestorePosition()
    self:Print("Gauge position reset.")
  elseif command == "" then
    self.settings.visible = not self.settings.visible
  else
    self:Print("Commands: show, hide, lock, unlock, reset")
    return
  end
  self:RefreshVisibility()
end
