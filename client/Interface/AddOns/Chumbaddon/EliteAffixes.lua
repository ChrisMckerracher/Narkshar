-- EliteAffixes: target-frame pseudo buffs for server-reported elite affixes.
--
-- The server owns affix selection and sends only player-facing categories. This
-- module displays those categories as cosmetic target buffs without exposing
-- concrete spell IDs or implementation details.

EliteAffixes = {}
EliteAffixes.__index = EliteAffixes

local unpack = unpack or table.unpack

function EliteAffixes:new()
  local o = setmetatable({}, self)
  o.prefix = "ELTAFFIX"
  o.request_seq = 0
  o.active_seq = 0
  o.last_request_at = 0
  o.request_throttle = 0.4
  o.pending_request = false
  o.categories = {}
  o.buttons = {}
  o.category_order = { "I", "E", "T", "C" }
  o.category_info = {
    I = {
      name = "The Inspiring",
      icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    },
    E = {
      name = "The Enraging",
      icon = "Interface\\Icons\\Ability_Druid_ChallangingRoar",
    },
    T = {
      name = "The Tanking",
      icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
    },
    C = {
      name = "The Conjuring",
      icon = "Interface\\Icons\\Spell_Nature_ForceOfNature",
    },
  }
  o.category_aliases = {
    i = "I",
    inspiring = "I",
    theinspiring = "I",
    ["the inspiring"] = "I",
    e = "E",
    enraging = "E",
    theenraging = "E",
    ["the enraging"] = "E",
    t = "T",
    tanking = "T",
    thetanking = "T",
    ["the tanking"] = "T",
    c = "C",
    conjuring = "C",
    theconjuring = "C",
    ["the conjuring"] = "C",
  }
  return o
end

function EliteAffixes:register()
  if self.frame then
    return
  end

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:SafelyHandleEvent(event, ...)
  end)
  self.frame:SetScript("OnUpdate", function()
    self:FlushPendingRequest()
  end)

  if hooksecurefunc and TargetFrame_Update then
    hooksecurefunc("TargetFrame_Update", function()
      self:UpdateDisplay()
    end)
  end
end

function EliteAffixes:SafelyHandleEvent(event, ...)
  local args = { ... }
  local ok, err = xpcall(function()
    self:OnEvent(event, unpack(args))
  end, function(message)
    return string.format("%s\n%s", tostring(message), debugstack and debugstack() or "")
  end)

  if not ok and err then
    self:ReportError(err)
  end
end

function EliteAffixes:ReportError(err)
  local message = string.format("[Chumbaddon] EliteAffixes failed: %s", tostring(err))
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(message)
  else
    print(message)
  end
end

function EliteAffixes:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    self:RegisterPrefix()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" then
    self:ClearDisplay()
    self:RequestTargetAffixes()
  elseif event == "CHAT_MSG_ADDON" then
    self:OnAddonMessage(...)
  end
end

function EliteAffixes:RegisterPrefix()
  if self.prefix_registered or not RegisterAddonMessagePrefix then
    return
  end

  if RegisterAddonMessagePrefix(self.prefix) then
    self.prefix_registered = true
  end
end

function EliteAffixes:ClearDisplay()
  self.categories = {}
  self.request_seq = self.request_seq + 1
  self.active_seq = self.request_seq
  self.target_guid = UnitGUID and UnitGUID("target") or nil
  self.target_guid_low = self:GuidLow(self.target_guid)
  self:UpdateDisplay()
end

function EliteAffixes:RequestTargetAffixes()
  if not SendAddonMessage or not UnitExists or not UnitExists("target") then
    self.pending_request = false
    return
  end

  local player_name = UnitName and UnitName("player") or nil
  if not player_name or player_name == "" then
    self.pending_request = false
    return
  end

  local now = GetTime and GetTime() or 0
  if now - (self.last_request_at or 0) < self.request_throttle then
    self.pending_request = true
    return
  end

  self:SendRequest()
end

function EliteAffixes:FlushPendingRequest()
  if not self.pending_request then
    return
  end

  local now = GetTime and GetTime() or 0
  if now - (self.last_request_at or 0) < self.request_throttle then
    return
  end

  self.pending_request = false
  self:SendRequest()
end

function EliteAffixes:SendRequest()
  if not SendAddonMessage or not UnitExists or not UnitExists("target") then
    return
  end

  local player_name = UnitName and UnitName("player") or nil
  if not player_name or player_name == "" then
    return
  end

  self.last_request_at = GetTime and GetTime() or 0
  SendAddonMessage(self.prefix, string.format("refresh;s=%d;seq=%d", self.active_seq, self.active_seq), "WHISPER", player_name)
end

function EliteAffixes:OnAddonMessage(prefix, message)
  if prefix ~= self.prefix then
    return
  end

  local seq, guid_low, categories, clear = self:ParsePayload(message or "")
  if not seq or seq ~= self.active_seq then
    return
  end

  if guid_low and guid_low ~= 0 and self.target_guid_low and guid_low ~= self.target_guid_low then
    return
  end

  if clear then
    self.categories = {}
  else
    self.categories = categories or {}
  end

  self:UpdateDisplay()
