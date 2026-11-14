# CLAUDE.md — Forever-Pinging (WoW: Forever addon)

## Target platform
- WoW: Forever, patch 1.60.1, **Interface 16001**. Runs on the modern (Mainline) client with **all Midnight addon restrictions** (secret values, no combat log for addons).
- Do NOT write Classic Era API code. Use the modern API (`C_AddOns`, `C_Timer`, Settings API, etc.).
- TOC: `ForeverPinging_Forever.toc` with `## Interface: 16001` and `## AllowLoadGameType: forever`.
- Lua `require` was renamed to `import` in this client — don't use either name for our own identifiers.
- If unsure an API exists in Forever, say so and suggest checking in-game with `/api` or `/dump`, rather than guessing.

## Key rules
- Targeting and pinging are **protected**. Never call them from addon code. Use a `SecureActionButtonTemplate` button with `type = "macro"` and `macrotext`; the player's click executes it.
- **Never change secure attributes in combat** (`InCombatLockdown()`). Queue edits until `PLAYER_REGEN_ENABLED` and tell the user.
- Don't modify Blizzard protected frames. Use `hooksecurefunc`, not function replacement.
- Never store secret values in SavedVariables; never compare/do math on values that might be secret (`issecretvalue` guard).
- Forever reskinned the player/target/focus frames and minimap header; don't anchor to their children.

## Code conventions
- `local addonName, ns = ...` namespace; no globals except the SavedVariables (`ForeverPingingDB`) and named frames prefixed `ForeverPinging`.
- SavedVariables carry `dbVersion`; merge defaults without overwriting user values.
- Files: `Core.lua` (init, events, slash), `Macro.lua` (macrotext builder — pure functions, easy to test), `UI.lua` (frames), `Locales/enUS.lua`.
- Keep the macro builder pure: input = settings table, output = macrotext string. Print the generated macro in a debug mode (`/fp debug`).

## Testing loop
- Install path: the Forever client's `Interface/AddOns/ForeverPinging/` (verify which folder Forever uses on this machine).
- TOC changes need a full client restart; Lua changes need `/reload`.
- Use BugGrabber + BugSack for errors. Test: out of combat, in combat (button still works, editing is blocked), target dead/alive, no match, gamepad mode.

## Reference
Project knowledge docs (claude.ai project "World of Warcraft: Forever Addons"): platform reference, combat/secrets playbook, UI conventions, data notes.
Sources: https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes · https://warcraft.wiki.gg/wiki/TOC_format · https://warcraft.wiki.gg/wiki/Secret_aspects · https://warcraft.wiki.gg/wiki/SecureActionButtonTemplate

See SPEC.md for what we're building.
