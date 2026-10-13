# The system's Cmd-Tab stays the system's unless the config asks for it

Part of {{UMBRELLA}}.

## What to build

Before this change, the shipped defaults bound `cmd-tab`, `cmd-shift-tab` and `cmd-backtick` to Lenses. Binding the Cmd-Tab pair makes WinMux switch off matching enabled system shortcuts and restore them at exit. Cmd-backtick is registered without disabling its native symbolic hotkey. On Prateek's first install that meant a tester's Cmd-Tab was replaced unasked, and when WinMux crashed, native Cmd-Tab stayed off until it was relaunched and quit.

A fresh install leaves the system's switcher alone. Taking it over is something a person turns on in their config.

## Decisions

- **The shipped defaults bind none of `cmd-tab`, `cmd-shift-tab` and `cmd-backtick`.** With no such binding WinMux disables no system shortcut and has nothing to restore.
- **The system's switcher is the fast switcher.** Prateek chose this on 2026-10-13, with WinMux's `overview` as the view that stays open. The strip is a Lens a person opts into, not the centre of switching.
- **Opting in is config**: the three bindings, written by the person. The takeover, its repair on wake and unlock, and its restore on exit stay as built, and run only for a config that binds those chords.

## Not in this issue

- Removing the takeover or its recovery code.
- A Settings toggle. It may come with **A first run that explains itself**.

## Depends on

Nothing.

## Defaults chosen for you

- **How `recent` and `app-windows` are reached by default.** They stay in the `lens` binding mode (`alt-semicolon`, then a key). The defaults give the strip no held chord: **A short list of default shortcuts** names every default chord, and `alt-tab` is deliberately left free.
- **`config convert`** adds the fork's Triggers to a converted TOML today. It stops adding these three.
- **An existing config that imports the defaults and relied on them** loses Cmd-Tab on upgrade. The release notes and `docs/default-config.md` give the three lines to paste.

## Done when

- [x] With no config, `winmux doctor` reports no held system shortcut and no marker, and macOS's Cmd-Tab works while WinMux runs.
- [x] A config with the three bindings takes Cmd-Tab over as today, and a normal quit, a signal and a relaunch after a hard kill each restore it.
- [x] `docs/default-config.md` and `docs/lenses.md` show the opt-in and say what it does to the system's switcher.
- [x] The helper's default-config tests and the conversion fixture are updated, not deleted.

## Built

Built together with **A short list of default shortcuts**. The defaults contain exactly 41 main chords, with overview on `alt-shift-o`, and `a` in the Lens leader opens `app-windows` as a list. Conversion adds only `alt-slash`, `alt-semicolon` and `alt-shift-o` to TOML modes where unbound; a TOML's own Cmd-Tab command remains unchanged.

Host and guest `make check` pass, with no skipped Swift tests. The debug guest shows empty held/marker sets and Apple's panel with no config, native Cmd-backtick cycling, and three explicit opt-in strips. Normal quit, SIGTERM and hard-kill/relaunch/normal-quit restore Apple's panel and empty the marker. The same script against the base build gives the same opt-in ownership and restoration results. Exact-default helper/Swift tests and the loaded-config ownership seam cover the change; takeover and empty-command registration code are untouched. The documentation's opt-in and migration examples pass the helper. The loaded-config ownership test derives chords from parsed modes without registering Carbon hotkeys or changing global config. Earlier conversions' explicit Cmd-Tab, Cmd-Shift-Tab and Cmd-backtick lines survive an upgrade; the guide names the lines to delete to return system switching.

## Checks for Prateek

- [ ] Installed dogfood build behavior.
- [ ] A second physical display.
- [ ] Real sleep, wake and unlock.

## Sources

- Prateek, after installing `0.5.6-dogfood.12` on his daily machine, 2026-10-06: "maybe you just don't take over shortcuts by default. We can let people opt into that via config. That way we don't have to deal with reverting the shortcuts."
- Prateek, 2026-10-13, choosing who owns Cmd-Tab and the open view: Apple's Cmd-Tab, WinMux's open view, and a row of windows above Cmd-Tab as a prototype.
