# Research: in-app trackpad gesture interception on macOS 26

Type: research
Status: resolved

## Question

Can WinMux itself recognise three- and four-finger swipes (up, down, left, right) and use them as Triggers, replacing the native Mission Control / App Exposé / space-switch gestures? Cover: the private MultitouchSupport framework (API surface, entitlements, sandbox or hardened-runtime impact, breakage history across macOS releases), whether the system gesture must be turned off in System Settings (and which defaults keys control that), whether an event tap can swallow the NSEvent gesture phases instead, latency, and how existing tools do it (BetterTouchTool, Swish, Jitouch, AltTab, and the sidebar swipe already in `Sources/AppBundle/ui/sidebar/WorkspaceSidebarViewSwipe.swift`). Deliverable: a recommended mechanism, with its risks.

## Answer

Yes, with private API. Detect the swipes with MultitouchSupport contact frames: `MTDeviceCreateList` plus `MTRegisterContactFrameCallback`, loaded through `dlopen`/`dlsym`, the way BetterTouchTool, jitouch, and BetterCmdTab do it. Feed them into a WinMux-owned 3/4-finger up/down/left/right recognizer, and restart it on wake and hot-plug.
Observing the frames doesn't stop the system gesture. Turn off the specific conflicting swipes in System Settings (`Trackpad{Three,Four}Finger{Horiz,Vert}SwipeGesture` in `com.apple.AppleMultitouchTrackpad` and `com.apple.driver.AppleBluetoothMultitouch.trackpad`), have WinMux read them and warn, and drop the resulting scroll leak with a scroll tap that's active only while the fingers are down.
An `NSEvent` gesture tap can't stop the Dock. A session tap dropping horizontal DockSwipe events (CGS type 30, HID type 23) can suppress Space swipes, but it's undocumented, horizontal-only in the one tool that ships it, and seems to have changed on macOS 27. Keep it as an off-by-default experiment.
Main risks: private-API drift, silent death after sleep, the cost of any always-active tap (AltTab #5911), and whether MT frames need Input Monitoring on top of Accessibility (sources disagree; needs a spike).

[findings](../research/01-gesture-interception.md)
