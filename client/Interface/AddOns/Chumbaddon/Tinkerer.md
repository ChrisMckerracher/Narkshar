# Requirements
Reminder, this is a client addon, so you must follow client addon conventions!

Develop a WoW addon, where each feature is separated into its own folder.:

## Feature 1: Bare Necessities
1. Parse the addon channel, for messages starting with BN_STATUS, and find messages correlating to our player
2. Parse the Hunger, Thirst, Fatigue, and Damage values
3. Display each of these in a bar, where said bar makes lines logically separating individaul values.
   4. ex a bar may have 0|0|0|0|0 indicating 5 values. Denote the | line being what I mean
4. Ensure this bar stays consistent with continual messages sent in the addon channel.
5. Make each bar clearly correlated with one of the resources, with text
6. Make the text yellow when the corresponding resource is at 20% or lower
7. Make the text red when the corresponding resource is 10% or lower
8. Make this bar moveable. See Short summary for more context
### Short summary:

  - Broadcasts now head over the BNSTAT addon channel (PlayerName|label=value...) so client mods can consume resource status directly, with inline docs spelling out the format. scripts/bare_necessities/bn_server_tick.lua:1
  - Dazed no longer auto-clears anywhere; only Resurrection Sickness is removed on recovery, even in campfire handling. scripts/bare_necessities/bn_1_resource.lua:160, scripts/bare_necessities/bn_resource_recovery.lua:1

  Code:

  local payload = string.format("%s|%s", player:GetName(), table.concat(status_parts, ","))
  player:SendAddonMessage(STATUS_ADDON_PREFIX, payload, player)  -- BNSTAT|Player|hunger=45,thirst=32,...

  Test plan:

  - In your addon, call RegisterAddonMessagePrefix("BNSTAT"), log the payload from CHAT_MSG_ADDON, and verify you see strings like PlayerName|hunger=45,thirst=32,fatigue=50,damage=48 arriving every refresh tick.
  - Confirm Hunger/Thirst/Rest Dazed auras persist after recovery while Resurrection Sickness still drops when the damage pool is healthy.
  - Trigger campfire recovery to ensure no debug chat spam remains and that the aura-only logic still increments resources.

## Feature 2: Spell Runes
This server has a special rule, where castable spells consume arrows. 
We will:
1. Modify on the client side, all quivers to be called "Spell Bag"
2. All rough arrows, to be called "Spell Rune"
3. Modify the icon for each to feel more magicy, using a reasonable builtin icon
4. Make sure the above ONLY applies to non-hunters, who are below level 10.
5. Hunters above level 10 should ALSO have these become spell runes