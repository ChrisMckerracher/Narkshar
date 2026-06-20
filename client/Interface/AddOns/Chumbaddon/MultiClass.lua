-- MultiClass (Wrath 3.3.5a) — replace the PlayerFrame mana bar with three bars
-- 0=MANA, 1=RAGE, 3=ENERGY in 3.3.5
local PT = { MANA=0, RAGE=1, ENERGY=3 }
local PIXEL = "Interface\\Buttons\\WHITE8x8"

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_MANA")
f:RegisterEvent("UNIT_RAGE")
f:RegisterEvent("UNIT_ENERGY")
f:RegisterEvent("UNIT_DISPLAYPOWER")

-- Hide Blizzard's single mana bar (keep the frame art)
local function KillDefaultManaBar()
    if not PlayerFrameManaBar then return end
    if PlayerFrameManaBar:IsShown() then PlayerFrameManaBar:Hide() end
    -- Stop it from popping back
    PlayerFrameManaBar.Show = function() end
    if PlayerFrameManaBarText then PlayerFrameManaBarText:Hide(); PlayerFrameManaBarText.Show = function() end end
end

-- Create our triple bar container exactly where the original sat
local container
local manaBar, energyBar, rageBar

local function MakeStatusBar(parent, name, r, g, b, yOff, h)
    local bar = CreateFrame("StatusBar", name, parent)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:SetStatusBarColor(r, g, b)
    -- Full width, one-pixel insets to match Blizzard padding
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -yOff)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -yOff)
    bar:SetHeight(h)

    -- Background tint like Blizzard
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0, 0, 0, 0.35)

    -- Value text in the same family as PlayerFrame’s bars
    local txt = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    txt:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.text = txt

    return bar
end

local function EnsureBars()
    if container then return end

    local base = PlayerFrameManaBar
    if not base then return end

    -- Use Blizzard's actual bar height & width so it looks native
    local bh = base:GetHeight() or 12
    local totalH = (bh * 3) + 2  -- two 1px separators

    container = CreateFrame("Frame", "MultiClassContainer", PlayerFrame)
    container:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
    container:SetPoint("TOPRIGHT", base, "TOPRIGHT", 0, 0)
    container:SetHeight(totalH)
    container:SetFrameStrata(base:GetFrameStrata())
    container:SetFrameLevel(base:GetFrameLevel())

    -- Thin black lines between rows to mimic Blizzard strokes
    local sep1 = container:CreateTexture(nil, "OVERLAY")
    sep1:SetTexture(PIXEL); sep1:SetVertexColor(0,0,0,0.8)
    sep1:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(bh))
    sep1:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -(bh))
    sep1:SetHeight(1)

    local sep2 = container:CreateTexture(nil, "OVERLAY")
    sep2:SetTexture(PIXEL); sep2:SetVertexColor(0,0,0,0.8)
    sep2:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(bh*2+1))
    sep2:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -(bh*2+1))
    sep2:SetHeight(1)

    -- Bars (top→bottom) with Blizzard colors
    manaBar   = MakeStatusBar(container, "MultiClassMana",   0.00, 0.55, 1.00, 0,        bh)
    energyBar = MakeStatusBar(container, "MultiClassEnergy", 1.00, 0.95, 0.00, bh+1,    bh)
    rageBar   = MakeStatusBar(container, "MultiClassRage",   1.00, 0.10, 0.10, (bh*2)+2, bh)
end

local function setBar(bar, cur, max)
    max = max or 0
    if max <= 0 then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar.text:SetText("0 / 0")
    else
        bar:SetMinMaxValues(0, max)
        bar:SetValue(cur)
        bar.text:SetText(cur .. " / " .. max)
    end
end

local function UpdateAll()
    if not container then return end
    -- Old API: UnitMana(unit, powerType), UnitManaMax(unit, powerType)
    local mCur, mMax = UnitMana("player", PT.MANA)   or 0, UnitManaMax("player", PT.MANA)   or 0
    local rCur, rMax = UnitMana("player", PT.RAGE)   or 0, UnitManaMax("player", PT.RAGE)   or 0
    local eCur, eMax = UnitMana("player", PT.ENERGY) or 0, UnitManaMax("player", PT.ENERGY) or 0
    setBar(manaBar,   mCur, mMax)
    setBar(rageBar,   rCur, rMax)
    setBar(energyBar, eCur, eMax)
end

-- If the PlayerFrame reanchors (e.g., some UIs do), keep our container glued to it
hooksecurefunc(PlayerFrame, "SetPoint", function()
    if container then
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", PlayerFrameManaBar, "TOPLEFT", 0, 0)
        container:SetPoint("TOPRIGHT", PlayerFrameManaBar, "TOPRIGHT", 0, 0)
    end
end)

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        KillDefaultManaBar()
        EnsureBars()
        UpdateAll()
        return
    end
    if arg1 ~= "player" then return end
    UpdateAll()
end)
