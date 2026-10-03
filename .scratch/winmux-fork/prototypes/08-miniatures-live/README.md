# Owned thumbnail benchmark

Compile `neutral-demo.swift` into an AppKit app bundle with executable and name `NeutralDemo`.
The app creates 50 distinct neutral windows with clocks. Its command file is
`/tmp/winmux9-demo/command`; `fullscreen 1`, `raise 1`, `minimize 1`, `keep 6`, `hide` and `quit`
operate only on those windows. Create the command directory before launch.

Compile the capture harness with:

```sh
swiftc -O -parse-as-library -framework ScreenCaptureKit -framework AppKit capture-cost.swift -o /tmp/capture-cost
/tmp/capture-cost bench
```

It captures only layer-zero windows owned by the `NeutralDemo` application, using
`SCScreenshotManager.captureScreenshot`. It needs an existing Screen Recording grant and never
requests one. Wait for all 50 windows to be created before launching the harness. No repeat
factor is needed; check that the output reports 50 windows. The harness measures the first
capture after process launch, then three serial and bounded-pair runs at 320 px and native size.
It does not start WinMux or inspect other windows' pixels. Follow the handoff's privacy and
frame-restoration instructions for a desktop-wide Lens run.
