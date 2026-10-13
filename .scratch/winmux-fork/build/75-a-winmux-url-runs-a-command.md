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

- **The form** is `winmux://run/<command>?<arg>=<value>`, or the command line percent-encoded in one parameter. Choose the one that needs no quoting rules of its own.
- **Commands that read stdin or print** are refused with an error in the log; a URL has nowhere to print.
- **A setting turns the scheme off.** On by default.

## Done when

- [ ] `open 'winmux://…'` for `mode`, `lens overview` and `workspace 2` each does what the CLI does, in a guest.
- [ ] A malformed URL and a refused command are logged and change nothing.
- [ ] `docs/` shows the form with three examples.

## Sources

- Prateek, 2026-10-07: "triggers (url/shortcut/?) to go into the different modes". 2026-10-13: a `winmux://` URL for any command.
