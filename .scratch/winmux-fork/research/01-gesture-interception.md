# Research: in-app trackpad gesture interception on macOS 26

Ticket: [01-research-gesture-interception](../issues/01-research-gesture-interception.md). Researched 2026-09-28 on macOS 26.5.2 (25F84) with Command Line Tools 26.6.

The upstream repos below were read at these commits. Line references point at them.

| Repo | Commit | License |
|---|---|---|
| lwouis/alt-tab-macos | `0d9d710` | GPL-3 |
| rokartur/BetterCmdTab | `1168eb6` | GPL-3 |
| acsandmann/aerospace-swipe | `7e06fe4` | MIT |
| aaronkollasch/jitouch | `f8e8d67` | GPL-3 |
| artginzburg/MiddleClick | `566155d` | GPL-3 |
| Kyome22/OpenMultitouchSupport | `15c6bb0` | MIT |
| asmvik/yabai | `dd84572` | MIT |

Only the MIT repos can donate code to an MIT fork. Treat the GPL ones as inspiration, the same rule the map sets for AltTab.

## Recommendation

1. **Detect** with the private MultitouchSupport framework. Call `MTDeviceCreateList` and register `MTRegisterContactFrameCallback` on every device, resolving the symbols with `dlopen`/`dlsym` so a renamed symbol turns the feature off instead of crashing WinMux. Feed the raw contact frames into a small WinMux-owned recognizer that classifies 3- and 4-finger swipes as up, down, left, or right. Restart the listeners on wake and on device hot-plug.
2. **Resolve the conflict with the system gestures** by asking Prateek to turn off, in System Settings > Trackpad, the specific system swipes that WinMux binds. WinMux reads the live settings and warns when a bound gesture still has a system owner.
3. **Drop the scroll leak.** Once a system swipe is off, macOS turns the multi-finger drag into a scroll stream to the app under the cursor. Arm an active scroll-wheel tap only while the configured finger count is down, and drop continuous scroll events for that sequence, momentum tail included.
4. **Optional and experimental:** keep the system gesture on and swallow the Dock's horizontal "DockSwipe" event with an active session tap. This is undocumented, only suppresses the horizontal Space swipe in the one tool that ships it, and appears to have changed on macOS 27. It stays off by default.

Don't build detection on `NSEvent` gesture events from a CGEvent tap. The touches it exposes are a private bridge as well, one report says macOS 26.3 truncates them to a single touch, and an always-active tap on that stream has caused system-wide cursor lag.

### Risks, ranked

1. **Private API drift.** Symbols, the `MTTouch` struct layout, and device family IDs are undocumented and have broken before, on Ventura for example. `dlsym` limits the damage to "gestures stop working" rather than a crash.
2. **Silent death after sleep, wake, or hot-plug.** Every long-lived tool in this space fights it, with restart-on-wake, IOKit hot-plug notifications, and tap re-enable handlers.
3. **Scroll leak** into the app under the cursor when a system gesture is off. It's known and fixable, but it needs an active tap for the duration of the gesture.
4. **Event-tap cost.** Any active tap on gesture or scroll events sits in the input path. Arm it only while it can matter.
5. **Permission ambiguity.** Whether MultitouchSupport contact frames need Input Monitoring on top of Accessibility is disputed between sources. A spike on Prateek's Mac settles it.

## Findings

### 1. What WinMux already has

