SubclassSpellbook = {}
SubclassSpellbook.__index = SubclassSpellbook

local unpack = unpack or table.unpack

local CLASS_NAMES = {
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

local DEFAULT_TABS = {
  [0] = "General",
  [1] = "Spec 1",
  [2] = "Spec 2",
  [3] = "Spec 3",
}

local CLASS_ICON_COORDS = {
  [1] = { 0, 0.25, 0, 0.25 },
  [2] = { 0, 0.25, 0.5, 0.75 },
  [3] = { 0, 0.25, 0.25, 0.5 },
  [4] = { 0.49609375, 0.7421875, 0, 0.25 },
  [5] = { 0.49609375, 0.7421875, 0.25, 0.5 },
  [7] = { 0.25, 0.49609375, 0.25, 0.5 },
  [8] = { 0.25, 0.49609375, 0, 0.25 },
  [9] = { 0.7421875, 0.98828125, 0.25, 0.5 },
  [11] = { 0.7421875, 0.98828125, 0, 0.25 },
}

local CLASS_ICON_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local SPELLS_PER_PAGE = 12
local NATIVE_TAB_COUNT = 12

local BANE_CAST_TIME_MODS = {
  [17788] = {
    default = -100,
    soul_fire = -400,
  },
  [17789] = {
    default = -200,
    soul_fire = -800,
  },
  [17790] = {
    default = -300,
    soul_fire = -1200,
  },
  [17791] = {
    default = -400,
    soul_fire = -1600,
  },
  [17792] = {
    default = -500,
    soul_fire = -2000,
  },
}

local BANE_DEFAULT_SPELLS = {
  [348] = true, [686] = true, [695] = true, [705] = true, [707] = true,
  [1088] = true, [1094] = true, [1106] = true, [2941] = true, [7641] = true,
  [11659] = true, [11660] = true, [11661] = true, [11665] = true, [11667] = true,
  [11668] = true, [25307] = true, [25309] = true, [27209] = true, [27215] = true,
  [47808] = true, [47809] = true, [47810] = true, [47811] = true,
  [50796] = true, [59170] = true, [59171] = true, [59172] = true,
}

local BANE_SOUL_FIRE_SPELLS = {
  [6353] = true, [17924] = true, [27211] = true, [30545] = true,
  [47824] = true, [47825] = true,
}

function SubclassSpellbook:new()
  local o = setmetatable({}, self)
  o.prefix = "SCBOOK"
  o.debug_prefix = "[SubclassSpellbook]"
  o.subclass_class = nil
  o.spell_tabs = {}
  o.spells = {}
  o.known_spells = {}
  o.known_spell_names = {}
  o.active_tab = nil
  o.active_page = 1
  o.subclass_mode = false
  o.pending_refresh = false
  o.class_buttons = {}
  o.original_tab_textures = {}
  o.original_tab_scripts = {}
  o.original_spell_button_scripts = {}
  o.original_prev_onclick = nil
  o.original_next_onclick = nil
  o.tab_click_hooked = {}
  return o
end

function SubclassSpellbook:register()
  if self.frame then
    return
  end

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("SPELLS_CHANGED")
  self.frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:SafelyHandleEvent(event, ...)
  end)

  self:InstallGlobalShim()
end

function SubclassSpellbook:InstallGlobalShim()
  _G.Chumbaddon_SubclassSpellbookSetData = function(class_id, spells, tabs)
    self:SetData({
      subclass_class = tonumber(class_id),
      spells = spells or {},
      tabs = tabs or {},
    })
  end
end

function SubclassSpellbook:SafelyHandleEvent(event, ...)
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

function SubclassSpellbook:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:RegisterPrefix()
    self:EnsureSpellbookUi()
    self:CollectKnownSpells()
    self:RequestData()
    self:Refresh()
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
    self:CollectKnownSpells()
    self:RequestData()
    self:Refresh()
  elseif event == "CHAT_MSG_ADDON" then
    self:OnAddonMessage(...)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if self.pending_refresh then
      self.pending_refresh = false
      self:Refresh()
    end
  end
end

function SubclassSpellbook:RegisterPrefix()
  if not RegisterAddonMessagePrefix then
    return
  end

  self.registered_prefixes = self.registered_prefixes or {}
  for _, prefix in ipairs({ self.prefix, "SCSUB", "SCTAL" }) do
    if not self.registered_prefixes[prefix] then
      RegisterAddonMessagePrefix(prefix)
      self.registered_prefixes[prefix] = true
    end
  end
