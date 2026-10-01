# Raise the deployment target to macOS 26

Part of {{UMBRELLA}}.

## What to build

Raise the fork's minimum macOS from 13 to 26 and remove every use of `CGWindowListCreateImage`. After this, code in the fork can call macOS 26 APIs, ScreenCaptureKit's one-shot window capture in particular, without `#available` checks.

## Decisions

- **Target.** The deployment target is macOS 26 for every product. It is set in two places today: `platforms` in `Package.swift` (now `.macOS(.v13)`) and `deploymentTarget` in `project.yml` (now `"13.0"`). Both change, and the comment above `platforms` in `Package.swift` is updated to match.
- **No availability gating.** New code does not wrap macOS 26 APIs in `#available`. Existing checks for macOS 14 and macOS 26 become dead once the target rises and are removed with their fallback branches. They are in `Sources/AppBundle/ui/menubar/MenuBarLabel.swift`, `Sources/WindowCapture/main.swift`, `Sources/AppBundle/ui/core/DesignTokens.swift`, `Sources/AppBundle/ui/tabs/WindowTabStripConstants.swift`, `Sources/AppBundle/ui/tabs/WindowTabGroupGeometry.swift` and `Sources/AppBundle/ui/sidebar/WorkspaceSidebarWorkspaceSection.swift`. The `@available(*, unavailable)` initialisers are unrelated and stay.
- **`CGWindowListCreateImage` goes.** The function is deprecated in the macOS 14 SDK and obsoleted in the macOS 15 SDK, so it does not compile at the new target. The code has five call sites, and all five go:
  - `Sources/AppBundle/ui/tabs/DoubleSidedWindowController.swift`, two calls: a single-window snapshot, and a capture of the screen region below a window (`.optionOnScreenBelowWindow`) used as the flip animation's background.
  - `Sources/AppBundle/ui/tabs/WindowTabsPanel.swift`: a single-window capture used to estimate a window's corner radius.
  - `Sources/AppBundle/ui/marketing/WinMuxMarketingRenderer.swift`: a capture of the renderer's own window.
  - `Sources/WindowCapture/main.swift`: the `--core-graphics` path of the dev-only capture tool.
- **Replacement API.** Window capture uses ScreenCaptureKit's one-shot capture, `SCScreenshotManager.captureScreenshot(contentFilter:configuration:)`, which is macOS 26 only. Do not use `captureSampleBuffer` for ordinary windows: it creates and tears down a stream per call. Do not use the private `CGSHWCaptureWindowList`.
- **Facts about the replacement that affect the call sites.** `SCContentFilter(desktopIndependentWindow:)` takes an `SCWindow`, not a `CGWindowID`. `SCWindow`s come from `SCShareableContent`, and that fetch costs about 30 ms, so cache it. The one-shot capture is asynchronous, while the current calls are synchronous and run on the main thread. A capture takes about 33 ms.
- **Upstream compatibility is not a constraint.** This is a personal fork running on macOS 26.

## Not in this issue

- The thumbnail cache and capture scheduling for Lenses: "Thumbnail cache and the `'miniatures` Presentation".

## Depends on

Nothing.

## Open details

- The decision says the `CGWindowListCreateImage` call sites go and that capture is ScreenCaptureKit one-shot. It does not say what each call site becomes. Four are single-window captures with a direct one-shot equivalent. The fifth captures everything on screen below a window, which a single-window filter cannot do; settle whether it becomes a display capture that excludes windows, or whether the flip animation drops its background.
- The two dev tools (`winmux-window-capture` and `winmux-marketing-renderer`) are not part of the fork's features. Settle whether to port their capture paths or remove the `--core-graphics` path and leave the ScreenCaptureKit one.
- The synchronous callers (`estimateWindowPreviewCornerRadiusFromImage`, the flip animation) need an async shape or a cached result. Settle which per call site.

## Done when

- [ ] `Package.swift` and `project.yml` both declare macOS 26 as the minimum.
- [ ] `rg CGWindowListCreateImage Sources` returns nothing.
- [ ] `rg '#available\(macOS' Sources` returns nothing.
- [ ] `swift build` and the release Xcode build succeed with no deprecation or obsoletion warnings from window capture.
- [ ] The existing test suite passes.
- [ ] The release app bundle declares macOS 26.0 as its minimum system version (`LSMinimumSystemVersion` in the built `Info.plist`).
- [ ] The double-sided tab flip and the tab preview corner radius still work on macOS 26 with Screen Recording granted, or the PR states what replaced them.

## Sources

- [Grilling: raise the fork's minimum macOS to 26?](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/15-grilling-deployment-target.md)
- [Research: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md)
- [Task: measure thumbnail capture](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/14-task-measure-thumbnail-capture.md)
