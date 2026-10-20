# The menu bar item shows the state, and pause reads at a glance

Part of {{UMBRELLA}}.

## What to build

The menu bar item's text is one letter: `A`, or the first letter of the current binding mode in brackets, `(W)`, when it is not `main`. Prateek wants to see, without looking at the sidebar, which mode is current by name, which workspace and project, and whether WinMux is paused; the pause icon in particular does not read as paused. The grilling made the menu bar item the one native status surface, with notch indicators and SketchyBar left to the dotfiles over `subscribe`.

## Decisions

- **The item's title shows workspace and project**, as `2 · work`, and the current mode by name when it is not `main`, as `2 · work · window`, replacing the one-letter `(W)`; the icon alone when the title is turned off.
- **Pause has its own icon**, visibly different from the running one in both menu bar appearances, and the title reads `paused`.
- **`menu-bar.title`** chooses `'workspace`, `'workspace-project`, `'none`; the default is `'workspace-project`.
- **The item reads the same state `subscribe` sends**, so the two never disagree.

## Depends on

Nothing.

## Done when

- [ ] Tests cover the title for each setting and each state, including pause and a non-`main` mode.
- [ ] In a guest, captures of the item running, paused, in `window` mode, and with the title off, in light and dark menu bars.
- [ ] `docs/` describes the setting.

## Sources

- The grilling record, 2026-10-19, "The boundary".
- #268, "At-a-glance status" and "The pause-mode menu bar icon isn't distinctive enough".
