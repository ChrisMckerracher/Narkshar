SubclassTalents = {}
SubclassTalents.__index = SubclassTalents

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

local function wipe_table(tbl)
  for key in pairs(tbl) do
    tbl[key] = nil
  end
end

local function sort_by_tab_page(left, right)
  if left.row == right.row then
    return left.col < right.col
  end
  return left.row < right.row
end

local MAX_SUBCLASS_TALENTS = 40
local MAX_TALENT_ROWS = 15
local NUM_TALENT_COLUMNS = 4
local MAX_CONNECTOR_TEXTURES = 30
local TALENT_BUTTON_SIZE = 32
local TALENT_OFFSET_X = 35
local TALENT_OFFSET_Y = 20
local TALENT_SPACING = 63
local TALENT_BRANCH_TEXTURE = "Interface\\TalentFrame\\UI-TalentBranches"
local TALENT_ARROW_TEXTURE = "Interface\\TalentFrame\\UI-TalentArrows"
local TALENT_BRANCH_PREFIX = "ChumbaddonSubclassTalentFrameBranch"
local TALENT_ARROW_PREFIX = "ChumbaddonSubclassTalentFrameArrow"

local TALENT_BRANCH_TEXTURECOORDS = {
  up = {
    [1] = { 0.12890625, 0.25390625, 0, 0.484375 },
    [-1] = { 0.12890625, 0.25390625, 0.515625, 1.0 },
  },
  down = {
    [1] = { 0, 0.125, 0, 0.484375 },
    [-1] = { 0, 0.125, 0.515625, 1.0 },
  },
  left = {
    [1] = { 0.2578125, 0.3828125, 0, 0.5 },
    [-1] = { 0.2578125, 0.3828125, 0.5, 1.0 },
  },
  right = {
    [1] = { 0.2578125, 0.3828125, 0, 0.5 },
    [-1] = { 0.2578125, 0.3828125, 0.5, 1.0 },
  },
  topright = {
    [1] = { 0.515625, 0.640625, 0, 0.5 },
    [-1] = { 0.515625, 0.640625, 0.5, 1.0 },
  },
  topleft = {
    [1] = { 0.640625, 0.515625, 0, 0.5 },
    [-1] = { 0.640625, 0.515625, 0.5, 1.0 },
  },
  bottomright = {
    [1] = { 0.38671875, 0.51171875, 0, 0.5 },
    [-1] = { 0.38671875, 0.51171875, 0.5, 1.0 },
  },
  bottomleft = {
    [1] = { 0.51171875, 0.38671875, 0, 0.5 },
    [-1] = { 0.51171875, 0.38671875, 0.5, 1.0 },
  },
  tdown = {
    [1] = { 0.64453125, 0.76953125, 0, 0.5 },
    [-1] = { 0.64453125, 0.76953125, 0.5, 1.0 },
  },
  tup = {
    [1] = { 0.7734375, 0.8984375, 0, 0.5 },
    [-1] = { 0.7734375, 0.8984375, 0.5, 1.0 },
  },
}

local TALENT_ARROW_TEXTURECOORDS = {
  top = {
    [1] = { 0, 0.5, 0, 0.5 },
    [-1] = { 0, 0.5, 0.5, 1.0 },
  },
  right = {
    [1] = { 1.0, 0.5, 0, 0.5 },
    [-1] = { 1.0, 0.5, 0.5, 1.0 },
  },
  left = {
    [1] = { 0.5, 1.0, 0, 0.5 },
    [-1] = { 0.5, 1.0, 0.5, 1.0 },
  },
}

local TALENT_BACKGROUNDS = {
  [1] = { "WarriorArms", "WarriorFury", "WarriorProtection" },
  [2] = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
  [3] = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
  [4] = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
  [5] = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
  [7] = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
  [8] = { "MageArcane", "MageFire", "MageFrost" },
  [9] = { "WarlockCurses", "WarlockSummoning", "WarlockDestruction" },
  [11] = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
}

local function get_talent_frame()
  return _G.PlayerTalentFrame or _G.TalentFrame
end

local function get_frame(name)
  return name and _G[name] or nil
end

local function set_desaturated(texture, desaturate)
  if texture and SetDesaturation then
    SetDesaturation(texture, desaturate and 1 or nil)
  end
end

local function is_connector_position_valid(row, col)
  return row
    and col
    and row >= 1
    and row <= MAX_TALENT_ROWS
    and col >= 1
    and col <= NUM_TALENT_COLUMNS
end

local function set_region_size(region, width, height)
  if region.SetSize then
    region:SetSize(width, height)
  else
    region:SetWidth(width)
    region:SetHeight(height)
  end
end

function SubclassTalents:new()
  local o = setmetatable({}, self)
  o.prefix = "SCTAL"
  o.debug_prefix = "[SubclassTalents]"
  o.subclass_class = 0
  o.free_points = 0
  o.used_points = 0
  o.tabs = {}
  o.tab_order = {}
  o.talents = {}
  o.talents_by_tab = {}
  o.active_tab = nil
  o.buttons = {}
  o.tab_buttons = {}
  o.branch_textures = {}
  o.arrow_textures = {}
  o.branch_nodes = {}
  o.class_buttons = {}
  o.hidden_native_widgets = {}
  o.pending_refresh = false
  return o
end

