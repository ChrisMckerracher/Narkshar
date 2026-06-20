SpellRunes = {}
SpellRunes.__index = SpellRunes

function SpellRunes:new()
  local o = setmetatable({}, self)
  o.active = true
  o.spell_rune_name = "Spell Rune"
  o.spell_bag_name = "Spell Rune Bag"
  o.spell_rune_icon = "Interface\\Icons\\INV_Misc_Rune_11"
  o.spell_bag_icon = "Interface\\Icons\\INV_Enchant_EssenceArcaneLarge"
  o.custom_item_icons = {
    [910200] = "Interface\\Icons\\INV_Weapon_ShortBlade_05",
    [910201] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    [910205] = "Interface\\Icons\\INV_Sword_2H_Blood_B_01",
    [910206] = "Interface\\Icons\\INV_Sword_2H_Blood_B_01",
    [910210] = "Interface\\Icons\\INV_Helmet_125",
    [910211] = "Interface\\Icons\\INV_Shoulder_92",
    [910212] = "Interface\\Icons\\INV_Chest_Plate11",
    [910213] = "Interface\\Icons\\INV_Belt_12",
    [910214] = "Interface\\Icons\\INV_Pants_Cloth_27",
    [910215] = "Interface\\Icons\\INV_Boots_Plate_05",
    [910216] = "Interface\\Icons\\INV_Bracer_17",
    [910217] = "Interface\\Icons\\INV_Gauntlets_32",
    [910218] = "Interface\\Icons\\INV_Misc_Cape_19",
    [910230] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    [910231] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    [910232] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    [910233] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    [910234] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
    [910240] = "Interface\\Icons\\INV_Wand_02",
    [910241] = "Interface\\Icons\\Spell_Holy_AvengersShield",
    [910220] = "Interface\\Icons\\INV_Staff_01",
    [910221] = "Interface\\Icons\\INV_Misc_Book_03",
    [910222] = "Interface\\Icons\\INV_Misc_Book_03",
    [910223] = "Interface\\Icons\\INV_Misc_Book_03",
    [910224] = "Interface\\Icons\\INV_Fishingpole_02",
    [910225] = "Interface\\Icons\\Spell_Frost_FrostBlast",
    [910242] = "Interface\\Icons\\INV_Misc_Eye_03",
    [910243] = "Interface\\Icons\\INV_Mace_05",
    [910244] = "Interface\\Icons\\Spell_Shadow_BrainWash",
    [910245] = "Interface\\Icons\\INV_Offhand_OutlandRaid_03White",
    [910246] = "Interface\\Icons\\Ability_Hunter_BeastSoothe",
    [910247] = "Interface\\Icons\\INV_Weapon_Rifle_05",
    [910248] = "Interface\\Icons\\INV_Jewelry_Ring_12",
    [910249] = "Interface\\Icons\\INV_Helmet_31",
    [910250] = "Interface\\Icons\\Spell_Holy_FistOfJustice",
  }
  o.custom_item_names = {
    ["Hilt of the Shattered Rune Blade"] = 910200,
    ["Shard of the Shattered Rune Blade"] = 910201,
    ["Unruned Runeblade"] = 910205,
    ["Runeblade of Arugal"] = 910206,
    ["Fallen Rider's Hood"] = 910210,
    ["Fallen Rider's Pauldrons"] = 910211,
    ["Fallen Rider's Hauberk"] = 910212,
    ["Fallen Rider's Girdle"] = 910213,
    ["Fallen Rider's Legguards"] = 910214,
    ["Fallen Rider's Sabatons"] = 910215,
    ["Fallen Rider's Bindings"] = 910216,
    ["Fallen Rider's Grips"] = 910217,
    ["Fallen Rider's Shroud"] = 910218,
    ["Dread Rod"] = 910220,
    ["Herald of the Dreamer"] = 910221,
    ["Herald of the Old Gods"] = 910222,
    ["Herald of Elune"] = 910223,
    ["Lee Brown's Backup Rod"] = 910224,
    ["Fishing Cooler"] = 910225,
    ["Symbol of the Argent Dawn"] = 910240,
    ["Bulwark of the Argent Dawn"] = 910241,
    ["Murlaga's Rotting Eye"] = 910242,
    ["Small's Beating Stick"] = 910243,
    ["Tuffscale's Brain"] = 910244,
    ["Churrlugggg's Whistle"] = 910245,
    ["Murbean's Bare Wrists"] = 910246,
    ["Glugglug's Moaning Rifle"] = 910247,
    ["Funnyfish's Rigor Mortis Finger"] = 910248,
    ["Half Eaten Fishing Hat"] = 910249,
    ["Right Hand of VanCleef"] = 910250,
  }
  o.keywords = {
    rune_item = { ids = { 900401 }, icon = o.spell_rune_icon, name = o.spell_rune_name },
    rune_bag = { ids = { 900402 }, icon = o.spell_bag_icon, name = o.spell_bag_name },
  }
  o.equipment_slots = {
    "AmmoSlot",
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "ShirtSlot",
    "TabardSlot",
    "WristSlot",
    "HandsSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot",
    "MainHandSlot",
    "SecondaryHandSlot",
    "RangedSlot",
  }
  return o
