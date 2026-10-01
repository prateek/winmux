# Raise the deployment target to macOS 26

Part of {{UMBRELLA}}.

## What to build

Raise the fork's minimum macOS from 13 to 26 and remove every use of `CGWindowListCreateImage`. After this, code in the fork can call macOS 26 APIs, ScreenCaptureKit's one-shot window capture in particular, without `#available` checks.

## Decisions

- **Target.** The deployment target is macOS 26 for every product. It is set in two places today: `platforms` in `Package.swift` (now `.macOS(.v13)`) and `deploymentTarget` in `project.yml` (now `"13.0"`). Both change, and the comment above `platforms` in `Package.swift` is updated to match.
- **No availability gating.** New code does not wrap macOS 26 APIs in `#available`. Existing checks for macOS 14 and macOS 26 become dead once the target rises and are removed with their fallback branches. They are in `Sources/AppBundle/ui/menubar/MenuBarLabel.swift`, `Sources/WindowCapture/main.swift`, `Sources/AppBundle/ui/core/DesignTokens.swift`, `Sources/AppBundle/ui/tabs/WindowTabStripConstants.swift`, `Sources/AppBundle/ui/tabs/WindowTabGroupGeometry.swift` and `Sources/AppBundle/ui/sidebar/WorkspaceSidebarWorkspaceSection.swift`. The `@available(*, unavailable)` initialisers are unrelated and stay.
- **`CGWindowListCreateImage` goes.** The function is deprecated in the macOS 14 SDK and obsoleted in the macOS 15 SDK, so it does not compile at the new target. The code has five call sites, and all five go. The deployment-target ticket under Sources counts three; `rg CGWindowListCreateImage Sources` finds these five, and this list is the one to work from:
  - `Sources/AppBundle/ui/tabs/DoubleSidedWindowController.swift`, two calls: a single-window snapshot, and a capture of the screen region below a window (`.optionOnScreenBelowWindow`) used as the flip animation's background.
  - `Sources/AppBundle/ui/tabs/WindowTabsPanel.swift`: a single-window capture used to estimate a window's corner radius.
  - `Sources/AppBundle/ui/marketing/WinMuxMarketingRenderer.swift`: a capture of the renderer's own window.
  - `Sources/WindowCapture/main.swift`: the `--core-graphics` path of the dev-only capture tool.
- **Replacement API.** Window capture uses ScreenCaptureKit's one-shot capture, `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)`, which is macOS 26 only. Do not use `captureSampleBuffer` for ordinary windows: it creates and tears down a stream per call. Do not use the private `CGSHWCaptureWindowList`. "Thumbnail cache and the `'miniatures` Presentation" uses the same call.
- **Facts about the replacement that affect the call sites.** `SCContentFilter(desktopIndependentWindow:)` takes an `SCWindow`, not a `CGWindowID`. `SCWindow`s come from `SCShareableContent`, and that fetch costs about 30 ms, so cache it. The one-shot capture is asynchronous, while the current calls are synchronous and run on the main thread. A capture takes about 33 ms. `SCScreenshotConfiguration`'s default `width` and `height` are the window's size in points, not in native pixels, so a caller that wants native resolution sets both from the window's backing scale.
- **Upstream compatibility is not a constraint.** This is a personal fork running on macOS 26.

## Not in this issue

- The thumbnail cache and capture scheduling for Lenses: "Thumbnail cache and the `'miniatures` Presentation".

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The single-window call sites.** Three become a one-shot capture of that window's `SCWindow`: the flip animation's snapshot, the marketing renderer's capture of its own window, and the capture tool. The fourth, the corner-radius capture, is deleted (see below). `WindowScreenshot` in `Sources/AppBundle/util/` holds the call and the `SCWindow` cache for the app; its caller passes the output size in pixels.
- **The flip animation's background.** Dropped. The flip animates the two window snapshots with nothing captured behind them. A single-window filter cannot capture the screen below a window, and a display capture that excludes windows would put a `SCShareableContent` fetch on an animation path. Today `flip` skips the animation when the background capture returns nil (`DoubleSidedWindowController.swift`), so `animate` has to stop requiring a background.
- **`winmux-window-capture`.** The `--core-graphics` flag and its code path are removed. The tool's ScreenCaptureKit path stays and moves from `SCScreenshotManager.captureImage` to the Replacement API above, so the fork has one capture call.
- **`winmux-marketing-renderer`.** Its capture of its own window is ported to the same one-shot call.
- **The corner-radius estimate.** Deleted, with its capture. On macOS 26 `windowTabGroupAppCornerRadius` returns the system window corner radius and reaches `estimatedWindowPreviewCornerRadius(for:)` only from the pre-26 fallback branch, which goes under "No availability gating". Nothing else calls the estimate.
- **The flip.** `flip` awaits its two snapshots before it starts the animation, and ignores a second flip while it waits.
- **Deprecations the new target surfaces.** Fix only the ones that fail the Release build, which treats warnings as errors for the app target (`Sources/WinMuxApp`). The rest (`onChange(of:perform:)`, `CVDisplayLink`, `activateIgnoringOtherApps`) are left for later.

## Done when

- [x] `Package.swift` and `project.yml` both declare macOS 26 as the minimum.
- [x] `rg CGWindowListCreateImage Sources` returns nothing.
- [x] `rg '#available\(macOS' Sources` returns nothing.
- [x] `swift build` and the release Xcode build succeed with no deprecation or obsoletion warnings from window capture.
- [x] The existing test suite passes.
- [x] The release app bundle declares macOS 26.0 as its minimum system version (`LSMinimumSystemVersion` in the built `Info.plist`).
- [ ] With Screen Recording granted on macOS 26, the double-sided tab flip animates between the two window snapshots. Not yet checked: it needs a running WinMux build that holds the grant.
- [x] `rg 'estimatedWindowPreviewCornerRadius|estimateTopCornerRadius' Sources` returns nothing, and no capture blocks the main thread.
- [x] `winmux-window-capture` has no `--core-graphics` flag and still writes a capture of the requested window.
- [x] `winmux-marketing-renderer` still writes its image.

## Sources

- [Grilling: raise the fork's minimum macOS to 26?](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/15-grilling-deployment-target.md)
- [Research: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md)
- [Task: measure thumbnail capture](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/14-task-measure-thumbnail-capture.md)
