# A refresh during startup binds windows to the focused workspace

Part of {{UMBRELLA}}.

## What to build

At launch, `MacWindow.getOrRegister` binds a window it has not seen to the active workspace of the monitor the window is on, but only inside the startup session, where `isStartup` is true. Any other refresh binds a new window to the focused workspace. Several refreshes can start before the startup session reaches every window: `MonitorConfigurationObserver.prepareForStartup` schedules one, and `GlobalObserver.initObserver()` and `MonitorConfigurationObserver.startObserving()` both run before `runRefreshSessionBlocking(.startup)` and schedule refreshes on app activation, mouse-up and screen changes. A window such a refresh reaches first is bound to the focused workspace, so with two displays a window on the second one can be tiled onto the first display's workspace at launch.

The first live run of **Quitting WinMux puts windows back where they were** saw the monitor-preparation refresh register two of five windows before the startup session. That issue no longer depends on which session registers a window, and left the binding as it was.

## Decisions

- **Startup discovers the windows.** Until the startup session has run, a scheduled refresh waits for it, whichever observer asked.

## Depends on

Nothing.

## Done when

- [ ] A test schedules a refresh before the startup session and every window is still bound to its monitor's active workspace.
- [ ] Two windows on a second display stay on that display's workspace at launch, a check for Prateek on real hardware.

## Sources

- The first live run, and the second and third reviews, of the pull request for **Quitting WinMux puts windows back where they were**, 2026-10-17.
