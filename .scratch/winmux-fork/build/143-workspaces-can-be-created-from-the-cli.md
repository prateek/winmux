# Workspaces can be created from the CLI and by `persistent-workspaces`

Part of {{UMBRELLA}}.

## What to build

`winmux workspace <n>` creates a workspace only when `n` is adjacent to an existing one, through the transient blank-workspace path the pager uses, and `move-node-to-workspace` creates only the next numeric slot. So on a config with workspaces 1 and 2, `winmux workspace 9` and `winmux move-node-to-workspace 9` both fail with "Workspace '9' doesn't exist", and `persistent-workspaces = ["1", "2", "9"]` did not create 9 on reload. A test harness or a script that wants a named scratch workspace cannot make one.

## Decisions

- **`workspace <name>` creates the workspace when it does not exist**, adjacent or not, numeric or named, in the current project, and switches to it. `move-node-to-workspace <name>` creates it the same way before moving. The adjacent-slot rule stays as the sidebar's convenience and stops being the CLI's limit.
- **`persistent-workspaces` creates its workspaces on load and on reload**, and they survive being emptied.
- **`--no-create`** on both commands keeps today's refusal for scripts that want it.

## Depends on

Nothing.

## Done when

- [ ] Tests cover creation by `workspace`, by `move-node-to-workspace`, by `persistent-workspaces` on reload, and `--no-create` refusing.
- [ ] In a guest, `winmux workspace 9` on a fresh config creates and shows workspace 9, and the sidebar lists it.
- [ ] `docs/cli.md` says so.

## Sources

- #268's handoff, "Workspaces can't be created from the CLI", with the commands tried.
