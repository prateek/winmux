# Hint mode: type a label to reach a window

Part of {{UMBRELLA}}.

## What to build

Vimium's `f` puts a letter label on every link on the page, and typing the label follows it; Neru does the same over every clickable element on the desktop, with a home-row alphabet, a rule for labels once single letters run out, `/` to filter by text and Tab to cycle, and it can label Mission Control's windows. Nothing in WinMux reaches a window that way: `focus` takes a direction or an id, `find-focus` shows where the focused window is, and the modifier-held hints of **Shortcut hints on tabs while the modifier is held** and **Modifier-held hints on the sidebar and on move targets** show a key that is already bound, a digit in the shipped defaults. Prateek asked for the Vimium version: a key that labels what is on screen and reaches whatever label he types.

Build it as a latched mode that reads labels, under **Modes are the only modality**: a mode whose unbound letters go to the label matcher rather than to a binding, ended by the command it runs or by Escape. Neru's precedence applies: a key the mode binds answers first, and only an unbound letter is a label.

## Decisions

- **`mode hints` is a latched mode with `unbound = 'labels`**, a fourth unbound policy this issue adds: unbound letters go to the label matcher, every other unbound key is consumed, Escape cancels as in any mode, and the mode ends when a label completes and its command runs. It labels every target on the focused monitor: each visible window, each Column mark, each sidebar workspace row, and each tab of the focused tab group. With a Lens open, the targets are the Lens's Tiles and its workspace miniatures instead, so `f` inside the overview reaches an entry the way Neru reaches a Mission Control window. The label sits at the target's top-left with the same renderer the modifier-held hints use.
- **Labels come from an alphabet and a direction**, as Neru enumerates them. `hints.alphabet` defaults to the home row, `asdfghjkl`, and is refused when shorter than two letters or with a repeat. `hints.label-direction` is `'normal`, which keeps single letters and expands the last slot into pairs once targets outnumber letters, or `'reverse`, which fills the pair tier evenly from the first letter so that first letters spread across the screen; the default is `'normal`.
- **The mode's own keys**: Backspace removes the last typed letter; Tab and Shift-Tab cycle a highlighted target and Return activates it, for a target whose label is awkward to read; `/` enters a text filter where typing narrows the targets by window title and app name, with the labels reassigned to what remains, and Return activates a single match.
- **Typing a label focuses the target**: a window gets focus, a Column focuses its remembered window, a workspace row switches to it, a tab focuses it. The mode ends with the command, as a transient mode does.
- **A key chooses the verb.** `f` in `window` runs `["mode hints", "hints focus"]`; Shift-f runs `["mode hints", "hints move"]`, where the move form moves the focused window to the target the label names, a Column, a workspace row or another window's position; `hints summon` brings the labelled window to the current workspace, as a Lens's Summon does. This issue adds the first two bindings to the `window` block, on the `f` that **The shipped keyboard: a minimal main and a full window mode** freed, and the user binds the third.
- **Two-letter labels filter as typed**: the first letter dims every label that does not start with it; a second letter completes it; Escape cancels; a letter that matches nothing is consumed.
- **Labels never cover each other** and never cover the label of a smaller target inside a larger one: a window's label yields to its Column mark's by an offset the renderer chooses.
- **The hint renderer is shared** with the modifier-held hints, so the two look the same and a change to one is a change to both. Its settings are a record, `hints.ui`, with the font size, the pill radius and the placement on the target, top, centre or bottom, as Neru's are.

## Not in this issue

- Labels on other monitors; the focused monitor only.
- Labels inside apps, on their buttons or links; that is Vimium's job.

## Depends on

- **Modes are the only modality**.
- **The shipped keyboard: a minimal main and a full window mode**, which frees `f`.

## Defaults chosen for you

- **The keys the mode binds** are the shipped `hints` block of the keymap, so a user rebinds Tab, `/` or Return there like any other key.
- **A target with no room for a label**, a window narrower than two labels, gets its label clipped to the screen rather than dropped.

## Done when

- [ ] Tests cover label assignment for nine and for twenty targets under both directions, two-letter filtering with the mode staying current between the letters, Backspace, Tab cycling and Return, the `/` filter narrowing by title, the four target kinds under `focus`, `move` and `summon`, labels on a Lens's Tiles while a Lens is open, Escape, and a non-matching letter.
- [ ] In a guest on the rich desk, a demo shows `f`, the labels on fourteen windows and three Column marks, a two-letter label focusing a window; a second shows Shift-f moving a window into a labelled Column.
- [ ] `docs/` describes the mode, its alphabet and direction, its own keys and the three verbs, beside the modifier-held hints.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: hint mode on the ultrawide with his own workspaces, and whether nine letters are enough before pairs appear.

## Sources

- Prateek, 2026-10-19: "i was reading the focus issue you posted and it made me think of vimium. how does it handle command v ... mode? and what about emacs? what would our design look like if we did that" and, on the answer, "ok i like that i think".
- The grilling record's addendum of 2026-10-19 on prefix keys, counts, cancel and hint mode.
- Neru's hints mode, its `hint_characters`, `label_direction`, `[hints.hotkeys]` and `[hints.ui]`, and its rule that a mode's bound keys answer before its labels, at github.com/y3owk1n/neru; Prateek, 2026-10-19: "for hints - look at what [Neru] is using".
