# The legacy `/tmp` socket stops answering

Part of {{UMBRELLA}}.

## What to build

**The CLI socket moves out of `/tmp`, and the docs say who can use it** put the socket in a mode-700 directory under the per-user temporary directory and kept a second listener on the old `/tmp/<app id>-<user>.sock`, so a `winmux` CLI from before that change still finds the app. Its issue chose to keep the old path for one release. Every land to `fork` cuts a dogfood release, so a release count is not what decides it. The CLI is: the cask installs `bin/winmux` beside the app, Sparkle updates only the app, and `brew upgrade` skips a cask that declares `auto_updates true` unless it is given `--greedy`. An installed `winmux` from before the move can stay on the `PATH` for many releases, and it only knows the old path.

While it stays, the old path keeps what the move was for out of reach: `/tmp` is world-listable, so another user on the Mac can see the socket's name, and a squatted entry there can stand in for WinMux to an older CLI.

## Decisions

- **The listener goes once an installed CLI cannot be older than the app**: the cask's `binary` points into the app bundle, so Sparkle updates both, or the release that removes the listener tells the person to run `brew upgrade --cask --greedy winmux`. Which of the two is Prateek's choice.
- **The app stops listening on the old path**, and the named legacy symbol and its listener are removed.
- **The CLI's restart hint for an older app stays** while an app from before the move can still be running. It reads a file at the old path and connects to nothing there.
- **The debug build's toggle of the release app's server** stops trying the release app's old path.

## Depends on

**The CLI socket moves out of `/tmp`, and the docs say who can use it**.

## Done when

- [ ] No `NWListener` binds the old path, checked in a test or by its absence from `Sources`.
- [ ] `docs/cli.md` no longer says the old path answers.
- [ ] A live run in a guest shows `ls /tmp/*.sock` empty of WinMux's socket while the debug app answers `env -i winmux --version`.

## Sources

- Issue #124's default: "The old path keeps working for one release, so an older CLI still finds the app."
