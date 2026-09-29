# How WinMux sees Accessory app windows

Ticket: [02-research-accessory-app-windows](../issues/02-research-accessory-app-windows.md)
Researched 2026-09-28 against WinMux at `470eedbf` (paths relative to repo root). Apple facts come from the local macOS SDK headers (`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`), because network fetches to developer.apple.com were blocked in this session.

## Short answer

WinMux sees an Accessory app's windows **only after that app has been the frontmost app at least once** while WinMux was running. It never scans Accessory apps proactively. Once an Accessory app is registered, its windows go through the normal heuristics. A window with no close button becomes a popup: it is stored outside every workspace, so the switcher, `list-windows`, and `on-window-detected` never see it. A window that has a close button becomes floating if its subrole isn't `AXStandardWindow` (or it lacks an enabled fullscreen button), and tiled otherwise. For a Filter to match "all floating windows including Accessory app windows", WinMux needs three changes: register Accessory apps proactively, decide how popup-classified Accessory windows are exposed, and give Filters activation policy, subrole, and window level as attributes. None of those attributes are exposed today.

## 1. Activation policies (Apple)

From `AppKit.framework/Headers/NSRunningApplication.h:34-43`:

- `.regular`: "an ordinary app that appears in the Dock and may have a user interface."
- `.accessory`: "does not appear in the Dock and does not have a menu bar, but it may be activated programmatically or by clicking on one of its windows. This corresponds to LSUIElement=1 in the Info.plist."
- `.prohibited`: "may not create windows or be activated. This corresponds to LSBackgroundOnly=1."

`NSRunningApplication.activationPolicy` "is observable through KVO (the type is usually fixed, but may be changed through a call to `-[NSApplication setActivationPolicy:]`)" (`NSRunningApplication.h:86-88`). Since macOS 10.9 an app can switch to any policy at runtime (`NSApplication.h:299`). So "is this an Accessory app" is a live property, not a fixed one.

## 2. App discovery: which policies get observed

**Proactive scan, `.regular` only.** Each refresh calls `MacApp.refreshAllAndGetAliveWindowIds` (`Sources/AppBundle/layout/refresh.swift:307`). That function walks `NSWorkspace.shared.runningApplications` and registers only apps with `activationPolicy == .regular` (`Sources/AppBundle/tree/MacApp.swift:376-381`).

**Non-regular apps are refreshed only if they're already registered.** The second loop refreshes apps in `allAppsMap` whose policy is not `.regular`. The comment there reads: "We don't monitor them actively as we do for regular apps, but if a window of one of those utility apps got focused it will end up in allAppsMap" (`MacApp.swift:382-390`). Upstream AeroSpace added this in commit `9cb47ac0` ("Refresh apps with non-regular activationPolicy if their window has got focused at least once", AeroSpace issue #1292).

**The only way in is being frontmost.** The one other caller of `MacApp.getOrRegister` is `focusedApp`, which registers `NSWorkspace.shared.frontmostApplication` whatever its policy (`Sources/AppBundle/getNativeFocusedWindow.swift:8-18`). `getOrRegister` itself filters out only the lock screen and WinMux's own pid (`MacApp.swift:49-55`).

**Workspace notifications don't add coverage.** `GlobalObserver` listens for launch, activate, hide, unhide, space change, wake, and terminate, and each of these only schedules a refresh session (`Sources/AppBundle/GlobalObserver.swift:100-108`, `onNotif` at `:10-25`). An Accessory app's launch triggers a refresh, but that refresh still skips the app because it isn't `.regular`.

**Per-app AX observation starts only at registration.** `kAXWindowCreatedNotification` and `kAXFocusedWindowChangedNotification` are subscribed per app inside `getOrRegister` (`MacApp.swift:81-85`). An unregistered Accessory app's window creation produces no event WinMux can hear.

**Registration lasts until the app quits.** An app leaves `allAppsMap` only through `destroy()`, which runs when `nsApp.isTerminated` (`MacApp.swift:361-366`, `402-403`, `425-426`).

What this means in practice:

- An Accessory app whose window you've clicked (which activates the app, per the header quote above) is tracked from then on.
- Some windows never activate their app: non-activating panels, windows shown without `activate`, HUDs. If an Accessory app only ever shows windows like that, WinMux never registers it, and its windows are invisible to WinMux entirely. I haven't confirmed which NSPanel styles avoid activation in practice. That's an inference from the header text, not a test.
- After a WinMux restart, every Accessory app is forgotten until it becomes frontmost again.
- Nothing observes activation-policy changes (no KVO on `activationPolicy` anywhere in `Sources/AppBundle`). An app that turns `.regular` gets picked up by the next refresh scan. An app that goes from `.regular` to `.accessory` stays registered.

## 3. Window classification

A new window flows through `MacWindow.getOrRegister`, then `unbindAndGetBindingDataForNewWindow`, then `getAxUiElementWindowType` (`Sources/AppBundle/tree/MacWindow.swift:24-54`, `Sources/AppBundle/tree/NewWindowBinding.swift:5-12`). The result:

