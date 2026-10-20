# Trackpad gestures as held modes

Replaces the body of #49, **Trackpad gestures as Triggers**, which was blocked on Prateek since 2026-09-30. The label comes off; the title changes to this one, since Trigger leaves the glossary. Part of {{UMBRELLA}}.

## What to build

A day with the BetterTouchTool bridge, trackpad swipes posting `winmux lens` commands, settled what the native version has to do and why the bridge cannot: the gesture must drive the transition continuously, distance and speed setting progress and reversing cancelling; it must be contextual, swipe down closing an open Lens and swipe up doing nothing while the overview is open; and swipe left and right must move between workspaces like Spaces. A bridge posts a command at a threshold; it cannot track a finger.

Build gestures as a way into a mode. WinMux reads the trackpad itself, the route the 2026-09-30 research found viable through the private MultitouchSupport framework, with the two risks it flagged, the Input Monitoring grant and the read dying across sleep, handled below; the ownership question that grilling deferred is answered here. A gesture enters a mode exactly as a chord does.

## Decisions

- **A gesture is bound in a mode's record like a chord**: `swipe-up-3 = "mode overview-swipe"`, `swipe-down-3`, `swipe-left-3`, `swipe-right-3`, with the finger count in the name. It is a key in whatever mode is current, so "swipe down while a Lens is open closes it" is a key in that Lens's mode, not a global rule.
- **`'held` for a gesture means while the fingers are on the pad**; `on-release` runs when they lift. The shipped `overview-swipe` mode is held, with `on-enter = ["lens overview"]` and `on-release = ["lens settle browse"]`.
- **`lens settle <mode>`** is the verb that reads the gesture's progress: at or past the settle point the Lens stays open, its transition completes, and the named mode becomes current; short of it the Lens closes and `main` is current. A flick, a lift with velocity above the flick threshold in the swipe's direction, settles as if past the point whatever the distance; a flick back closes. The verb exists only for a gesture-entered mode; from a chord it exits 1.
- **The gesture drives the Presentation's transition** with a progress value from 0 to 1 that **Build the overview Presentation from the pick** defines; a reversed swipe lowers it, and the Presentation draws the value it is given, never an animation of its own while fingers are down. `'miniatures` gets the same progress property so the gesture works before the new Presentation lands.
- **Opening is instant by a number**: the Lens's first frame is drawn within 50 ms of the swipe passing its start threshold, measured by the Lens trace, so the transition is under the finger from the first centimetre.
- **Swipe left and right change workspace** in the shipped `main`, with the same progress-driven transition between the two workspaces' layouts.
- **The system gestures WinMux takes are turned off for it** while WinMux runs and restored on quit, through the same reconciler pattern the symbolic hotkeys use: a marker records what WinMux changed, launch repairs after a hard kill, and quit restores. The Dock owns these gestures and reads its defaults at launch, so the reconciler writes the Dock's gesture keys and restarts the Dock once on each change, which the docs say. Which gestures is the ownership question the 2026-09-30 grilling deferred, answered here: three-finger swipe up, down, left and right, and nothing else. Four-finger gestures stay macOS's.
- **The read survives sleep and asks for its grant once.** The trackpad read is restarted on wake, as the symbolic hotkeys are repaired on wake, and WinMux requests the Input Monitoring grant at the first gesture binding's load with a line in `doctor` while it is missing.
- **A continuous gesture that moves or resizes a window** shows a preview, commits on lift and cancels on Escape or after a rest, as already decided; none of them ships in this issue.
- **Licences**: AltTab, BetterCmdTab, jitouch and MiddleClick are GPL-3 and inspiration only, as already decided.

## Not checkable in a guest

A Tart guest has no trackpad. The build is tested through a recorded-frames seam, the way the refresh timing tests drive time through a controlled clock, and the real trackpad is Prateek's check.

## Depends on

- **Modes are the only modality**.

## Defaults chosen for you

- **Reading the trackpad** uses the private MultitouchSupport framework, as the gesture interception research found, behind a seam that a test drives with recorded frames. If the framework proves unusable on the current macOS, that is a stop and a question for Prateek, not a fallback to a bridge.
- **The start threshold** for a swipe to register is 10% of the pad's height or width, progress is linear from there to 60%, the settle point is progress 0.5, and the flick threshold is a lift velocity above 30% of the pad per second.
- **A gesture with a Lens already open from a chord** is read in that Lens's mode.

## Done when

- [ ] Tests drive the seam with recorded three-finger swipes: up enters `overview-swipe` and sets progress; a reversal lowers it; a lift past the settle point leaves the Lens open in `browse` and before it closes to `main`; a flick settles from any distance; down while `browse` is current runs its bound command; left and right change workspace with progress.
- [ ] The Lens trace in a guest, driven through the seam, shows the first frame within 50 ms of the start threshold on the rich desk.
- [ ] The system's three-finger swipes are disabled while WinMux runs and restored on quit: a test of the reconciler covers the marker, the repair after a simulated hard kill and the restore, and in a guest the Dock's gesture defaults read as off with WinMux running and on after it quits, with the Dock restarted each time.
- [ ] `doctor` names the Input Monitoring grant while it is missing, and the read restarts after a simulated wake, driven through the seam.
- [ ] `docs/` describes the gesture names, the modes they enter and what macOS loses.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: all four swipes on his trackpad, the reversal, and that four-finger gestures still belong to macOS.

## Sources

- The grilling record, 2026-10-19, "Modality" and "The boundary": gestures go native through held modes.
- #268's handoff, "Gestures stay on the BTT bridge until WinMux has native gestures; contextual behaviour and finger-tracked, interruptible animation are requirements".
- The gesture interception research and the gesture ownership grilling, `.scratch/winmux-fork/issues/01-` and `17-`.