function SubclassTalents:RememberAndHide(widget)
  if not widget then
    return
  end

  if self.hidden_native_widgets[widget] == nil then
    self.hidden_native_widgets[widget] = widget:IsShown() and true or false
  end
  widget:Hide()
end

function SubclassTalents:register()
  if self.frame then
    return
  end

  _G.Chumbaddon_SubclassTalents = self

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("ADDON_LOADED")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    self:SafelyHandleEvent(event, ...)
  end)

  SLASH_CHUMBADDONSUBCLASSTALENTS1 = "/sctalent"
  SLASH_CHUMBADDONSUBCLASSTALENTS2 = "/subclasstalents"
  SlashCmdList.CHUMBADDONSUBCLASSTALENTS = function()
    self:TogglePanel()
  end

  SLASH_CHUMBADDONSUBCLASSTALENTSDEBUG1 = "/sctalentdebug"
  SlashCmdList.CHUMBADDONSUBCLASSTALENTSDEBUG = function()
    self.debug_connectors = not self.debug_connectors
    self:ReportError("connector debug " .. (self.debug_connectors and "enabled" or "disabled"))
    self:Refresh()
  end
end

function SubclassTalents:SafelyHandleEvent(event, ...)
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

function SubclassTalents:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    local addon_name = ...
    if addon_name == "Blizzard_TalentUI" then
      self:HookTalentFrame()
    end
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:RegisterPrefix()
    self:HookTalentFrame()
    self:RequestData()
  elseif event == "CHAT_MSG_ADDON" then
    self:OnAddonMessage(...)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if self.pending_refresh then
      self.pending_refresh = false
      self:Refresh()
    end
  end
end

function SubclassTalents:RegisterPrefix()
  if self.prefix_registered or not RegisterAddonMessagePrefix then
    return
  end

  if RegisterAddonMessagePrefix(self.prefix) then
    self.prefix_registered = true
  end
end

function SubclassTalents:RequestData()
  if SendAddonMessage then
    local player_name = UnitName("player")
    if player_name then
      SendAddonMessage(self.prefix, "refresh", "WHISPER", player_name)
    end
  end
end

function SubclassTalents:HookTalentFrame()
  if self.hooked_talent_frame then
    return
  end

  if not get_talent_frame() and LoadAddOn then
    LoadAddOn("Blizzard_TalentUI")
  end

  local talent_frame = get_talent_frame()
  if not talent_frame then
    return
  end

  self.talent_frame = talent_frame
  self:CreateClassButtons()

  talent_frame:HookScript("OnShow", function()
    self:RequestData()
    self:RefreshClassButtons()
  end)
  talent_frame:HookScript("OnHide", function()
    self:LeaveSubclassMode(true)
  end)

  if hooksecurefunc and PlayerTalentFrame_Update then
    hooksecurefunc("PlayerTalentFrame_Update", function()
      if self.subclass_mode then
        self:HideNativeTalentWidgets()
      end
    end)
  elseif hooksecurefunc and TalentFrame_Update then
    hooksecurefunc("TalentFrame_Update", function()
      if self.subclass_mode then
        self:HideNativeTalentWidgets()
      end
    end)
  end

  self.hooked_talent_frame = true
end

function SubclassTalents:GetNativeTalentWidgets()
  local widgets = {}

  table.insert(widgets, _G.PlayerTalentFrameScrollFrame)
  table.insert(widgets, _G.TalentFrameScrollFrame)
  table.insert(widgets, _G.PlayerTalentFramePointsBar)
  table.insert(widgets, _G.TalentFramePointsBar)
  table.insert(widgets, _G.PlayerTalentFrameSpentPoints)
  table.insert(widgets, _G.TalentFrameSpentPoints)
  table.insert(widgets, _G.PlayerTalentFrameTalentPointsText)
  table.insert(widgets, _G.TalentFrameTalentPointsText)

  for index = 1, 10 do
    table.insert(widgets, _G["PlayerTalentFrameTab" .. index])
    table.insert(widgets, _G["TalentFrameTab" .. index])
  end

  for index = 1, MAX_SUBCLASS_TALENTS do
    table.insert(widgets, _G["PlayerTalentFrameTalent" .. index])
    table.insert(widgets, _G["TalentFrameTalent" .. index])
  end

  return widgets
end

function SubclassTalents:HideNativeTalentWidgets()
  for _, widget in ipairs(self:GetNativeTalentWidgets()) do
    self:RememberAndHide(widget)
  end
end

function SubclassTalents:ShowNativeTalentWidgets()
  for widget, was_shown in pairs(self.hidden_native_widgets) do
    if widget and was_shown then
      widget:Show()
    end
  end

  wipe_table(self.hidden_native_widgets)
end

function SubclassTalents:GetNativeClassId()
  local _, class_file = UnitClass("player")
  return CLASS_FILE_TO_ID[class_file] or 0
end

function SubclassTalents:GetNativeClassName()
  return CLASS_NAMES[self:GetNativeClassId()] or (UnitClass("player")) or "Class"
end

