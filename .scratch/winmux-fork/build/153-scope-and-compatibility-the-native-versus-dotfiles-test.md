# Scope and compatibility: the native-versus-dotfiles test

Part of {{UMBRELLA}}.

## What to build

`AGENTS.md`'s **Scope and compatibility** says whose the fork is and where dotfiles changes go. It does not say when a helper script becomes a WinMux feature, and a day of adoption produced three helpers that each cover a missing feature. The grilling settled the test; this issue writes it down. Docs only.

## Decisions

- **The paragraph**, under **Scope and compatibility**: "WinMux is a window manager with an integration surface: the CLI, the socket, events and the URL scheme. A helper over that surface becomes a WinMux feature when any of these holds: it needs state the surface cannot expose, or can only expose by polling; it fights WinMux when both act on a window; or it must be continuous and instant, as a finger-tracked animation must. Otherwise it stays a script, and the gap it exposes is a CLI or events issue, not a feature. The launcher, status displays such as SketchyBar or a notch indicator, and leader menus are consumers of the surface, not parts of WinMux, which ships no leader menu and no command bar; its one native status piece is the menu bar item." The last clause is the record's own limit, so the menu bar item (#290) is not declined as a status display.
- **A sentence on upstream** in the same section: for now the fork tracks upstream and merges what is useful, and changes anything it wants meanwhile; the record agreed to track it "for a bit longer", not for good.
- **A pointer to the grilling record** that settled both.
- **In the relay's review**, the test is part of the Scope and compatibility reason for declining a finding; what becomes of the gap a declined helper exposes is settled where every finding's is, by Items for Prateek.

## Depends on

Nothing.

## Done when

- [x] The two paragraphs are in `AGENTS.md` and the record is linked.
- [x] The `issue-relay` skill's step 6 names the test within the Scope and compatibility reason it already gives for declining a finding.

## Sources

- The grilling record, 2026-10-19, "The boundary".
