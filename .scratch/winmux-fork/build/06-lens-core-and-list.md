# Lens core and the `'list` Presentation with Search

Part of {{UMBRELLA}}.

## What to build

Build the Lens machinery that every Presentation shares: the `lenses.<name>` config record, Filter evaluation when a Lens opens, sort order, selection, marks, key actions, the `summon` command and the overlay panel. Build the first Presentation on it, `'list`, out of the existing `SwitcherPalette` (`Sources/AppBundle/ui/hud/SwitcherPalette.swift`): a Search box above ranked rows of windows. Add the CLI that opens Lenses and runs their Filters and Search for scripts. After this issue `winmux lens search` opens a searchable list of every window, and enter focuses the selection or shift-enter Summons it.

## Decisions

**The Lens record**

A Lens is the record `lenses.<name>` in the Nickel config. Its fields:

| Field | What it holds | Default |
|---|---|---|
| `filter` | A Filter: a named one (`filters.same-app`) or an inline function `fun w ctx => …` | left out, which means every window |
| `presentation` | `'list`, `'strip`, `'miniatures` or `'grid` | |
| `entries` | What one entry of the Lens is: `'window` or `'app` | `'window` |
| `sections` | How the `'grid` Presentation groups its tiles: `'none`, `'workspace`, `'project`, `'monitor` or `'app` | `'workspace`, for the grid |
| `sort` | An ordered list of sort keys, written as enum tags, for example `sort = ['mru]` | `['mru]` for `'list` and the strip, `['spatial]` for the grid |
| `keys` | A map from a key to a winmux command that runs on the selected window | see Actions |
| `popups` | The popup Window classes the Lens includes: a list of any of `'accessory-popup`, `'app-popup` | `[]` |
| `frozen-thumbnail` | How a Frozen thumbnail is marked: `'plain`, `'age-badge`, `'pause-badge` or `'dimmed` | `'dimmed` |
| `accessory-window` | How a small Accessory app window is drawn: `'enlarged` or `'actual-size` | `'enlarged` |
| `summon-hints` | What shows while Summon's modifier is held: a list of any of `'label`, `'landing-spot`, `'target-workspace` | `['label, 'landing-spot]` |
| `enabled` | `false` switches the Lens off | `true` |
| `when.<profile>` | A record of the same fields, merged over the Lens while that Display profile is active | |

- **Spelling.** Every field name and enum tag this issue adds uses hyphens, never underscores: `frozen-thumbnail`, `accessory-window`, `summon-hints`, `'age-badge`, `'pause-badge`, `'actual-size`, `'landing-spot`, `'target-workspace`, `'accessory-popup`. A Lens name with more than one word is hyphenated the same way.
- **`filter` may be left out.** A Lens with no `filter` matches every window.
- **`'grid` is rejected at load** as not yet supported. The value stays in the contract.
- **`sections` only affects the grid.** The strip ignores it.
- **The three look settings live on the Lens**, not in a per-Presentation record, and every Presentation reads them. The `'label` hint puts "Summon to N" on the selection, `'landing-spot` draws a dashed outline where the window will land, and `'target-workspace` outlines the current workspace.
- **`when.<profile>`.** There is one implicit Display profile, `"default"`, and it is always active. The slot stays in the shape so profile matching can be added later without reshaping the config. A `when` record under any other profile name loads and never applies.
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
| `created` | creation order: window id, which macOS gives out from one counter in creation order |

- Keys apply in the order listed: each later key breaks ties left by the earlier ones.
- All keys are ascending. There are no descending variants.
- Sort belongs to the Lens. A Filter never orders.

**Opening a Lens**

