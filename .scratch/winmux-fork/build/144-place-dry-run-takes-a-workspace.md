# `place --dry-run` takes a workspace

Part of {{UMBRELLA}}.

## What to build

`place --dry-run` explains placement for the focused workspace, not for the window's own workspace, so a per-workspace `place` hook cannot be checked without moving focus there first. A script checking a config has to switch workspaces to read an answer.

## Decisions

- **`place --dry-run --workspace <name>`** resolves placement as if the window arrived on that workspace, with that workspace's Columns and hook, and changes nothing.
- **Without `--workspace`** the behaviour stays as today.
- **The output names the workspace it resolved against**, so a reader can tell which hook answered.

## Depends on

Nothing.

## Done when

- [ ] A test with two workspaces and different `place` hooks shows `--dry-run --workspace` answering for each without a focus change.
- [ ] `docs/cli.md` and `docs/columns.md` show the flag.

## Sources

- #268's handoff, "`place --dry-run` explains placement for the focused workspace".