function SubclassTalents:CreateClassButtons()
  if self.class_buttons_created or not self.talent_frame then
    return
  end

  local native = CreateFrame("Button", "ChumbaddonTalentNativeClassButton", self.talent_frame, "UIPanelButtonTemplate")
  native:SetSize(78, 22)
  native:SetPoint("TOPRIGHT", self.talent_frame, "TOPRIGHT", -92, -44)
  native:SetNormalFontObject("GameFontNormalSmall")
  native:SetHighlightFontObject("GameFontHighlightSmall")
  native:SetFrameLevel((self.talent_frame:GetFrameLevel() or 0) + 30)
  native:SetScript("OnClick", function()
    self:LeaveSubclassMode()
  end)
  self.class_buttons.native = native

  local subclass = CreateFrame("Button", "ChumbaddonTalentSubclassClassButton", self.talent_frame, "UIPanelButtonTemplate")
  subclass:SetSize(78, 22)
  subclass:SetPoint("TOP", native, "BOTTOM", 0, -4)
  subclass:SetNormalFontObject("GameFontNormalSmall")
  subclass:SetHighlightFontObject("GameFontHighlightSmall")
  subclass:SetFrameLevel((self.talent_frame:GetFrameLevel() or 0) + 30)
  subclass:SetScript("OnClick", function()
    self:ShowPanel()
  end)
  self.class_buttons.subclass = subclass

  self.class_buttons_created = true
  self:RefreshClassButtons()
end

function SubclassTalents:RefreshClassButtons()
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
    native:Show()
  end

  if subclass then
    subclass:SetText(CLASS_NAMES[self.subclass_class] or "Subclass")
    if self.subclass_class and self.subclass_class ~= 0 then
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

function SubclassTalents:EnsurePanel()
  if self.panel then
    return
  end

  self:HookTalentFrame()

  local talent_frame = self.talent_frame or get_talent_frame()
  if not talent_frame then
    return
  end

  local panel = CreateFrame("Frame", "ChumbaddonSubclassTalentFrame", talent_frame)
  local scroll_anchor = _G.PlayerTalentFrameScrollFrame or _G.TalentFrameScrollFrame
  if scroll_anchor then
    panel:SetPoint("TOPLEFT", scroll_anchor, "TOPLEFT", 0, 0)
  else
    panel:SetPoint("TOPLEFT", talent_frame, "TOPLEFT", 24, -74)
  end
  panel:SetSize(302, 372)
  panel:SetFrameLevel((talent_frame:GetFrameLevel() or 0) + 20)
  panel:EnableMouse(true)
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", panel, "TOP", 0, 20)
  title:SetText("Subclass Talents")
  panel.title = title

  local scroll = CreateFrame("ScrollFrame", "ChumbaddonSubclassTalentFrameScrollFrame", panel, "UIPanelScrollFrameTemplate")
  scroll:SetSize(302, 332)
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  panel.scroll = scroll

  local child = CreateFrame("Frame", "ChumbaddonSubclassTalentFrameScrollChildFrame", scroll)
  child:SetSize(320, 50)
  scroll:SetScrollChild(child)
  panel.child = child

  local bg_top_left = scroll:CreateTexture(nil, "BORDER")
  bg_top_left:SetSize(256, 256)
  bg_top_left:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  panel.bg_top_left = bg_top_left

  local bg_top_right = scroll:CreateTexture(nil, "BORDER")
  bg_top_right:SetSize(44, 256)
  bg_top_right:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
  bg_top_right:SetTexCoord(0, 0.6875, 0, 1)
  panel.bg_top_right = bg_top_right

  local bg_bottom_left = scroll:CreateTexture(nil, "BORDER")
  bg_bottom_left:SetSize(256, 75)
  bg_bottom_left:SetPoint("TOPLEFT", bg_top_left, "BOTTOMLEFT", 0, 0)
  bg_bottom_left:SetTexCoord(0, 1, 0, 0.5859375)
  panel.bg_bottom_left = bg_bottom_left

  local bg_bottom_right = scroll:CreateTexture(nil, "BORDER")
  bg_bottom_right:SetSize(44, 75)
  bg_bottom_right:SetPoint("TOPLEFT", bg_top_right, "BOTTOMLEFT", 0, 0)
  bg_bottom_right:SetTexCoord(0, 0.6875, 0, 0.5859375)
  panel.bg_bottom_right = bg_bottom_right

  local points_bar = CreateFrame("Frame", "ChumbaddonSubclassTalentFramePointsBar", panel)
  points_bar:SetSize(331, 26)
  local points_anchor = _G.PlayerTalentFramePointsBar or _G.TalentFramePointsBar
  if points_anchor then
    points_bar:SetPoint("CENTER", points_anchor, "CENTER", 0, 0)
  else
    points_bar:SetPoint("TOP", scroll, "BOTTOM", 0, -4)
  end
  panel.points_bar = points_bar

  local points_bg = points_bar:CreateTexture(nil, "BACKGROUND")
  points_bg:SetAllPoints(points_bar)
  points_bg:SetTexture("Interface\\Buttons\\UI-Button-Borders2")
  points_bg:SetTexCoord(0, 0.646484375, 0.2109375, 0.4140625)

  local spent = points_bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  spent:SetPoint("LEFT", points_bar, "LEFT", 12, 1)
  spent:SetJustifyH("LEFT")
  panel.spent = spent

  local points = points_bar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  points:SetPoint("RIGHT", points_bar, "RIGHT", -12, 1)
  points:SetJustifyH("RIGHT")
  panel.points = points

  local status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  status:SetPoint("CENTER", scroll, "CENTER", 0, 0)
  status:SetWidth(240)
  status:SetJustifyH("LEFT")
  panel.status = status

  self.panel = panel
  self:CreateTalentButtons()
  self:CreateConnectorLayers()
