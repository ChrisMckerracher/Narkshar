# Keepers of the Storm AddOn

Wrath 3.3.5 client-side encounter UI helpers for Keepers of the Storm.

Current behavior:

- Shows `??` in the default target/focus level text for KOTS boss-style mobs.
- Rewrites default tooltips for KOTS boss-style mobs from `Level 25 ...` to `Level ?? ...`.
- Listens for server `KOTS` addon messages and renders `center|...` payloads as center-screen raid-warning style encounter text.
- Current boss-style entries: Protector of the Lake, the five Idol party mobs, Smalls, Biggie, and Murlaga.
- Small's Risen Add is intentionally excluded because it is a normal non-elite add.
- Provides `/kots` as a quick load/target diagnostic command.

This is cosmetic only. Server level, combat math, and other players' clients are unchanged.
