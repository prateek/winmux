# `config check` smoke-runs hooks with every workspace the config names

Part of {{UMBRELLA}}.

## What to build

`winmux config check` already smoke-runs every Filter and every hook: the Nickel helper calls each with a synthetic window and each of its synthetic contexts, and reports a body that fails. Prateek's per-workspace `place` hook passed it and then failed on the first real window, with the error reaching only `last-error` in `config status`. The branch that failed keyed on a workspace name, and no synthetic context carries the workspaces the config itself names.

Make the smoke passes cover what the config says about itself.

## Decisions

- **One smoke context per workspace the config names**, from `persistent-workspaces`, `columns.when.<workspace>` and every workspace a hook body mentions, each with that workspace's Column count and widths resolved; and one per Display profile under `when`.
- **A failing pass names its context**: the hook, the workspace, the profile and Nickel's message.
- **A hook that returns an action the contract does not allow** in any pass is reported the same way, as today.
- **`--no-hooks`** keeps a parse-only check for a config that is only being edited.

## Depends on

Nothing.

## Defaults chosen for you

- **A workspace named only inside a hook body** is found by the helper's existing parse of the body's string literals; a name it cannot see is not a context, and the docs say to list such workspaces in `persistent-workspaces` to have them checked.
- **The synthetic window's fields** stay as they are and are documented in `docs/columns.md`.

## Done when

- [ ] A test with a `place` hook that errors only for workspace `9`, named in `persistent-workspaces`, fails `config check` naming workspace `9`; the same config without the name passes, as today.
- [ ] A test with a hook that errors only under a non-default Display profile fails naming the profile.
- [ ] `docs/cli.md` and `docs/columns.md` describe the passes and the contexts.

## Sources

- #268's handoff, "`winmux config check` is lazy about hook bodies".
- `nickel-helper/src/protocol.rs`, the smoke passes, and `docs/columns.md` on hook smoke runs.
