# Column Policy hooks and Column commands

Part of {{UMBRELLA}}.

## What to build

Three Policy hooks let the config decide where windows go: `arrive` for a newly detected window, `place` for a tiling window arriving on a workspace, and `move-boundary` for a move that crosses a Column edge. Each returns one action from a fixed set, plus an optional list of commands to run afterwards. This issue also adds the `winmux` commands that drive Columns from the keyboard and from scripts.

## Decisions

**Hooks in general**

- A hook is a Nickel function in the config. It is a pure function of its arguments.
- A hook returns a record of fixed actions, which a contract checks, and may add `run`: a list of winmux commands that execute after the action has settled.
- The result fields are `workspace`, `float`, `column`, `overflow`, `action` and `run`.
- Hook names, result fields and enum tags are spelled with hyphens, like the keys inherited from upstream and the CLI: `move-boundary`, `'tab-group`, `'nearest-empty`, `'next-workspace`. In Nickel `a-b` is one name, so a subtraction in a hook body needs spaces around the minus.
- Each hook call is one request to the `winmux-nickel` helper. The helper answers requests in strict order, one at a time.
- A hook call gets 50 ms. Past that, or when the helper is unavailable, WinMux does what it would do with no hook configured: the built-in placement and the built-in boundary move from **Fixed Columns: slots, the count invariant, Width presets**.
- A hook that raises an error, or returns a record that breaks its contract, gets the same fallback as a timeout.
- `run` commands target the window the hook was called for, as upstream's detection callbacks target the detected window (`Sources/AppBundle/tree/WindowDetectedCallbacks.swift`). `run` executes for a Summon, which is an arrival, and never for `place --dry-run`.
- The `place` and `move-boundary` hooks are fields of the `columns` record, so they follow its precedence chain: `columns`, `columns.when.<profile>`, `workspace.<name>.columns`, `workspace.<name>.columns.when.<profile>`. A more specific hook definition replaces a less specific one whole. `arrive` is a top-level field of the config.
- The load-time smoke run calls each hook twice, once with the Filter context's `focused`, `mouse` and `previous` windows set and once with all three `null`.
- The request and reply plumbing for hook calls comes from **Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`**. This issue fills in what each hook request carries and adds the contracts for the three hooks' results.

**What a hook receives**

- The window, as the Window record of Filter contract version 1.
- The Filter context.
- The workspace's Columns, as a list of Column records. A Column record has `index` (Number), `width` (Number, a fraction), `empty` (Bool) and `windows` (Array of Window).
- `move-boundary` also receives a boolean that is true when the move is at the workspace edge.
- The arguments come in that order: `place` and `arrive` are written `fun w ctx cols => …`, and `move-boundary` is `fun w ctx cols edge => …`.
- `arrive` receives the Columns of the workspace the window was detected on.

**`place`**

- `place` runs when a tiling window arrives on a workspace.
- It returns `column`, the target Column: a Column index, or one of `'focused`, `'mru`, `'nearest-empty`, `'last`.
- It returns `overflow`, the Overflow policy action used when the target Column is occupied: `'tab-group`, `'split`, `'float` or `'squeeze`.
- `'tab-group` joins the target Column's tab group, creating one if the Column holds a single window.
- `'split` puts the window in a `v` `tiles` container with the Column's contents. Build that container the way `join-with` does, with a wrapper; upstream's `split` command refuses to run under flatten normalization and cannot be used for this.
- `'float` makes the window floating instead of placing it in a Column.
- `'squeeze` adds a Column beyond the count. It is the only way to exceed the count.
- No action is named "stack": `stack-with` already makes a tab group in this codebase.
- With no `place` hook, the built-in placement applies: the nearest empty Column, else `'tab-group` into the focused Column, or into the most recently used Column when focus is not on this workspace's tiling tree.

**`arrive`**

