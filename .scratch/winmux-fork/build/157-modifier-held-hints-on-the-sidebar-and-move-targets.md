# Modifier-held hints on the sidebar and on move targets

Part of {{UMBRELLA}}.

## What to build

Holding the tab digits' modifier for half a second shows each tab's key on the focused tab group, since **Shortcut hints on tabs while the modifier is held** landed. Prateek wants the same for the other two places a digit means something: the sidebar's workspace rows while the workspace modifier is held, and the move targets, the workspaces and Columns a window can go to, while the move modifier is held.

## Decisions

- **The hint follows the binding in effect**, as the tab hints do: whatever chord is bound to `workspace <n>` or `move-node-to-workspace <n>` or `focus-column <n>` names the hint, and a mode's keys count when that mode is current.
- **The sidebar's workspace rows** show their key at the row's trailing end while the workspace modifier is held, in the rail and in the expanded tree.
- **Move targets** show on the focused window's own workspace: each Column's mark gets its `move-node-to-column` key, and the sidebar's rows get their `move-node-to-workspace` key, while the move modifier is held.
- **One half-second delay and one renderer** for all three, so they appear and disappear together.

## Depends on

Nothing.

## Defaults chosen for you

- **In `window` mode**, where the digits are bare, holding nothing shows nothing; the HUD legend from **The HUD can show the current mode's keys** is the help there.

## Done when

- [ ] Tests cover the hint text resolved from a custom binding for each of the three places.
- [ ] In a guest, captures of the sidebar with the workspace modifier held, and of a workspace's Column marks with the move modifier held.
- [ ] `docs/` describes them beside the tab hints.

## Sources

- #268, "Modifier-held hints: holding Alt on a tab group shows which Alt-N reaches each tab; the same for Ctrl-N in the sidebar and move targets".
