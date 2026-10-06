# The Hold ends at the first letter

Part of {{UMBRELLA}}.

## What to build

**The Hold: one rule for keys while the Trigger's modifiers are down** made every key during a Hold a key with the held modifiers taken off: Cmd-Tab, keep Command down, type "saf", and Search reads "saf". Prateek does not want that. Nobody types a word with Command down.

A Lens session is in one of two states, and a key means one thing in each.

- **During the Hold** the Lens is a gesture. The Trigger's key steps, release commits, and the Lens's own chords run. This is native Cmd-Tab: Tab, Tab, Tab, release.
- **After the Hold** the Lens is modal. It stays open with nothing held, letters go to Search, and a modifier means itself.

The first letter typed during a Hold ends the Hold. The Lens stays open and the letter starts Search. From the next key on, Command with a letter is a Command chord.

## Decisions

- **During the Hold, a key is read in this order**, the same in every Presentation:
  1. A chord the Lens binds in `keys` runs its command (`cmd-w`, `cmd-1`).
  2. The Trigger's own key, and Tab and backtick, with exactly the Hold's modifiers, step the selection; Shift reverses. Unchanged.
  3. An arrow moves the selection and Escape dismisses, read with the Hold's modifiers taken off. Unchanged.
  4. **A letter that is not bound ends the Hold.** It goes to Search with the Hold's modifiers taken off, and the Lens stays open as if `on-release` were `'stay`: the later release of the modifiers does nothing. A strip converts to a list, as today.
  5. A key with a modifier that is not the Hold's is not the Lens's. Unchanged.
- **After the Hold, modifiers mean themselves**, including while the Trigger's modifiers are still physically down. Command-V pastes into Search, Command-A selects all, and a chord the Lens binds runs. No letter is typed by a Command chord.
- **One session, one Hold.** It ends at the release or at the first unbound letter, whichever comes first, and does not start again.
- **A Lens with no Hold is unchanged.** Opened by the CLI or by a key with no modifier, it has nothing to end: a list or a grid stays open and takes letters as Search, and a strip opened with no modifier held still commits at once.
- **`on-release` is the only way to choose a modal Lens.** There is no key that keeps a committing Lens open. That setting is **Staying open on release, and light and dark**.
- **A remembered Search** is still replaced by the letter that ends the Hold.
- **`CONTEXT.md` and `docs/lenses.md`** say this. The glossary entry for **Hold** is changed by the pull request that drafts this issue.

## What this undoes

- Letters after the first are no longer read with Command taken off. "Every letter is a letter during a Hold" goes, and with it the special case for a, c, v, x, y and z.
- Backspace during a Hold does nothing: there is no Search to edit until a letter has ended the Hold.
- `g` after Cmd-Tab and one letter is `cmd-g`, the grouping chord, because the Hold is over and Command is down. That is the chord doing its job. With Command released it is a letter.

## Not in this issue

- `on-release`, and a grid or list that commits on release.
- Which keys start a Search from a strip. Letters do and digits do not.
- **Hints shown while a key is held**.

## Depends on

- **The strip as one row of the grid**, which changes the strip's conversion.

## Defaults chosen for you

- **Where it lives.** `lensKeyMeaning` is the one decision for the panel, key equivalents, Carbon and queued opening keys. The change is there and in the lifecycle's release path, which already ends the Hold.
- **Queued keys.** A letter that arrives while the Lens is opening ends the Hold when it is replayed, and the keys queued after it are read with no Hold.
- **The stuck Hold.** A release that lands before the Lens begins opening leaves a list's Hold on until the next modifier event. With this change the first letter ends it anyway. Say in the pull request whether anything of that edge is left.
- **The live run** is the Hold's own, in a guest, with posted keys: the gesture, the letter that ends it, a paste after it, and a bound chord in both states.

## Done when

- [ ] Cmd-Tab, Tab, Tab, release: the selection steps at each press and the window selected at release is focused, as today.
- [ ] Cmd-Tab, then `s` with Command still down: the Lens is a list, Search reads "s", and releasing Command leaves it open.
- [ ] After that `s`, with Command still down, `a` selects all of Search and `v` pastes; neither types a letter.
- [ ] After that `s`, with Command released, "af" makes Search read "saf".
- [ ] `cmd-w` during the Hold closes the selected window and the Hold goes on; `cmd-g` in a list or grid after the Hold changes the grouping.
- [ ] Backspace during a Hold changes nothing.
- [ ] The same holds for a grid and a list opened by a chord with modifiers, and for an Option Hold.
- [ ] A Lens with no Hold reads keys as before.
- [ ] The key record in `winmux debug-lens-trace` shows the Hold ending at the letter.
- [ ] `docs/lenses.md` describes the Hold as built, and agrees with `CONTEXT.md`.

## Sources

- Prateek, 2026-10-05: "I can imagine cmd-tabbing with cmd held and Tab pressed a couple of times. I can't imagine holding Command and then typing." He chose "a letter goes modal" and "setting only".
- Pull request [#81](https://github.com/prateek/winmux/pull/81), which built the rule this replaces.
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
