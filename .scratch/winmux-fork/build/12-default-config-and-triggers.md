# Default config, Triggers, the `lens` leader mode, `subscribe` events

Part of {{UMBRELLA}}.

## What to build

This issue completes `defaults.ncl`, the config WinMux ships. When this issue starts, the file holds upstream's settings and bindings, converted from TOML, and each sibling issue has put its own default Lens there. This issue adds the Triggers the siblings leave out (`alt-slash`, `alt-semicolon` and a `lens` binding mode that reaches the Lenses with no global chord of their own), ships Columns off, and checks that all five default Lenses are present and bound. `winmux subscribe` gains four events so scripts can react to config reloads, Lenses opening and closing, and Column changes. This is the last issue: it wires together what the other issues built, so a fresh install with no config file is usable as a daily driver.

## Decisions

**The shipped defaults and how a config layers over them**

- The config is Nickel. The user's file is `~/.config/winmux/winmux.ncl`.
- WinMux ships `defaults.ncl`, a Nickel file that holds every default setting, binding and Lens. **Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`** introduces the file; this issue completes its contents.
- A user's config imports `defaults.ncl` and merges its own record over it explicitly: `((import "winmux/defaults.ncl") & { … }) | W.Config`.
- Nothing is merged implicitly. A config that does not import `defaults.ncl` has no default Lens and no default binding.
- Any default can be dropped. A user removes a field from the imported record before merging, or leaves the import out.
- Every value in `defaults.ncl` is written at Nickel's `default` priority, so a user's value for the same field wins the merge. Nickel refuses to merge two different values of equal priority.
- `winmux config convert` writes the import line, so a converted TOML config keeps the default Lenses, the Triggers and the `lens` mode.
- With no config file, WinMux loads `defaults.ncl` as the config. When the first load fails, it runs on the static settings of `defaults.ncl`.
- TOML is gone. `resources/default-config.toml` stops being the default. **Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`** seeds `defaults.ncl` by converting that file, and this issue owns the contents from there. Upstream's settings and bindings keep the same values, at the same record paths (`mode.main.binding`, `gaps`, `workspace-sidebar` and so on), except where another issue renames a key: `auto-reload-config` becomes `reload-on-save` in **Config hot reload**.
- Every name the fork adds to the config is spelled with hyphens, like the keys carried over from upstream: `app-windows`, `reload-on-save`.
- `[[on-window-detected]]` does not carry over. The `arrive` hook replaces it, and `defaults.ncl` ships no `arrive`, `place` or `move-boundary` hook.
- `defaults.ncl` ships `columns.count` as `'off`, so a fresh install tiles exactly as upstream does. **Fixed Columns: slots, the count invariant, Width presets** decides that default; this issue only ships it.

**Default Lenses**

- Five Lenses ship. Each is defined in `defaults.ncl` by the issue that builds what it needs.
- `search` is defined in **Lens core and the `'list` Presentation with Search**.
- `recent` and `app-windows`, with their `cmd-tab` and `cmd-backtick` bindings, are defined in **Strip Presentation and the cmd+tab takeover**.
- `overview` is defined in **Thumbnail cache and the `'miniatures` Presentation**.
- `floating` is defined in **Accessory window defaults and the `floating` Lens**.
- This issue does not define a Lens or set any Lens field. It checks that the five are present in `defaults.ncl`, that they load, and that each has a Trigger.
- A default Lens that needs a Filter uses a named entry under `filters`, such as `filters.same-app` for `app-windows`. The entry is defined with its Lens, in the same sibling issue.
- A binding names a Lens exactly as `lenses` does, so the command for `app-windows` is `lens app-windows`.

**Default Triggers**

- `cmd-tab` runs `lens recent` and `cmd-backtick` runs `lens app-windows`. **Strip Presentation and the cmd+tab takeover** adds both bindings, and any reverse chord that goes with them; this issue checks they are there.
- This issue adds two bindings to `mode.main.binding`: `alt-slash` runs `lens search`, and `alt-semicolon` runs `mode lens`, which enters the `lens` mode.
- This issue adds `mode.lens.binding`. Each key opens a Lens and returns to `main`: `o` opens `overview`, `f` opens `floating`, `s` opens `search`, and `r` opens `recent` in the `'list` Presentation (`lens recent --presentation list`). `esc` leaves the mode without opening anything.
- A binding's value is one command or a list of commands run in order. Upstream's binding parser accepts both (`parseCommandOrCommands` in `Sources/AppBundle/config/parseConfig.swift`), and the Nickel contract keeps both. Each Lens key in the `lens` mode is a list of two commands: the `lens` command and `mode main`.
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
- `config-reloaded` fires after every reload attempt, whether `winmux reload-config` or a file save started it. It says the reload succeeded, or carries the error.
- `lens-opened` and `lens-closed` carry the Lens name.
- `columns-changed` fires when the Column count, the Column widths or which Columns are occupied changes on the focused workspace.
- The event names are added to `ServerEventType` in `Sources/Common/cmdArgs/impl/SubscribeCmdArgs.swift`, so `subscribe --all` includes them. Their payloads go on `ServerEvent` in `Sources/AppBundle/model/ServerEvent.swift`.
- Payload keys are camelCase, like the existing ones (`windowId`, `appBundleId`). `ServerEvent` is a plain `Codable` struct with no key mapping, and the hyphen rule for config names does not apply to event JSON.

