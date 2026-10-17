# Ctrl-Up does nothing while the pointer is over the expanded sidebar

Part of {{UMBRELLA}}.

## What to build

In a guest on `0.5.6-dogfood.13`, with the pointer over the expanded workspace sidebar, `ctrl-up` did not open Mission Control. It opened as soon as the pointer left the sidebar. Twice in two tries.

Confirmed against base `3877046b`: expanding the sidebar starts a session-wide search tap. Its classifier handles arrows before modifiers, so Ctrl-Up becomes `.moveUp`, Ctrl-Down becomes `.moveDown`, and both are swallowed. Hover search also requests a key window and application activation. In the unbundled guest those activation requests did not make WinMux frontmost, and Cmd-N already reached Ghostty.

## Decisions

- **Reproduce first**, and find out whether other system shortcuts are lost the same way.
- **A system shortcut works wherever the pointer is.**
- **Modified chords pass through.** Control always passes through; Command and Option do too, except Delete, which keeps their existing delete-to-beginning and delete-word edits. Plain and Shift-only search keys retain their behavior.
- **Hover search keeps the working app in front.** It requests neither a key window nor activation. Command-opened search, both rename paths and sidebar clicks retain their existing activation behavior; hover exit activates nothing.
- **Plain letters remain type-to-search.** This applies on base and head and is outside the shortcut fix.

## Not in this issue

- What Mission Control draws once it opens. That is **Mission Control and Exposé with WinMux running**.

## Depends on

Nothing.

## Done when

- [x] `ctrl-up`, `ctrl-down` and one app shortcut such as `cmd-n` work with the pointer over the expanded sidebar, checked in a guest.
- [x] The pull request says what took the key.

## Build and checks

The CGEvent tap and NSEvent panel adapter share one classifier. Required `.hoverSearch`, `.commandSearch` and `.rename` origins control panel-preparation requests. Classifier, real-event and preparation tests fail with their respective fixes removed; existing plain-key, edit, rename and command-search expectations pass with the fixes off. Host and pinned-version guest `make check` pass: 1,412 Swift, 88 helper and 138 script tests, without skips.

Base/head guest runs show the native overlays, frontmost app and focused window, Cmd-N's one-to-two window count, unchanged search/selection/Return/Escape and command search, plus workspace rename and Ctrl-Up during its field. Type-to-search begins under `always-expanded` and `auto-hide` on both trees, and Ctrl-Up works in both on head. Spotlight opens on both. Control-Left/Right were filmed on one Space; the edge bounce was inconclusive and no Space-transition claim is made.

The base has no double-click rename handler; preservation was checked through its existing **Rename Workspace** context menu. Native arrow probes preserve the Function flag required by the guest's runtime hotkey table. Scripts and rerun instructions are in `.scratch/winmux-fork/proofs/sidebar-shortcuts/`. The pull request says what took each lost shortcut. Whether hover search made an installed, bundled WinMux frontmost, and so took Cmd-N, is Prateek's check on an installed build.

## Sources

- The switching comparison, 2026-10-07: the Mission Control captures with WinMux running.
