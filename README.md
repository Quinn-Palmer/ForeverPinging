# Forever Pinging

WoW: Forever addon (Interface 16001). It builds a "target X, then ping it" macro and runs it
from a secure button. See [SPEC.md](SPEC.md) for the v0.1 scope.

## Install for testing

```powershell
powershell -ExecutionPolicy Bypass -File tools\install.ps1              # junction (default): edits live, /reload to pick up
powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Mode Copy   # copy only the TOC-listed files
powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Mode Remove # uninstall
```

The default AddOns path is `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`.
Override it with `-AddOnsPath` or the `FOREVER_ADDONS` environment variable.
TOC changes need a full client restart. Lua changes need `/reload`.

## Updating for a new Forever patch

Get the client's interface number with `/dump select(4, GetBuildInfo())`. Put it in
`## Interface:` in the TOC, then restart the client.

## Unit tests

```powershell
pip install lupa
python tests/run_tests.py
```

This syntax-checks every TOC-listed Lua file under Lua 5.1 and runs the `Macro.lua`, `QuestMobs.lua` and `Abilities.lua` tests.

## Commands

`/fp` toggles the window · `/fp options` opens the Settings page · `/fp macro` puts an action-bar macro on your cursor · `/fp reset` resets position and settings · `/fp debug` prints the current macrotext

## Settings page and themes

Options → AddOns → Forever Pinging (or the gear on the window, or `/fp options`) has every
setting: show window, theme, scale, background opacity, lock position, compact mode, reset
position, ping type, attack, raid marker, the targeting checkboxes, and a button for the action
bar macro. It and the window's Options panel stay in sync. The name box and custom attack spells
stay in the window only.

Themes: Classic Tooltip (the original look, default), Blizzard Dialog, Dark Minimal, Class Color
(Dark Minimal in your class colour) and Parchment. Changing the theme, scale, opacity or compact
mode in combat is saved and applied when combat ends, because the window holds the secure Ping! button.

## Keybinding the ping

Either way, the window still sets the name, ping type, attack and options. The keybind just presses Ping!.

- **Action bar:** `/fp macro` creates an account macro `FP Ping` (`/click ForeverPingingPingButton`)
  and puts it on your cursor. Drop it on a bar slot and bind that slot as usual. Running it again
  repairs the macro body if it was edited.
- **Direct keybind:** Options → Keybindings → AddOns → Forever Pinging → "Ping! (target and ping)".

Both work in combat (they're a click on the secure button) and with the window closed.

## Verify in-game (open questions from the spec)

- **AllowLoadGameType.** The TOC uses `forever` per CLAUDE.md. Installed Forever addons
  (Auctionator, EllesmereUI) use `camelot`. If the addon doesn't appear in the AddOns list,
  check this first.
- **Ping type syntax.** This uses numeric aliases (`1` attack, `2` warning, `3` on my way, `4` assist)
  because the word forms only match on English clients.
- **`/tm [@target,exists] N`.** Check that the conditional is accepted. Re-applying the same
  marker may toggle it off.
- **Clear target if not found.** This is implemented as a `/cleartarget` before the search,
  so a miss leaves no target and nothing is pinged.
- **Return to previous target with a missed search.** `/targetlasttarget` may jump to an older
  target when nothing matched, or when combined with "Clear target if not found".
- **Keybind / `/click`.** The button sets `useOnKeyDown = false` so it acts on release only.
  Check that the bar macro and the Keybindings entry each ping exactly once, with
  `ActionButtonUseKeyDown` both on and off (`/console ActionButtonUseKeyDown 0|1`), with the window
  open and closed, and in combat. If the bar macro does nothing, try `/click ForeverPingingPingButton LeftButton 1`.
- **Quest mobs menu.** Check `/dump C_QuestLog.GetQuestObjectives(<questID>)` on a kill quest for the
  real text format (the parser handles `X slain: 3/8` and `3/8 X slain`). Check that `C_QuestLog.IsOnMap`
  filters to the current zone, that the quest icon texture shows, and that `MenuUtil.CreateContextMenu`
  opens the menu.
- **Attack list.** The spell IDs in `Abilities.lua` are Classic rank 1 IDs. For each class, check
  that the menu shows real names (`/dump C_Spell.GetSpellName(8050)` should say Flame Shock), that
  learned spells aren't greyed (`/dump IsPlayerSpell(8050)`), and that `/cast Flame Shock` with no rank
  uses the highest rank. Also check whether Forever changed any cast times (Corruption, Multi-Shot, Exorcism).
- **Attack in the macro.** One press should target, ping and cast. Check the `[@target,harm,nodead]`
  conditional skips friendlies and corpses, and that `/cast !Auto Shot` doesn't toggle Auto Shot off.
- **Combat.** Inputs lock and Ping! still fires. `/fp`, `/fp reset` and the close button queue
  until combat ends.
- **Settings page.** Check that Forever Pinging appears under Options → AddOns, that sliders show
  percentages, and that the section headers and the Reset / Create buttons render
  (`CreateSettingsListSectionHeaderInitializer`, `CreateSettingsButtonInitializer`). Change a checkbox
  on the page with the window's Options panel open, and the other way round, and check both update.
  Change a setting on the page in combat: one "change saved" message, applied when combat ends.
- **Themes.** Check each theme's textures load: the gear (`Interface\WorldMap\Gear_64Grey`), the
  Blizzard dialog border at this window size, and the Parchment background
  (`Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal`). On Dark Minimal and Class Color,
  check the flat buttons hide the red art (template keys `Left`/`Middle`/`Right`), still show a
  hover, and stay flat after pressing and when Ping! is disabled. On Parchment, check the name box
  text is readable.
