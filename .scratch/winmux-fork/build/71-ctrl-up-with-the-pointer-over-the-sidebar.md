# Ctrl-Up does nothing while the pointer is over the expanded sidebar

Part of {{UMBRELLA}}.

## What to build

In a guest on `0.5.6-dogfood.13`, with the pointer over the expanded workspace sidebar, `ctrl-up` did not open Mission Control. It opened as soon as the pointer left the sidebar. Twice in two tries.

Inferred, not shown: the hovered sidebar panel takes the key event.

## Decisions

- **Reproduce first**, and find out whether other system shortcuts are lost the same way.
- **A system shortcut works wherever the pointer is.**

## Not in this issue

- What Mission Control draws once it opens. That is **Mission Control and Exposé with WinMux running**.

## Depends on

Nothing.

## Done when

- [ ] `ctrl-up`, `ctrl-down` and one app shortcut such as `cmd-n` work with the pointer over the expanded sidebar, checked in a guest.
- [ ] The pull request says what took the key.

## Sources

- The switching comparison, 2026-10-07: the Mission Control captures with WinMux running.
