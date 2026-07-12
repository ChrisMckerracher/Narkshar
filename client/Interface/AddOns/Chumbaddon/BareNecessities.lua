BareNecessities = {}
BareNecessities.__index = BareNecessities

local unpack = unpack or table.unpack

local RESOURCE_DEFINITIONS = {
  {
    key = "hunger",
    label = "Fullness",
    urgent_text = "Eat something now",
    icon = "Interface\\Icons\\INV_Misc_Food_15",
    bar_color = { 0.91, 0.58, 0.22 },
    max_value = 5,
    hint = "Eat food to restore fullness.",
  },
  {
    key = "thirst",
    label = "Hydration",
    urgent_text = "Drink something now",
    icon = "Interface\\Icons\\INV_Drink_01",
    bar_color = { 0.20, 0.58, 0.94 },
    max_value = 5,
    hint = "Drink to restore hydration.",
  },
  {
    key = "fatigue",
    label = "Energy",
    urgent_text = "Get some rest now",
    icon = "Interface\\Icons\\Spell_Nature_Sleep",
    bar_color = { 0.63, 0.52, 0.91 },
    max_value = 50,
    hint = "Rest in an inn, city, or near a fire to recover energy.",
  },
  {
    key = "damage",
    label = "Condition",
    urgent_text = "Treat your wounds now",
    icon = "Interface\\Icons\\INV_Misc_Bandage_15",
    bar_color = { 0.85, 0.35, 0.32 },
    max_value = 5,
    hint = "Use bandages to improve your condition.",
  },
}

function BareNecessities:new()
  local o = setmetatable({}, self)
  o.prefix = "BNSTAT"
  o.player_name = nil
  o.resource_order = RESOURCE_DEFINITIONS
  o.resource_map = {}
  o.values = {}
  o.ui_rows = {}

  for _, resource in ipairs(o.resource_order) do
    o.resource_map[resource.key] = resource
  end

  return o
end

function BareNecessities:register()
  if self.frame then
    return
  end

  self:InitializeSettings()
  self:CreateUi()
  self:RegisterSlashCommands()

  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("PLAYER_NAME_UPDATE")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:SafelyHandleEvent(event, ...)
  end)
end

function BareNecessities:InitializeSettings()
  ChumbaddonDB = ChumbaddonDB or {}
  ChumbaddonDB.survival_hud = ChumbaddonDB.survival_hud or {}
  self.settings = ChumbaddonDB.survival_hud

  if self.settings.visible == nil then
    self.settings.visible = true
  end
  if self.settings.locked == nil then
    self.settings.locked = false
  end
end

function BareNecessities:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self.player_name = UnitName("player")
    self:RegisterMessagePrefix()
    self:RefreshDisplays()
  elseif event == "PLAYER_NAME_UPDATE" then
    local unit = ...
    if unit == "player" then
      self.player_name = UnitName("player")
    end
  elseif event == "CHAT_MSG_ADDON" then
    self:OnChatMessageAddon(...)
  end
end

function BareNecessities:RegisterMessagePrefix()
  if self.prefix_registered or not RegisterAddonMessagePrefix then
    return
  end
  if RegisterAddonMessagePrefix(self.prefix) then
    self.prefix_registered = true
  end
end

function BareNecessities:SafelyHandleEvent(event, ...)
  local args = { ... }
  local ok, err = xpcall(function()
    self:OnEvent(event, unpack(args))
  end, function(message)
    local stack = debugstack and debugstack() or ""
    return string.format("%s\n%s", tostring(message), stack)
  end)

  if not ok then
    self:Print("error: " .. tostring(err))
  end
end

function BareNecessities:OnChatMessageAddon(prefix, message)
  if prefix ~= self.prefix or type(message) ~= "string" then
    return
  end

  local target, payload = string.match(message, "^([^|]+)|(.+)$")
  if not target or not payload or (self.player_name and target ~= self.player_name) then
    return
  end

  local next_values = {}
  local recognized = false
  for entry in string.gmatch(payload, "[^,]+") do
    local key, value = string.match(entry, "^%s*([^=]+)%s*=%s*(-?%d+%.?%d*)%s*$")
    key = key and string.lower(key)
    local numeric = tonumber(value)
    if key and numeric and self.resource_map[key] then
      next_values[key] = self:NormalizeValue(key, numeric)
      recognized = true
    end
  end

  if recognized then
    self.values = next_values
    self:RefreshDisplays()
  end
end

function BareNecessities:NormalizeValue(key, value)
  local resource = self.resource_map[key]
  local maximum = resource and resource.max_value or 100
  return self:ClampValue(value, maximum)
end

function BareNecessities:ClampValue(value, maximum)
  if type(value) ~= "number" or value < 0 then
    return 0
  end
  if value > maximum then
    return maximum
  end
  return value
end

function BareNecessities:GetRatio(resource, value)
  if value == nil or not resource or resource.max_value <= 0 then
    return nil
  end
  return self:ClampValue(value, resource.max_value) / resource.max_value
end

function BareNecessities:GetState(ratio)
  if ratio == nil then
    return "Unavailable", "unavailable"
  elseif ratio <= 0 then
    return "Depleted", "critical"
  elseif ratio < 0.4 then
    return "Critical", "critical"
  elseif ratio < 0.6 then
    return "Low", "warning"
  elseif ratio < 0.8 then
    return "Fair", "healthy"
  elseif ratio < 1 then
    return "Steady", "healthy"
  end
  return "Full", "healthy"
end

function BareNecessities:FormatValue(resource, value)
  if value == nil then
    return "--"
  end
  if math.floor(value) == value then
    return string.format("%d / %d", value, resource.max_value)
  end
  return string.format("%.1f / %d", value, resource.max_value)
end

function BareNecessities:Print(message)
  local text = "|cffd9b66f[Survival]|r " .. tostring(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  else
    print(text)
  end
end