| `AxUiElementWindowType` | Binding target | What that means |
|---|---|---|
| `.popup` (`!isWindowHeuristic`) | global `macosPopupWindowsContainer` | Outside every workspace. `tryOnWindowDetected` skips it (`Sources/AppBundle/tree/WindowDetectedCallbacks.swift:8-9`). `participatesInWorkspaceFocus == false` (`Sources/AppBundle/tree/TreeNodeEx.swift:141-151`). `window-layout` prints `NULL-WINDOW-LAYOUT` (`Sources/AppBundle/command/format.swift:201`). |
| `.dialog` (`isDialogHeuristic`) | the workspace directly | Floating. `isFloating` is `parent is Workspace` (`Sources/AppBundle/tree/Window.swift:104`). |
| `.window` | tiling tree, or the workspace if `automaticallyTileNewWindows` is false | Tiled (`NewWindowBinding.swift:15-21`). |

Popups get a second chance: every normalize pass re-runs `isWindowHeuristic` on them and moves them into a workspace if they now pass (`Sources/AppBundle/normalizeLayoutReason.swift:12-21`).

### The Accessory-specific rule

`Sources/AppBundle/model/AxUiElementWindowType.swift:132-134`:

```swift
if activationPolicy == .accessory && get(Ax.closeButtonAttr) == nil && id != .steam {
    return false
}
```

