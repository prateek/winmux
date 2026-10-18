# Mission Control and parked windows

Keep the existing parking policy. Smaller parked windows improve Mission Control substantially, but discard the parked window's useful rendered content and introduce visible resizing in the switching probe. Minimization also improves Mission Control, with native Dock animations and a Dock full of minimized windows. Neither is a suitable default from this evidence.

## What was tested

The fourteen-window rich desk ran on one 1920×1080, 1× virtual display on macOS 26.6.2 (25G83), with Swift 6.4. The base was `2d39d262`; the overlay change is `475243be`. The same `live.zsh` and `interact.zsh` drove both trees. Mission Control used `arrow-chord up`, and App Exposé used `arrow-chord down`.

The parking experiments ran with WinMux stopped. `parking.swift` records native window IDs and CoreGraphics frames, maps those IDs to AX windows, changes only the desk's frames or minimized state, and reads the resulting frames back. No production parking code changed. The probe saves the workspace 2 and 3 arrangements before quitting WinMux, then replays them with incoming windows first, matching production's unhide-before-hide order. These serial AX replays demonstrate possible visual costs; they are not measurements of a future WinMux implementation's latency.

The evidence directory supplied with the builder handoff contains `mission-control/base/`, `mission-control/branch/` and `mission-control/spike/`. Each Mission Control still has a matching Dock AX dump. `measure.py` matches thumbnail rectangles to saved native window sizes. Percentages below are linear size, the mean of width and height ratios, not area. Pixel rounding accounts for the small ranges. The screenshots independently show the same rectangles.

The desk has fourteen managed windows. Mission Control shows thirteen application thumbnails: the Updater prop is a floating-level titled window, and macOS already omits it. On the base it additionally shows four WinMux panels, for seventeen thumbnails total. The branch shows thirteen, with no WinMux panels. The removed panels are the tab-group backing panel, its tab strip and two Column dividers. Expanded/collapsed sidebar, mode HUD and Lens comparisons agree. App Exposé shows three Safari windows, with no WinMux chrome, at 59.58%, 76.46% and 91.67% of their real sizes.

The first pass also found that a mode HUD or Lens summoned after entry draws above Mission Control, although Dock still lists only thirteen application thumbnails. Its captures are `late/hud-opened-during-mission-control.png` and `late/lens-opened-during-mission-control.png`. The follow-up ruling explicitly permits those summoned overlays. It separately requires normal-level chrome and the sidebar to stay ordered out during a system overview, which `MissionControlState` now enforces through Dock notifications. `.transient` itself changes only normal-level entry behavior; above-normal windows are already transient in AppKit. These panel changes do not alter the parking experiments or recommendation below.

## Results

| Arrangement | Application thumbnails | Linear share | Union of native window frames |
| --- | ---: | ---: | ---: |
| Rich desk, WinMux base or branch | 13 | 8.17–8.30% | 3703×2035 |
| Parking replay, WinMux stopped | 13 | 8.12–8.23% | 3703×2035 |
| Attempt fully off screen | 13 | 9.09–9.14% | 3664×2035 |
| Request 80×80 parked windows | 13 | 69.54–70.06% | 2565×1394 |
| Minimize hidden windows | 3 | 89.44–89.47% | 3703×2035, including minimized windows |
| Full-size on-screen control | 13 | 35.25–35.33% | 1846×1025 |

The first two alternatives were fully off-screen parking and smaller parking. The smaller alternative improved thumbnails, so the issue's stop-after-two condition did not apply. Minimization was tried next. The final control restores every window to its full saved size and places every formerly parked window at `(62, 42)`, entirely on screen. It is a control, not a workspace-hiding option.

### Does the bounding-box inference hold?

Parked geometry causes the poor fit: stopping WinMux while replaying its parked frames retains the approximately 8% thumbnails; bringing the same full-size windows on screen raises them to approximately 35%. Shrinking parked windows raises the unshrunk visible windows to approximately 70%.

The stronger claim that Mission Control simply scales to the union bounding box is unsupported. The smaller-parking case has a larger union than the on-screen control, yet a much larger thumbnail scale. Minimization leaves the recorded union unchanged while removing ten thumbnails and raising the scale to approximately 89%. Both eligibility and individual window geometry matter. These experiments do not recover Dock's internal fitting algorithm or reproduce the earlier report's approximately 50% control value.

### Fully off-screen parking

The probe requested `(1950, 1110)` for hidden windows. AX returned success for positions, but the subsequent frames were clamped to `x = 1880` and app-dependent `y` values of 1028–1052. A 40-point strip remained on the right edge. The small thumbnail increase therefore comes with a worse visible leak; this trial did not achieve fully off-screen parking through AX.

