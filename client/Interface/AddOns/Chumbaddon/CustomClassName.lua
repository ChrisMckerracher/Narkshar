CustomClassName = {}
CustomClassName.__index = CustomClassName

local unpack = unpack or table.unpack

function CustomClassName:new()
  local o = setmetatable({}, self)
  o.prefix = "SCCLASS"
  o.debug_prefix = "[CustomClassName]"
  o.display_name = nil
  o.is_custom = false
  o.native_class_name = nil
  o.last_applied_name = nil
  o.players = {}
  o.pending_requests = {}
  return o
end

function CustomClassName:register()
  if self.frame then
    return
  end

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("ADDON_LOADED")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  self.frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:SafelyHandleEvent(event, ...)
  end)
end

function CustomClassName:SafelyHandleEvent(event, ...)
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

function CustomClassName:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    local addon_name = ...
    if addon_name == "Blizzard_CharacterUI" then
      self:InstallCharacterPanelHooks()
      self:RefreshCharacterPanel()
    end
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:RegisterPrefix()
    self:InstallCharacterPanelHooks()
    self:InstallTooltipHook()
    self:RequestData()
    self:RefreshCharacterPanel()
  elseif event == "CHAT_MSG_ADDON" then
    self:OnAddonMessage(...)
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
    self:RequestUnitData(event == "PLAYER_TARGET_CHANGED" and "target" or "mouseover")
    self:RefreshCharacterPanel()
  end
end

function CustomClassName:RequestData()
  if SendAddonMessage then
    local player_name = UnitName("player")
    if player_name then
      SendAddonMessage(self.prefix, "refresh", "WHISPER", player_name)
    end
  end
end

function CustomClassName:BuildPayload()
  local player_name = UnitName("player")
  if not player_name then
    return nil
  end

  return string.format("%s|name=%s;custom=%d;native=%s",
    player_name,
    self:GetDisplayName() or self:GetNativeClassName() or "",
    self.is_custom and 1 or 0,
    self:GetNativeClassName() or "")
end

function CustomClassName:SendDataTo(target)
  if not SendAddonMessage or not target or target == "" then
    return
  end

  local payload = self:BuildPayload()
  if payload then
    SendAddonMessage(self.prefix, payload, "WHISPER", target)
  end
end

function CustomClassName:GetUnitName(unit)
  if not unit or not UnitIsPlayer or not UnitIsPlayer(unit) then
    return nil
  end

  local name, realm = UnitName(unit)
  if not name then
    return nil
  end

  if realm and realm ~= "" then
    return name .. "-" .. realm
  end

  return name
end

function CustomClassName:RequestUnitData(unit)
  if not SendAddonMessage then
    return
  end

  local name = self:GetUnitName(unit)
  if not name then
    return
  end

  if UnitIsUnit and UnitIsUnit(unit, "player") then
    self:RequestData()
    return
  end

  local now = GetTime and GetTime() or 0
  if self.pending_requests[name] and now - self.pending_requests[name] < 5 then
    return
  end

  self.pending_requests[name] = now
  SendAddonMessage(self.prefix, "request", "WHISPER", name)
end

function CustomClassName:RegisterPrefix()
  if self.prefix_registered or not RegisterAddonMessagePrefix then
    return
  end

  if RegisterAddonMessagePrefix(self.prefix) then
    self.prefix_registered = true
  end
end

function CustomClassName:OnAddonMessage(prefix, message, channel, sender)
  if prefix ~= self.prefix then
    return
  end

  local player_name = UnitName("player")
  if message == "request" or message == "refresh" then
    if sender and sender ~= "" and sender ~= player_name then
      self:SendDataTo(sender)
    end
    return
  end

  local target, payload = string.match(message or "", "^([^|]+)|(.+)$")

  self:ParsePayload(payload or message, target or sender)
  self:RefreshCharacterPanel()
  if GameTooltip and GameTooltip:IsShown() then
    self:UpdateTooltip(GameTooltip)
  end
end

function CustomClassName:ParsePayload(payload, owner)
  local parsed = {}
  for key, value in string.gmatch(payload or "", "([^=;]+)=([^;]+)") do
    key = string.lower(key)
    if key == "name" then
      parsed.display_name = value
    elseif key == "custom" then
      parsed.is_custom = value == "1"
    elseif key == "native" then
      parsed.native_class_name = value
    end
  end

  local player_name = UnitName("player")
  if not owner or owner == "" or owner == player_name then
    self.display_name = parsed.display_name or self.display_name
    self.is_custom = parsed.is_custom or false
    self.native_class_name = parsed.native_class_name or self.native_class_name
    owner = player_name
  end

  if owner and owner ~= "" and parsed.display_name and parsed.display_name ~= "" then
    self.players[owner] = {
      display_name = parsed.display_name,
      is_custom = parsed.is_custom,
      native_class_name = parsed.native_class_name,
    }
  end
end

function CustomClassName:GetDisplayName(unit)
  if unit and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
    local name = self:GetUnitName(unit)
    local data = name and self.players[name]
    if data and data.display_name and data.display_name ~= "" then
      return data.display_name
    end

    local class_name = UnitClass(unit)
    return class_name
  end

  if self.display_name and self.display_name ~= "" then
    return self.display_name
  end

  local class_name = UnitClass(unit or "player")
  return class_name