end

function SpellRunes:register()
  if self.frame then
    return
  end

  self.frame = CreateFrame("Frame")
  local frame = self.frame
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_LEVEL_UP")
  frame:RegisterEvent("BAG_UPDATE")
  frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  frame:RegisterEvent("MERCHANT_SHOW")
  frame:RegisterEvent("MERCHANT_UPDATE")
  frame:SetScript("OnEvent", function(_, event, ...)
    self:OnEvent(event, ...)
  end)

  if ContainerFrame_Update then
    hooksecurefunc("ContainerFrame_Update", function(container)
      self:ApplyToContainerFrame(container)
    end)
  end

  if BagSlotButton_Update then
    hooksecurefunc("BagSlotButton_Update", function(button)
      self:ApplyToBagButton(button)
    end)
  end

  if SetItemButtonTexture then
    hooksecurefunc("SetItemButtonTexture", function(button)
      self:ApplyToKnownItemButton(button)
    end)
  end

  if PaperDollItemSlotButton_Update then
    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
      self:ApplyToEquipmentSlot(button)
    end)
  end

  if MerchantFrame_UpdateMerchantInfo then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
      self:RefreshMerchant()
    end)
  elseif MerchantFrame_Update then
    hooksecurefunc("MerchantFrame_Update", function()
      self:RefreshMerchant()
    end)
  end

  GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
    self:OnTooltipSetItem(tooltip)
  end)

  ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
    self:OnTooltipSetItem(tooltip)
  end)

  self:RefreshAllContainers()
  self:RefreshVisibleItemButtons()
  self:RefreshBagBar()
  self:RefreshEquipment()
  self:RefreshMerchant()
  self:ScheduleRefresh()
end

function SpellRunes:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:RefreshAllContainers()
    self:RefreshVisibleItemButtons()
    self:RefreshBagBar()
    self:RefreshEquipment()
    self:RefreshMerchant()
    self:ScheduleRefresh()
  elseif event == "PLAYER_LEVEL_UP" then
    self:RefreshAllContainers()
    self:RefreshVisibleItemButtons()
    self:RefreshBagBar()
    self:RefreshEquipment()
    self:ScheduleRefresh()
  elseif event == "BAG_UPDATE" then
    self:RefreshContainer(...)
    self:RefreshVisibleItemButtons()
    self:ScheduleRefresh()
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    self:RefreshVisibleItemButtons()
    self:RefreshBagBar()
    self:RefreshEquipment()
    self:ScheduleRefresh()
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    self:RefreshAllContainers()
    self:RefreshVisibleItemButtons()
    self:RefreshBagBar()
    self:RefreshEquipment()
    self:RefreshMerchant()
    self:ScheduleRefresh()
  elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
    self:RefreshMerchant()
  end
end

