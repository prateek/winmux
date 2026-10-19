# The sidebar as a tree

Part of {{UMBRELLA}}.

## What to build

Build the native sidebar from the layout tree, using the variant Prateek chooses from **Prototype: the sidebar as a tree**. This draft recommends B: Column marks on workspace rows, oriented splits and bracketed tab groups below them, and a focused-app rail. It waits on Prateek's choice of variant. His pick may replace this draft's recommendation before implementation starts.

The current sidebar already groups tab groups with more than one child. It flattens other containers into windows and omits Columns. Preserve those missing boundaries and make the tree a usable view and editor of the layout.

Start with a native tree snapshot that keeps workspace, Column, container and window identities, with Column widths and container layout/orientation. Render the selected variant from that snapshot before adding drag mutations. Extend the existing sidebar snapshot, row and drag owners; use WinMux's binding and Column placement seams. The prototype's JavaScript and layout sketch are evidence, not implementation to import.

The prototype, fixture, native baseline captures, measurements and drag-rule table are in `prototypes/83-sidebar-tree/`. Its published extension screenshots are references, not live extension behavior verification.

## Decisions

The prototype issue's settled Decisions carry forward below. Each proposed application to the shipping feature is the relay's recommendation awaiting Prateek's variant pick; this draft does not reopen the prototype's contract.

