local addonName = ...

local KOTS = _G.KeepersOfTheStorm or {}
_G.KeepersOfTheStorm = KOTS
KOTS.Prefix = "KOTS"

KOTS.BossEntries = {
  [910000] = true, -- Protector of the Lake
  [910030] = true, -- Tuffscale
  [910031] = true, -- Churrlugggg
  [910032] = true, -- Murbean
  [910033] = true, -- Funnyfish
  [910034] = true, -- Glugglug
  [910040] = true, -- Smalls
  [910041] = true, -- Biggie
  [910043] = true, -- Shiggie
  [910044] = true, -- Jiggie
  [910045] = true, -- Liggie
  [910046] = true, -- Kiggie
  [910047] = true, -- Diggie
  [910050] = true, -- Murlaga
}

KOTS.BossNames = {
  ["Protector of the Lake"] = true,
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
}

local function creatureEntryFromGuid(guid)
  if not guid then
    return nil
  end

  local modernEntry = string.match(guid, "^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if modernEntry then
    return tonumber(modernEntry)
  end

  -- Wrath 3.3.5 GUIDs are usually hex strings such as 0xF13000DE2CE00001.
  -- The creature entry is stored in the six hex digits starting at position 7.
  if string.sub(guid, 1, 2) == "0x" and string.len(guid) >= 12 then
    return tonumber(string.sub(guid, 7, 12), 16)
  end

  return nil
end

function KOTS:IsBossUnit(unit)
  if not unit or not UnitExists(unit) then
    return false
  end

  local entry = creatureEntryFromGuid(UnitGUID(unit))
  if entry and self.BossEntries[entry] then
    return true
  end

  local name = UnitName(unit)
  return name and self.BossNames[name] or false
end

local function setLevelText(frameName, unit)
  if not KOTS:IsBossUnit(unit) then
    return
  end

  local levelText = _G[frameName .. "TextureFrameLevelText"]
  if levelText then
    levelText:SetText("??")
    levelText:Show()
  end
end

local function updateUnitFrames()
  setLevelText("TargetFrame", "target")
  setLevelText("FocusFrame", "focus")
end

function KOTS:ShowCenterMessage(message)
  if not message or message == "" then
    return
  end

  if RaidNotice_AddMessage and RaidWarningFrame then
    local info = ChatTypeInfo and ChatTypeInfo["RAID_WARNING"]
    RaidNotice_AddMessage(RaidWarningFrame, message, info or { r = 1, g = 0.82, b = 0 })
    return
  end

  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(message, 1, 0.82, 0, 1)
  end
end

local function registerAddonPrefix()
  if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(KOTS.Prefix)
  end
end

local function patchTooltipLevelLine(tooltip)
  local _, unit = tooltip:GetUnit()
  local name = unit and UnitName(unit) or _G[tooltip:GetName() .. "TextLeft1"] and _G[tooltip:GetName() .. "TextLeft1"]:GetText()

  if unit and not KOTS:IsBossUnit(unit) then
    return
  end

  if not unit and (not name or not KOTS.BossNames[name]) then
    return
  end

  for lineIndex = 2, tooltip:NumLines() do
    local line = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
    local text = line and line:GetText()
    if text and string.match(text, "^Level%s+%d+") then
      line:SetText(string.gsub(text, "^Level%s+%d+", "Level ??"))
      return
    end
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(_, event, arg1, arg2)
  if event == "ADDON_LOADED" and arg1 == addonName then
    registerAddonPrefix()

    if GameTooltip then
      GameTooltip:HookScript("OnTooltipSetUnit", patchTooltipLevelLine)
    end

    if type(TargetFrame_Update) == "function" then
      hooksecurefunc("TargetFrame_Update", updateUnitFrames)
    end

    if type(TargetFrame_CheckClassification) == "function" then
      hooksecurefunc("TargetFrame_CheckClassification", updateUnitFrames)
    end

    if type(FocusFrame_Update) == "function" then
      hooksecurefunc("FocusFrame_Update", updateUnitFrames)
    end
  elseif event == "PLAYER_LOGIN" then
    registerAddonPrefix()
    DEFAULT_CHAT_FRAME:AddMessage("[KeepersOfTheStorm] loaded")
    updateUnitFrames()
  elseif event == "CHAT_MSG_ADDON" then
    if arg1 == KOTS.Prefix and type(arg2) == "string" then
      local command, payload = string.match(arg2, "^([^|]+)|(.+)$")
      if command == "center" then
        KOTS:ShowCenterMessage(payload)
      end
    end
  else
    updateUnitFrames()
  end
end)

SLASH_KEEPERSOFTHESTORM1 = "/kots"
SlashCmdList["KEEPERSOFTHESTORM"] = function()
  local targetStatus = KOTS:IsBossUnit("target") and "yes" or "no"
  DEFAULT_CHAT_FRAME:AddMessage("[KeepersOfTheStorm] target boss UI patch: " .. targetStatus)
  updateUnitFrames()
end
