# Scope and compatibility: the native-versus-dotfiles test

Part of {{UMBRELLA}}.

## What to build

`AGENTS.md`'s **Scope and compatibility** says whose the fork is and where dotfiles changes go. It does not say when a helper script becomes a WinMux feature, and a day of adoption produced three helpers that each cover a missing feature. The grilling settled the test; this issue writes it down. Docs only.

## Decisions

- **The paragraph**, under **Scope and compatibility**: "WinMux is a window manager with an integration surface: the CLI, the socket, events and the URL scheme. A helper over that surface becomes a WinMux feature when any of these holds: it needs state the surface cannot expose, or can only expose by polling; it fights WinMux when both act on a window; or it must be continuous and instant, as a finger-tracked animation must. Otherwise it stays a script, and the gap it exposes is a CLI or events issue, not a feature. The launcher, status displays and leader menus are consumers of the surface, not parts of WinMux."
- **A sentence on upstream** in the same section: the fork tracks upstream and merges what is useful, and changes anything it wants meanwhile.
- **A pointer to the grilling record** that settled both.

## Depends on

Nothing.

## Done when

- [ ] The two paragraphs are in `AGENTS.md` and the record is linked.
- [ ] The `issue-relay` skill's step 6 names the test among the reasons a finding is declined, beside the Scope and compatibility reason it already names.

## Sources

- The grilling record, 2026-10-19, "The boundary".
