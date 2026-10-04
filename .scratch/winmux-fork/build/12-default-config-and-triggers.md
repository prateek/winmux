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
- `winmux config convert` keeps all five default Lenses. A TOML `mode` table replaces upstream modes and bindings: conversion adds only the fork's `lens` keys and the five `main` Triggers where their normalized chords are unbound. Without a `mode` table it imports defaults whole. The converted file explains what was retained and how to remove it.
- With no config file, WinMux loads `defaults.ncl` as the config. When the first load fails, it runs on the static settings of `defaults.ncl`.
- TOML is gone. The upstream TOML survives only as `nickel-helper/tests/fixtures/upstream-default-config.toml`, the conversion fixture; it is not a runtime default. **Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`** seeds `defaults.ncl` by converting that file, and this issue owns the contents from there. Upstream's settings and bindings keep the same values, at the same record paths (`mode.main.binding`, `gaps`, `workspace-sidebar` and so on), except where another issue renames a key: `auto-reload-config` becomes `reload-on-save` in **Config hot reload**.
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
- A binding's value is one command or a list of commands run in order. Upstream's binding parser accepts both (`parseCommandOrCommands` in `Sources/AppBundle/config/parseConfig.swift`), and the Nickel contract keeps both. Each Lens key in the `lens` mode is a list of two commands: `mode main` followed by the `lens` command.
- The fork claims no other global chord. Later fork commands, such as Column widths or `compact`, can join the `lens` mode without claiming one.

**Upstream chords the defaults must not collide with**

Upstream ships one mode, `main`, with these bindings in `nickel-helper/tests/fixtures/upstream-default-config.toml`. All of them stay.

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
- `lens-opened` and `lens-closed` carry the Lens name. Opening fires on presentation; only presented sessions close. An undrawn quick strip tap emits neither event; list and miniatures appear at once. Handoff and Presentation changes keep the same pair.
- `columns-changed` compares every workspace against its retained baseline by name on each refresh, emitting only for the focused workspace. Focus alone emits nothing, but a Column filled in the same refresh as focus arrives emits. Every workspace is a silent baseline on the first refresh after launch; a workspace created later starts from its Columns with nothing in them, so a window arriving with it emits. Removed workspaces lose their baseline. Reads create no tiling root or leaf arrays.
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

- **`config-version`.** Absent from defaults and new conversions. Older Nickel files may set it: the contract accepts and ignores it, and the Swift bridge drops it like `contract-version`. Conversion of TOML at version 1 or lower, or unversioned, without an explicit persistence list writes the formerly inferred workspace names in first-seen order and warns; when nothing is inferred it writes nothing.
- **Checking the carried-over settings.** A test runs `winmux config convert` on `nickel-helper/tests/fixtures/upstream-default-config.toml`, the existing upstream input, and checks that the result evaluates to the same static config as `defaults.ncl` alone.
- **Leaving the `lens` mode.** In each list `mode main` comes first: `o = ["mode main", "lens overview"]`. This returns before opening or failure and leaves standalone Lens commands neutral about user modes.
- **Event payload keys.** `config-reloaded` carries `ok`, `error` and `configPath`. `lens-opened` and `lens-closed` carry `lens`. `columns-changed` carries `workspace`, `count`, `widths` and `occupied`.
- **Ad-hoc Lenses in events.** For a Lens opened with `lens --filter`, `lens` is `null` and a `filter` key carries the Filter's name or body.
- **`lens-closed` and re-presenting.** Handing a strip off to `'list` emits nothing. One Lens gets one `lens-opened` and one `lens-closed`.

## Done when

