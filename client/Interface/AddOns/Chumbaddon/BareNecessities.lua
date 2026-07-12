BareNecessities = {}
BareNecessities.__index = BareNecessities

local unpack = unpack or table.unpack

function BareNecessities:new()
  local o = setmetatable({}, self)
o.prefix = "BNSTAT"
o.debug_prefix = "[BareNecessities]"
o.player_name = nil
  o.resource_order = {
    {
      key = "hunger",
      label = "Hunger",
      bar_color = { 0.80, 0.52, 0.26 },
      max_value = 5,
      transform = function(raw)
        if not raw then
          return 0
        end
        return raw
      end,
    },
    {
      key = "thirst",
      label = "Thirst",
      bar_color = { 0.26, 0.52, 0.90 },
      max_value = 5,
      transform = function(raw)
        if not raw then
          return 0
        end
        return raw
      end,
    },
    {
      key = "fatigue",
      label = "Fatigue",
      bar_color = { 0.58, 0.64, 0.86 },
      max_value = 5,
      transform = function(raw)
        if not raw then
          return 0
        end
        return math.floor(raw / 10)
      end,
    },
    {
      key = "damage",
      label = "Damage",
      bar_color = { 0.86, 0.18, 0.18 },
      max_value = 5,
      transform = function(raw)
        if not raw then
          return 0
        end
        return raw
      end,
    },
  }
  o.resource_map = {}
  o.values = {}
  for _, resource in ipairs(o.resource_order) do
    o.resource_map[resource.key] = resource
    o.values[resource.key] = 0
  end
  o.segment_count = 5
  o.ui_rows = {}
  return o
end

function BareNecessities:register()
  if self.frame then
    return
  end

  self:CreateUi()
  self:ReportInfo("register() invoked")

  local frame = self.frame
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_NAME_UPDATE")
  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:SetScript("OnEvent", function(_, event, ...)
    self:SafelyHandleEvent(event, ...)
  end)

  self:ReportInfo("Events wired")
end

function BareNecessities:CreateUi()
  local frame = CreateFrame("Frame", "BareNecessitiesFrame", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetSize(280, 130)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetTexture(0, 0, 0, 0.55)

  local border = CreateFrame("Frame", nil, frame)
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
  border:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
  })
  border:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.7)

  local row_height = 26
  local start_offset = -12

  for index, resource in ipairs(self.resource_order) do
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(260, row_height)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, start_offset - (index - 1) * row_height)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", 4, 0)
    label:SetText(resource.label)

    local status_bar = CreateFrame("StatusBar", nil, row)
    status_bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    status_bar:SetMinMaxValues(0, resource.max_value or 100)
    status_bar:SetValue(0)
    status_bar:SetSize(140, 14)
    status_bar:SetPoint("LEFT", row, "LEFT", 110, 0)
    status_bar:SetStatusBarColor(unpack(resource.bar_color))

    local bar_bg = status_bar:CreateTexture(nil, "BACKGROUND")
    bar_bg:SetAllPoints()
    bar_bg:SetTexture(0.05, 0.05, 0.05, 0.7)

    self:CreateSegmentDividers(status_bar)

    self.ui_rows[resource.key] = {
      label = label,
      bar = status_bar,
    }
  end

  self.frame = frame
  frame:Show()
  self:ReportInfo("Frame initialized")
end

function BareNecessities:CreateSegmentDividers(status_bar)
  status_bar.segmentDividers = {}

  local function layout() 
    local width = status_bar:GetWidth()
    local height = status_bar:GetHeight()
    for index = 1, self.segment_count - 1 do
      local divider = status_bar.segmentDividers[index]
      if not divider then
        divider = status_bar:CreateTexture(nil, "ARTWORK")
        status_bar.segmentDividers[index] = divider
      end
      divider:SetTexture(0, 0, 0, 0.8)
      divider:SetWidth(1)
      divider:SetHeight(height)
      divider:ClearAllPoints()
      divider:SetPoint("LEFT", status_bar, "LEFT", (width / self.segment_count) * index, 0)
    end
  end

  status_bar:SetScript("OnSizeChanged", layout)
  layout()
