# Research: monitor identity and display-change handling for Display profiles

Type: research
Status: resolved

## Question

How does WinMux identify monitors (name, index, UUID) and react to displays appearing or disappearing (`WorkspaceMonitorAssignment.swift`, `WorkspaceAutomaticDisplay.swift`, monitor config)? How does the BetterDisplay mirrored virtual screen created by `~/dotfiles/home/dot_config/raycast/scripts/executable_g95nc.sh` (name `G95-HiDPI`, pinned serial and model) look to macOS and to WinMux compared with the built-in panel? Is its identity stable across recreates? What event sequence does WinMux see during a `g95nc set` / `reset` or clamshell transition? Deliverable: how a Display profile can be matched reliably, and which hook would apply it.

## Answer

WinMux has no stable monitor identity. Monitors are identified by `NSScreen` index, localized name, and frame, and workspace state is keyed by top-left corner, which is always (0,0) with one display at a time. The only display signal is `didChangeScreenParametersNotification`, which `MonitorConfigurationObserver` handles in an immediate pass and a 750 ms "settled" pass, ending in a refresh session plus `gcMonitors()`. `on-focused-monitor-changed` does not fire on a laptop↔ultrawide swap.

Match Display profiles on a CoreGraphics descriptor instead: `isBuiltin` for the laptop, and UUID or vendor/model/serial for the ultrawide, listing both the physical Odyssey (19501/29813) and the pinned `G95-HiDPI` virtual screen (serial 90570057, model 9057). The virtual screen's UUID should be stable across recreates according to the BetterDisplay developer, but that hasn't been verified live. Keep a name regex as a fallback.

Apply the profile from `MonitorConfigurationObserver.refreshMonitorPolicy` on the settled pass and at startup, and emit a new `displayProfileChanged` event. `g95nc`'s internal sleeps exceed 750 ms, so resolution must tolerate transient two-monitor and LoDPI states (hysteresis, priority, or an explicit nudge from `g95nc`).

[findings](../research/05-monitor-identity-and-display-change.md)
