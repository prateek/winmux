# The Hold: one rule for keys while the Trigger's modifiers are down

Part of {{UMBRELLA}}.

## What to build

A Lens opened by a chord is open while the chord's modifiers are still down. What a key means during that time is decided today by the Presentation, and the Presentations disagree.

- **The strip** knows about the held modifiers. The Trigger's key steps, a letter with exactly those modifiers starts Search, and their release commits (`StripGesture` and `handleStripLetter` in `Sources/AppBundle/lens/StripLayout.swift`).
- **The list and `'miniatures`** do not. A key with Command down is a Command chord, whatever opened the Lens.

The seam shows when a Lens changes Presentation with the modifiers still down. Hold Command, press Tab, type "gh": the strip takes "g", converts to the list, and the list is handed "h" as Cmd+H, which a Search field does not insert. Search reads "g". That is how this was found, in the live run of **Lens state, events and effect lifetimes, with controlled time**; it is not an artifact of synthetic keys, since the rule is in the code. The same seam is there for Backspace and the arrows, and it will be there for every Presentation a held chord can open once **Staying open on release, and light and dark** lets a grid commit on release.

This issue names the thing and gives it one rule. The **Hold** is the time from a Trigger's key press until the modifiers it was pressed with are released. It belongs to the Lens session, not to a Presentation. While it lasts, the held modifiers are not part of what is typed.

## Decisions

- **A session has a Hold or it does not.** A Lens opened by a chord with modifiers has one, from the key press until those modifiers are all released. A Lens opened by the CLI, or by a key with no modifier (the `lens` binding mode's letters), has none. A Hold ends once and does not start again in the same session.
- **The Hold and the Presentation are separate.** Changing Presentation does not end the Hold or change what keys mean during it. The strip converting to a list is a change of Presentation and nothing else.
- **During the Hold, a key is read in this order**, the same in every Presentation:
  1. A chord the Lens binds in `keys` runs its command (`cmd-w`, `cmd-1`).
  2. The Trigger's own key, and Tab and backtick, with exactly the Hold's modifiers, step the selection; Shift reverses. This is the strip's rule today, unchanged.
  3. Any other key is read with the Hold's modifiers taken off. A letter goes to Search, Backspace deletes one character, an arrow moves the selection, Escape dismisses.
  4. A key with a modifier that is not the Hold's is not the Lens's. It dismisses the Lens and runs its global binding, as an unrelated chord drops the strip today.
- **After the Hold, modifiers mean themselves.** Command with a letter is a Command chord again, in the Search field and everywhere else.
- **What the end of the Hold does is not decided here.** A strip commits and a list stays, as today, and a strip that has converted to a list stays. Making that a setting is **Staying open on release, and light and dark**, which builds on the Hold this issue defines.
- **No key is lost to a change of Presentation.** A key that arrives while the Search field is not yet first responder is kept and delivered in order. Today conversion leaves focus to the list view's `onAppear`, a run-loop turn or more later.
- **`Hold` is added to `CONTEXT.md`** by the pull request that drafts this issue. Use the word as written.

## Not in this issue

- `on-release`, and a grid or list that commits on release.
- **Hints shown while a key is held**. Its hints key is a different key held for a different reason; a Hold whose modifiers include it is that issue's case to settle.
- Search's matching, debounce or inline Filters.
- Which keys start a Search from a strip. Letters do today and digits do not; that stays.

## Depends on

Nothing. **A trace of a Lens opening, from the key press to the first frame, and the strip's half second** gives key-event timestamps a home; if it has landed, use its record, and if not, extend `WINMUX_DEBUG_STRIP_EVENTS`.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Where it lives.** One value on the session, set from the gesture at opening and cleared by `LensLifecycle.stripFlagsChanged`, which already sees the release in every Presentation. One function reads a key against it, and the panel's key routing for all three Presentations calls that function before anything else.
- **`StripGesture` keeps its name and its deadline.** It already carries the invoking key and modifiers; the Hold is what it becomes once the strip is not the only thing that reads it.
- **A list opened by a chord directly** (not through a strip) has a Hold too, usually a few milliseconds long. A letter typed inside it goes to Search without its modifier, which is what the person meant.
- **Cmd+A, Cmd+V and the like in Search during a Hold** type nothing and do nothing, unless the Lens binds them. They work once the modifiers are up.
- **Record before fixing.** Log each key with its timestamp, modifiers and where it went, for `tap:g tap:h` with the modifier held, for `tap:g`, modifier up, `tap:h`, and for two letters 0, 5, 20 and 50 ms apart with the modifier up. The first shows the cause, the second is the control, the third measures the focus gap.

## Done when

- [x] Holding the Trigger's modifiers, pressing the Trigger and typing two letters puts both in Search, in a lifecycle test and in a guest.
- [x] With the modifiers still held after conversion, Backspace deletes one character, the arrows move the selection and a Lens `keys` chord runs its command.
- [x] After the modifiers are released, a Command chord on the list is not typed into Search, and releasing them did not commit the list.
- [x] A Lens opened from the CLI or the `lens` binding mode reads keys exactly as before.
- [x] One function decides what a key means during a Hold, and the strip, the list and `'miniatures` call it; the strip's step, commit and unrelated-chord tests pass unchanged.
- [x] Two letters sent with no gap and no modifier after a conversion both reach Search, or the record shows the gap cannot be hit and says why.
- [x] The click-in-the-field workaround is gone from the handoff and from any skill that carries it.

## Built and checked

The Hold is stored on `LensSession` and set or ended by `LensLifecycle`, including
release while opening. `lensKeyMeaning` is the pure decision used by panel events,
key equivalents, Carbon bindings and queued opening keys. Held Search edits go
through session events; conversion requests focus synchronously and retains early
typing in arrival order. Opening stages remain unchanged; `debug-lens-trace`
retains a separate bounded key table and final session readback.

The record-only guest captures showed Search stuck at `g` for held `gh`, release
before `h`, and every short-gap pair: Search never acquired its field editor during
those takes. After the fix, held `gh` and release-before-`h` both read `gh`; the
0, 5, 20 and 50 ms pairs after conversion all read `gha`, without a caret click.
Controlled-clock lifecycle, pure-table and AppKit event-entry tests cover the rule.
The guest also checks Backspace, arrows, Lens commands, foreign Carbon chords,
direct list/overview openings, CLI/leader input and unchanged strip commit/cycling.

Decided: Preserve the existing strip distinction between its own Trigger and the
other Lens's Tab/backtick Trigger: the latter is consumed without stepping. This
keeps the existing strip assertions and behavior required by the builder ruling.
Decided: Search editing during a Hold operates at the end; ordinary editing resumes
in the field editor after release. No starting default was changed.

Host and CI-version guest `make check` pass. Installed behavior remains separate:

- [ ] Installed-build checks.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

## Sources

- The live run of **Lens state, events and effect lifetimes, with controlled time**, in pull request [#73](https://github.com/prateek/winmux/pull/73).
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
