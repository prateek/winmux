# Escape while Cmd-Tab is held does not dismiss the strip

Part of {{UMBRELLA}}.

## What to build

On the rich desk in a guest, holding Cmd, tapping Tab, then tapping Escape and releasing Cmd focused the strip's selection instead of dismissing the strip. **The Hold: one rule for keys while the Trigger's modifiers are down** says Escape during a Hold, read with the Hold's modifiers taken off, dismisses the Lens.

The `keys` event log shows Escape at 5.6 seconds with Cmd still down. The Lens trace for that opening lists no keys: the Hold ended on Cmd's release, and WinMux committed to Safari on workspace 2. Base `3cfd54d2` behaves the same (`ending-workspace` 2 after the same sequence), and so does the build of **A Safari window's picture is a thin grey strip**.

Not yet known: whether the Escape reaches WinMux at all. `keys` posts synthetic events; a real keyboard may differ.

## Decisions

- **Escape during a Hold dismisses the Lens and keeps focus where it was**, as the Hold's rule says.

## Not in this issue

- Escape after the Hold, in a Lens that stays open on release.

## Depends on

Nothing.

## Done when

- [ ] Reproduce first, and say whether WinMux's key path saw the Escape.
- [ ] Holding Cmd, tapping Tab and then Escape, and releasing Cmd leaves focus on the window that had it, checked in a guest on base and head with one script.
- [ ] A test covers Escape during a Hold.

## Sources

- The demo pass for **A Safari window's picture is a thin grey strip**, 2026-10-17: the `safari-strip` take, and the builder's base, dogfood.13 and head strip runs, which use the same sequence (`.scratch/winmux-fork/proofs/safari-picture/live.zsh`).
