# AGENTS.md

## Purpose

Support development of **AzerothCore 3.3.5** client addon, with consistent structure and practices.

## Scope & Target

* **Game:** World of Warcraft **3.3.5a**.
* **Scripting:** Lua.
* **Write location:** `Chumbaddon/` (and subfolders). Do not write anywhere else.
* **No escalations or hard limits** in behavior descriptions.

## Operating Rules (Do/Don't)

**Do**

* Place all new code in `Chumbaddon/`.
* Group related behavior into **classes** (Lua OOP pattern) when practical.
* For features that modify player behavior, provide a **class** exposing a `register()` method that performs all engine registrations.
* Keep files **append-only** unless refactoring is explicitly required by the task.

**Don't**

* Do **not** use `require`.
* Do **not** modify anything in `scripts/sub_class/`.
* Do **not** introduce external dependencies or point to outside materials.

## Coding Standards (General Lua)

* **Style**:

  * Indentation: 2 spaces; no tabs.
  * Max line length ~100 chars; wrap thoughtfully.
  * Keep files under 150 lines. You can occasionally make exceptions. Consider breaking up a file into two, with a logical split(not arbitrary)
  * Use `snake_case` for variables/functions; `PascalCase` for classes/tables used as types.
* **Tables & Classes**:

  * Class pattern:

    ```lua
    MyClass = {}
    MyClass.__index = MyClass

    function MyClass:new(arg)
      local o = setmetatable({}, self)
      o.arg = arg
      return o
    end
    ```
  * Prefer explicit constructors; avoid implicit globals.
* **Globals**:

  * Declare locals with `local`; avoid polluting `_G`.
  * Wrap module state in tables; export only what’s needed.
* **Functions**:

  * Single responsibility; short, well‑named.
  * Document parameters and returns via line comments.
* **Error Handling**:

  * Validate inputs; fail fast with clear messages in dev logs.
  * Guard Eluna calls that can be nil or fail.
* **Performance**:

  * Cache repeated lookups (e.g., table lengths, frequently used constants).
  * Avoid hot‑path allocations in tick/event handlers.
* **Logging**:

  * Prefer concise log lines: `[Feature] action – details`.
* **Compatibility**:

  * Stick to Lua 5.1 semantics compatible with Eluna.

## File & Project Conventions

* **Directory layout** (example):

  * `scripts/feature_name/Feature.lua` (class + `register()`)
  * `scripts/feature_name/config.lua` (tunable constants)
  * `scripts/feature_name/events.lua` (event IDs, mappings)
* **One feature per folder**; small utilities may live beside features if truly local.
* **Naming**: `Feature.lua` matches folder `feature_name/`.

## Registration Pattern

Provide a single entry function to register your feature with Eluna:

```lua
-- scripts/my_feature/Feature.lua
MyFeature = {}
MyFeature.__index = MyFeature

function MyFeature:new()
  return setmetatable({}, self)
end

function MyFeature:register()
  -- Example: Player event hooks, creature hooks, commands, etc.
  -- RegisterPlayerEvent(eventId, functionRef)
end

-- Bootstrap
local feature = MyFeature:new()
feature:register()
```

## Test Plan

* **Unit-lite checks** (manual/automated):

  * Load-time: file compiles (no globals leaked); `register()` runs without error.
  * Event hooks: expected handlers fire under correct conditions.
  * Config guards: invalid config values are rejected with clear logs.
* **Gameplay checks**:

  * On a local realm, verify effects on player/creature/world are correct and reversible.
  * Confirm no excessive log spam; check performance under load (e.g., 20+ players).
* **Output Quality Bar** *(applies within Test Plan only)*:

  * No script errors in logs after 10 minutes of mixed play.
  * No unbounded loops or frame hitches from handlers.
  * Feature toggles/configurable behaviors documented in-file.

## Voice & Tone (optional)

For developer-facing prompts, and also anything else, responses must adopt:

* A whimsical **WoW gnomish tinkerer** voice

This is purely stylistic and must not affect technical correctness.hm

## Security & Safety

* Sanitize all inputs received from players/commands.
* Never perform direct file I/O or OS calls.
* Keep all identifiers and constants local to avoid collisions.

## Checklist (Before Submit)

* [ ] Files live under `scripts/` only.
* [ ] No `require` used.
* [ ] Feature encapsulated in a class with `register()`.
* [ ] Adheres to general Lua standards above.
* [ ] Test Plan steps executed; quality bar met.
