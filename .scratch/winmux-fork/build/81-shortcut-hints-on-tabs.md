# Shortcut hints on tabs while the modifier is held

Part of {{UMBRELLA}}.

## What to build

A tab group's tabs are reached by digit, and nothing shows which digit is which. Holding the modifier for a moment shows a number on each tab.

## Decisions

- **Its own issue, built after Hints shown while a key is held.** Lens hints remain instant and per Lens. Tab hints have a fixed half-second delay, follow `window-tabs.enabled`, and add no setting; `hints-key` does not apply to tabs.
- **The hints come from the bindings in effect**, not from an assumed modifier.
- **Only the addressed tab group shows hints**, with exactly the binding's modifiers held. A single-command `focus --tab-index` binding qualifies regardless of its other flags; sequences and multi-command bindings do not.
- **A quick chord spoils the hold until every modifier is released.** Once hints are showing, tab keys and clicks keep them showing. Opening a Lens, changing binding mode, reloading, disabling WinMux or suspending hotkeys hides them.

## Not in this issue

- Hints on sidebar workspaces. Say in the pull request if they come for free.

## Depends on

- **Hints shown while a key is held**.
- **The ninth tab digit goes to the last tab**, for what the ninth hint says.

## Defaults chosen for you

- **A tab with no binding shows no hint.**
- **The hint sits where the tab's icon is.**

## Done when

- [x] Holding the tab digits' modifier past the delay shows a number on each bound tab, and releasing clears them.
- [x] A config that rebinds the digits shows the new ones.
- [x] A quick chord shows nothing.

## Built and checked

`WindowTabHintState` is a deterministic reducer with externally driven deadline tokens. `WindowTabHintController` owns the published shown modifier set and one cancellable 500 ms task, with injected clock, live flags, bindings and eligibility seams. Modifier events enter before tap-binding suspension checks; key monitors, registered bindings and mouse-button downs cancel an armed hold. Pointer moves, drags and scrolling do not spoil it. A changed nonempty modifier set re-arms only an unspoiled hold, and the deadline checks live modifier state before showing anything. The controller alone checks for an open Lens, including during strip rebuilds. Tap bindings retain their release behavior.

The focus command and hints share tab-group and index resolution. Pure label selection prefers a positional binding over `last`, then the first configured key in sort order. Labels use the configured notation, including keyboard-layout mappings, and `displayBindingNotation`. Strip models carry labels, with child identity mapped through each tab's representative window; the view replaces its icon with a white 14-point rounded badge and dark bold rounded text. Floating focus addresses no group. One-window tab layouts retain only the `last` resolution and have no strip, and double-sided windows gain no strip. Sidebar hints do not come for free: their workspace commands and rendering are separate.

No named default changed. No config, contract, default-binding or generated-default file changed. The existing focus-command tests are unchanged. Host and pinned-version guest `make check` pass: 1,626 Swift tests, 87 Rust integration tests and 171 script tests; the guest skips the host-only committed-hash assertion. Thirteen new behavior tests cover timing, spoil/reset, pointer movement, Lens/enable gates, exact modifiers, defaults on 3/8/9/12 children, custom keys, extra command flags, collisions, group identity, floating focus and nested-child resolution. The spoil regression and configured-key regression were each observed failing before restoration or repair.

The 1280 × 720 guest run used shipped defaults first. Twelve-tab captures show keys 1–8, icons on tabs 9–11 and 9 on tab 12 after manually scrolling; the overflowing strip does not reveal offscreen tabs automatically. Three tabs show 1–3. Option-2 moves focus while hints stay, release restores icons, and quick Option-3 both released immediately and held for two more seconds shows no hint in any captured frame and ends on tab 3. An explicit split of two groups shows hints only on the focused group. A literal Control-digit config shows digits under Control and only Q under Option, with the corresponding focus readbacks. A pointer move before the deadline preserves the hold; Option-slash hides tab hints when Search opens. Registered hotkeys reached `triggerBinding` but not the keyDown monitors; Escape reached the latter. Search's six matches and their row positions are recorded with the relay captures. The identical positional/relative-focus script produces matching output against the base and feature trees. Proof tools are in `.scratch/winmux-fork/proofs/tab-hints/`, reusing the known-order stage from `tab-nine-last/`. No permission prompt appeared or was granted. The builder publishes no release.

## Checks that remain Prateek's

- [ ] Installed-build behavior.
- [ ] Real keyboard timing, including a quick chord followed by keeping its modifier held.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-07: "show shortcut overlays on winmux tabs after a short delay when holding alt (or whatever the bind is)".
