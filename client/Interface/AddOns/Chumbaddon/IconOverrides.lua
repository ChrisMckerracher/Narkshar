-- IconOverrides: client-side icon replacements for custom server items.
--
-- Custom items borrow stock display IDs server-side, which couples their
-- icon to the borrowed model. This module repaints specific item IDs with
-- the icons chosen in the content workshop, without any DBC patching.
--
-- To change an icon: edit the table below (icon names are the standard
-- Interface\\Icons texture names, lowercase ok).

IconOverrides = {}
IconOverrides.__index = IconOverrides

function IconOverrides:new()
  local o = setmetatable({}, self)
  o.active = true
  o.overrides = {
    -- Herald trinkets (Keepers of the Storm part 1 rewards)
    [910221] = "Interface\\Icons\\INV_Misc_Book_03",
    [910222] = "Interface\\Icons\\INV_Misc_Book_03",
    [910223] = "Interface\\Icons\\INV_Misc_Book_03",
    -- Fishing Cooler ("Ray of Frost" look)
    [910225] = "Interface\\Icons\\Spell_Frost_FrostBlast",
    -- Workshop-authored boss/reward items
    [910240] = "Interface\\Icons\\INV_Wand_02",
    [910241] = "Interface\\Icons\\Spell_Holy_AvengersShield",
    [910242] = "Interface\\Icons\\INV_Misc_Eye_03",
    [910243] = "Interface\\Icons\\INV_Mace_05",
    [910244] = "Interface\\Icons\\Spell_Shadow_BrainWash",
    [910245] = "Interface\\Icons\\INV_Offhand_OutlandRaid_03White",
    [910246] = "Interface\\Icons\\Ability_Hunter_BeastSoothe",
    [910247] = "Interface\\Icons\\INV_Weapon_Rifle_05",
    [910248] = "Interface\\Icons\\INV_Jewelry_Ring_12",
    [910250] = "Interface\\Icons\\Spell_Holy_FistOfJustice",
  }
  return o
end

function IconOverrides:iconFor(itemLink)
  if not itemLink then
    return nil
  end
  local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
  if not itemId then
    return nil
  end
  return self.overrides[itemId]
end

function IconOverrides:repaintContainer(container)
  local frameName = container:GetName()
  local bagId = container:GetID()
  local size = container.size or GetContainerNumSlots(bagId)
  for i = 1, size do
    local button = _G[frameName .. "Item" .. i]
    if button then
      local slot = button:GetID()
      local link = GetContainerItemLink(bagId, slot)
      local icon = self:iconFor(link)
      if icon then
        SetItemButtonTexture(button, icon)
      end
    end
  end
end

function IconOverrides:repaintBags()
  for i = 1, NUM_CONTAINER_FRAMES do
    local frame = _G["ContainerFrame" .. i]
    if frame and frame:IsShown() then
      self:repaintContainer(frame)
    end
  end
end

function IconOverrides:repaintEquipment()
  for _, slotName in ipairs({ "MainHandSlot", "SecondaryHandSlot", "RangedSlot",
      "Trinket0Slot", "Trinket1Slot", "Bag0Slot", "Bag1Slot", "Bag2Slot", "Bag3Slot" }) do
    local slotId = GetInventorySlotInfo(slotName)
    if slotId then
      local link = GetInventoryItemLink("player", slotId)
      local icon = self:iconFor(link)
      if icon then
        local button = _G["Character" .. slotName] or _G["CharacterBag" .. (slotId - 19) .. "Slot"]
        if button then
          SetItemButtonTexture(button, icon)
        end
      end
    end
  end
  -- bottom-right bag bar
  for i = 0, 3 do
    local slotId = GetInventorySlotInfo("Bag" .. i .. "Slot")
    if slotId then
      local link = GetInventoryItemLink("player", slotId)
      local icon = self:iconFor(link)
      if icon then
        local button = _G["CharacterBag" .. i .. "Slot"]
        if button then
          SetItemButtonTexture(button, icon)
        end
      end
    end
  end
end

function IconOverrides:register()
  if self.frame then
    return
  end

  self.frame = CreateFrame("Frame")
  self.frame:RegisterEvent("PLAYER_LOGIN")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("BAG_UPDATE")
  self.frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  self.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  self.frame:SetScript("OnEvent", function()
    if not self.active then
      return
    end
    self:repaintBags()
    self:repaintEquipment()
  end)

  if ContainerFrame_Update then
    hooksecurefunc("ContainerFrame_Update", function(container)
      if self.active then
        self:repaintContainer(container)
      end
    end)
  end
  if BagSlotButton_Update then
    hooksecurefunc("BagSlotButton_Update", function()
      if self.active then
        self:repaintEquipment()
      end
    end)
  end
end

local iconOverrides = IconOverrides:new()
iconOverrides:register()
