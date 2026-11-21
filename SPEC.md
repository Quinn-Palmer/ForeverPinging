# Forever-Pinging — Spec v0.1

A small window that builds a "target X, then ping it" macro and runs it from a real button.

## Base macro
```
/targetexact Night Watch Guard
/ping [@target,exists]
```

## Main window (always visible — keep it compact)
- **Name:** text box (the unit name to target)
- **Use Current Target** button → fills Name with `UnitName("target")` (out of combat; guard against secret values)
- **Quest mobs** icon button (between Name and Use Current Target) → opens a menu of mob names from
  the quest log; picking one fills Name (see below)
- **Ping type** dropdown: Default (contextual), Attack, Assist, Warning, On My Way, No ping (target only: drops the `/ping` line; marker and attack still apply)
- **Ping!** button → secure action button running the generated macrotext
- **Options ▸** toggle that expands/collapses the options panel (collapsed by default, state remembered)

## Options panel (collapsible)
| Option | Default | Macro effect (verify in-game) |
|---|---|---|
| Exact name match | on | `/targetexact` vs `/target` |
| Skip dead | on | add `/cleartarget [dead]` after targeting |
| Enemies only | off | add `/cleartarget [help]` |
| Friendlies only | off | add `/cleartarget [harm]` (mutually exclusive with Enemies only) |
| Clear target if not found | off | add `/cleartarget` before the search, so a miss leaves no target. **Forced on when an attack is set**, or a miss would cast it at the old target |
| Return to previous target | off | append `/targetlasttarget` after ping |
| Raid marker | off (dropdown: none/star/…/skull) | `/tm [@target,exists] N` |
| Attack | None (dropdown: class abilities / Custom spell...) | `/cast [@target,harm,nodead] <spell>` after the ping (see below) |

Ping line: `/ping [@target,exists]` plus type, e.g. `/ping [@target,exists] attack` — **confirm exact ping-type syntax in Forever**.

## Attack (cast after the ping)
Adds `/cast [@target,harm,nodead] <spell>` after the ping line (before `/targetlasttarget`), so
one press of Ping! / the keybind / the bar macro targets, pings and attacks.
- List per class in `Abilities.lua`: instant, enemy-targeted abilities only (a cast-time spell
  would just start casting). Entries are Classic rank 1 spell IDs; the name is resolved with
  `C_Spell.GetSpellName` so it's localized, and `/cast` by name uses the highest known rank.
- Unlearned abilities are greyed with a "Not learned yet" tooltip but still selectable. Notes
  (stance/form/talent) show in the tooltip.
- **Custom spell...** opens a popup for any spell name not in the list.
- Auto-repeat abilities (Auto Shot, wand Shoot) use `/cast !Name` so a second press doesn't stop them.
- Saved per class in `attackByClass[classFile]` (spell ID or custom name); SavedVariables are
  account-wide, so a shaman's Flame Shock doesn't leak onto a warrior.
- Only one GCD ability per press; `/ping` is off the GCD so it never blocks the cast.

## Quest mobs menu
Built on open from `C_QuestLog.GetQuestObjectives`; parsing lives in `QuestMobs.lua` (pure, unit-tested).
- Lists only **unfinished `monster` (kill) objectives**. Item/event/explore objectives are skipped.
- **Current zone only** by default (`C_QuestLog.IsOnMap`), with a "+N in other zones" line and a
  **Show all zones** checkbox in the menu (remembered as `questMobsAllZones`).
- Same mob in several quests is listed once; its tooltip lists the quests. Label shows progress (`3/8`).
- Mob name = objective text with the count and trailing "slain"/"killed" removed. Custom objective
  text may parse imperfectly; edit the name box if so.
- Menu scrolls past ~300 px as a safety net. Disabled in combat like the other inputs.

## Settings page (Options → AddOns → Forever Pinging)
Built with the Settings API (`Options.lua`). Every control is a proxy setting over a field in
`ns.FIELDS` (Core), and the window and the page both write through `ns.Set`, so a change on one
shows up on the other immediately. Opened from the gear on the window or `/fp options`.
- **Window:** Show window, Theme, Scale (70–150%), Background opacity (0–100%), Lock position,
  Compact mode, Reset position button
- **Ping:** Ping type, Ping cooldown (0–3s, default 1s, 0 = off), Attack (list entries, plus the current custom spell if one is set; custom
  spells are typed in the window), Raid marker
- **Targeting:** the six option checkboxes (Enemies only / Friendlies only stay exclusive)
- **Keybinding:** Macro icon (five target-style icons), Create action bar macro button (same as `/fp macro`)
- The name box is window-only.

## Themes
Defined in `Themes.lua` (pure, unit-tested): Classic Tooltip (default, the original look),
Blizzard Dialog, Dark Minimal, Class Color (Dark Minimal with class-coloured border, title and
Ping! edge), Parchment. Flat themes replace the red button art with flat boxes. Opacity
multiplies the theme's background alpha only. Compact mode hides the title row and close button.
Theme, scale, opacity and compact change the secure button's parent, so in combat they're saved
and applied after combat (with one chat note per fight).

## Behaviour
- Rebuild macrotext whenever Name/options/ping type change.
- In combat: inputs disabled (or edits queued) with a visible "locked in combat" note; Ping! still works.
- Warn if macrotext exceeds 255 chars (keep it short anyway).
- Empty name → Ping! button disabled.

## Commands
- `/fp` toggle window · `/fp options` open the Settings page · `/fp reset` reset position/settings · `/fp debug` print current macrotext
- `/fp macro` create/repair account macro `FP Ping` (`/click ForeverPingingPingButton`) and put it on the cursor for the action bar

## Keybinding
- `Bindings.xml` CLICK binding on `ForeverPingingPingButton` → Keybindings > AddOns
- Ping! button acts on release only (`useOnKeyDown = false`) so mouse, keybind and `/click` each fire once
- Ping cooldown: a `SecureHandlerWrapScript` pre-click snippet drops clicks within `pingCooldown`
  seconds of the last one that went through, so it works in combat. If `GetTime` isn't available in
  the restricted environment, a PreClick fallback throttles out of combat only. **Confirmed on
  1.60.1: `GetTime` is nil in the restricted environment, so the fallback is what runs.** The wrap
  is kept so it starts working in combat if a patch exposes `GetTime`. The value is pushed
  to the handler out of combat (queued during combat)

## Saved settings (`ForeverPingingDB`)
`dbVersion, name, pingType, pingCooldown, options{...}, optionsExpanded, questMobsAllZones, attackByClass{...}, shown, appearance{theme, scale, opacity, locked, compact}, position`

## Later (not v0.1)
- Saved list of target names / presets
- Optional: export to a real WoW macro
- Edit Mode integration
