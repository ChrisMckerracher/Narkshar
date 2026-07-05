local addon_name = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

local function safe_invoke(label, fn)
  local ok, err = pcall(fn)
  if not ok then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(string.format("[Chumbaddon] %s failed: %s", label, tostring(err)))
    else
      print(string.format("[Chumbaddon] %s failed: %s", label, tostring(err)))
    end
  end
end

loader:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addon_name then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("[Chumbaddon] AddOn files loaded")
    else
      print("[Chumbaddon] AddOn files loaded")
    end

    if BareNecessities and BareNecessities.new then
      safe_invoke("BareNecessities", function()
        BareNecessities:new():register()
      end)
    else
      safe_invoke("BareNecessities missing", function()
        error("BareNecessities table not found; file may not be loading")
      end)
    end

    if SpellRunes and SpellRunes.new then
      safe_invoke("SpellRunes", function()
        SpellRunes:new():register()
      end)
    else
      safe_invoke("SpellRunes missing", function()
        error("SpellRunes table not found; file may not be loading")
      end)
    end

    if SubclassSpellbook and SubclassSpellbook.new then
      safe_invoke("SubclassSpellbook", function()
        SubclassSpellbook:new():register()
      end)
    else
      safe_invoke("SubclassSpellbook missing", function()
        error("SubclassSpellbook table not found; file may not be loading")
      end)
    end

    if SubclassPicker and SubclassPicker.new then
      safe_invoke("SubclassPicker", function()
        SubclassPicker:new():register()
      end)
    else
      safe_invoke("SubclassPicker missing", function()
        error("SubclassPicker table not found; file may not be loading")
      end)
    end

    if ComboPoints and ComboPoints.new then
      safe_invoke("ComboPoints", function()
        ComboPoints:new():register()
      end)
    else
      safe_invoke("ComboPoints missing", function()
        error("ComboPoints table not found; file may not be loading")
      end)
    end

    if SubclassTalents and SubclassTalents.new then
      safe_invoke("SubclassTalents", function()
        SubclassTalents:new():register()
      end)
    else
      safe_invoke("SubclassTalents missing", function()
        error("SubclassTalents table not found; file may not be loading")
      end)
    end

    if CustomClassName and CustomClassName.new then
      safe_invoke("CustomClassName", function()
        CustomClassName:new():register()
      end)
    else
      safe_invoke("CustomClassName missing", function()
        error("CustomClassName table not found; file may not be loading")
      end)
    end

  elseif event == "PLAYER_LOGIN" then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("[Chumbaddon] Readyz for tinkering!")
    else
      print("[Chumbaddon] Ready for tinkering!")
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("[Chumbaddon] Systems coming online...")
    else
      print("[Chumbaddon] Systems coming online...")
    end
  end
end)
