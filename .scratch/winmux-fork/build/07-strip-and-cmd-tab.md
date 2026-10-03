# Strip Presentation and the cmd+tab takeover

Part of {{UMBRELLA}}.

## What to build

Build the `'strip` Presentation: a single centred row of a Lens's matches that is cycled while the invoking modifiers are held and commits when they are released. Ship the two Lenses that use it, `recent` on `cmd-tab` and `app-windows` on `cmd-backtick`, and make those two bindings actually fire by taking the chords away from macOS. Taking them needs three new pieces: a reconciler that turns the matching system chords off and back on, handlers that restore them on every exit WinMux can catch, and a screen-unlock observer beside the wake observers WinMux already has. After this issue, cmd+tab and cmd+backtick open WinMux Lenses in place of the native ones, and the system chords come back whenever WinMux stops listening for them.

## Decisions

**The strip is the Lens machinery with a one-row layout**

- The strip is not a second system. It uses the Lens's Filter, sort order, selection, `keys` actions, Summon, thumbnail cache and overlay panel, and adds only a one-row layout and hold-to-cycle.
- The strip has no settings record of its own. It reads the Lens-level fields `frozen-thumbnail`, `accessory-window` and `summon-hints`, which every Presentation reads.
- A strip ignores `sections`. `entries` defaults to one entry per window. `sort` defaults to MRU order with the current window first, and the selection starts on the second entry.
- The strip has no Search box, because letters typed while cmd is held are chords.
- The panel is non-activating, and WinMux never becomes the active app while a strip is open. The strip must not call `NSApp.activate` the way `SwitcherPalette` does today (`Sources/AppBundle/ui/hud/SwitcherPalette.swift`); the app that had focus keeps it until the strip commits. How the panel receives keys without activating is under Open details.
- Committing a selection asks the OS to focus the window and does not write MRU itself. MRU moves only when the OS confirms the focus, which is what `lastFocusedSeq` already guarantees.

**Entry look**

- Each entry shows a thumbnail with the app icon and the window title.
- Until Thumbnail cache and the `'miniatures` Presentation lands, the strip shows the app icon and title only. Once the cache exists, an entry with no capture still shows the app icon.
- A Frozen thumbnail is marked as the Lens's `frozen-thumbnail` says. The shipped default is `'dimmed`.
- While Summon's modifier is held, the strip shows what the Lens's `summon-hints` lists. The shipped default is `'label` plus `'landing-spot`: a "Summon to N" label on the selected entry, and a dashed outline on the screen itself where the window will land.

**Placement**

- The strip is centred on the screen.
- When the row runs out of room it scrolls, keeps the selection in view, and shows a "+N" count at each end for the entries that are out of view.

**Hold and release**

- When the `lens` command opens a strip, it records which modifiers were held at that moment. Releasing those modifiers commits.
- Committing runs the command bound to `enter` in the Lens's `keys` map (focus by default), unless a modifier held at release selects another binding.
- Summon at release is Option: holding Option when the invoking modifiers are released runs `summon` on the selection. Shift held at release never selects a binding in a strip, because Shift reverses the cycle. `shift-enter` stays Summon in `'list` and `'miniatures`.
- There is a 100 ms display delay. If the invoking modifiers are released within it, the strip never draws and the commit lands on the initial selection, which swaps to the previous window.
- When `lens` runs, it first samples the live modifier state (`CGEventSource.flagsState(.combinedSessionState)`). If the invoking modifiers are already up, it commits at once without drawing. This covers the quick tap and guards against the Carbon event arriving after the release.
- Modifier releases come from the existing `flagsChanged` monitor (`Sources/AppBundle/GlobalObserver.swift`, feeding `noteTapBindingFlagsChanged`). No new event tap is added for commit on release.
- There is no stay-open variant of the strip. A Lens that should stay open uses `'list`.

**Keys while the strip is open**

- Pressing the invoking key again moves the selection forward and wraps at the end.
- Reverse is Shift plus the invoking key: `shift-tab` in `recent`, `shift-backtick` in `app-windows`. The backtick key does not reverse `recent`, which differs from the native cmd+tab.
- `esc` closes the strip and leaves focus unchanged.
- The Lens's other `keys` bindings apply in a strip as in any Presentation. The Lens defaults are `cmd-w` for `close` and `cmd-<n>` for `move-node-to-workspace <n>`.
- With the mouse, hovering moves the selection, a click runs `enter`'s command, and a modifier-click runs the matching modifier binding.

**Hand-off to Search**

- Typing a letter turns the strip into the `'list` Presentation of the same Lens, through `lens --presentation list`. The typed letter goes into the Search box, and the Filter, sort and selection carry over.
- After the hand-off the Lens behaves as any `'list` Lens: it stays open when the modifiers are released.

