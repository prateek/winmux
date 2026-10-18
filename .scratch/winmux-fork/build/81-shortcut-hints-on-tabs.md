# Shortcut hints on tabs while the modifier is held

Part of {{UMBRELLA}}.

## What to build

A tab group's tabs are reached by digit, and nothing shows which digit is which. Holding the modifier for a moment shows a number on each tab.

## Decisions

- **Its own issue, built after Hints shown while a key is held**, sharing that issue's delay and its setting. That one draws on Tiles in a Lens; this draws on the tab strip. As built, that issue has no delay (a Lens shows its hints the moment the key goes down) and its setting is per Lens, so there was nothing to share: tab hints wait a fixed half second, follow `window-tabs.enabled`, and add no setting, and `hints-key` does not apply to tabs.
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

`WindowTabHintState` is a deterministic reducer with externally driven deadline tokens. `WindowTabHintController` owns the shown modifier set, the labels it publishes and one cancellable 500 ms task, with injected clock, live flags, bindings and eligibility seams. Modifier events enter before tap-binding suspension checks; a key-monitor key, a registered binding or a mouse-button down while any modifier is held and hints are not yet showing spoils the hold until every modifier is released, even under a set with no tab bindings. Pointer moves, drags and scrolling do not spoil it. A changed nonempty modifier set re-arms only an unspoiled hold, and the deadline checks live modifier state before showing anything. Keys and clicks catch the controller up from their own events' modifiers, and pointer moves too when those agree with the live ones (a move WinMux posts can carry none). Registered hotkeys, strip rebuilds, a Lens opening or closing and the deadline read the live session modifiers, so a release event macOS drops neither leaves hints up nor blocks the next hold. The controller alone decides whether a Lens hides the hints, from the moment a Lens starts opening; the Lens lifecycle tells it when it opens or closes. Tap bindings retain their release behavior.

The focus command and hints share tab-group and index resolution. Pure label selection prefers a positional binding over `last`, then the first configured key in sort order. Labels use the configured notation, including keyboard-layout mappings, and `displayBindingNotation`. The controller publishes the addressed group, held weakly, with its labels by each tab's representative window id. The strip view observes it, so the strip models carry no label and a tab click's optimistic strip rewrite keeps them. A nested group's window that also stands for an outer tab is labelled in the inner strip only. The view replaces its icon with a white 14-point rounded badge and dark bold rounded text. Floating focus addresses no group. One-window tab layouts retain only the `last` resolution and have no strip, and double-sided windows gain no strip. Sidebar hints do not come for free: their workspace commands and rendering are separate.

No named default changed. No config, contract, default-binding or generated-default file changed. The existing focus-command tests are unchanged. Host and pinned-version guest `make check` pass: 1,634 Swift tests, 87 Rust integration tests and 171 script tests; the guest skips the host-only committed-hash assertion. Twenty-one new behavior tests cover timing, spoil/reset, a dropped release, pointer movement, Lens/enable gates, exact modifiers, defaults on 3/8/9/12 children, custom keys, extra command flags, collisions, group identity, floating focus and nested-child resolution. The spoil, unbound-modifier spoil, both dropped-release paths, a key queued before its modifier, a hotkey whose modifier event was never seen, a posted pointer move, nested-group and configured-key regressions were each observed failing before restoration or repair.

The 1280 × 720 guest run used shipped defaults first. Twelve-tab captures show keys 1–8, icons on tabs 9–11 and 9 on tab 12 after manually scrolling; the overflowing strip does not reveal offscreen tabs automatically. Three tabs show 1–3. Option-2 moves focus while hints stay, release restores icons, and quick Option-3 both released immediately and held for two more seconds shows no hint in any captured frame and ends on tab 3. An explicit split of two groups shows hints only on the focused group. A literal Control-digit config shows digits under Control and only Q under Option, with the corresponding focus readbacks. A pointer move before the deadline preserves the hold; Option-slash hides tab hints when Search opens. Registered hotkeys reached `triggerBinding` but not the keyDown monitors; Escape reached the latter. Search's six matches and their row positions are recorded with the relay captures. The identical positional/relative-focus script produces matching output against the base and feature trees. Proof tools are in `.scratch/winmux-fork/proofs/tab-hints/`, reusing the known-order stage from `tab-nine-last/`. No permission prompt appeared or was granted. The builder publishes no release.

## Checks that remain Prateek's

- [ ] Installed-build behavior.
- [ ] Real keyboard timing, including a quick chord followed by keeping its modifier held.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

## Sources

- Prateek, 2026-10-07: "show shortcut overlays on winmux tabs after a short delay when holding alt (or whatever the bind is)".
