-- TooltipText: green effect lines for custom server items.
--
-- The client derives green "Use:/Chance on hit:" tooltip lines from
-- Spell.dbc; our custom items' behaviors live in server Lua, so the client
-- shows nothing. This module appends the authored lines (content workshop)
-- to item tooltips. Limitation: appended at the bottom of the tooltip -
-- 3.3.5 cannot insert mid-tooltip without rebuilding it.
--
-- To change wording: edit the table below.

TooltipText = {}
TooltipText.__index = TooltipText

function TooltipText:new()
  local o = setmetatable({}, self)
  o.active = true
  o.lines = {
    [910200] = { -- Hilt of the Shattered Rune Blade
      "Use: Combine with four Shards of the Shattered Rune Blade to reforge the blade",
    },
    [910205] = { -- Unruned Runeblade
      "Use: Absorb the soul that it calls for, gaining a Rune",
    },
    [910206] = { -- Runeblade of Arugal
      "Chance on hit: Blasts the target for 24 Frost and 24 Shadow Damage.",
      "Use: Pierce your soul, and die.",
    },
    [910221] = { -- Herald of the Dreamer
      "Chance on hit: Slumber, and witness the Emerald Dream",
    },
    [910222] = { -- Herald of the Old Gods
      "Chance on hit: Gaze into the abyss of the Old Gods, causing you and nearby party members to descend into madness",
    },
    [910223] = { -- Herald of Elune
      "Chance on hit: Unleash your primal instincts, likely for worse...",
    },
    [910242] = { -- Murlaga's Rotting Eye
      "Use: Call forth the power of the storms. (10 Min Cooldown)",
    },
    [910246] = { -- Murbean's Bare Wrists
      "Use: Call forth the power of the Light to adorn yourself in a necessary amount of protection. (30 Min Cooldown)",
    },
  }
  return o
end

function TooltipText:linesFor(link)
  if not link then
    return nil
  end
  local itemId = tonumber(string.match(link, "item:(%d+)"))
  if not itemId then
    return nil
  end
  return self.lines[itemId]
end

function TooltipText:append(tooltip)
  if tooltip.chumbaTooltipTextDone then
    return
  end
  local _, link = tooltip:GetItem()
  local lines = self:linesFor(link)
  if not lines then
    return
  end
  tooltip.chumbaTooltipTextDone = true
  for _, text in ipairs(lines) do
    tooltip:AddLine(text, 0, 1, 0, true)
  end
  tooltip:Show()
end

function TooltipText:hook(tooltip)
  if not tooltip then
    return
  end
  tooltip:HookScript("OnTooltipSetItem", function(tt)
    if self.active then
      self:append(tt)
    end
  end)
  tooltip:HookScript("OnTooltipCleared", function(tt)
    tt.chumbaTooltipTextDone = nil
  end)
end

function TooltipText:register()
  if self.hooked then
    return
  end
  self.hooked = true
  self:hook(GameTooltip)
  self:hook(ItemRefTooltip)
  self:hook(ShoppingTooltip1)
  self:hook(ShoppingTooltip2)
  self:hook(ItemRefShoppingTooltip1)
  self:hook(ItemRefShoppingTooltip2)
end

local tooltipText = TooltipText:new()
tooltipText:register()
