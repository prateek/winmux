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

- [x] With capture on, opening a window writes one record per hook that ran, with inputs that match `debug-windows` for that window.
- [x] A hook that fails is recorded with its error.
- [x] With capture off, nothing is written.

## Built and checked

- `debug-hooks on`, `off` and status (also the bare command) have text and JSON forms. Capture starts off, survives reload, uses `hook-capture.jsonl` in the state directory, and expires at a fixed 15-minute deadline with no timer. Repeated `on` keeps records and extends the deadline; starting again from off truncates. File failures stop capture, log the reason and appear in status. No Default changed.
- Only `PolicyHookCompletion.call` records calls. Arrive, Place, workspace-local definitions, dry runs, boundary moves and previews share that path; Filters and helper smoke runs do not. Records preserve exact helper arguments and raw answers, including invalid results, with separate argument and helper timings. Cancellation and missing Window records are silent. Errors applying accepted answers, including an out-of-range Column and disallowed or suppressed Run commands, remain outside the record in `config status` and the log.
- Controlled helper tests cover success, invalid results, unavailable/timeout/Nickel failures, argument failure, cancellation, missing records, capture off without reading its clock, deadline expiry before a call or during helper work, restart, file errors, command forms and file/event equality. An injected clock and file location keep these deterministic. A deadline mutation fails both expiry tests. Existing hook-behavior tests are unchanged; only command/event list expectations and the required agent-skill assertion were extended.
- Host and pinned-version guest `make check` pass (1,755 Swift, 92 Rust/helper and 171 script tests). The guest uses Apple Swift 6.4; this does not establish a pass on CI's swift.org compiler. The guest skips its existing committed-hash script check. The agent skill's Nickel recipes still pass `config check`; its capture example uses a shell fence.
- A three-Column guest run writes one Arrive and one Place record for a new Ghostty window, which lands in Column 2. Every Window-record field was compared with the immediate `debug-windows` readback. In the final run, `title` changes from empty during initial AX discovery to the configured title, and `lastFocusedSeq` changes from zero to the subsequent focus sequence; all other fields match, including workspace, project, monitor and class. An ordinary-shell preliminary run also changes `document` as shell integration reports its working directory. The records retain the actual earlier helper input rather than rewriting it from a later readback.
- The raised Place hook records null result and its helper diagnostic while built-in placement still lands the window. A Column-7 answer on three Columns records the raw answer with null error, while `config status` names the later Column failure. Dry run and an edge Move each add one record. Eight file records equal the eight `hook-called` events; turning capture off keeps the line count at eight and a subscriber silent while a fourth window is managed. Repeated `on`, off/status output, reload retention and fresh-capture truncation are checked live.
- A separate guest run checks Filters and `config check` smoke calls leave the capture empty. Replacing the capture file with a directory makes the next call stop capture and report/log its file error, with no fallback event. A failed `on --json` still reports JSON status and exits 1. Repairing the location and starting again recovers one matching file/event record.
- The same capture-off script runs against the archived base and new build in separate guest directories. Inventory, native frames, agent tree, Column placement, dry-run answer and boundary result agree after substituting window/pane/process identities and snapshot metadata. Screenshots agree with the readbacks. Proof tools are in `.scratch/winmux-fork/proofs/hook-capture/`; transcripts and screenshots accompany the builder handoff. No Search or permission grant was used. Ghostty's command-line execution confirmation was dismissed with Cancel during an initial probe; the accepted runs use a configured command instead. No release was published.

## Sources

- Prateek, 2026-10-07: "debug hooks and event capture mode", with the two diagnostic hooks from his config.
