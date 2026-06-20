DebugBar = {}
DebugBar.__index = DebugBar

function DebugBar:new()
  local o = setmetatable({}, self)
  o.frame = nil
  return o
end

function DebugBar:register()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "ChumbaddonDebugBar", UIParent)
  frame:SetFrameStrata("HIGH")
  frame:SetSize(220, 48)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetTexture(0, 0, 0, 0.65)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -6)
  title:SetText("Debug Bar")

  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  bar:SetStatusBarColor(0.28, 0.82, 0.42)
  bar:SetMinMaxValues(0, 100)
  bar:SetValue(75)
  bar:SetSize(180, 18)
  bar:SetPoint("TOP", title, "BOTTOM", 0, -8)

  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  text:SetText("75 / 100")

  self.bar = bar
  self.text = text
  self.frame = frame

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("[Chumbaddon] DebugBar deployed")
  else
    print("[Chumbaddon] DebugBar deployed")
  end
end
