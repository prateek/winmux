# Keys queued while a Lens opens are decided by the session's own rules

Part of {{UMBRELLA}}.

## What to build

A registered chord pressed while a Lens is still opening is queued and replayed once the session is ready. To know whether a later press is the Lens's or a global binding's, `LensLifecycle.openingStripKey` predicts the state the session will be in: it keeps its own copy of the input state, the Presentation and the list's keys, and changes them at a queued letter or `/` the way `LensSession` would.

The copy does not know that a queued key will close the Lens. With Option held from `alt-slash` and the list still opening, Return is queued, and a following `alt-1` is read as a key of the Hold, consumed and queued behind it. On replay Return focuses and closes the Lens, and `alt-1` is dropped. On a Lens already on screen the same two presses focus and then change workspace.

It takes two presses inside the opening, which is tens of milliseconds for a list, so nobody has met it. The prediction is the larger problem: every change to how a session ends its Hold, enters Search or closes must be made twice.

## Decisions

- **One function** takes a state, a Presentation and a key's meaning and returns the next state, the next Presentation and whether the Lens closes. `LensSession.perform` and the opening queue both use it.
- **After a queued key that closes the Lens**, a later press is not the Lens's: its global binding runs.

## Not in this issue

A key pressed before the panel has the keyboard that is not a registered chord. It goes to the app in front, as `docs/lenses.md` says.

## Depends on

Nothing.

## Done when

- [ ] With a list opening under an Option Hold, Return then `alt-1` focuses the selected window and then runs `alt-1`'s binding.
- [ ] `LensLifecycle` holds no copy of the session's transitions: a test that changes state through the queue and through a presented session uses the same function.

## Sources

- Pull request [#143](https://github.com/prateek/winmux/pull/143), the second review's findings on the opening queue.
