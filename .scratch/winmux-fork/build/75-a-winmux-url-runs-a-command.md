# A `winmux://` URL runs a command

Part of {{UMBRELLA}}.

## What to build

A mode is entered, and any command run, by a key binding or the CLI. A launcher, a Shortcuts action, a gesture tool or a link in a note can open a URL more easily than it can run a shell command.

WinMux registers a `winmux://` URL scheme that runs a command.

## Decisions

- **Any CLI command**, not only `mode`. Prateek chose this over a list of mode triggers.
- **The same trust as the CLI.** Anything that can open a URL as the person can run a command. See **The CLI socket moves out of `/tmp`, and the docs say who can use it**.

## Not in this issue

- A native Shortcuts action.
- Trackpad gestures, which are **Trackpad gestures as Triggers**. A gesture tool that opens URLs is a way to try a swipe on `overview` before that issue is built.

## Depends on

Nothing.

## Defaults chosen for you

- **The form** is `winmux://run/<arg>/<arg>/…`: one percent-decoded path segment per CLI argument, with no query or shell splitting. `%20` preserves a space inside one word and `%2F` preserves a literal slash; normal CLI argument validation still applies. This replaces the offered query/one-parameter forms under the builder ruling.
- **Commands that read stdin or print** are refused with an error in the log; a URL has nowhere to print.
- **A setting turns the scheme off.** The top-level Bool `url-scheme` defaults to `true`; a saved config reload applies to the next URL. Off, every URL logs a refusal naming the setting. Bundle registration remains in place.

## Built behavior

- The early `kAEGetURL` Apple-event handler registers in `applicationWillFinishLaunching`, before SwiftUI finishes launching. Registering in `prepareWinMuxProcess` was too early to remain effective in the live run. The handler logs and enqueues; one consumer awaits each command before starting the next. A runtime-ready signal holds URLs through startup. It is also set when the startup task ends early, so a startup step that throws cannot hold them forever. While first-run setup waits for the person, the signal releases the queue to the existing setup refusal, and Go holds it again until startup finishes.
- Socket and URL commands share parsing, the disabled-server guard, the parsed-command gate, first-run checks and light-session execution. `exec-and-forget` does not parse from an argument list, on the socket as before or from a URL. The socket retains its subscription loop and incomplete-request note. URLs use empty stdin, the focused window/workspace and a distinct URL trace origin and refresh event.
- Refused forms are help, subscriptions, every `list-*`, both debug commands, `doctor`, `config`, every `agent` subcommand, `place` (every form only explains a placement), `reload-config --dry-run`, `exec-and-forget`, the workspace/movement `--stdin` forms, `lens --filter -`, and `trigger-binding` for a binding that runs any of these or another `trigger-binding`, since a binding's commands run past the gate. `TriggerBindingCommand` checks the binding again as it runs it, when the command's `CmdEnv` says a URL asked for it, so a config reload between the gate and the run changes nothing. Config hooks and refreshes get their own env and run as they do after the same command from the CLI. A link still fires the config's own hooks, as the same command from the CLI does. The classifier exhaustively switches over `CmdKind`. A successful URL is logged at info with any stdout; a refusal or non-zero exit is logged once at error, in category `url`.
- The release plist and debug wrapper register `winmux`. XcodeGen produced only the requested URL-types addition in the tracked plist. `docs/url-scheme.md`, linked from the README, documents the form, restrictions, setting and trust boundary.

## Done when

- [x] `open 'winmux://…'` for `mode`, `lens overview` and `workspace 2` each does what the CLI does, in a guest. Separate CLI/URL readbacks match; Overview screenshots and traces show both openings and Escape closure. The running wrapped process is retained and no SwiftUI window opens.
- [x] A malformed URL and a refused command are logged and change nothing. Both malformed examples, output and stdin forms retain exact workspace/window snapshots. Setting-off, disabled-server recovery, FIFO ordering, incidental stdout, a failing command and cold first-run refusal are also checked in the guest.
- [x] `docs/` shows the form with three examples.

Host and pinned-version guest `make check` pass: 1,526 Swift tests, 91 Rust tests and 171 Python tests (one expected synced-guest provenance skip). The socket comparison runs one script against the base and feature trees and matches all eleven normalized answers. `ExternalCommandTest`, `URLCommandTest` and the helper tests cover the seams. The first pass's live tools are in `.scratch/winmux-fork/proofs/url-scheme/`; the review's later fixes are covered by `URLCommandTest`, and the pull request's demos show the trigger-binding and `reload-config --dry-run` refusals live.

The signed release dry run built and verified without publishing. Its built URL registration, single-process URL delivery, workspace readback and release-category log passed in the guest. The release screenshot exposed the driving tool's private-window-picker bypass prompt; it was left unanswered and ends the live run. Clean release visual acceptance remains blocked by that image defect. Earlier debug acceptance screenshots are clear.

## Checks left for Prateek

- [ ] Open a URL from a real browser, Shortcuts or Raycast on an installed build, including its native external-scheme confirmation.
- [ ] Check on a second display.
- [ ] Check real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-07: "triggers (url/shortcut/?) to go into the different modes". 2026-10-13: a `winmux://` URL for any command.
