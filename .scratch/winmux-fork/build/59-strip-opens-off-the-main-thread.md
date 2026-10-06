# The strip opens off the main thread in a release build, and WinMux crashes

Part of {{UMBRELLA}}.

## What to build

Holding Cmd-Tab on `0.5.6-dogfood.12` kills WinMux. The crash is `EXC_BREAKPOINT`, "Must only be used from the main thread", on a thread of Swift's cooperative pool, inside `-[NSWindow _doOrderWindow:]`. The frames above it are `SwitcherPalettePanel.show`, `LensLifecycle.presented` and the strip's display-delay task in `LensLifecycle.complete`. A tap released inside the 100 ms delay never shows the strip and survives; any hold past it crashes. Only `.12` was run; the code is the same in every release since the strip landed, so they are presumed to crash too.

The delay task is `@MainActor` and awaits `StripGesture.waitForDisplay`, a stored closure typed `@Sendable () async throws -> Void`. `AppBundle` turns on `NonisolatedNonsendingByDefault`, so that type means "runs on the caller's actor", and the caller does not hop back after the call because the callee promised to return there. The closure is written inside the generic `StripGesture.start(on:)` and captures its clock. The release is built optimised with Swift 6.3.3, and that compiler loses the hop back to the caller's actor in exactly this shape: a caller-isolated async closure formed in a generic context that captures a generic value. The task then carries on wherever the clock's sleep resumed it. It happens for a gesture made inside `AppBundle`, as the hotkey handler makes it, and not for one made from another module; that the compiler's specialisation of the generic function is what drops the hop is a guess.

CI and the guest build with Swift 6.2.4, unoptimised, where the closure returns to the main actor. No check runs on the compiler that builds what is installed.

## Decisions

- **The wait says which actor it runs on.** `waitForDisplay` is `@MainActor`: its one caller is the lifecycle, and an isolation written in the type does not depend on the callee finding its way back. The 100 ms deadline and the lifecycle's ownership of the task stay as they are.
- **No hop at the crash site.** `DispatchQueue.main.async` in `show` would hide a lifecycle that is running off its actor, with every guard before it already read from the wrong thread.
- **The regression check is a release build in a guest.** A test that makes its gesture in the test module passes with and without the fix, optimised or not: the wait returns to the main actor on that path. A model of the two modules shows the same split, and loses the hop only when the gesture is made inside the library. `AppBundle` makes a gesture in two places, the Carbon hotkey handler and `lens` run with the invoking modifiers physically held, and a test can drive neither; a seam added for the test alone was not built. `make check` is unoptimised and would not run such a test anyway.
- **The rule for new code**, until the toolchains are one: an async closure made inside a generic function, a function with a `some` parameter, a protocol extension or a method of a generic type, and stored or returned, names its isolation (`@MainActor`, another global actor, or `@concurrent`).

## What was looked at

A standalone file with each shape, compiled with Swift 6.3.3 and 6.2.4, optimised and not, with and without the feature. Only Swift 6.3.3 `-O` loses the hop, and only for the shape above; writing `nonisolated(nonsending)` on the type loses it without the feature flag too.

- **Affected:** `StripGesture.waitForDisplay`. It is the only async closure in `AppBundle` formed in a generic context without an isolation of its own.
- **Not affected.** Each verdict is from a model of the site's shape in one optimised file, seen to return to the main thread, not from the app's own code. The release build then ran the thumbnail loop and a strip-to-list conversion in the guest without a crash:
  - `LensLifecycle`'s thumbnail loop, which sleeps on an `any Clock` inside a `@MainActor` task.
  - `LensInlineSearch`, whose debounce and display deadline sleep on an `any Clock` from main-actor tasks, and whose `Evaluate` is `@MainActor`.
  - `LensLifecycle`'s landing task, which awaits another task's value and `ColumnPolicy.decision`.
  - `ThumbnailCache`'s stored `capture` closure, which is caller-isolated but not formed in a generic context.
  - `ConfigReloadScheduler`, which uses `Task.sleep` and a `@MainActor` closure.
  - The generic async functions: `Thread.runInLoop`, `runLightSession`, `RefreshingSnapshot.refresh` and `DoubleSidedWindowController.firstResult`. Their closures are not stored, or carry an actor.

## Not in this issue

- Building and testing with the compiler that builds the release. That is **One pinned toolchain for CI, the guest and the release**, and this crash is the case for taking it early.
- Reporting the compiler defect to Swift.

## Depends on

Nothing.

## Done when

- [x] A release build holds Cmd-Tab in a guest without crashing: ten holds past the delay, letters during a hold, Escape, and a quick tap, with no crash report and `winmux debug-lens-trace` reading back the openings.
- [x] `0.5.6-dogfood.12` is seen to crash the same way in the same guest, with the same frames as the report from Prateek's machine.
- [x] The pull request says whether a unit test can catch it, and if none can, why.
- [x] `make check` passes on the host and in the guest.
- [ ] Prateek holds Cmd-Tab on the installed release that carries the fix.

## Sources

- The crash report from Prateek's machine on `0.5.6-dogfood.12`, 2026-10-06, and the guest's report of the same crash.
- Pull requests [#80](https://github.com/prateek/winmux/pull/80) and [#81](https://github.com/prateek/winmux/pull/81), which built the lifecycle and the Hold.
