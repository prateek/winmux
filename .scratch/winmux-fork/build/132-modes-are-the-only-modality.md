# Modes are the only modality

Part of {{UMBRELLA}}.

## What to build

Today keys live in two places. A binding mode, `main` or `window`, is a record of chords that `mode <name>` makes current. A Lens carries its own `keys`, and an open Lens session reads them through three states of its own: the Hold, while the opening chord's modifiers stay down; normal; and Search. The Hold has a five-step reading order, ends on release with `on-release` or on the first unbound letter, and never commits after a letter. A user cannot read the config and predict what a key does while a Lens is open, and cannot compose a mode of their own that drives a Lens.

Make modes the only modal concept. A mode gains a lifetime, a policy for unbound keys, and commands on entry and on release. A Lens becomes a view: a Filter, a Presentation and a sort, opened and closed by commands. Every rule the Lens session applied moves into shipped mode definitions in `defaults.ncl`, into a Presentation property, or into one engine rule named below, where a user can see and change it.

## Decisions

- **A mode is a named record of chords to command lists, with four properties.** `lifetime` is `'latched`, current until a command changes the mode, or `'held`, current while the modifiers of the chord that entered it stay down. `unbound` says what an unbound key does: `'pass` to the app; `'consume`; `'type` into the open Lens's Search field; or `'latch`, which switches to the mode named by `latch-to` on the first unbound letter and reads that letter there, while other unbound keys, digits, Backspace, Space and punctuation, are consumed. `on-enter` is a command list run on entry. `on-release` is a command list run when a held mode's modifiers release. A held mode whose `on-release` commits also has a timing setting, `draw-delay`, below.
- **Matching in a held mode.** Return, the arrows, Escape and the peek key match with the entry modifiers removed first; every other chord matches as pressed first, then with the entry modifiers removed. So a record written for Cmd-Tab says `tab`, `shift-tab` and `w`, and Cmd-W pressed while Command is down matches `w`.
- **The entry modifiers are Command, Control and Option**, never Shift, unless Shift is the chord's only modifier. So Cmd-Shift-Tab enters `cmd-tab` holding on Command, and a repeated Cmd-Shift-Tab minus Command matches `shift-tab`, stepping back as today. Releasing all the entry modifiers runs `on-release`.
- **A chord with a foreign modifier leaves a held mode**, closes its Lens and runs the chord's global binding. In a latched mode an unbound modifier chord runs its global binding and closes the Lens too.
- **No stack.** `mode <name>` replaces the current mode. A Lens is entered through a mode exactly once; the chord that entered it, pressed again while the Lens is open, is a key in the current mode. In the shipped held modes it steps; in `browse` and `search` it is bound to close, so repeating Option-slash toggles Search closed. An ad-hoc Lens is the same Lens when its Filter text and resolved settings are equal.
- **Closing a Lens returns to `main`.** `lens close`, a focus or Summon that closes, and `winmux lens close` from the CLI all end in `main`, so nobody is left in a Lens-operating mode with no Lens; the click outside the panel, built by **Clicking outside a Lens does not dismiss it**, ends the same way. A mode's own Escape key may name another mode instead.
- **A Lens has no `keys`, `on-release` or `starts-in`.** Its config is Filter, Presentation, sort, Tile, sections, popups, hints and `when`. A Nickel config that still sets one fails `config check` with a message naming the mode property that replaces it, and `docs/default-config.md` gains a migration section with the three rewrites. `config convert` is unaffected: a TOML config has no Lens keys, and the six default Lenses it imports come with the shipped modes.
- **A Lens keeps view state and no key state**: its selection, its Search text, its Lens marks and, for an arrangement, its focused pane. Modes read and change that state through the verbs.
- **Lens verbs** act on the open Lens from any mode's keys: `lens step next`, `lens step prev`, `lens step <direction>` for left, right, up and down; `lens focus`; `lens summon`; `lens peek`; `lens close`; `lens close-window`; `lens sections next`; `lens mark`; `lens pane next`; `lens presentation <name>`, which converts the open Lens keeping its selection; `lens settle <mode>`, defined by **Trackpad gestures as held modes**. With no Lens open each exits 1 and does nothing. Entering Search is `mode search`, not a verb.
- **`lens <name>` alone changes no mode.** An opener is a pair, `["lens search", "mode search"]`, or a mode whose `on-enter` opens the Lens, as the shipped Cmd-Tab is. Either way the Lens opens once. A Lens opened from `main` with no mode is drawn and inert to plain keys, which pass to the app as `main`'s `unbound` says.
- **A Presentation defines what a direction step does**: in a list, left and right do nothing while the mode is `browse` and move the caret while it is `search`; in a one-row strip, up and down cycle as previous and next; in a grid, miniatures and an arrangement, each arrow moves to the nearest Tile.
- **Commit timing is a mode property.** A held mode whose `on-release` runs `lens focus` draws its Lens after `draw-delay`, 100 ms by default, so a quick Cmd-Tab release never flashes a panel; a release before the Lens is ready runs `on-release` once it is, and a latch during opening cancels that release. Every other mode draws at once.
- **Hints discount the held modifiers.** While a held mode is current, its entry modifiers do not count as the hints key or as a Summon key's modifiers. After release or a mode change they count again.
- **`list-modes --current` reports the real mode** while a Lens is open, `cmd-tab` or `browse`, not `main`; the menu bar's mode letter and the HUD follow.
- **A gesture enters a mode** the same way a chord does, as **Trackpad gestures as held modes** says; this issue builds the lifetimes and the gesture issue binds them.
- **The glossary changes.** `CONTEXT.md` gains **Mode** with the four properties; **Lens** becomes a view opened by a key in any mode, a gesture or the CLI, with the view state above; **Trigger** and **Hold** are deleted; **Search** stays as the text typed into a Lens; **Hold**, **held mode** and **strip mode** go on Mode's avoid list.

## The shipped modes

`defaults.ncl` defines these; the records are built from `winmux/keys.ncl` once **The shipped keyboard: a minimal main and a full window mode** lands, and are written out in full here, each mode complete and no record merged over another, so that this issue stands alone and the block evaluates as written. The shipped `main` binds the three Option openers it has today; **The shipped keyboard** changes them later. The Cmd-Tab and Cmd-backtick modes ship, but nothing binds them: the opt-in stays the user's three lines, now in mode form.

```nickel
mode.main.binding = {
  alt-slash = "mode search-hold", alt-shift-o = "mode overview-hold",
  alt-semicolon = "mode window",
},
# The Cmd-Tab opt-in, merged by the user over defaults as today:
#   mode.main.binding.cmd-tab = "mode cmd-tab",
#   mode.main.binding.cmd-shift-tab = "mode cmd-tab-back",
#   mode.main.binding.cmd-backtick = "mode cmd-backtick",
mode.cmd-tab = {
  lifetime = 'held, unbound = 'latch, latch-to = "browse", draw-delay = 100,
  on-enter = ["lens recent"], on-release = ["lens focus", "mode main"],
  binding = {
    tab = "lens step next", shift-tab = "lens step prev", backtick = [],
    left = "lens step left", right = "lens step right", up = "lens step up", down = "lens step down",
    enter = ["lens focus", "mode main"], shift-enter = ["lens summon", "mode main"],
    w = "lens close-window", y = "lens peek", g = "lens sections next",
    slash = ["lens presentation list", "mode search"],
    esc = ["lens close", "mode main"],
  },
},
mode.cmd-tab-back = {
  lifetime = 'held, unbound = 'latch, latch-to = "browse", draw-delay = 100,
  on-enter = ["lens recent", "lens step prev"], on-release = ["lens focus", "mode main"],
  binding = {
    tab = "lens step next", shift-tab = "lens step prev", backtick = [],
    left = "lens step left", right = "lens step right", up = "lens step up", down = "lens step down",
    enter = ["lens focus", "mode main"], shift-enter = ["lens summon", "mode main"],
    w = "lens close-window", y = "lens peek", g = "lens sections next",
    slash = ["lens presentation list", "mode search"],
    esc = ["lens close", "mode main"],
  },
},
mode.cmd-backtick = {
  lifetime = 'held, unbound = 'latch, latch-to = "browse", draw-delay = 100,
  on-enter = ["lens app-windows"], on-release = ["lens focus", "mode main"],
  binding = {
    backtick = "lens step next", shift-backtick = "lens step prev", tab = [],
    left = "lens step left", right = "lens step right", up = "lens step up", down = "lens step down",
    enter = ["lens focus", "mode main"], shift-enter = ["lens summon", "mode main"],
    w = "lens close-window", y = "lens peek", g = "lens sections next",
    slash = ["lens presentation list", "mode search"],
    esc = ["lens close", "mode main"],
  },
},
mode.search-hold = {
  lifetime = 'held, unbound = 'latch, latch-to = "search",
  on-enter = ["lens search"], on-release = ["mode search"],
  binding = { tab = "lens step next", shift-tab = "lens step prev", enter = ["lens focus", "mode main"], esc = ["lens close", "mode main"] },
},
mode.overview-hold = {
  lifetime = 'held, unbound = 'latch, latch-to = "browse",
  on-enter = ["lens overview"], on-release = ["mode browse"],
  binding = { tab = "lens step next", shift-tab = "lens step prev", enter = ["lens focus", "mode main"], esc = ["lens close", "mode main"] },
},
mode.browse = {
  lifetime = 'latched, unbound = 'consume,
  binding = {
    h = "lens step left", j = "lens step down", k = "lens step up", l = "lens step right",
    left = "lens step left", right = "lens step right", up = "lens step up", down = "lens step down",
    tab = "lens mark", enter = ["lens focus", "mode main"], shift-enter = ["lens summon", "mode main"],
    y = "lens peek", g = "lens sections next", slash = ["lens presentation list", "mode search"],
    alt-slash = ["lens close", "mode main"], alt-shift-o = ["lens close", "mode main"],
    esc = ["lens close", "mode main"],
  },
},
mode.search = {
  lifetime = 'latched, unbound = 'type,
  binding = {
    up = "lens step up", down = "lens step down", left = "lens step left", right = "lens step right",
    enter = ["lens focus", "mode main"], shift-enter = ["lens summon", "mode main"],
    cmd-w = "lens close-window", cmd-y = "lens peek", cmd-g = "lens sections next",
    alt-slash = ["lens close", "mode main"],
    esc = "mode browse",
  },
},
```

In `window` mode the six Lens letters become `w = ["mode main", "lens windows", "mode browse"]` and so on, with `s` ending in `mode search` and `r` and `a` opening their text lists into `search`.

## Where each rule of the Hold goes

Every rule in `docs/lenses.md`, "The Hold", "Release and appearance" and the Search paragraphs, and its home after this issue.

| Rule today | Home |
| --- | --- |
| Return matches with the opening modifiers removed before the pressed chord; Shift-Return Summons | Matching in a held mode; `enter` and `shift-enter` in each shipped mode |
| The opening key steps, Shift reverses; the other opener's key is consumed | `tab`, `shift-tab` and `backtick = []` in `cmd-tab`; mirrored in `cmd-backtick` |
| In a staying held list, Tab steps the matches | `tab` in `search-hold` |
| Arrows move and Escape dismisses with the modifiers removed | Matching in a held mode |
| The first unbound letter or `/` ends the Hold; the letter is read in the starting state; `/` starts Search; a strip stays a strip at a letter; `/` converts a strip to a list keeping its selection; a list configured to start in Search types the letter | `unbound = 'latch` with `latch-to = "browse"` on `cmd-tab` and `"search"` on `search-hold`; `slash = ["lens presentation list", "mode search"]` |
| Backspace, digits, Space, punctuation and function keys do nothing during a Hold | The `'latch` policy consumes them |
| A foreign-modifier chord belongs to its global binding and dismisses | Foreign-modifier rule |
| Peek matches with the modifiers removed; Cmd-Y during Cmd-Tab | Matching in a held mode; `y` in `cmd-tab` |
| Release ends the Hold; commit for a strip, stay otherwise | `on-release` of each shipped mode |
| A Hold ended by a key never commits on release, a release received while opening included | A latch replaces the held mode, so release runs nothing; commit timing rule |
| One session never starts a second Hold; repeating the chord after a letter toggles the Lens closed; ad-hoc identity | No stack; the entry chord bound to close in `browse` and `search` |
| Every committing Hold uses the 100 ms display deadline | `draw-delay` |
| Normal mode: a bound key wins, `hjkl` move, list `h`/`l` do nothing, one-row strip `j`/`k` cycle, `/` enters Search, Return runs, Escape dismisses, Tab marks, other plain keys are consumed | `browse` with `unbound = 'consume`; direction steps are the Presentation's |
| An unbound modifier chord belongs to its global binding | Latched-mode rule |
| Search: the editor owns letters, Backspace and clipboard chords, Command-A and Command-V included, while the opening modifiers are still down; a bound chord wins; plain-letter bindings are typed | `search` with `unbound = 'type`: an unbound chord of any modifier goes to the editor, a bound one runs |
| Search: up and down move selection; left and right move Tiles in grid and miniatures and the caret in a list | `search` binds the arrows; the list Presentation moves the caret for left and right in `search` |
| Search: Return commits; Escape returns to normal keeping the text; a second Escape dismisses | `enter` and `esc` in `search`, `esc` in `browse` |
| The Search row is muted and shows `/` in the Hold and normal; clicking it enters Search | A click on the Search row runs `mode search` |
| Letters arriving before the editor is ready are kept in order; queued opening keys are decided by the resulting state; other Carbon bindings run at once and dismiss | Engine rule: keys pressed while a Lens is opening are queued and read in the mode current when it is ready; a global chord runs at once and closes it |
| Before the panel is key, an unregistered key goes to the app in front | Unchanged limit, still documented |
| `starts-in`: explicit, or Search for a list and normal otherwise; a Lens with a Hold enters it when the Hold ends | The `'latch` target of each held mode; a CLI or `window` opener names its mode in the pair |
| Hints and Summon keys discount the Hold's invoking modifiers | Hints rule |
| Lens `keys` run on the selected window; Escape, Tab and the arrows cannot be rebound; `peek` runs alone | Verbs act on the selection; any key may be rebound in a mode; `lens peek` runs alone as today |

