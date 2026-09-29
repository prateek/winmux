# Research: taking over cmd+tab and cmd+` from the system

Type: research
Status: resolved

## Question

How can WinMux bind `cmd-tab` and `` cmd-` `` to Lenses, replacing the native app switcher and "Move focus to next window" on macOS 26? WinMux registers keys through the `HotKey` package (Carbon `RegisterEventHotKey`, see `Sources/AppBundle/config/`), which probably can't override these system shortcuts. Find out:

- Whether Carbon hotkeys can take `cmd-tab` or `` cmd-` `` at all.
- What AltTab does instead (GPL-3, so design only): private `CGSSetSymbolicHotKeyEnabled`, a `CGEventTap`, or both. Also what permissions it needs, and how it restores the system shortcuts when it quits or crashes.
- How modifier release is detected for a strip's commit-on-release, and what that costs in an always-on tap (AltTab #5911).
- Whether the cmd+` symbolic hotkey is disabled the same way, and how this interacts with the user's keyboard settings (System Settings → Keyboard Shortcuts).

Deliverable: a recommended mechanism that fits WinMux's binding pipeline, so `cmd-tab = 'lens recent'` works in `[mode.main.binding]`, plus its failure modes. Background: [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md).

## Answer

- **Carbon alone isn't enough for cmd+tab.** A Carbon hotkey takes `cmd-backtick` directly. `cmd-tab` registers without error but never fires while the system's symbolic hotkey is on (on this Mac, exclusive registration fails with `eventHotKeyExistsErr`: another process holds it, probably the Dock).
- **Mechanism, following AltTab's design (GPL-3, design only):** keep the Carbon hotkey, and turn off the system's symbolic hotkeys 1 and 2 (cmd-tab, cmd-shift-tab) with the private `CGSSetSymbolicHotKeyEnabled`. That needs only Accessibility, which WinMux already has. AltTab's id 6 is force quit on this Mac, not cmd+`, so it has been disabling the wrong hotkey.
- **Where it goes:** a small reconciler called from `applyHotkeyEnabledState()`, which already runs on mode change, `enable off`, reload and shortcut recording. It matches the active bindings against the *live* symbolic-hotkey table instead of hardcoded ids, and restores only the ids it disabled (Prateek has id 28 turned off himself). So `cmd-tab = 'lens recent'` and `cmd-backtick = 'lens app-windows'` stay ordinary bindings.
- **Restoring:** a disabled symbolic hotkey outlives the process, and release builds catch no termination signals. So the reconciler records a marker before disabling anything, arms signal and uncaught-exception handlers first, and repairs on launch, wake and unlock. A `kill -9` still leaves cmd+tab dead until WinMux next launches.
- **Commit on release costs nothing new.** The existing `flagsChanged` monitor sees modifier releases; AltTab #5911 was an active trackpad tap, not a keyboard one. `lens` checks whether the invoking modifiers are already up and commits immediately if so, which covers the quick tap.
- **Left for the implementing spec:** whether to also disable 27 and 220 (cmd+` and its reverse) as insurance. It isn't needed for the Carbon hotkey to fire, and it would leave cmd+` dead after a hard kill.

[findings](../research/25-system-switcher-takeover.md)
