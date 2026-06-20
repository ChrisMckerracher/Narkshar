-- BossLevels: show custom level-25 bosses as boss-level ("??") client-side.
--
-- The bosses are mechanically level 25 server-side; this module repaints
-- their level/classification as Level ?? Boss in tooltips and with the boss
-- skull on stock target/focus frames. Addons that call UnitLevel directly
-- will still see the server's real level.

BossLevels = {}
BossLevels.__index = BossLevels

function BossLevels:new()
  local o = setmetatable({}, self)
  o.active = true
  o.version = "2026-06-14.2"
  o.bossIds = {
    [910000] = true, -- Protector of the Lake
    [910010] = true, -- The Idol
    [910030] = true, -- Tuffscale
    [910031] = true, -- Churrlugggg
    [910032] = true, -- Murbean
    [910033] = true, -- Funnyfish
    [910034] = true, -- Glugglug
    [910040] = true, -- Smalls
    [910041] = true, -- Biggie
    [910043] = true, -- Shiggie (Biggie clone)
    [910044] = true, -- Jiggie
    [910045] = true, -- Liggie
    [910046] = true, -- Kiggie
    [910047] = true, -- Diggie
    [910050] = true, -- Murlaga
    [910100] = true, -- Black Rider of Elwynn
    [910101] = true, -- Black Rider of Darkshore
    [910102] = true, -- Black Rider of Hillsbrad
    [910103] = true, -- Black Rider of Loch Modan
    [910104] = true, -- Black Rider of the Wetlands
    [910123] = true, -- Jake LaModda (Raging Bull)
  }
  o.bossNames = {
    ["Protector of the Lake"] = true,
    ["The Idol"] = true,
    ["Tuffscale"] = true,
    ["Churrlugggg"] = true,
    ["Murbean"] = true,
    ["Funnyfish"] = true,
    ["Glugglug"] = true,
    ["Smalls"] = true,
    ["Biggie"] = true,
    ["Shiggie"] = true,
    ["Jiggie"] = true,
    ["Liggie"] = true,
    ["Kiggie"] = true,
    ["Diggie"] = true,
    ["Murlaga"] = true,
    ["Black Rider of Elwynn"] = true,
    ["Black Rider of Darkshore"] = true,
    ["Black Rider of Hillsbrad"] = true,
    ["Black Rider of Loch Modan"] = true,
    ["Black Rider of the Wetlands"] = true,
    ["Jake LaModda"] = true,
  }
  return o
end