end

function SubclassSpellbook:RequestData()
  if not SendAddonMessage then
    return
  end

  local player_name = UnitName("player")
  if player_name then
    self:RequestSpellbookData(player_name)
    SendAddonMessage("SCSUB", "refresh", "WHISPER", player_name)
  end
end

function SubclassSpellbook:RequestSpellbookData(player_name)
  if not SendAddonMessage then
    return
  end

  player_name = player_name or UnitName("player")
  if player_name then
    SendAddonMessage(self.prefix, "refresh", "WHISPER", player_name)
  end
end

function SubclassSpellbook:EnsureSpellbookUi()
  if not SpellBookFrame then
    return
  end

  self:CreateClassButtons()
  self:HookSpellbook()
end

function SubclassSpellbook:GetNativeClassId()
  local _, class_file = UnitClass("player")
  return CLASS_FILE_TO_ID[class_file] or 0
end

function SubclassSpellbook:GetNativeClassName()
  return CLASS_NAMES[self:GetNativeClassId()] or (UnitClass("player")) or "Class"
end

function SubclassSpellbook:CreateClassButtons()
  if self.class_buttons_created or not SpellBookFrame then
    return
  end

  local native = CreateFrame("Button", "ChumbaddonSpellbookNativeClassButton", SpellBookFrame, "UIPanelButtonTemplate")
  native:SetSize(78, 22)
  native:SetPoint("TOPRIGHT", SpellBookFrame, "TOPRIGHT", -92, -44)
  native:SetFrameLevel((SpellBookFrame:GetFrameLevel() or 0) + 30)
  native:SetNormalFontObject("GameFontNormalSmall")
  native:SetHighlightFontObject("GameFontHighlightSmall")
  native:SetText(self:GetNativeClassName())
  native:SetScript("OnClick", function()
    self:LeaveSubclassMode()
    if PlaySound then PlaySound("igCharacterInfoTab") end
  end)
  self.class_buttons.native = native

  local subclass = CreateFrame("Button", "ChumbaddonSpellbookSubclassClassButton", SpellBookFrame, "UIPanelButtonTemplate")
  subclass:SetSize(78, 22)
  subclass:SetPoint("TOP", native, "BOTTOM", 0, -4)
  subclass:SetFrameLevel((SpellBookFrame:GetFrameLevel() or 0) + 30)
  subclass:SetNormalFontObject("GameFontNormalSmall")
  subclass:SetHighlightFontObject("GameFontHighlightSmall")
  subclass:SetText(CLASS_NAMES[self.subclass_class or 0] or "Subclass")
  subclass:SetScript("OnClick", function()
    self:EnterSubclassMode()
    if PlaySound then PlaySound("igCharacterInfoTab") end
  end)
  self.class_buttons.subclass = subclass

  self.class_buttons_created = true
  self:RefreshClassButtons()
end

function SubclassSpellbook:HookSpellbook()
  if self.spellbook_hooked then
    return
  end

  if SpellBookFrame_Update then
    hooksecurefunc("SpellBookFrame_Update", function()
      self:OnSpellbookUpdate()
    end)
  end

  if SpellButton_UpdateButton then
    hooksecurefunc("SpellButton_UpdateButton", function(button)
      self:OnSpellButtonUpdate(button)
    end)
  end

  SpellBookFrame:HookScript("OnShow", function()
    self:CollectKnownSpells()
    self:RequestData()
    self:Refresh()
  end)

  for slot = 1, SPELLS_PER_PAGE do
    local button = _G["SpellButton" .. slot]
    if button then
      button:HookScript("OnEnter", function(btn)
        self:OnSpellButtonEnter(btn)
      end)
    end
  end

  SpellBookFrame:HookScript("OnHide", function()
    self.subclass_mode = false
    self:RestoreNativeSkillLineTabs()
    self:RestoreNativeSpellButtons()
    self:RefreshClassButtons()
  end)

  for index = 1, NATIVE_TAB_COUNT do
    local tab = _G["SpellBookSkillLineTab" .. index]
    if tab and not self.tab_click_hooked[index] then
      tab:HookScript("OnClick", function()
        if self.subclass_mode then
          self:OnNativeTabClicked(index)
        end
      end)
      self.tab_click_hooked[index] = true
    end
  end

  if SpellBookPrevPageButton then
    SpellBookPrevPageButton:HookScript("OnClick", function()
      if self.subclass_mode then
        self:OnPrevPage()
      end
    end)
  end

  if SpellBookNextPageButton then
    SpellBookNextPageButton:HookScript("OnClick", function()
      if self.subclass_mode then
        self:OnNextPage()
      end
    end)
  end

  self.spellbook_hooked = true
