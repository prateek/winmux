# Strip Presentation and the cmd+tab takeover

Part of {{UMBRELLA}}.

## What to build

Build the `'strip` Presentation: a single centred row of a Lens's matches that is cycled while the invoking modifiers are held and commits when they are released. Ship the two Lenses that use it, `recent` on `cmd-tab` and `app-windows` on `cmd-backtick`, and make those two bindings actually fire by taking the chords away from macOS. After this issue, cmd+tab and cmd+backtick open WinMux Lenses in place of the native ones, and the system chords come back whenever WinMux stops listening for them.

## Decisions

**The strip is the Lens machinery with a one-row layout**

- The strip is not a second system. It uses the Lens's Filter, sort order, selection, `keys` actions, Summon, thumbnail cache and overlay panel, and adds only a one-row layout and hold-to-cycle.
- The strip has no settings record of its own. It reads the Lens-level fields `frozen_thumbnail`, `accessory_window` and `summon_hints`, which every Presentation reads.
- A strip ignores `sections`. `entries` defaults to one entry per window. `sort` defaults to MRU order with the current window first, and the selection starts on the second entry.
- The strip has no Search box, because letters typed while cmd is held are chords.
- The panel is non-activating. It must not call `NSApp.activate` or `makeKey` the way `SwitcherPalette` does today (`Sources/AppBundle/ui/hud/SwitcherPalette.swift`); the app that had focus keeps it until the strip commits.
- Committing a selection asks the OS to focus the window and does not write MRU itself. MRU moves only when the OS confirms the focus, which is what `lastFocusedSeq` already guarantees.

**Entry look**

- Each entry shows a thumbnail with the app icon and the window title.
- Until Thumbnail cache and the `'miniatures` Presentation lands, the strip shows the app icon and title only. Once the cache exists, an entry with no capture still shows the app icon.
- A Frozen thumbnail is marked as the Lens's `frozen_thumbnail` says. The shipped default is `'dimmed`.
- While Summon's modifier is held, the strip shows what the Lens's `summon_hints` lists. The shipped default is `'label` plus `'landing_spot`: a "Summon to N" label on the selected entry, and a dashed outline on the screen itself where the window will land.

**Placement**

- The strip is centred on the screen.
- When the row runs out of room it scrolls, keeps the selection in view, and shows a "+N" count at each end for the entries that are out of view.

**Hold and release**

- When the `lens` command opens a strip, it records which modifiers were held at that moment. Releasing those modifiers commits.
- Committing runs the command bound to `enter` in the Lens's `keys` map (focus by default), unless a modifier held at release selects another binding.
- Summon at release is Option: holding Option when the invoking modifiers are released runs `summon` on the selection. Shift held at release never selects a binding in a strip, because Shift reverses the cycle. `shift-enter` stays Summon in `'list` and `'miniatures`.
- There is a 100 ms display delay. If the invoking modifiers are released within it, the strip never draws and the commit lands on the initial selection, which swaps to the previous window.
- When `lens` runs, it first samples the live modifier state (`CGEventSource.flagsState(.combinedSessionState)`). If the invoking modifiers are already up, it commits at once without drawing. This covers the quick tap and guards against the Carbon event arriving after the release.
- Modifier releases come from the existing `flagsChanged` monitor (`GlobalObserver.swift`, feeding `noteTapBindingFlagsChanged`). No new event tap is added for commit on release.
- There is no stay-open variant of the strip. A Lens that should stay open uses `'list`.

**Keys while the strip is open**

- Pressing the invoking key again moves the selection forward and wraps at the end.
- Reverse is Shift plus the invoking key: `shift-tab` in `recent`, `shift-backtick` in `app-windows`. The backtick key does not reverse `recent`, which differs from the native cmd+tab.
- `esc` closes the strip and leaves focus unchanged.
- The Lens's other `keys` bindings apply in a strip as in any Presentation. The Lens defaults are `cmd-w` for `close` and `cmd-<n>` for `move-node-to-workspace <n>`. See Open details for a letter that is also a binding.
- With the mouse, hovering moves the selection, a click runs `enter`'s command, and a modifier-click runs the matching modifier binding.

**Hand-off to Search**

- Typing a letter turns the strip into the `'list` Presentation of the same Lens, through `lens --presentation list`. The typed letter goes into the Search box, and the Filter, sort and selection carry over.
- After the hand-off the Lens behaves as any `'list` Lens: it stays open when the modifiers are released.

**The two default Lenses**

- `recent`: a strip over every window, sorted by MRU, opened by `cmd-tab` running `lens recent`.
- `app-windows`: a strip over the windows whose app has the same bundle id as the focused window's app, sorted by MRU, opened by `cmd-backtick` running `lens app-windows`. `cmd-backtick` is WinMux's spelling of the chord.
- The `app-windows` Filter must handle `ctx.focused` being `null`, because the load-time smoke run calls every Filter once with no focused window. It matches nothing in that case.
- Both Triggers are ordinary entries in `mode.main.binding`. The user can rebind or remove them like any other binding.

