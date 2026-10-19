# Thin, quiet tabs above grouped windows

Part of {{UMBRELLA}}.

## What to build

After Prateek picks a look from **Prototype: the tab strip above apps that have
tabs of their own**, build the relay's recommended Thin and quiet strip with
the grip gone. This draft waits on his pick of look; his pick may replace the
recommendation. The [comparison page](../prototypes/84-tab-strip/index.html)
and [pictures and measured baseline](../prototypes/84-tab-strip/README.md)
are the visual specification, with the fidelity limits stated there.

At the default height of 24 points, group tabs are unfilled labels. The active
label has semibold text and a hairline underneath. Remove the enclosing frame
stroke and the old two-line grip; keep a 28-point trailing gutter and empty
strip background as whole-group drag targets. The band keeps today's fill, the
`GlassSurface` that `workspace-sidebar.chrome-style` and `solid-chrome-color`
drive; the prototype's per-app band colours are illustrations, not a rule. The
native app keeps its own tabs and title bar. Preserve current tab order, focus, close, reorder,
detach, overflow and Option-held digit behavior through their existing owners.

## Decisions

Each is the relay's recommendation from the prototype, awaiting Prateek's pick of look; his pick replaces any of them.

- **The look is Thin and quiet**: a 24-point band above the group, tab labels with no pill fill at rest, the active tab marked by semibold text and a hairline, and no frame stroke around the group.
- **The grip goes.** A whole group is dragged from the empty strip after the last tab, from the 28-point gutter at the strip's right end, or from the sidebar's tab-group header, as it is today.
- **Nothing moves into the app's own title bar.** The app keeps its tabs and title chrome; WinMux's band stays above them.

## Defaults chosen for you

- Default height 24; item height remains `min(max(height − 10, 18), 26)`, giving 18. Keep 12-point labels, 14-point icons, 240/132 preferred/minimum widths and 4-point spacing unless the picked native capture requires an adjustment. Adapt close-button geometry and hit areas to fit the shorter item without changing its action contract.
- Keep existing explicit configured heights greater than 20; lower the runtime minimum to 24. The parser's refusal at 20 or less remains. Say that accepted 21–23 resolve to 24 in a comment beside `height` in the schema (`nickel-helper/nickel/winmux/winmux.ncl:294`), which today documents neither the floor nor the refusal.
- The band's fill and ink stay with their current owners in both appearances: `GlassSurface` under `workspace-sidebar.chrome-style` (`WindowTabGroupFrameView.swift:17–19`, `WindowTabGroupChromeContent.swift:9–19`). No per-app tint, so no appearance sampling.
- Keep the 500 ms hint behavior and the actual current binding-derived labels, with no second modifier timer. A key/click before display spoils the hold until all modifiers are released; activity after display keeps hints available.
- Keep existing persisted state readable. No new permission, socket, compatibility listener or installed-machine action is expected; record an actual by-hand step in **Prateek's checks on an installed build and real hardware** if one proves necessary.

## Depends on

Prateek's pick of look and grip treatment from the completed prototype. This is
a decision dependency; the draft is not authorization to ship the recommendation.
The existing native **The sidebar as a tree** and **Shortcut hints on tabs while
the modifier is held** supply the sidebar group target and hint seam.

## Done when

- [ ] In a 1920 × 1080 guest, stage Chrome with three local browser tabs, VS Code with three editor tabs and Ghostty with three native tabs. Read the actual membership once after discovery. Capture the picked strip over each app at rest, tab hover, close hover, mid-drag from the gutter, and under held Option. Match the prototype at logical point scale; explain native blur/font departures.
- [ ] Default strip height measures 24, item height 18 and no added top gap. The old grip and enclosing frame stroke are absent. Explicit height 38 still resolves to 38; heights 21–23 resolve to 24, and 20 or less still fail config checking. Test Swift defaults and generated Nickel defaults together.
- [ ] Drag the whole staged group from the 28-point gutter and empty background after the last tab to New Workspace. Preview, screenshot and final tree retain all leaves as one group. Drag from the sidebar group header too; a tab drag still reorders/detaches one tab without Option.
- [ ] Native pointer switching, keyboard tab focus, background/active closes, width hold, reorder, detach/re-entry and overflow remain usable at 24 points. Check a narrow group with enough tabs to scroll, a long title and an app with a close sheet. Extend behavior tests at the existing seams before changing them.
- [ ] Hints appear after 500 ms for the addressed group, follow active bindings, hide on release and retain the current pre-display spoil rule. A quick chord never flashes them; a shown digit or pointer selection remains usable. Use the existing controlled clock tests and a guest capture.
- [ ] The resize preview's mock pills (`WindowResizePreviewMockTabPillsPath.swift`) match the strip: no grip inset, unfilled labels at the 18-point item height. Captured mid-resize of the staged group.
- [ ] In light and in dark system appearance, the band over Chrome shows today's `chrome-style` fill with legible labels, and a `solid` chrome-style with a `solid-chrome-color` still colours it. Captured in both.
- [ ] Host and pinned-version guest `make check` pass; latest GitHub `Build and test` passes before landing. Retain guest screenshots and final layout readbacks against the picked prototype.
- [ ] Prateek checks installed-build pointer/keyboard use, his configured heights, a second display and real sleep/wake/unlock. Record any necessary by-hand migration or permission step in **Prateek's checks on an installed build and real hardware**.