**CLI conventions to confirm across the fork**

- Every new `list-*` command takes `--json`. That is `list-lenses` and `list-columns`.
- New flags follow the existing names, such as `--window-id`.
- New commands exit 0 on success, 1 on a runtime failure (server down, helper unavailable), and 2 on bad usage or a bad Filter.

## Not in this issue

- **Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`** covers loading the config, the shipped contracts, introducing `defaults.ncl` and its import path, and `winmux config convert`, which translates a user's existing `winmux.toml` to Nickel once and writes the import line.
- **Config hot reload** covers reload on save. This issue only emits `config-reloaded` when a reload happens, whatever started it.
- **Lens core and the `'list` Presentation with Search** covers the Lens machinery, `lens`, `list-lenses`, `summon`, the default `keys` of every Lens, Search, the `search` Lens, and `winmux palette` as an alias for `lens search`.
- **Strip Presentation and the cmd+tab takeover** covers the `recent` and `app-windows` Lenses and their bindings, taking `cmd-tab` and `cmd-backtick` from the system, hold and release, and the strip's reverse and hand-off keys.
- **Thumbnail cache and the `'miniatures` Presentation** covers the `overview` Lens and what it draws.
- **Accessory window defaults and the `floating` Lens** covers the `floating` Lens and Accessory app windows floating by default.
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
- Config hot reload, for `config-reloaded` on a reload that a file save starts

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **`config-version`.** Dropped. The Nickel contract replaces it, and the one thing it gates upstream, `persistent-workspaces` in `Sources/AppBundle/config/parseConfig.swift`, needs no gate in a new format.
- **Checking the carried-over settings.** A test runs `winmux config convert` on `resources/default-config.toml`, which stays in the repo as that test's input, and checks that the result evaluates to the same static config as `defaults.ncl` alone.
- **Leaving the `lens` mode.** In each list the `lens` command comes first and `mode main` second: `o = ["lens overview", "mode main"]`.
- **Event payload keys.** `config-reloaded` carries `ok`, `error` and `configPath`. `lens-opened` and `lens-closed` carry `lens`. `columns-changed` carries `workspace`, `count`, `widths` and `occupied`.
- **Ad-hoc Lenses in events.** For a Lens opened with `lens --filter`, `lens` is `null` and a `filter` key carries the Filter's name or body.
- **`lens-closed` and re-presenting.** Handing a strip off to `'list` emits nothing. One Lens gets one `lens-opened` and one `lens-closed`.

## Done when

- [ ] With no file at `~/.config/winmux/winmux.ncl`, WinMux starts on `defaults.ncl`, and `winmux config status` reports no error.
- [ ] `winmux config check` passes on `defaults.ncl`.
- [ ] A config that is only the import of `defaults.ncl` behaves the same as no config file.
- [ ] A config that imports `defaults.ncl` and merges one changed binding over it loads, applies that binding, and still has the five Lenses and the `lens` mode.
- [ ] A config that removes `alt-slash` from the imported record before merging has no `alt-slash` binding, and its other defaults are intact.
- [ ] The output of `winmux config convert` for a TOML config loads and still has the five Lenses and the `lens` mode.
- [ ] Every binding listed under "Upstream chords" still runs its upstream command on a fresh install.
- [ ] On a fresh install, `winmux list-lenses --json` lists `recent`, `app-windows`, `overview`, `search` and `floating`, and each has a Trigger: `cmd-tab`, `cmd-backtick` and `alt-slash` in `main`, and `o`, `f`, `s` and `r` in the `lens` mode.
- [ ] `alt-slash` opens `search`.
- [ ] `alt-semicolon` enters the `lens` mode, and `winmux list-modes --current` prints `lens`.
- [ ] In the `lens` mode, `o` opens `overview`, `f` opens `floating`, `s` opens `search`, and `r` opens `recent` as a list. After each, the mode is `main` again.
- [ ] In the `lens` mode, `esc` returns to `main` and opens nothing.
- [ ] On a fresh install Columns are off and layout is plain tree tiling, the same as upstream's.
- [ ] `winmux subscribe config-reloaded` prints an event after `winmux reload-config`, once for a good config and once, with the error, for a broken one. Saving the config file with reload on save enabled prints one too.
- [ ] `winmux subscribe lens-opened lens-closed` prints one event with the Lens name when a Lens opens and one when it closes.
- [ ] `winmux subscribe columns-changed` prints an event after `winmux column-count 3`, after `winmux column-width next`, and when a window fills or empties a Column on the focused workspace.
- [ ] `winmux subscribe --all` includes the four new events.
- [ ] `winmux list-lenses --json` and `winmux list-columns --json` both print valid JSON.
## Sources

- [Grilling: default Triggers and a leader mode](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/34-grilling-default-triggers.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
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