**Taking cmd+tab and cmd+backtick from the system**

- Bindings stay registered through the `HotKey` package (Carbon `RegisterEventHotKey`), as every binding is today.
- A Carbon hotkey takes `cmd-backtick` directly. Nothing has to be turned off for it to fire.
- A Carbon hotkey on `cmd-tab` registers without error but never fires while the system's symbolic hotkey for it is on. WinMux turns off symbolic hotkeys 1 (cmd-tab) and 2 (cmd-shift-tab) with the private `CGSSetSymbolicHotKeyEnabled`. Binding `cmd-tab` always takes `cmd-shift-tab` with it. This needs only the Accessibility permission WinMux already has.
- The work is done by a small reconciler called from `applyHotkeyEnabledState()` (`Sources/AppBundle/config/HotkeyBinding.swift`). That function already runs on mode change, `enable off`, config reload and while the shortcut recorder suspends bindings, so the reconciler needs no other call sites for those cases.
- The reconciler computes the chords WinMux is listening for right now: the enabled bindings of the active mode, and none while bindings are suspended or WinMux is disabled.
- It matches those chords, by keycode and modifiers, against the live symbolic-hotkey table (`CGSGetSymbolicHotKeyValue`, `CGSIsSymbolicHotKeyEnabled`). It does not hardcode ids and does not read `com.apple.symbolichotkeys.plist`, which lists only customised entries. Matching the live table also keeps ISO keyboards correct, where the key above Tab has a different keycode.
- Only ids that are enabled at that moment are candidates for disabling. An id the user had already turned off is never touched.
- Before disabling anything, the reconciler records a marker listing the ids it is about to disable. It restores only ids in the marker, and removes an id from the marker once it is restored.
- When a chord is no longer wanted (the binding was removed, the mode changed, WinMux was disabled), the reconciler restores the matching ids.

**Restoring and repairing**

- A disabled symbolic hotkey outlives the process, and release builds catch no termination signals today. Signal handlers and an uncaught-exception handler that restore the marker's ids are armed before the first disable.
- The reconciler repairs from the marker and re-applies on launch, on wake and on screen unlock. The observers for wake and unlock already exist in `GlobalObserver.swift`. This also covers macOS turning the system chord back on by itself after a reboot.
- A hard kill (`kill -9`, a kernel panic, power loss) leaves cmd+tab dead until WinMux next launches, when the marker repair runs. This is accepted.

**Known failure behaviour**

- If the private API stops working on a later macOS, `cmd-tab` stays native and the `recent` Trigger never fires. `cmd-backtick` keeps working through plain Carbon.
- If another app that takes cmd+tab is running, both receive the non-exclusive Carbon hotkey and two overlays appear. This is documented, not prevented.

## Not in this issue

- The `lens` command, the Lens record, `keys` actions, `summon`, Search, the `'list` Presentation and `lens --presentation list` itself: Lens core and the `'list` Presentation with Search.
- `lastFocusedSeq` and MRU order: Global MRU (`lastFocusedSeq`).
- Capturing thumbnails and the cache: Thumbnail cache and the `'miniatures` Presentation.
- Where a Summoned window lands (the `place` hook): Column Policy hooks and Column commands. Until it exists, the landing spot is wherever the built-in insertion would put the window.
- `alt-slash`, the `lens` leader mode (including `r` opening `recent` as a list) and the `lens-opened` and `lens-closed` events: Default config, Triggers, the `lens` leader mode, `subscribe` events.
- Deferred: trackpad-gesture Triggers for the strip, and placing the strip over the focused Column on an ultrawide, which waits for Display profiles.

## Depends on

- Lens core and the `'list` Presentation with Search
- Thumbnail cache and the `'miniatures` Presentation, for thumbnails only. The strip ships with icon and title before it.

## Open details

Settle each of these while building and note the choice in the PR.

