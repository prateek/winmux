# A capture mode for hooks

Part of {{UMBRELLA}}.

## What to build

To see what a `place` hook was given, Prateek added temporary hooks to his config that echoed their input to files. `winmux subscribe` streams events and `place --dry-run` prints one decision; nothing records what each hook was called with and what it returned.

A capture mode records every hook call.

## Decisions

- **Each record holds the hook, its inputs, its result and how long it took.** Prateek: "something like that, yeah".
- **Switched on and off by a command**, off by default.

## Not in this issue

- Replaying a captured call against an edited config. Say in the pull request how far the format is from allowing it.

## Depends on

Nothing.

## Defaults chosen for you

- **Where records go**: a file in the state directory, one JSON object per line, and the `subscribe` stream.
- **Window titles are in the records.** The docs say so, and the capture stops itself after a set time.

## Done when

- [ ] With capture on, opening a window writes one record per hook that ran, with inputs that match `debug-windows` for that window.
- [ ] A hook that fails is recorded with its error.
- [ ] With capture off, nothing is written.

## Sources

- Prateek, 2026-10-07: "debug hooks and event capture mode", with the two diagnostic hooks from his config.
