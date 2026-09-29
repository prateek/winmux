# Research 04: WinMux layout engine seams for fixed Columns

Ticket: [04-research-layout-engine-for-columns](../issues/04-research-layout-engine-for-columns.md)
Sources: WinMux source at `470eedbf` (paths relative to `Sources/AppBundle/` unless noted). I read the code and did not run the tests. Where a claim comes from reading code rather than a test, I say so.

## TL;DR

- A Column maps onto what the tree already has: a child of an `h`-oriented, `tiles`-layout root container. Each child is a bare window, a `v` tiles container (a stack), or a `tabGroup` container. No new layout math is needed.
- Recommended seam: **(C) a policy on window insertion** in `bindingDataForNewTilingWindow`, which enforces the Overflow policy, plus **(B) a Column invariant on the workspace root**, which is a small pass after `normalizeContainers` together with Width presets stored as fractions and re-applied before layout. **Don't add a new `Layout` case (A).**
- What fights it: flatten normalization can replace the root with a single stacked Column. `layoutTiles` redistributes width in equal absolute amounts, so fractions drift on display change and on close. `balance-sizes` wipes presets. About a dozen other code paths bind windows into the tree without going through the new-window policy.

## 1. How layout works today

### Tree model
- `TilingContainer` has an `orientation` (`h`/`v`) and a `layout`. `Layout` has exactly two cases, `tiles` and `tabGroup` (`tree/TilingContainer.swift:4-8`, `:58-61`).
- A workspace has zero or one root `TilingContainer`. It is created lazily with `default-root-container-orientation` (`auto` means `h` when the monitor is wider than tall) and `default-root-container-layout` (`tree/WorkspaceEx.swift:21-36`; defaults `tiles`/`auto` at `config/Config.swift:42-43`).
- Floating windows are direct children of the `Workspace` (`tree/WorkspaceEx.swift:38-40`; `command/impl/LayoutCommand.swift:83`).

### Weights and sizing
- Each node has one `adaptiveWeight`. Its meaning comes from the parent: it is the node's size along the parent's orientation (`tree/TreeNode.swift:9`, `:50-64`). Weights can only be set when the parent is a `tiles` container, otherwise the code calls `die` (`tree/TreeNode.swift:34-48`).
- The root's weight is the workspace's weight, which is the monitor's padded visible width or height in points (`tree/TreeNode.swift:57`; `tree/WorkspaceType.swift:43-45`). **Weights are absolute points, not fractions.**
- Binding with `WEIGHT_AUTO` sets the new child to the *average* of its siblings' weights (`tree/TreeNode.swift:75-83`).
- `layoutTiles` computes `delta = (available − Σweights) / childCount` and adds the **same absolute delta** to every child, so the weights sum to the space available again. Then it walks the children, applying inner gaps (`layout/layoutRecursive.swift:159-191`). This one line is what renormalizes weights after an insertion, a removal, or a monitor resize.
- `layoutTabGroup` gives the full rect to the MRU child and parks the other tabs in the corner when WinMux window tabs are on. Otherwise it uses the AeroSpace accordion padding (`layout/layoutRecursive.swift:194-255`). A container counts as a window tab group only when it is `tabGroup` **and has more than one child** (`tree/TreeNodeEx.swift:163-166`; `ui/tabs/TilingContainer+WindowTabs.swift:5-7`).
- Entry point: `Workspace.layoutWorkspace()` uses the padded visible rect, special-cases fullscreen tabs and windows, then recurses (`layout/layoutRecursive.swift:6-36`).

### Refresh pipeline
- `runRefreshSessionBlocking` runs `refreshModel()` (reconcile workspaces, focus callbacks, `normalizeContainers` for every workspace), then `layoutWorkspaces()` (`layout/refresh.swift:137-164`, `:299-303`, `:459-464`).
- `Workspace.normalizeContainers()` does two things: it flattens single-child containers and removes empty ones, and it forces nested containers to alternate orientation (`tree/normalizeContainers.swift:1-32`). Both are on by default (`config/Config.swift:40`, `:51`).
- Screen-parameter changes arrive through `MonitorConfigurationObserver` and trigger a refresh (`ui/core/MonitorConfigurationObserver.swift:15-32`). This is the natural place for Display profile re-application (ticket 05/10 territory).

