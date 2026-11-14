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
- **Ping type** dropdown: Default (contextual), Attack, Assist, Warning, On My Way
- **Ping!** button → secure action button running the generated macrotext
- **Options ▸** toggle that expands/collapses the options panel (collapsed by default, state remembered)

## Options panel (collapsible)
| Option | Default | Macro effect (verify in-game) |
|---|---|---|
| Exact name match | on | `/targetexact` vs `/target` |
| Skip dead | on | add `/cleartarget [dead]` after targeting |
| Enemies only | off | add `/cleartarget [help]` |
| Friendlies only | off | add `/cleartarget [harm]` (mutually exclusive with Enemies only) |
| Clear target if not found | off | behaviour TBD — targeting by name keeps old target on no match; investigate |
| Return to previous target | off | append `/targetlasttarget` after ping |
| Raid marker | off (dropdown: none/star/…/skull) | `/tm [@target,exists] N` |

Ping line: `/ping [@target,exists]` plus type, e.g. `/ping [@target,exists] attack` — **confirm exact ping-type syntax in Forever**.

## Behaviour
- Rebuild macrotext whenever Name/options/ping type change.
- In combat: inputs disabled (or edits queued) with a visible "locked in combat" note; Ping! still works.
- Warn if macrotext exceeds 255 chars (keep it short anyway).
- Empty name → Ping! button disabled.

## Commands
- `/fp` toggle window · `/fp reset` reset position/settings · `/fp debug` print current macrotext

## Saved settings (`ForeverPingingDB`)
`dbVersion, name, pingType, options{...}, optionsExpanded, position`

## Later (not v0.1)
- Saved list of target names / presets
- Keybinding for the Ping! button (Bindings.xml / `SetBindingClick`)
- Optional: export to a real WoW macro
- Edit Mode integration
