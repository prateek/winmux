# WinMux crashes on unbounded recursion while releasing objects, and does not relaunch

Part of {{UMBRELLA}}.

## What to build

WinMux 0.5.6-dogfood.66 (build 1954, arm64) crashed twice in 25 minutes on Prateek's laptop, the same way each time: `EXC_BAD_ACCESS (SIGSEGV)`, "Thread stack size exceeded due to excessive recursion", on the main thread. The faulting stack is a release chain: `swift_release_dealloc` → `doDecrementSlow` → a WinMux deinit at `0x3deb98`/`0x3dec08` → … → a frame at `0x228a40` repeated at least six times, entered from `0x22a584` and ultimately from an async Task (`completeTaskWithClosure`). The report keeps only 22 frames, so the true depth is unknown. It looks like a long linked structure whose deinit releases the next node recursively. The release ships no dSYM, so the offsets cannot be symbolicated from the installed build.

Both crashes came about two seconds after a ScreenCaptureKit screenshot (`SCScreenshotManager captureScreenshotWithFilter`) in the unified log, probably a Lens thumbnail capture. Cmd-Tab was bound to `lens recent` at the time. That is the only lead.

The crash is a hard kill, so WinMux kept the native Cmd-Tab pair (symbolic hotkeys 1 and 2) disabled until it was relaunched, as `docs/default-config.md` says. WinMux does not relaunch itself after a crash, so the system switcher stays dead until the user notices and relaunches it.

The reporting half this issue first carried, dSYMs per release, an opt-in `winmux report` and a prefilled GitHub issue, moved to **Crash and bug reports that are easy to send and easy to read**, #106, on 2026-10-20. This issue keeps the crash and adds the relaunch.

## Decisions

- **Find the recursion and make the release iterative**, using the offsets above against the dogfood.66 dSYM rebuilt from `3b76a45`, or by reproducing with Lens openings under the debugger.
- **WinMux relaunches after a crash**, through a launch agent with `KeepAlive` on crash, so held system shortcuts come back without the user acting. A relaunch within a minute of the previous one does not relaunch again, so a crash at startup cannot loop.

## Questions

None open. Where dSYMs live is answered in #106: public release assets.

## Done when

- [ ] Neither crash signature reproduces, and a test covers releasing a long chain of the structure without recursion.
- [ ] In a guest with the Cmd-Tab opt-in on, a forced crash relaunches WinMux once, the relaunch repairs the symbolic hotkeys and takes the chords again, and Cmd-Tab opens the Lens.
- [ ] In a guest with the opt-in off, the same crash relaunches once and the system's Cmd-Tab is live.
- [ ] A second forced crash within a minute does not relaunch, and the log says why.

## Sources

- Two crash reports on the installed dogfood.66, 2026-10-19 14:58 and 15:23 local time; binary UUID `F5273DF9-AC39-30F8-9733-A72E28DB8F2A` (arm64).
- Native Cmd-Tab was restored by relaunching WinMux with the Cmd-Tab bindings removed; the `WinMux.symbolicHotkeyMarker.v1` default cleared on launch.
