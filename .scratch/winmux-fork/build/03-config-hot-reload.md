# Config hot reload

Part of {{UMBRELLA}}.

## What to build

WinMux reloads its Nickel config when the config file or any file it imports is saved. A save that fails to load changes nothing and reports the error once. This replaces today's `auto-reload-config` watcher, which watches only the one file.

## Decisions

- **On by default.** Reload on save is on unless the config sets `reload-on-save` to false. With it off, `reload-config` is the only trigger. `reload-on-save` replaces the existing `auto-reload-config` setting.
- **What is watched.** The config file and every file it imports. The list comes from the helper: every successful load returns the resolved list of imported files next to the static config.
- **Re-arming.** The watch is set up again after every load, whether it succeeded or failed, so a newly added import is picked up.
- **Watch directories, not files.** WinMux watches the directories that contain the watched files and filters events to those files. An editor that saves by writing a temporary file and renaming it over the original is then seen. Today's watcher opens the config file itself with `O_EVTONLY` and loses it on such a rename.
- **Debounce.** WinMux waits 300 ms after the last change before loading, so a burst of writes becomes one reload. Today's value is 200 ms.
- **Half-written files.** No special handling. A half-written file fails to load and the old config stays.
- **The reload itself.** A file-triggered reload runs the same swap as `reload-config`: a fresh helper loads the file, checks contracts and runs the smoke run; on success WinMux applies the static config and swaps helpers atomically, and requests in flight finish on the old helper; on failure the old helper and config stay.
- **Where a failure shows.** In a notification, as the last error in `winmux config status`, and in the log.
- **No repeated notifications.** An error identical to the last one notified is not notified again. The next notification comes when the file changes to something that fails differently. A successful load clears the remembered error.
- **Bindings and Triggers.** New bindings and Triggers apply immediately, even while a binding mode is active.
- **Active mode.** The current mode is kept if it still exists in the new config. Otherwise WinMux returns to `main`.
- **Open Lens.** A Lens that is open during a reload keeps its already-filtered entries until it closes.
- **Circuit breaker.** A file change resets the helper's circuit breaker, the same as `reload-config` does. So after the breaker trips on a config that crashes the helper, saving a fix brings the helper back without a manual command.

## Not in this issue

- The helper, the load and swap sequence, `reload-config`, the circuit breaker and `config status`: "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`".
- The `config-reloaded` event on `winmux subscribe`: "Default config, Triggers, the `lens` leader mode, `subscribe` events".
- Lens behaviour during a reload beyond keeping its entries: "Lens core and the `'list` Presentation with Search".
- Display profiles are deferred. A reload does not re-match a profile; the one implicit profile `"default"` stays active.

## Depends on

- "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"

## Open details

- The helper returns the import list only on a successful load. Which files are watched after a failed load is not decided. Candidates: keep the last successful list plus the config file, or have the helper report the imports it resolved before failing.
- Whether the WinMux-shipped contracts and defaults library counts as a watched import. It changes only when the app is replaced.
- "The log" has no decided destination. Use WinMux's existing logging and say in the PR where the entry lands.
- Whether "identical error" compares the full diagnostic text or something coarser. The diagnostic includes file positions, so an unrelated edit above the error changes the text.
- What a file change does when no config file existed at startup and one is created later. Watching the directory makes this visible; the natural reading is that it loads like any other change.
- The Settings pane has a "Reload config when it changes" toggle that writes `auto-reload-config` into the TOML file. What happens to the TOML-editing Settings panes is an open detail of the Nickel config issue; follow whatever that issue settles.

## Done when

- [ ] Saving a valid change to `~/.config/winmux/winmux.ncl` applies it within about half a second, with no command run.
- [ ] Saving a valid change to a file the config imports does the same.
- [ ] Adding a new `import` to the config and then editing the newly imported file triggers a reload.
- [ ] Saving through an editor that writes a temporary file and renames it triggers a reload, and later saves keep working.
- [ ] Several writes within 300 ms cause exactly one load.
- [ ] Saving a config with an error keeps the old config running, shows one notification, and the error appears as the last error in `winmux config status` and in the log.
- [ ] Saving the same broken file again shows no second notification. Changing it to fail differently shows a new one. Fixing it loads the config, and `winmux config status` no longer shows the error.
- [ ] A binding added in a save works immediately while a non-`main` mode is active, and the mode stays active. Removing the active mode from the config returns WinMux to `main`.
- [ ] A Lens open during a save keeps its entries and still acts on a selection.
- [ ] With the helper's circuit breaker tripped (`winmux config status` reports `failed`), saving the config file starts a new helper, and the state becomes `ready` if the file loads.
- [ ] With `reload-on-save` set to false, a save does nothing and `winmux reload-config` still reloads.

## Sources

- [Grilling: config hot reload](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/32-grilling-config-hot-reload.md)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/wayfind-fork/docs/adr/0001-nickel-helper-process.md)
