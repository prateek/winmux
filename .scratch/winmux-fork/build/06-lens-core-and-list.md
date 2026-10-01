# Lens core and the `'list` Presentation with Search

Part of {{UMBRELLA}}.

## What to build

Build the Lens machinery that every Presentation shares: the `lenses.<name>` config record, Filter evaluation when a Lens opens, sort order, selection, marks, key actions, the `summon` command and the overlay panel. Build the first Presentation on it, `'list`, out of the existing `SwitcherPalette` (`Sources/AppBundle/ui/hud/SwitcherPalette.swift`): a Search box above ranked rows of windows. Add the CLI that opens Lenses and runs their Filters and Search for scripts. After this issue `winmux lens search` opens a searchable list of every window, and enter focuses the selection or shift-enter Summons it.

## Decisions

**The Lens record**

A Lens is the record `lenses.<name>` in the Nickel config. Its fields:

| Field | What it holds | Default |
|---|---|---|
| `filter` | A Filter: a named one (`filters.same_app`) or an inline function `fun w ctx => …` | |
| `presentation` | `'list`, `'strip`, `'miniatures` or `'grid` | |
| `entries` | What one entry of the Lens is: a window or an app | window |
| `sections` | How the `'grid` Presentation groups its tiles: none, workspace, project, monitor or app | workspace, for the grid |
| `sort` | An ordered list of sort keys, written as enum tags, for example `sort = ['mru]` | `['mru]` for `'list` and the strip, `['spatial]` for the grid |
| `keys` | A map from a key to a winmux command that runs on the selected window | see Actions |
| `frozen_thumbnail` | How a Frozen thumbnail is marked: `'plain`, `'age_badge`, `'pause_badge` or `'dimmed` | |
| `accessory_window` | How a small Accessory app window is drawn: `'enlarged` or `'actual_size` | |
| `summon_hints` | What shows while Summon's modifier is held: a list of any of `'label`, `'landing_spot`, `'target_workspace` | |
| `enabled` | `false` switches the Lens off | on |
| `when.<profile>` | A record of the same fields, merged over the Lens while that Display profile is active | |

- **`'grid` is rejected at load** as not yet supported. The value stays in the contract.
- **`sections` only affects the grid.** The strip ignores it.
- **The three look settings live on the Lens**, not in a per-Presentation record, and every Presentation reads them. The `'label` hint puts "Summon to N" on the selection, `'landing_spot` draws a dashed outline where the window will land, and `'target_workspace` outlines the current workspace.
- **`when.<profile>`.** There is one implicit Display profile, `"default"`, and it is always active. The slot stays in the shape so profile matching can be added later without reshaping the config.
- **A Lens that is off** (`enabled = false`): its Trigger does nothing, and `winmux lens <name>` exits non-zero with a message.
- **The contract checks the record at load.** An unknown field, a bad enum value or an unknown sort key fails the load.

**Sort keys**

| Key | Order |
|---|---|
| `mru` | most recently focused first, from the Global MRU |
| `previous` | the previously focused window first |
| `spatial` | tree order, left to right |
| `workspace` | sidebar order |
| `app` | by app |
| `title` | by title |
| `created` | registration order |

- Keys apply in the order listed: each later key breaks ties left by the earlier ones.
- All keys are ascending. There are no descending variants.
- Sort belongs to the Lens. A Filter never orders.

**Opening a Lens**

- **Triggers are ordinary bindings.** The command `lens <name>` goes in `mode.<mode>.binding` like any other command. Triggers are keyboard bindings only.
- **The Filter runs once, when the Lens opens,** as one batched request over all windows. An open Lens keeps its already-filtered entries until it closes, including across a config reload.
- **Both popup Window classes are left out** unless the Lens's Filter names them. For example, a Filter that wants an Accessory app's close-button-less window says so with `std.array.elem w.class ['floating, 'accessory-popup]`.
- **If the Filter fails or times out,** the Lens opens with every window and a banner saying the Filter failed.

**Actions**

- `keys` maps a key to any winmux command. The command runs with the selected window as its target, the way an `on-window-detected` command targets the detected window today.
- Default `keys`:

| Key | Command |
|---|---|
| `enter` | `focus` |
| `shift-enter` | `summon` |
| `cmd-w` | `close` |
| `cmd-<n>` | `move-node-to-workspace <n>` |

