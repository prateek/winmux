# `close` reports success on a window with no close button, and the strip drops its entry

Part of {{UMBRELLA}}.

## What to build

`close` on a window that has no close button returns success and closes nothing. In an open strip, `cmd-w` on such a window removes its entry from the row while the window stays on screen. This issue makes `close` report what happened: it fails when the window cannot be closed, the window stays in WinMux's model, and a Lens keeps its entry.

**Reproduce**

1. Open a titled window with no close button (an `NSWindow` whose style mask is `[.titled]`), with a debug build running on the shipped defaults.
2. Hold cmd, tap tab until the window is selected, press `w`, release cmd.

Seen: the row goes from five entries to four, and the selection moves on. The window is still on screen, and `winmux list-windows --all` still lists it afterwards. `winmux close --window-id <id>` has the same shape: exit 0, window still open. The window is registered again on a later refresh.

It is easy to miss by eye: if another window is focused next, the unclosed window can end up behind it and look closed.

**Where it comes from**

- `MacWindow.closeAxWindow` (`Sources/AppBundle/tree/MacWindow.swift`) calls `garbageCollect` first, so the window leaves WinMux's model before anything is tried.
- `MacApp.closeAndUnregisterAxWindow` (`Sources/AppBundle/tree/MacApp.swift`) returns silently when the window has no `AXCloseButton`, and when the press fails.
- `CloseCommand.run` (`Sources/AppBundle/command/impl/CloseCommand.swift`) returns `true` after `closeAxWindow()` whatever happened, so the Lens treats the close as done and drops the entry.

## Decisions

- A window that cannot be closed is not closed some other way. `close` does not fall back to quitting the app, hiding the window or minimizing it.
- When the window has no close button, or pressing it fails, `close` fails: it prints the reason on stderr and exits 1. The window stays in WinMux's model, bound where it was: nothing is garbage collected.
- A Lens whose `close` action failed keeps the entry and the selection. The strip stays a strip.
- A press the app accepts counts as a close. The window leaves the model at once, as it does today, so the layout does not wait on the app.
- `close --quit-if-last-window` keeps its behaviour.

## Not in this issue

- Any change to which windows a Lens lists. A window with no close button stays eligible.
- A visible notice in the Lens for a failed action. A failed Lens action is already written to the unified log, category `lens`; this issue adds nothing on screen.
- **Accessory window defaults and the `floating` Lens** covers how close-button-less dialogs are classified.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The seam.** `MacApp.pressCloseButton` already presses the button and returns whether the press succeeded. `closeAxWindow` becomes a call that reports its result, and garbage collection follows a successful press instead of preceding the attempt.
- **The other callers.** `AgentOperationApply` and `WorkspaceProjects` also call `closeAxWindow`. They get the same rule: a window that could not be closed stays in the model. Whether each reports the failure is the builder's call.
- **The message.** `Can't close '<app name>': the window has no close button`, and `Can't close '<app name>': the app refused` for a failed press.
- **A press the app accepts and then refuses**, such as an unsaved-changes sheet. The accepted press still removes the window immediately. The TextEdit live run, compared with the base build, found two outcomes: the held strip removed the entry and kept one row while the model re-registered the document on the same workspace by the readback about 1.4 seconds later; CLI close left it absent from the model while the sheet was open, and Cancel returned it on the same workspace. The open strip did not re-add the entry. This issue preserves that behavior; the CLI sheet case is **A window that answers `close` with a save sheet drops out of WinMux until the sheet is dismissed**.
- **Closing several marked windows from a Lens.** Each is tried; the ones that closed leave the row, the ones that did not stay, and the action reports failure if any failed.

## Done when

- [x] `winmux close --window-id <id>` on a window with no close button exits 1 with the message, and `winmux list-windows --all` lists the window before and after with the same workspace.
- [x] `winmux close` on an ordinary window exits 0 and the window is gone, as before.
- [x] In an open strip, `cmd-w` on a window with no close button leaves the row with the same entries and the same selection, and the window is still on screen.
- [x] In an open strip, `cmd-w` on an ordinary window closes it, removes its entry, and the row stays a row.
- [x] The same two results hold in the `'list` Presentation.
- [x] A test fails without the change: a window whose close fails is still in the model and the command returned failure.
- [x] The live run tried a window that answers the press with a sheet, and the pull request says what happened.

## Built behavior and checks

`Window.closeAxWindow()` is async and returns closed or a reason. `MacWindow` presses first, unregisters its AX window only after success, then garbage collects with the closed-windows cache skipped. Project deletion shares the press but retains its existing wait for disappearance. The fire-and-forget close is removed. Agent apply awaits the result and leaves failed targets bound; it keeps the apply API's existing silent-failure behavior. The non-native project-deletion path awaits and checks whether a workspace remains.

A disabled AX close button counts as no close button; unreadable `AXEnabled` still permits a press. A window that is already gone (missing from the app's AX map, or `.invalidUIElement` from the lookup or the press) counts as closed and is collected, as before. A failed or timed-out close-button lookup or a rejected press reports that the app refused; the button gets the same 1-second AX timeout as its window. A read-only server presses nothing and every caller gets `WinMux is read-only` as the reason; the quit-if-last-window branch is unchanged, read-only included. `close-all-windows-but-current` and a marked Lens close skip a window an earlier close in the same command already took with it. CLI help states exit 1.

Host and pinned-toolchain guest `make check` pass (1,266 Swift, 82 helper and 131 Python tests). Command regressions were red before result handling; the disabled-button regression was red before the enabled guard. Tests cover both messages, exact parent/order/workspace retention, successful removal, marked targets in every Presentation, close-all continuation, read-only, and agent/project routing. Native CLI, held strip and held list checks cover both absent and explicitly disabled buttons and ordinary closes. The unified `lens` log contains the failure reason. The same ordinary-close and quit-if-last-window script passes on base and fixed builds; both sheet paths were also compared with the base. No Lens code or keys changed. Installed-build and physical-device checks are outside this issue's builder run.

## Sources

- [Issue #35 as first reported](https://github.com/prateek/winmux/issues/35), found while filming the strip demos for pull request [#34](https://github.com/prateek/winmux/pull/34).
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
