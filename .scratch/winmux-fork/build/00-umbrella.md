# Fork foundation: Nickel config, Lenses, fixed Columns and the CLI

This is the build plan for a personal WinMux fork meant to replace AeroSpace as a daily driver. The design was settled as a set of decision tickets on the [`wayfind-fork` branch](https://github.com/prateek/winmux/tree/wayfind-fork/.scratch/winmux-fork); each child issue below consolidates the decisions for one buildable slice, so it can be built without reading the tickets. Upstream acceptance doesn't constrain the design.

## What the foundation is

- **Nickel config.** `~/.config/winmux/winmux.ncl` replaces TOML. A supervised helper process, `winmux-nickel`, evaluates it; WinMux never links Nickel. See [ADR 0001](https://github.com/prateek/winmux/blob/wayfind-fork/docs/adr/0001-nickel-helper-process.md).
- **Lenses.** One model covers exposé, cmd+tab and cmd-K search: a Lens is a Filter, a Presentation (`'list`, strip or `'miniatures`), a sort order and key actions, opened by an ordinary key binding. Selecting a window focuses it or Summons it.
- **Fixed Columns.** A fixed number of Columns per workspace that keep their place when empty, with Width presets, and Policy hooks that decide where an arriving window goes.
- **CLI.** Every feature has `winmux` subcommands with machine-readable output.

The terms are defined in [`CONTEXT.md`](https://github.com/prateek/winmux/blob/wayfind-fork/CONTEXT.md). Use them as written.

## Child issues, in build order

{{CHILDREN}}

Two tracks can run in parallel after the Nickel config lands: the Lens issues and the Column issues don't depend on each other. The default config comes last because it binds everything together.

## Deferred

These were designed in part and then put off so the foundation gets built first. None is specified here, and no child issue should build toward them beyond what it states.

- **Tabs.** Reading and switching tabs inside windows. The tab provider interface is decided, but no tab field, command or provider is built.
- **Trackpad gestures.** Triggers are keyboard bindings only.
- **Display profiles.** Matching a profile to a display and switching between laptop and ultrawide. The config keeps a `when.<profile>` override slot, with one implicit profile, `"default"`, so matching can be added without reshaping the config.
- **The `'grid` Presentation** (packed thumbnails without positions) and an open animation for `'miniatures`.

## Things to check while building

- **Capture indicator.** No screen-recording indicator appeared during a burst of 48 ScreenCaptureKit captures, but that was with the grant held by a host app. Check a signed WinMux build with its own Screen Recording grant.
- **Prior art.** The `codex-columns` branch of this fork has an earlier columns implementation on an older upstream base. Mine it for the Column issues; don't build on it.
- **`'list` rows.** A row shows what today's palette rows show. A richer row is undecided and not needed for the foundation.

## Where the reasoning lives

- [The map](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/map.md): every decision in one line each, in the order they were made, with links to the tickets.
- [The tickets](https://github.com/prateek/winmux/tree/wayfind-fork/.scratch/winmux-fork/issues), [research notes](https://github.com/prateek/winmux/tree/wayfind-fork/.scratch/winmux-fork/research) and [prototypes](https://github.com/prateek/winmux/tree/wayfind-fork/.scratch/winmux-fork/prototypes).

When a child issue and a ticket disagree, the child issue is right: it applies later amendments. When a child issue is silent on something, the implementer decides and says so in the pull request.
