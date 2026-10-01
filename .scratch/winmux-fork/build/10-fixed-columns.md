# Fixed Columns: slots, the count invariant, Width presets

Part of {{UMBRELLA}}.

## What to build

A workspace can be given a fixed number of Columns. Each Column keeps its position and width whether or not it holds a window, and the count holds no matter how a window gets onto the workspace. Column widths are fractions of the workspace width that can be stepped through Width presets or resized freely. This issue builds the layout model, the width handling and the built-in placement; the config hooks and the Column commands come in **Column Policy hooks and Column commands**.

## Decisions

**Where a Column lives in the tree**

- A Column is a child of the workspace's root container, and that root is `h` orientation with `tiles` layout. No new `Layout` case is added; a Column is marked by a per-workspace setting or by data on the node, not by a tree type.
- Columns belong to the workspace. Switching workspace changes every Column at once.
- A Column holds any arrangement: one window, a tab group, or splits in either direction, side by side included.
- Normalization (flatten, and opposite orientation for nested containers) leaves Column nodes alone and still applies inside them.

**Positional Columns**

- Each Column keeps its x-range and its width when it is empty. With one window on a three-Column workspace, the window sits in its Column and the other two Columns show the desktop.
- Closing a window leaves its Column empty. Nothing moves over to fill it.
- The tree cannot hold an empty container, so each root child carries a slot index. Layout places a root child by its slot index and the stored widths, not by its position in the children list.
- `focus left` and `focus right` skip empty Columns.
- An empty Column can still be the focused Column. It is drawn with a faint outline, and the next window placed in the focused Column lands there. The command that focuses an empty Column is in **Column Policy hooks and Column commands**; the model and the outline are here.

**The count is an invariant**

- The Column count holds on every path that puts a window on the workspace: a new window, `move`, `move-node-to-workspace`, drag and drop, closed-window-cache restore and `flatten-workspace-tree`. The paths that reuse new-window binding (floating to tiling, leaving native fullscreen or minimized) are covered too.
- A Column-invariant pass runs after `normalizeContainers` on every refresh, for every workspace with Columns on. It is idempotent.
- The pass forces the root to `h` and `tiles`.
- The pass counters flatten replacing the root. Today, a root whose only child is a container is replaced by that child, so a workspace with one occupied Column holding a tab group or a split ends up with a `v` or tab-group root. Either exempt the root from that flatten while Columns are on, or have the pass wrap it again.
- The pass counters the paths that wrap the root in a new root: `move` at the workspace boundary, insertion after a tab group, and `workspaceSiblingInsertionRoot`.
- The pass folds any root child beyond the count into a Column, using the built-in placement below.
- The pass re-applies the stored width fractions to the root children's weights.
- The `'squeeze` Overflow policy action is the only way to exceed the count. It is built in **Column Policy hooks and Column commands**.

**Built-in placement**

- A new tiling window goes to the nearest empty Column.
- When no Column is empty, the window joins the focused Column as a tab group. When focus is not on this workspace's tiling tree, it joins the most recently used Column instead.
- `move left` and `move right` that cross a Column edge: an empty neighbour takes the window; an occupied neighbour takes it into a tab group; at the workspace edge the move stops. Inside a Column, `move` behaves as it does today.
- Closing a window runs no placement.

**Widths**

- Column widths are fractions of the workspace width that sum to 1. They are stored per workspace and converted to point weights before every layout. The tree's weights are absolute points and `layoutTiles` spreads any difference in equal amounts, so fractions kept only as weights drift when the monitor size changes or a Column empties. `AgentSizing.swift` already turns ratios into weights and is the pattern to follow.
- `widths` in the config gives the starting widths as a list of fractions. A list that does not sum to 1 is normalized proportionally, with a warning when the config loads.
- `width-presets` in the config is the list of Width presets. It is one global list, read from the top-level `columns` record only, and it defaults to `[1/3, 1/2, 2/3]`.
- Setting a Column to a Width preset or to an explicit fraction makes its neighbours give up or take space in proportion to their widths, so the total stays 1. This issue builds that operation; the `column-width` command that calls it is in **Column Policy hooks and Column commands**.
- Free `resize` and divider drag are allowed, down to a minimum Column width. Width presets are stops, not limits.
- The minimum Column width is 80 points. It reuses upstream's resize floor, `minimumTiledResizeWeight` in `mouse/resize/TiledResizeConstraints.swift`.
- `resize` on a window that is alone in its Column resizes the Column. `resize` on a window inside a split resizes within the Column.
- `balance-sizes` resets the Column widths to the declared `widths` and balances sizes inside each Column.