end

function SubclassTalents:CreateTalentButtons()
  if self.buttons_created then
    return
  end

  for index = 1, MAX_SUBCLASS_TALENTS do
    local button_name = "ChumbaddonSubclassTalentFrameTalent" .. index
    local ok, button = pcall(function()
      return CreateFrame("Button", button_name, self.panel.child, "PlayerTalentButtonTemplate")
    end)
    if not ok or not button then
      button = CreateFrame("Button", button_name, self.panel.child)
    end

    button:SetID(index)
    button:SetSize(TALENT_BUTTON_SIZE, TALENT_BUTTON_SIZE)
    button:RegisterForClicks("AnyUp")
    button:SetScript("OnClick", function(btn)
      self:SpendTalent(btn.talent)
    end)
    button:SetScript("OnEnter", function(btn)
      self:ShowTalentTooltip(btn)
    end)
    button:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    local icon = get_frame(button_name .. "IconTexture") or get_frame(button_name .. "Icon")
    if not icon then
      icon = button:CreateTexture(button_name .. "Icon", "ARTWORK")
      icon:SetAllPoints(button)
    end
    button.icon = icon

    local border = get_frame(button_name .. "Slot")
    if not border then
      border = button:CreateTexture(button_name .. "Slot", "OVERLAY")
      border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
      border:SetPoint("TOPLEFT", button, "TOPLEFT", -14, 14)
      border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 14, -14)
    end
    button.border = border

    local rank = get_frame(button_name .. "Rank")
    if not rank then
      rank = button:CreateFontString(button_name .. "Rank", "OVERLAY", "GameFontNormalSmall")
      rank:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -6)
    end
    button.rank = rank

    button.rank_border = get_frame(button_name .. "RankBorder")
    button:Hide()
    table.insert(self.buttons, button)
  end

  self.buttons_created = true
end

function SubclassTalents:CreateConnectorLayers()
  if self.connectors_created then
    return
  end

  self.panel.arrow_frame = CreateFrame("Frame", nil, self.panel.child)
  self.panel.arrow_frame:SetAllPoints(self.panel.child)
  self.panel.arrow_frame:SetFrameLevel((self.panel.child:GetFrameLevel() or 0) + 10)
  self.panel.arrow_frame:EnableMouse(false)
  self.panel.arrow_frame:Show()

  for row = 1, MAX_TALENT_ROWS do
    self.branch_nodes[row] = {}
    for col = 1, NUM_TALENT_COLUMNS do
      self.branch_nodes[row][col] = {}
    end
  end

  for index = 1, MAX_CONNECTOR_TEXTURES do
    local branch = self.panel.child:CreateTexture(TALENT_BRANCH_PREFIX .. index, "ARTWORK")
    set_region_size(branch, 32, 32)
    branch:SetTexture(TALENT_BRANCH_TEXTURE)
    branch:Hide()
    self.branch_textures[index] = branch

    local arrow = self.panel.arrow_frame:CreateTexture(TALENT_ARROW_PREFIX .. index, "OVERLAY")
    set_region_size(arrow, 32, 32)
    arrow:SetTexture(TALENT_ARROW_TEXTURE)
    arrow:Hide()
    self.arrow_textures[index] = arrow
  end

  self.connectors_created = true
end

function SubclassTalents:ResetConnectorNodes()
  for row = 1, MAX_TALENT_ROWS do
    for col = 1, NUM_TALENT_COLUMNS do
      local node = self.branch_nodes[row][col]
      node.id = nil
      node.up = 0
      node.down = 0
      node.left = 0
      node.right = 0
      node.left_arrow = 0
      node.right_arrow = 0
      node.top_arrow = 0
    end
  end
end

function SubclassTalents:HideConnectorTextures()
  self.branch_index = 1
  self.arrow_index = 1

  for _, texture in ipairs(self.branch_textures) do
    texture:Hide()
  end

  for _, texture in ipairs(self.arrow_textures) do
    texture:Hide()
  end
end

function SubclassTalents:GetConnectorTexture(pool, index, parent, layer, texture_path)
  local texture = pool[index]
  if not texture then
    texture = parent:CreateTexture(nil, layer)
    set_region_size(texture, 32, 32)
    pool[index] = texture
  elseif texture.SetDrawLayer then
    texture:SetDrawLayer(layer)
  end

  texture:SetTexture(texture_path)
  texture:SetVertexColor(1, 1, 1)
  texture:ClearAllPoints()
  texture:Show()
  return texture
end

function SubclassTalents:SetBranchTexture(tex_coords, x_offset, y_offset)
  if (self.branch_index or 1) > MAX_CONNECTOR_TEXTURES then
    return
  end

  local texture = self:GetConnectorTexture(
    self.branch_textures,
    self.branch_index or 1,
    self.panel.child,
    "ARTWORK",
    TALENT_BRANCH_TEXTURE
  )
  self.branch_index = (self.branch_index or 1) + 1
  self.connector_branch_draws = (self.connector_branch_draws or 0) + 1

  texture:SetTexCoord(tex_coords[1], tex_coords[2], tex_coords[3], tex_coords[4])
  texture:SetPoint("TOPLEFT", self.panel.child, "TOPLEFT", x_offset, y_offset)
end

