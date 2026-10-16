# A read-only command drops the refresh it cancels, and a new window stays unmanaged

Part of {{UMBRELLA}}.

## What to build

Every hotkey and CLI command runs in a light session, and `runLightSession` cancels the refresh in progress so the command goes first. It counts on its own post-command refresh to cover what the cancelled one would have done. A command whose `canSkipPostCommandRefresh` is true (`list-windows`, `list-workspaces`, `config` and the other read-only commands in `Command.swift`) schedules none. The cancelled refresh's work is then lost until some unrelated event schedules another: a window the cancelled refresh was about to register stays on screen, unmanaged and out of `list-windows`, for as long as nothing else happens.

**Reproduce** (in a guest, on the build of **`arrive` is skipped when its refresh session is cancelled**, and in that issue's live run on the base build)

1. Start a debug WinMux with a config that has an `arrive` hook, and `stage.swift`.
2. Open a stage window and, at once, run `winmux list-windows --all --json` every 100 ms until the window is listed.
3. The window is drawn on screen and never listed. Stop polling and run `winmux list-windows --all` again a few seconds later: it is still not listed.
4. `winmux doctor`, which does schedule a refresh: the window is registered and placed by its hook at once.

## Decisions

- A refresh that a light session cancels is run again after that session, whether or not the command itself needs a post-command refresh.
- A read-only command still does no refresh of its own when nothing was cancelled.

## Not in this issue

- Which events cancel a refresh, and the coalescing in `scheduleRefreshSession`.

## Depends on

Nothing.

## Done when

- [ ] A test cancels a scheduled refresh with a light session for a command that can skip its post-command refresh, and a refresh runs afterwards. The test fails without the change.
- [ ] A test runs the same command with no refresh in progress, and no refresh is scheduled.
- [ ] In a live run, the reproduction above lists the window within one second of its opening, while the polling continues.

## Sources

- The live run of **`arrive` is skipped when its refresh session is cancelled**, whose trial script needed `winmux doctor` before each readback for this reason.
