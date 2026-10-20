# Workspaces can be created from the CLI and by `persistent-workspaces`

Part of {{UMBRELLA}}.

## What to build

`winmux workspace <n>` creates a numeric workspace only when `n` is adjacent to an existing one, through the transient blank-workspace path the pager uses, and `move-node-to-workspace <n>` creates a numeric one only for the next slot; a non-numeric name is created by either command already, through `Workspace.get(byName:)`. So on a config with workspaces 1 and 2, `winmux workspace 9` and `winmux move-node-to-workspace 9` both fail with "Workspace '9' doesn't exist" while `winmux workspace scratch` works, and `persistent-workspaces = ["1", "2", "9"]` did not create 9 on reload. A script that wants numbered scratch workspaces cannot make them.

## Decisions

- **A numeric name is created like a non-numeric one**: `workspace <n>` and `move-node-to-workspace <n>` create workspace `n` in the current project whether or not it is adjacent, as they create `scratch` today. The adjacent-slot rule stays as the sidebar's convenience and stops being the CLI's limit.
- **`persistent-workspaces` creates its workspaces on load and on reload**, and they survive being emptied.
- **`--no-create`** on both commands keeps today's refusal for scripts that want it.

## Depends on

Nothing.

## Done when

- [ ] Tests cover creation of a non-adjacent numeric workspace by `workspace`, by `move-node-to-workspace`, by `persistent-workspaces` on reload, and `--no-create` refusing; a named workspace keeps working as today.
- [ ] In a guest, `winmux workspace 9` on a fresh config creates and shows workspace 9, and the sidebar lists it.
- [ ] `docs/cli.md` says so.

## Sources

- #268's handoff, "Workspaces can't be created from the CLI", with the commands tried.