function SubclassTalents:SetArrowTexture(tex_coords, x_offset, y_offset)
  if (self.arrow_index or 1) > MAX_CONNECTOR_TEXTURES then
    return
  end

  local texture = self:GetConnectorTexture(
    self.arrow_textures,
    self.arrow_index or 1,
    self.panel.arrow_frame,
    "OVERLAY",
    TALENT_ARROW_TEXTURE
  )
  self.arrow_index = (self.arrow_index or 1) + 1
  self.connector_arrow_draws = (self.connector_arrow_draws or 0) + 1

  texture:SetTexCoord(tex_coords[1], tex_coords[2], tex_coords[3], tex_coords[4])
  texture:SetPoint("TOPLEFT", self.panel.arrow_frame, "TOPLEFT", x_offset, y_offset)
end

function SubclassTalents:SetTalentConnectorNode(talent)
  local row = (talent.row or 0) + 1
  local col = (talent.col or 0) + 1
  if not is_connector_position_valid(row, col) then
    return
  end

  self.branch_nodes[row][col].id = talent.talent_id
end

function SubclassTalents:IsPrerequisiteMet(talent)
  local prereq = self.talents[talent.prereq_talent]
  return prereq and (prereq.current_rank or 0) > (talent.prereq_rank or 0)
end

function SubclassTalents:GetConnectorState(talent)
  if not self:IsPrerequisiteMet(talent) then
    return -1
  end

  if ((talent.row or 0) * 5) > self:GetSpentInTab(talent.tab_id) then
    return -1
  end

  if (talent.current_rank or 0) == 0 and (self.free_points or 0) <= 0 then
    return -1
  end

  return 1
end

function SubclassTalents:DrawConnectorLine(button_row, button_col, prereq_row, prereq_col, state)
  if
    not is_connector_position_valid(button_row, button_col)
    or not is_connector_position_valid(prereq_row, prereq_col)
    or button_row < prereq_row
  then
    return
  end

  local left, right

  if button_col == prereq_col then
    if (button_row - prereq_row) > 1 then
      for row = prereq_row + 1, button_row - 1 do
        if self.branch_nodes[row][button_col].id then
          return
        end
      end
    end

    for row = prereq_row, button_row - 1 do
      self.branch_nodes[row][button_col].down = state
      if (row + 1) <= (button_row - 1) then
        self.branch_nodes[row + 1][button_col].up = state
      end
    end
    self.branch_nodes[button_row][button_col].top_arrow = state
    return
  end

  if button_row == prereq_row then
    left = math.min(button_col, prereq_col)
    right = math.max(button_col, prereq_col)

    if (right - left) > 1 then
      for col = left + 1, right - 1 do
        if self.branch_nodes[prereq_row][col].id then
          return
        end
      end
    end

    for col = left, right - 1 do
      self.branch_nodes[prereq_row][col].right = state
      self.branch_nodes[prereq_row][col + 1].left = state
    end

    if button_col < prereq_col then
      self.branch_nodes[button_row][button_col].right_arrow = state
    else
      self.branch_nodes[button_row][button_col].left_arrow = state
    end
    return
  end

  left = math.min(button_col, prereq_col)
  right = math.max(button_col, prereq_col)
  if left == prereq_col then
    left = left + 1
  else
    right = right - 1
  end

  local blocked = nil
  for col = left, right do
    if self.branch_nodes[prereq_row][col].id then
      blocked = true
    end
  end

  left = math.min(button_col, prereq_col)
  right = math.max(button_col, prereq_col)
  if not blocked then
    for row = prereq_row, button_row - 1 do
      self.branch_nodes[row][button_col].down = state
      self.branch_nodes[row + 1][button_col].up = state
    end

    for col = left, right - 1 do
      self.branch_nodes[prereq_row][col].right = state
      self.branch_nodes[prereq_row][col + 1].left = state
    end

    self.branch_nodes[button_row][button_col].top_arrow = state
    return
  end

  if left == button_col then
    left = left + 1
  else
    right = right - 1
  end

  for col = left, right do
    if self.branch_nodes[button_row][col].id then
      return
    end
  end

  left = math.min(button_col, prereq_col)
  right = math.max(button_col, prereq_col)
  for row = prereq_row, button_row - 1 do
    self.branch_nodes[row][prereq_col].up = state
    self.branch_nodes[row + 1][prereq_col].down = state
  end

  if button_col < prereq_col then
    self.branch_nodes[button_row][button_col].right_arrow = state
  else
    self.branch_nodes[button_row][button_col].left_arrow = state
  end
end

function SubclassTalents:BuildConnectorNodes(talents)
  for _, talent in ipairs(talents or {}) do
    if talent.prereq_talent and talent.prereq_talent > 0 then
      local prereq = self.talents[talent.prereq_talent]
      if prereq and prereq.tab_id == talent.tab_id then
        self.connector_dependency_count = (self.connector_dependency_count or 0) + 1
        local state = self:GetConnectorState(talent)
        self:DrawConnectorLine(
          (talent.row or 0) + 1,
          (talent.col or 0) + 1,
          (prereq.row or 0) + 1,
          (prereq.col or 0) + 1,
          state
        )
      end
    end
  end
end

