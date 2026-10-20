# Sidebar accents and indicators match the prototypes

Part of {{UMBRELLA}}.

## What to build

The sidebar's accents and indicators, the focused row, the Column marks, the project colour and the active workspace, do not match what the sidebar tree prototype showed and Prateek picked on 2026-10-18. The tree's structure landed; its colour and emphasis did not.

## Decisions

- **The prototype's pick is the specification**: `prototypes/83-sidebar-tree/index.html#pick`, its rail, focused row, Column marks and project accent, in light and dark.
- **Where the built sidebar differs on purpose**, the difference is listed in the pull request with the reason, and the prototype's README is updated to say so.

## Depends on

Nothing.

## Done when

- [ ] Side-by-side captures of the prototype's pick and the guest's sidebar in each state the pick shows, with no unlisted difference.
- [ ] Tests cover the accent colours the sidebar resolves for the focused row, the active workspace and the project.

## Sources

- #268, "Sidebar accents and indicators don't match the prototypes".
- The sidebar tree prototype and Prateek's pick, 2026-10-18.
