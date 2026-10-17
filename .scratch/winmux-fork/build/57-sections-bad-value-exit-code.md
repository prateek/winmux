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

- [x] `winmux sections spiral` and `winmux lens <name> --sections spiral` exit 2 with empty stdout and the same message, `Possible sections values:` followed by the values each one accepts.

## Built

Both refusals print `Possible sections values: <accepted values>` on stderr, without an `ERROR: ` prefix, and exit 2 with empty stdout. `sections` lists `next, none, workspace, project, monitor, app`; `lens --sections` lists the five groupings, since it does not take `next`. Both parsers read one grouping list in Common.

`parseFailureExitCode` in Common holds the CLI's parse-failure exit codes, with a test table for the commands it leaves unchanged. Every `sections` parse failure exits 2; a missing value, an extra argument and an unknown flag keep the generic parser's `ERROR: ` text.

## Sources

- Pull request [#83](https://github.com/prateek/winmux/pull/83), **Decisions the relay made**.