function SubclassTalents:DrawConnectorTextures()
  local ignore_up = nil

  for row = 1, MAX_TALENT_ROWS do
    for col = 1, NUM_TALENT_COLUMNS do
      local node = self.branch_nodes[row][col]
      local x_offset = ((col - 1) * TALENT_SPACING) + TALENT_OFFSET_X + 2
      local y_offset = -((row - 1) * TALENT_SPACING) - TALENT_OFFSET_Y - 2

      if node.id then
        if node.up ~= 0 then
          if not ignore_up then
            self:SetBranchTexture(
              TALENT_BRANCH_TEXTURECOORDS.up[node.up],
              x_offset,
              y_offset + TALENT_BUTTON_SIZE
            )
          else
            ignore_up = nil
          end
        end

        if node.down ~= 0 then
          self:SetBranchTexture(
            TALENT_BRANCH_TEXTURECOORDS.down[node.down],
            x_offset,
            y_offset - TALENT_BUTTON_SIZE + 1
          )
        end

        if node.left ~= 0 then
          self:SetBranchTexture(
            TALENT_BRANCH_TEXTURECOORDS.left[node.left],
            x_offset - TALENT_BUTTON_SIZE,
            y_offset
          )
        end

        if node.right ~= 0 then
          local next_node = self.branch_nodes[row][col + 1]
          if next_node and next_node.left ~= 0 and next_node.down < 0 then
            self:SetBranchTexture(
              TALENT_BRANCH_TEXTURECOORDS.right[next_node.down],
              x_offset + TALENT_BUTTON_SIZE,
              y_offset
            )
          else
            self:SetBranchTexture(
              TALENT_BRANCH_TEXTURECOORDS.right[node.right],
              x_offset + TALENT_BUTTON_SIZE + 1,
              y_offset
            )
          end
        end

        if node.right_arrow ~= 0 then
          self:SetArrowTexture(
            TALENT_ARROW_TEXTURECOORDS.right[node.right_arrow],
            x_offset + TALENT_BUTTON_SIZE / 2 + 5,
            y_offset
          )
        end

        if node.left_arrow ~= 0 then
          self:SetArrowTexture(
            TALENT_ARROW_TEXTURECOORDS.left[node.left_arrow],
            x_offset - TALENT_BUTTON_SIZE / 2 - 5,
            y_offset
          )
        end

        if node.top_arrow ~= 0 then
          self:SetArrowTexture(
            TALENT_ARROW_TEXTURECOORDS.top[node.top_arrow],
            x_offset,
            y_offset + TALENT_BUTTON_SIZE / 2 + 5
          )
        end
      else
        if node.up ~= 0 and node.left ~= 0 and node.right ~= 0 then
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.tup[node.up], x_offset, y_offset)
        elseif node.down ~= 0 and node.left ~= 0 and node.right ~= 0 then
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.tdown[node.down], x_offset, y_offset)
        elseif node.left ~= 0 and node.down ~= 0 then
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.topright[node.left], x_offset, y_offset)
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.down[node.down], x_offset, y_offset - 32)
        elseif node.left ~= 0 and node.up ~= 0 then
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.bottomright[node.left], x_offset, y_offset)
        elseif node.left ~= 0 and node.right ~= 0 then
          self:SetBranchTexture(
            TALENT_BRANCH_TEXTURECOORDS.right[node.right],
            x_offset + TALENT_BUTTON_SIZE,
            y_offset
          )
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.left[node.left], x_offset + 1, y_offset)
        elseif node.right ~= 0 and node.down ~= 0 then
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.topleft[node.right], x_offset, y_offset)
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.down[node.down], x_offset, y_offset - 32)
        elseif node.right ~= 0 and node.up ~= 0 then
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.bottomleft[node.right], x_offset, y_offset)
        elseif node.up ~= 0 and node.down ~= 0 then
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.up[node.up], x_offset, y_offset)
          self:SetBranchTexture(TALENT_BRANCH_TEXTURECOORDS.down[node.down], x_offset, y_offset - 32)
          ignore_up = true
        end
      end
    end
  end
end

function SubclassTalents:RefreshConnectors(talents)
  if not self.panel or not self.panel.child then
    return
  end

  self:CreateConnectorLayers()
  self:ResetConnectorNodes()
  self:HideConnectorTextures()
  self.connector_talent_count = 0
  self.connector_dependency_count = 0
  self.connector_branch_draws = 0
  self.connector_arrow_draws = 0

  for _, talent in ipairs(talents or {}) do
    self.connector_talent_count = self.connector_talent_count + 1
    self:SetTalentConnectorNode(talent)
  end

  self:BuildConnectorNodes(talents)
  self:DrawConnectorTextures()

  if self.debug_connectors then
    self:ReportError(string.format(
      "connectors tab=%s talents=%d dependencies=%d branches=%d arrows=%d",
      tostring(self.active_tab),
      self.connector_talent_count or 0,
      self.connector_dependency_count or 0,
      self.connector_branch_draws or 0,
      self.connector_arrow_draws or 0
    ))
  end
end