**The two default Lenses**

- Both Lenses are defined in the shipped `defaults.ncl`, which a user's config imports and merges over. This issue adds them there, together with their bindings.
- `recent`: a strip over every window, sorted by MRU, opened by `cmd-tab` running `lens recent`.
- `app-windows`: a strip over the windows whose app has the same bundle id as the focused window's app, sorted by MRU, opened by `cmd-backtick` running `lens app-windows`. `cmd-backtick` is WinMux's spelling of the chord.
- The `app-windows` Filter is the named Filter `filters.same-app`, also defined in `defaults.ncl`: `fun w ctx => ctx.focused != null && ctx.focused.app.bundleId == w.app.bundleId`. It must handle `ctx.focused` being `null`, because the load-time smoke run calls every Filter once with no focused window. It matches nothing in that case.
- Neither Lens sets `popups`, the Lens field that lists the popup Window classes a Lens includes. It is empty by default, so "every window" leaves out `'accessory-popup` and `'app-popup` windows: they never reach the Filter.
- Both Triggers are ordinary entries in `mode.main.binding`. The user can rebind or remove them like any other binding.

**Taking cmd+tab and cmd+backtick from the system**

- "Symbolic hotkey" is Apple's term for a chord the system owns, such as the native cmd+tab, and "Carbon hotkey" is the name of the registration API. Both name system mechanisms in this issue. A WinMux binding that opens a Lens is a Trigger.
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
- The reconciler repairs from the marker and re-applies on launch, on wake and on screen unlock. This also covers macOS turning the system chord back on by itself after a reboot.
- The wake observers exist: `NSWorkspace.didWakeNotification` and `NSWorkspace.screensDidWakeNotification` in `Sources/AppBundle/GlobalObserver.swift`. WinMux has no unlock observer. This issue adds one, for `com.apple.screenIsUnlocked` on `DistributedNotificationCenter`.
- A hard kill (`kill -9`, a kernel panic, power loss) leaves cmd+tab dead until WinMux next launches, when the marker repair runs. This is accepted.

**Known failure behaviour**

- If the private API stops working on a later macOS, `cmd-tab` stays native and the `recent` Trigger never fires. `cmd-backtick` keeps working through plain Carbon.
- If another app that takes cmd+tab is running, both receive the non-exclusive Carbon hotkey and two overlays appear. This is documented, not prevented.

## Not in this issue

- The `lens` command, the Lens record (including the `popups` field), `keys` actions, `summon`, Search, the `'list` Presentation and `lens --presentation list` itself: Lens core and the `'list` Presentation with Search.
- `lastFocusedSeq` and MRU order: Global MRU (`lastFocusedSeq`).
- Capturing thumbnails and the cache: Thumbnail cache and the `'miniatures` Presentation.
- Where a Summoned window lands (the `place` hook): Column Policy hooks and Column commands. Until it exists, the landing spot is wherever the built-in insertion would put the window.
- `alt-slash`, the `lens` leader mode (including `r` opening `recent` as a list) and the `lens-opened` and `lens-closed` events: Default config, Triggers, the `lens` leader mode, `subscribe` events.
- Deferred: trackpad-gesture Triggers for the strip, and placing the strip over the focused Column on an ultrawide, which waits for Display profiles.

## Depends on

- Lens core and the `'list` Presentation with Search
- Thumbnail cache and the `'miniatures` Presentation, for thumbnails only. The strip ships with icon and title before it.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The cmd+backtick system chords stay on.** The reconciler disables a matching symbolic hotkey only for the cmd+tab pair. A match for `cmd-backtick` or its Shift variant (ids 27 and 220 in a stock table) is left on, because the Carbon hotkey fires without it, and disabling them would make a hard kill take cmd+backtick down along with cmd+tab. Disable them too only if a test shows the system chord winning over the Carbon hotkey.
- **Opening a strip with no modifiers held.** It commits at once and swaps to the previous window without drawing. This applies to `winmux lens recent` from a shell and to a Trigger with no modifiers. The way to browse `recent` with nothing held is its `'list` Presentation.
- **`cmd-shift-tab` with no strip open.** It opens `recent` with the selection on the last entry, as the native chord does. `defaults.ncl` binds `cmd-shift-tab` to `lens recent` next to `cmd-tab`, and the strip reads Shift from the invoking chord. Shift is not one of the modifiers whose release commits.
- **A letter that is also a `keys` binding.** The `keys` binding wins, so `cmd-w` closes the selected window. Only a letter with no binding hands off to `'list`.
- **How Summon at release is spelled.** The Lens `keys` defaults gain `alt-enter` for `summon`. Releasing the invoking modifiers with Option held selects it by the ordinary rule, with nothing special-cased. `shift-enter` stays beside it for a Lens that is also opened as a list.
- **`accessory-window` and `'target-workspace` in a strip.** With `'enlarged`, an Accessory app window's entry is drawn at the normal entry size with a dashed outline and a "menu-bar app" caption. With `'actual-size`, the entry is scaled down. The `'target-workspace` hint draws nothing in a strip.
- **Arrow keys.** Left and right move the selection.
- **One match or none.** With one match the selection is on it. With none the strip shows "No windows" and releasing the modifiers does nothing.
- **Summon hints for a window already on the current workspace.** The label and landing spot show only when the selected window is on another workspace. Summoning a window that is already on the current workspace does nothing.
- **How many entries fit before the row scrolls.** As many as fit the screen width, capped at 9. Tune the cap on the real build.
- **Marker storage and visibility.** The marker lives in `UserDefaults`. The reconciler checks the `CGError` from `CGSSetSymbolicHotKeyEnabled` and reads the result back with `CGSIsSymbolicHotKeyEnabled`. `HotKey` registration failures are logged, since the package swallows them. `winmux doctor` gains a line with the symbolic hotkey ids WinMux holds and the marker's contents.
- **Restoring an id the user changed meanwhile.** The reconciler restores an id only if it is still in the state WinMux left it in: still disabled, with the same key and modifiers. Otherwise it leaves the id alone and drops it from the marker.

