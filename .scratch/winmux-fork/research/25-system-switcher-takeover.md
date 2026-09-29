# Research: taking over cmd-tab and cmd-backtick from the system

Researched 2026-09-29 for [issue 25](../issues/25-research-system-switcher-takeover.md), on macOS 26.4.1 (25E253) with the Command Line Tools macOS SDK. Anything marked **UNVERIFIED** rests on a single secondary claim or on reasoning, not on a test here.

## Sources

- **[WM]** WinMux, this worktree (`prateek/wayfind-fork`).
- **[HK]** soffes/HotKey at tag `v0.2.1` (the exact pin in `Package.swift:28`), commit `a3cf605d`. No SwiftPM checkout exists in this worktree or DerivedData, so I cloned the tag.
- **[AT]** lwouis/alt-tab-macos at `0d9d7107` (2026-09-26). GPL-3: design only, cited by file and function. Commits `ffc3cbea`, `c75aac58`, `848ae5f`, `1a85669b`; issues #1622, #5178, #5911.
- **[SDK]** `MacOSX.sdk` headers and `.tbd` stubs: `HIToolbox.framework/Headers/CarbonEvents.h`, `CarbonEventsCore.h`, `CoreGraphics.framework/CoreGraphics.tbd`, `PrivateFrameworks/SkyLight.framework/SkyLight.tbd`.
- **[Probe]** Two throwaway Swift binaries run on this Mac. `sym` reads `CGSGetSymbolicHotKeyValue` and `CGSIsSymbolicHotKeyEnabled`. `reg` calls `RegisterEventHotKey` and unregisters straight away. Neither changes system state.
- **[Lan]** peacock0803sz/Lanterna PR #28 (merged 2026-09-11). It takes over cmd-tab on macOS 26 and was hand-tested on 26.6.2.
- **[Vor]** vorssaint/vorssaint-utils PR #882 (merged 2026-09-01) and issue #1336: a cmd-tab takeover built with the same private API.

## 1. Can Carbon `RegisterEventHotKey` take cmd-tab or cmd-backtick?

Registration succeeds for cmd-backtick. For cmd-tab it also succeeds, but on its own the hotkey never fires.

- HotKey registers through `RegisterEventHotKey(..., GetEventDispatcherTarget(), 0, ...)`, which is non-exclusive, and installs handlers for both `kEventHotKeyPressed` and `kEventHotKeyReleased` [HK `Sources/HotKey/HotKeysController.swift:60-67, 150-158`]. When registration fails it just `return`s, with no error or log [HK `:70-72`], so WinMux cannot tell that a binding is dead.
- [Probe] With no AltTab, WinMux or AeroSpace running:

  | Chord | non-exclusive | `kEventHotKeyExclusive` |
  |---|---|---|
  | cmd-tab (kc 48) | `noErr` | **-9878 `eventHotKeyExistsErr`** |
  | cmd-backtick (kc 50) | `noErr` | `noErr` |

  The header says an exclusive registration fails when another registration for the same key and modifiers already exists [SDK `CarbonEvents.h:15404-15424`; `CarbonEventsCore.h:152`]. So some other process holds cmd-tab and nothing holds cmd-backtick. **UNVERIFIED:** which process holds it (probably the Dock), and whether disabling symbolic hotkey 1 releases it.
- AltTab's design note: the Dock matches cmd-tab and cmd-shift-tab "inside the WindowServer's symbolic-hotkey layer, ahead of any app's Carbon hotkey", so those two have to be switched off first. Cmd-backtick is handled by AppKit inside the front app after Carbon has already matched the hotkey, so a Carbon hotkey takes it with nothing disabled [AT `src/macos/api-wrappers/CGSSymbolicHotKey.swift:9-20`; `NativeHotkeyResolverSpecs.md` §Summary, test C]. [Lan] independently shows the same thing on macOS 26: a Carbon hotkey plus `CGSSetSymbolicHotKeyEnabled` off is enough for cmd-tab. **UNVERIFIED here:** I pressed no keys. The probe only shows that registration is accepted.

## 2. What AltTab does

