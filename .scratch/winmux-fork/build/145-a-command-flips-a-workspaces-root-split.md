# A command flips a workspace's root split orientation

Part of {{UMBRELLA}}.

## What to build

There is no CLI to turn a workspace's root split from columns to rows. `layout --window-id <w> v_tiles` flips the window's parent, which is a tab group when a Column holds several windows, not the root. Prateek's `winmux-rows` script rewrites the root split through `winmux agent`'s layout JSON, flipping the direction and carrying floating windows through. By the native-versus-dotfiles test this is a CLI gap, not a feature: the script stays, and WinMux gives it the one command it lacks.

## Decisions

- **`layout --root <orientation>`** sets the current workspace's root split to `h_tiles` or `v_tiles`, and `--root toggle` flips it, leaving every child, Column binding and floating window as it is.
- **On a workspace with Columns**, the root is the Column row; flipping it stacks the Columns vertically with their widths becoming heights, and flipping back restores. Normalization today forces a Columns root horizontal, so the flip has to survive normalization: the workspace records its orientation and normalization keeps it. The docs say that Columns are built for one orientation and that rows are the laptop case.
- **Direction commands follow the orientation**: after a flip, `focus down` and `move down` go to the next Column, and the drag overlay's Column targets are stacked too.
- **`--workspace <name>`** targets another workspace without focusing it.

## Depends on

Nothing.

## Done when

- [ ] Tests flip a plain root split, a Columns root and a root with floating windows, run a normalization pass and a `focus down` on the Columns root, and flip each back unchanged.
- [ ] In a guest, `winmux layout --root toggle` turns three side-by-side windows into three stacked ones and back, read back with `agent query`.
- [ ] `docs/cli.md` shows the flag, and the dotfiles script is noted in #268's handoff as replaceable by it.

## Sources

- #268's handoff, "No CLI to flip a workspace's root split orientation".
