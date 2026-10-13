# Settings shows what is loaded

Part of {{UMBRELLA}}.

## What to build

The Settings window is upstream's. Lenses, Columns, hooks, Filters and Triggers do not appear in it, and its panes write keys from before the config was Nickel. A Nickel config can hold functions, so a window cannot rewrite it safely.

Settings becomes a view of the loaded config, with a button that opens the file.

## Decisions

- **Read-only.** It shows what WinMux loaded and edits nothing.
- **Open Config** opens `winmux.ncl` in the person's editor.
- **It shows the fork's features**: the Lenses and their Triggers, Columns, the default shortcuts in effect, hooks, and the last config error.

## Not in this issue

- Toggles that write an overrides file.
- The first run, which is **A first run that explains itself**. The two share a design; build that one first or together.

## Depends on

Nothing.

## Defaults chosen for you

- **Upstream's panes that still work** on a Nickel config stay only if they are read-only too.
- **A shortcut list a person can search**, since it answers "what did I just press".

## Done when

- [ ] With the shipped config, Settings lists every Lens with its Trigger, the Column count per workspace, and the bindings in effect.
- [ ] A config with an error shows the error and the last good config's values.
- [ ] No control in the window writes the config.
- [ ] The pull request shows the window on the staged desk.

## Sources

- Prateek, 2026-10-07: "none of our new features show up in the winmux settings ui. we need to rethink that." 2026-10-13: a read-only view plus Open Config.
