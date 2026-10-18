# The CLI socket moves out of `/tmp`, and the docs say who can use it

Part of {{UMBRELLA}}.

## What to build

The CLI talks to the app over a socket at `<per-user temporary directory>/<app id>/winmux.sock`. The old `/tmp/<app id>-<user>.sock` path, inherited from upstream, also answers for older CLIs. Any process running as the person can drive WinMux and read every window title through it. Prateek was asked whether an agent should get less, and chose no boundary, documented.

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

- **Where.** The per-user temporary directory from `confstr(_CS_DARWIN_USER_TEMP_DIR)`, with no environment-based fallback. LaunchServices and shells can see different environments, so a state-directory or `TMPDIR` choice could separate the app and CLI. `getconf DARWIN_USER_TEMP_DIR` prints the base. Sockets six days old survived in that directory on the build machine across six days of uptime, and the app makes its socket again at each start.
- **The old path** keeps working through a second listener until **The legacy `/tmp` socket stops answering** lands, so an older CLI still finds the app. This replaces the original one-release default. A legacy bind failure logs and continues; only the new endpoint is required.

## Done when

- [x] The socket's directory is mode 700 and owned by the person, checked in a test.
- [x] A CLI and an app from the same build find each other with no environment set.
- [x] `docs/` has a short section on who can drive WinMux.

## Built and checked

- `Sources/Common/SocketPath.swift` supplies the shared path, directory preparation and legacy naming. Directory checks refuse links, non-directories and foreign owners, and tighten an owned directory to 0700 through an opened, identity-checked descriptor. Overlong Unix socket paths fail with the path in the message. A missing `confstr` result is fatal, without a `/tmp` fallback.
- Nine seam tests cover missing and existing directories, refusal reasons, the real path's ownership/mode/location/length, changed process environments for both app ids, exact legacy naming, connection-error hints and safe legacy cleanup. Network.framework leaves socket entries after exit; legacy cleanup unlinks only an owned socket, leaving a squatting regular file or symlink alone. Both listeners share the command handler. Debug toggles the release app through its new path first and then its legacy path.
- Host and pinned-version guest `make check` pass: 1,548 Swift tests, 86 helper tests and 171 Python tests. The guest intentionally skips the committed-hash assertion for its sync repository; the host runs it. GitHub CI remains the merge gate.
- Live guest transcripts cover `env -i` version/workspace replies, directory and socket readback, the baseline CLI reaching the new app, identical baseline/new command output, stopped-app errors with and without a legacy entry (since narrowed in review to a legacy path that answers, with its own driver transcript), 0755 repair, symlink refusal/restoration, nonfatal legacy squatting, and both release-toggle routes using protocol stubs. The two updated raw socket proof scripts pass without a staged desk; first-run routing uses a temporary pending marker with the existing grants, then restores normal startup. No permission was granted.
- `docs/cli.md`, the URL guide, README and bundled agent skill document full caller reach and no read-only mode. The proof scripts and VM guide use the private path. The diagnostic cache and agent JSON scratch file remain out of scope.

## Installed-build check for Prateek

- [ ] An installed release whose app Sparkle updated still answers an older `winmux` from the cask on `PATH`. The baseline debug CLI live proof covers the protocol and legacy listener, not that installation/update path.

## Sources

- Prateek, 2026-10-07: "does winmux cli that we expose have any agent boundaries?" and "why tmp? is that the idiomatic location?". 2026-10-13: no boundary; document it.