- The sidebar swipe isn't a trackpad-gesture recognizer. `WorkspaceSidebarViewSwipe.swift:6-22` is a SwiftUI `DragGesture`. The companion `WorkspaceSidebarProjectSwipeCapture.swift:48-54` installs an **app-local** `NSEvent` monitor for `.scrollWheel` and handles only two-finger precise scrolls whose `event.window` is the sidebar panel and whose point is inside the view (`:72-88`). It swallows the event by returning `nil` (`:117`). None of this sees events outside WinMux's own window, so none of it reaches global 3- and 4-finger swipes.
- Reusable bits: the direction-lock and threshold helpers (`workspaceSidebarProjectSwipeDirection`, `WorkspaceSidebarViewSwipe.swift:42-61`) and the haptic call (`WorkspaceSidebarView.swift:632-633`, `NSHapticFeedbackManager`).
- WinMux already runs active CGEvent taps at `.cgSessionEventTap` on the main run loop, with `.tapDisabledByTimeout` re-enable handling (`Sources/AppBundle/ui/tabs/DoubleSidedWindowGesture.swift:23-53`, `Sources/AppBundle/ui/sidebar/WorkspaceSidebarPanel.swift:486-505`). The Accessibility-backed tap plumbing exists.
- Packaging: the app is not sandboxed (`resources/WinMux.entitlements:5-6`, `project.yml:59-63`), and Release builds enable the hardened runtime (`project.yml:56`). No code requests Input Monitoring. A search for `IOHIDRequestAccess` or `ListenEventAccess` under `Sources/` finds nothing.

### 2. MultitouchSupport: API surface

- The framework ships at `/System/Library/PrivateFrameworks/MultitouchSupport.framework` on this Mac. The macOS 26.6 SDK stub `MacOSX.sdk/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport.tbd` (current-version 9450.2, targets x86_64 and arm64e) exports `_MTDeviceCreateList`, `_MTDeviceCreateDefault`, `_MTRegisterContactFrameCallback`, `_MTUnregisterContactFrameCallback`, `_MTDeviceStart`, `_MTDeviceStop`, `_MTDeviceRelease`, `_MTDeviceIsBuiltIn`, and `_MTDeviceCreateFromService`, plus an `_MTActuator*` haptics family.
- The community-reverse-engineered declarations are in OpenMultitouchSupport `Framework/OpenMultitouchSupportXCF/OpenMTInternal.h:17-90`. They cover the `MTTouch` struct (frame, timestamp, identifier, state, fingerId, handId, normalized position and velocity, pressure, angle, axes, density), the touch states 0-7 (`MakeTouch=3`, `Touching=4`, `BreakTouch=5`), and the frame-callback signature `(device, touches[], numTouches, timestamp, frame)`.
- Use `MTDeviceCreateList`, not `MTDeviceCreateDefault`. The default device only covers the built-in trackpad: OpenMultitouchSupport's README says so ("only default device"), and aerospace-swipe PR #29 reports that Magic Trackpad frames never arrived through it. jitouch (`jitouch/Jitouch/Gesture.m:2786`), MiddleClick (`MoreTouch/Sources/MoreTouchCore/Core.swift:3-19`), and BetterCmdTab (`BetterCmdTab/Input/SwipeTrigger.swift:181`) all enumerate with `MTDeviceCreateList`.
- Swift binding patterns:
  - MiddleClick declares the functions in a system-library module with `CF_SWIFT_NAME` (`MoreTouch/Sources/MultitouchSupport/MultitouchSupport.h:63`) and links with `-F/System/Library/PrivateFrameworks` (`MoreTouch/Package.swift:21-26`).
  - BetterCmdTab `dlopen`s the framework path and `dlsym`s each symbol, so "a missing or renamed symbol degrades to 'feature unavailable' instead of crashing at launch" (`BetterCmdTab/Input/SwipeTrigger.swift:18-22, 170-185`). **The `dlsym` route fits WinMux better**: no link-time dependency, and it avoids any question about linking an arm64 binary against the arm64e-only `.tbd`, which I didn't test.
- Shipping tools that use it:
  - BetterTouchTool 6.791, installed here, links `MultitouchSupport.framework` (`otool -L`) and imports `_MTDeviceCreateList`, `_MTRegisterContactFrameCallback`, `_MTDeviceStart`, and others (`nm -u`).
  - jitouch, MiddleClick, BetterCmdTab, and OpenMultitouchSupport do the same, per the files cited above.
  - Swish is closed source and not installed here, so I couldn't verify it. BetterCmdTab's comment says Swish uses MultitouchSupport (`SwipeTrigger.swift:7-8`), but that's secondary.

### 3. Entitlements, sandbox, hardened runtime, permissions