**Config shape and precedence**

- The settings are read from four record paths, least specific first: `columns`, then `columns.when.<profile>`, then `workspace.<name>.columns`, then `workspace.<name>.columns.when.<profile>`.
- The most specific path wins field by field. A hook definition is replaced whole, never merged.
- `count` and `widths` can be set at all four paths, and so can the two hook fields that **Column Policy hooks and Column commands** adds. `width-presets` is the exception: it is set on `columns` only, and the contract rejects it at the other three paths.
- Every Columns field name and enum tag is spelled with hyphens, like the keys inherited from upstream and the CLI: `width-presets`, `move-boundary`, `'tab-group`, `'nearest-empty`. In Nickel `a-b` is one name, so a subtraction needs spaces around the minus.
- The `when.<profile>` slot is part of the shape now. There is one implicit profile, `"default"`, and it is the only one that ever matches.
- `count` is a number or `'off`, and the default is `'off`. That default is decided here; **Default config, Triggers, the `lens` leader mode, `subscribe` events** only ships it. With `count` off the workspace uses plain tree tiling exactly as upstream does: no slot indexes, no invariant pass, no width re-application.
- The Columns settings arrive as part of the static config the `winmux-nickel` helper returns at load. WinMux resolves the precedence chain itself at runtime, per workspace.

**Where it lands in the code** (paths under `Sources/AppBundle/`)

- The invariant pass goes right after `rootTilingContainer.unbindEmptyAndAutoFlatten()` in `tree/normalizeContainers.swift`.
- Built-in placement branches in `bindingDataForNewTilingWindow` in `tree/NewWindowBinding.swift`. About 25 other files call `bind(to:)` directly and skip that function, which is why the invariant pass has to catch what they do.
- Width handling touches `layout/layoutRecursive.swift` (`layoutTiles`), `command/impl/ResizeCommand.swift`, `command/impl/BalanceSizesCommand.swift` and the divider drag under `mouse/resize/`.
- `split` refuses to run while flatten normalization is on, so build a split inside a Column the way `join-with` does, with a wrapper container.
- A tab group with one child is not a stable node: flatten collapses it. Nothing here may depend on a one-window tab group.
- In this codebase `stack-with` makes a tab group. Do not name anything in Columns "stack".

## Not in this issue

- **Column Policy hooks and Column commands** covers the `place`, `move-boundary` and `arrive` hooks, the `'split`, `'float` and `'squeeze` Overflow policy actions, and the commands `focus-column`, `move-node-to-column`, `column-width`, `compact`, `list-columns`, `column-count` and `place --dry-run`.
- **Default config, Triggers, the `lens` leader mode, `subscribe` events** covers the `columns-changed` event. It ships `count` as `'off`, the default this issue decides.
- **Thumbnail cache and the `'miniatures` Presentation** covers drawing Columns in miniature.
- Deferred: Display profiles. That includes matching a profile to a display, resetting widths and re-flowing Columns when the profile changes, and any profile other than `"default"`.
- Deferred: trackpad gestures, including drag gestures with a ghost preview.
- Deferred: reading and switching Tabs inside windows. A tab group of windows inside a Column is in scope; it is the existing WinMux feature.

## Depends on