function SubclassTalents:CreateTabButtons()
  if not self.panel then
    return
  end

  for _, button in ipairs(self.tab_buttons) do
    button:Hide()
  end

  for index, tab_id in ipairs(self.tab_order) do
    local button = self.tab_buttons[index]
    if not button then
      button = CreateFrame("Button", "ChumbaddonSubclassTalentFrameTab" .. index, self.panel, "CharacterFrameTabButtonTemplate")
      self.tab_buttons[index] = button
    end

    button.tab_id = tab_id
    button:SetID(index)
    button:SetText(self.tabs[tab_id] or ("Tree " .. index))
    button:ClearAllPoints()
    if index == 1 then
      button:SetPoint("TOPLEFT", self.panel.scroll, "BOTTOMLEFT", -2, -32)
    else
      button:SetPoint("LEFT", self.tab_buttons[index - 1], "RIGHT", -15, 0)
    end
    button:SetScript("OnClick", function(btn)
      self.active_tab = btn.tab_id
      PlaySound("igCharacterInfoTab")
      self:Refresh()
    end)
    if PanelTemplates_TabResize then
      PanelTemplates_TabResize(button, 0)
    end
    button:Show()
  end
end

function SubclassTalents:TogglePanel()
  self:EnsurePanel()
  if self.panel and self.panel:IsShown() then
    self:LeaveSubclassMode()
  else
    self:ShowPanel()
  end
end

function SubclassTalents:ShowPanel()
  self:EnsurePanel()
  if not self.panel then
    return
  end

  local talent_frame = self.talent_frame or get_talent_frame()
  if talent_frame and not talent_frame:IsShown() then
    if ShowUIPanel then
      ShowUIPanel(talent_frame)
    else
      talent_frame:Show()
    end
  end

  self.subclass_mode = true
  self:HideNativeTalentWidgets()
  self:RefreshClassButtons()

  self:RequestData()
  self.panel:Show()
  self:Refresh()
end

function SubclassTalents:LeaveSubclassMode(silent)
  self.subclass_mode = false

  if self.panel then
    self.panel:Hide()
  end

  self:ShowNativeTalentWidgets()
  self:RefreshClassButtons()

  if not silent and self.talent_frame and self.talent_frame:IsShown() then
    if PlayerTalentFrame_Update then
      PlayerTalentFrame_Update()
    elseif TalentFrame_Update then
      TalentFrame_Update(self.talent_frame)
    end
  end
end

function SubclassTalents:OnAddonMessage(prefix, message, channel, sender)
  if prefix ~= self.prefix then
    return
  end

  local player_name = UnitName("player")
  local target, payload = string.match(message or "", "^([^|]+)|(.+)$")
  if target and player_name and target ~= player_name then
    return
  end

  self:ParsePayload(payload or message)
end

function SubclassTalents:ParsePayload(payload)
  if not payload then
    return
  end

  local values = {}
  for part in string.gmatch(payload .. ";", "([^;]*);") do
    local key, value = string.match(part, "^([^=]+)=(.*)$")
    if key then
      values[string.lower(key)] = value
    end
  end

  if values.clear == "1" then
    local previous_active_tab = self.active_tab
    self.subclass_class = tonumber(values.class) or 0
    self.free_points = tonumber(values.free) or 0
    self.used_points = tonumber(values.used) or 0
    wipe_table(self.tabs)
    wipe_table(self.talents)
    wipe_table(self.talents_by_tab)
    wipe_table(self.tab_order)

    for tab_id, name in string.gmatch(values.tabs or "", "(%d+):([^,]+)") do
      tab_id = tonumber(tab_id)
      if tab_id then
        self.tabs[tab_id] = name
        table.insert(self.tab_order, tab_id)
      end
    end

    local preserved = nil
    if previous_active_tab then
      for _, tab_id in ipairs(self.tab_order) do
        if tab_id == previous_active_tab then
          preserved = previous_active_tab
          break
        end
      end
    end
    self.active_tab = preserved or self.tab_order[1]
  end

  if values.talent then
    local fields = {}
    for value in string.gmatch(values.talent, "([^:]+)") do
      table.insert(fields, value)
    end

    local talent = {
      talent_id = tonumber(fields[1]),
      tab_id = tonumber(fields[2]),
      row = tonumber(fields[3]) or 0,
      col = tonumber(fields[4]) or 0,
      max_rank = tonumber(fields[5]) or 0,
      current_rank = tonumber(fields[6]) or 0,
      prereq_talent = tonumber(fields[7]) or 0,
      prereq_rank = tonumber(fields[8]) or 0,
      rank_spells = {},
    }

    for spell_id in string.gmatch(fields[9] or "", "([^/]+)") do
      table.insert(talent.rank_spells, tonumber(spell_id))
    end

    if talent.talent_id and talent.tab_id then
      self.talents[talent.talent_id] = talent
      if not self.talents_by_tab[talent.tab_id] then
        self.talents_by_tab[talent.tab_id] = {}
      end
      table.insert(self.talents_by_tab[talent.tab_id], talent)
      table.sort(self.talents_by_tab[talent.tab_id], sort_by_tab_page)
    end
  end

  if values.done == "1" then
    self:RefreshClassButtons()
    self:Refresh()
  end
end