## Open details

Checked against the debug build with owned neutral apps:

- **How a non-activating panel receives keys.** The starting approach works: the strip calls `makeKey()` on its `.nonactivatingPanel` without `NSApp.activate`. `lsappinfo front`, followed by `lsappinfo info -only name`, reported the owned app before, during and after the strip. Local panel events delivered navigation, letters and Lens `keys`; Carbon delivered the invoking chord. No temporary Carbon fallback or event tap was needed. Both Carbon and panel keys now use the same tested session input handler. The existing global `flagsChanged` monitor cannot see the key panel's releases, so the existing local monitor also feeds the strip release path; live release committed with the panel key.
- **Platform behaviour.** A focused owned `NSSecureTextField` enabled Secure Input. Key events still reached the strip: an unbound letter opened the list's Search box, and cmd release committed through local `flagsChanged`. Global `flagsChanged` also fired for down and up while the secure field itself remained key. Fast user switching is not checkable: the machine has one login session and no second user to switch to. No real password field, Terminal Secure Keyboard Entry, screen lock or sleep was used.

## Implementation and validation

The strip extends the existing Lens session and eligible-window path. `StripLayout` and `StripGesture`
provide testable geometry and hold/release rules; `StripView` reuses the miniature entry renderer,
`Window.thumbnail`, `ThumbnailAppearance`, `ThumbnailCache` and its capture gate. The cap remains
**9**: at 148-point entries on the available 1920-point display it leaves room for readable titles
and end counts. Narrower widths reduce capacity. A regression test also checks the shared onscreen snapshot: visible native-fullscreen entries stay live while inactive ones are Frozen. No chosen default changed. `alt-enter = summon`
already existed in both the Swift and Nickel Lens contracts; it is retained and tested rather than
added twice. The new Lenses, `filters.same-app` and three main-mode bindings ship in defaults.

The reconciler's CGS adapter and UserDefaults store have fake-table seams. Ownership is persisted
before disable, verified by readback, restored only for unchanged marked ids, and reconciled from
successful active Carbon registrations. HotKey 0.2.1 is vendored with its license and a small
registration-error exposure; failed registrations are logged. Launch, both wake notifications and
the new distributed unlock observer repair ownership. TERM, INT, HUP, Objective-C exception and
exit restoration are armed before disabling in all build configurations. The old debug signal
handler was removed. Live signal checks used only the debug executable; release-build behavior
remains a check for Prateek, and no release build was run.

`make check` passed 751 Swift tests and 47 helper integration tests, plus its lint, script and
format checks. Tests were written and failed before their seams/defaults were implemented.
`make default-config` was run; no contract record changed. All five Nickel examples in
`docs/lenses.md` passed `winmux-nickel check`.

Live evidence covers held cycling, reverse-first selection, Shift-only release, local release,
Search hand-off, Close staying a strip, cross-workspace Focus and Option Summon, scrolling counts,
one/no match, icon fallback, ad-hoc invocation and explicit list override. Captures use owned
windows and redact protected dialogs and unrelated desktop content. The native table was read
before launch, while held, after config removal, mode change and disable, and after normal quit,
SIGTERM, SIGINT, SIGHUP, hard kill, recovery and final normal quit. All candidates were initially
on, so preservation of a user-disabled id was checked only with the fake table. Real wake and
unlock remain unchecked below; a synthetic distributed unlock notification was tested live after
manually re-enabling id 1, and the reconciler took it again. Two-display geometry is tests only.
The debug executable's marker domain is `WinMuxApp`, distinct from the installed upstream app.
The final exit restored ids 1 and 2, left 27 and 220 enabled, removed the marker and drew the native
switcher. The installed upstream build was not started.