- `arrive` replaces `[[on-window-detected]]`. It runs once for each newly detected window, and its result decides where the window is first placed. Upstream binds a new window into the tree before the detection callbacks run; that ordering goes away.
- It returns any of: `workspace` (send the window to that workspace), `float` (make it floating), `column` and `overflow` (as `place` returns them), and `run`.
- For a tiling window, a result with no `column` falls through to `place`.
- When `arrive` returns a `workspace` and no `column`, WinMux routes the window first, then calls `place` with the target workspace's Columns.
- A window of an Accessory app that would otherwise be tiled floats by default, and `arrive` can override that. The default itself belongs to **Accessory window defaults and the `floating` Lens**.

**Summon**

- A Summoned window counts as a tiling window arriving on the current workspace. `place` picks its Column and Overflow policy action. `arrive` does not run, because the window is not new.
- Summoning several marked windows runs `place` once per window, in order.
- A Lens shows a landing spot for Summon, which is `place`'s answer for the selected window. This issue provides a call that returns that answer without moving anything. The same call backs `place --dry-run`.

**`move-boundary`**

- `move-boundary` runs when `move left` or `move right` crosses a Column edge.
- An empty neighbouring Column takes the window. The hook is not asked.
- Into an occupied Column it returns an `action` of `'join`, with an `overflow` Overflow policy action, or `'swap`.
- At the workspace edge it returns an `action` of `'stop`, `'wrap`, `'next-workspace` or `'next-monitor`.
- With no hook, the move is `'join` using `place`'s Overflow policy action, and `'stop` at the edge.
- Closing a window has no hook.

**Commands**

- `focus-column <n>` focuses Column `n`. It can focus an empty Column, which then shows the faint outline and receives the next window placed in the `'focused` Column.
- `move-node-to-column <n>` moves the focused window to Column `n`.
- `column-width next|prev|<fraction>` steps the focused Column through the Width presets, or sets it to the given fraction. The other Columns give up or take space in proportion, so the total stays 1.
- `compact` packs the workspace's windows on demand, closing up empty Columns. Nothing packs on its own when a window closes.
- `list-columns [--json]` prints each Column's index, width, whether it is empty, and its window ids.
- `column-count <n>|off` overrides the Column count at runtime. The override lasts until the next config reload.
- `place --dry-run --window-id <id>` explains which hook result the window would get, without moving it.
- `move`, `resize` and `balance-sizes` keep their names, with the behaviour **Fixed Columns: slots, the count invariant, Width presets** gives them.
- Exit codes: 0 for success, 1 for a runtime failure (server down, helper unavailable), 2 for bad usage.
- Flags follow the existing names, such as `--window-id`.

## Not in this issue

- **Fixed Columns: slots, the count invariant, Width presets** covers the slot model, the invariant pass, the width operations these commands call, and the built-in placement used when no hook answers.
- **Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`** covers the helper's supervision: killing and respawning a helper whose request timed out, the crash backoff and the circuit breaker.
- **Filter contract v1 and `config schema`** covers the Window, App, Monitor, Filter context and Column records and how `config schema` prints them.
- **Lens core and the `'list` Presentation with Search** covers the `summon` command and marking several windows.
- **Strip Presentation and the cmd+tab takeover** and **Thumbnail cache and the `'miniatures` Presentation** cover drawing the Summon landing spot.
- **Default config, Triggers, the `lens` leader mode, `subscribe` events** covers the `columns-changed` event.
- Deferred: Display profiles, including profile commands and any profile other than `"default"`.
- Deferred: trackpad gestures.
- Deferred: Tabs inside windows and the tab commands.

## Depends on

- Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`
- Filter contract v1 and `config schema`
- Fixed Columns: slots, the count invariant, Width presets

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Telling the user about a failed hook.** A hook that raises or breaks its contract is logged and shown as the last error in `winmux config status`. There is no notification per call.
- **A Column index out of range.** A hook result whose `column` is a number greater than the count is treated as a contract failure, so the built-in placement applies. `focus-column` and `move-node-to-column` with such a number exit 2 with a message.
- **`count` off.** On a workspace with Columns off, `place` and `move-boundary` do not run. `arrive` still runs there, with an empty Columns list, so it can still route and float windows.
- **Overriding the Accessory default.** An `arrive` result with `float = false` tiles an Accessory app window.
- **Which paths run which hook.** Every path that makes a window a tiling window on a workspace runs `place`: floating to tiling, leaving minimized or native fullscreen, closed-window-cache restore, `move-node-to-workspace`, and drag and drop. Only detection of a new window runs `arrive`.
- **`'squeeze`.** The extra Column gets the average width of the existing Columns, taken from them in proportion to their widths. When it empties, the invariant pass removes it and re-applies the declared widths.
- **`move-node-to-column` into an occupied Column.** The window joins that Column's tab group, the built-in Overflow policy action.
- **`compact`.** Windows pack toward Column 1. Column widths stay with the slots and do not move with the windows.
- **`column-count` scope.** The override applies to the focused workspace. When it lowers the count, the invariant pass folds the extra Columns' contents.
- **`list-columns` scope and JSON keys.** It prints the focused workspace, or the one named by `--workspace <name>`. The JSON keys are `index`, `width`, `empty` and `window-ids`.
- **`place --dry-run` output.** One line per decision, such as `column 2 (focused), overflow tab-group, hook columns.place`. It also takes `--json`.

## Done when

- [ ] A config with `arrive`, `place` and `move-boundary` hooks loads. A hook whose smoke run returns an unknown action fails `winmux config check` with the Nickel diagnostic.
- [ ] A new tiling window lands in the Column the `place` hook returns. With the target occupied, each of `'tab-group`, `'split`, `'float` and `'squeeze` does what it says.
- [ ] `'squeeze` leaves the workspace with one Column more than the count; no other path does.
- [ ] An `arrive` hook that branches on its Columns argument sees the Columns of the workspace the window was detected on.
- [ ] An `arrive` hook that returns a `workspace` sends the window there, and `place` then runs with that workspace's Columns.
- [ ] An `arrive` hook that returns `float = true` makes the window floating, and `place` does not run.
- [ ] A hook's `run` commands execute after the window has been placed, and they act on that window, not on the focused one.
- [ ] `summon` on a window from another workspace runs `place` and not `arrive`, and the `run` commands of that `place` result execute.
- [ ] `move right` into an occupied Column follows the `move-boundary` result for `'join` and for `'swap`; at the workspace edge it follows `'stop`, `'wrap`, `'next-workspace` and `'next-monitor`.
- [ ] A hook whose body is expensive enough to run past 50 ms, and a killed helper, both result in the built-in placement, and the window is still placed.
- [ ] A hook that raises an error for one window, and a hook whose result breaks the contract for one window, both result in the built-in placement for that window.
- [ ] `winmux focus-column 2` focuses Column 2, including when it is empty, and the next new window with a `'focused` target lands there.
- [ ] `winmux move-node-to-column 3` moves the focused window to Column 3.
- [ ] `winmux column-width next` and `prev` step through the Width presets, `winmux column-width 0.5` sets the fraction, and the widths still sum to 1.
- [ ] `winmux compact` leaves no empty Column between occupied ones.
- [ ] `winmux list-columns --json` prints index, width, empty and window ids for each Column.
- [ ] `winmux column-count 2` changes the count at once, `winmux column-count off` returns the workspace to plain tree tiling, and `winmux reload-config` restores the configured count.
- [ ] `winmux place --dry-run --window-id <id>` prints the hook result for that window, moves nothing, and runs none of the result's `run` commands.
- [ ] Each new command exits 0 on success, 1 with the server down, and 2 on bad usage.
## Sources

- [Grilling: fixed Columns, Width presets and Overflow policy semantics](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/09-grilling-fixed-columns-model.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Config language prototype](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/27-config-language.html)
- [Prototype: grid Presentation look and behaviour](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/08-prototype-grid-presentation.md)
- [Grilling: where the Nickel evaluator runs](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/31-grilling-nickel-evaluator-process.md)
- [Grilling: the Filter contract's final field list](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/33-grilling-filter-contract-field-list.md)
- [Grilling: CLI surface for the fork's features](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/20-grilling-cli-surface.md)
- [Research 04: WinMux layout engine seams for fixed Columns (findings)](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/04-layout-engine-for-columns.md)
- [ADR 0001: Nickel runs in a supervised helper process](https://github.com/prateek/winmux/blob/wayfind-fork/docs/adr/0001-nickel-helper-process.md)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/wayfind-fork/CONTEXT.md)