function SubclassTalents:Refresh()
  if not self.panel then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self.pending_refresh = true
    return
  end

  local class_name = CLASS_NAMES[self.subclass_class] or "Subclass"
  if self.subclass_mode then
    self:HideNativeTalentWidgets()
  end

  self.panel.title:SetText(string.format("%s Talents", class_name))
  self.panel.spent:SetText(string.format("%s: %d", class_name, self.used_points or 0))
  self.panel.points:SetText(string.format("Unspent talent points: |cffffffff%d|r", self.free_points or 0))

  if not self.subclass_class or self.subclass_class == 0 then
    self.panel.status:SetText("No active subclass")
  else
    self.panel.status:SetText("")
  end

  self:CreateTabButtons()
  self:RefreshClassButtons()

  local active_tab_index = 1
  for index, tab_id in ipairs(self.tab_order) do
    local button = self.tab_buttons[index]
    if tab_id == self.active_tab then
      active_tab_index = index
      if button then
        if button.SetChecked then
          button:SetChecked(true)
        elseif PanelTemplates_SelectTab then
          PanelTemplates_SelectTab(button)
        end
      end
    elseif button then
      if button.SetChecked then
        button:SetChecked(false)
      elseif PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(button)
      end
    end
  end

  local background = TALENT_BACKGROUNDS[self.subclass_class] and TALENT_BACKGROUNDS[self.subclass_class][active_tab_index] or "MageFire"
  local base = "Interface\\TalentFrame\\" .. background .. "-"
  self.panel.bg_top_left:SetTexture(base .. "TopLeft")
  self.panel.bg_top_right:SetTexture(base .. "TopRight")
  self.panel.bg_bottom_left:SetTexture(base .. "BottomLeft")
  self.panel.bg_bottom_right:SetTexture(base .. "BottomRight")
  set_desaturated(self.panel.bg_top_left, false)
  set_desaturated(self.panel.bg_top_right, false)
  set_desaturated(self.panel.bg_bottom_left, false)
  set_desaturated(self.panel.bg_bottom_right, false)

  for _, button in ipairs(self.buttons) do
    button:Hide()
  end

  local talents = self.talents_by_tab[self.active_tab] or {}
  local max_row = 4
  for index, talent in ipairs(talents) do
    local button = self.buttons[index]
    if not button then
      break
    end

    local spell_id = talent.rank_spells[math.max(1, talent.current_rank)] or talent.rank_spells[1]
    local name, _, icon = GetSpellInfo(spell_id or 0)
    button.talent = talent
    button.spell_id = spell_id
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", self.panel.child, "TOPLEFT", TALENT_OFFSET_X + talent.col * TALENT_SPACING, -(TALENT_OFFSET_Y + talent.row * TALENT_SPACING))
    button.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.rank:SetText(string.format("%d/%d", talent.current_rank or 0, talent.max_rank or 0))

    local learned = (talent.current_rank or 0) > 0
    local spendable = self:IsTalentSpendable(talent)
    set_desaturated(button.icon, not learned and not spendable)

    if (talent.current_rank or 0) >= (talent.max_rank or 0) then
      button.icon:SetVertexColor(1, 1, 1)
      button.border:SetVertexColor(1.0, 0.82, 0)
      button.rank:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    elseif spendable then
      button.icon:SetVertexColor(1, 1, 1)
      button.border:SetVertexColor(0.1, 1.0, 0.1)
      button.rank:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
      button:Enable()
    elseif learned then
      button.icon:SetVertexColor(1, 1, 1)
      button.border:SetVertexColor(1.0, 0.82, 0)
      button.rank:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
      button:Enable()
    else
      button.icon:SetVertexColor(0.45, 0.45, 0.45)
      button.border:SetVertexColor(0.5, 0.5, 0.5)
      button.rank:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
      button:Enable()
    end

    if button.rank_border then
      button.rank_border:Show()
    end

    max_row = math.max(max_row, talent.row or 0)
    button:Show()
  end

  self:RefreshConnectors(talents)
  self.panel.child:SetHeight(math.max(332, TALENT_OFFSET_Y + ((max_row or 0) + 1) * TALENT_SPACING + 20))
end

function SubclassTalents:IsTalentSpendable(talent)
  if not talent or (talent.current_rank or 0) >= (talent.max_rank or 0) then
    return false
  end

  if (self.free_points or 0) <= 0 then
    return false
  end

  if ((talent.row or 0) * 5) > self:GetSpentInTab(talent.tab_id) then
    return false
  end

  if talent.prereq_talent and talent.prereq_talent > 0 then
    local prereq = self.talents[talent.prereq_talent]
    if not prereq or (prereq.current_rank or 0) <= (talent.prereq_rank or 0) then
      return false
    end
  end

  return true
end

function SubclassTalents:GetSpentInTab(tab_id)
  local total = 0
  for _, talent in ipairs(self.talents_by_tab[tab_id] or {}) do
    total = total + (talent.current_rank or 0)
  end
  return total
end

function SubclassTalents:SpendTalent(talent)
  if not talent then
    return
  end

  if not self:IsTalentSpendable(talent) then
    return
  end

  if SendAddonMessage then
    local player_name = UnitName("player")
    if player_name then
      SendAddonMessage(self.prefix, string.format("spend=%d:%d", talent.talent_id, talent.current_rank or 0), "WHISPER", player_name)
    end
  end
end

function SubclassTalents:ShowTalentTooltip(button)
  if not button or not button.talent then
    return
  end

  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if button.spell_id and GameTooltip.SetHyperlink then
    GameTooltip:SetHyperlink("spell:" .. button.spell_id)
  else
    GameTooltip:SetText("Subclass Talent")
  end
  GameTooltip:AddLine(string.format("Rank %d/%d", button.talent.current_rank or 0, button.talent.max_rank or 0), 1, 1, 1)
  GameTooltip:Show()
end

function SubclassTalents:ReportError(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s %s", self.debug_prefix, tostring(message)))
  else
    print(string.format("%s %s", self.debug_prefix, tostring(message)))
  end
end