end

function SubclassSpellbook:EnterSubclassMode()
  if InCombatLockdown and InCombatLockdown() then
    self.pending_refresh = true
    return
  end

  if not self.subclass_class then
    return
  end

  self.subclass_mode = true
  self.active_page = 1
  self:RefreshClassButtons()
  if SpellBookFrame_Update then
    SpellBookFrame_Update()
  end
end

function SubclassSpellbook:LeaveSubclassMode()
  if InCombatLockdown and InCombatLockdown() then
    self.pending_refresh = true
    return
  end

  self.subclass_mode = false
  self:RestoreNativeSkillLineTabs()
  self:RestoreNativeSpellButtons()
  self:RefreshClassButtons()
  if SpellBookFrame_Update then
    SpellBookFrame_Update()
  end
end

function SubclassSpellbook:OnNativeTabClicked(tab_index)
  local ordered = self.ordered_tabs or {}
  local tab_id = ordered[tab_index]
  if tab_id == nil then
    return
  end

  self.active_tab = tab_id
  self.active_page = 1
  if SpellBookFrame_Update then
    SpellBookFrame_Update()
  end
end

function SubclassSpellbook:OnPrevPage()
  if (self.active_page or 1) > 1 then
    self.active_page = self.active_page - 1
    if SpellBookFrame_Update then
      SpellBookFrame_Update()
    end
  end
end

function SubclassSpellbook:OnNextPage()
  local max_page = self:GetMaxPage()
  if (self.active_page or 1) < max_page then
    self.active_page = (self.active_page or 1) + 1
    if SpellBookFrame_Update then
      SpellBookFrame_Update()
    end
  end
end