### New-window insertion (`tree/NewWindowBinding.swift`)
1. `MacWindow.getOrRegister` calls `unbindAndGetBindingDataForNewWindow` *before* on-window-detected callbacks run. Callbacks run afterwards and may move or float the window (`tree/MacWindow.swift:31-52`).
2. Popups go to the popup container, dialogs float, and regular windows go to `bindingDataForNewRegularWindow` (`tree/NewWindowBinding.swift:5-12`). If `automatically-tile-new-windows = false`, the window floats (`:15-21`).
3. `bindingDataForNewTilingWindow` (`:24-38`):
   - With `auto-add-new-windows-to-tab-group` on and the focused window in a tab group, the window is appended to that tab group (`:41-49`).
   - Otherwise it goes after the workspace's MRU window, inside the MRU window's parent.
   - If that parent is a tab group, the window goes *after the tab group* in the nearest non-tab ancestor, wrapping the root in a new opposite-orientation root when needed (`:52-82`).
4. The same function is reused for float→tile (`command/impl/LayoutCommand.swift:44`), for leaving native fullscreen or minimized state (`normalizeLayoutReason.swift:103-104`), for shake-to-tile fallback (`mouse/driver/WindowMouseInteractionDriver.swift:366`), and for closed-window-cache restore (`tree/frozen/closedWindowsCache.swift:130`), all through `Window.relayoutWindow` (`tree/WindowRelayout.swift:3-8`).

### Commands that reshape the tree
- `resize`: finds the nearest ancestor whose parent is `tiles` with the requested orientation. It adds the diff to that node and spreads `−diff/(n−1)` **equally** over its siblings, clamped by a minimum weight (`command/impl/ResizeCommand.swift:11-58`; `mouse/resize/TiledResizeConstraints.swift:15-33`). `resize width set N` sets absolute points.
- `balance-sizes`: sets every `tiles` child weight to 1 across the whole workspace tree. `layoutTiles` then turns that into equal sizes (`command/impl/BalanceSizesCommand.swift:9-27`).
- `split`: refuses to run while flatten normalization is on (`command/impl/SplitCommand.swift:9-11`; config warning at `config/parseConfig.swift:173-185`). Otherwise it wraps the window in a new tiles container (`:27-39`).
- `join-with`: wraps the target and the current window in a new opposite-orientation `tiles` container (`command/impl/JoinWithCommand.swift:14-30`).
- `stack-with`, a WinMux addition, **creates a tab group, not a vertical stack**. It calls `createOrAppendWindowTabStack` (`command/impl/StackWithCommand.swift:27-33`; `mouse/drag/WindowDragTabStackApply.swift:4-37`). Watch the terminology: in WinMux code "stack" means tabs.
- `move`: swaps with siblings, deep-moves into sibling containers, moves out to ancestors, and at the workspace boundary can **wrap the root in a new root** (`createImplicitContainerAndMoveNode`) (`command/impl/MoveCommand.swift:16-33`, `:104-148`). A window in a tab group moves together with its whole tab group (`:183-191`).
- `flatten-workspace-tree`: rebinds every window directly under the root (`command/impl/FlattenWorkspaceTreeCommand.swift:9-15`).
- `move-node-to-workspace`: appends at the target root via `workspaceSiblingInsertionRoot`, which wraps the root in a new container if the root is a tab group (`command/impl/MoveNodeToWorkspaceCommand.swift:77-91`; `mouse/drag/WindowDragWorkspaceBinding.swift:33-68`).
- The WinMux `agent` command has a declarative `setWorkspaceLayout` with per-child `sizeRatio`. It rebuilds the root and converts ratios into weights with `totalWeight * ratio` (`command/impl/agent/AgentWorkspaceLayout.swift:37-65`; `command/impl/agent/AgentSizing.swift:23-36`). **This is prior art for fraction-based widths on top of point weights.**

## 2. Mapping Columns onto the tree

| Concept | Tree representation |
|---|---|
| Columns on a workspace | Root container, `h` + `tiles` |
| Column holding one window | Window as a direct root child |
| Column holding a tab group | `tabGroup` container as a root child (orientation normalized to `v`) |
| Overflow = stack | `v` tiles container as a root child (what `join-with` builds) |
| Overflow = squeeze | An extra (N+1th) root child. This is today's behaviour. |
| Overflow = float | Bind to `Workspace`, as the `automatically-tile-new-windows=false` path does (`tree/NewWindowBinding.swift:16-19`) |
| Width preset | That child's `h` weight = fraction × root width |