end

function BareNecessities:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self.player_name = UnitName("player")
    if not self.prefix_registered and RegisterAddonMessagePrefix then
      if RegisterAddonMessagePrefix(self.prefix) then
        self.prefix_registered = true
        self:ReportInfo("Registered addon prefix " .. self.prefix)
      end
    end
    self:RefreshDisplays()
    self:ReportInfo("RefreshDisplays executed for event " .. event)
  elseif event == "PLAYER_NAME_UPDATE" then
    local unit = ...
    if unit == "player" then
      self.player_name = UnitName("player")
      self:ReportInfo("Player name updated: " .. tostring(self.player_name))
    end
  elseif event == "CHAT_MSG_ADDON" then
    self:OnChatMessageAddon(...)
  end
end

function BareNecessities:SafelyHandleEvent(event, ...)
  local args = { ... }
  local ok, err = xpcall(function()
    self:OnEvent(event, unpack(args))
  end, function(message)
    return string.format("%s\n%s", tostring(message), debugstack())
  end)

  if not ok and err then
    self:ReportError(err)
  end
end

function BareNecessities:OnChatMessageAddon(prefix, message, channel, sender)
  if prefix ~= self.prefix then
    return
  end

  local target, payload = string.match(message, "([^|]+)|(.+)")
  if not target or not payload then
    return
  end

  if self.player_name and target ~= self.player_name then
    return
  end

  local updated = false
  for entry in string.gmatch(payload, "[^,]+") do
    local key, value = string.match(entry, "([^=]+)=(%d+)")
    if key and value then
      key = string.lower(key)
      local numeric = tonumber(value)
      if numeric and self.values[key] ~= nil then
        self.values[key] = self:NormalizeValue(key, numeric)
        updated = true
      end
    end
  end

  if updated then
    self:RefreshDisplays()
  end
end

function BareNecessities:NormalizeValue(key, value)
  local resource = self.resource_map[key]
  if not resource then
    return self:ClampValue(value, 100)
  end

  local normalized = value
  if resource.transform then
    normalized = resource.transform(value)
  end

  if type(normalized) ~= "number" then
    return self:ClampValue(0, resource.max_value)
  end

  return self:ClampValue(normalized, resource.max_value)
end

function BareNecessities:RefreshDisplays()
  for _, resource in ipairs(self.resource_order) do
    local row = self.ui_rows[resource.key]
    if row then
      local value = self.values[resource.key] or 0
      self:UpdateRow(resource, row, value)
    end
  end
end

function BareNecessities:UpdateRow(resource, row, value)
  local max_value = resource.max_value or 100
  local clamped = self:ClampValue(value, max_value)
  row.bar:SetMinMaxValues(0, max_value)
  row.bar:SetValue(clamped)

  local percent = 0
  if max_value > 0 then
    percent = (clamped / max_value) * 100
  end

  if percent <= 10 then
    row.label:SetTextColor(1, 0.1, 0.1)
  elseif percent <= 20 then
    row.label:SetTextColor(1, 0.82, 0)
  else
    row.label:SetTextColor(0.9, 0.9, 0.9)
  end
end

function BareNecessities:ReportError(message)
  local text = string.format("%s error: %s", self.debug_prefix, tostring(message))
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  else
    print(text)
  end
end

function BareNecessities:ReportInfo(message)
  local text = string.format("%s %s", self.debug_prefix, tostring(message))
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  else
    print(text)
  end
end

function BareNecessities:ClampValue(value, max_value)
  max_value = max_value or 100
  if not value then
    return 0
  end
  if value < 0 then
    return 0
  elseif value > max_value then
    return max_value
  end
  return value
end

function BareNecessities:FormatValueForDisplay(resource, value)
  local max_value = resource.max_value or 100
  if max_value <= 10 then
    return string.format("%d/%d", value, max_value)
  end

  local percent = 0
  if max_value > 0 then
    percent = math.floor((value / max_value) * 100)
  end
  return string.format("%d%%", percent)
end