**Mechanism: Carbon hotkeys, a private symbolic-hotkey toggle, and a passive tap.** No active keyboard tap takes cmd-tab.

- Every shortcut, cmd-tab included, is a non-exclusive `RegisterEventHotKey` on `GetEventDispatcherTarget()`, with separate pressed and released handlers [AT `src/events/KeyboardEvents.swift:178-194, 244-265`]. Their comment says `GetEventMonitorTarget` would require Accessibility and the dispatcher target does not [AT `:7-8`]. [Lan] says the same.
- `CGSSetSymbolicHotKeyEnabled(id, Bool)` is declared through `@_silgen_name` [AT `src/macos/api-wrappers/SkyLight.framework.swift:92-102`]. The pure function `NativeHotkeyResolver.resolve` decides which ids to disable, and `ControlsTab.toggleNativeCommandTabIfNeeded` applies the result every time a shortcut changes [AT `ControlsTab.swift:722-751`]. Disabling cmd-tab also disables cmd-shift-tab. Issue #5653 (commit `c75aac58`) was a bug where one shortcut matched two native predicates but only one of them was disabled.
- **The ids, checked on this Mac with [Probe] `sym`** (modifiers are `CGEventFlags`, 0x100000 = cmd):

  | id | chord | keycode | enabled here |
  |---|---|---|---|
  | 1 | cmd-tab | 48 | yes |
  | 2 | cmd-shift-tab | 48 | yes |
  | 6 | cmd-opt-shift-esc (force quit) | 53 | yes |
  | 27 | cmd-backtick, "Move focus to next window" | 50 | yes |
  | 28 | cmd-shift-3 (screenshot) | 20 | **no, the user turned it off** |
  | 220 | cmd-shift-backtick | 50 | yes |

  AltTab disabled **id 6**, believing it was cmd-backtick, from 2022 (`848ae5f`, "command+backtick not working if stage manager is on") until 2026-09-17 (`ffc3cbea`). The table above confirms their fix: 6 is force quit. [Vor] #882 disables "27 and 28" for window switching, but in the live table 28 is cmd-shift-3. [Vor] #1336 admits this, and the probe agrees.