ScreenCaptureKit's desktop-independent captures remained complete: TextEdit 1221×986 and Safari 1024×678. The switch movie shows the persistent corner strip. This option needs no resize, but fails the hiding requirement.

Evidence: `spike/offscreen-actual.json`, `offscreen-apply.txt`, `offscreen-mission-control.png`, `offscreen-desktop.png`, `offscreen-textedit.png`, `offscreen-safari.png`, `offscreen-switch.mov`.

### Smaller parked windows

Apps enforce different minimum sizes. An 80×80 request produced TextEdit 115×82, Safari 574×220 or 574×240, Zed 360×240, Ghostty 87×80, Finder 501×252 and Preview 708×224. Calculator stayed 230×408. The Updater refused size writes. Native readback, rather than the requested size or AX success alone, supplies the measurement denominator.

The three visible windows retain their full sizes and draw at about 70% in Mission Control. Hidden TextEdit and Safari captures now contain only 115×82 and 574×240 pixels respectively. TextEdit's picture is almost entirely toolbar; Safari has little page content. A consumer that needs the previous full-size picture must retain it before resizing. This also changes the app's layout, including terminal reflow.

The switching film shows a small outgoing Notes window over the incoming arrangement before it is parked. Restoring dimensions and moving windows are separate visible operations in this probe. A production experiment could try different ordering and redraw barriers, but neither flicker-free switching nor preservation of app state is established here.

Evidence: `spike/small-actual.json`, `small-mission-control.png`, `small-textedit.png`, `small-safari.png`, `small-switch.mov` and its four `small-switch*-*.txt` readbacks.

### Minimization

The probe sets `AXMinimized` for every hidden window and clears it for the incoming workspace. Only the three visible windows remain in Mission Control, at about 89%. The two static parked-window capture targets remain available through ScreenCaptureKit at their full saved sizes. This does not establish fresh rendering while minimized: the desk content is static.

The Dock gains minimized-window tiles, and the switching film shows the native Genie distortions. Minimization also gives workspace hiding the semantics of real minimized windows. WinMux's minimized-window origin, Lens Frozen state and native restore paths would need a separate design; this spike implements none of them.

Evidence: `spike/minimize-mission-control.png`, `minimize-textedit.png`, `minimize-safari.png`, `minimize-switch.mov` and its AX write/readback transcripts.

### What another app can capture

The baseline, off-screen attempt and minimization all returned complete static TextEdit and Safari pictures through `SCScreenshotManager` with a desktop-independent window filter. The baseline pictures include readable document/page text even though the windows are parked one point inside the right edge. The general claim that a parked window can only be captured as a one-point sliver is therefore false for this capture path on this guest. DockDoor's specific backend was not exercised; a screen-intersection capture can have different results.

## Other approaches

These were considered but not trialled:

- Hide an app only when all its windows are hidden. This cannot cover the rich desk's mixed-workspace Safari and TextEdit windows. App activation/unhide would also need to preserve WinMux's per-window workspace policy. Its capture and switching costs remain unmeasured.
- Put hidden windows on a second native Space. This would introduce a native-Space ownership and transition policy alongside WinMux workspaces. Assignment, activation and capture behavior, especially with multiple displays or fullscreen Spaces, remain unmeasured.

No change to parking is recommended, so this pass creates no parking build-issue draft. WinMux's chosen persistent overview remains the usable all-workspace view. A later parking change should prove useful hidden-window captures and switching behavior across real apps before trading either for Mission Control thumbnail size.

## Boundaries and decisions

Decided: Try fully off-screen parking first and smaller parked windows second; continue with minimization because smaller parking improves thumbnails.

Decided: Use desktop-independent ScreenCaptureKit captures of parked TextEdit and Safari windows to measure the capture cost; do not generalize the result to DockDoor's backend.

Decided: Retain shipped parking and create no parking implementation draft, because the tested alternatives have visible or capture costs.

No named default changed. Installed-build checks, a physical trackpad gesture, a second display and real sleep/wake/unlock remain untested. The native working windows, marketing renderer and corner-radius probe are unchanged. Full raw screenshots, movies, native frames, AX dumps and check logs remain with the issue's builder evidence; the demo pass supplies public final-commit media.

## Sources

- [Mission Control and Exposé with WinMux running](https://github.com/prateek/winmux/issues/108), including its settled panel exclusion and report-before-changing-parking decisions.
- `Sources/AppBundle/tree/MacWindow.swift`, `hideInCorner`: retained size, one-point corner placement and pre-parking picture request.
- `Sources/AppBundle/layout/refresh.swift`, `layoutWorkspaces`: incoming-workspace layout before hidden-workspace parking.
- `.scratch/winmux-fork/proofs/mission-control/`: the probe, shared live/interaction drivers and measurement script used for these results.
