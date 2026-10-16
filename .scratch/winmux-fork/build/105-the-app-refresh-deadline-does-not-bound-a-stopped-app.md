# The per-app refresh deadline does not bound a stopped app

Part of {{UMBRELLA}}.

## What to build

`singleAppRefreshDeadline` (`tree/AppRefreshDeadline.swift`) promises that one app holds up the window-refresh barrier for at most 1500 ms. Its doc comment says a CPU-starved app would otherwise hold every other app's layout for windows × the AX messaging timeout. At the deadline, `appRefreshWithDeadline` cancels the app's enumeration, then waits for it to end. An AX call blocked on an app that does not answer ignores the cancellation and returns only at the messaging timeout, so the barrier waits anyway, once for each message still to send.

**Reproduce** (in a guest, on the build of **Config reload attempts and Policy hook completion, each with one owner**, and on the build before it)

1. Start a debug WinMux on scratch config, and `stage.swift` with one app showing two windows.
2. `kill -STOP` that app's process, then open a window from a second stage app.
3. Run no `winmux` command for 2 s, then run `winmux list-windows --all` once.
4. The readback returns about 4.4 s after the window opened, and the refresh that registered it ran about 4 to 5 s. Started at 5 s instead, the readback returns about 20.5 s after the open.

## Decisions

- One app that does not answer holds a refresh for no more than the deadline. Every other app's windows are registered and laid out in that refresh.
- The stopped app's windows stay as the model had them until a refresh in which the app answers.
- An abandoned enumeration may finish after its refresh, but it does not run beside a newer enumeration of the same app, and what it returns late changes no refresh's alive-window list.

## Not in this issue

- Which events cancel a refresh, and the light session's cancellation of a scheduled refresh: **A read-only command drops the refresh it cancels, and a new window stays unmanaged**.
- Registration and restoration under a cancelled refresh: **A window registered or restored during a cancelled refresh misses its placement hook**.
- A CLI readback blocking on AX for a stopped app.

## Depends on

**A window registered or restored during a cancelled refresh misses its placement hook**, since an abandoned enumeration registers windows outside the refresh that started it.

## Done when

- [ ] A controlled-clock test in `AppRefreshDeadlineTest` holds an app's work past the deadline without honouring cancellation, and the call returns the fallback at 1500 ms. It fails on the base.
- [ ] A test starts a second refresh while the first one's abandoned work is still running, and shows one enumeration of that app at a time, with the late result changing nothing either refresh returned.
- [ ] In a live run, the reproduction lists the new window in a readback started 2 s after it opened, returning within about 2 s on the changed build.

## Sources

- The live run and review of the pull request for **Config reload attempts and Policy hook completion, each with one owner**, Time and cancellation part.
