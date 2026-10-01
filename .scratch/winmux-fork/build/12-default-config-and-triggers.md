# Default config, Triggers, the `lens` leader mode, `subscribe` events

Part of {{UMBRELLA}}.

## What to build

The config WinMux ships gains five default Lenses, their Triggers, a `lens` binding mode that reaches the Lenses with no global chord of their own, and Columns set to off. `winmux subscribe` gains four events so scripts can react to config reloads, Lenses opening and closing, and Column changes. This is the last issue: it wires together what the other issues built, so a fresh install with no config file is usable as a daily driver.

## Decisions

**The shipped default config**

- The config is Nickel. The user's file is `~/.config/winmux/winmux.ncl`, checked against the contracts and defaults WinMux ships. With no config file, or when the first load fails, WinMux runs on the shipped defaults.
- TOML is gone. `resources/default-config.toml` stops being the default. Its settings and bindings carry over to the Nickel defaults with the same values, at the same record paths (`mode.main.binding`, `gaps`, `workspace-sidebar` and so on), except where another issue renames a key: `auto-reload-config` becomes `reload-on-save` in **Config hot reload**.
- `[[on-window-detected]]` does not carry over. The `arrive` hook replaces it, and the default config ships no `arrive`, `place` or `move-boundary` hook.
- `columns.count` defaults to `'off`, so a fresh install tiles exactly as upstream does.
- Every default below is an ordinary Lens or binding that the user's config can change.

**Default Lenses**

- `recent`: every window, `'strip` Presentation, sorted by `mru`.
- `app-windows`: the windows of the focused window's app, matched on bundle id; `'strip` Presentation, sorted by `mru`. The Filter reads the Filter context's focused window and says no to every window when nothing is focused.
- `overview`: every window, `'miniatures` Presentation. Its `miniatures` record sets `fit` to `'page`, `current_workspace` to `'highlight` and `arrow_keys` to `'nearest`.
- `search`: every window, `'list` Presentation, sorted by `mru`.
- `floating`: windows whose Window class is floating, on every workspace; `'list` Presentation.
- `overview` also sets the three look fields that sit on the Lens, not in the `miniatures` record: `frozen_thumbnail` is `'dimmed`, `accessory_window` is `'enlarged`, and `summon_hints` is `'label` and `'landing_spot`. The two `'strip` Lenses use the same three values.
- "Every window" still leaves out the accessory-popup and app-popup Window classes, as any Lens does unless its Filter names them.
- The default `keys` for every Lens are `enter` for `focus`, `shift-enter` for `summon`, `cmd-w` for `close`, and `cmd-<n>` for `move-node-to-workspace <n>`. In a `'strip`, releasing with Option held is Summon, because Shift reverses the cycle there.
- No default Lens uses `'grid`. A Lens with `presentation = 'grid` is rejected at load as not yet supported.

**Default Triggers**

- In `mode.main.binding`: `cmd-tab` runs `lens recent`, `cmd-backtick` runs `lens app-windows`, and `alt-slash` runs `lens search`.
- In `mode.main.binding`: `alt-semicolon` runs `mode lens`, which enters the `lens` mode.
- In `mode.lens.binding`, each key opens a Lens and returns to `main`: `o` opens `overview`, `f` opens `floating`, `s` opens `search`, and `r` opens `recent` in the `'list` Presentation (`lens recent --presentation list`). `esc` leaves the mode without opening anything.
- The fork claims no other global chord. Later fork commands, such as Column widths or `compact`, can join the `lens` mode without claiming one.

**Upstream chords the defaults must not collide with**

Upstream ships one mode, `main`, with these bindings in `resources/default-config.toml`. All of them stay.