- **Triggers are ordinary bindings.** The command `lens <name>` goes in `mode.<mode>.binding` like any other command. Triggers are keyboard bindings only.
- **The Filter runs once, when the Lens opens,** as one batched request over all the Lens's candidate windows. An open Lens keeps its already-filtered entries until it closes, including across a config reload, and its key actions keep working on them.
- **Popup-class windows are opted into with `popups`.** A Lens's candidates are every window of a non-popup class, plus the windows of each popup class its `popups` field lists. A window of a popup class that is not listed never reaches the Lens's Filter. With the default `popups = []` a Lens shows no popup-class windows, whatever its Filter says. A Lens that wants an Accessory app's close-button-less windows sets `popups = ['accessory-popup]`, and its Filter still decides window by window.
- **Two kinds of window live outside every workspace.** Today's palette and `list-windows` collect windows by walking the workspaces, which misses both. Minimized windows sit in a global container (`macosMinimizedWindowsContainer`) and are always candidates, so a Lens and `list-windows --lens`, `--filter` and `--search` read that container too. Those three flags therefore list minimized windows that a bare `list-windows --all` does not. Popup-class windows sit in another (`macosPopupWindowsContainer`), which is read only for the classes `popups` lists.
- **If the Filter fails or times out,** the Lens opens with every candidate window and a banner saying the Filter failed. `popups` still applies: popup classes that are not listed stay out.
- **Running `lens` while a Lens is open.** `lens <name>` for the Lens that is already open closes it, as `palette` toggles today. `lens <other>` replaces the open Lens with the other one.

**Actions**

- `keys` maps a key to any winmux command. The command runs with the selected window as its target, the way an `on-window-detected` command targets the detected window today.
- Default `keys`:

| Key | Command |
|---|---|
| `enter` | `focus` |
| `shift-enter` | `summon` |
| `alt-enter` | `summon` |
| `cmd-w` | `close` |
| `cmd-<n>` | `move-node-to-workspace <n>` |

- **`cmd-<n>` replaces the palette's quick-select.** Today's palette uses cmd-1 to cmd-9 to pick the Nth row and shows a badge for it. Both go: `cmd-<n>` runs its `keys` command, and rows carry no number badge.
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
- A row shows what a palette row shows today, without the cmd-number badge.
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

- The `search` Lens is defined in `defaults.ncl`, the shipped defaults file that a user's config imports and merges over explicitly. This issue adds it there: every window, `'list`, sorted by `mru`. It ships here because `palette` is an alias for it.
- `winmux palette` becomes an alias for `lens search`. It is to be dropped later.
- A config that does not import `defaults.ncl` and defines no `search` Lens has none, and `palette` then fails the way `lens search` does.

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
- **`list-windows` scope.** `list-windows` requires one of `--focused`, `--all`, `--monitor` or `--workspace` today. `--lens`, `--filter` and `--search` imply `--all` when no scope flag is given. With a scope flag, the output is the windows that are both in that scope and matched.
- **Failure in a script.** In a non-interactive command (`list-windows`), a Filter that fails or times out prints nothing on stdout and the Nickel diagnostic on stderr. This is the opposite of the interactive Lens, which shows every window with a banner. A script must never act on "all windows" by accident.
- **Exit codes** for the new commands: `0` success, `1` runtime failure (server down, helper unavailable), `2` bad usage or a bad Filter.
- New flags follow the existing names (`--window-id`), and every new `list-*` command takes `--json`.

## Not in this issue

- The strip, hold-and-release, reverse cycling, Option to Summon at release, the strip's key that hands off to the list, the `recent` and `app-windows` Lenses, and taking cmd+tab from the system: "Strip Presentation and the cmd+tab takeover".
- Thumbnails, drawing the Frozen thumbnail and Accessory window treatments, the Summon landing spot, Search inside `'miniatures`, the `miniatures` record and the `overview` Lens: "Thumbnail cache and the `'miniatures` Presentation". This issue only puts `frozen-thumbnail`, `accessory-window` and `summon-hints` on the Lens record.
- The default `floating` Lens, and which popup class a popup-classified window carries: "Accessory window defaults and the `floating` Lens".
- The `place` hook that picks a Summoned window's Column: "Column Policy hooks and Column commands".
- Default key bindings for any Lens, the `lens` leader mode, and the `lens-opened` and `lens-closed` events on `subscribe`: "Default config, Triggers, the `lens` leader mode, `subscribe` events". The `search` Lens ships unbound here.
- The batched Filter request, the `eval-filter` request, their timeouts and the smoke-run loop: "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`".
- The records a Filter reads, their contracts and the smoke run's synthetic values: "Filter contract v1 and `config schema`".
- Deferred: tabs (Search over tab titles and URLs, tab-group entries), trackpad-gesture Triggers, Display profile matching, and the `'grid` Presentation. A richer `'list` row is not specified yet.

## Depends on