- **Sandbox:** it must be off. OpenMultitouchSupport's README says "App SandBox must be disabled", and WinMux's already is.
- **Hardened runtime:** it doesn't block the framework. BetterTouchTool is signed with `flags=0x10000(runtime)` and still links it (`codesign -dv`). MiddleClick sets `ENABLE_HARDENED_RUNTIME = YES` (`MiddleClick.xcodeproj/project.pbxproj:185`) with an empty entitlements file (`MiddleClick/MiddleClick.entitlements`). BTT does carry `com.apple.security.cs.disable-library-validation`, most likely for its plugins. MiddleClick shows the framework doesn't need it, which fits library validation only rejecting non-Apple-signed code, and the framework is Apple-signed. I inferred that last point and didn't test it.
- **No special entitlement** turns up in any of the tools examined.
- **TCC:** Accessibility is required for the CGEvent taps. aerospace-swipe issue #28 and PR #29 say raw MT frames also need **Input Monitoring** and add `IOHIDRequestAccess`. But none of AltTab, BetterCmdTab, MiddleClick, jitouch, or aerospace-swipe HEAD requests Input Monitoring: a grep for `IOHIDRequestAccess|IOHIDCheckAccess|ListenEventAccess` across their sources comes up empty. **Unsettled.** The #28 probe may have run from a terminal without the other grants.
- **SDK header drift:** the `CGEvent.h` comment says taps at `kCGHIDEventTap` are root-only (`MacOSX.sdk/.../CoreGraphics.framework/Headers/CGEvent.h:269-270`). AltTab and aerospace-swipe both create HID-level taps as ordinary users with Accessibility (`src/events/TrackpadEvents.swift:79-92`, `src/event_tap.m:72-79`), so the comment is stale.

### 4. Breakage history

