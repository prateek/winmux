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

- [x] An installed CLI can produce the skill with no network.
- [x] A fresh agent given the skill adds a binding and a Filter to `winmux.ncl`, and `config check` passes.
- [x] The same agent answers "which window is focused" from the CLI.

## Built and checked

`winmux agent skill` prints one self-contained `SKILL.md`, named `winmux`, for configuring and driving WinMux. This changes the **How it is delivered** Default from a command such as `winmux skill` to the existing `winmux agent skill`; installation is a documented redirect, with no install flags. The CLI answers immediately after parsing, before socket resolution. `Sources/Common/agentSkill.swift` holds the one compiled constant shared with the app command. No resource bundle, adjacent file, helper, server or internet is needed to print it. The cask CLI's location and Sparkle updates are independent of this change.

The skill teaches focus/window/workspace/Column readback, Nickel-only config, defaults, binding removal with `[]`, Filters, Lenses and a workspace-local Place hook. All four Nickel blocks are complete files checked through the built CLI and helper in `AgentSkillTest`. The existing JSON arrangement workflow, operation names, layout examples and `/tmp/winmux-agent.json` path remain together under Arranging windows. **The agent skill's query file is readable by other users** owns changing that path; its draft now names the shared text and its test. **A capture mode for hooks** remains unbuilt and is omitted.

Host and pinned-version guest `make check` pass: 1,743 Swift, 92 Rust/helper and 171 Python tests; the guest skips its existing committed-hash check for a sync checkout. The CLI regression was red on the old socket path and green after local interception. The recipe regression was red with no recipes and green with all four checked files. The app command retains its JSON operation assertions; no other existing test changed. A copied standalone guest CLI printed the skill with all networking denied, no server and an invalid helper path, exiting 0.

The skill edits `~/.config/winmux/winmux.ncl`, creating it when absent, unless `config status` names another file of the person's, and never the shipped `defaults.ncl` or `default-config.json`, which `config --config-path` prints when there is no config. After an edit it checks that file by name, since a bare `config check` checks the shipped defaults and passes when the file is missing; applies it with `reload-config --no-gui`, whose exit status also covers commands and key names, which `config check` does not; and confirms in `config status` that `config-path` is the edited file and `last-error` is null. Choosing the file from `--config-path`, as an earlier version did, misread a config that failed to load as no config.

A fresh host agent with only the installed skill and a shim to the guest's debug app did the three tasks. Its shell's `HOME` was a scratch directory whose absolute path the guest app also reads its config from, mirrored before each forwarded command. Starting with no config, it created `~/.config/winmux/winmux.ncl` with Option-Shift-F for `find-focus`, an `editors` Filter for Zed and Ghostty, its Lens and Option-Shift-E, checked it by name, reloaded, and confirmed in `config status` that WinMux loaded it. In the same session it answered focused Zed on workspace 1 with no Column, and Column 2 after `column-count 3`; guest readbacks agree. Earlier runs shaped the skill: one reached past the shim into the guest's config, and one, with the real `HOME`, wrote to the host's own config path, which is what the skill rightly tells a person's agent to do.

Loading that agent's config in the guest and pressing both chords showed the focus mark and an editors Lens with exactly Zed and Ghostty. Screenshots, key events and readbacks are retained for the relay. The same query/check/apply probe on the base and changed builds preserved all four windows and produced identical inventory, focus, workspace and Column readbacks. No permission was granted; the debug app and staged apps were closed, with the assigned guest left running. No by-hand upgrade step or release is part of this build.

Left to Prateek: the installed CLI printing the skill with WinMux quit, and his own agent answering what is focused with the skill installed, in **Prateek's checks on an installed build and real hardware**. The cask's `winmux` is updated by `brew upgrade --cask --greedy winmux`, not by Sparkle.

## Sources

- Prateek, 2026-10-07: "agent surface area: skill + make it focus aware"; "make the agent write ncl, not json?".