- "Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`"
- "Filter contract v1 and `config schema`"
- "Global MRU (`lastFocusedSeq`)"

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **`entries = 'app` in `'list`.** A row shows the app's icon, its name and its window count. `focus` goes to the app's most recently focused window.
- **`sections` in `'list`.** Ignored, as the strip ignores it.
- **Look-setting defaults.** `frozen-thumbnail = 'dimmed`, `accessory-window = 'enlarged` and `summon-hints = ['label, 'landing-spot]` are the field defaults for every Lens, so a record can omit them. A `'list` row ignores `frozen-thumbnail` and `accessory-window`. The `'label` hint shows on the selected row.
- **A Lens's `keys` merges over the defaults.** The merge is field by field, as a Nickel record merge: a Lens that sets one key keeps the other defaults.
- **First selection in `'list`.** The second row when the first row is the focused window, otherwise the first row.
- **Score.** `score` is the sum, over the Search's words, of tier weight times field weight. Tier weights run from 6 (exact) down to 1 (fuzzy subsequence). Title and app have field weight 2, workspace and project 1. For each word choose the field with the highest tier weight times field weight; title and app win a weighted tie over workspace and project. Remaining ties prefer title before app, workspace before project. Thus `my mail` on workspace `mailbox` contributes 8 from title, rather than 5 from workspace. The JSON key for the matched field is `matched-field`.
- **What Summon does after moving.** Summon focuses the window once it is placed. A floating window moves and stays floating. A minimized or hidden-app window is restored the way `focus` restores it.
- **Minimized and popup actions.** Focus restores a minimized window to its origin (recreating a cleaned-up workspace), falling back to the current workspace only when the origin is unknown. Summon restores it on the current workspace. Workspace moves restore minimized/hidden windows before moving, preserving floating layout. Close does not restore. Popup Focus raises it natively and Close closes it; Summon and workspace moves fail without mutating the popup tree.
- **Reserved keys.** Escape, Tab and all four arrows, including modifier variants, are rejected in Lens `keys` at load. They belong to the list's navigation. Hover changes selection only when the pointer moves.
- **Candidate failures.** AX record reads overlap; results preserve candidate order. A failed/missing record drops that window from the open or script request; context reads of a failed record become null.
- **The two budgets.** The Search box's 50 ms is a display deadline: past it the box says "Filter too slow" and keeps the last result, while the request runs on. At 100 ms the helper's own timeout applies.
- **`lens --filter` with a bad body.** A body that does not parse or breaks the contract exits 2 and opens nothing. A Filter that fails at run time or times out opens with every candidate window and the banner.
- **Ad-hoc Lens Presentation.** `lens --filter` without `--presentation` opens as `'list`.
- **Ad-hoc Lenses and popups.** `lens --filter` and `list-windows --filter` behave as a Lens with `popups = []`. `list-windows --lens <name>` uses that Lens's `popups`.
- **Disabled Lens exit code.** Both `winmux lens <name>` and `winmux list-windows --lens <name>` on a Lens with `enabled = false` exit 2 with the same diagnostic and nothing on stdout.
- **`'strip` and `'miniatures` before their issues land.** The contract accepts both values. Opening such a Lens falls back to `'list` and writes a log line.

## Build notes

Implemented on `prateek/lens-core-list`, open as pull request #26 and awaiting driver push/CI/review. The review fixes clarify Score, disabled script Lenses, unconventional row actions, reserved navigation keys and per-window AX failure handling above.

- A configured Lens that omits `presentation` defaults to `'list`; the original field table left that default blank.
- Search reads the displayed workspace/project names; Filter records keep their existing workspace/project ids. When different words match different fields, JSON joins their names with commas in `matched-field`.
- Ad-hoc and script Filter bodies use the helper’s new `check-filter` preflight. This catches an invalid body even when an explicit scope contains no windows. Runtime evaluation failures still follow the interactive/banner and script/fail-closed policies.
- Configured key equivalents run before Search editing can consume Command shortcuts (such as Cmd+X).
- `cmd-1` through `cmd-9` use the existing workspace-number command. Summon restores minimized/hidden windows, preserves floating layout, then uses the existing move/focus path without `arrive`. Column placement remains a later issue.
- Popup-class inclusion is tested at the candidate seam; live Accessory classification is still issue #8. A real native fullscreen Space was not exercised.
- `make check` and the debug live run cover the checked items below. The driver’s PR description and report list the tests and captures. CI on the latest commit remains the driver’s check after pushing the review fixes.

