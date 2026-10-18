# The ninth tab digit goes to the last tab

Part of {{UMBRELLA}}.

## What to build

`alt-1` to `alt-9` focus tabs one to nine and `alt-0` the tenth. Browsers do it differently, and Prateek's hands expect theirs: one to eight by position, nine for the last tab.

## Decisions

- **`alt-1` to `alt-8` focus by position, and `alt-9` focuses the last tab.**
- **`alt-0` is unbound.**

## Not in this issue

- Which modifier the tab digits use. **A short list of default shortcuts** keeps them on `alt-`.

## Depends on

Nothing.

## Defaults chosen for you

- **The argument** is `focus --tab-index last`.
- **A group with fewer than eight tabs**: a digit past the end does nothing.

## Done when

- [x] In a group of twelve tabs, `alt-9` focuses the twelfth and `alt-8` the eighth.
- [x] `alt-0` reaches the focused app on the defaults.
- [x] The command's tests cover `last` on one tab and on twelve.

## Built and checked

`FocusCmdArgs.TabIndex` represents a positive position or `last`. The latter resolves the last child of the focused window's nearest tab group, or of a one-window tab layout when no group encloses it, using the same MRU/representative resolution as a position. A position past the end still fails without changing focus. `--tab-index`, `tab-next` and `tab-prev` no longer bind the workspace's floating windows into the tree before resolving, so a floating window is never one of their tabs; a focused floating window is in no group, so from it `--tab-index` fails and `tab-next` and `tab-prev` follow their boundaries action, stopping by default. Directions and dfs still bind floating windows inside a tab group: **A floating window over a tab group becomes a tab for focus directions**. The shipped main mode has 40 bindings; Option-0 is free. Old `std.record.remove "alt-0"` removals get the existing migration hint. Conversion and first-run TOML bootstrap preserve explicit user chords, including ninth- and tenth-position bindings; the upstream conversion expectation and fixture are unchanged. The Rust exact-short-list expectation also needed its digit range changed to match the new defaults.

Host and Swift-6.4 guest `make check` pass: 1,613 Swift tests, 87 Rust integration tests and 171 script tests (the guest skips the host-only committed-hash assertion by design). Tests cover parsing, incompatible options, one/twelve tabs, nested-child MRU resolution, an out-of-range position, no tab group, exact default commands and the removal hint.

At 1280 × 720, an import-free/defaults-only debug guest run with twelve owned windows checked Option-9 → tab twelve and Option-8 → tab eight. With three tabs, Option-9 → tab three and Option-8 leaves focus and the screen unchanged. Notes receives `º` from Option-0 while WinMux focus stays on Notes. CLI `last` succeeds; `0` and `first` print the specified error and exit non-zero. The same positional/relative-focus script produces identical output against the base and feature builds. Proof tools are in `.scratch/winmux-fork/proofs/tab-nine-last/`; screenshots, key logs and readbacks are retained by the relay. No Search was used, no permission prompt appeared, and the debug build and owned windows were closed after the run. The builder publishes no release.

## Checks that remain Prateek's

- [ ] After the dotfiles change for Option-9 and Option-0, on the installed build with a real keyboard: Option-9 in a tab group of more than nine focuses the last tab, and Option-0 reaches the focused app.

## Sources

- Prateek, 2026-10-07: "alt-9 should go to the last tab in the tab-group". Asked what Chrome does past ten tabs, and to the proposal above: "yes".