- `ctrl-f` opens the sidebar.
- `alt-space` toggles the layout orientation.
- `alt-h`, `alt-j`, `alt-k`, `alt-l`, `alt-n`, `alt-p` move focus.
- `alt-tab` and `alt-shift-tab` focus the next and previous tab; `alt-0` to `alt-9` focus a tab by index.
- `alt-shift-h`, `alt-shift-j`, `alt-shift-k`, `alt-shift-l` move a window; `alt-shift-t` toggles floating; `alt-shift-m` is fullscreen; `alt-shift-1` to `alt-shift-9` move a window to a workspace.
- `cmd-shift-h`, `cmd-shift-j`, `cmd-shift-k`, `cmd-shift-l` run `join-with`; `cmd-shift-i` runs `balance-sizes`.
- `ctrl-cmd-shift-h`, `ctrl-cmd-shift-j`, `ctrl-cmd-shift-k`, `ctrl-cmd-shift-l` run `stack-with`.
- `alt-cmd-h` and `alt-cmd-l` switch project; `alt-cmd-j` and `alt-cmd-k` swap; `alt-cmd-1` to `alt-cmd-9` pick a project.
- `alt-cmd-shift-h`, `alt-cmd-shift-l` and `alt-cmd-shift-1` to `alt-cmd-shift-9` move a window to a project.
- `ctrl-0` to `ctrl-9` and `ctrl-q`, `ctrl-w`, `ctrl-e`, `ctrl-r`, `ctrl-t` pick a workspace; `ctrl-h`, `ctrl-l`, `cmd-ctrl-h`, `cmd-ctrl-l` step between workspaces.
- `ctrl-shift-0`, `ctrl-shift-h`, `ctrl-shift-l` move a window to a workspace.

None of `cmd-tab`, `cmd-backtick`, `alt-slash` or `alt-semicolon` is bound upstream, and upstream leaves `palette` unbound. `alt-tab` stays upstream's tab focus; the fork's `recent` Trigger is `cmd-tab`, not `alt-tab`. The strip's reverse keys, `shift-tab` and `shift-backtick` while cmd is held, hit no upstream binding either. The `lens` mode's keys are in their own mode table, so `o`, `f`, `s`, `r` and `esc` collide with nothing in `main`.

**`subscribe` events**

- Four events join the existing six (`focus-changed`, `focused-monitor-changed`, `focused-workspace-changed`, `mode-changed`, `window-detected`, `binding-triggered`).
- `config-reloaded` fires after every reload attempt. It says the reload succeeded, or carries the error.
- `lens-opened` and `lens-closed` carry the Lens name.
- `columns-changed` fires when the Column count, the Column widths or which Columns are occupied changes on the focused workspace.
- The event names are added to `ServerEventType` in `Sources/Common/cmdArgs/impl/SubscribeCmdArgs.swift`, so `subscribe --all` includes them. Their payloads go on `ServerEvent` in `Sources/AppBundle/model/ServerEvent.swift`.

**CLI conventions to confirm across the fork**

- Every new `list-*` command takes `--json`. That is `list-lenses` and `list-columns`.
- New flags follow the existing names, such as `--window-id`.
- New commands exit 0 on success, 1 on a runtime failure (server down, helper unavailable), and 2 on bad usage or a bad Filter.

## Not in this issue

- **Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`** covers loading the config, the shipped contracts, and `winmux config convert`, which translates a user's existing `winmux.toml` to Nickel once.
- **Config hot reload** covers reload on save. This issue only emits `config-reloaded` when a reload happens, whatever started it.
- **Lens core and the `'list` Presentation with Search** covers the Lens machinery, `lens`, `list-lenses`, `summon`, the default `keys` behaviour, Search, and `winmux palette` as an alias for `lens search`.
- **Strip Presentation and the cmd+tab takeover** covers taking `cmd-tab` and `cmd-backtick` from the system, hold and release, and the strip's reverse and hand-off keys.
- **Thumbnail cache and the `'miniatures` Presentation** covers what `overview` draws.
- **Accessory window defaults and the `floating` Lens** covers the `floating` Lens's behaviour and Accessory app windows floating by default.
- **Column Policy hooks and Column commands** covers the hooks and the Column commands; this issue only ships Columns off and emits `columns-changed`.
- Deferred: trackpad gestures. There is no gesture binding table in the default config, and `overview` has no gesture Trigger.
- Deferred: Display profiles. The default config has no `when.<profile>` overrides, and there is no `displayProfileChanged` event.
- Deferred: Tabs. The default config ships no Tab provider.

## Depends on

- Lens core and the `'list` Presentation with Search
- Strip Presentation and the cmd+tab takeover
- Thumbnail cache and the `'miniatures` Presentation
- Accessory window defaults and the `floating` Lens
- Column Policy hooks and Column commands

## Open details

Settle each of these while building and note the choice in the PR.