## Done when

- [x] A config with a `lenses.<name>` record loads, and `winmux list-lenses --json` prints its resolved settings.
- [x] A Lens with `presentation = 'grid`, an unknown field (for example `frozen_thumbnail`, with an underscore) or an unknown sort key fails `winmux config check` with a diagnostic.
- [x] A Lens record with no `filter` loads and shows every window.
- [x] A binding `lens <name>` in `mode.main.binding` opens the Lens.
- [x] With a config that imports `defaults.ncl`, `winmux lens search` opens a list of every window in most-recently-used order. `winmux palette` does the same.
- [x] `winmux lens <name>` run while that Lens is open closes it. `winmux lens <other>` run while a Lens is open replaces it with the other Lens.
- [x] A Lens with the default `popups = []` shows no popup-class window, even when its Filter is `fun w ctx => true`. The same Lens with `popups = ['accessory-popup]` shows `'accessory-popup` windows its Filter matches and still no `'app-popup` window.
- [x] `enter` focuses the selected window. `shift-enter` moves it into the current workspace. `cmd-w` closes it.
- [x] `cmd-1` moves the selected window to workspace 1 and does not pick the first row. Rows show no cmd-number badge.
- [x] `winmux summon --window-id <id>` moves that window into the current workspace from a script.
- [x] A custom `keys` entry runs its command against the selected window.
- [x] Marking three windows with `tab` and pressing `shift-enter` Summons all three in the order marked. `enter` with marks present focuses only the selection.
- [x] Hover moves the selection, click focuses, shift-click Summons.
- [x] Typing narrows the rows. Words match in any order, `vsc` finds Visual Studio Code, and a title match ranks above a workspace-name match. Tests cover each tier.
- [x] Clearing the Search restores the Lens's `sort` order.
- [x] Reopening a Lens shows the last Search preselected. `winmux lens search --search 'foo'` opens with `foo` in the box.
- [x] Typing `= w.class == 'floating` shows only floating windows. A half-typed body keeps the previous rows, shows the first line of the Nickel error and turns the border amber.
- [x] `lens --presentation list` run while a Lens is open reopens it as a list with the same Filter, `sort`, selection, marks and Search.
- [x] A Lens with `enabled = false` does not open, and `winmux lens <name>` exits non-zero with a message.
- [x] A setting under `when.default` overrides the base Lens. A `when` record under any other profile name loads and never applies.
- [x] A Lens whose Filter fails at run time opens with every candidate window and a banner, and still shows no popup-class window it did not list in `popups`.
- [x] `winmux lens --filter "w.class == 'floating"` opens an ad-hoc Lens. `--filter <name>` uses the named Filter. `--filter -` reads the body from stdin.
- [x] `winmux list-windows --lens <name> --json`, with no scope flag, prints that Lens's matches across all workspaces in its `sort` order. Adding `--workspace <name>` prints only the matches on that workspace. `--search '<text>'` adds `score` and the matched field.
- [x] `winmux list-windows --filter "w.nope"` prints nothing on stdout, the Nickel diagnostic on stderr, and exits 2. With the server down the command exits 1.
- [x] A Lens open during a config reload keeps its entries and still acts on a selection.

## Sources

- [Grilling: Lens configuration shape](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/07-grilling-picker-binding-shape.md)
- [Grilling: cmd-K search Lens](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/19-grilling-cmd-k-search.md)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md) (the `popups` field, hyphenated names, `defaults.ncl`)
- [Prototype: strip Presentation look and keyboard model](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/29-prototype-strip-presentation.md) (the look settings move to the Lens)
- [Prototype: grid Presentation look and behaviour](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/08-prototype-grid-presentation.md) (what Summon does, and the look settings' values)
- [Prototype: filter language worked examples](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/06-prototype-filter-language.md) (the popup Window classes)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/27-prototype-config-language.md) (a Lens record with no `filter`)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md) (one batched request per open, `eval-filter`, failure behaviour)
- [Research 03: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md) (how `SwitcherPalette` is built today)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/fork/docs/adr/0001-nickel-helper-process.md)