function SpellRunes:ScheduleRefresh()
  if not self.frame then
    return
  end

  self.refresh_delay = 0.10
  self.frame:SetScript("OnUpdate", function(frame, elapsed)
    self.refresh_delay = (self.refresh_delay or 0) - elapsed
    if self.refresh_delay > 0 then
      return
    end

    frame:SetScript("OnUpdate", nil)
    self:RefreshAllContainers()
    self:RefreshVisibleItemButtons()
    self:RefreshBagBar()
    self:RefreshEquipment()
  end)
end

function SpellRunes:RefreshContainer(bag_id)
  if bag_id == nil then
    return
  end

  for frame_index = 1, NUM_CONTAINER_FRAMES or 13 do
    local frame = _G["ContainerFrame" .. frame_index]
    if frame and frame:GetID() == bag_id then
      self:ApplyToContainerFrame(frame)
      break
    end
  end
end

function SpellRunes:RefreshAllContainers()
  for frame_index = 1, NUM_CONTAINER_FRAMES or 13 do
    local frame = _G["ContainerFrame" .. frame_index]
    if frame and frame:GetID() ~= nil then
      self:ApplyToContainerFrame(frame)
    end
  end
end

function SpellRunes:ApplyToContainerFrame(frame)
  if not frame.size or frame.size == 0 then
    return
  end

  local bag_id = frame:GetID()

  for button_index = 1, frame.size do
    local button = _G[frame:GetName() .. "Item" .. button_index]
    if button then
      local slot = button:GetID()
      local texture, _, _, _, _, _, item_link = GetContainerItemInfo(bag_id, slot)
      local icon = _G[button:GetName() .. "IconTexture"]
      local item_id = self:GetContainerItemId(bag_id, slot, item_link) or self:GetContainerItemIdFromTooltip(bag_id, slot)
      if item_id and icon then
        local override_name, override_icon = self:GetOverrideDataForItemId(item_id)
        if override_icon then
          icon:SetTexture(override_icon)
        elseif texture then
          icon:SetTexture(texture)
        end
        button.spellRunesOverrideName = override_name
      else
        if icon and texture then
          icon:SetTexture(texture)
        end
        button.spellRunesOverrideName = nil
      end
    end
  end
end

function SpellRunes:SetButtonIcon(button, icon)
  if not button or not icon then
    return
  end

  local texture = button.icon
  if not texture and button.GetName and button:GetName() then
    texture = _G[button:GetName() .. "IconTexture"]
  end
  if texture then
    texture:SetTexture(icon)
  end
end

function SpellRunes:ApplyToBagSlotButton(button, bag_id, slot)
  if not button or bag_id == nil or not slot then
    return false
  end

  local _, _, _, _, _, _, item_link = GetContainerItemInfo(bag_id, slot)
  local item_id = self:GetContainerItemId(bag_id, slot, item_link) or self:GetContainerItemIdFromTooltip(bag_id, slot)
  if not item_id then
    return false
  end

  local override_name, override_icon = self:GetOverrideDataForItemId(item_id)
  if not override_icon then
    return false
  end

  self:SetButtonIcon(button, override_icon)
  button.spellRunesOverrideName = override_name
  return true
end

function SpellRunes:GetBagSlotFromButton(button)
  if not button then
    return nil, nil
  end

  local slot = button.GetID and button:GetID()
  if not slot then
    return nil, nil
  end

  if button.GetBag then
    local ok, bag_id = pcall(button.GetBag, button)
    if ok and bag_id ~= nil then
      return bag_id, slot
    end
  end

  local parent = button.GetParent and button:GetParent()
  if parent and parent.GetID then
    local bag_id = parent:GetID()
    if bag_id ~= nil then
      return bag_id, slot
    end
  end

  return nil, nil
end

function SpellRunes:ApplyToKnownItemButton(button)
  local name = button and button.GetName and button:GetName()
  if not name or (not string.match(name, "^ContainerFrame%d+Item%d+$") and
      not string.match(name, "^DragonUI_CombuctorItem%d+$")) then
    return false
  end

  local bag_id, slot = self:GetBagSlotFromButton(button)
  if bag_id == nil or not slot then
    return false
  end
  return self:ApplyToBagSlotButton(button, bag_id, slot)