Opposite-orientation normalization *helps* here, because anything nested in an `h` root becomes `v` (`tree/TilingContainer.swift:48-55`).

## 3. Candidate hook points

### A. New `Layout` case (e.g. `.columns`)
- **Pro:** Column identity lives in the tree. It serializes, shows up in `layoutDescription`, and can carry the count.
- **Con:** `Layout` is switched on or compared in about 34 files (`rg -l` count over `Sources/AppBundle`). `setWeight` calls `die` on anything that isn't `tiles` (`tree/TreeNode.swift:41-43`). `resize`, `balance`, and agent sizing all filter on `layout == .tiles` (`command/impl/ResizeCommand.swift:12`; `command/impl/BalanceSizesCommand.swift:19-21`; `command/impl/agent/AgentSizing.swift:24`). The case would have to behave exactly like `h tiles` everywhere, so it buys only a marker.
- **Verdict:** high blast radius for a flag. Avoid it. If identity is needed, a per-workspace setting or `TreeNode` user data (`tree/TreeNode.swift:137-143`) does the job without touching every switch.

### B. Constraint on the root container (post-normalization invariant)
- Add a `Workspace.enforceColumns(profile)` step right after `rootTilingContainer.unbindEmptyAndAutoFlatten()` in `tree/normalizeContainers.swift:2-7`. It runs on every refresh for every workspace (`layout/refresh.swift:459-464`). The step would:
  - force the root to `h` + `tiles`;
  - if root children > N, fold the extras according to the Overflow policy (this is the catch-all for every path that isn't the new-window path);
  - re-apply stored Width preset fractions to the root children's weights.
- **Pro:** one place catches `move`, `move-node-to-workspace`, drag and drop, cache restore, `flatten-workspace-tree`, agent layouts, and Display profile switches. Idempotent.
- **Con:** it runs after the fact. A window that `move` put into an (N+1)th slot gets silently re-folded, which may surprise. Folding needs a rule for *which* extra child to fold and where to put it.

### C. Policy on window insertion
- Branch in `bindingDataForNewTilingWindow` (`tree/NewWindowBinding.swift:24-38`). When Columns are active and `root.children.count >= N`, apply the Overflow policy:
  - `tabGroup`: target the focused or MRU Column. If it is already a tab group, append (as in `:41-49`). Otherwise wrap it the way `createOrAppendWindowTabStack` does (`mouse/drag/WindowDragTabStackApply.swift:19-30`). This isn't directly usable because it unbinds the source window and focuses, so it needs a variant that returns `BindingData`.
  - stack: same, but with a `v` `tiles` wrapper.
  - squeeze: fall through to today's behaviour.
  - float: return `BindingData(parent: workspace, …)`.
- When `count < N`, bind as a new root child, not next to the MRU window inside a nested container, so every window opens in a new Column.
- **Pro:** smallest change, and it hits the paths the user notices most (new window, un-float, un-minimize, cache restore, all via `relayoutWindow`).
- **Con:** it misses every other `bind(to:)` site. `rg` shows direct binds in about 25 files, including `move`, `join-with`, drag operations, sidebar actions, the agent command, and workspace lifecycle. It also runs before on-window-detected callbacks (`tree/MacWindow.swift:32-52`), so a window a rule later floats or moves may already have triggered a tab-group wrap. Flatten cleans that up (a one-child tab group collapses), but the MRU/tab state is disturbed.

### Recommendation
Use **C for the Overflow policy on arrival, plus B as the invariant and width keeper.** C gives the right placement for the common case. B guarantees the Column count and widths after any other mutation or display change. Both key off a per-workspace or per-Display-profile setting rather than a tree type.

## 4. Existing behaviour that would fight Columns

1. **Flatten can replace the root.** `unbindEmptyAndAutoFlatten` flattens a container with a single child when `child is TilingContainer || !isRootContainer` (`tree/normalizeContainers.swift:12-22`). So a root holding one stacked or tab-grouped Column gets replaced by that child, and the workspace root becomes `v` or `tabGroup`. The next window then lands in the wrong orientation (and `workspaceSiblingInsertionRoot` wraps a tab-group root, `mouse/drag/WindowDragWorkspaceBinding.swift:55-67`). The test `testNormalizeContainers_flattenContainers` confirms the root-level single-child flatten for a one-window case (`Sources/AppBundleTests/tree/TreeNodeTest.swift:112-125`). The multi-window case is inferred from the code, not tested. **Fix:** exempt the root from the `child is TilingContainer` flatten while Columns are active, or have B re-wrap it.
2. **Equal-absolute-delta redistribution.** `layoutTiles` adds the same number of points to every child (`layout/layoutRecursive.swift:163-168`). Consequences:
   - on a display change (laptop to ultrawide) a 1/3 Column doesn't stay 1/3;
   - when a Column closes, its width is split equally rather than proportionally;
   - a new Column gets the sibling average (`tree/TreeNode.swift:75-78`), not a preset.

   Width presets have to be stored as fractions and re-applied (B), the same way agent `sizeRatio` does (`command/impl/agent/AgentSizing.swift:32-35`).
3. **`balance-sizes` wipes presets** (`command/impl/BalanceSizesCommand.swift:17-27`). Decide whether it means "reset to the profile's default preset" in Columns mode.
4. **`resize` spreads diffs equally over all siblings** and works in points (`command/impl/ResizeCommand.swift:45-57`). Cycling a Width preset should be a new command, or a `resize` mode, that sets the target fraction and chooses how the other Columns give up space. `resize` as written would break other Columns' presets.
5. **Paths that create or wrap roots**: `move` at the workspace boundary (`command/impl/MoveCommand.swift:136-148`), after-tab-group insertion (`tree/NewWindowBinding.swift:71-82`), and `workspaceSiblingInsertionRoot` (`mouse/drag/WindowDragWorkspaceBinding.swift:47-68`). Each can nest the Column root inside a new root, and flatten only undoes that when the old root is the only child.
6. **`split` is disabled under flatten** (`command/impl/SplitCommand.swift:9-11`). Don't rely on it to build stacks. Use the `join-with`-style wrapper.
7. **A tab group needs at least two children** to get window-tab behaviour (`tree/TreeNodeEx.swift:163-166`), and flatten collapses one-child containers anyway. So an "empty" or single-window tab-group Column isn't a stable state. That's fine as long as the spec doesn't require it.
8. **The tree can't hold empty Columns.** Empty non-root containers are removed (`tree/normalizeContainers.swift:27-29`). With N=3 and one window, that window takes the full width unless the Width preset math reserves space. This is a spec decision (see open questions).

## 5. Open questions (for ticket 09 or new tickets)

- **Empty Columns:** with fewer windows than N, do occupied Columns expand to fill the width, or keep their preset and leave blank space? Blank space needs either a placeholder node type or root-level padding in `layoutTiles`. Neither exists today.
- **Which Column absorbs overflow:** the focused one, the MRU one, or the last one? The tree's MRU helpers (`tree/TreeNode.swift:112-126`) support focused and MRU cheaply.
- **Does the Column count bind non-new-window moves** (`move`, `move-node-to-workspace`, drag)? This decides whether B folds silently or only C applies.
- **Width preset semantics when presets don't sum to 1** (for example three Columns at 1/2): who shrinks? The agent sizing normalizes over-budget ratios proportionally (`command/impl/agent/AgentSizing.swift:43-48`), which is one candidate rule.
- **Terminology:** WinMux's `stack-with` means tab group, so "stack" as an Overflow policy name will confuse readers of the code. Consider "split" or "rows" in the glossary.
- **On-window-detected ordering:** should the Overflow policy run after callbacks? That means deferring placement or re-placing in `tryOnWindowDetected` (`tree/MacWindow.swift:48-52`).

## Uncertainty

- I read the code and did not run the tests. The flatten-replaces-root behaviour for a multi-window stacked Column is inferred from `tree/normalizeContainers.swift:12-17`. The existing test covers only the one-window case.
- The counts ("about 34 files switch on Layout", "about 25 files call `bind(to:)`") are `rg` file counts, not a line-by-line audit.
- I didn't consult AeroSpace upstream. Everything cited here is in this repo, and the inherited parts (normalization, weights, `balance-sizes`) match their AeroSpace names.
