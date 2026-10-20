# A command hands a chord to the system switcher

Part of {{UMBRELLA}}.

## What to build

With the Cmd-Tab opt-in, WinMux finds the system's Cmd-Tab and Cmd-Shift-Tab in the symbolic hotkey table, disables them through `CGSSetSymbolicHotKeyEnabled`, and records what it owns in a marker so wake, unlock and quit can restore them. There is then no way to reach the native switcher while WinMux runs: Prateek wants Cmd-Tab for the current workspace's windows and a second chord, Alt-Tab, that opens the system's switcher over everything.

Add a command that lends the system its switcher for one use.

## Decisions

- **`system-switcher`** is bound to any chord; the shipped docs show Alt-Tab. When it runs, WinMux asks the reconciler to re-enable the hotkeys it owns, posts a synthetic Command down and Tab down, and holds the synthetic Command until the chord's own modifiers, Option for Alt-Tab, are released; then it posts Tab up and Command up, the native switcher commits, and the reconciler re-applies its desired state.
- **While the lend lasts, the user's keys are translated**: Tab and Shift-Tab repeats are posted as Tab and Shift-Tab with the synthetic Command held, the arrows pass through, Escape posts Escape and ends the lend. The user's Option stays down throughout and is not posted.
- **WinMux ignores its own posted events.** They carry a source tag the event taps skip, so the synthetic Cmd-Tab never enters `cmd-tab` mode.
- **The reconciler stays the owner of the symbolic hotkey state**: the lend is a request to it, the marker is unchanged during it, and a wake or unlock during a lend ends the lend before repairing.

## Depends on

Nothing.

## Defaults chosen for you

- **The lend ends on its own after five seconds** without a modifier release, posting the ups and exiting 1.
- **With the Cmd-Tab opt-in off** the command exits 1 and says the system switcher is already live.
- **A chord bound to `system-switcher` whose own modifiers include Command** is refused by `config check`, since the synthetic Command could not be told from the user's.

## Done when

- [ ] A test of the reconciler's lend shows the hotkeys enabled during it and the marker and the hotkey state consistent before, during and after, including a timeout and a wake during a lend.
- [ ] A test of the translation posts Alt-Tab, Alt-Shift-Tab and an Option release and asserts the synthetic events in order, each tagged.
- [ ] In a guest with the opt-in on, a chord bound to `system-switcher` opens the native switcher and a release focuses what it selected; Cmd-Tab still opens the Lens afterwards; `winmux doctor` reports the hotkeys as WinMux left them.
- [ ] `docs/default-config.md` shows the binding under the Cmd-Tab opt-in.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: Alt-Tab opens the native switcher on his machine, and Cmd-Tab is unaffected after a sleep and wake.

## Sources

- #268, "a second chord (Alt-Tab) should fall back to the native switcher".
- `Sources/AppBundle/config/SymbolicHotkeyReconciler.swift`, the candidate scan, and `SystemSymbolicHotkeys.swift`.
