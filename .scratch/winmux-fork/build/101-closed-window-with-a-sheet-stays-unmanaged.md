# A window that answers `close` with a save sheet drops out of WinMux until the sheet is dismissed

Part of {{UMBRELLA}}.

## What to build

`winmux close` on a document window with unsaved changes exits 0, and the app answers the press with its "Do you want to save" sheet. The window stays on screen with the sheet on it, but WinMux has already dropped it: `winmux list-windows --all` leaves it out for as long as the sheet is open, a minute and more in the runs below, and a Lens cannot show it. Cancel brings it back, on the same workspace, at the next readback.

**Reproduce** (in a guest; seen on the base build and after **`close` reports success on a window with no close button, and the strip drops its entry**)

1. Turn on TextEdit's per-app `NSCloseAlwaysConfirmsChanges`, open TextEdit, give it an untitled document and type into it. Without the preference, TextEdit autosaves and closes with no sheet.
2. `winmux close --window-id <id>` on that window: exit 0, empty stderr, and the sheet opens.
3. `winmux list-windows --all` a few times over the next minute: the document is missing every time. Raising TextEdit does not bring it back.
4. Cancel the sheet: the document is listed again on the workspace it was on.

The same press from Cmd-W in a held strip behaves differently: the document is back in `list-windows --all` within about 1.3 seconds, on its workspace, while the sheet is still open. What brings it back there and not after the CLI close has not been found.

**Where it comes from.** An accepted press removes the window from WinMux's model and from the app's AX window map at once (`MacWindow.closeAxWindow`, `MacApp.pressCloseButton` with `unregisterOnSuccess`). That is settled: the layout does not wait on the app. A window still on screen after it is meant to be registered again by the next refresh, and after the CLI close it is not.

## Decisions

- An accepted press still counts as closed, and the window still leaves the model at once. This issue does not make `close` wait for the window to go.
- A window that is still on screen after an accepted press is back in WinMux's model, on the workspace it left, by the next refresh, from the CLI, a Lens or any other caller alike.

## Not in this issue

- Re-adding the window to a Lens that is already open. An open Lens keeps the entries it has.

## Depends on

**`close` reports success on a window with no close button, and the strip drops its entry**.

## Done when

- [ ] After `winmux close` on a TextEdit document that answers with a save sheet, `winmux list-windows --all` lists it again on the same workspace within two seconds, while the sheet is still open.
- [ ] The Cmd-W path in a held strip still behaves as it does today.
- [ ] A test fails without the change.

## Sources

- The live run of **`close` reports success on a window with no close button, and the strip drops its entry**, which compared the base build and the fix on both paths.