function SubclassSpellbook:GetMaxPage()
  local spells = (self.cached_grouped and self.cached_grouped[self.active_tab]) or {}
  return math.max(1, math.ceil(#spells / SPELLS_PER_PAGE))
end

function SubclassSpellbook:Refresh()
  self:EnsureSpellbookUi()
  self:RefreshClassButtons()

  if not SpellBookFrame or not SpellBookFrame:IsShown() then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self.pending_refresh = true
    return
  end

  if SpellBookFrame_Update then
    SpellBookFrame_Update()
  end
end

function SubclassSpellbook:RefreshClassButtons()
  if not self.class_buttons_created then
    return
  end

  local native = self.class_buttons.native
  local subclass = self.class_buttons.subclass
  if native then
    native:SetText(self:GetNativeClassName())
    if self.subclass_mode then
      native:Enable()
    else
      native:Disable()
    end
    if self.subclass_class then native:Show() else native:Hide() end
  end

  if subclass then
    subclass:SetText(CLASS_NAMES[self.subclass_class or 0] or "Subclass")
    if self.subclass_class then
      if self.subclass_mode then
        subclass:Disable()
      else
        subclass:Enable()
      end
      subclass:Show()
    else
      subclass:Hide()
    end
  end
end

function SubclassSpellbook:OnSpellbookUpdate()
  if not self.subclass_mode then
    return
  end

  local book_type = SpellBookFrame and SpellBookFrame.bookType
  if book_type and BOOKTYPE_SPELL and book_type ~= BOOKTYPE_SPELL then
    return
  end

  if not self.subclass_class then
    self.subclass_mode = false
    self:RefreshClassButtons()
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self.pending_refresh = true
    return
  end

  local grouped, ordered = self:GetVisibleSpells()
  self.cached_grouped = grouped
  self.ordered_tabs = ordered

  if not self.active_tab or not grouped[self.active_tab] then
    self.active_tab = ordered[1]
    self.active_page = 1
  end

  self:PaintSkillLineTabs(grouped, ordered)
  self:PaintSpellButtons(grouped[self.active_tab] or {})
  self:PaintPagination(grouped[self.active_tab] or {})
end

function SubclassSpellbook:PaintSkillLineTabs(grouped, ordered)
  for index = 1, NATIVE_TAB_COUNT do
    local tab = _G["SpellBookSkillLineTab" .. index]
    if tab then
      self:CaptureNativeSkillLineTabScripts(index, tab)

      local tab_id = ordered[index]
      if tab_id ~= nil then
        local icon_path, tcl, tcr, tct, tcb = self:GetTabIcon(tab_id, grouped[tab_id])
        tab:SetNormalTexture(icon_path)
        local tex = tab:GetNormalTexture()
        if tex and tcl then
          tex:SetTexCoord(tcl, tcr, tct, tcb)
        elseif tex then
          tex:SetTexCoord(0, 1, 0, 1)
        end

        local label = self.spell_tabs[tab_id] or DEFAULT_TABS[tab_id] or ("Tab " .. tostring(tab_id))
        tab.tooltip = label
        tab:SetScript("OnClick", function()
          self:OnNativeTabClicked(index)
        end)
        tab:SetScript("OnEnter", function(btn)
          GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
          GameTooltip:SetText(label)
          GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

        if tab_id == self.active_tab then
          tab:LockHighlight()
        else
          tab:UnlockHighlight()
        end

        tab:Show()
      else
        tab:Hide()
      end
    end
  end
end

function SubclassSpellbook:CaptureNativeSkillLineTabScripts(index, tab)
  if not tab or self.original_tab_scripts[index] then
    return
  end

  self.original_tab_scripts[index] = {
    OnClick = tab:GetScript("OnClick"),
    OnEnter = tab:GetScript("OnEnter"),
    OnLeave = tab:GetScript("OnLeave"),
  }
end

function SubclassSpellbook:RestoreNativeSkillLineTabs()
  for index, scripts in pairs(self.original_tab_scripts or {}) do
    local tab = _G["SpellBookSkillLineTab" .. index]
    if tab then
      tab:SetScript("OnClick", scripts.OnClick)
      tab:SetScript("OnEnter", scripts.OnEnter)
      tab:SetScript("OnLeave", scripts.OnLeave)
      if tab.UnlockHighlight then
        tab:UnlockHighlight()
      end
    end
  end

  self.original_tab_scripts = {}
end

function SubclassSpellbook:CaptureNativeSpellButtonScripts(slot, button)
  if not button or self.original_spell_button_scripts[slot] then
    return
  end

  self.original_spell_button_scripts[slot] = {
    OnClick = button:GetScript("OnClick"),
    OnDragStart = button:GetScript("OnDragStart"),
    OnReceiveDrag = button:GetScript("OnReceiveDrag"),
  }
end

function SubclassSpellbook:RestoreNativeSpellButtons()
  for slot, scripts in pairs(self.original_spell_button_scripts or {}) do
    local button = _G["SpellButton" .. slot]
    if button then
      button:SetScript("OnClick", scripts.OnClick)
      button:SetScript("OnDragStart", scripts.OnDragStart)
      button:SetScript("OnReceiveDrag", scripts.OnReceiveDrag)
      if not (InCombatLockdown and InCombatLockdown()) then
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
      end
      button.subclass_spell = nil
      button.spellID = nil
    end
  end

  self.original_spell_button_scripts = {}
end

function SubclassSpellbook:GetTabIcon(tab_id, spells)
  for _, spell in ipairs(spells or {}) do
    local known = self:FindKnownSpell(spell.spell_id)
    if known and known.texture then
      return known.texture, 0.08, 0.92, 0.08, 0.92
    end
  end

  return CLASS_ICON_TEXTURE,
    CLASS_ICON_COORDS[self.subclass_class] and CLASS_ICON_COORDS[self.subclass_class][1] or 0,
    CLASS_ICON_COORDS[self.subclass_class] and CLASS_ICON_COORDS[self.subclass_class][2] or 1,
    CLASS_ICON_COORDS[self.subclass_class] and CLASS_ICON_COORDS[self.subclass_class][3] or 0,
    CLASS_ICON_COORDS[self.subclass_class] and CLASS_ICON_COORDS[self.subclass_class][4] or 1
end

function SubclassSpellbook:GetSpellForSlot(slot)
  local spells = (self.cached_grouped and self.cached_grouped[self.active_tab]) or {}
  local page = self.active_page or 1
  local start_index = (page - 1) * SPELLS_PER_PAGE + 1
  return spells[start_index + slot - 1]
end

function SubclassSpellbook:GetButtonSlot(button)
  if not button then
    return nil
  end

  if button.subclass_slot then
    return button.subclass_slot
  end

  if button.GetName then
    local slot = tonumber(string.match(button:GetName() or "", "^SpellButton(%d+)$"))
    if slot then
      return slot
    end
  end

  return button.GetID and button:GetID() or nil
end

function SubclassSpellbook:ApplySpellButton(slot, button, spell)
  if not button then return end

  local icon = _G["SpellButton" .. slot .. "IconTexture"]
  local name = _G["SpellButton" .. slot .. "SpellName"]
  local rank = _G["SpellButton" .. slot .. "SubSpellName"]
  local highlight = _G["SpellButton" .. slot .. "Highlight"]
  local normal = _G["SpellButton" .. slot .. "NormalTexture"]
  local in_combat = InCombatLockdown and InCombatLockdown()

  if not in_combat then
    self:CaptureNativeSpellButtonScripts(slot, button)
    button:SetScript("OnClick", function(btn, mouse_button)
      self:OnSpellButtonClick(btn, mouse_button)
    end)
    button:SetScript("OnDragStart", function(btn)
      self:OnSpellButtonDrag(btn)
    end)
    button:SetScript("OnReceiveDrag", function(btn)
      self:OnSpellButtonDrag(btn)
    end)
  end

  if spell then
    if icon then
      icon:SetTexture(spell.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
      icon:SetDesaturated(false)
      icon:Show()
    end
    if name then
      name:SetText(spell.name or ("Spell " .. tostring(spell.spell_id)))
      name:Show()
    end
    if rank then
      rank:SetText(spell.rank or "")
      rank:Show()
    end
    if normal then normal:Show() end

    if not in_combat then
      button:SetAttribute("type", "spell")
      button:SetAttribute("spell", self:GetCastSpellName(spell))
    end
    button.subclass_spell = spell
    button.subclass_slot = slot
    button.spellID = spell.spell_id
    button:Show()
    if button.Enable then button:Enable() end
  else
    if icon then icon:SetTexture(nil); icon:Hide() end
    if name then name:SetText(""); name:Hide() end
    if rank then rank:SetText(""); rank:Hide() end
    if highlight then highlight:Hide() end
    if normal then normal:Hide() end

    if not in_combat then
      button:SetAttribute("type", nil)
      button:SetAttribute("spell", nil)
    end
    button.subclass_spell = nil
    button.subclass_slot = nil
    button.spellID = nil
    button:Hide()
  end
end

function SubclassSpellbook:PaintSpellButtons(spells)
  local page = self.active_page or 1
  local start_index = (page - 1) * SPELLS_PER_PAGE + 1

  for slot = 1, SPELLS_PER_PAGE do
    local button = _G["SpellButton" .. slot]
    if button then
      self:ApplySpellButton(slot, button, spells[start_index + slot - 1])
    end
  end
end

function SubclassSpellbook:OnSpellButtonEnter(button)
  if not button then return end
  if not self.subclass_mode then return end
  if not self.subclass_class then return end

  local book_type = SpellBookFrame and SpellBookFrame.bookType
  if book_type and BOOKTYPE_SPELL and book_type ~= BOOKTYPE_SPELL then
    return
  end

  local slot = self:GetButtonSlot(button)
  if not slot or slot < 1 or slot > SPELLS_PER_PAGE then
    return
  end

  local spell = self:GetSpellFromButton(button) or self:GetSpellForSlot(slot)
  if not spell or not spell.spell_id then
    GameTooltip:Hide()
    return
  end

  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if spell.book_index and GameTooltip.SetSpellBookItem then
    GameTooltip:SetSpellBookItem(spell.book_index, BOOKTYPE_SPELL)
  elseif GameTooltip.SetHyperlink then
    GameTooltip:SetHyperlink("spell:" .. spell.spell_id)
  else
    GameTooltip:SetText(spell.name or "")
  end
  self:PatchTooltipCastTime(spell)
  GameTooltip:Show()
end

function SubclassSpellbook:GetActiveSubclassTalentSpellIds()
  local active = {}
  local talents = _G.Chumbaddon_SubclassTalents
  if not talents or not talents.talents then
    return active
  end

  for _, talent in pairs(talents.talents) do
    local rank = talent.current_rank or 0
    if rank > 0 and talent.rank_spells then
      local spell_id = talent.rank_spells[rank]
      if spell_id then
        active[spell_id] = true
      end
    end
  end

  return active
end

function SubclassSpellbook:GetBaneCastTimeMod(spell_id, active_talents)
  if not spell_id then
    return 0
  end

  local bucket = nil
  if BANE_SOUL_FIRE_SPELLS[spell_id] then
    bucket = "soul_fire"
  elseif BANE_DEFAULT_SPELLS[spell_id] then
    bucket = "default"
  end

  if not bucket then
    return 0
  end

  for talent_spell_id, mods in pairs(BANE_CAST_TIME_MODS) do
    if active_talents[talent_spell_id] then
      return mods[bucket] or 0
    end
  end

  return 0
end

function SubclassSpellbook:GetAdjustedCastTime(spell)
  if not spell or not spell.spell_id or not GetSpellInfo then
    return nil
  end

  local _, _, _, _, _, _, cast_time = GetSpellInfo(spell.spell_id)
  cast_time = tonumber(cast_time) or 0
  if cast_time <= 0 then
    return nil
  end

  local active_talents = self:GetActiveSubclassTalentSpellIds()
  local flat_mod = self:GetBaneCastTimeMod(spell.spell_id, active_talents)
  if flat_mod == 0 then
    return nil
  end

  return math.max(0, cast_time + flat_mod)
end

function SubclassSpellbook:FormatCastTime(cast_time)
  if not cast_time or cast_time <= 0 then
    return "Instant cast"
  end

  local seconds = cast_time / 1000
  local text = string.format("%.1f", seconds)
  text = string.gsub(text, "%.0$", "")
  return text .. " sec cast"
end

function SubclassSpellbook:PatchTooltipCastTime(spell)
  local adjusted = self:GetAdjustedCastTime(spell)
  if not adjusted or not GameTooltip or not GameTooltip.GetName then
    return
  end

  local replacement = self:FormatCastTime(adjusted)
  local tooltip_name = GameTooltip:GetName()
  for line = 2, 12 do
    local font_string = _G[tooltip_name .. "TextLeft" .. line]
    local text = font_string and font_string:GetText()
    if text and string.find(text, "sec cast") then
      font_string:SetText(replacement)
      if font_string.SetTextColor then
        font_string:SetTextColor(1, 1, 1)
      end
      return
    end
  end
end

function SubclassSpellbook:GetSpellFromButton(button)
  if not button then
    return nil
  end

  if button.subclass_spell then
    return button.subclass_spell
  end

  local slot = self:GetButtonSlot(button)
  if not slot or slot < 1 or slot > SPELLS_PER_PAGE then
    return nil
  end

  return self:GetSpellForSlot(slot)
end

function SubclassSpellbook:GetCastSpellName(spell)
  if not spell or not spell.name then
    return nil
  end

  if spell.rank and spell.rank ~= "" then
    return spell.name .. "(" .. spell.rank .. ")"
  end

  return spell.name
end

function SubclassSpellbook:OnSpellButtonClick(button, mouse_button)
  if not self.subclass_mode then
    return
  end

  local spell = self:GetSpellFromButton(button)
  if not spell or not spell.spell_id then
    return
  end

  if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
    local link = nil
    if GetSpellLink then
      if spell.book_index then
        link = GetSpellLink(spell.book_index, BOOKTYPE_SPELL)
      end
      link = link or GetSpellLink(spell.spell_id)
    end
    if link then
      ChatEdit_InsertLink(link)
      return
    end
  end

  if IsModifiedClick and IsModifiedClick("PICKUPACTION") then
    self:OnSpellButtonDrag(button)
    return
  end

  if spell.book_index and CastSpell then
    CastSpell(spell.book_index, BOOKTYPE_SPELL)
  elseif spell.name and CastSpellByName then
    CastSpellByName(self:GetCastSpellName(spell))
  elseif CastSpellByID then
    CastSpellByID(spell.spell_id)
  end
end

function SubclassSpellbook:RankNumber(rank)
  return tonumber(string.match(tostring(rank or ""), "(%d+)")) or 0
end

function SubclassSpellbook:ShouldPreferSpell(candidate, current)
  if not current then
    return true
  end

  local candidate_rank = self:RankNumber(candidate.rank)
  local current_rank = self:RankNumber(current.rank)
  if candidate_rank ~= current_rank then
    return candidate_rank > current_rank
  end

  return (candidate.spell_id or 0) > (current.spell_id or 0)
end

function SubclassSpellbook:AddVisibleSpell(grouped, ordered_tabs, tab_id, known)
  if not known then
    return
  end

  tab_id = tab_id or 0
  if not grouped[tab_id] then
    grouped[tab_id] = {
      spells = {},
      by_name = {},
    }
    table.insert(ordered_tabs, tab_id)
  end

  local bucket = grouped[tab_id]
  local name_key = tostring(known.name or known.spell_id or "")
  local existing_index = bucket.by_name[name_key]
  if existing_index then
    if self:ShouldPreferSpell(known, bucket.spells[existing_index]) then
      bucket.spells[existing_index] = known
    end
  else
    table.insert(bucket.spells, known)
    bucket.by_name[name_key] = #bucket.spells
  end
end

function SubclassSpellbook:OnSpellButtonDrag(button)
  if not self.subclass_mode then
    return
  end

  local spell = self:GetSpellFromButton(button)
  if not spell or not spell.spell_id or not PickupSpell then
    return
  end

  if spell.book_index then
    PickupSpell(spell.book_index, BOOKTYPE_SPELL)
  else
    PickupSpell(self:GetCastSpellName(spell) or spell.spell_id)
  end
end

function SubclassSpellbook:OnSpellButtonUpdate(button)
  if not button then return end
  if not self.subclass_mode then return end
  if not self.subclass_class then return end

  local book_type = SpellBookFrame and SpellBookFrame.bookType
  if book_type and BOOKTYPE_SPELL and book_type ~= BOOKTYPE_SPELL then
    return
  end

  local slot = self:GetButtonSlot(button)
  if not slot or slot < 1 or slot > SPELLS_PER_PAGE then
    return
  end

  self:ApplySpellButton(slot, button, self:GetSpellForSlot(slot))
end

function SubclassSpellbook:PaintPagination(spells)
  local page = self.active_page or 1
  local max_page = math.max(1, math.ceil(#spells / SPELLS_PER_PAGE))

  if SpellBookPageText then
    SpellBookPageText:SetText(string.format("Page %d of %d", page, max_page))
    SpellBookPageText:Show()
  end

  if SpellBookPrevPageButton then
    SpellBookPrevPageButton:Show()
    if page > 1 then
      SpellBookPrevPageButton:Enable()
    else
      SpellBookPrevPageButton:Disable()
    end
  end

  if SpellBookNextPageButton then
    SpellBookNextPageButton:Show()
    if page < max_page then
      SpellBookNextPageButton:Enable()
    else
      SpellBookNextPageButton:Disable()
    end
  end
end

function SubclassSpellbook:OnAddonMessage(prefix, message, channel, sender)
  local player_name = UnitName("player")
  local target, payload = string.match(message or "", "^([^|]+)|(.+)$")
  if target and player_name and target ~= player_name then
    return
  end

  payload = payload or message

  if prefix == "SCSUB" or prefix == "SCTAL" then
    self:UpdateSubclassClassFromPayload(payload)
    return
  end

  if prefix ~= self.prefix then
    return
  end

  self:SetData(self:ParsePayload(payload))
end

function SubclassSpellbook:UpdateSubclassClassFromPayload(payload)
  local class_id = nil
  for key, value in string.gmatch(payload or "", "([^=;]+)=([^;]+)") do
    if string.lower(key) == "class" then
      class_id = tonumber(value) or 0
      break
    end
  end

  if not class_id then
    return
  end

  if class_id == 0 then
    self.subclass_class = nil
    self.subclass_mode = false
  else
    self.subclass_class = class_id
    self:RequestSpellbookData()
  end

  self:RefreshClassButtons()
  if SpellBookFrame and SpellBookFrame:IsShown() then
    self:Refresh()
  end
end

function SubclassSpellbook:ParsePayload(payload)
  local data = {
    tabs = {},
    spells = {},
  }

  for key, value in string.gmatch(payload or "", "([^=;]+)=([^;]+)") do
    key = string.lower(key)
    if key == "class" then
      data.subclass_class = tonumber(value)
    elseif key == "tabs" then
      for tab_id, name in string.gmatch(value, "(%d+):([^,]+)") do
        data.tabs[tonumber(tab_id)] = name
      end
    elseif key == "spells" then
      for spell_id, tab_id in string.gmatch(value, "(%d+):(%d+)") do
        table.insert(data.spells, {
          spell_id = tonumber(spell_id),
          tab_id = tonumber(tab_id),
        })
      end
    end
  end

  return data
end

function SubclassSpellbook:SetData(data)
  if not data then
    return
  end

  local class_id = tonumber(data.subclass_class or data.class)
  self.subclass_class = class_id and class_id ~= 0 and class_id or nil
  self.spell_tabs = {}
  self.spells = {}
  self.active_tab = nil

  for tab_id, tab_name in pairs(data.tabs or {}) do
    self.spell_tabs[tonumber(tab_id) or 0] = tostring(tab_name)
  end

  for _, spell in ipairs(data.spells or {}) do
    local spell_id = tonumber(spell.spell_id or spell.id or spell[1])
    if spell_id then
      table.insert(self.spells, {
        spell_id = spell_id,
        tab_id = tonumber(spell.tab_id or spell.tab or spell[2]) or 0,
      })
    end
  end

  self.active_page = 1
  self:CollectKnownSpells()
  self:Refresh()
end

function SubclassSpellbook:CollectKnownSpells()
  self.known_spells = {}
  self.known_spell_names = {}

  if not GetNumSpellTabs or not GetSpellTabInfo then
    return
  end

  for tab_index = 1, GetNumSpellTabs() do
    local tab_name, _, offset, num_spells = GetSpellTabInfo(tab_index)
    offset = offset or 0
    num_spells = num_spells or 0

    for spell_index = offset + 1, offset + num_spells do
      local name, rank = GetSpellName(spell_index, BOOKTYPE_SPELL)
      if name then
        local spell_id = self:GetSpellIdFromBookIndex(spell_index)
        local texture = GetSpellTexture(spell_index, BOOKTYPE_SPELL)
        local known = {
          spell_id = spell_id,
          book_index = spell_index,
          name = name,
          rank = rank,
          texture = texture,
          tab_name = tab_name,
        }
        if spell_id then
          self.known_spells[spell_id] = known
        end
        self.known_spell_names[self:GetSpellNameKey(name, rank)] = known
      end
    end
  end
end

function SubclassSpellbook:GetSpellIdFromBookIndex(spell_index)
  if not GetSpellLink then
    return nil
  end

  local link = GetSpellLink(spell_index, BOOKTYPE_SPELL)
  if not link then
    return nil
  end

  return tonumber(string.match(link, "spell:(%d+)"))
end

function SubclassSpellbook:GetSpellNameKey(name, rank)
  return tostring(name or "") .. "\001" .. tostring(rank or "")
end

function SubclassSpellbook:FindKnownSpell(spell_id)
  local known = self.known_spells[spell_id]
  if known then
    return known
  end

  if GetSpellInfo then
    local name, rank, texture = GetSpellInfo(spell_id)
    if name then
      known = {
        spell_id = spell_id,
        book_index = nil,
        name = name,
        rank = rank,
        texture = texture,
        tab_name = nil,
      }
      self.known_spells[spell_id] = known
      return known
    end
  end

  return nil
end

function SubclassSpellbook:GetVisibleSpells()
  local grouped = {}
  local ordered_tabs = {}

  for _, spell in ipairs(self.spells) do
    local known = self:FindKnownSpell(spell.spell_id)
    if known then
      self:AddVisibleSpell(grouped, ordered_tabs, spell.tab_id or 0, known)
    end
  end

  table.sort(ordered_tabs)

  for tab_id, bucket in pairs(grouped) do
    table.sort(bucket.spells, function(left, right)
      return tostring(left.name or "") < tostring(right.name or "")
    end)
    grouped[tab_id] = bucket.spells
  end

  return grouped, ordered_tabs
end

function SubclassSpellbook:ReportError(message)
  local text = string.format("%s error: %s", self.debug_prefix, tostring(message))
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  else
    print(text)
  end
end
