# `sections` and `--sections` refuse a bad value with the same exit code

Part of {{UMBRELLA}}.

## What to build

`winmux sections spiral` exits 1, the command parser's code. `winmux lens recent --sections spiral` exits 2. Both are the same mistake by the caller and both print the possible values.

## Decisions

- **Both exit 2** with the same message, the code the Lens commands already use for a refused argument.

## Not in this issue

Leftovers of the same pull request that Prateek accepted as they are: `'columns` being hard to read at about nine Sections, a list showing part of a row at its bottom edge, and the Summon label running out of a very narrow Tile.

## Depends on

Nothing.

## Done when

- [ ] `winmux sections spiral` and `winmux lens <name> --sections spiral` exit 2 with the same message and empty stdout.

## Sources

- Pull request [#83](https://github.com/prateek/winmux/pull/83), **Decisions the relay made**.