- Nickel config: the `winmux-nickel` helper, config load, and `config check`, `convert`, `status`

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Column index base.** Slot indexes start at 1, like the tab indexes and workspace numbers in upstream's default config.
- **`widths` left out, or the wrong length.** With `widths` omitted, every Column starts at `1/count`. A `widths` list whose length differs from `count`, once the precedence chain is resolved, is a load error.
- **Which Columns absorb a width change.** Every other Column, each in proportion to its width, not only the adjacent ones.
- **Free resize.** `resize` and divider drag on a Column take space from the other Columns in proportion to their widths, the same operation as a Width preset change. Upstream's equal-amounts spreading does not apply between Columns.
- **Stepping from a width that is not a preset.** `next` picks the smallest preset above the current width and `prev` the largest below it. Both wrap at the ends of the list.
- **Which child is the extra.** When the root has more children than the count, the invariant pass folds each root child that has no slot index, using the built-in placement.
- **"Nearest" empty Column.** Distance is counted in slot indexes from the focused Column. A tie goes to the left.
- **`move up` and `move down` at the top or bottom of a Column.** The move stops, as `move left` and `move right` do at the workspace edge. Upstream wraps the root in a new `v` root here, which the invariant forbids.
- **`auto-add-new-windows-to-tab-group`.** Ignored on a workspace with Columns on, where built-in placement decides. It still applies on a workspace with `count` off.
- **Config reload.** A reload resets each workspace's stored widths to the declared `widths`. When a reload lowers the count, the invariant pass folds the extra Columns' contents.
- **Gaps and empty Columns.** Inner gaps are still reserved next to an empty Column, so occupied Columns do not shift when a neighbour empties.

## Done when

- [ ] With `count` off, the existing layout tests pass unchanged and layout is the same as upstream's.
- [ ] `winmux config check` accepts a config that sets `columns.count`, `columns.widths` and `columns.width-presets`, and a `workspace.<name>.columns` record overrides `count` and `widths` field by field for that workspace only.
- [ ] `width-presets` set under `workspace.<name>.columns` or under a `when` record fails `winmux config check`. With `columns.width-presets` left out, the Width presets are 1/3, 1/2 and 2/3.
- [ ] A `columns.when.default` record overrides `columns`, and a `when` record under any other profile name loads and never applies.
- [ ] `widths` that do not sum to 1 load with a warning and are normalized proportionally.
- [ ] On a three-Column workspace with one window, the window occupies only its Column's x-range and the other two Columns are empty.
- [ ] Opening a second and a third window fills the empty Columns. A fourth joins the focused Column as a tab group, and the root still has three children.
- [ ] Closing the only window in a Column leaves that Column empty, and no other window moves or changes width.
- [ ] With every window but one closed, and that one in a tab group or a split, the root is still `h` and `tiles` after a refresh.
- [ ] `move right` into an empty Column moves the window there. Into an occupied Column it joins a tab group. At the workspace edge it does nothing and the root is not wrapped.
- [ ] `move-node-to-workspace`, drag and drop, `flatten-workspace-tree` and closed-window-cache restore each leave the target workspace with no more root children than the count.
- [ ] `focus left` and `focus right` skip empty Columns.
- [ ] A focused empty Column shows a faint outline, and the next new window lands in it. Until `focus-column` exists, a test sets the focused Column directly.
- [ ] After the monitor's size changes, every Column has the same fraction of the width as before.
- [ ] Setting a Column to a Width preset changes its width to that fraction and the widths still sum to 1. Until `column-width` exists, a test calls the operation directly.
- [ ] `resize` on a window alone in its Column changes the Column's width and stops when the Column is 80 points wide. `resize` on a window inside a split leaves the Column's width alone.
- [ ] `balance-sizes` returns the Column widths to the declared `widths`.
- [ ] Unit tests in `Sources/AppBundleTests` cover the invariant pass, including the flatten-replaces-root case with several windows, which upstream's tests do not cover.
## Sources

- [Grilling: fixed Columns, Width presets and Overflow policy semantics](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/09-grilling-fixed-columns-model.md)
- [Research: WinMux layout engine seams for fixed Columns](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/04-research-layout-engine-for-columns.md)
- [Research 04: WinMux layout engine seams for fixed Columns (findings)](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/research/04-layout-engine-for-columns.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
- [Prototype: config and scripting language](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/27-prototype-config-language.md)
- [Config language prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/27-config-language.html)
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
