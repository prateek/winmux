# Close a window from its WinMux tab

Part of {{UMBRELLA}}.

## What to build

A tab in a WinMux tab group has no way to close its window with the pointer.

Each tab gets a close button, and closing several in a row works as it does in Chrome.

## Decisions

- **The button closes the window**, as its red button would. Prateek: "close the window (whatever clicking the red x in osx would do to it)".
- **After a close by pointer, the remaining tabs keep their width until the pointer leaves the strip**, so the next tab's button is already under the pointer. They then animate to their new widths.

## Not in this issue

- Taking a window out of a group without closing it.
- The controls at the right of the strip. They are in **Prototype: the tab strip above apps that have tabs of their own**.

## Depends on

Nothing.

## Defaults chosen for you

- **The button shows on the hovered tab and on the active tab.**
- **Middle-click on a tab closes it too.**
- **A window that refuses to close**, for an unsaved document, keeps its tab.

## Done when

- [x] Clicking a tab's button closes that window and no other.
- [x] Three clicks without moving the pointer close three windows, in a guest.
- [x] A window with an unsaved-changes sheet keeps its tab.
- [ ] The pull request has a clip of the three closes.

## Built

The trailing `xmark` appears on the active and hovered tabs, outside the tab's focus button and drag gestures. It has a 20-point circular hit area and the accessibility label `Close <title>`. Middle-button release uses the view's published tab frames, clipped to its scroll viewport; the gutter closes nothing, including when a tab's frame extends off screen.

`Window.requestClose` shares project deletion's press-and-confirm implementation. A tab close presses without unregistering, waits up to one second with 100 ms checks, and stops waiting as soon as AX reports a sheet. The press, collection/strip update and retained-window focus use separate light sessions; the poll holds none. Project deletion retains its 1.5-second wait and caller-owned session. CLI, agent and Lens closes retain their accepted-press behavior, including the separate defect **A window that answers `close` with a save sheet drops out of WinMux until the sheet is dismissed**.

An observable model outside the view retains closing ids and strip widths across panel root-view replacements. A closing tab stays present at 55% opacity and accepts no clicks or drags; another close cannot press again. A refused window or a window showing a sheet keeps its index and comes forward. Successful background closes preserve focus even when a refresh collects the window before the poll. Closing the active tab uses the existing most-recent replacement. A pointer close holds widths until the pointer leaves the strip or the panel disappears; the layout, drag hit tests and reorder offsets share that width. Re-widening uses the strip's normal or Reduce Motion animation. The default normalization still dissolves a group left with one window.

Fourteen new behavior tests cover confirmation, sheets, timeout, retained bindings, targeting, both focus outcomes, repeated close suppression, width holding/release, three fixed-position closes, panel removal and clipped hit-testing. Existing project-deletion, CLI, agent, Lens and width tests pass unchanged. Host and pinned-version guest `make check` pass: 1,591 Swift tests, 92 Rust/helper tests and 171 Python tests.

The 1280 × 720 standing-desk run adds Ghostty windows to make five tabs. One inactive-button close removes only its target and preserves focus. Three clicks at one point close three windows, leave two tabs at their held width, and moving out re-widens them. Middle-click targets its window and ignores the overflow gutter. An unsaved TextEdit document stays at its index with its save sheet visible and focused, both from the background and while active; Cancel leaves it managed. One script produces identical ordinary/no-button CLI close results on the base and feature trees. Reproduction tools are in `../proofs/close-tab/`; pull-request media is supplied by the demo pass.

## Checks needing the installed build or hardware

- [ ] Installed-build behavior with a real mouse or trackpad, including a real middle button.
- [ ] A save sheet from an app other than TextEdit.

## Sources

- Prateek, 2026-10-07: "winmux tabs should have the controls to be able to close a window — make it spiffy like chrome where the tabs take the same space and animate to make the next windows close button be where the mouse already".