- **Symbolic hotkeys 27 and 220.** These are cmd+backtick ("Move focus to next window") and its reverse. The Carbon hotkey fires without disabling them. Disabling them too is insurance against setups where the system chord wins, but then a hard kill leaves cmd+backtick dead as well as cmd+tab. Decide whether the reconciler disables them.
- **How the strip receives keys other than the Trigger.** The panel is non-activating, so `shift-tab`, `esc`, the arrows, letters and the `keys` bindings do not reach it as ordinary key events. Options include registering extra Carbon hotkeys while the strip is open, or an event tap armed only while it is open. An always-on active tap is a known hazard for input methods and must be avoided.
- **Opening a strip with no modifiers held.** The sample-the-flags decision means `winmux lens recent` from a shell commits at once and swaps to the previous window without drawing. Confirm that this is the intended behaviour for the CLI and for a Trigger with no modifiers.
- **`cmd-shift-tab` with no strip open.** Symbolic hotkey 2 is disabled, so the chord does nothing unless it is bound. Decide whether it opens `recent` with the selection on the last entry.
- **A letter that is also a `keys` binding.** `cmd-w` is a letter typed while cmd is held, and it is also the default `close` binding. Decide which wins: the `keys` binding or the hand-off to `'list`.
- **How Summon at release is spelled in the `keys` map.** The decision is that Option at release runs `summon`. Whether that is a default `alt-enter` entry in the Lens's `keys` map, and how it sits beside `shift-enter` for a Lens that is also opened as a list, was not written down.
- **`accessory_window` and `'target_workspace` in a one-row layout.** Both were defined for `'miniatures`, where windows are drawn to scale inside their workspace. The strip prototype drew an Accessory app window smaller, with a dashed outline and a "menu-bar app" caption. Decide what the two values of `accessory_window` and the `'target_workspace` hint do in a strip.
- **Arrow keys.** In the prototype the left and right arrow keys also moved the selection. This was not written down as a decision.
- **One match or none.** With one match the prototype put the selection on it. With no match nothing was decided.
- **Summon hints for a window already on the current workspace.** The prototype showed the label and landing spot only when the selected window was on another workspace. This was not written down as a decision.
- **How many entries fit before the row scrolls.** The prototype used 9 as a starting value. No number was decided.
- **Marker storage and visibility.** The research recommends keeping the marker in `UserDefaults`, checking the `CGError` from `CGSSetSymbolicHotKeyEnabled` and reading the result back, logging `HotKey` registration failures (the package swallows them), and adding a `winmux doctor` line with the ids held and the marker contents. None of these was decided.
- **Restoring an id the user changed meanwhile.** If the user turns a system chord off in System Settings while WinMux holds it, a later restore overwrites that choice. Decide whether to restore only when the id is still in the state WinMux left it.
- **Unverified platform behaviour.** Whether the global `flagsChanged` monitor still fires under Secure Input, and whether symbolic-hotkey state is per login session (fast user switching), were not tested.

## Done when

- [ ] Holding cmd and pressing tab opens `recent`: a centred row of every window in MRU order, with the selection on the second entry.
- [ ] Each further tab press moves the selection forward, `shift-tab` moves it back, and backtick does not move it in `recent`.
- [ ] Releasing cmd focuses the selected window, switching workspace if needed. The strip never becomes the active app while open.
- [ ] Releasing cmd with Option held runs `summon`: the selected window moves into the current workspace.
- [ ] While Option is held on a window from another workspace, the selected entry shows "Summon to N" and the landing spot is outlined on the screen.
- [ ] A cmd+tab released within 100 ms swaps to the previous window and the strip never draws.
- [ ] `esc` closes the strip and focus is unchanged.
- [ ] Holding cmd and pressing backtick opens `app-windows` with only the focused app's windows. `shift-backtick` reverses it.
- [ ] Typing a letter in an open strip reopens the same Lens as `'list` with that letter in the Search box and the same window selected.
- [ ] With more matches than fit, the row scrolls with the selection and shows "+N" at each end that has hidden entries.
- [ ] Entries show icon and title with no thumbnail cache, and thumbnails with Frozen thumbnails dimmed once the cache exists.
- [ ] `winmux lens recent` and `winmux lens app-windows` open the two Lenses, `winmux lens recent --presentation list` opens `recent` as a list, and `winmux lens --filter <name|body> --presentation strip` opens an ad-hoc strip.
- [ ] `winmux list-lenses --json` lists `recent` and `app-windows` with the strip Presentation.
- [ ] With `cmd-tab` bound, the native cmd+tab no longer appears. After removing the binding and reloading the config, after switching to a mode without it, and after `enable off`, the native cmd+tab works again.
- [ ] After a normal quit, `SIGTERM`, `SIGINT` or `SIGHUP`, the native cmd+tab works again.
- [ ] After `kill -9`, cmd+tab does nothing until WinMux is launched again, and it works after that launch.
- [ ] After sleep and wake, and after unlocking the screen, cmd+tab still opens `recent`.
- [ ] A symbolic hotkey the user had turned off before WinMux started is still off after WinMux quits.

## Sources

- [Prototype: strip Presentation look and keyboard model](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/29-prototype-strip-presentation.md)
- [Strip Presentation prototype](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/prototypes/29-strip-presentation.html)
- [Grilling: Lens configuration shape](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/07-grilling-picker-binding-shape.md)
- [Research: taking over cmd+tab and cmd+` from the system](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/25-research-system-switcher-takeover.md)
- [Research findings: taking over cmd-tab and cmd-backtick from the system](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/25-system-switcher-takeover.md)
- [Research: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/03-research-thumbnails-and-alttab.md)
- [Research findings: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md)
- [Grilling: cmd-K search Lens](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/19-grilling-cmd-k-search.md)
