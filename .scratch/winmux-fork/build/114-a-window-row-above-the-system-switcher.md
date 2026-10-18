# A window row above the system switcher

Part of {{UMBRELLA}}.

## What to build

Keep Cmd-Tab as macOS's app switcher and show the highlighted process's windows above it, with their workspace names. Cmd-A leaves the system switcher for the row; release focuses the chosen window, including on a hidden workspace.

The prototype's twelve openings ordered the row 0.785–11.291 ms after the first readable system highlight, with a 1.692 ms median. Five frame-timestamped openings showed the row zero or one frame behind the native switcher. A corrected single-process Safari hero still flashed its shown-workspace window when the Dock committed first; closing the switcher with Command-Escape on row entry avoided that intermediate switch. These are macOS 26 guest measurements, not an in-process performance promise.

## Decisions

- **The system's switcher is not replaced or drawn over.** Native Cmd-Tab opens and navigates it, and the row sits above its AX frame.
- **Entering the row leaves the switcher.** Cmd-A closes the system's switcher by posting Escape with Command, and the row stays on its own until Command is released or Escape cancels it. This changes the prototype issue's Decision that the row is removed when the switcher closes; it is Prateek's to accept, and this issue waits on his answer.
- **Once entered, the row owns the keyboard until Command is released.** Tab, Shift-Tab and the arrows move in the row and do not reopen the system's switcher. Every other Command chord is consumed too, so Cmd-Q or Cmd-W cannot reach the app being switched away from.
- **One process per row.** Match the selected icon to its pid, and offer only that pid's windows. Two processes have separate icons and separate rows. Suppress an unresolved icon rather than combine processes. Unique titles worked in the prototype; duplicate-icon association through observed activation order needs explicit validation, including at startup and after relaunch.
- **With nothing chosen, release does what the system does.** No focus or cancellation event is issued by WinMux.
- **Cmd-A enters a nonempty row.** Tab, Shift-Tab and arrows then move among its windows; Command release focuses once. Escape cancels without focus. Entry closes the system switcher without switching apps, and swallowed Cmd-Tab must not reopen it.
- **Hide the row under Secure Input.** The native switcher remains fully available. There is no display-only row with an unusable entry key.
- **Off by default**, behind one setting. The prototype itself ships no setting or behavior.
- **Extend MissionControlState's Dock observer.** Share Dock lifetime, launch readiness and retry handling with its existing observer. Do not introduce a second tracking subsystem.
- **The event tap owns paired events.** Decide on a key's first, non-autorepeat key-down, and consume a key-up only for a key-down that was consumed; reset the pairing when macOS disables and re-enables the tap. Pass modifier events, and every key while no row is entered. No AX or window-list call runs on the tap's run loop, the Dock polling and observer callbacks included. A stale focus cannot commit into a newer session.
- **Use WinMux's in-process model and focus path.** Do not run the debug CLI or clone the prototype's window snapshot parser. Prepare the snapshot at opening Cmd-Tab and discard quick taps. The prototype's CLI costs do not establish a number for the integrated path.
- **Use original implementation and assets.** Copy no GPL-3 DockDoor code or asset.

## Defaults chosen for you

- **Setting:** `system-switcher-window-row = false`. Enabling it registers no Cmd-Tab binding and leaves Cmd-Tab to macOS until the person enters a row; only then, for the rest of that Command hold, does the row take Tab.
- **Entry:** Cmd-A matched by character through WinMux's binding rules, including non-US layouts. Cmd-A is taken only while a nonempty row is on screen; before that, or over an empty row, it reaches the front app as it would without WinMux, and is not applied later.
- **Presentation:** text Tiles with title and workspace, a 16-point gap above the native frame, no thumbnails. Keep a row within the selected screen's usable width. Make overflow keyboard-accessible.
- **Identity:** use an unambiguous process association where the platform supplies one. If duplicate titles/URLs need an activation-order association, validate it against native selection and suppress it while incomplete or uncertain.
- **Pointer:** keyboard-first. A click cancels initially; it must never leave a stranded row. Native hover may change the target before entry. After entry the switcher is closed, so pointer crossing cannot change its highlight.
- **Observers:** a 1.0-second AX messaging timeout, independent required-notification retries and bounded polling only during an armed opening or missing subscriptions. Reset on Dock exit, sleep, wake and unlock through the existing lifecycle owner.
- **Diagnostics:** bounded stage/selection traces without recording ordinary app keys or text. Measure added lag relative to the native switcher, and verify visible arrival with frame-timestamped film.

## Depends on

- **The system's Cmd-Tab stays the system's unless the config asks for it**.

## Done when

- [ ] Behavior tests cover the disabled setting, native release without a choice, quick-tap disposal, pending/empty entry, per-process filtering and unresolved duplicate icons; enabling this feature never registers a replacement Cmd-Tab binding.
- [ ] Tests and a live run cover paired key-ups after cancellation/release, Escape ending input ownership, a newer session invalidating delayed focus, Secure Input hiding the row and partial observer registrations retrying with fallback discovery.
- [ ] A live single-process app with windows on shown and hidden workspaces demonstrates Cmd-A closing the switcher without switching, swallowed Cmd-Tab keeping it closed, and direct focus on release without an intermediate app/window switch. Preserve a frame-timestamped film and release/focus traces.
- [ ] At least twelve openings report native AXCreated, first read, row ordering and added lag; five filmed openings compare first-visible native and row frames. Report cold and later openings and load conditions without claiming an unmeasured in-process number.
- [ ] MissionControlState owns the Dock tracking; the tap callback performs no synchronous cross-process work, and layout-independent entry works through WinMux's bindings.
- [ ] macOS 26 and macOS 27 live runs verify the selected-element identity, duplicate processes, Dock restarts, quick taps, Secure Input, row cancellation and hidden-workspace focus.
- [ ] Prateek checks the installed build with a real keyboard, including rapid Cmd-Tab, non-US layout entry and release, a second display, real sleep/wake/unlock, disabled-setting behavior and the transition to a hidden workspace.

## Sources

- **Prototype: a row of windows above the system's Cmd-Tab**, the follow-up prototype README and captured measurements, 2026-10-18.
- The relay driver's rulings on the prototype's first result: compare with the native switcher, use one process's windows, try an explicit row handoff and hide the row under Secure Input.
