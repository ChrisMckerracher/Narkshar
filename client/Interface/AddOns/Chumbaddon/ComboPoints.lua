ComboPoints = {}
ComboPoints.__index = ComboPoints

local CLASS_ROGUE = 4
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

function ComboPoints:new()
  local o = setmetatable({}, self)
  o.subclass_prefix = "SCSUB"
  o.bridge_prefix = "CHCP"
  o.native_class = 0
  o.subclass_class = 0
  o.bridge_points = nil
  o.bridge_target_guid = nil
  o.bridge_target_name = nil
  o.bridge_updated_at = nil
  o.bridge_ttl = 3
  o.bridge_seen = false
  return o
end

local function set_region_size(region, width, height)
  if region.SetSize then
    region:SetSize(width, height)
  else
    region:SetWidth(width)
    region:SetHeight(height)
  end
end

function ComboPoints:register()
  if self.frame then
    return
  end

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.frame:RegisterEvent("UNIT_COMBO_POINTS")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:OnEvent(event, ...)
  end)

  SLASH_CHUMBADDONCOMBOPOINTS1 = "/chcp"
  SlashCmdList.CHUMBADDONCOMBOPOINTS = function()
    self:PrintDebug()
  end

  if ComboFrame_Update then
    hooksecurefunc("ComboFrame_Update", function()
      self:Refresh()
    end)
  end
end

function ComboPoints:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:SetNativeClass()
    self:RegisterPrefix()
    self:RequestSubclass()
    self:ScheduleRefresh()
  elseif event == "CHAT_MSG_ADDON" then
    self:OnAddonMessage(...)
  elseif event == "UNIT_COMBO_POINTS" then
    self:Refresh()
  elseif event == "PLAYER_TARGET_CHANGED" then
    self:Refresh()
  elseif event == "PLAYER_REGEN_DISABLED" then
    self:StartPolling()
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:StopPolling()
    self:Refresh()
  end
end

function ComboPoints:SetNativeClass()
  local _, class_file = UnitClass("player")
  self.native_class = CLASS_FILE_TO_ID[class_file] or self.native_class or 0
end

function ComboPoints:RegisterPrefix()
  if self.prefix_registered or not RegisterAddonMessagePrefix then
    return
  end

  RegisterAddonMessagePrefix(self.subclass_prefix)
  RegisterAddonMessagePrefix(self.bridge_prefix)
  self.prefix_registered = true
end

function ComboPoints:RequestSubclass()
  if not SendAddonMessage then
    return
  end

  local player_name = UnitName("player")
  if player_name then
    SendAddonMessage(self.subclass_prefix, "refresh", "WHISPER", player_name)
  end
end

function ComboPoints:OnAddonMessage(prefix, message)
  local player_name = UnitName("player")
  local target, payload = string.match(message or "", "^([^|]+)|(.+)$")
  if target and player_name and target ~= player_name then
    return
  end

  if prefix == self.subclass_prefix then
    self:ParseSubclassPayload(payload or message)
  elseif prefix == self.bridge_prefix then
    self:ParseBridgePayload(payload or message)
  else
    return
  end

  self:Refresh()
end

function ComboPoints:ParsePairs(payload, handler)
  for key, value in string.gmatch(payload or "", "([^=;]+)=([^;]*)") do
    key = string.lower(key)
    handler(key, value)
  end
end

function ComboPoints:ParseSubclassPayload(payload)
  self:ParsePairs(payload, function(key, value)
    if key == "native" then
      self.native_class = tonumber(value) or self.native_class or 0
    elseif key == "class" then
      self.subclass_class = tonumber(value) or 0
    end
  end)

  if not self.native_class or self.native_class == 0 then
    self:SetNativeClass()
  end
end

function ComboPoints:ParseBridgePayload(payload)
  local points = nil
  local target_guid = nil
  local target_name = nil

  self:ParsePairs(payload, function(key, value)
    if key == "points" then
      points = tonumber(value) or 0
    elseif key == "target" then
      target_guid = tonumber(value) or 0
    elseif key == "targetname" then
      target_name = value or ""
    end
  end)

  if points == nil then
    return
  end

  self.bridge_points = math.max(0, math.min(5, points))
  self.bridge_target_guid = target_guid or 0
  self.bridge_target_name = target_name or ""
  self.bridge_updated_at = GetTime and GetTime() or 0
  self.bridge_seen = true
end

function ComboPoints:IsRogueEnabled()
  return tonumber(self.native_class) == CLASS_ROGUE or tonumber(self.subclass_class) == CLASS_ROGUE or self.bridge_seen
end

function ComboPoints:GetComboPointCount()
  local bridge_points = self:GetBridgeComboPointCount()
  if bridge_points ~= nil then
    return bridge_points
  end

  if not GetComboPoints then
    return 0
  end

  local ok, points = pcall(GetComboPoints, "player", "target")
  if ok and points then
    return tonumber(points) or 0
  end

  ok, points = pcall(GetComboPoints)
  if ok and points then
    return tonumber(points) or 0
  end

  return 0
end

function ComboPoints:IsBridgeFresh()
  if self.bridge_points == nil or self.bridge_updated_at == nil then
    return false
  end

  local now = GetTime and GetTime() or 0
  return now - self.bridge_updated_at <= self.bridge_ttl
end

