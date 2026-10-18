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

An observable model outside the view retains closing ids and strip widths across panel root-view replacements. A closing tab stays present at 55% opacity and accepts no clicks or drags; another close cannot press again. A detected sheet keeps its tab at its index and brings it forward. A timeout or refused press restores normal opacity and input without moving focus. Confirmation distinguishes disappearance, sheet, timeout and refused press; project deletion accepts only disappearance.

Background-close intent is recorded at the click, separately from the closing appearance. It survives a timeout for five seconds from the click, until collection consumes it; a refused press or a sheet clears it. Collection skips replacement only for a background-at-click window that is still unfocused. An active-at-click window, including an active retry after a background timeout, uses the existing most-recent replacement even if native focus drifts before collection. `MacWindow` and the test double share `Window.unbindAndFocusAfterClosure`.

A pointer close holds the tab width, with the strip's width and tab count, across content replacement. Each time the tab frames change, hover goes to the tab under the live pointer, read from the panel, so the next tab's button appears under a still pointer, after a scroll or a moved panel too. Strip exit, panel disappearance, resize or tab growth clears the hold; a later close revalidates it before retaining the first width. Layout, drag hit tests and reorder offsets share the held width. The close overlay moves with its tab and the reorder/re-entry animations wrap the offset again. A title fades out under a visible close button instead of reflowing, and keeps its full width when the button is hidden. Re-widening uses the strip's normal or Reduce Motion animation. The default normalization still dissolves a group left with one window. The light sessions own their tab-model updates and post-refreshes; the close path adds no duplicate updates or trailing refresh.

The 25 tab-close/confirmation behavior tests cover confirmation, sheets, timeout/refusal, retained bindings, targeting, focus drift, focused retry, late collection, repeated close suppression, live-pointer hover, background-close expiry, hold invalidation and sub-point tolerance, title fade, refresh scheduling, panel removal and clipped hit-testing. Final review regressions were seen failing with their fixes removed; reorder animation is covered by a recorded before/after visual check, and discardable-result by a standalone compiler check. Existing project-deletion, CLI, agent, Lens and width tests pass. Host and pinned-version guest `make check` pass: 1,600 Swift tests, 92 Rust/helper tests and 171 Python tests, with the guest's working-copy commit test skipped.

The final 1280 × 720 standing-desk run adds Ghostty windows to make five tabs. `stationary-clicks.swift` sends only mouse-down/up pairs after one initial pointer placement: three clicks remove three windows, leave two tabs at their held width, preserve focus, and moving out re-widens them. The previous build removes only one window with that input. `stationary-three.zsh` records and asserts this take. Recordings also cover springing reorder neighbors, an isolated background close preserving focus, an active close choosing the primed most-recent tab, and a background TextEdit sheet retaining its fifth tab through Cancel. A close attempt right after a drag once only focused its tab, because hover was cleared by the drag; hover now follows the live pointer after every layout, the reorder included. The first pass checked middle-click/gutter targeting, an active save sheet and identical ordinary/no-button CLI output on base and feature trees. Reproduction tools are in `../proofs/close-tab/`; pull-request media is supplied by the demo pass.

## Checks needing the installed build or hardware

- [ ] Installed-build behavior with a real mouse or trackpad, including a real middle button.
- [ ] A save sheet from an app other than TextEdit.

## Sources

- Prateek, 2026-10-07: "winmux tabs should have the controls to be able to close a window — make it spiffy like chrome where the tabs take the same space and animate to make the next windows close button be where the mouse already".