- **Mouse.** Hovering moves the selection. A click runs `enter`'s command. A modifier-click runs the matching modifier-enter binding, so shift-click Summons by default.
- **Marks.** In a Presentation with a Search box (`'list` here, not the strip), `tab` toggles a mark on the selected window. When anything is marked, a key's command runs once per marked window, in the order they were marked. Otherwise it runs on the selection. `focus` always acts on the selection alone.

**Summon**

- `summon [--window-id <id>]` is a real command. It moves the window into the current workspace. It is unrelated to the existing `summon-workspace` command.
- A Summoned window counts as a tiling window arriving on the current workspace. Once "Column Policy hooks and Column commands" lands, the `place` hook picks its Column and Overflow policy action. Until then it lands where a new tiling window lands today.
- The `arrive` hook does not run for a Summon, because the window is not new.
- Summoning several marked windows places each in turn.

**The `'list` Presentation**

- It is built from the existing `SwitcherPalette`, not written next to it.
- The Search box is always shown. Windows that do not match the Search are hidden.
- A row shows what a palette row shows today.
- With an empty Search the rows are in the Lens's `sort` order.

**Search**

- Search is the text typed into an open Lens. The Filter decides which windows are eligible, and Search narrows and ranks among them.
- **Fields.** Search matches app name, window title, workspace name and project name. It does not match the bundle id or the document path.
- **Words.** The Search splits into words. Every word must match some field, in any order.
- **Tiers.** Each word gets the best tier it reaches: exact > prefix > word-prefix > substring > acronym (`vsc` matches Visual Studio Code) > fuzzy subsequence.
- **Field weight.** Title and app matches outrank workspace and project matches.
- **Order.** An empty Search leaves the Lens's `sort` order unchanged. A non-empty Search ranks by score, and the Lens's `sort` breaks ties.
- **Remembered text.** The Search text is remembered per Lens and shown preselected on the next open, so the first keystroke replaces it. `--search` overrides it.
- This replaces the palette's current single-string fuzzy score. The matching code is written fresh. AltTab's tiered scoring is GPL-3 and is a design reference only.

**Inline Nickel in the Search box**

- A leading `=` switches the whole box to Nickel. The rest is a function body with `w` and `ctx` bound, for example `= w.class == 'floating && w.app.name == "Ghostty"`.
- Text and Nickel do not mix in one Search.
- Named Filters are callable inside it: `= filters.floating w ctx`. There are no `@name` tokens.
- The body is evaluated 150 ms after typing stops, through the helper's `eval-filter` request, in the loaded config's environment.
- While the text does not parse or fails, the last good result stays up, the first line of Nickel's error shows under the box, and the border turns amber. An error never closes or empties the Lens.
- Each evaluation gets a 50 ms budget over the whole set of windows. Past it, the box says "Filter too slow" and keeps the last result.

**Changing Presentation while open**

- `lens --presentation list`, with no Lens name, reopens the open Lens as a list. It carries over the Filter, `sort`, selection, marks and Search.
- This issue builds the command. The strip and `'miniatures` bind it in their own issues.

**The `search` Lens**

- The shipped defaults include a Lens named `search`: every window, `'list`, sorted by `mru`. It ships here because `palette` is an alias for it.
- `winmux palette` becomes an alias for `lens search`. It is to be dropped later.

**CLI**

| Command | What it does |
|---|---|
| `lens <name> [--search '<text>'] [--presentation list\|strip\|miniatures]` | Opens a configured Lens, optionally with the Search prefilled or in another Presentation |
| `lens --filter <name\|body> [--presentation …] [--sort mru,…]` | Opens an ad-hoc Lens |
| `lens --presentation list` | Reopens the open Lens as a list |
| `list-lenses [--json]` | Prints the Lens names and each Lens's settings as resolved for the active Display profile |
| `summon [--window-id <id>]` | Summons the focused window or the given one |
| `palette` | Alias for `lens search` |
| `list-windows --lens <name>` | Prints the windows that Lens's Filter matches, in its `sort` order |
| `list-windows --filter <name\|body>` | Prints the windows the Filter matches |
| `list-windows --search '<text>'` | Applies Search ranking. JSON output adds `score` and the matched field |

