# Config hot reload

Part of {{UMBRELLA}}.

## What to build

WinMux reloads its Nickel config when the config file or any file it imports is saved. A save that fails to load changes nothing and reports the error once. This replaces today's `auto-reload-config` watcher, which watches only the one file.

## Decisions

- **On by default.** Reload on save is on unless the config sets `reload-on-save` to false. With it off, `reload-config` is the only trigger. `reload-on-save` replaces the existing `auto-reload-config` setting.
- **What is watched.** The config file and every file it imports. The list comes from the helper: every successful load returns the resolved list of imported files next to the static config.
- **Re-arming.** The watch is set up again after every load, whether it succeeded or failed, so a newly added import is picked up.
- **Watch directories, not files.** WinMux watches the directories that contain the watched files and filters events to those files. Today's watcher (`Sources/AppBundle/config/ConfigFileWatcher.swift`) opens the one config file with `O_EVTONLY`, and it misses two cases this issue needs. It cannot see imported files, because a TOML config has none. And it cannot see a config file created after startup, because opening a file that does not exist fails and nothing tries again until the next reload. Watching directories makes both visible, and it still sees an editor that saves by writing a temporary file and renaming it over the original.
- **Debounce.** WinMux waits 300 ms after the last change before loading, so a burst of writes becomes one reload. Today's value is 200 ms.
- **Half-written files.** No special handling. A half-written file fails to load and the old config stays.
- **The reload itself.** A file-triggered reload runs the same swap as `reload-config`: a fresh helper loads the file, checks contracts and runs the smoke run; on success WinMux applies the static config and swaps helpers atomically, and requests in flight finish on the old helper; on failure the old helper and config stay.
- **Where a failure shows.** In a notification, as the last error in `winmux config status`, and in the log.
- **No repeated notifications.** An error identical to the last one notified is not notified again. The next notification comes when the file changes to something that fails differently. A successful load clears the remembered error.
- **Bindings and Triggers.** New bindings and Triggers apply immediately, even while a binding mode is active.
- **Active mode.** The current mode is kept if it still exists in the new config. Otherwise WinMux returns to `main`.
- **Open Lens.** A Lens that is open during a reload keeps its already-filtered entries until it closes.
- **Circuit breaker.** A file change resets the helper's circuit breaker, the same as `reload-config` does. So after the breaker trips on a config that crashes the helper, saving a fix brings the helper back without a manual command.
- **The Settings toggle is read-only.** Settings has a "Reload config when it changes" toggle that writes `auto-reload-config` into the TOML file today (`Sources/AppBundle/ui/settings/ConfigSettingsViews.swift`). The Settings panes are read-only in the first version, so the toggle shows the loaded value of `reload-on-save` and cannot change it. Changing it means editing the config file.

## Not in this issue

- The helper, the load and swap sequence, `reload-config`, the circuit breaker, `config status`, and making the Settings panes read-only with their "Open config" button: "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`".
- The `config-reloaded` event on `winmux subscribe`: "Default config, Triggers, the `lens` leader mode, `subscribe` events".
- Lens behaviour during a reload beyond keeping its entries: "Lens core and the `'list` Presentation with Search".
- Display profiles are deferred. A reload does not re-match a profile; the one implicit profile `"default"` stays active.

## Depends on

- "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **A config file that appears after startup.** WinMux watches the config directory (`$XDG_CONFIG_HOME/winmux/`, by default `~/.config/winmux/`) from startup even when it holds no config file. When the file appears it loads like any other change.
- **Files watched after a failed load.** The config file plus the import list from the last successful load. The helper returns an import list only when a load succeeds. Until a load succeeds, any `.ncl` file in the watched directories also triggers a reload, so fixing a newly imported file that failed is seen.
- **The shipped library.** Not watched. The helper's `load` reply names the library directory, and imports under it are left out of the watch list, since `winmux/winmux.ncl` and `winmux/defaults.ncl` change only when the app is replaced. "Inside the app bundle" would miss a debug build, whose library is in the source tree.
- **The log.** WinMux had no log outside debug builds, which print to stderr. A failed reload is written to the unified log under WinMux's app id with the category `config`.
- **What counts as an identical error.** The full diagnostic text. The text includes file positions, so an edit above the error changes it and notifies again; that counts as failing differently.
- **`reload-config` always notifies.** Only a save is silenced when it fails the way the last notified failure did. A reload the user asked for by name reports its failure every time.
- **The old setting.** `auto-reload-config` is not kept as an alias. A config that sets it fails to load with Nickel's "extra field" diagnostic, and `config convert` renames it.
- **A change during a reload.** One more reload runs after the one under way. A reload is never cancelled part way.

## Done when

- [ ] Saving a valid change to `~/.config/winmux/winmux.ncl` applies it within about half a second, with no command run.
- [ ] Saving a valid change to a file the config imports does the same.
- [ ] Adding a new `import` to the config and then editing the newly imported file triggers a reload.
- [ ] Saving through an editor that writes a temporary file and renames it triggers a reload, and later saves keep working.
- [ ] With no config file at startup, creating `~/.config/winmux/winmux.ncl` loads it with no command run.
- [ ] Several writes within 300 ms cause exactly one load.
- [ ] Saving a config with an error keeps the old config running, shows one notification, and the error appears as the last error in `winmux config status` and in the log.
- [ ] After a save that fails to load, saving a file from the last successful import list still triggers a reload.
- [ ] Saving the same broken file again shows no second notification. Changing it to fail differently shows a new one. Fixing it loads the config, and `winmux config status` no longer shows the error.
- [ ] A binding added in a save works immediately while a non-`main` mode is active, and the mode stays active. Removing the active mode from the config returns WinMux to `main`.
- [ ] With the helper's circuit breaker tripped (`winmux config status` reports `failed`), saving the config file starts a new helper, and the state becomes `ready` if the file loads.
- [ ] With `reload-on-save` set to false, a save does nothing and `winmux reload-config` still reloads.
- [ ] The "Reload config when it changes" toggle in Settings shows the loaded value of `reload-on-save`, cannot be switched, and writes nothing to the config file.

## Sources

- [Grilling: config hot reload](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/32-grilling-config-hot-reload.md)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/fork/docs/adr/0001-nickel-helper-process.md)
