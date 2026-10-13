# A skill for a person's agent, shipped with the CLI

Part of {{UMBRELLA}}.

## What to build

The repository's skills are for building WinMux. A person whose coding agent should configure or drive WinMux has nothing to give it. Prateek asked that such an agent write Nickel, not JSON.

The CLI ships a skill for end users' agents.

## Decisions

- **Bundled with the CLI**, for end users. Prateek: "a skill bundled in the winmux cli for end users".
- **It knows what is focused.** The skill shows how to ask: the focused window, workspace and Column.
- **Config is Nickel.** The skill says to edit `winmux.ncl` and run `winmux config check`, and never to edit generated JSON.

## Not in this issue

- A boundary on what an agent may do. See **The CLI socket moves out of `/tmp`, and the docs say who can use it**.

## Depends on

Nothing.

## Defaults chosen for you

- **How it is delivered**: a command such as `winmux skill` that prints or installs the skill's files, so the skill matches the installed version.
- **What it covers**: reading state, writing a Filter, a Lens, a hook and a binding, checking a config, and the capture mode from **A capture mode for hooks** once that exists.
- **It is tested** by having a fresh agent with only the skill do three tasks in a guest.

## Done when

- [ ] An installed CLI can produce the skill with no network.
- [ ] A fresh agent given the skill adds a binding and a Filter to `winmux.ncl`, and `config check` passes.
- [ ] The same agent answers "which window is focused" from the CLI.

## Sources

- Prateek, 2026-10-07: "agent surface area: skill + make it focus aware"; "make the agent write ncl, not json?".
