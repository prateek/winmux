# The CLI socket moves out of `/tmp`, and the docs say who can use it

Part of {{UMBRELLA}}.

## What to build

The CLI talks to the app over a socket at `/tmp/<app id>-<user>.sock`, a path inherited from upstream. Any process running as the person can drive WinMux and read every window title through it. Prateek was asked whether an agent should get less, and chose no boundary, documented.

The socket moves to a per-user directory, and the docs say plainly what can use it.

## Decisions

- **No caller boundary.** A process running as the person has the CLI's full reach. This is a decision, not an oversight.
- **The docs say so**, where the CLI and the bundled skill are described.
- **The socket is not in a world-listable directory.**

## Not in this issue

- A read-only socket or mode for agents.

## Depends on

Nothing.

## Defaults chosen for you

- **Where.** A directory only the person can read: the per-user temporary directory or WinMux's state directory. Say which and why.
- **The old path** keeps working for one release, so an older CLI still finds the app.

## Done when

- [ ] The socket's directory is mode 700 and owned by the person, checked in a test.
- [ ] A CLI and an app from the same build find each other with no environment set.
- [ ] `docs/` has a short section on who can drive WinMux.

## Sources

- Prateek, 2026-10-07: "does winmux cli that we expose have any agent boundaries?" and "why tmp? is that the idiomatic location?". 2026-10-13: no boundary; document it.