- **Permissions.** `CGSSetSymbolicHotKeyEnabled` needs none ([Lan]: "No new permission"). The CGEvent taps need Accessibility; `tapCreate` returns nil without it [AT `KeyboardEvents.swift:207`]. WinMux already requires Accessibility (`Sources/AppBundle/util/accessibility.swift:8`).
- **Persistence and restore.** "The effect of enabling/disabling persists after the app is quit" [AT `SkyLight.framework.swift:94`; issue #1622: after a force-quit from Activity Monitor, cmd-tab stayed dead]. AltTab re-enables in four places:
  - `applicationWillTerminate` [AT `src/App.swift:658-661`].
  - `emergencyExit`, reached from a synchronous `SIGTRAP` handler.
  - Dispatch sources for `SIGTERM`, `SIGINT` and `SIGHUP`, after unblocking the signal mask.
  - `NSSetUncaughtExceptionHandler`.

  All four call `setNativeCommandTabEnabled(true)` and then `_exit` [AT `src/main.swift:8-80`]. Nothing survives `SIGKILL`. [Vor] covers that case with a write-ahead marker: it records which ids it disabled before disabling them and repairs them on the next launch. It also restores only ids that were enabled beforehand. [Lan] arms its signal handlers *before* the first disable and restores by writing "enabled" unconditionally.
- **The OS re-enables on its own.** Issue #5178: after a reboot cmd-tab sometimes goes back to the system until AltTab is restarted. The maintainer's guess is "the OS overrides our change". AltTab does not re-apply on a timer.
- **Public alternative, rejected.** `PushSymbolicHotKeyMode` is public but disables *all* symbolic hotkeys (Spotlight, screenshots and the rest). It only takes effect while the calling app is frontmost and reverts when the app deactivates [SDK `CarbonEvents.h:15640-15671`]. A background window manager is never frontmost when cmd-tab is pressed.
- **Not investigated:** the SDK exports `CGSSetSymbolicHotKeyEnabledForConnection` and `CGSIsSymbolicHotKeyEnabledForConnection` [SDK `CoreGraphics.tbd`; `SLS…` twins in `SkyLight.tbd`]. If the disable is scoped to our connection, it might undo itself when the process dies. **UNVERIFIED.** The signature is unknown and no project I read uses it. Worth a spike, but don't design around it.

## 3. Detecting modifier release for a strip's commit-on-release

- **AltTab:** a permanent `.cgSessionEventTap` with `.listenOnly` on `flagsChanged` and `keyDown` drives hold-and-release [AT `KeyboardEvents.swift:13-15, 30-52, 206-225`]. The only active keyboard tap is an HID `keyDown` tap that absorbs Esc, and it is enabled only while the switcher is open. Leaving it on during normal typing broke third-party IMEs (#5766) [AT `:16-20, 142-155`]. Their comment adds that SecureInput filters `keyDown` from both kinds of tap but not `flagsChanged` [AT `:207-209`].
- **The race.** Carbon delivers hotkeys on the main run loop, while the tap runs on its own thread. If main stalls, a quick cmd-tab tap can deliver cmd-up *before* the hotkey arrives, and at that point the live modifier state already belongs to a later gesture. `GetEventTime` returns the dequeue time, not the press time. AltTab solves this with `ModifierReleaseLog`, which pairs each Carbon key-down with the release that followed it [AT `src/events/ModifierReleaseLog.swift:4-28`], and with a state machine tested against dropped and reordered events [AT `KeyboardEventsSpecs.md`].
- **Cost, and what #5911 was about.** #5911 ("unusable dock and menu", macOS 27) came from an *active* `cghidEventTap` on the **gesture** stream. The WindowServer waits for an active tap's callback on every event queued behind it, including mouse moves, and CPU looked idle because every process was blocked rather than busy. The fix split it into an always-on listen-only tap and an active tap armed only while the switcher is open ("Listening costs the WindowServer nothing") [AT commit `1a85669b`; `src/events/TrackpadEvents.swift:5-19`]. A listen-only `flagsChanged` stream fires only on modifier transitions, so its cost is negligible.
- **WinMux already has the signal.** Global and local `NSEvent` `flagsChanged` monitors feed `noteTapBindingFlagsChanged` [WM `GlobalObserver.swift:68-74, 159-163`]. A global NSEvent monitor is passive. Commit-on-release adds no new tap. **UNVERIFIED:** whether the global NSEvent monitor still receives `flagsChanged` under SecureInput, as AltTab's CG tap does.

## 4. Interaction with the user's keyboard settings

- **27** ("Move focus to next window") and **220** (reverse) are listed in System Settings → Keyboard → Keyboard Shortcuts → Keyboard, where the user can remap or turn them off. **1 and 2** are not user-editable there (**UNVERIFIED**, from memory of the pane; the live table is authoritative either way). Only customised entries appear in `~/Library/Preferences/com.apple.symbolichotkeys.plist`: on this Mac neither 1 nor 27 has an entry, while 28 appears as `{ enabled = false }` and the live table agrees. So read the **live** table (`CGSGetSymbolicHotKeyValue`/`CGSIsSymbolicHotKeyEnabled`), not the plist. [Vor] #1336 found the same thing.
- A runtime disable doesn't change the checkbox in System Settings [Vor #1336]. If the user unticks an id while WinMux holds it and WinMux later restores it, the user's choice is overwritten. [Vor] #1336 plans to check the live state before restoring. Nothing I read describes how System Settings and a runtime disable interact in detail. **UNVERIFIED.**
- WinMux spells the key `cmd-backtick` (`KeyMappingPresets.swift:174` → `.grave`, kc 50), not `` cmd-` ``. On ISO keyboards the key above Tab is `sectionSign` (kc 10); a live-table match keeps that case correct.

## 5. Recommendation

Keep `cmd-tab = 'lens recent'` and `cmd-backtick = 'lens app-windows'` as ordinary `[mode.main.binding]` entries, registered through HotKey as they are now. Add a small **system-shortcut reconciler** (one new file under `Sources/AppBundle/config/`) that `applyHotkeyEnabledState()` [WM `HotkeyBinding.swift:230-235`] calls after it sets each HotKey's `isEnabled`. That function already runs on mode change, `enable off` (`activateMode(nil)`, `EnableCommand.swift:36-38`), config reload and shortcut-recorder suspension. The reconciler:

1. Computes the set of chords WinMux is listening for right now: enabled bindings in the active mode, and none while suspended or disabled.
2. Scans the live symbolic table once per reload (ids 0 to about 300, cached) and matches each chord's keycode and modifiers. Don't hardcode 1, 2 and 27. Only ids that are currently **enabled** are candidates. Treat 27 and 220 the same way as 1 and 2, even though AltTab says 27 doesn't need it; that is cheap insurance for the Stage Manager report (#2053) and [Vor]'s "affected setups". Binding cmd-tab also takes cmd-shift-tab, as AltTab does.
3. Writes a write-ahead marker (UserDefaults: the ids WinMux disabled) **before** calling `CGSSetSymbolicHotKeyEnabled(id, false)`. Ids that are no longer wanted are restored and removed from the marker.
4. Restores on every exit path. Today only a menu-bar quit runs `beforeTermination` [WM `ui/menubar/MenuBar.swift:43`]. `interceptTermination` covers only SIGINT and only in debug builds [WM `initAppBundle.swift:11-14`], and `die()` never reaches it [WM `Common/util/commonUtil.swift:169`]. Add dispatch-source handlers for SIGTERM, SIGINT and SIGHUP and an uncaught-exception handler that restore the marker's ids synchronously before doing anything else, armed before the first disable.
5. Repairs and re-applies on launch (from the marker), `didWake`/`screensDidWake` and screen unlock. The observers for these already exist [WM `GlobalObserver.swift:13, 106-107`], and they cover #5178.
6. Commits a strip on release using the existing `flagsChanged` monitor. When `lens` runs, first sample `CGEventSource.flagsState(.combinedSessionState)`; if the invoking modifiers are already up, commit immediately without drawing. That gives ticket 07's quick-tap swap, and a cheap guard against the Carbon/main-thread race, without porting `ModifierReleaseLog`.
7. Makes failures visible. Log HotKey registrations (fork the status check or register through a thin wrapper, since HotKey swallows the error), and add a `winmux doctor` line showing the symbolic ids held and the marker contents.

### Failure modes

| Failure | Effect | Mitigation |
|---|---|---|
| `SIGKILL`, kernel panic, power loss | cmd-tab stays disabled with WinMux gone | Marker repair on next launch. **UNVERIFIED** whether logout or reboot resets it anyway (#5178 hints a reboot sometimes does). |
| OS re-enables after reboot or wake | cmd-tab opens the native switcher and WinMux's hotkey stays silent | Re-apply on launch, wake and unlock. There is no event to hook if it happens at another time. |
| Private API removed or changed in a future macOS | cmd-tab stays native, and Lens triggers on it fail silently | Check the `CGError` result and read back with `CGSIsSymbolicHotKeyEnabled`; `doctor` reports it. Cmd-backtick still works through plain Carbon. |
| User changes Keyboard Shortcuts while WinMux holds an id | A later restore may overwrite the user's choice | Re-scan on reload and restore only ids in the marker (optionally only if still unchanged). |
| Main-thread stall | Commit-on-release acts on the wrong gesture, or a quick tap opens a sticky strip | Sample flags when `lens` runs; if the problem shows up, port a release-log design. |
| Another switcher (AltTab, Vorssaint) running | Both get the non-exclusive Carbon hotkey, so two overlays appear | Document it. `kEventHotKeyExclusive` would starve the other app, but cmd-tab already fails exclusive registration (§1). |
| Disabling 27 and 220 too (step 2) | After a `SIGKILL`, cmd-backtick goes dead along with cmd-tab until the marker repair runs. With AltTab's approach cmd-backtick keeps working natively | Accept, or leave 27 and 220 alone unless a test shows Carbon losing to them |
| Fast user switching | **UNVERIFIED** whether symbolic state is per session ([Vor] #1236/#1304 needed tap hand-back on user switch) | Re-apply on session activation. |