- **Writing an inline Filter.** `--filter` takes a Filter name or a function body with `w` and `ctx` bound, the same shape as the Search box after `=`. A bare identifier that matches a named Filter is the name. Anything else is a body.
- **Quoting.** Nickel enum tags start with `'`, which collides with shell single quotes. The docs show double quotes: `--filter "w.class == 'floating"`. `--filter -` reads the body from stdin, for anything that contains strings.
- **Failure in a script.** In a non-interactive command (`list-windows`), a Filter that fails or times out prints nothing on stdout and the Nickel diagnostic on stderr. This is the opposite of the interactive Lens, which shows every window with a banner. A script must never act on "all windows" by accident.
- **Exit codes** for the new commands: `0` success, `1` runtime failure (server down, helper unavailable), `2` bad usage or a bad Filter.
- New flags follow the existing names (`--window-id`), and every new `list-*` command takes `--json`.

## Not in this issue

- The strip, hold-and-release, reverse cycling, Option to Summon at release, the strip's key that hands off to the list, the `recent` and `app-windows` Lenses, and taking cmd+tab from the system: "Strip Presentation and the cmd+tab takeover".
- Thumbnails, drawing the Frozen thumbnail and Accessory window treatments, the Summon landing spot, Search inside `'miniatures`, the `miniatures` record and the `overview` Lens: "Thumbnail cache and the `'miniatures` Presentation". This issue only puts `frozen_thumbnail`, `accessory_window` and `summon_hints` on the Lens record.
- The default `floating` Lens: "Accessory window defaults and the `floating` Lens".
- The `place` hook that picks a Summoned window's Column: "Column Policy hooks and Column commands".
- Default key bindings for any Lens, the `lens` leader mode, and the `lens-opened` and `lens-closed` events on `subscribe`: "Default config, Triggers, the `lens` leader mode, `subscribe` events". The `search` Lens ships unbound here.
- The records a Filter reads, the smoke run, the batched request and the `eval-filter` request: "Filter contract v1 and `config schema`".
- Deferred: tabs (Search over tab titles and URLs, tab-group entries), trackpad-gesture Triggers, Display profile matching, and the `'grid` Presentation. A richer `'list` row is not specified yet.

## Depends on

- "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"
- "Filter contract v1 and `config schema`"
- "Global MRU (`lastFocusedSeq`)"

## Open details

- **Popup classes.** How does WinMux tell that a Filter "names" a popup class now that a Filter is a function and not a string? This was decided when Filters were expression strings and was never restated. Also undecided: whether the every-window result after a failed Filter includes the popup classes.
- **No `filter`.** May `filter` be left out to mean every window, as the spike config writes the `recent` Lens, or must it be written out?
- **Enum spellings.** `sort` and `sections` have Nickel examples (`['mru]`, `'workspace`). The tags for `entries` and for the other `sections` values were only ever written in TOML. The Window class tags use hyphens (`'accessory-popup`) and the look-setting tags use underscores (`'age_badge`, `'landing_spot`); both are as decided, and both can appear in one Lens record. Keep them or align them, and say which in the PR.
- **`entries` as app in `'list`.** What does an app row show, and which of the app's windows does `focus` act on?
- **`sections` in `'list`.** Decided as grid-only, with the strip ignoring it. Nothing says whether `'list` ignores it or rejects it.
- **Look settings.** Are `'dimmed`, `'enlarged` and `['label, 'landing_spot]` (the values chosen for the `overview` Lens) the field defaults for every Lens? Which of the three affect a `'list` row while rows have no thumbnail?
- **`cmd-<n>`.** Today's palette uses cmd-1 to cmd-9 to pick a row and shows a badge for it. The Lens default maps `cmd-<n>` to `move-node-to-workspace <n>`. Apply the Lens default, and decide what happens to the badge. Also undecided: whether a Lens's `keys` map is merged over the defaults or replaces them.
- **First selection in `'list`.** The strip starts on the second entry with the current window first. Nothing says where a list starts.
- **Score.** How do per-word tiers and the field weight combine into one `score`, and what is the JSON key for the matched field?
- **Summon details.** Does Summon focus the window afterwards? What does it do to a floating, minimized or hidden-app window?
- **Two budgets.** A Filter request gets 100 ms and a timed-out request makes WinMux kill the helper. The Search box's `=` budget is 50 ms. Decide whether passing 50 ms only shows "Filter too slow" while the request runs on to 100 ms.
- **`lens --filter` with a bad body.** It is an interactive command, so it could open with every window and a banner, but a bad Filter is also exit code 2. Decide which.
- **Ad-hoc Lens defaults.** Which Presentation `lens --filter` uses when `--presentation` is not given.
- **`lens` while a Lens is open.** Today `palette` toggles. Nothing says whether `lens <name>` toggles, replaces the open Lens or does nothing.
- **Disabled Lens exit code.** Only "non-zero" was decided.
- **Other profile names.** Is `when.<name>` for a name other than `default` rejected at load or kept inert?
- **`list-windows` flags.** How `--lens`, `--filter` and `--search` combine with the existing mandatory `--all | --focused | --monitor | --workspace`.
- **`'strip` and `'miniatures` before their issues land.** The Lens core needs a seam for them. What a Lens with one of those values does until then is up to the implementer.

