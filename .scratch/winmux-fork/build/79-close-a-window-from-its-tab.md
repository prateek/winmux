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

- [ ] Clicking a tab's button closes that window and no other.
- [ ] Three clicks without moving the pointer close three windows, in a guest.
- [ ] A window with an unsaved-changes sheet keeps its tab.
- [ ] The pull request has a clip of the three closes.

## Sources

- Prateek, 2026-10-07: "winmux tabs should have the controls to be able to close a window — make it spiffy like chrome where the tabs take the same space and animate to make the next windows close button be where the mouse already".