So any Accessory app window **without a close button is a popup**. Upstream introduced this narrowly in `3a635ea6` ("Treat choose window as popup", AeroSpace issue #1560): the original version also required the app's AX title to be `"choose"`. It has since been generalized to every Accessory app. This is the only place where activation policy affects classification.

### Accessory windows that have a close button

These fall through to the same heuristics as regular apps:

- `isWindowHeuristicOld` (`AxUiElementWindowType.swift:165-193`) keeps the window if its subrole is `AXStandardWindow`, `AXDialog`, `AXFloatingWindow`, or Finder's "Quick Look". A window with any other subrole becomes a popup even with a close button, unless it's Firefox (`:136-163`).
- `isDialogHeuristic` (`AxUiElementWindowType.swift:21-94`) makes it floating if the subrole isn't `AXStandardWindow` (`:43-47`), or if it has no enabled fullscreen button (`:70-92`).

The consequence: **an Accessory app window with the `AXStandardWindow` subrole and an enabled fullscreen button gets tiled.** Those are ordinary `NSWindow`s from a menu-bar app, such as a settings or main window that opts into fullscreen. WinMux doesn't float Accessory windows by default. Most menu-bar-app windows lack a fullscreen button, so they probably land as floating, but that's an expectation, not something I measured.

### Window level

`getWindowLevel` reads `kCGWindowLayer` from `CGWindowListCopyWindowInfo` with `.optionOnScreenOnly` (`Sources/AppBundle/windowLevelCache.swift:10-35`). Layer 0 maps to `.normalWindow` and layer 3 to `.alwaysOnTopWindow` (`:42-47`). Those match `kCGNormalWindowLevel = 0` and `kCGFloatingWindowLevel = 3` in `CoreGraphics.framework/Headers/CGWindowLevel.h:67-68`. A non-normal level makes a window a popup only for a hard-coded allowlist of apps (Slack, Chrome, Firefox, Brave, Screen Studio, CleanShot X, iTerm2; `AxUiElementWindowType.swift:107-112`), and makes it a dialog only for 1Password (`:27-29`). Off-screen windows return `nil`.

## 4. Attributes available to tell windows apart

| Attribute | Source | Exposed to users today? |
|---|---|---|
| Activation policy | `NSRunningApplication.activationPolicy` (`MacApp.nsApp`) | Only in `debug-windows` (`Sources/AppBundle/command/impl/DebugWindowsCommand.swift:93`). |
| AX subrole (`AXStandardWindow`, `AXDialog`, `AXFloatingWindow`, `AXSystemDialog`, `AXSystemFloatingWindow`, ...) | `Ax.subroleAttr`; constants in `HIServices.framework/Headers/AXRoleConstants.h:414-418` | Only in `debug-windows` (AX dump). |
| Presence of close, fullscreen, zoom, and minimize buttons | `Ax.*ButtonAttr` | Only in `debug-windows`. |
| Window level (CG layer) | `getWindowLevel` | Only in `debug-windows` (`DebugWindowsCommand.swift:82`). |
| WinMux classification (tiled, floating, fullscreen, minimized, hidden-app, popup) | `getChildParentRelation` | Yes, as `window-layout` (`format.swift:193-206`). |
| App bundle id, name, pid, exec path, bundle path | `AbstractApp` | Yes (`Sources/Common/cmdArgs/impl/ListWindowsCmdArgs.swift:149-155`). |

The format variables (`ListWindowsCmdArgs.swift:134-155`) and the `on-window-detected` matcher (app id, app-name regex, title regex, workspace, startup; `WindowDetectedCallbacks.swift:31-48`) have no activation-policy, subrole, or level field.

### What the current switcher can see

`SwitcherPalette` builds its items from `workspace.allLeafWindowsRecursive` over every workspace (`Sources/AppBundle/ui/hud/SwitcherPalette.swift:155-162`), and `list-windows` does the same (`Sources/AppBundle/command/impl/ListWindowsCommand.swift:35`). The popup and minimized containers are global nodes with no workspace parent (`Sources/AppBundle/tree/MacosUnconventionalWindowsContainer.swift:18-34`), so popup-classified windows never appear in any Picker built on this path. Fullscreen and hidden-app containers are workspace children, so their windows do appear.

## 5. What a Filter matching "all floating windows, including Accessory app windows" needs

1. **Discovery.** Accessory apps have to be registered before they become frontmost. Two options:
   - (a) Register `.accessory` apps in the first loop of `refreshAllAndGetAliveWindowIds` (`MacApp.swift:378-381`). This is simple, but every menu-bar utility then gets an AX thread and subscriptions, and every refresh sends AX traffic to each of them. The per-app 1500 ms deadline (`MacApp.swift:328`) bounds a stall but doesn't remove the cost.
   - (b) Register only Accessory apps that own an on-screen layer-0 window according to `CGWindowListCopyWindowInfo`. `getWindowLevel` already runs that query, but it discards the owner pid. This costs less, but it misses windows that are off-screen at scan time.
   - Either way, adding KVO on `activationPolicy` or a `didActivate` hook would handle apps that switch policy.
2. **Classification.** Decide what happens to Accessory windows without a close button, which are currently popups and invisible:
   - Keep them hidden. Many are genuine popovers or HUDs, which is why upstream added the rule.
   - Or give the Picker its own window source that includes `macosPopupWindowsContainer`, so a Filter can opt in (for example with `window.type == "popup"`).

   Separately, decide whether Accessory windows that currently get tiled (`AXStandardWindow` with an enabled fullscreen button) should float by default in this fork. A one-line rule in `isDialogHeuristic` would do it.
3. **Filter attributes.** Expose at least `app.activationPolicy` (`regular`, `accessory`, `prohibited`), `window.subrole`, `window.level` (a CG layer int or a named level), `window.hasCloseButton`, and the WinMux classification (`tiled`, `floating`, `fullscreen`, `minimized`, `hiddenApp`, `popup`). Then "all floating windows" can be written as `layout == floating || (app.activationPolicy == accessory && ...)` without baking a policy into the model. The filter-language prototype ticket owns the syntax.
4. **"Floating" needs a definition in the glossary.** Today it means "parent is a workspace" (`Window.swift:104`). With that definition, popups and windows WinMux never discovered don't count as floating. "Can't find floating windows" likely covers all three cases: unregistered, popup, and floating-but-hidden-behind-tiles. Worth deciding with Prateek which of those "floating" includes.

## 6. Ghost Pepper, observed locally (read-only)

- `lsappinfo list` shows `"Ghost Pepper"`, bundle id `com.github.matthartman.ghostpepper`, at `/Applications/GhostPepper.app`, `type="UIElement"`, which is an Accessory app.
- `Info.plist` has `LSUIElement = true` and `CFBundleShortVersionString = 2.4.4`.
- System Events reports the process as `background only = true`, `visible = false`, with no AX windows at the moment of checking.
- The CG window list shows six layer-0 windows and one layer-3 window for its pid (47333). All are unnamed, and none has `kCGWindowIsOnscreen` set. These are probably ordered-out or hidden windows, not something on screen right now.
- I couldn't confirm what Ghost Pepper does, because the network was blocked. The bundle id points at `github.com/matthartman/ghostpepper`. I believe that's a speech-to-text menu-bar utility, not an IDE tool as the ticket says, but that's unverified.
- WinMux and AeroSpace weren't running, so I couldn't check live how WinMux classifies it. **Verification step:** with WinMux running and a Ghost Pepper window visible, click the window, then run `winmux debug-windows` for it. That shows activation policy, subrole, buttons, and level. Separately, check whether the window shows up in `winmux list-windows --all` before and after clicking it. That would confirm or refute the "only after frontmost" claim for this app.

## Uncertainties

- I haven't tested whether particular Accessory windows appear without the app becoming frontmost. The discovery claim comes from code reading (sections 2 and 5).
- The comment in `AxUiElementWindowType.swift:18` says the heuristics are "Covered by tests in ./axDumps", but this repo has no `axDumps/` directory and no test calls `isWindowHeuristic`. Either the coverage was dropped in the fork or it lives elsewhere. I didn't chase it further.
- AX roles and subroles for NSPanel variants come from general knowledge, not a header: `AXFloatingWindow` for utility panels, `AXSystemDialog` for system alerts. Live dumps would settle this.
