# Shortcut hints on tabs while the modifier is held

Part of {{UMBRELLA}}.

## What to build

A tab group's tabs are reached by digit, and nothing shows which digit is which. Holding the modifier for a moment shows a number on each tab.

## Decisions

- **Its own issue, built after Hints shown while a key is held**, sharing that issue's delay and its setting. That one draws on Tiles in a Lens; this draws on the tab strip.
- **The hints come from the bindings in effect**, not from an assumed modifier.

## Not in this issue

- Hints on sidebar workspaces. Say in the pull request if they come for free.

## Depends on

- **Hints shown while a key is held**.
- **The ninth tab digit goes to the last tab**, for what the ninth hint says.

## Defaults chosen for you

- **A tab with no binding shows no hint.**
- **The hint sits where the tab's icon is.**

## Done when

- [ ] Holding the tab digits' modifier past the delay shows a number on each bound tab, and releasing clears them.
- [ ] A config that rebinds the digits shows the new ones.
- [ ] A quick chord shows nothing.

## Sources

- Prateek, 2026-10-07: "show shortcut overlays on winmux tabs after a short delay when holding alt (or whatever the bind is)".
