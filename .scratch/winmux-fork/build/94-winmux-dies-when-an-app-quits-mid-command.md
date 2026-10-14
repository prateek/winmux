# WinMux dies when an app quits while a command reads its windows

Part of {{UMBRELLA}}.

## What to build

When an app quits, `MacApp.destroy()` (`Sources/AppBundle/tree/MacApp.swift`) queues a job on the app's AX thread that destroys its window table, its subscriptions and its AX handles, and then sets `thread = nil` so no later job can be submitted. A job submitted before that line, but queued behind the destroying job, still runs. `withWindow` then reads `windows.threadGuarded`, finds the value destroyed, and `ThreadGuardedValue` calls `dieT("Value is already destroyed")`, which ends WinMux.

The demo pass of pull request #149 met it while tearing down the fourteen-window desk: Preview quit while a `winmux list-windows --all` was running, and WinMux exited with "Value is already destroyed" on Preview's `AxAppThread`, from `MacApp.withWindow`, during the refresh for that `list-windows`. A Console window opened on the runtime error. Quitting an app while a script, a Lens or a subscription is reading windows is ordinary use.

## Decisions

- **A job that runs on an app's thread after the app was destroyed does nothing and returns no result**, as `withWindow` does for a window id it no longer knows. WinMux keeps running.
- **`ThreadGuardedValue` still dies on a read from the wrong thread.** Only a read after destruction from the right thread becomes a nil result, at the `MacApp` call sites.

## Not in this issue

Other `dieT` checks, and crash reporting.

## Depends on

Nothing.

## Done when

- [ ] A test destroys a `MacApp` while a `withWindow` and a `withWindowAsync` job are queued behind the destroying job; both finish without a result and the process lives.
- [ ] In a guest, quitting an app in a loop while `winmux list-windows --all` runs in another loop for a minute leaves WinMux running.

## Sources

- Pull request [#149](https://github.com/prateek/winmux/pull/149): its demo pass's crash log and crash report from the rich desk's teardown.