end

function SpellRunes:RefreshVisibleItemButtons()
  -- DragonUI's Combuctor module renders its own bag buttons and does not use
  -- Blizzard ContainerFrame_Update, so scan its visible item buttons directly.
  for i = 1, 600 do
    local button = _G["DragonUI_CombuctorItem" .. i]
    if button and (not button.IsVisible or button:IsVisible()) then
      self:ApplyToKnownItemButton(button)
    end
  end
end

function SpellRunes:RefreshBagBar()
  for bag = 0, NUM_BAG_SLOTS do
    local button = _G["CharacterBag" .. bag .. "Slot"]
    if button then
      self:ApplyToBagButton(button)
    end
  end
end

function SpellRunes:ApplyToBagButton(button)
  local inventory_slot = button:GetID()
  if not inventory_slot then
    return
  end

  local item_link = GetInventoryItemLink("player", inventory_slot)
  local item_texture = GetInventoryItemTexture("player", inventory_slot)
  local item_id = self:GetInventoryItemId(inventory_slot, item_link)
  local icon = _G[button:GetName() .. "IconTexture"]
  if not icon then
    return
  end

  if item_id then
    local override_name, override_icon = self:GetOverrideDataForItemId(item_id)
    if override_icon then
      icon:SetTexture(override_icon)
    elseif item_texture then
      icon:SetTexture(item_texture)
    end
    button.spellRunesOverrideName = override_name
  else
    if item_texture then
      icon:SetTexture(item_texture)
    end
    button.spellRunesOverrideName = nil
  end
end

function SpellRunes:ApplyToEquipmentSlot(button, slot_id)
  if not button then
    return
  end

  local slot = slot_id or (button.GetID and button:GetID())
  if not slot then
    return
  end

  local icon = button.icon or _G[button:GetName() .. "IconTexture"]
  if not icon then
    return
  end

  local item_link = GetInventoryItemLink("player", slot)
  local item_texture = GetInventoryItemTexture("player", slot)
  local item_id = self:GetInventoryItemId(slot, item_link)

  if item_id then
    local override_name, override_icon = self:GetOverrideDataForItemId(item_id)
    if override_icon then
      icon:SetTexture(override_icon)
    elseif item_texture then
      icon:SetTexture(item_texture)
    end
    button.spellRunesOverrideName = override_name
  else
    if item_texture then
      icon:SetTexture(item_texture)
    end
    button.spellRunesOverrideName = nil
  end
end

function SpellRunes:RefreshEquipment()
  if not self.equipment_slots then
    return
  end

  for _, slot_name in ipairs(self.equipment_slots) do
    local slot_id = GetInventorySlotInfo(slot_name)
    if slot_id then
      local button = _G["Character" .. slot_name]
      if button then
        self:ApplyToEquipmentSlot(button, slot_id)
      end
    end
  end
end

function SpellRunes:RefreshMerchant()
  if not MerchantFrame or not MerchantFrame:IsShown() then
    return
  end

  local per_page = MERCHANT_ITEMS_PER_PAGE or 10
  local page = MerchantFrame.page or 1
  local offset = (page - 1) * per_page

  for button_index = 1, per_page do
    local item_index = offset + button_index
    local button = _G["MerchantItem" .. button_index]
    if button then
      self:ApplyToMerchantButton(button, item_index)
    end
  end
end

function SpellRunes:ApplyToMerchantButton(button, item_index)
  if not item_index then
    return
  end

  local name, texture = GetMerchantItemInfo(item_index)
  local item_link = GetMerchantItemLink and GetMerchantItemLink(item_index)
  local item_id = self:GetItemIdFromLink(item_link)
  if not item_id and name then
    item_id = self:GetItemIdByKnownName(name)
  end

  local override_name, override_icon = self:GetOverrideDataForItemId(item_id)
  local icon = _G[button:GetName() .. "ItemButtonIconTexture"] or _G[button:GetName() .. "IconTexture"]
  if icon then
    if override_icon then
      icon:SetTexture(override_icon)
    elseif texture then
      icon:SetTexture(texture)
    end
  end

  local name_text = _G[button:GetName() .. "Name"]
  if name_text and override_name then
    name_text:SetText(override_name)
  end