## Not in this issue

- The click outside a Lens's panel: **Clicking outside a Lens does not dismiss it**. This issue states where it ends; that one builds it.
- The minimal `main` and the full keyboard module: **The shipped keyboard: a minimal main and a full window mode**.
- The HUD legend: **The HUD can show the current mode's keys**.
- The marks commands: **focus-back, mark and jump**.

## Depends on

Nothing.

## Defaults chosen for you

- **`unbound` defaults to `'pass`** for a mode with no `on-enter` Lens and `'consume` otherwise, so a user's own Lens mode is safe by default.
- **`winmux mode <name>` from the CLI enters a held mode as latched**, since no modifiers are down, and says so on stderr.
- **A pointer click on the Search row** runs `mode search`; a click on a Tile selects it as today.
- **The HUD names the current mode while it is not `main`**, including `browse` and `search`.

## Done when

- [ ] `defaults.ncl` defines the modes above and the block in this issue loads under `config check` as written; the opt-in's three lines in mode form, Option-slash, Option-Shift-o and the six `window` letters open each Lens exactly once; and a config that merges the opt-in lines over defaults gets Cmd-Tab while one that does not leaves the system's switcher alone.
- [ ] A Nickel config with `lenses.<name>.keys`, `on-release` or `starts-in` fails `config check` with a message naming the mode property that replaces it, and the docs' migration section shows the rewrite.
- [ ] Tests cover each row of the table above: at least one test per row, named for the rule.
- [ ] Tests cover the lifetime rules: held release runs `on-release`; a latch makes a later release run nothing; a foreign-modifier chord leaves a held mode and its global binding runs; `lens <name>` alone leaves `main` current and plain keys reach the app; closing a Lens by key and by the CLI ends in `main`; Cmd-Shift-Tab repeated steps back; `list-modes --current` reports `browse` while a browsed Lens is open.
- [ ] In a guest, Cmd-Tab, Cmd-Shift-Tab, Cmd-W during the hold, release, Option-slash then typing, Escape twice, and Option-Shift-o then `hjkl` all behave as `docs/lenses.md` describes today, and the docs describe them as modes.
- [ ] `CONTEXT.md` has the new Mode and Lens entries and no Trigger or Hold entry; `docs/lenses.md` has no section named The Hold; `docs/default-config.md` lists the shipped modes with their properties, `draw-delay` included.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: Cmd-Tab and Option-slash under his own config, with the modes his config defines.

## Sources

- The grilling record, 2026-10-19: [what WinMux becomes](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/36-grilling-what-winmux-becomes.md), "Modality".
- Prateek, 2026-10-19: "i should be able to be in a mode while holding a key, that's all cmd-tab is, if i then need to switch to a different mode where i don't need to be holding command any more, i should express that - it doesn't need to be coupled to every lens".
- `docs/lenses.md`, "The Hold", for the rules the table places.