- **Ventura (13):**
  - jitouch "No gestures working on Ventura" (#55).
  - The Magic Trackpad's family ID changed from 130 to 129 (#54).
  - The fix came in "jitouch now works on Ventura" (#51).
  - Crashes followed on Sonoma (14) (#74, #80).
- **macOS 27:** jitouch 2.82.1 is reported working on 27.0 (#89, 2026-09-25). The MT contact-frame API survived at least 13 through 27.
- **macOS 26.3:** aerospace-swipe #28 reports that `NSEvent.allTouches` on tapped gesture events holds at most one touch, while MT contact frames still deliver every finger. PR #32 contradicts it: on 26.3.2 "the event tap delivers complete 3-touch frames", but KVC `timestamp` on `NSTouch` now returns nil. The NSTouch path breaks in ways that vary by machine.
- **Sleep and wake:**
  - MiddleClick restarts its listeners on wake and on device-added (`MiddleClick/Controller.swift:6-20`). Its maintainer names "stop randomly stopping" as the top complaint in seven years of issues (MiddleClick issue #174).
  - OpenMultitouchSupport stops and restarts the device on `NSWorkspaceWillSleep`/`DidWake` (`OpenMTManager.m:43-44, 134-140`).
  - jitouch re-registers through `IOServiceAddMatchingNotification` for add and remove (`Gesture.m:3261-3271`).
  - aerospace-swipe #14 reports swipes dying after sleep.
- **Taps dying:** AltTab #5137 ("Gesture stops working", macOS 26.1) was fixed by re-enabling on `tapDisabledBy*` (`src/events/TrackpadEvents.swift:116-135`, commit `8ffe344f`).

### 5. Do the system gestures have to be off, and which keys control them?

- Observing MT frames doesn't stop the system gesture. jitouch refuses to bind Four-Swipe-Left/Right while `TrackpadFourFingerHorizSwipeGesture` is on and tells the user to untick "Swipe between full-screen apps" (`prefpane/TrackpadTab.m:704-718`). AltTab, even with its absorbing tap, tells users "You may need to disable some conflicting system gestures" and links to `x-apple.systempreferences:com.apple.Trackpad-Settings.extension` (`src/preferences/settings-window/tabs/controls/ControlsTab.swift:357-358, 1018-1019`).
- Keys, read from this Mac (`defaults read`):
  - `com.apple.AppleMultitouchTrackpad` (built-in) and `com.apple.driver.AppleBluetoothMultitouch.trackpad` (Magic Trackpad) both hold `TrackpadThreeFingerHorizSwipeGesture`, `TrackpadThreeFingerVertSwipeGesture`, `TrackpadFourFingerHorizSwipeGesture`, `TrackpadFourFingerVertSwipeGesture`, `TrackpadFourFingerPinchGesture`, `TrackpadFiveFingerPinchGesture`, and `TrackpadThreeFingerDrag`.
  - `defaults -currentHost read -g` mirrors them as `com.apple.trackpad.threeFingerHorizSwipeGesture` and so on.
  - Prateek's current values are all `2` for the 3- and 4-finger horizontal and vertical swipes, and `TrackpadThreeFingerDrag = 0`.
  - My inference, not a documented fact: `0` means off, and `2` on both the three- and four-finger keys matches the "three or four fingers" choice.
  - The Dock keys commonly cited for Mission Control and App Exposé (`showMissionControlGestureEnabled`, `showAppExposeGestureEnabled`) aren't set in `com.apple.dock` here, so they're at their defaults. I found no primary source defining them.
- The live driver state lives in the IORegistry. `ioreg -l` shows `MultitouchPreferences` and `HIDEventServiceProperties` dictionaries carrying the same `Trackpad*Gesture` keys, and jitouch reads `TrackpadUserPreferences` from the driver service (`TrackpadTab.m:705-711`). **Unverified:** whether `defaults write` alone takes effect without a logout or a System Settings toggle. Change the settings through System Settings and have WinMux only read them.
- **Side effect of turning them off:**
  - The drag becomes scroll events to the app under the cursor, momentum included. AltTab has a TODO saying so (`src/events/TrackpadEvents.swift:3`).
  - aerospace-swipe PR #31 measured "a ~400 ms momentum tail" and fixed it with an active scroll tap gated on the finger count.
  - jitouch #69 reports the same leak for three-finger swipes.
  - AltTab's version drops `scrollWheelEventIsContinuous != 0` events while armed (`src/events/ScrollwheelEvents.swift:31-39`).

### 6. Can an event tap swallow the gesture instead?

Two different event streams are involved.

- **NSEvent gesture events (type 29, `NSEventTypeGesture`):**
  - AltTab swallows these with a second, active HID tap that it enables only while enough fingers are down or its switcher is open (`src/events/TrackpadEvents.swift:13-18, 104-123, 159`).
  - That stops the *focused app* acting on the swipe (`:184`). It doesn't stop the Dock, which is why AltTab still asks users to turn off system gestures (section 5).
  - aerospace-swipe's tap is listen-only for the same reason (`src/event_tap.m:72-79`), and PR #31 says "Gesture events are never dropped, so Mission Control and NSTouch-reading apps are unaffected".
- **The Dock's own swipe (CGS type 30 `kCGSEventDockControl`, field 110 = 23 `kIOHIDEventTypeDockSwipe`):**
  - BetterCmdTab's experimental `SpaceSwipeSuppressor` runs an active `.cgSessionEventTap` on types 29 and 30. It returns `nil` for real (source pid 0) DockSwipe events with field 123 (`kCGEventGestureSwipeMotion`) equal to 1, meaning horizontal. The comment says this suppresses the swipe "before the Dock acts" (`BetterCmdTab/Input/SpaceSwipeSuppressor.swift:6-16, 70-77, 92-118, 208-224`).
  - It passes vertical DockSwipes (Mission Control and App Exposé) through untouched, so there's no evidence either way that vertical suppression works.
  - yabai (MIT) reads the same fields and phases (`src/mouse_handler.c:69-79`) and synthesizes DockSwipes for instant Space switching (`src/space_manager.c:959-968`), which corroborates the constants.
  - BetterTouchTool's binary contains "failed to create macOS 27 augmented DockSwipe event; posting legacy event" (`strings` on BTT 6.791). The DockSwipe format appears to have changed on macOS 27.
  - Verdict: this may work for horizontal Space swipes on 26 but hasn't been verified here. It's undocumented, it's already drifting, and it rides on an always-on active tap (see section 7).
- For an AeroSpace-style WM, the horizontal system swipe matters less than it looks. AeroSpace, and so WinMux, "employs its own emulation of virtual workspaces instead of relying on native macOS Spaces" (AeroSpace README, line 21), so the native horizontal swipe mostly moves between full-screen apps.

### 7. Latency and cost

- **MT frames:** there's no primary figure for the frame rate. One probe logged 77 frames during a single 4-finger swipe (aerospace-swipe #28). Recognition latency is dominated by the recognizer's travel threshold, not delivery: aerospace-swipe fires at 5% of pad travel (`src/event_tap.h:9`, `ACTIVATE_PCT 0.05f`), and AltTab steps at 3% (`src/events/TrackpadEvents.swift:274`). MT callbacks run on the framework's own thread and need a live run loop (PR #29), which WinMux has. **Measure it in the spike.**
- **Active taps on gesture streams hurt.** AltTab #5911 (macOS 27) reported an "unusable dock and menu" and cursor lag with no CPU spike. The cause: "an active tap on `cghidEventTap` makes the WindowServer wait for our callback on EVERY gesture event … including the mouse-moves that carry the cursor" (`src/events/TrackpadEvents.swift:5-11`, commit `1a85669b`). AltTab fixed it by detecting on a listen-only tap and enabling the active one only at gesture boundaries (`:101-109, 155-159`).
- Apply the same rule to WinMux's scroll-leak tap and to any DockSwipe suppressor: enable them from the MT recognizer when N fingers land, and disable them when the fingers lift.
- BetterCmdTab adds a guard against "tap disabled" storms. Re-enabling an active tap after Accessibility is revoked "freezes the whole system" (`SpaceSwipeSuppressor.swift:49-66, 161-205`). WinMux's existing taps re-enable unconditionally (`DoubleSidedWindowGesture.swift:48-53`), so this is worth copying.

### 8. How the named tools do it

| Tool | Detection | Conflict handling | Source |
|---|---|---|---|
| BetterTouchTool 6.791 | MultitouchSupport (`MTDeviceCreateList`, contact-frame callback) | Has a "Block Real Gesture Triggering" option; synthesizes DockSwipe events, with macOS 27 variants. Mechanism is closed | `otool -L`, `nm -u`, and `strings` on the installed binary |
| Swish | Not verified (closed source, not installed) | Unknown | BetterCmdTab comment only |
| jitouch | MultitouchSupport on every device, IOKit hot-plug | Asks the user to turn off the conflicting system gesture | `Gesture.m:2786, 3261`; `TrackpadTab.m:704-718` |
| AltTab | Listen-only HID tap on `NSEvent` gesture events, reading `allTouches` | Absorbing tap armed per gesture, scroll tap, "disable conflicting system gestures" hint | `src/events/TrackpadEvents.swift`, `ScrollwheelEvents.swift`, `ControlsTab.swift:357` |
| BetterCmdTab | MultitouchSupport via `dlopen` | Experimental DockSwipe suppressor, horizontal only | `SwipeTrigger.swift`, `SpaceSwipeSuppressor.swift` |
| aerospace-swipe | Listen-only HID tap on gesture events; PR #29 (open) moves to MT frames | Scroll gate (PR #31, fork) | `src/event_tap.m`, `src/main.m:252-280` |
| WinMux sidebar | App-local `.scrollWheel` monitor, two fingers, own window only | Not applicable | `WorkspaceSidebarProjectSwipeCapture.swift:48-117` |

## Open questions for a spike

A throwaway probe on Prateek's Mac (26.5.2) would settle these:

1. Do MT contact frames arrive for WinMux with Accessibility alone, or is Input Monitoring also required?
2. How many touches does a listen-only HID tap on type 29 see on this build? This is only for comparison with #28 and #32.
3. With a system swipe on, does dropping DockSwipe events stop the horizontal Space swipe? Does dropping vertical ones stop Mission Control and App Exposé?
4. What's the frame interval, and the time from touch-down to the Trigger firing at a given travel threshold?
5. Does `defaults write` on the `Trackpad*SwipeGesture` keys take effect without a logout?
