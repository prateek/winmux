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
strip background as whole-group drag targets. Tint the band toward the active
app's chrome, as the three captured examples show. The native app keeps its
own tabs and title bar. Preserve current tab order, focus, close, reorder,
detach, overflow and Option-held digit behavior through their existing owners.

## Decisions

- Relay recommendation, awaiting Prateek's pick: **he decides from pictures**. Use the prototype's same-scale Today, Thin, Held, Sidebar and baseline osx captures when accepting the feature.
- Relay recommendation, awaiting Prateek's pick: **three alternatives beside today's strip** remain available in the prototype. This implementation draft selects Thin and quiet; Held and Sidebar remain comparison alternatives unless his pick replaces it.
- Relay recommendation, awaiting Prateek's pick: **the grip goes or becomes a clear handle**. Select grip gone. Empty chrome, the gutter and the existing sidebar group header drag the whole group.
- Relay recommendation, awaiting Prateek's pick: **a prototype answers questions; it does not ship**. Keep the prototype static and isolated. This separate issue owns native behavior only after the pick.
- Relay recommendation, awaiting Prateek's pick: use the 24-point unfilled strip, active hairline and app-adjacent colours, with no group frame stroke. Keep membership and pointer access visible at rest.

## Defaults chosen for you

- Default height 24; item height remains `min(max(height − 10, 18), 26)`, giving 18. Keep 12-point labels, 14-point icons, 240/132 preferred/minimum widths and 4-point spacing unless the picked native capture requires an adjustment. Adapt close-button geometry and hit areas to fit the shorter item without changing its action contract.
- Keep existing explicit configured heights greater than 20; lower the runtime minimum to 24. The parser's refusal at 20 or less remains. Document that accepted 21–23 resolve to 24, just as accepted sub-36 values resolved to 36 before.
- Determine the active-app band colour through a bounded, cached native appearance seam, with the prototype's neutral light/dark tones as fallback. Do not sample every frame or create a second thumbnail pipeline. Verify Chrome, VS Code and Ghostty in both appearances before accepting a colour policy.
- Keep the 500 ms hint behavior and the actual current binding-derived labels, with no second modifier timer. A key/click before display spoils the hold until all modifiers are released; activity after display keeps hints available.
- Keep existing persisted state readable. No new permission, socket, compatibility listener or installed-machine action is expected; record an actual by-hand step in **Prateek's checks on an installed build and real hardware** if one proves necessary.

## Depends on

Prateek's pick of look and grip treatment from the completed prototype. This is
a decision dependency; the draft is not authorization to ship the recommendation.
The existing native **The sidebar as a tree** and **Shortcut hints on tabs while
the modifier is held** supply the sidebar group target and hint seam.

## Done when

- [ ] In a 1920 × 1080 guest, stage Chrome with three local browser tabs, VS Code with three editor tabs and Ghostty with three native tabs. Read the actual membership once after discovery. Capture the picked strip over each app at rest, tab hover, close hover, grip/gutter hover and under held Option. Match the prototype at logical point scale; explain native blur/font departures.
- [ ] Default strip height measures 24, item height 18 and no added top gap. The old grip and enclosing frame stroke are absent. Explicit height 38 still resolves to 38; heights 21–23 resolve to 24, and 20 or less still fail config checking. Test Swift defaults and generated Nickel defaults together.
- [ ] Drag the whole staged group from the 28-point gutter and empty background after the last tab to New Workspace. Preview, screenshot and final tree retain all leaves as one group. Drag from the sidebar group header too; a tab drag still reorders/detaches one tab without Option.
- [ ] Native pointer switching, keyboard tab focus, background/active closes, width hold, reorder, detach/re-entry and overflow remain usable at 24 points. Check a narrow group with enough tabs to scroll, a long title and an app with a close sheet. Extend behavior tests at the existing seams before changing them.
- [ ] Hints appear after 500 ms for the addressed group, follow active bindings, hide on release and retain the current pre-display spoil rule. A quick chord never flashes them; a shown digit or pointer selection remains usable. Use the existing controlled clock tests and a guest capture.
- [ ] Light and dark examples over all three apps meet the picked band appearance; no per-frame app-colour capture is introduced. Check focus changes between unlike app chromes and explain the selected caching/fallback policy.
- [ ] Host and pinned-version guest `make check` pass; latest GitHub `Build and test` passes before landing. Retain guest screenshots and final layout readbacks against the picked prototype.
- [ ] Prateek checks installed-build pointer/keyboard use, his configured heights, a second display and real sleep/wake/unlock. Record any necessary by-hand migration or permission step in **Prateek's checks on an installed build and real hardware**.