end

function CustomClassName:GetNativeClassName(unit)
  if unit and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
    local name = self:GetUnitName(unit)
    local data = name and self.players[name]
    if data and data.native_class_name and data.native_class_name ~= "" then
      return data.native_class_name
    end

    local class_name = UnitClass(unit)
    return class_name
  end

  if self.native_class_name and self.native_class_name ~= "" then
    return self.native_class_name
  end

  local class_name = UnitClass("player")
  self.native_class_name = class_name
  return class_name
end

function CustomClassName:EscapePattern(text)
  return string.gsub(text or "", "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

function CustomClassName:ReplaceClassName(text, unit)
  if not text or text == "" then
    return text
  end

  local display_name = self:GetDisplayName(unit)
  local native_class = self:GetNativeClassName(unit)
  if not display_name or display_name == "" or not native_class or native_class == "" then
    return text
  end

  if string.find(text, self:EscapePattern(display_name)) then
    return text
  end

  if (not unit or (UnitIsUnit and UnitIsUnit(unit, "player"))) and self.last_applied_name and self.last_applied_name ~= "" and self.last_applied_name ~= display_name then
    local replaced, count = string.gsub(text, self:EscapePattern(self.last_applied_name), function()
      return display_name
    end, 1)
    if count and count > 0 then
      return replaced
    end
  end

  local replaced, count = string.gsub(text, self:EscapePattern(native_class), function()
    return display_name
  end, 1)
  if count and count > 0 then
    return replaced
  end

  return text
end

function CustomClassName:ReplaceFontStringText(font_string, unit)
  if not font_string or not font_string.GetText or not font_string.SetText then
    return false
  end

  local text = font_string:GetText()
  local replacement = self:ReplaceClassName(text, unit)
  if replacement and replacement ~= text then
    font_string:SetText(replacement)
    return true
  end

  return false
end

function CustomClassName:StripTextCodes(text)
  text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  return text
end

function CustomClassName:ClearDuplicateDisplayLine(font_string, unit)
  if not font_string or not font_string.GetText or not font_string.SetText then
    return false
  end

  local display_name = self:GetDisplayName(unit)
  local text = font_string:GetText()
  if not display_name or display_name == "" or not text or text == "" then
    return false
  end

  if self:StripTextCodes(text) == display_name then
    font_string:SetText("")
    font_string:Hide()
    return true
  end

  return false
end

function CustomClassName:HideAdditiveCharacterPanelLabel()
  local label = _G.ChumbaddonCustomClassNameText
  if label then
    label:SetText("")
    label:Hide()
  end
end

function CustomClassName:InstallCharacterPanelHooks()
  if self.character_panel_hooked then
    return
  end

  local installed = false
  if PaperDollFrame and PaperDollFrame.HookScript then
    PaperDollFrame:HookScript("OnShow", function()
      self:RefreshCharacterPanel()
    end)
    installed = true
  end

  if hooksecurefunc and _G.PaperDollFrame_SetLevel then
    hooksecurefunc("PaperDollFrame_SetLevel", function()
      self:RefreshCharacterPanel()
    end)
    installed = true
  end

  self.character_panel_hooked = installed
end

function CustomClassName:RefreshCharacterPanel()
  self:HideAdditiveCharacterPanelLabel()
  self:ReplaceFontStringText(_G.CharacterLevelText)
  self:ReplaceFontStringText(_G.CharacterRaceText)
  self.last_applied_name = self:GetDisplayName()
end

function CustomClassName:InstallTooltipHook()
  if self.tooltip_hooked or not GameTooltip then
    return
  end

  GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    self:UpdateTooltip(tooltip)
  end)
  self.tooltip_hooked = true
end

function CustomClassName:UpdateTooltip(tooltip)
  if not tooltip or not tooltip.GetUnit then
    return
  end

  local _, unit = tooltip:GetUnit()
  if not unit or not UnitIsPlayer or not UnitIsPlayer(unit) then
    return
  end

  self:RequestUnitData(unit)

  local display_name = self:GetDisplayName(unit)
  if not display_name or display_name == "" then
    return
  end

  local changed = false
  local tooltip_name = tooltip:GetName()
  local line_count = tooltip.NumLines and tooltip:NumLines() or 0
  for index = 2, line_count do
    local line = _G[tooltip_name .. "TextLeft" .. index]
    if self:ClearDuplicateDisplayLine(line, unit) then
      changed = true
    elseif self:ReplaceFontStringText(line, unit) then
      changed = true
    end

    local right_line = _G[tooltip_name .. "TextRight" .. index]
    if self:ClearDuplicateDisplayLine(right_line, unit) then
      changed = true
    elseif self:ReplaceFontStringText(right_line, unit) then
      changed = true
    end
  end

  if changed then
    tooltip:Show()
  end
end

function CustomClassName:ReportError(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s %s", self.debug_prefix, tostring(message)))
  else
    print(string.format("%s %s", self.debug_prefix, tostring(message)))
  end
end