- [x] With no file at `~/.config/winmux/winmux.ncl`, WinMux starts on `defaults.ncl`, and `winmux config status` reports no error.
- [x] `winmux config check` passes on `defaults.ncl`.
- [x] A config that is only the import of `defaults.ncl` behaves the same as no config file.
- [x] A config that imports `defaults.ncl` and merges one changed binding over it loads, applies that binding, and still has the five Lenses and the `lens` mode.
- [x] A config that removes `alt-slash` from the imported record before merging has no `alt-slash` binding, and its other defaults are intact.
- [x] The output of `winmux config convert` for a TOML config loads and still has the five Lenses and the `lens` mode.
- [x] Every binding listed under "Upstream chords" still runs its upstream command on a fresh install.
- [x] On a fresh install, `winmux list-lenses --json` lists `recent`, `app-windows`, `overview`, `search` and `floating`, and each has a Trigger: `cmd-tab`, `cmd-backtick` and `alt-slash` in `main`, and `o`, `f`, `s` and `r` in the `lens` mode.
- [x] `alt-slash` opens `search`.
- [x] `alt-semicolon` enters the `lens` mode, and `winmux list-modes --current` prints `lens`.
- [x] In the `lens` mode, `o` opens `overview`, `f` opens `floating`, `s` opens `search`, and `r` opens `recent` as a list. After each, the mode is `main` again.
- [x] In the `lens` mode, `esc` returns to `main` and opens nothing.
- [x] On a fresh install Columns are off and layout is plain tree tiling, the same as upstream's.
- [x] `winmux subscribe config-reloaded` prints an event after `winmux reload-config`, once for a good config and once, with the error, for a broken one. Saving the config file with reload on save enabled prints one too.
- [x] `winmux subscribe lens-opened lens-closed` prints one event with the Lens name when a Lens opens and one when it closes.
- [x] `winmux subscribe columns-changed` prints an event after `winmux column-count 3`, after `winmux column-width next`, and when a window fills or empties a Column on the focused workspace.
- [x] `winmux subscribe --all` includes the four new events.
- [x] `winmux list-lenses --json` and `winmux list-columns --json` both print valid JSON.
## Build decisions

Decided: Checking the carried-over settings uses the existing upstream fixture in `nickel-helper/tests/fixtures/`; no `resources/default-config.toml` is recreated. This changes the chosen input location, not the comparison: converted upstream settings equal the shipped static defaults and every upstream binding is compared against the fixture.

Decided: With neither a config file nor a legacy config, startup loads defaults without creating a starter. Explicit “Open config” still writes the import-only starter; legacy bootstrap conversion remains available.

Decided: An import-only example still applies the usual `W.Config` contract. It adds no user override and equals the no-file static config.

Decided: `list-lenses --json` keeps settings introspection; it does not report Triggers. Trigger assertions read the loaded config bindings.

Decided: Ad-hoc opening and closing events carry `lens: null` and the Filter name/body retained on the session. A handoff, Presentation conversion or Search change keeps the same event pair.

Decided: Live user examples and converted output are imported unchanged by a capture wrapper that removes the three native chords and restricts Lens pixels to owned apps. Fresh-default captures use unmodified shipped defaults.

## Review rulings

Conversion keeps TOML modes and omitted upstream bindings, adding unbound fork Triggers and `lens` keys. Chord identities resolve modifier order, presets and aliases. Earlier Nickel `config-version` fields load and are ignored; conversion leaves them out. Legacy inferred persistence is materialized with a warning. **Leaving the `lens` mode** now puts `mode main` first. Column baselines are refreshed for every workspace by name, so focus-following changes emit; names replace freed-object identities. Snapshot reads create no roots or leaf arrays. Reload results use the small function called by the existing defer. Lens events start when the panel is presented, so undrawn quick taps emit nothing; immediate list and miniatures behavior and handoff pairing stay the same.

Decided: If the TOML itself redeclares one chord through two spellings, conversion fails with a binding redeclaration diagnostic rather than choosing between conflicting commands. Aliased default additions are deduplicated too, in Trigger order.

## Validation boundaries

The eighteen acceptance items are exercised by real-helper and Swift tests and isolated debug captures. Releases, a controlled monitor-size change and two physical displays are not checkable here and were not run. The umbrella's installed/release and physical-device checks remain Prateek's; they do not add a release-only acceptance item to this issue.

## Sources

- [Grilling: default Triggers and a leader mode](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/34-grilling-default-triggers.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
- [Grilling: Lens configuration shape](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/07-grilling-picker-binding-shape.md)
- [Grilling: cmd-K search Lens](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/19-grilling-cmd-k-search.md)
- [Grilling: default handling of floating and Accessory app windows](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/11-grilling-floating-and-accessory-defaults.md)
- [Prototype: grid Presentation look and behaviour](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/08-prototype-grid-presentation.md)
- [Prototype: strip Presentation look and keyboard model](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/29-prototype-strip-presentation.md)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Config language prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/27-config-language.html)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [Upstream default config](https://github.com/prateek/winmux/blob/fork/nickel-helper/tests/fixtures/upstream-default-config.toml)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