- **Identifier spelling.** The tickets write `app-windows`; the config prototype writes `app_windows`, and the Lens look fields are written with underscores (`frozen_thumbnail`, `'landing_spot`). This issue uses each name as its ticket spells it. Use whatever the shipped Nickel contract settles on, and make `lens app-windows` in the binding match the Lens's real name.
- **Where the defaults live.** Not decided: whether the defaults are `| default` values inside the shipped contracts file, a separate shipped default file, a starter file written to `~/.config/winmux/winmux.ncl`, or a mix.
- **How a user config layers over the defaults.** Not decided: whether a user file that defines `mode.main.binding` or `lenses` replaces the shipped records or merges with them, and so whether a converted TOML config still gets the default Lenses and Triggers.
- **`config-version`.** Upstream's default sets `config-version = 2`. Not decided: whether that key survives in Nickel next to the Filter contract's `contract-version`.
- **Producing the Nickel defaults.** Not decided: whether the upstream settings are carried over by hand or by running `config convert` on `default-config.toml` once.
- **Named Filters in the default config.** Not decided: whether the `app-windows` and `floating` Filters are named entries under `filters`, and under which names, or are written inline on the Lens.
- **`floating` Lens sort.** No ticket gives it.
- **Leaving the `lens` mode.** Not decided: whether each `lens` mode binding is a command list (`lens <name>` plus `mode main`) and in which order, or the mode returns to `main` some other way.
- **Event payload field names.** Not decided: the JSON keys for the success flag and error on `config-reloaded`, the Lens name on `lens-opened` and `lens-closed`, and what `columns-changed` carries beyond the fact that something changed.
- **Ad-hoc Lenses in events.** Not decided: what name `lens-opened` and `lens-closed` carry for a Lens opened with `lens --filter`.
- **`lens-closed` and re-presenting.** Not decided: whether handing a strip off to `'list` (`lens --presentation list`) emits a close and an open, or nothing.

## Done when

- [ ] With no file at `~/.config/winmux/winmux.ncl`, WinMux starts on the shipped defaults, and `winmux config status` reports no error.
- [ ] `winmux config check` passes on the shipped default config.
- [ ] Every binding listed under "Upstream chords" still runs its upstream command on a fresh install.
- [ ] `winmux list-lenses --json` lists `recent`, `app-windows`, `overview`, `search` and `floating` with the Presentations above.
- [ ] `cmd-tab` opens `recent` as a strip and `cmd-backtick` opens `app-windows` as a strip.
- [ ] `alt-slash` opens `search` as a list, and `winmux palette` opens the same Lens.
- [ ] `alt-semicolon` enters the `lens` mode, and `winmux list-modes --current` prints `lens`.
- [ ] In the `lens` mode, `o` opens `overview`, `f` opens `floating`, `s` opens `search`, and `r` opens `recent` as a list. After each, the mode is `main` again.
- [ ] In the `lens` mode, `esc` returns to `main` and opens nothing.
- [ ] `app-windows` opened with no focused window shows no windows and reports no Filter error.
- [ ] On a fresh install Columns are off and layout is plain tree tiling, the same as upstream's.
- [ ] `winmux subscribe config-reloaded` prints an event after `winmux reload-config`, once for a good config and once, with the error, for a broken one.
- [ ] `winmux subscribe lens-opened lens-closed` prints one event with the Lens name when a Lens opens and one when it closes.
- [ ] `winmux subscribe columns-changed` prints an event after `winmux column-count 3`, after `winmux column-width next`, and when a window fills or empties a Column on the focused workspace.
- [ ] `winmux subscribe --all` includes the four new events.
- [ ] `winmux list-lenses --json` and `winmux list-columns --json` both print valid JSON.

## Sources

- [Grilling: default Triggers and a leader mode](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/34-grilling-default-triggers.md)
- [Grilling: Lens configuration shape](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/07-grilling-picker-binding-shape.md)
- [Grilling: cmd-K search Lens](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/19-grilling-cmd-k-search.md)
- [Grilling: default handling of floating and Accessory app windows](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/11-grilling-floating-and-accessory-defaults.md)
- [Prototype: grid Presentation look and behaviour](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/08-prototype-grid-presentation.md)
- [Prototype: strip Presentation look and keyboard model](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/29-prototype-strip-presentation.md)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Config language prototype](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/27-config-language.html)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [Upstream default config](https://github.com/prateek/winmux/blob/wayfind-fork/resources/default-config.toml)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/wayfind-fork/CONTEXT.md)
