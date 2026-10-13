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

- [ ] In a group of twelve tabs, `alt-9` focuses the twelfth and `alt-8` the eighth.
- [ ] `alt-0` reaches the focused app on the defaults.
- [ ] The command's tests cover `last` on one tab and on twelve.

## Sources

- Prateek, 2026-10-07: "alt-9 should go to the last tab in the tab-group". Asked what Chrome does past ten tabs, and to the proposal above: "yes".
