# The second letter typed into a strip is lost while the modifier is held

Part of {{UMBRELLA}}.

## What to build

Typing a letter while the strip is open converts it to the list and puts that letter in Search. The strip opens on a held modifier (Command, for the shipped cmd-tab), so the first letter usually arrives with it still down, and the strip accepts it that way by design (`handleStripLetter` in `Sources/AppBundle/lens/StripLayout.swift` takes a letter with no modifier or with exactly the invoking ones).

The second letter is not accepted. The Lens is a list by then, the strip's rule no longer applies, and the key reaches the Search field as a Command chord, which a text field does not insert. So holding Command, pressing Tab and typing "gh" searches for "g". In the live run that found this, the keys sent were `down:cmd tap:tab tap:g tap:h up:cmd`; Search held "g", and after a click in the field typing worked, because the modifier was up by then.

There may be a second, smaller gap behind it. Conversion does not focus the Search field itself; the field takes focus when the list view appears, a run-loop turn or more later. A letter that arrives in between, modifier or not, has a key panel and no editor to go to. Nobody has measured whether a real key can land there.

This issue makes every letter typed into a strip reach Search, in order.

## Decisions

- **A converted list keeps accepting letters under the invoking modifiers until they are released.** While the modifiers that opened the strip stay down after conversion, a letter with exactly those modifiers, or with none, is appended to Search, as the first was. Once they are released the list is an ordinary list: a Command chord is a Command chord again.
- **A Lens `keys` binding still wins.** A chord the Lens binds (`cmd-w`, `cmd-1`) runs its command during that window as it does before conversion, and is not typed.
- **Releasing the modifiers after conversion does not commit.** That is today's behaviour and stays: the release that would have focused the strip's selection does nothing to a list.
- **No letter is lost to the focus gap.** If the measurement below shows a key can arrive before the Search field is first responder, keys in that gap are kept and delivered in order. The fix is in the hand-off, not a delay added to it.
- **Reproduce first, with a record.** Before the fix, log each key event with its timestamp, its modifiers and where it went (the Carbon handler, the local monitor, the panel's `keyDown`, the field's editor), for these sequences in a guest: `tap:g tap:h` with the modifier held throughout; `tap:g`, modifier up, 200 ms, `tap:h`; and `tap:g tap:h` with the modifier already up, at gaps of 0, 5, 20 and 50 ms. The first shows the modifier cause, the second is the control, the third measures the focus gap.

## Not in this issue

- Search's matching, debounce or inline Filters.
- Digits and punctuation starting a Search from the strip; the strip converts on letters only, and that rule stays.

## Depends on

Nothing. **A trace of a Lens opening, from the key press to the first frame, and the strip's half second** gives the key-event timestamps a better home; if it has landed, use its record, and if not, extend `WINMUX_DEBUG_STRIP_EVENTS`.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Where the rule lives.** In the session, beside `handleStripLetter`: the gesture's modifiers are remembered across conversion and cleared on their release, which `LensLifecycle.stripFlagsChanged` already sees.
- **Backspace under the held modifier** deletes one character, not a word or the line, during the same window.
- **The focus gap.** Have conversion ask for the Search field's focus directly, as the first open of a list does, and keep `onAppear` as the fallback.

## Done when

- [ ] The pull request has the record of the three sequences before the fix, showing where each second letter went.
- [ ] Holding the invoking modifier, pressing the Trigger and typing two letters puts both in Search, in a lifecycle test and in a guest.
- [ ] After the modifier is released, a Command chord on the list is not typed into Search.
- [ ] A Lens `keys` chord pressed in that window runs its command.
- [ ] Two letters sent with the modifier up and no gap both reach Search, or the record shows the gap cannot be hit and says why.
- [ ] The click-in-the-field workaround is gone from the handoff and from any skill that carries it.

## Sources

- The live run of **Lens state, events and effect lifetimes, with controlled time**, in pull request [#73](https://github.com/prateek/winmux/pull/73).
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
