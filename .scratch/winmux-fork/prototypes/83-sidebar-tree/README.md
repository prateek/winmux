# The sidebar as a tree

Prateek picked **numbers only in the rail; a flat tree with proportional Column marks; optional split and Column levels; a window drop means sibling** on 2026-10-18. Open [The pick](index.html#pick) from disk. It needs no server, package install or build. This prototype ships no native behavior.

The pick starts collapsed at 44 points; hover opens it at 320. Pin it to read. Every view uses the same captured fourteen-window [desk.json](desk.json), exactly embedded in the page for disk opening. A/B/C remain working below the pick, under **The variants he chose from**, with their original drag rules.

## Answers to the four questions

### Columns: marks by default, a level on toggle

A workspace with Columns carries one width-proportional mark per Column, its remembered focused Column filled. Hovering a window highlights its Column's mark. There are no Column tags on windows. Workspaces without Columns have neither marks nor a Columns button.

The default tree flattens splits and Column levels, while retaining tab groups and their tabs; floating windows sit flat under their workspace with a small floating glyph. **Splits** reveals BSP levels with orientation glyphs and the floating group, as Prateek asked after the pick ("the bsp toggle should control bsp+floating container grouping"); **Columns** reveals Column rows. Both on gives workspace → Column → split/tab group → window. Each button affects its workspace only and has an accessible label and tooltip. A workspace with no actual split does not invent one when Splits turns on; a sibling drop onto its lone Column window makes the level visible.

The small config panel models proposed Nickel names `sidebar.tree.splits = false` and `sidebar.tree.columns = false`. Defaults apply to all workspaces and persist in browser local storage. Overrides live in memory by workspace identity. Changing one default clears that toggle's overrides; changing the other preserves them. A reload discards session overrides but retains defaults.

### Drags: any target; window means sibling; two refusals

A window or tab group is accepted on every existing row in the pick, including a workspace number, Column mark, floating window, or the floating group when Splits shows it. Each accepted drop changes only the in-page desk. Trees, rail focus, marks and the focused workspace's 16:9 sketch update together. Reset restores the fixture; Save changed desk.json exports a copy. No page action sends a WinMux command.

Operations below refer to code at [`1fbbdc72`](https://github.com/prateek/winmux/tree/1fbbdc72). “Join” means tab-group binding; it is not a `winmux join` CLI. `join-with` makes a split.

| Target / subject | Result in the pick | WinMux operation and source seam |
| --- | --- | --- |
| Workspace row or rail number, workspace without native Columns | Append to the tiling root, including on the same workspace. A floating window stays floating on that workspace | `move-node-to-workspace`; [applySidebarWorkspaceMove](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragWorkspaceMove.swift#L8), [workspaceAppendBindingData](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragWorkspaceBinding.swift#L33) |
| Workspace row/number, workspace with native Columns, regardless of visible levels | Nearest empty Column to remembered focus, lower index on a tie; otherwise focused occupied Column. The source's own windows do not count as occupying a Column, so a same-workspace drop leaves it where it is. A floating window stays floating | Sidebar append followed by [enforceColumnInvariant / columnPlacementSlot](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L83), rather than calling dropDecision directly; `columnPlacementSlot(excluding:)` excludes the source. The floating branch of `applySidebarWorkspaceMove` keeps floating windows floating |
| Column mark or row | Fill empty Column or join its occupied tabs; wrap occupied non-tabs as tabs | `move-node-to-column`; [drag destination](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragColumnDestination.swift#L4), [dropDecision](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/ColumnPolicy.swift#L130), [ColumnPlacement.resolve](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/ColumnPlacement.swift#L49), [bindToColumn](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L226) |
| Tab group row | A window joins as a tab. A tab group or split joins as its windows, in order, since a tab group holds windows only | No seam takes a tab group by identity: MoveCommand's [join case](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/command/impl/MoveCommand.swift#L40) and the drag's `.tabStack` ([WindowDragPendingIntent](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragPendingIntent.swift#L248)) take a window, and [columnBinding](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L201) only a Column. Breaking a group into its windows follows [bindToColumn's occupied branch](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L254). The feature adds the seam |
| Split row or split insertion line | Insert at that index, or append on the row; adjust for removing a same-parent source | [moveNodeToSiblingIndex](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/command/impl/MoveCommand.swift#L108) and [workspaceInsertBindingData](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragWorkspaceBinding.swift#L73) are both file-private free functions; the second picks before or after along the parent's orientation, not by a row's upper or lower half |
| Plain window row, upper/lower half | Insert before/after in its actual parent, even with structural levels hidden | No single existing command targets “sibling of this window at this index”. The closest seams are `moveNodeToSiblingIndex` and `workspaceInsertBindingData` above, both file-private, and the second decides before or after by orientation. The feature needs a sidebar seam that binds to a parent at an index |
| Tab inside a tab group, upper/lower half | Join that tab group at the pointed tab index; a tab group or split joins as its windows | Same sibling-binding adapter; retains the real tab parent |
| Window directly in a Column | Become its sibling in a split within that Column, not another Column | [bindToColumn's split branch](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L243) constructs a vertical `.v` tiles container. Preserve that default orientation; the adapter supplies before/after order |
| Tab group or split → ordinary parent / empty Column | Preserve one node and its children | [WindowDragPendingIntent](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragPendingIntent.swift#L199), `bindToColumn` |
| Group → occupied Column | Merge leaf windows into its tabs | [bindToColumn's occupied branch](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L254) |
| Floating window → a tiled window, tab, tab group, split or Column | Tile first, then apply the same target rule. Workspace rows and rail numbers are not tiled destinations: there it stays floating | `layout tiling` plus the operation above. This deliberately replaces the [native drag guard](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/mouse/drag/WindowDragColumnDestination.swift#L6); the feature needs the combined sidebar path |
| Floating group or floating window | Keep/set floating state and insert into its floating group at the pointed index | Floating workspace/window binding; [bindToColumn's float branch](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/tree/Columns.swift#L233) floats a group's leaf windows |
| Node onto itself or descendant | Refuse without mutation, explain on hover | Tree acyclicity, checked before unbinding |
| Drag workspace/Column row | Refuse as a layout-node drag, explain in tooltip/status | Structural workspace and Column state; these headings are not windows. Native workspace ordering remains a separate interaction |

A window drop gets an insertion line at its upper/lower edge; containers get an outline. Refusal gets a dashed outline and a visible reason. Hidden levels change neither the destination nor the preview: the sketch shows the actual split or tab group after the drop. Revealing that level exposes the same relationship.

The A/B/C variants retain first-pass behavior, including refusal of window-as-parent and floating-to-Column drops. They are comparison alternatives, not the picked rules. Their original 21 fixture rows and 43 browser assertions remain intact.

The page models the rich config's no-hook placement. It does not evaluate Nickel. The sketch uses logical proportions and Column widths, omitting native app minimum sizes and gaps. Parked floating frames stay unchanged in the fixture; only their sketch uses a centered fallback.

### Rail: numbers

The pick has one number per workspace and nothing else. It uses today's neutral rounded focused section, white bold 18-point digit and subdued inactive numbers, as seen in the corrected [workspace 2 rail](img/today-2-collapsed.png) and [native WorkspaceSidebarWorkspaceSection](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarWorkspaceSection.swift#L241). No blue app badge is substituted.

The native Nickel config uses a 50-point rail; this page retains the first prototype's 44-point comparison rail beside the expanded tree. Hover uses the native 50 ms open / 80 ms close delay and 140 ms animation. Pinning is a reading aid. Drag-end releases its hover expansion lock.

### Width: measured flat and both levels

The pick needs **307 points** in its default flat view and **307 points** with both levels on, measured with the first pass's algorithm. Controls on the workspace row set the maximum here. Default expanded width is **320**; the slider changes it. Width includes the retained rail, actual controls and indentation plus full text measured with the rendered font; measurement ignores search/disclosure hiding.

Window text is 12.5 points, group text 13, focused text semibold, icons 14, rows 24, workspace rows 32 and indentation 18. Sources: [WorkspaceSidebarRows](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarRows.swift#L35), [WorkspaceSidebarPanel](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarPanel.swift#L22) and [dimensions](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarDimensions.swift).

The config initializer's expanded width is 240 in [Config.swift](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/config/Config.swift#L102), reached through [parseWorkspaceSidebar](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/config/parseWorkspaceSidebar.swift); the Nickel defaults and rich desk use 280. Both are below the pick's measured width. A/B/C each need 297 on this fixture; their full heights are 817/697/847. Arbitrary titles can exceed any finite default.

## Fixture and native baseline

The first pass staged the rich desk at 1920 × 1080 before Firefox: 14 windows on workspaces 1/2/3/4, counts 4/5/3/2, with two tab groups, floating Updater/Calculator and Columns on 2 and 3. [raw/agent.json](raw/agent.json) exposes actual container layouts, orientation and tab identities. Independent workspace/window readbacks and `raw/columns-N.json` retain the Column widths. No container structure was hand-invented.

Remembered focus is the one inferred field: the agent exposes only global focus. [raw/focus-from-captures.json](raw/focus-from-captures.json) names the highlighted native window per workspace, then membership supplies its Column. Moving that window makes the page use the first remaining window as a fallback; the feature should use native focus state.

`node normalize.mjs raw desk.json` reproduces the fixture. Browser checks verify exact equality with the embedded copy. App icons were captured using NSWorkspace in the guest.

Today's native captures prove the existing sidebar already groups multi-child tab groups; it flattens splits and omits Columns, matching [ContainerItemBuilder](https://github.com/prateek/winmux/blob/1fbbdc72/Sources/AppBundle/ui/sidebar/WorkspaceSidebarContainerItemBuilder.swift#L34). This corrects the issue's broad premise. The follow-up corrected the first pass's centered image crops using retained full originals; page baseline images now actually show the left-edge sidebar.

## Browser-tree references and licences

The page compares live guest-only Tree Style Tab and Sidebery captures beside the pick. Firefox extension permission confirmations are accepted; macOS permission prompts are never granted. The capture index records the actual tree/search coverage and any limits.

- [Tree Style Tab by Piro](https://addons.mozilla.org/en-US/firefox/addon/tree-style-tab/) is MPL 2.0 by default, with per-file MPL 1.1/MIT/PSF licences in its [COPYING](https://github.com/piroor/treestyletab/blob/master/COPYING.txt). It deliberately delegates search to helpers ([project policy](https://github.com/piroor/treestyletab#basic-project-policy)); search coverage uses the separately identified [TST Tab Search](https://addons.mozilla.org/en-US/firefox/addon/tst-search/) helper, rather than claiming a built-in filter.
- [Sidebery by mbnuqw](https://addons.mozilla.org/en-US/firefox/addon/sidebery/) is [MIT licensed](https://github.com/mbnuqw/sidebery/blob/master/LICENSE).
- No extension code or assets implement WinMux. Their screenshots are reference material only. [references.json](references.json) records versions, provenance and the files displayed on the page.

## Checks and evidence

Open `index.html?selftest` for 50 fixture rows: the original 21 plus 29 pick rules. Run `node check-pick.mjs <driver-capture-directory>` for real headless-browser interactions, and `node check-browser.mjs <driver-capture-directory>` for the unchanged variants. The pick check covers both window-row halves, hidden-parent placement, tab indices, direct Column siblings, floating conversion, marks/rail targets, refusals, disclosure/search, hover, independent toggles and persisted defaults.

The builder physically restored the old drag branch: all 20 changed-rule rows failed, while the 9 unchanged pick rows passed. Restoring the pick made all 29 pass. `check-rules.mjs <output.json> --old` checks the deliberately reverted state; without `--old` it checks the restored rules. Reversion is evidence, never the checked-in default.

Page screenshots stay in the driver's capture directory, not `img/`. The [capture index](captures/index.md) maps them by filename, query count and position. Only displayed baseline/icons/extension images remain in `img/`; flat UI is PNG. The prototype stays below 5 MB. No history was rewritten.

Host and pinned Swift 6.4 guest `make check` pass on the unchanged product tree. This is not GitHub CI; the driver opens the PR and owns CI and landing. Installed-build checks, second display and real sleep/wake/unlock remain Prateek's in the [feature draft](../../build/121-the-sidebar-as-a-tree.md). No release or installed-machine change is made by the prototype.

## Defaults recorded for the relay

Decided: Propose `sidebar.tree.splits` and `sidebar.tree.columns` as config names, both false. Persist page defaults in local storage; keep workspace overrides in memory and clear each toggle's overrides when its own default changes.

Decided: Use 320 expanded / 44 collapsed points in the pick, retaining the rail beside the tree for comparison. Keep A/B/C at their existing comparison width; native compact geometry remains a feature implementation concern.

Decided: Use TST Tab Search 0.0.7 for Tree Style Tab's search comparison, explicitly labelled as a separate helper in the fresh guest-only profile. Tree Style Tab delegates filtering to helpers.

The picked design and new drag policy are Prateek's decisions. The prototype issue has no named Defaults chosen for you section to change. Implementation defaults are collected in the feature draft.