The installed cliclick imposes a 100 ms pause between actions even with `-w 0`, so its apparent
tap held cmd for about 260 ms. An isolated source build with that pause removed produced a
56 ms tap: focus swapped, no strip draw was logged, and a 20 fps contact sheet showed none.
The installed tool was unchanged. Cliclick arrow events also leave Fn held; clearing it with
`ku:fn` restored Carbon delivery, confirmed with a separate registration probe. Physical-key
helpers supplied backtick and letters that cliclick's `kp` does not support. Invalid early driver
attempts were discarded rather than used as failure evidence. No thumbnail-refresh stall was
observed during this issue's sessions.

## Done when

- [x] Holding cmd and pressing tab opens `recent`: a centred row of every window in MRU order, with the selection on the second entry. No popup-class window appears in it.
- [x] Each further tab press moves the selection forward, `shift-tab` moves it back, the left and right arrows move it, and backtick does not move it in `recent`.
- [x] With no strip open, holding cmd and pressing shift-tab opens `recent` with the selection on the last entry, and releasing Shift alone does not commit.
- [x] Releasing cmd focuses the selected window, switching workspace if needed. WinMux never becomes the active app while the strip is open.
- [x] Releasing cmd with Option held runs `summon`: the selected window moves into the current workspace. `winmux list-lenses --json` shows `alt-enter` bound to `summon` in the Lens's `keys`.
- [x] While Option is held on a window from another workspace, the selected entry shows "Summon to N" and the landing spot is outlined on the screen. On a window of the current workspace neither shows.
- [x] A cmd+tab released within 100 ms swaps to the previous window and the strip never draws.
- [x] `winmux lens recent` run from a shell, with no modifiers held, swaps to the previous window without drawing a strip.
- [x] `esc` closes the strip and focus is unchanged.
- [x] Holding cmd and pressing backtick opens `app-windows` with only the focused app's windows. `shift-backtick` reverses it.
- [x] With one match the selection is on it. With no match the strip shows "No windows" and releasing cmd changes nothing.
- [x] Typing a letter that has no `keys` binding in an open strip reopens the same Lens as `'list` with that letter in the Search box and the same window selected. Pressing `w` while cmd is held closes the selected window and the strip stays a strip.
- [x] With more matches than fit, the row scrolls with the selection and shows "+N" at each end that has hidden entries.
- [x] Entries show icon and title with no thumbnail cache, and thumbnails with Frozen thumbnails dimmed once the cache exists.
- [x] `winmux lens recent --presentation list` opens `recent` as a list, and a binding that runs `lens --filter <name|body> --presentation strip` opens an ad-hoc strip while its modifiers are held.
- [x] `winmux list-lenses --json` lists `recent` and `app-windows` with the strip Presentation.
- [x] With `cmd-tab` bound, the native cmd+tab no longer appears, and the native cmd+backtick system chord is still enabled in the live symbolic-hotkey table. After removing the binding and reloading the config, after switching to a mode without it, and after `enable off`, the native cmd+tab works again.
- [x] After a normal quit, `SIGTERM`, `SIGINT` or `SIGHUP`, the native cmd+tab works again.
- [x] After `kill -9`, cmd+tab does nothing until WinMux is launched again, and it works after that launch.
- [ ] After sleep and wake, and after unlocking the screen, cmd+tab still opens `recent`. The unlock case is handled by the new `com.apple.screenIsUnlocked` observer.
- [x] A symbolic hotkey the user had turned off before WinMux started is still off after WinMux quits.
- [x] `winmux doctor` prints the symbolic hotkey ids WinMux holds and the marker's contents.

## Sources

- [Prototype: strip Presentation look and keyboard model](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/29-prototype-strip-presentation.md)
- [Strip Presentation prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/29-strip-presentation.html)
- [Grilling: Lens configuration shape](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/07-grilling-picker-binding-shape.md)
- [Research: taking over cmd+tab and cmd+` from the system](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/25-research-system-switcher-takeover.md)
- [Research findings: taking over cmd-tab and cmd-backtick from the system](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/research/25-system-switcher-takeover.md)
- [Research: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/03-research-thumbnails-and-alttab.md)
- [Research findings: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md)
- [Grilling: cmd-K search Lens](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/19-grilling-cmd-k-search.md)
- [Grilling: questions left by the review of the build issues](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/35-grilling-build-issue-review.md)
