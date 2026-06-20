SubclassPicker = {}
SubclassPicker.__index = SubclassPicker

local unpack = unpack or table.unpack

local CLASS_FILE_TO_ID = {
  WARRIOR = 1,
  PALADIN = 2,
  HUNTER = 3,
  ROGUE = 4,
  PRIEST = 5,
  SHAMAN = 7,
  MAGE = 8,
  WARLOCK = 9,
  DRUID = 11,
}

local CLASS_ORDER = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }

local DEFAULT_CLASS_NAMES = {
  [1] = "Warrior",
  [2] = "Paladin",
  [3] = "Hunter",
  [4] = "Rogue",
  [5] = "Priest",
  [7] = "Shaman",
  [8] = "Mage",
  [9] = "Warlock",
  [11] = "Druid",
}

local CLASS_NAME_TO_ID = {
  warrior = 1,
  paladin = 2,
  hunter = 3,
  rogue = 4,
  priest = 5,
  shaman = 7,
  mage = 8,
  warlock = 9,
  druid = 11,
}

local function trim(value)
  return string.gsub(value or "", "^%s*(.-)%s*$", "%1")
end

local function class_name(class_id, names)
  return (names and names[class_id]) or DEFAULT_CLASS_NAMES[class_id] or "Class"
end

function SubclassPicker:new()
  local o = setmetatable({}, self)
  o.prefix = "SCSUB"
  o.debug_prefix = "[SubclassPicker]"
  o.native_class = 0
  o.subclass_class = 0
  o.level = 0
  o.unlock_level = 10
  o.classes = {}
  o.buttons = {}
  return o
end

function SubclassPicker:register()
  if self.frame then
    return
  end

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:SafelyHandleEvent(event, ...)
  end)

  SLASH_CHUMBADDONSUBCLASSPICKER1 = "/subclass"
  SLASH_CHUMBADDONSUBCLASSPICKER2 = "/picksubclass"
  SlashCmdList.CHUMBADDONSUBCLASSPICKER = function(input)
    self:HandleSlash(input)
  end
end

function SubclassPicker:HandleSlash(input)
  local value = string.lower(trim(input))
  if value == "" or value == "show" or value == "open" then
    self:TogglePanel()
    return
  end

  if value == "refresh" then
    self:RequestData()
    return
  end

  if value == "clear" or value == "none" or value == "0" then
    self:ConfirmSelect(0)
    return
  end

  local class_id = CLASS_NAME_TO_ID[value] or tonumber(value)
  if class_id then
    self:ConfirmSelect(class_id)
    return
  end

  self:Print("Usage: /subclass, /subclass mage, /subclass clear, /subclass refresh")
end

function SubclassPicker:SafelyHandleEvent(event, ...)
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

function SubclassPicker:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:RegisterPrefix()
    self:RequestData()
  elseif event == "CHAT_MSG_ADDON" then
    self:OnAddonMessage(...)
  end
end

function SubclassPicker:RegisterPrefix()
  if self.prefix_registered or not RegisterAddonMessagePrefix then
    return
  end

  if RegisterAddonMessagePrefix(self.prefix) then
    self.prefix_registered = true
  end
end

function SubclassPicker:RequestData()
  if SendAddonMessage then
    local player_name = UnitName("player")
    if player_name then
      SendAddonMessage(self.prefix, "refresh", "WHISPER", player_name)
    end
  end
end

function SubclassPicker:TogglePanel()
  self:EnsurePanel()
  self:RequestData()

  if self.panel:IsShown() then
    self.panel:Hide()
  else
    self.panel:Show()
    self:Refresh()
  end
end

function SubclassPicker:EnsurePanel()
  if self.panel then
    return
  end

  local panel = CreateFrame("Frame", "ChumbaddonSubclassPickerFrame", UIParent)
  panel:SetSize(330, 390)
  panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  panel:SetFrameStrata("DIALOG")
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(frame)
    frame:StartMoving()
  end)
  panel:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
  end)
  panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -22)
  title:SetText("Choose Subclass")
  panel.title = title

  local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  status:SetWidth(270)
  status:SetJustifyH("LEFT")
  panel.status = status

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)

  for index, class_id in ipairs(CLASS_ORDER) do
    local button = CreateFrame("Button", "ChumbaddonSubclassPickerClass" .. class_id, panel, "UIPanelButtonTemplate")
    button:SetSize(128, 24)
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", 28 + column * 140, -88 - row * 32)
    button.class_id = class_id
    button:SetScript("OnClick", function(btn)
      self:ConfirmSelect(btn.class_id)
    end)
    self.buttons[class_id] = button
  end

  local clear = CreateFrame("Button", "ChumbaddonSubclassPickerClear", panel, "UIPanelButtonTemplate")
  clear:SetSize(128, 24)
  clear:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 28, 24)
  clear:SetText("Clear")
  clear:SetScript("OnClick", function()
    self:ConfirmSelect(0)
  end)
  panel.clear = clear

  local refresh = CreateFrame("Button", "ChumbaddonSubclassPickerRefresh", panel, "UIPanelButtonTemplate")
  refresh:SetSize(128, 24)
  refresh:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 24)
  refresh:SetText("Refresh")
  refresh:SetScript("OnClick", function()
    self:RequestData()
  end)
  panel.refresh = refresh

  self.panel = panel
