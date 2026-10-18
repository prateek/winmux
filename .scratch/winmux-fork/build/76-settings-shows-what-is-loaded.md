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

- [x] With the shipped config, Settings lists every Lens with its Trigger, the Column count per workspace, and the bindings in effect.
- [x] A config with an error shows the error and the last good config's values.
- [x] No control in the window writes the config.
- [ ] The pull request shows the window on the staged desk.

## Built

The existing Settings window opens on Overview, then offers Lenses, searchable Shortcuts, Columns, Hooks and Filters, Behavior, Appearance, Config File and Configuration Reference. One pure `LoadedConfigSummary` resolves the new panes from the loaded config, load state and workspace names. Triggers come from parsed Lens commands in chords, taps and sequences, including flags and missing Lens references. Columns includes configured and current workspace names, plus an Other workspaces policy. Hook functions are labelled, including inactive Column hooks when Columns is Off. Filter source names stay in the helper; Lenses shows their function markers.

The load state records the file and time independently of helper errors. Failed loads retain the last good values; a failed first load explains the built-in defaults. All panes show the diagnostic while open, and a successful load clears it. Dry runs publish no load-state change. An application failure, which can follow adoption of the new values, is labelled separately. A failed load after it heads its banner as a load failure, and still says the running values did not finish applying. The Overview's hook count counts each Column Policy hook once, and only where Columns are on.

## Decisions the relay made

- Changed **Upstream's panes that still work**: remove the old Shortcuts and Workspaces panes in favour of the searchable list, which covers every binding and mode. The old workspace-pattern inference test is removed with its unused code; the empty-binding regression now checks the summary.
- Move **Double-sided windows** to the menu bar menu, preserving its preference, permission request and refresh. Behavior shows its state and explains where to switch it.
- Replace disabled controls with read-only rows and drawn colour swatches in Behavior and Appearance. Remove the unused Automation pane and shortcut recorder dependency.
- **Open Config** retains the existing menu behaviour: create a starter only when no file exists, then ask the default application to open it. Existing files are untouched. Reload From Disk updates only the displayed text.

## Verification

Host and pinned-version guest `make check` pass. Summary and controlled-reloader tests cover shipped and rich configs, all binding kinds, missing and untriggered Lenses, search, failed loads, dry runs, recovery and startup fallback. A standing-desk run at 1280 by 720 checks every pane, search counts, retained Columns through an error, cold fallback, the menu checkbox and read-only controls. The same base/head probe preserves file hashes, modification times and defaults for both file buttons, and creates identical valid starters from no-file startup. The assigned image has no default application for `.ncl`: Open Config reaches the same macOS application chooser on both builds, which is dismissed without choosing one. A default-editor launch remains unverified there. Reproduction tools are in `.scratch/winmux-fork/proofs/settings-loaded/`.

Restaging also showed the Python docs server's Local Network screen. It was dismissed without answering, and the desk checker passed again before the final capture. The image recipe should settle that screen too.

## Installed-build and hardware checks

- [ ] Settings on an installed build, including the person's configured default editor.
- [ ] A second physical display.
- [ ] Real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-07: "none of our new features show up in the winmux settings ui. we need to rethink that." 2026-10-13: a read-only view plus Open Config.
