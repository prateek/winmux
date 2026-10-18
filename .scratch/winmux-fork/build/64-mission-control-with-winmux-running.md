# Mission Control and Exposé with WinMux running

Part of {{UMBRELLA}}.

## What to build

Prateek, on `0.5.6-dogfood.12` with the shipped defaults: the trackpad's three- or four-finger swipe for Mission Control gave "an Exposé-like thing" that was much slower than Exposé, was not the grid, and showed WinMux's sidebar as if it were an app's window.

That gesture is macOS's own, and WinMux takes over neither it nor any Mission Control key. It was Mission Control itself, drawn badly because of what WinMux does to the desktop. It was reproduced in a guest on `0.5.6-dogfood.13`, on the fourteen-window desk across four workspaces, opened with `ctrl-up`:

- **Every thumbnail is about 8% of the window's real size**, scattered on an empty screen. Without WinMux the same windows draw at about 50%.
- **It is not slower by the clock.** It settles in 287 to 289 ms with WinMux and 304 to 312 ms without, at fourteen windows and at twenty-five. The gesture could not be tried in a guest.
- **A tab group's backing panel, its tab bar and the Column dividers are drawn as windows.** The settled view did not show the sidebar.
- **App Exposé is normal**, windows of hidden workspaces included.

Inferred, not shown: WinMux parks the windows of hidden workspaces one point inside the screen's bottom-right corner, and Mission Control scales to fit the bounding box of every window, parked ones included. DockDoor draws a parked window as a one-point sliver for a related reason: it captures only the part that is on screen.

Prateek has chosen WinMux's `overview` as the view that stays open, so Mission Control does not have to be good. It has to not be embarrassing, and it stays the swipe's target until **Trackpad gestures as Triggers** is built.

## Decisions

- **WinMux's own panels stay out of Mission Control and App Exposé**: tab-group panels and tab bars, Column dividers, the sidebar, the Lens panel, the HUDs and the empty-Column outline.
- **A spike on where hidden windows are parked**, reported before anything is changed. Say whether the inference above holds, what else could hide a workspace's windows, and what each option costs: in Mission Control's thumbnails, in what another app captures of a parked window, and in the flicker AeroSpace's parking was chosen to avoid.

## Not in this issue

- Replacing Mission Control with a Lens, or binding the swipe.
- Changing how workspaces are hidden. The spike reports; a change is its own issue.

## Depends on

Nothing.

## Defaults chosen for you

- **The spike is a day at most.** If the first two options tried do not improve the thumbnails, stop and report.

## Done when

- [ ] Mission Control with WinMux running on the fourteen-window desk shows no WinMux panel, shown by a capture before and after.
- [x] The pull request reports the spike: what Mission Control does with parked windows, the options tried, and a recommendation.
- [ ] Check the installed build with Mission Control and App Exposé.
- [ ] Check the physical trackpad gesture.
- [ ] Check a second display.
- [ ] Check real sleep, wake and unlock.

## Built

Every overlay constructor uses `winMuxOverlayCollectionBehavior`, beside `NSPanelHud`: `.canJoinAllSpaces`, `.fullScreenAuxiliary` and `.transient`. Window levels, input and stacking remain unchanged. Titled setup, Settings, message/error and confirmation windows retain their behavior; the marketing renderer and corner-radius probe are untouched.

Native-panel regressions cover the HUD base, sidebar, Lens and its landing, Peek and the flip animation factory. They fail without `.transient`; host and pinned-version guest `make check` pass. The same guest driver checks both source trees on the fourteen-window rich desk. The base shows thirteen application thumbnails plus four WinMux panels; the branch shows thirteen application thumbnails and no WinMux panels. macOS already excludes the floating Updater prop. Sidebar, HUD and Lens captures agree; App Exposé shows all three Safari windows normally. Tab clicks, divider dragging and sidebar workspace selection retain the base's behavior after leaving Mission Control and switching workspaces.

The first Done-when item remains unmet for late-opened overlays: the mode HUD and Lens, when opened after Mission Control has started, still draw above it with `.transient`. Panels open before entry are excluded correctly. The builder's ruling requires these panels to be reported unmet and forbids `.stationary`; no extra window-ordering policy was added. The shared native policy and tests are built, with this live limitation preserved in the capture index and pull request notes.

The spike is [Mission Control and parked windows](../research/31-mission-control-parking.md), with reproducible tools under `../proofs/mission-control/`. Full-size corner parking yields about 8% thumbnails. The fully off-screen AX attempt is clamped onto the display. Smaller parking raises current-window thumbnails to about 70%, but sacrifices parked picture detail and visibly resizes windows during the serial switch probe. Minimization raises current-window thumbnails to about 89%, with native Dock tiles and animations. The full-size on-screen control gives about 35%; the union bounding box alone does not explain fitting. Desktop-independent ScreenCaptureKit captures full static parked pictures with the existing policy. Keep existing parking; no parking change or implementation draft is proposed.

Installed-build and physical-device checks above remain Prateek's. The builder publishes no release.

## Sources

- Prateek, 2026-10-06: "it took over my Exposé shortcuts, but it was much slower than Exposé … in the Exposé view it was using the sidebar as well, like an app." He opened it with the three- or four-finger trackpad gesture.
- The switching comparison, 2026-10-07 to 2026-10-09: Mission Control and App Exposé with and without WinMux in guests, and DockDoor on the same desk.
- Prateek, 2026-10-13, choosing who owns Cmd-Tab and the open view.
