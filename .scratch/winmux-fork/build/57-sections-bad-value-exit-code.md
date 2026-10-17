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

- [x] `winmux sections spiral` and `winmux lens <name> --sections spiral` exit 2 with the same message and empty stdout.

## Built

The shared message form is `Possible sections values: <accepted values>`, without an `ERROR: ` prefix. `sections` lists `next, none, workspace, project, monitor, app`; `lens --sections` lists `none, workspace, project, monitor, app`, because it does not accept `next`. Both parsers validate and build their messages from one grouping list in Common.

`parseFailureExitCode` in Common owns the executable's parse-failure policy. Every `sections` parse failure exits 2, including a missing value, extra argument or unknown flag; these generic parser errors retain their `ERROR: ` prefixes. Existing Lens, config-action, Column and ordinary-command exit codes are covered by a preserved-behavior table.

Host and pinned-version guest `make check` pass: 1,394 Swift, 88 Rust/helper and 138 Python script tests each. The existing `SectionsCommandTest` passes unchanged; config bindings reject the new invalid-value diagnostic, accepted values remain accepted, and the existing session tests retain cycling. Generated help is unchanged. Base and head debug guest CLI transcripts verify the two exact diagnostics, empty stdout, generic failures, unchanged `focus spiral`, closed-Lens `sections next`, and successful open/workspace/next calls followed by dismissal. The default recent strip ignores grouping changes as before; real grouping and cycling are covered by session tests. No Search or permission prompt was involved. No builder release was published.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A physical second display.
- [ ] Real sleep, wake and unlock.

## Sources

- Pull request [#83](https://github.com/prateek/winmux/pull/83), **Decisions the relay made**.