function ComboPoints:BridgeTargetMatchesCurrentTarget()
  if (self.bridge_points or 0) <= 0 then
    return true
  end

  if not self.bridge_target_name or self.bridge_target_name == "" then
    return true
  end

  local target_name = UnitName("target")
  return target_name ~= nil and target_name == self.bridge_target_name
end

function ComboPoints:GetBridgeComboPointCount()
  if not self:IsBridgeFresh() then
    return nil
  end

  if not self:BridgeTargetMatchesCurrentTarget() then
    return 0
  end

  return tonumber(self.bridge_points) or 0
end

function ComboPoints:GetRawComboPoints()
  local with_target = "n/a"
  local without_target = "n/a"

  if GetComboPoints then
    local ok, points = pcall(GetComboPoints, "player", "target")
    if ok then
      with_target = tostring(points)
    end

    ok, points = pcall(GetComboPoints)
    if ok then
      without_target = tostring(points)
    end
  end

  return with_target, without_target
end

function ComboPoints:EnsureFallbackFrame()
  if self.fallback_frame then
    return self.fallback_frame
  end

  local parent = UIParent
  local frame = CreateFrame("Frame", "ChumbaddonComboPointFrame", parent)
  set_region_size(frame, 92, 18)
  frame:SetFrameStrata("MEDIUM")
  frame:SetFrameLevel(90)
  frame:EnableMouse(false)
  if TargetFrame then
    frame:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -42, -8)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  end
  frame:Hide()

  frame.points = {}
  for index = 1, 5 do
    local point = frame:CreateTexture("ChumbaddonComboPoint" .. index, "OVERLAY")
    set_region_size(point, 14, 18)
    point:SetTexture("Interface\\ComboFrame\\ComboPoint")
    point:SetTexCoord(0.5625, 1, 0, 1)
    point:SetVertexColor(1, 0.82, 0.15, 1)
    if index == 1 then
      point:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    else
      point:SetPoint("RIGHT", frame.points[index - 1], "LEFT", -4, 0)
    end
    point:Hide()
    frame.points[index] = point
  end

  self.fallback_frame = frame
  return frame
end

function ComboPoints:RefreshFallbackFrame(points)
  local frame = self:EnsureFallbackFrame()
  if points <= 0 then
    frame:Hide()
    return
  end

  frame:Show()
  for index = 1, 5 do
    local point = frame.points[index]
    if point then
      if index <= points then
        point:SetAlpha(1)
        point:Show()
      else
        point:Hide()
      end
    end
  end
end

function ComboPoints:RefreshNativeFrame(points)
  if not ComboFrame then
    return false
  end

  if points <= 0 then
    ComboFrame:Hide()
    return true
  end

  ComboFrame:SetAlpha(1)
  ComboFrame:Show()

  for index = 1, 5 do
    local point = _G["ComboPoint" .. index]
    if point then
      point:SetAlpha(1)
      if index <= points then
        point:Show()
      else
        point:Hide()
      end
    end

    local highlight = _G["ComboPoint" .. index .. "Highlight"]
    if highlight then
      highlight:SetAlpha(index <= points and 1 or 0)
    end

    local shine = _G["ComboPoint" .. index .. "Shine"]
    if shine then
      shine:SetAlpha(index <= points and 1 or 0)
    end
  end

  return true
end

function ComboPoints:Refresh()
  if not self:IsRogueEnabled() then
    return
  end

  local points = self:GetComboPointCount()
  self:RefreshNativeFrame(points)
  self:RefreshFallbackFrame(points)
end

function ComboPoints:HideDisplays()
  if ComboFrame then
    ComboFrame:Hide()
  end

  if self.fallback_frame then
    self.fallback_frame:Hide()
  end
end

function ComboPoints:ScheduleRefresh()
  if not self.frame then
    return
  end

  self.refresh_delay = 0.25
  self.frame:SetScript("OnUpdate", function(frame, elapsed)
    self.refresh_delay = (self.refresh_delay or 0) - elapsed
    if self.refresh_delay > 0 then
      return
    end
    frame:SetScript("OnUpdate", nil)
    self:Refresh()
  end)
end

function ComboPoints:StartPolling()
  if not self.frame then
    return
  end

  self.poll_elapsed = 0
  self.frame:SetScript("OnUpdate", function(_, elapsed)
    self.poll_elapsed = (self.poll_elapsed or 0) + elapsed
    if self.poll_elapsed < 0.1 then
      return
    end

    self.poll_elapsed = 0
    self:Refresh()
  end)
end

function ComboPoints:StopPolling()
  if self.frame then
    self.frame:SetScript("OnUpdate", nil)
  end
end

function ComboPoints:PrintDebug()
  local with_target, without_target = self:GetRawComboPoints()
  local target_name = UnitName("target") or "none"
  local message = string.format(
    "[Chumbaddon] combo rogue=%s native=%s subclass=%s target=%s cp(player,target)=%s cp()=%s bridge=%s/%s/%s seen=%s fresh=%s",
    tostring(self:IsRogueEnabled()),
    tostring(self.native_class),
    tostring(self.subclass_class),
    target_name,
    with_target,
    without_target,
    tostring(self.bridge_points),
    tostring(self.bridge_target_guid),
    tostring(self.bridge_target_name),
    tostring(self.bridge_seen),
    tostring(self:IsBridgeFresh())
  )

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(message)
  else
    print(message)
  end
end