## Sources

All code references below are at `7c7c9648`; recheck them against the feature's
base before implementing.

- [Prototype and recommendation](../prototypes/84-tab-strip/README.md), including its source-derived answers, measured native baseline and pick pictures. Original request: Prateek, 2026-10-07 and 2026-10-13, duplicated app/WinMux rows and the ambiguous grip; pictures beside baseline osx.
- `Sources/AppBundle/ui/tabs/WindowTabMetrics.swift:3–22`: 3-point side/bottom shell and 36-point runtime floor. `Sources/AppBundle/config/parseWindowTabs.swift:16–18` rejects 20 or less. `Sources/AppBundle/config/Config.swift:229–232` and `nickel-helper/nickel/winmux/defaults.ncl:150–152` both default to 36 today; change both and regenerate the shipped defaults. `nickel-helper/tests/helper.rs:941–951` converts `upstream-default-config.toml`, whose `window-tabs.height` is 36, and asserts it equals the defaults: add an `expected_conversion["window-tabs"]["height"]` exception beside the `workspace-sidebar.width` one, or that test fails.
- `Sources/AppBundle/ui/tabs/WindowTabStripView.swift`: the scroll background's group drag (`tabScrollBackgroundGroupDragGesture` at 54–85, attached at 275, with its focusing tap at 267–274), the item-height formula at 159, the gutter with its own focusing tap and group drag at 171–179, and the handle at 181–185. `tabChromeGroupDragGesture` (87–120) and `isWindowTabStripChromeGroupDragStart` (137–154) are attached nowhere; delete them rather than count them as a drag region. In an overflowing strip the scroll background has no empty area, so the gutter is the only strip target left once the handle goes: keep it. `WindowTabStripConstants.swift:10–27,41–76` owns the 24-point reserved grip, widths, spacing, radius and strokes.
- `WindowTabStripSupportViews.swift:46–86`: the two 9 × 1.5 capsules at 22% white, click-to-focus and stable group-drag identity. `WindowTabItemView.swift:11–53` owns pills, title weight and hover colour; `WindowTabCloseButton.swift:11–24` owns the close control.
- `Sources/AppBundle/mouse/resize/WindowResizePreviewMockTabPillsPath.swift:11–25` insets the resize preview's mock pills by `windowTabStripReservedGroupHandleWidth()` on both sides and draws them filled, `headerHeight − 8` tall.
- `WindowTabGroupFrameView.swift:14–39`, `WindowTabGroupShellShape.swift:20–30` and `WindowTabFrameGeometry.swift:4–27`: shell fill, outer/inner strokes and layout-derived frame geometry. Remove visible frame stroke without leaving stale resize/occlusion geometry or unused chrome owners.
- `WindowTabHintState.swift:11–37`, `WindowTabHintController.swift:11,42–70,102–118` and `WindowTabHintLabels.swift:12–29`: existing deadline, spoil, exact modifier and binding-derived label ownership. The shorter strip reuses these unchanged contracts.
- `Sources/AppBundle/ui/sidebar/WorkspaceSidebarWorkspaceSection.swift:520–563` and `WorkspaceSidebarTreeRows.swift:72–76` (the `.tabGroup` case): the existing native tab-group header, stable container drag payload and tree row. Keep this alternate whole-group target.
- `Sources/AppBundleTests/tree/WindowTabsTestTabStrip.swift:227–279`, `testWindowTabStripLayoutMatchesNextChromeMetrics` and `testWindowTabStripScrollBackgroundDragIgnoresTabPills`: the viewport reserves `windowTabStripReservedGroupHandleWidth()`. Line 240's `windowTabStripTabWidth(stripWidth: 360, count: 2) == 132` holds only because the 24-point reservation leaves 264 points for two tabs; without it they get 144. Change that expectation to the new arithmetic rather than keep a reservation to satisfy it, and retain the hit-classification tests. Searching `WindowTabGroupHandleView` finds no direct view test today; add behavior coverage for its removed focus target and retained alternatives rather than claiming such a test exists.
- `Sources/AppBundleTests/tree/WindowTabsTestDragGeometry.swift:33–72`: managed shell insets and a resize fixture explicitly set to 36. Retain explicit-height coverage and add 24-point default/floor cases. `Sources/AppBundleTests/config/ConfigTestWorkspaceSidebarConfig.swift:178–198` (`testParseWindowTabs`) pins the rejection of 20; add accepted 24 and floor cases without weakening that refusal. `WindowTabCloseTest.swift:200–215,241` pins width holds through the shared strip-width functions.
