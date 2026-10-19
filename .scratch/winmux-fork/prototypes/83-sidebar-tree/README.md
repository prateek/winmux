# The sidebar as a tree

Open [index.html](index.html) from disk. It needs no server, package install or build. The three small stages and the larger selected view share the fourteen-window layout in [desk.json](desk.json). Pinning starts on for comparison; unpin a stage and hover its rail to try the everyday interaction. Disclosures, window and group drags, search, focus and the width slider work.

Recommend **B, Columns as marks**, at **320 points expanded**. It keeps the Column widths and destinations visible while using five fewer rows than A. This recommendation awaits Prateek's pick. The [feature draft](../../build/121-the-sidebar-as-a-tree.md) waits on that choice; this prototype ships no WinMux behavior.

## Answers to the four questions

### How are Columns shown?

Each variant uses the same captured tree, with a different presentation of its Columns:

| Variant | Expanded tree | Collapsed rail | Evidence |
| --- | --- | --- | --- |
| A | Workspace → Column → tab group or oriented split → window | Workspace number and one mark per Column; the remembered focused Column is filled | [Expanded](img/page-A-expanded.png), [collapsed](img/page-A-collapsed.png), [hover](img/page-A-hover.png) |
| B | Workspace → tab group or oriented split → window. Width-proportional Column marks on workspace rows; windows have C1/C2/C3 tags | Remembered focused app icon, then workspace number | [Expanded](img/page-B-expanded.png), [collapsed](img/page-B-collapsed.png), [hover](img/page-B-hover.png) |
| C | No Column level or workspace-row marks. Thin labelled dividers separate Column contents | Stacked window icons; a tab group is one icon with its count | [Expanded](img/page-C-expanded.png), [collapsed](img/page-C-collapsed.png), [hover](img/page-C-hover.png) |

A explains the model most directly. B retains useful targets in less height. C's five divider labels consume more height than A's five Column rows in this design: “flat” does not by itself mean shorter. None is discarded. Every tree scrolls inside its stage, and all three fit in the native sidebar's 1080-point desk with space for modest chrome; C needs scrolling in the small 826-point comparison stage.

Tab groups have a tab glyph and bracketed children. Splits show horizontal or vertical layout glyphs, with ordinary indented children. Floating windows are separate children of their workspace. The staged desk contains tiles, tab groups and two floating windows; it contains no accordion. The normalizer preserves a container's reported `layout`, so an accordion would retain that label rather than become invented tabs.

### What do drags do, and what is refused?

Every accepted drop edits an in-page copy of `desk.json`. All trees, rails and the focused workspace's 16:9 layout sketch render from that copy. Reset restores the capture; **Save changed desk.json** exports a copy. No operation reaches a running WinMux.

The table maps intent to WinMux's existing operation or binding seam at [`1fbbdc72`](https://github.com/prateek/winmux/tree/1fbbdc72). “Join” names a tab-group binding, not a nonexistent `winmux join` CLI. `join-with` makes a split and is a different command.