## Sources

All code references below are at `7c7c9648`; recheck them against the feature's
base before implementing.

- [Prototype and recommendation](../prototypes/84-tab-strip/README.md), including its source-derived answers, measured native baseline and pick pictures. Original request: Prateek, 2026-10-07 and 2026-10-13, duplicated app/WinMux rows and the ambiguous grip; pictures beside baseline osx.
- `Sources/AppBundle/ui/tabs/WindowTabMetrics.swift:3–22`: 3-point side/bottom shell and 36-point runtime floor. `Sources/AppBundle/config/parseWindowTabs.swift:17–20` rejects 20 or less. `Sources/AppBundle/config/Config.swift:229–232` and `nickel-helper/nickel/winmux/defaults.ncl:150–152` both default to 36 today; change both and regenerate the shipped defaults.
- `Sources/AppBundle/ui/tabs/WindowTabStripView.swift:54–154,157–197`: background/chrome drag classification, item-height formula, gutter, handle insertion, padding and clipping. Preserve those drag regions while removing the handle reservation. `WindowTabStripConstants.swift:10–27,41–76` owns the 24-point reserved grip, widths, spacing, radius and strokes.
- `WindowTabStripSupportViews.swift:46–86`: the two 9 × 1.5 capsules at 22% white, click-to-focus and stable group-drag identity. `WindowTabItemView.swift:11–53` owns pills, title weight and hover colour; `WindowTabCloseButton.swift:11–24` owns the close control.
- `WindowTabGroupFrameView.swift:14–39`, `WindowTabGroupShellShape.swift:20–30` and `WindowTabFrameGeometry.swift:4–27`: shell fill, outer/inner strokes and layout-derived frame geometry. Remove visible frame stroke without leaving stale resize/occlusion geometry or unused chrome owners.
- `WindowTabHintState.swift:11–37`, `WindowTabHintController.swift:11,42–70,102–118` and `WindowTabHintLabels.swift:12–29`: existing deadline, spoil, exact modifier and binding-derived label ownership. The shorter strip reuses these unchanged contracts.
- `Sources/AppBundle/ui/sidebar/WorkspaceSidebarWorkspaceSection.swift:520–563` and `WorkspaceSidebarTreeRows.swift:82–86`: the existing native tab-group header, stable container drag payload and tree row. Keep this alternate whole-group target.
- `Sources/AppBundleTests/tree/WindowTabsTestTabStrip.swift:227–279`, `testWindowTabStripLayoutMatchesNextChromeMetrics` and `testWindowTabStripScrollBackgroundDragIgnoresTabPills`: the viewport reserves `windowTabStripReservedGroupHandleWidth()` and pins 240/132 widths. Update the reservation expectation and retain hit classification tests. Searching `WindowTabGroupHandleView` finds no direct view test today; add behavior coverage for its removed focus target and retained alternatives rather than claiming such a test exists.
- `Sources/AppBundleTests/tree/WindowTabsTestDragGeometry.swift:33–72`: managed shell insets and a resize fixture explicitly set to 36. Retain explicit-height coverage and add 24-point default/floor cases. `Sources/AppBundleTests/config/ConfigTestWorkspaceSidebarConfig.swift:178–198` (`testParseWindowTabs`) pins the rejection of 20; add accepted 24 and floor cases without weakening that refusal. `WindowTabCloseTest.swift:200–215,241` pins width holds through the shared strip-width functions.