function BossLevels:entryFromGUID(guid)
  if not guid then
    return nil
  end

  local modernEntry = string.match(guid, "^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if modernEntry then
    return tonumber(modernEntry)
  end

  local modernVehicleEntry = string.match(guid, "^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if modernVehicleEntry then
    return tonumber(modernVehicleEntry)
  end

  -- 3.3.5 creature GUID: 0x F130 EEEEEE CCCCCC (entry = hex chars 7-12).
  if string.sub(guid, 1, 2) == "0x" and string.len(guid) >= 12 then
    return tonumber(string.sub(guid, 7, 12), 16)
  end

  return nil
end

function BossLevels:isBossUnit(unit)
  if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then
    return false
  end
  local entry = self:entryFromGUID(UnitGUID(unit))
  if entry and self.bossIds[entry] then
    return true
  end

  local name = UnitName(unit)
  if name and self.bossNames[name] then
    return true
  end

  return false
end

-- ------------------------------------------------------------- target frame
function BossLevels:repaintFrame(frame)
  if not frame then
    return
  end
  local unit = frame.unit or (frame == TargetFrame and "target") or (frame == FocusFrame and "focus")
  if not unit or not self:isBossUnit(unit) then
    return
  end
  local name = frame:GetName()
  local levelText = _G[name .. "TextureFrameLevelText"]
  local skull = _G[name .. "TextureFrameHighLevelTexture"]
  if levelText then
    levelText:SetText("??")
    levelText:Show()
  end
  if skull then
    skull:Show()
  end
end

function BossLevels:repaintUnitFrames()
  if TargetFrame then
    self:repaintFrame(TargetFrame)
  end
  if FocusFrame then
    self:repaintFrame(FocusFrame)
  end
end

function BossLevels:forceRefresh(seconds)
  self.refreshUntil = (GetTime and GetTime() or 0) + (seconds or 2)
end

-- ----------------------------------------------------------------- tooltip
function BossLevels:isBossTooltip(tooltip, unit)
  if unit and self:isBossUnit(unit) then
    return true
  end

  local firstLine = tooltip and tooltip.GetName and _G[tooltip:GetName() .. "TextLeft1"]
  local name = firstLine and firstLine:GetText()
  return name and self.bossNames[name] or false
end

function BossLevels:bossLevelLine(text)
  local levelLabel = "Level"
  local bossLabel = BOSS or "Boss"
  local localizedLevel = LEVEL or ""
  local localizedPrefix = string.match(localizedLevel, "^([^%%]+)")
  if localizedPrefix then
    localizedPrefix = string.gsub(localizedPrefix, "%s+$", "")
    if localizedPrefix ~= "" then
      levelLabel = localizedPrefix
    end
  end

  local startIndex, endIndex = string.find(text, levelLabel, 1, true)
  if not startIndex then
    return nil
  end

  local suffix = string.sub(text, endIndex + 1)
  if not string.find(suffix, "%d+") and not string.find(suffix, "%?%?") then
    return nil
  end

  suffix = string.gsub(suffix, "^%s*%?%?%s*", "", 1)
  suffix = string.gsub(suffix, "^%s*%d+%s*", "", 1)
  suffix = string.gsub(suffix, "^[Rr]are%s+[Ee]lite%s*", "", 1)
  suffix = string.gsub(suffix, "^[Ee]lite%s*", "", 1)
  suffix = string.gsub(suffix, "^[Rr]are%s*", "", 1)
  suffix = string.gsub(suffix, "^[Bb]oss%s*", "", 1)

  if suffix ~= "" then
    return string.sub(text, 1, endIndex) .. " ?? " .. bossLabel .. " " .. suffix
  end
  return string.sub(text, 1, endIndex) .. " ?? " .. bossLabel
end

function BossLevels:repaintTooltip(tooltip)
  local _, unit = tooltip:GetUnit()
  if not self:isBossTooltip(tooltip, unit) then
    return
  end
  local tooltipName = tooltip:GetName()
  for i = 2, tooltip:NumLines() do
    local line = _G[tooltipName .. "TextLeft" .. i]
    local text = line and line:GetText()
    local replacement = text and self:bossLevelLine(text)
    if replacement then
      line:SetText(replacement)
      tooltip:Show()
      break
    end
  end
end

function BossLevels:debugUnit(unit)
  local guid = unit and UnitGUID and UnitGUID(unit) or nil
  local entry = self:entryFromGUID(guid)
  local name = unit and UnitName and UnitName(unit) or nil
  return string.format(
    "version=%s unit=%s exists=%s player=%s name=%s guid=%s entry=%s idMatch=%s nameMatch=%s boss=%s",
    tostring(self.version),
    tostring(unit),
    tostring(unit and UnitExists and UnitExists(unit)),
    tostring(unit and UnitIsPlayer and UnitIsPlayer(unit)),
    tostring(name),
    tostring(guid),
    tostring(entry),
    tostring(entry and self.bossIds[entry] or false),
    tostring(name and self.bossNames[name] or false),
    tostring(self:isBossUnit(unit))
  )
end

function BossLevels:installSlashCommand()
  SLASH_CHUMBABOSS1 = "/chumbaboss"
  SlashCmdList["CHUMBABOSS"] = function()
    local message = "[Chumbaddon] BossLevels " .. self:debugUnit("target")
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(message)
    else
      print(message)
    end
    self:forceRefresh(5)
    self:repaintUnitFrames()
    if GameTooltip and GameTooltip:IsShown() then
      self:repaintTooltip(GameTooltip)
    end
  end
end

function BossLevels:register()
  if self.frame then
    return
  end

  self:installSlashCommand()

  if TargetFrame_CheckLevel then
    hooksecurefunc("TargetFrame_CheckLevel", function(frame)
      if self.active then
        self:repaintFrame(frame)
        self:forceRefresh(1)
      end
    end)
  end
  if TargetFrame_Update then
    hooksecurefunc("TargetFrame_Update", function(frame)
      if self.active then
        self:repaintFrame(frame)
        self:forceRefresh(1)
      end
    end)
  end
  if TargetFrame_CheckClassification then
    hooksecurefunc("TargetFrame_CheckClassification", function()
      if self.active then
        self:repaintUnitFrames()
      end
    end)
  end
  if FocusFrame_Update then
    hooksecurefunc("FocusFrame_Update", function()
      if self.active then
        self:repaintUnitFrames()
      end
    end)
  end

  GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    if self.active then
      self:repaintTooltip(tooltip)
      self:forceRefresh(1)
    end
  end)

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  self.frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
  self.frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  self.frame:SetScript("OnEvent", function()
    if not self.active then
      return
    end
    self:forceRefresh(2)
    self:repaintUnitFrames()
  end)
  self.frame:SetScript("OnUpdate", function()
    if not self.active or not self.refreshUntil then
      return
    end

    if (GetTime and GetTime() or 0) > self.refreshUntil then
      self.refreshUntil = nil
      return
    end

    self:repaintUnitFrames()
    if GameTooltip and GameTooltip:IsShown() then
      self:repaintTooltip(GameTooltip)
    end
  end)
end

local bossLevels = BossLevels:new()
bossLevels:register()
