-- BoxerAuras: cosmetic aura tooltip names for Jake LaModda.
--
-- Jake's Uppercut uses Destructive Poison server-side for its damage-taken
-- modifier. During the Jake fight, show the player-facing mechanic name while
-- leaving the real aura icon, spell ID, stacks, and behavior untouched.

BoxerAuras = {}
BoxerAuras.__index = BoxerAuras

function BoxerAuras:new()
  local o = setmetatable({}, self)
  o.prefix = "BXAURA"
  o.server_active = false
  o.boss_name = "Jake LaModda"
  o.source_name = "Destructive Poison"
  o.display_name = "Bruised Body"
  return o
end

function BoxerAuras:IsJakeUnit(unit)
  if not unit or not UnitExists or not UnitExists(unit) then
    return false
  end
  return UnitName(unit) == self.boss_name
end

function BoxerAuras:IsJakeVisible()
  if self:IsJakeUnit("target") or self:IsJakeUnit("focus") then
    return true
  end
  for i = 1, 4 do
    if self:IsJakeUnit("party" .. i .. "target") then
      return true
    end
  end
  return false
end

function BoxerAuras:IsActive()
  if not UnitAffectingCombat or not UnitAffectingCombat("player") then
    return false
  end
  return self.server_active or self:IsJakeVisible()
end

function BoxerAuras:RewriteTooltip(tooltip)
  if not self:IsActive() or not tooltip then
    return
  end

  local name = tooltip:GetName()
  if not name then
    return
  end

  local title = _G[name .. "TextLeft1"]
  if not title or title:GetText() ~= self.source_name then
    return
  end

  local r, g, b, a = title:GetTextColor()
  title:SetText(self.display_name)
  title:SetTextColor(r or 1, g or 1, b or 1, a or 1)
  tooltip:Show()
end

function BoxerAuras:HookTooltip(tooltip)
  if not tooltip then
    return
  end

  local function rewrite(tt)
    self:RewriteTooltip(tt or tooltip)
  end

  if hooksecurefunc then
    if tooltip.SetUnitAura then
      hooksecurefunc(tooltip, "SetUnitAura", rewrite)
    end
    if tooltip.SetUnitBuff then
      hooksecurefunc(tooltip, "SetUnitBuff", rewrite)
    end
    if tooltip.SetUnitDebuff then
      hooksecurefunc(tooltip, "SetUnitDebuff", rewrite)
    end
  end
end

function BoxerAuras:OnChatMessageAddon(prefix, message)
  if prefix ~= self.prefix then
    return
  end
  if message == "jake=1" then
    self.server_active = true
  elseif message == "jake=0" then
    self.server_active = false
  end
end

function BoxerAuras:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    if RegisterAddonMessagePrefix then
      RegisterAddonMessagePrefix(self.prefix)
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
    self.server_active = false
  elseif event == "CHAT_MSG_ADDON" then
    self:OnChatMessageAddon(...)
  end
end

function BoxerAuras:register()
  if self.frame then
    return
  end

  self:HookTooltip(GameTooltip)

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:OnEvent(event, ...)
  end)
end

local boxerAuras = BoxerAuras:new()
boxerAuras:register()
