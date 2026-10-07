# The Hold ends at the first letter

Part of {{UMBRELLA}}.

## What to build

**The Hold: one rule for keys while the Trigger's modifiers are down** made every key during a Hold a key with the held modifiers taken off: Cmd-Tab, keep Command down, type "saf", and Search reads "saf". Prateek does not want that. Nobody types a word with Command down.

He also does not want an open grid to be a text field. A Lens that stays open reads keys the way vim's normal mode does: `h`, `j`, `k`, `l` and the arrows move, `/` starts Search.

A Lens session is in one of three states, and a key means one thing in each.

- **During the Hold** the Lens is a gesture. The Trigger's key steps, release commits, and the Lens's own chords run. This is native Cmd-Tab: Tab, Tab, Tab, release.
- **Modal, normal.** The Lens stays open with nothing held. Plain keys are commands: they move the selection and act on it. Nothing is typed.
- **Modal, Search.** Entered with `/`. Letters go to Search. Escape goes back to normal with the matches kept.

The first letter typed during a Hold ends the Hold. The Lens stays open, modal, and that letter is read as a normal-mode key. From the next key on, a modifier means itself.

## Decisions

- **During the Hold, a key is read in this order**, the same in every Presentation:
  1. A chord the Lens binds in `keys` runs its command (`cmd-w`, `cmd-1`).
  2. The Trigger's own key, and Tab and backtick, with exactly the Hold's modifiers, step the selection; Shift reverses. Unchanged.
  3. An arrow moves the selection and Escape dismisses, read with the Hold's modifiers taken off. Unchanged.
  4. **A letter that is not bound ends the Hold**, and so does `/`. The Lens stays open as if `on-release` were `'stay`: the later release of the modifiers does nothing. The key is then read as a normal-mode key with the Hold's modifiers taken off, so `j` moves down and `/` starts Search.
  5. A key with a modifier that is not the Hold's is not the Lens's. Unchanged.
- **Normal mode is vim's, as far as a switcher has use for it.** `h`, `j`, `k`, `l` and the arrows move the selection; `/` starts Search; Return runs the Lens's Enter binding; Escape dismisses. A plain key the Lens binds in `keys` runs its command and wins over all of these. Any other letter does nothing.
- **Search is entered with `/`** and left with Escape, which returns to normal mode and keeps the matches. Return commits from either state. The arrows move the selection in both.
- **After the Hold, modifiers mean themselves**, including while the Trigger's modifiers are still physically down. In Search, Command-V pastes and Command-A selects all. A chord the Lens binds runs. No letter is typed by a Command chord.
- **One session, one Hold.** It ends at the release or at the first unbound letter, whichever comes first, and does not start again.
- **`on-release` is the only way to choose a modal Lens.** There is no key that keeps a committing Lens open other than the letter that ends the Hold. That setting is **Staying open on release, and light and dark**.
- **`CONTEXT.md` and `docs/lenses.md`** say this. The glossary entry for **Hold** is changed by the pull request that amends this issue.

## What this undoes

- Letters are no longer read with Command taken off and sent to Search. "Every letter is a letter during a Hold" goes, and with it the special case for a, c, v, x, y and z.
- A grid or strip no longer takes a typed letter as Search. Typing "saf" over a grid moves and does nothing; `/saf` searches.
- Backspace during a Hold does nothing, and nothing in normal mode: there is no Search to edit until `/`.
- `g` after Cmd-Tab and one letter is `cmd-g`, the grouping chord, because the Hold is over and Command is down. With Command released it is a normal-mode key.

## Not in this issue

- `on-release`, and a grid or list that commits on release.
- Counts, `gg` and `G`, marks by letter, a `:` command line, or any other part of vim. Each is a later issue if Prateek wants it.
- **Hints shown while a key is held**.

## Depends on

- **The strip as one row of the grid**, which gave the strip rows for `j` and `k` to move between.

## Defaults chosen for you

Prateek's words settle the Decisions above. These he has not spoken to; build them, list each under **Decisions the relay made**, and expect him to reverse some.

- **Which state a modal Lens starts in** is a setting of the Lens, `starts-in`, `'normal` or `'search`. A grid, a strip and miniatures default to `'normal`. A list defaults to `'search`, so the shipped `search` and `floating` Lenses still take typing the moment they open. A Lens opened with a Hold starts where its setting says once the Hold ends.
- **A strip whose Hold ends by a letter stays a strip**, modal, in normal mode. It becomes a list at `/`, as it does today at the first letter.
- **A remembered Search** is shown when the Lens opens in Search, selected, and the first typed letter replaces it. In normal mode it is not applied until `/`.
- **`h` and `l` in a list** do nothing. `j` and `k` in a one-row strip step as the arrows do.
- **Where it lives.** `lensKeyMeaning` is the one decision for the panel, key equivalents, Carbon and queued opening keys. The change is there and in the lifecycle's release path, which already ends the Hold. The Search field takes the keyboard only in Search.
- **Queued keys.** A letter that arrives while the Lens is opening ends the Hold when it is replayed, and the keys queued after it are read with no Hold.
- **The stuck Hold.** A release that lands before the Lens begins opening leaves a list's Hold on until the next modifier event. With this change the first letter ends it anyway. Say in the pull request whether anything of that edge is left.
- **Showing the state.** The Search row reads as inactive in normal mode and shows a `/` hint; say what you drew.
- **The live run** is the Hold's own, in a guest, with posted keys, on a release build as the `vm` skill describes: the gesture, the letter that ends it, movement by `hjkl`, `/` and a Search, Escape back to normal, a paste in Search, and a bound chord in each state.

## Done when

- [ ] Cmd-Tab, Tab, Tab, release: the selection steps at each press and the window selected at release is focused, as today.
- [ ] Cmd-Tab, then `j` with Command still down: the strip stays open after Command is released, and the selection has moved as the down arrow would move it.
- [ ] In an open grid with nothing held, `h`, `j`, `k`, `l` move the selection as the arrows do, and "saf" typed leaves Search empty.
- [ ] `/` then "saf" makes Search read "saf"; Escape returns to normal mode with the matches kept; `j` then moves among them; a second Escape dismisses.
- [ ] In Search, with Command down, `a` selects all of Search and `v` pastes; neither types a letter.
- [ ] `winmux lens search` opens taking letters as Search at once, and `starts-in = 'normal` on it makes it wait for `/`.
- [ ] `cmd-w` during the Hold closes the selected window and the Hold goes on; `cmd-g` in a list or grid after the Hold changes the grouping; a plain letter bound in the Lens's `keys` runs its command in normal mode.
- [ ] Backspace during a Hold and in normal mode changes nothing.
- [ ] The same holds for a grid and a list opened by a chord with modifiers, and for an Option Hold.
- [ ] The key record in `winmux debug-lens-trace` shows the Hold ending at the letter and names the state each key was read in.
- [ ] `docs/lenses.md` describes the Hold and the two modal states as built, and agrees with `CONTEXT.md`.

## Sources

- Prateek, 2026-10-05: "I can imagine cmd-tabbing with cmd held and Tab pressed a couple of times. I can't imagine holding Command and then typing." He chose "a letter goes modal" and "setting only".
- Prateek, 2026-10-07, after daily-driving `0.5.6-dogfood.13`: "we need to make the Exposé/grid-style thing feel like vim normal mode: / to search, hjkl/arrows to move, etc."
- Pull request [#81](https://github.com/prateek/winmux/pull/81), which built the rule this replaces.
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