| Drag | Result in this prototype | Code behind the rule |
| --- | --- | --- |
| Window → workspace row or rail cell, Columns off | `move-node-to-workspace`; append to its tiling root. A floating window stays floating | [`applySidebarWorkspaceMove`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragWorkspaceMove.swift#L8), [`workspaceAppendBindingData`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragWorkspaceBinding.swift#L33) |
| Window → workspace, Columns on | Prefer the nearest empty Column to the remembered focused Column, lower index on a tie. With all Columns occupied, join the focused Column. On this desk that is Column 1 on workspaces 2 and 3 | [`enforceColumnInvariant` and `columnPlacementSlot`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L83). The sidebar appends first; it does **not** call `dropDecision` directly |
| Window → Column row (A), mark (B) or divider (C) | `move-node-to-column`; fill an empty Column or join its occupied tab group, wrapping occupied non-tabs in a tab group | [`currentColumnDragDestination`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragColumnDestination.swift#L4), [`dropDecision`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/ColumnPolicy.swift#L130), [`ColumnPlacement.resolve`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/ColumnPlacement.swift#L49), [`bindToColumn`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L226) |
| Window → tab group | Join as one tab | [`columnBinding`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L201); [`MoveCommand`'s `join` case](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/command/impl/MoveCommand.swift#L40) uses the same binding |
| Window → insertion line between split children | Bind as a sibling at that index, adjusting the index after removing a source from the same parent | [`moveNodeToSiblingIndex`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/command/impl/MoveCommand.swift#L108), [`workspaceInsertBindingData`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragWorkspaceBinding.swift#L73) |
| Tab group or split → another ordinary parent, or an empty Column | Move one node; keep its children together | [`WindowDragPendingIntent`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragPendingIntent.swift#L199), `bindToColumn` |
| Tab group or split → occupied Column | Merge its leaf windows into that Column's tabs. The source group does not survive as a nested group | [`bindToColumn`'s occupied-container branch](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L254) |
| Node → itself or its descendant | Refuse; would create a cycle | Tree parent invariant; checked before unbinding in the prototype |
| Node → window row as parent | Refuse: a window has no children. The split's insertion lines remain available | The `Window`/`TilingContainer` distinction and sibling binding above |
| Drag Column, workspace or floating-section row | Refuse as a layout-node drag; these are structural headings | Column slots belong to workspace Column state. Existing native workspace ordering is a separate sidebar interaction, outside this layout prototype |
| Column target on a Columns-off workspace | Refuse: that target is absent. C dividers and B marks exist only for real Columns | [`Workspace.columns` and `enforceColumnInvariant`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L83) |
| Floating window → Column or its tiling descendants | Refuse with “run layout tiling” first; do not silently convert a native floating drag | [`currentColumnDragDestination`'s floating-source guard](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragColumnDestination.swift#L6). The explicit CLI can tile such a window; the prototype models the drag guard |

The target shows a line or outline during a drag. A refused target shows a dashed outline and its reason in both the target tooltip and the persistent status line. [A accepted](img/page-A-accepted.png), [B accepted](img/page-B-accepted.png) and [C accepted](img/page-C-accepted.png) show a Ghostty window moved to workspace 4. Each miniature loses the upper-right tile and the destination tree gains the window. [A refused](img/page-A-refused.png), [B refused](img/page-B-refused.png) and [C refused](img/page-C-refused.png) show a window-row parent refused. Safari also verifies [insertion between the Ghostty siblings](img/B-insertion.png), the [destination miniature](img/B-destination-miniature.png) and [collapse after an unpinned drag](img/B-drag-end-collapse.png).

These corrections to ruling 6 follow the code: workspace drops use invariant placement and prefer an empty Column before an occupied focused one; an occupied Column merges an incoming group's leaves. `bindToColumn` is called once for the subject, but its occupied branch deliberately visits its windows. The page models the rich config's **no-hook** behavior. It does not evaluate Nickel hooks.

The miniature is a layout sketch, not a native-frame replay. It uses captured split proportions, Column widths and tab identity, with auto-sized arrivals. It omits app minimum sizes and gaps. Hidden native frames are parked offscreen; floating windows with parked frames use a centred sketch fallback, without inventing a native frame in the fixture. A [split moved into a tab group](img/B-nested-group.png) remains one tab with its two children; [selecting it](img/B-nested-miniature.png) draws that split in the miniature. Tab counts count immediate tabs, not every leaf window below a container tab.

### What should the collapsed rail show?

B's focused-app icon is the most useful cue on this desk: Zed, Notes, TextEdit and Preview name four distinct destinations before expanding. A's Column marks are useful when the question is “how many Columns?”. C can show a workspace's inventory, but its stacked icons take more rail height and ask the reader to distinguish small icons and counts.

The rail always remains 44 points wide beside the expanded tree so both states can be compared. The real sidebar replaces its compact contents while expanding; this side-by-side treatment is a prototype decision, and its width cost is included in the measurements. Open delay is 50 ms, close delay 80 ms and width animation 140 ms, from the native [controller](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarPanelController.swift#L45) and [collapse scheduling](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarPanel.swift#L780). Pinning is an explicit reading aid.

### How wide does the tree need to be?

The page measures the full text at every depth with the browser's system font, including the focused semibold row, and adds the rendered controls, tags and indentation. It measures all rows even when disclosures or search hide them. The slider clips titles naturally at the tail.

| Variant | Depth 0 | Depth 1 | Depth 2 | Depth 3 | First title clips below | Full tree height |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 187 | 210 | 297 | 275 | 297 pt | 817 pt |
| B | 261 | 265 | 297 | 187 | 297 pt | 697 pt |
| C | 187 | 247 | 297 | 187 | 297 pt | 847 pt |

These are Chromium measurements on this macOS desk; the [live Safari table](img/widths-light.png) gives the same numbers. The longest requirement is the focused Zed title at depth 2, so all three share the maximum despite different Column treatment. The browser check verifies no title clips at the computed width, then verifies clipping two points below it.

Metrics come from [`WorkspaceSidebarRows.swift`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarRows.swift#L35) (12.5-point window text, 13-point group header, focused semibold), [`WorkspaceSidebarPanel.swift`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarPanel.swift#L22) (14-point icon, 6-point icon/text spacing, 24-point row, 18-point tab-child indentation) and the [dimension calculations](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarDimensions.swift). New tree depths also use 18-point indentation. Workspace rows are 32 points.

[`parseWorkspaceSidebar`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/config/parseWorkspaceSidebar.swift) starts from `WorkspaceSidebarConfig()`: the actual default declaration is **240 points** in [`Config.swift`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/config/Config.swift#L102). The rich desk overrides it to **280**. Both clip this prototype's longest row. Recommend **320** for B, with tail clipping beyond that; the prototype starts at 360 to leave reading room and exposes the slider. No finite default can promise unclipped arbitrary titles.

## Where the data came from

The worktree at `1fbbdc72` was synced and built in a 1920 × 1080 macOS guest, and `stage-rich.sh` ran once before Firefox. Host and pinned Swift 6.4 guest `make check` passed: 1,657 Swift tests and 171 Python script tests on each, plus the helper suites. These checks cover the unchanged product tree; they are not GitHub CI.

[raw/agent.json](raw/agent.json) is `winmux agent query`. `reasoning.rawTrees` exposes each split's `layout` and `direction`, tab group ids, tab order and active tabs; `inventory.windows` supplies app, title, global focus, floating layout and native frame. [raw/workspaces.json](raw/workspaces.json) and [raw/windows.json](raw/windows.json) are independent CLI readbacks. `raw/columns-N.json` contains every workspace's `list-columns --workspace N --json` result, including empty arrays for Columns off. No container layout was inferred.

The only inferred field is **remembered per-workspace focus**: the agent query exposes global focus, not every workspace's remembered focused window or Column. [raw/focus-from-captures.json](raw/focus-from-captures.json) records the highlighted window in each native expanded capture: Zed, Notes, Grievances and Preview. Column membership then supplies its Column. This corrects the tempting but wrong inference that a tab group's active tab must be its workspace's focused window.

`node normalize.mjs raw desk.json` derives the normalized tree, joins Columns by their reported window ids, and checks that it contains fourteen windows. The identical JSON is embedded in `index.html` so opening from disk does not depend on cross-file `fetch`. `check-browser.mjs` verifies that copy equals `desk.json`.

Today's captures are cropped to the native rail/panel; full desktop originals are retained with the relay evidence. They confirm the code: [`buildWorkspaceSidebarContainerItems`](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarContainerItemBuilder.swift#L34) already emits a group when a tab group has more than one child. Other containers recurse into their children, flattening splits. Columns get no row. The issue's statement that tab groups and splits look the same is therefore too broad; the missing distinctions are splits, their orientation and Columns.

App icons were captured with `NSWorkspace.icon(forFile:)` in that guest using `icons.swift`. They are reference app icons, as in the Lens look prototype. No user's windows or host desktop were captured.

## Browser-tree references and licences

Firefox 158.0 installed in the guest only, in a fresh task profile with telemetry and crash submission disabled. Its first-run terms screen was dismissed to reach Mozilla Add-ons. Both **Add to Firefox** attempts then requested tab access; Tree Style Tab also requested notifications. Both permission prompts were cancelled under the pass's no-grants rule: [Tree Style Tab prompt](img/tst-permission.png), [Sidebery prompt](img/sidebery-permission.png). No extension was installed and no OS permission was granted. The published-screenshot fallback was used; live desk-shaped trees, collapsed/expanded extension branches and extension search were not checked.

The page labels all six references as **published**, links their authors and keeps them separate from the working WinMux render. The original image URLs and licences are in [references.json](references.json).

- [Tree Style Tab by Piro](https://addons.mozilla.org/en-US/firefox/addon/tree-style-tab/): overview, drag/tree and themes images published by the project on Mozilla Add-ons. Its [COPYING.txt](https://github.com/piroor/treestyletab/blob/master/COPYING.txt) specifies MPL 2.0 by default, with per-file MPL 1.1, MIT and Python Software Foundation licences for included files. The Add-ons API calls this a custom composite licence. Screenshots are comparison references; no Tree Style Tab code or asset is used in WinMux.
- [Sidebery by mbnuqw](https://addons.mozilla.org/en-US/firefox/addon/sidebery/): sidebar/group page, bookmarks/history and themes images published by the project on Mozilla Add-ons. Sidebery is [MIT licensed](https://github.com/mbnuqw/sidebery/blob/master/LICENSE). No Sidebery code or asset is used in WinMux.

## Checks and reproduction

Open `index.html?selftest` for the 21 fixture checks, also [captured in Safari](img/selftest.png). They cover every table row, same-parent insertion, floating preservation, group identity and refusal without mutation. Run `node check-browser.mjs <capture-directory>` with `agent-browser` installed for the 43 headless Chromium assertions covering real drags, disclosure/hover/search, shared-view updates, all three Column targets, split insertion and measured clipping. It closes its task browser. It has no third-party JavaScript dependency.

`capture-today.zsh` and `capture-page.zsh` are guest-only capture tools, transported and invoked through the repository's `vm` skill. The latter uses `drag.swift` for actual dragged mouse events and `read-page.swift` for Safari's visible accessibility text. The native checks cover every variant's pin/collapse, hover, branch disclosure, accepted and refused drag, and Safari search. [captures/index.md](captures/index.md) maps screenshots to results and counts. The driver retains full-size originals and accessibility readbacks.

No installed-build check, second display or real sleep/wake/unlock is claimed. Those remain unticked in the feature draft and in the handoff. No release was built or published by this prototype pass.

## Decisions recorded for the relay

Decided: Recommend B with a 320-point expanded width, awaiting Prateek's variant pick; the prototype opens at 360 for comparison.

Decided: Embed the exact normalized fixture in the single HTML file for disk opening; verify equality instead of requiring a server or a build step.

Decided: Start the comparison pinned and retain the 44-point rail beside the expanded tree; unpinning exercises native hover timing.

Decided: Preserve the rich desk's floating Updater as well as Calculator. Preserve native raw frames and use a centred sketch fallback for parked floaters.

Decided: Derive remembered focus from the native highlighted captures, explicitly separate from the agent's global focus. If a drag removes that remembered window, the prototype uses the first remaining window and its Column as its fallback; the feature should use WinMux's own focus cache.

Decided: Follow workspace invariant placement (nearest empty, then focused occupied Column), and merge group leaves in occupied Columns, correcting the two broad descriptions in ruling 6.

Decided: Cancel extension install permission prompts and use credited published screenshots. Do not claim live extension tree or search coverage.

The authoritative issue has no **Defaults chosen for you** section. None of its named defaults changed. Its Decisions remain intact; the feature choice is a recommendation.
