# Grilling: raise the fork's minimum macOS to 26?

Type: grilling
Status: resolved

## Question

ScreenCaptureKit's one-shot window capture needs macOS 26, and `CGWindowListCreateImage` is obsoleted in the macOS 15 SDK. WinMux targets macOS 13. Should the personal fork raise its deployment target to macOS 26 (dropping the three `CGWindowListCreateImage` call sites), or gate thumbnails behind `#available` to stay closer to upstream?

## Answer

Raise the fork's deployment target to macOS 26 (Prateek, 2026-09-28). Thumbnails use ScreenCaptureKit's one-shot capture with no `#available` gating, and the three `CGWindowListCreateImage` call sites go. This was decided without waiting for the capture measurement: for a personal fork on a macOS 26 machine, upstream compatibility doesn't matter.