## Done when

- [ ] A config with a `lenses.<name>` record loads, and `winmux list-lenses --json` prints its resolved settings.
- [ ] A Lens with `presentation = 'grid`, an unknown field or an unknown sort key fails `winmux config check` with a diagnostic.
- [ ] A binding `lens <name>` in `mode.main.binding` opens the Lens.
- [ ] `winmux lens search` opens a list of every window in most-recently-used order. `winmux palette` does the same.
- [ ] Popup-class windows do not appear in a Lens whose Filter does not name them.
- [ ] `enter` focuses the selected window. `shift-enter` moves it into the current workspace. `cmd-w` closes it.
- [ ] `winmux summon --window-id <id>` moves that window into the current workspace from a script.
- [ ] A custom `keys` entry runs its command against the selected window.
- [ ] Marking three windows with `tab` and pressing `shift-enter` Summons all three in the order marked. `enter` with marks present focuses only the selection.
- [ ] Hover moves the selection, click focuses, shift-click Summons.
- [ ] Typing narrows the rows. Words match in any order, `vsc` finds Visual Studio Code, and a title match ranks above a workspace-name match. Tests cover each tier.
- [ ] Clearing the Search restores the Lens's `sort` order.
- [ ] Reopening a Lens shows the last Search preselected. `winmux lens search --search 'foo'` opens with `foo` in the box.
- [ ] Typing `= w.class == 'floating` shows only floating windows. A half-typed body keeps the previous rows, shows the first line of the Nickel error and turns the border amber.
- [ ] `lens --presentation list` run while a Lens is open reopens it as a list with the same Filter, `sort`, selection, marks and Search.
- [ ] A Lens with `enabled = false` does not open, and `winmux lens <name>` exits non-zero with a message. A setting under `when.default` overrides the base Lens.
- [ ] A Lens whose Filter fails at run time opens with every window and a banner.
- [ ] `winmux lens --filter "w.class == 'floating"` opens an ad-hoc Lens. `--filter <name>` uses the named Filter. `--filter -` reads the body from stdin.
- [ ] `winmux list-windows --lens <name> --json` prints that Lens's matches in its `sort` order. `--search '<text>'` adds `score` and the matched field.
- [ ] `winmux list-windows --filter "w.nope"` prints nothing on stdout, the Nickel diagnostic on stderr, and exits 2. With the server down the command exits 1.
- [ ] Reloading the config while a Lens is open leaves its rows unchanged until it closes.

## Sources

- [Grilling: Lens configuration shape](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/07-grilling-picker-binding-shape.md)
- [Grilling: cmd-K search Lens](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/19-grilling-cmd-k-search.md)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md)
- [Prototype: strip Presentation look and keyboard model](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/29-prototype-strip-presentation.md) (the look settings move to the Lens)
- [Prototype: grid Presentation look and behaviour](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/08-prototype-grid-presentation.md) (what Summon does, and the look settings' values)
- [Prototype: filter language worked examples](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/06-prototype-filter-language.md) (Lenses leave out the popup classes)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md) (one batched request per open, `eval-filter`, failure behaviour)
- [Research 03: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md) (how `SwitcherPalette` is built today)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/wayfind-fork/docs/adr/0001-nickel-helper-process.md)