- **The tree is the layout:** workspace, Column, tab group or split, window. B represents the Column with marks and tags rather than an extra row level. (Relay recommendation; awaiting Prateek's pick.)
- **Rows collapse, drag to a new parent, and can be searched.** Preserve the person's disclosure choices through search and layout updates. (Relay recommendation; awaiting Prateek's pick.)
- **A tab group and a split look different.** Use a tab glyph with bracketed children for a tab group and orientation glyphs with ordinary indentation for splits. Preserve the actual layout label, including accordion when present. (Relay recommendation; awaiting Prateek's pick.)
- **The sidebar runs collapsed, expanding on hover.** The rail shows the workspace's remembered focused app icon with its workspace number underneath. Keep the existing hover timing and leave its activation behavior intact. (Relay recommendation; awaiting Prateek's pick.)
- **The prototype is a clickable page with variants side by side.** Retain it as the comparison evidence. This issue implements the selected design in the app, not another page. (Relay recommendation; awaiting Prateek's pick.)
- **A prototype answers questions; it does not ship.** The selected native implementation is a separate change, gated on the pick. Copy no extension code or assets into WinMux. (Relay recommendation; awaiting Prateek's pick.)
- **Recommend B, Columns as marks.** Workspace rows carry one width-proportional mark per Column, with its remembered focused Column filled. Windows carry their Column number. No Column nesting level is inserted. Marks are explicit Column drop targets. (Relay recommendation; awaiting Prateek's pick.)
- **A drop maps to one existing operation.** Workspace drops retain their sidebar transfer path; invariant placement prefers the nearest empty Column, then the focused occupied Column. Explicit Column drops resolve through the Column placement path. Joining tabs and inserting into splits share the existing binding seams. Hooks remain authoritative where the existing path invokes them; the prototype demonstrates the no-hook rich config. (Relay recommendation; awaiting Prateek's pick.)
- **A group moves as a subject.** Preserve the node on an ordinary parent or empty Column; an occupied Column merges its leaf windows into tabs, as `bindToColumn` does. Preview the actual outcome. (Relay recommendation; awaiting Prateek's pick.)
- **Refuse invalid layout parents before mutation.** Explain self/descendant drops, a window row used as a parent, a nonexistent Column, and a floating drag into a Column that needs `layout tiling` first. Column and workspace headings are not draggable layout nodes; existing workspace ordering remains a separate interaction. (Relay recommendation; awaiting Prateek's pick.)
- **Floating windows stay under their workspace.** A floating workspace transfer preserves floating state. Do not insert a floating window into a tab group by expanding the tree. (Relay recommendation; awaiting Prateek's pick.)

## Defaults chosen for you

- **Expanded width:** 320 points when unset. The prototype needs 297 points on the captured desk; 320 leaves 23 points of headroom. Preserve an explicit configured width. Retain 44 points collapsed. Truncate arbitrary longer titles at the tail with their full title available on hover.
- **Rows:** native 12.5-point window text, 13-point group headers, 14-point app icons, 24-point window rows and 18-point tree indentation. Workspace rows remain 32 points. A tree taller than the usable sidebar scrolls.
- **Disclosure state:** keep stable node identities and maintain the person's open/closed choices for surviving nodes. Search reveals matched paths without writing to that state. No new persistent state is needed for the first implementation.
- **Search:** case-insensitive substring matches in app or title, one match per window, with the count visible. Retain and dim ancestors; hide unrelated branches. Clearing restores the saved disclosures.
- **Pin:** provide an explicit expanded reading state through the sidebar's existing expansion lock. Hover continues to open and close when unpinned. The prototype retains the rail beside the expanded tree for comparison; the native sidebar may replace compact contents as it does today.
- **Drop affordances:** an insertion line for a split index, an outline for a parent destination and a visible reason for refusal. Keep hit areas stable while drawing the line. Resolve against current tree/Column state at commit so a removed parent cannot receive a stale drop.

## Depends on

- **Prototype: the sidebar as a tree**, its staged-desk fixture and recommendation.
- **Prateek's choice of variant.** This is a blocking product decision. The driver records his choice; the builder creates no separate question or feature issue from this draft.

## Done when

- [ ] On the fourteen-window rich desk, the native sidebar shows workspace 1's horizontal root and two vertically split Ghostty windows, distinct from workspace 2's three Safari tabs and workspace 3's two TextEdit tabs. Both floating Updater and Calculator are under their workspaces. An accordion fixture retains its own layout label.
- [ ] Column marks on workspace 2 have widths 28/44/28 and on workspace 3 have widths 2/3 and 1/3; every tiled window has the right Column tag. Empty Columns remain targetable, and Columns-off workspaces have no marks or Column targets.
- [ ] At 1920 × 1080, capture the selected rail collapsed and expanded under hover on every workspace. Remembered focus supplies Zed, Notes, TextEdit and Preview icons on the captured desk. Pinning and unpinning use the existing expansion lifetime and keyboard activation rules.
- [ ] Collapse the Safari and TextEdit groups and the vertical Ghostty split. Search reveals the right ancestors and clearing it restores those disclosures. `Safari` finds exactly three windows in workspace 2's tab group, `Grievances` finds one in workspace 3's tab group, and `qzxnomatch` finds none.
- [ ] Behavior tests and a native live run cover workspace transfers with Columns off/on, nearest-empty and occupied-focused placement, all explicit Column destinations, adding a tab, exact-index insertion and moving a group intact. An occupied Column visibly merges the incoming group's leaves as the preview predicts. Placement hooks follow their existing destination rules.
- [ ] Test and show refusals without mutation for self/descendant, a window parent, an absent Column and a floating source into a Column. Config headings cannot become layout children. A floating workspace transfer stays floating. Stale/removed parents and changed Column counts refuse or re-resolve before binding.
- [ ] Focus, tree rows and rail cues update together after a move, a tab change, a close and a workspace switch. No new thumbnail or window-inventory pipeline is introduced. Existing workspace ordering and sidebar keyboard activation retain their behavior.
- [ ] Measure title clipping at each depth with the actual native fonts and controls. Show 240, 280 and 320 points on the rich desk, in light and dark, and check scrolling at a smaller usable height. Explain any departure from the prototype's 297-point threshold.
- [ ] Host and pinned-version guest `make check` pass, and GitHub's latest `Build and test` passes before landing. Keep screenshot/video evidence of the visible changes and record the final native layout readback.
- [ ] Prateek checks the installed build with his normal sidebar config and real pointer timing, a second display, and real sleep/wake/unlock. Any by-hand upgrade or permission step is recorded in **Prateek's checks on an installed build and real hardware**.

## Sources

- **Prototype: the sidebar as a tree**, its settled Decisions and four questions; Prateek's Tree Style Tab / Sidebery direction and request for collapse, drag and search.
- [Prototype README, evidence and drag-rule table](../prototypes/83-sidebar-tree/README.md), including the extension permission fallback and the recommendation awaiting a pick.
- [Captured desk](../prototypes/83-sidebar-tree/desk.json) and [raw agent tree](../prototypes/83-sidebar-tree/raw/agent.json).
- At `1fbbdc72`: `WorkspaceSidebarContainerItemBuilder`, `WorkspaceSidebarRows`, `WorkspaceSidebarDimensions`, `WorkspaceSidebarHoverExpansion`, `WorkspaceSidebarPanelController`, `WorkspaceSidebarDropDelegate`, `WindowDragWorkspaceMove`, `WindowDragWorkspaceBinding`, `WindowDragColumnDestination`, `ColumnPolicy.dropDecision`, `ColumnPlacement`, `Columns.bindToColumn` and `MoveCommand`.
