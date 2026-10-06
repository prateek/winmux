# The system's Cmd-Tab stays the system's unless the config asks for it

Part of {{UMBRELLA}}.

## What to build

The shipped defaults bind `cmd-tab`, `cmd-shift-tab` and `cmd-backtick` to Lenses. Binding them makes WinMux switch off macOS's own Cmd-Tab and Cmd-backtick, and it has to switch them back on at every exit. On Prateek's first install that meant a tester's Cmd-Tab was replaced unasked, and when WinMux crashed, native Cmd-Tab stayed off until it was relaunched and quit.

A fresh install leaves the system's switcher alone. Taking it over is something a person turns on in their config.

## Decisions

- **The shipped defaults bind none of `cmd-tab`, `cmd-shift-tab` and `cmd-backtick`.** With no such binding WinMux disables no system shortcut and has nothing to restore.
- **Opting in is config**: the three bindings, written by the person. The takeover, its repair on wake and unlock, and its restore on exit stay as built, and run only for a config that binds those chords.

## Not in this issue

- Removing the takeover or its recovery code.
- A Settings toggle. It may come with **A first run that explains itself**.

## Depends on

Nothing.

## Defaults chosen for you

- **How `recent` and `app-windows` are reached by default.** They stay in the `lens` binding mode (`alt-semicolon`, then a key). Whether the defaults also give the strip a held chord that macOS does not own is the builder's call; say which and why.
- **`config convert`** adds the fork's Triggers to a converted TOML today. It stops adding these three.
- **An existing config that imports the defaults and relied on them** loses Cmd-Tab on upgrade. The release notes and `docs/default-config.md` give the three lines to paste.

## Done when

- [ ] With no config, `winmux doctor` reports no held system shortcut and no marker, and macOS's Cmd-Tab works while WinMux runs.
- [ ] A config with the three bindings takes Cmd-Tab over as today, and a normal quit, a signal and a relaunch after a hard kill each restore it.
- [ ] `docs/default-config.md` and `docs/lenses.md` show the opt-in and say what it does to the system's switcher.
- [ ] The helper's default-config tests and the conversion fixture are updated, not deleted.

## Sources

- Prateek, after installing `0.5.6-dogfood.12` on his daily machine, 2026-10-06: "maybe you just don't take over shortcuts by default. We can let people opt into that via config. That way we don't have to deal with reverting the shortcuts."