end

function EliteAffixes:ParsePayload(payload)
  local fields = {}
  for key, value in string.gmatch(payload or "", "([^=;]+)=([^;]*)") do
    fields[string.lower(key)] = value
  end

  local seq = tonumber(fields.s or fields.seq or string.match(payload or "", "s[:=](%d+)") or string.match(payload or "", "seq[:=](%d+)"))
  local guid_low = tonumber(fields.g or fields.guid or fields.targetguid or "")
  local clear = fields.clear == "1" or fields.clear == "true"
  local cats = fields.a or fields.cats or fields.categories or fields.cat

  if not cats and not clear then
    cats = string.match(payload or "", "^%s*([IECTiect][IECTiect,%s]*)%s*$")
  end

  local parsed = self:ParseCategories(cats)

  return seq, guid_low, parsed, clear
end

function EliteAffixes:ParseCategories(cats)
  local parsed = {}
  if not cats or cats == "" then
    return parsed
  end

  if string.find(cats, ",") then
    for token in string.gmatch(cats .. ",", "%s*([^,]+)%s*,") do
      local key = self:NormalizeCategoryToken(token)
      if key then
        parsed[key] = true
      end
    end
    return parsed
  end

  local compact = string.gsub(cats, "%s+", "")
  if string.find(compact, "^[IECTiect]+$") then
    for index = 1, string.len(compact) do
      local key = self:NormalizeCategoryToken(string.sub(compact, index, index))
      if key then
        parsed[key] = true
      end
    end
    return parsed
  end

  local key = self:NormalizeCategoryToken(cats)
  if key then
    parsed[key] = true
  end

  return parsed
end

function EliteAffixes:GuidLow(guid)
  if not guid then
    return nil
  end

  local low = string.match(guid, "%-(%d+)$")
  if low then
    return tonumber(low)
  end

  if string.sub(guid, 1, 2) == "0x" and string.len(guid) >= 18 then
    return tonumber(string.sub(guid, 13, 18), 16)
  end

  return nil
end

function EliteAffixes:NormalizeCategoryToken(token)
  token = string.lower(token or "")
  token = string.gsub(token, "^%s+", "")
  token = string.gsub(token, "%s+$", "")
  token = string.gsub(token, "%.", "")
  if token == "" then
    return nil
  end

  local compact = string.gsub(token, "%s+", "")
  return self.category_aliases[token] or self.category_aliases[compact]
end

function EliteAffixes:GetActiveCategories()
  local active = {}
  for _, key in ipairs(self.category_order) do
    if self.categories[key] and self.category_info[key] then
      table.insert(active, key)
    end
  end
  return active
end

function EliteAffixes:CreateButton(index)
  local parent = TargetFrame or UIParent
  local button = CreateFrame("Button", "ChumbaddonEliteAffixButton" .. index, parent)
  button:SetWidth(26)
  button:SetHeight(26)
  button:EnableMouse(true)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
  button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetAllPoints(button)
  button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

  button:SetScript("OnEnter", function(frame)
    self:ShowTooltip(frame)
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  self.buttons[index] = button
  return button
end

function EliteAffixes:AnchorButton(button, index, active_count)
  button:ClearAllPoints()
  local spacing = 5
  local size = 26
  local offset = (index - 1) * (size + spacing)
  local level_text = _G and _G.TargetFrameTextureFrameLevelText

  if TargetFrame and TargetFrame.GetFrameLevel and button.SetFrameLevel then
    button:SetFrameLevel(TargetFrame:GetFrameLevel() + 20)
  end

  if level_text then
    button:SetPoint("BOTTOMLEFT", level_text, "TOPLEFT", -5 + offset, 0)
  elseif TargetFrameHealthBar then
    button:SetPoint("BOTTOMLEFT", TargetFrameHealthBar, "TOPLEFT", 16 + offset, 28)
  elseif TargetFrame then
    button:SetPoint("BOTTOMLEFT", TargetFrame, "TOPLEFT", 60 + offset, -6)
  else
    button:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

function EliteAffixes:UpdateDisplay()
  local active = self:GetActiveCategories()
  local should_show = TargetFrame and UnitExists and UnitExists("target") and #active > 0

  for index, key in ipairs(active) do
    local button = self.buttons[index] or self:CreateButton(index)
    local info = self.category_info[key]
    button.category_key = key
    button.category_name = info.name
    button.icon:SetTexture(info.icon)
    self:AnchorButton(button, index, #active)
    if should_show then
      button:Show()
    else
      button:Hide()
    end
  end

  for index = #active + 1, #self.buttons do
    self.buttons[index]:Hide()
  end
end

function EliteAffixes:ShowTooltip(button)
  if not GameTooltip or not button or not button.category_name then
    return
  end

  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:AddLine(button.category_name, 1, 1, 1)
  GameTooltip:AddLine("Elite Affix", 0.75, 0.75, 0.75)
  GameTooltip:Show()
end

local eliteAffixes = EliteAffixes:new()
eliteAffixes:register()
