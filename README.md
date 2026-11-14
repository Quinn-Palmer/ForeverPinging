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

## Unit tests

```powershell
pip install lupa
python tests/run_tests.py
```

This syntax-checks every TOC-listed Lua file under Lua 5.1 and runs the `Macro.lua` tests.

## Commands

`/fp` toggles the window · `/fp reset` resets position and settings · `/fp debug` prints the current macrotext

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
- **Combat.** Inputs lock and Ping! still fires. `/fp`, `/fp reset` and the close button queue
  until combat ends.