end

function SpellRunes:GetOverrideData(item_link)
  if not self.active then
    return nil, nil
  end

  local item_id = self:GetItemIdFromLink(item_link)
  if not item_id then
    return nil, nil
  end

  return self:GetOverrideDataForItemId(item_id)
end

function SpellRunes:GetOverrideDataForItemId(item_id)
  if not self.active then
    return nil, nil
  end

  if not item_id then
    return nil, nil
  end

  if self:IsRuneItem(item_id) then
    return self.keywords.rune_item.name, self.keywords.rune_item.icon
  end

  if self:IsRuneBagItem(item_id) then
    return self.keywords.rune_bag.name, self.keywords.rune_bag.icon
  end

  if self.custom_item_icons and self.custom_item_icons[item_id] then
    return nil, self.custom_item_icons[item_id]
  end

  return nil, nil
end

function SpellRunes:GetContainerItemId(bag_id, slot, item_link)
  if GetContainerItemID then
    local item_id = GetContainerItemID(bag_id, slot)
    if item_id then
      return item_id
    end
  end

  return self:GetItemIdFromLink(item_link)
end

function SpellRunes:GetContainerItemIdFromTooltip(bag_id, slot)
  if not self.custom_item_names then
    return nil
  end

  if not self.tooltip then
    self.tooltip = CreateFrame("GameTooltip", "ChumbaddonSpellRunesTooltip", nil, "GameTooltipTemplate")
    self.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
  end

  self.tooltip:ClearLines()
  self.tooltip:SetBagItem(bag_id, slot)

  local name, item_link = self.tooltip:GetItem()
  local item_id = self:GetItemIdFromLink(item_link)
  if item_id then
    return item_id
  end

  if name and self.custom_item_names[name] then
    return self.custom_item_names[name]
  end

  local first_line = _G["ChumbaddonSpellRunesTooltipTextLeft1"]
  if first_line and first_line:GetText() then
    return self.custom_item_names[first_line:GetText()]
  end

  return nil
end

function SpellRunes:GetInventoryItemId(slot, item_link)
  if GetInventoryItemID then
    local item_id = GetInventoryItemID("player", slot)
    if item_id then
      return item_id
    end
  end

  return self:GetItemIdFromLink(item_link)
end

function SpellRunes:GetItemIdByKnownName(name)
  if not name then
    return nil
  end

  if name == self.spell_rune_name then
    return self.keywords.rune_item.ids[1]
  end

  if name == self.spell_bag_name then
    return self.keywords.rune_bag.ids[1]
  end

  return nil
end

function SpellRunes:OnTooltipSetItem(tooltip)
  if not self.active then
    return
  end

  local name, item_link = tooltip:GetItem()
  if not item_link then
    return
  end

  local override_name = nil
  local item_id = self:GetItemIdFromLink(item_link)
  if item_id and self:IsRuneItem(item_id) then
    override_name = self.keywords.rune_item.name
  elseif item_id and self:IsRuneBagItem(item_id) then
    override_name = self.keywords.rune_bag.name
  end

  if not override_name then
    return
  end

  local text = _G[tooltip:GetName() .. "TextLeft1"]
  if text then
    text:SetText(override_name)
    tooltip:Show()
  end
end

function SpellRunes:GetItemIdFromLink(item_link)
  if not item_link then
    return nil
  end
  local item_id = string.match(item_link, "item:(%d+)")
  if item_id then
    return tonumber(item_id)
  end
  return nil
end

function SpellRunes:IsRuneItem(item_id)
  if not item_id then
    return false
  end
  for _, id in ipairs(self.keywords.rune_item.ids) do
    if id == item_id then
      return true
    end
  end
  return false
end

function SpellRunes:IsRuneBagItem(item_id)
  if not item_id then
    return false
  end
  for _, id in ipairs(self.keywords.rune_bag.ids) do
    if id == item_id then
      return true
    end
  end
  return false
end