end

function SubclassPicker:ConfirmSelect(class_id)
  class_id = tonumber(class_id) or 0
  if class_id ~= 0 and not DEFAULT_CLASS_NAMES[class_id] then
    self:Print("Invalid subclass.")
    return
  end

  local current = tonumber(self.subclass_class) or 0
  local message
  if class_id == 0 then
    if current == 0 then
      return
    end
    message = "Clear your subclass? This removes subclass spells and talents."
  elseif current ~= 0 and current ~= class_id then
    message = string.format("Switch subclass to %s? This removes current subclass spells and talents.", class_name(class_id, self.classes))
  else
    message = string.format("Choose %s as your subclass?", class_name(class_id, self.classes))
  end

  StaticPopupDialogs.CHUMBADDON_SUBCLASS_PICKER_CONFIRM = {
    text = message,
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
      self:SetSubclass(class_id)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
  StaticPopup_Show("CHUMBADDON_SUBCLASS_PICKER_CONFIRM")
end

function SubclassPicker:SetSubclass(class_id)
  if SendAddonMessage then
    local player_name = UnitName("player")
    if player_name then
      SendAddonMessage(self.prefix, string.format("set=%d", class_id), "WHISPER", player_name)
    end
  end
end

function SubclassPicker:OnAddonMessage(prefix, message, channel, sender)
  if prefix ~= self.prefix then
    return
  end

  local player_name = UnitName("player")
  local target, payload = string.match(message or "", "^([^|]+)|(.+)$")
  if target and player_name and target ~= player_name then
    return
  end

  self:ParsePayload(payload or message)
  self:Refresh()
end

function SubclassPicker:ParsePayload(payload)
  for key, value in string.gmatch(payload or "", "([^=;]+)=([^;]+)") do
    key = string.lower(key)
    if key == "native" then
      self.native_class = tonumber(value) or self.native_class
    elseif key == "class" then
      self.subclass_class = tonumber(value) or 0
    elseif key == "level" then
      self.level = tonumber(value) or self.level
    elseif key == "unlock" then
      self.unlock_level = tonumber(value) or self.unlock_level
    elseif key == "message" then
      self.last_message = value
      self:Print(value)
    elseif key == "classes" then
      for class_id, name in string.gmatch(value, "(%d+):([^,]+)") do
        self.classes[tonumber(class_id)] = name
      end
    end
  end

  if not self.native_class or self.native_class == 0 then
    local _, class_file = UnitClass("player")
    self.native_class = CLASS_FILE_TO_ID[class_file] or 0
  end
end

function SubclassPicker:Refresh()
  self:EnsurePanel()
  if not self.panel then
    return
  end

  local current = tonumber(self.subclass_class) or 0
  local native = tonumber(self.native_class) or 0
  local level = tonumber(self.level) or UnitLevel("player") or 0
  local unlock = tonumber(self.unlock_level) or 10

  if level < unlock then
    self.panel.status:SetText(string.format("Subclass unlocks at level %d.", unlock))
  elseif current ~= 0 then
    self.panel.status:SetText(string.format("Current subclass: %s", class_name(current, self.classes)))
  else
    self.panel.status:SetText("No subclass selected.")
  end

  for _, class_id in ipairs(CLASS_ORDER) do
    local button = self.buttons[class_id]
    if button then
      button:SetText(class_name(class_id, self.classes))
      if level < unlock or class_id == native or class_id == current then
        button:Disable()
      else
        button:Enable()
      end
    end
  end

  if self.panel.clear then
    if current ~= 0 then
      self.panel.clear:Enable()
    else
      self.panel.clear:Disable()
    end
  end
end

function SubclassPicker:Print(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s %s", self.debug_prefix, tostring(message)))
  else
    print(string.format("%s %s", self.debug_prefix, tostring(message)))
  end
end

function SubclassPicker:ReportError(message)
  self:Print(message)
end
