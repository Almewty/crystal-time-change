# Crystal Time Change

A small mod for **Pokémon Crystal in Gen1Recomp 0.3.98**, including Android.
Adds **CHANGE TIME** to the main menu with CONTINUE / NEW GAME / OPTION.
Set the in-game hour, minute, and weekday without changing Android's clock.

## Install on Android

1. Back up your save first (the launcher's duplicate-save-slot feature is suitable).
2. Download `crystal-time-change-1.0.0.zip` supplied with the mod. Alternatively,
   GitHub's **Code → Download ZIP** also contains a single mod root and manifest.
3. In Gen1Recomp's launcher, open **MODS → Import mod .zip** and pick the ZIP.
   Do not unpack it first.
4. Enable **Crystal Time Change** for Crystal and launch the game again.
5. At the main menu, choose **CHANGE TIME**. It appears only when a save exists.

## Controls

Uses the existing Android touch D-pad and A/B buttons, or a controller/keyboard.

- **Up / Down:** choose HOUR, MINUTE, DAY, SAVE CLOCK, or CANCEL.
- **Left / Right:** change the highlighted field. Hours use **24-hour time**:
  `00` = midnight, `12` = noon, `20` = 8 PM. Values wrap at either end.
- Highlight **SAVE CLOCK**, then press **A** to write the change immediately.
- **B** or **CANCEL → A** discards the edits and returns to the main menu.

After saving, the main-menu clock updates. Choose CONTINUE normally.
The clock keeps running from your chosen time, including while the app is closed.
The change persists even if you disable the mod later. No original-cartridge
clock-reset password is needed.

## Save safety and limitations

- Uses Gen1Recomp's native save writer for the **currently selected save slot**,
  including its `.bak` and temporary-file recovery behavior. It does not edit ROMs.
- Edits a copy of the main menu's loaded save, not a possibly stale `game.save`.
  Only after a successful write is that candidate handed to CONTINUE.
- `SAVE FAILED` means the writer failed; the editor stays open for retry or B.
  A failure before staging preserves the old disk clock. If the engine fails
  **after staging but while replacing the primary file**, a restart may recover
  the **new** clock from `.tmp` even though the editor reported failure. Retry
  SAVE CLOCK to finish the write; the native `.bak` retains the previous save.
  The mod does not replace or bypass this engine recovery mechanism.
  Normal engine save normalization and `savedAt` metadata also run on a write.
- Weekday-change notifications to other mods are deferred until a successful
  write, so a failed attempt does not announce a change that was not committed.
- Time-sensitive encounters and daily events can be affected by clock/weekday changes.
  This is not a daily-event-reset mod and does not clear event flags or cooldowns.
- The clock remains based on the device clock plus the chosen offset. Changing the
  device clock/time zone later can still affect it; the mod does not freeze time.
- Crystal only. Compatibility is intentionally restricted to **0.3.98** until other
  versions are tested. Other games do not load the mod.
- A mod that also replaces the `Gen2MainMenu` screen may conflict. This mod leaves
  the original main-menu module unchanged and preserves its menu hooks/actions.
- Declares `engine_internals` because 0.3.98 has no public clock-setting API and
  its Gen 2 menu does not execute callbacks on injected menu items. It wraps the
  screen factory through the registry and decorates only its own menu instances.
  It requests no network or host-filesystem permission.

## Development and verification

Requires Python 3 and LuaJIT, plus the upstream Gen1Recomp **v0.3.98** sources
(commit `4312fb64c927b8892091075f159f09d7a211d4b5`). No ROM is needed for the tests.

```sh
git clone --depth 1 --branch v0.3.98 https://github.com/bryanthaboi/gen1recomp.git
cd gen1recomp
luajit /absolute/path/to/crystal-time-change/tests/run.lua /absolute/path/to/crystal-time-change
```

Tests load the actual mod through the pinned engine's loader and sandbox, build
its real main menu and editor, drive input, exercise drawing calls, and round-trip
saves through the real save implementation with the upstream in-memory filesystem.
Headless drawing uses an ASCII test charmap, not extracted Pokémon art. No physical
Android device, ROM-backed full playthrough, or pixel-perfect rendering is covered.
The intentional write-failure tests produce expected engine error logs.

Build the installable ZIP (runtime files only):

```sh
python3 tools/package.py
```

The archive is written to `dist/`. Tests and build tools are not shipped in it.

## License

MIT; see [LICENSE](LICENSE). This repository contains no Nintendo assets, ROMs,
or copied engine implementation. Gen1Recomp engine modules are used at runtime.
