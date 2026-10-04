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
- **A press the app accepts and then refuses**, such as an unsaved-changes sheet. The window is registered again on the next refresh, as today. The issue as reported did not check this case; check it in the live run and say what happens.
- **Closing several marked windows from a Lens.** Each is tried; the ones that closed leave the row, the ones that did not stay, and the action reports failure if any failed.

## Done when

- [ ] `winmux close --window-id <id>` on a window with no close button exits 1 with the message, and `winmux list-windows --all` lists the window before and after with the same workspace.
- [ ] `winmux close` on an ordinary window exits 0 and the window is gone, as before.
- [ ] In an open strip, `cmd-w` on a window with no close button leaves the row with the same entries and the same selection, and the window is still on screen.
- [ ] In an open strip, `cmd-w` on an ordinary window closes it, removes its entry, and the row stays a row.
- [ ] The same two results hold in the `'list` Presentation.
- [ ] A test fails without the change: a window whose close fails is still in the model and the command returned failure.
- [ ] The live run tried a window that answers the press with a sheet, and the pull request says what happened.

## Sources

- [Issue #35 as first reported](https://github.com/prateek/winmux/issues/35), found while filming the strip demos for pull request [#34](https://github.com/prateek/winmux/pull/34).
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
