# Modes are the only modality

Part of {{UMBRELLA}}.

## What to build

Today keys live in two places. A binding mode, `main` or `window`, is a record of chords that `mode <name>` makes current. A Lens carries its own `keys`, and an open Lens session reads them through three states of its own: the Hold, while the opening chord's modifiers stay down; normal; and Search. The Hold has a five-step reading order, ends on release with `on-release` or on the first unbound letter, and never commits after a letter. A user cannot read the config and predict what a key does while a Lens is open, and cannot compose a mode of their own that drives a Lens.

Make modes the only modal concept, and make the mode a condition on a binding rather than the place a binding lives, as Zed's keymap and VS Code's `when` clauses do. A mode gains a lifetime, a policy for unbound keys, and commands on entry and on release. Bindings move into one keymap list, each block conditioned on a context: the mode, the app in front, the open Lens and its Presentation, the workspace's Columns, the Display profile. A Lens becomes a view: a Filter, a Presentation and a sort, opened and closed by commands. Every rule the Lens session applied moves into shipped mode definitions in `defaults.ncl`, into a Presentation property, or into one engine rule named below, where a user can see and change it.

## Decisions

- **A mode is a named record of properties, and its keys live in the keymap.** `lifetime` is `'latched`, current until a command changes the mode; `'held`, current while the modifiers of the chord that entered it stay down; or `'transient`, current for exactly one key, after which the mode that entered it is current again. A transient mode is Emacs's transient keymap: a one-shot `window` mode entered by a chord, where one `window` key runs and the mode is gone, is the shipped example. Key sequences, `"m a"`, are not modes; they are the keymap's pending state, below. `unbound` says what an unbound key does: `'pass` to the app; `'consume`; `'type` into the open Lens's Search field; or `'latch`, which switches to the mode named by `latch-to` on the first unbound letter and reads that letter there, while other unbound keys, digits, Backspace, Space and punctuation, are consumed. `on-enter` is a command list run on entry. `on-release` is a command list run when a held mode's modifiers release. `latch-to` names the mode a `'latch` policy switches to. `count`, off by default, is below. `draw-delay` applies to a held mode that commits, below. That is the whole list: lifetime, unbound with latch-to, on-enter, on-release, count and draw-delay.
- **Bindings live in a keymap of named blocks, each conditioned on a context.** `keymap` is a record whose fields are blocks, `{ context, bindings, priority }`, so a user adds one with a field of their own and Nickel's `&` merges it; a list would not merge. `context` is a predicate over a fixed vocabulary, `mode`, `app`, `lens`, `presentation`, `columns` and `profile`, with `==`, `!=`, `&&`, `||`, `!` and parentheses, and `lens` or `columns` alone meaning present. A key is a chord, spelled as the config spells chords today, `quote` for the apostrophe, or a space-separated sequence of chords, `"m a"`, `"g t"`, as Zed writes them; a sequence's first chord puts the engine in a pending state that the HUD names and the legend lists, and a chord that continues no sequence cancels it. A binding's value is a command list or `'pass`, which hands the key to the app. When two blocks bind the same key and both contexts hold, the more specific context wins, the one with more conjuncts; at equal specificity the higher `priority` wins, and equal priority is a conflict `config check` reports, so nothing depends on order. The library's blocks have priority 0 and a user's default to 1. `mode.<name>.binding` stays as sugar for a block `mode-<name>` with `context = "mode == <name>"`, so today's configs and AeroSpace's shape still load, and `config check` reports a context that names an unknown variable or a chord it cannot parse.
- **Matching in a held mode.** Return, the arrows, Escape and the peek key match with the entry modifiers removed first; every other chord matches as pressed first, then with the entry modifiers removed. So a record written for Cmd-Tab says `tab`, `shift-tab` and `w`, and Cmd-W pressed while Command is down matches `w`.
- **The entry modifiers are Command, Control and Option**, never Shift, unless Shift is the chord's only modifier. So Cmd-Shift-Tab enters `cmd-tab` holding on Command, and a repeated Cmd-Shift-Tab minus Command matches `shift-tab`, stepping back as today. Releasing all the entry modifiers runs `on-release`.
- **Escape cancels.** In any mode but `main`, an unbound Escape ends the mode: a transient mode returns to the mode that entered it, any other returns to `main` and closes an open Lens. A mode may bind Escape to something else, as the shipped `search` does to return to `browse`.
- **A count is a mode property.** With `count = true`, unbound digits typed before a bound key repeat its command that many times, `3l` focusing three Columns right, as in vim and Vimium. The shipped modes leave it off, since `window` binds the digits to workspaces; the example keyboard module shows a mode with counts on.
- **A chord is left to an app through the context**, Vimium's per-site pass keys and VSCodeVim's `handleKeys` in one line: `{ context = "app == 'com.googlecode.iterm2'", bindings = { ctrl-semicolon = 'pass } }` keeps that chord the terminal's whatever mode is current, since `'pass` as a binding's value means the key reaches the app.
- **A mode library in `winmux.ncl` writes the records.** Every mode and every keymap block is a plain record the engine reads, and nobody has to write one by hand: `W.switcher`, `W.hold`, `W.open`, `W.transient`, `W.when`, `W.keymap` and the shared key sets `W.keys.*` return records whose every field carries `| default`, so a user's `&` overrides one field cleanly; `W.Mode` and `W.Keymap` are the contracts `config check` validates against, and `W.Keymap`'s binding value is `Commands | 'pass`, the sugar's record included. The long form stays valid for anyone who wants it; the shipped defaults use the library.
- **A collection a user extends is a record; a list is a value replaced whole.** The keymap taught this: Nickel's `&` merges records field by field and cannot merge arrays, so anything a person adds to or overrides one member of, Lenses, modes, keymap blocks, Filters, `when` profiles, is a record keyed by name, and a list is kept for an ordered value that is replaced as one, a command list, a hook's `run`, a Lens's `sort`, `width-presets`, a workspace's Column `widths`. The one set still written as a list, a Lens's `popups`, becomes a record of booleans, `popups.accessory-popup = true`, with `config check` naming the old shape and its rewrite. The rule goes into `CONTEXT.md` beside the Keymap entry, so the next field follows it.
- **A chord with a foreign modifier leaves a held mode**, closes its Lens and runs the chord's global binding. In a latched mode an unbound modifier chord runs its global binding and closes the Lens too.
- **No stack.** `mode <name>` replaces the current mode. A Lens is entered through a mode exactly once; the chord that entered it, pressed again while the Lens is open, is a key in the current mode. In the shipped held modes it steps; in `browse` and `search` it is bound to close, so repeating Option-slash toggles Search closed. An ad-hoc Lens is the same Lens when its Filter text and resolved settings are equal.
- **Closing a Lens returns to `main`.** `lens close`, a focus or Summon that closes, and `winmux lens close` from the CLI all end in `main`, so nobody is left in a Lens-operating mode with no Lens; the click outside the panel, built by **Clicking outside a Lens does not dismiss it**, ends the same way. A mode's own Escape key may name another mode instead.
- **A mode and its Lens are one thing exactly when the mode opened the Lens.** A Lens opened by a mode's `on-enter` belongs to that mode: ending either ends both, closing it returns to `main` as the Decision above says, and the mode's entry modifiers end with it. A Lens opened by a key binding while some other mode is current is not that mode's Lens: closing it changes nothing about the mode, its lifetime or its entry modifiers, so a held `'pass` mode that opened a Lens through a key keeps waiting on its modifiers and ends on their release as before.
- **A Lens has no `keys`, `on-release` or `starts-in`.** Its config is Filter, Presentation, sort, Tile, sections, popups, hints and `when`. A Nickel config that still sets one fails `config check` with a message naming the mode property that replaces it, and `docs/default-config.md` gains a migration section with the three rewrites. `config convert` is unaffected: a TOML config has no Lens keys, and the six default Lenses it imports come with the shipped modes.
- **A Lens keeps view state and no key state**: its selection, its Search text, its Lens marks and, for an arrangement, its focused pane. Modes read and change that state through the verbs.
- **Lens verbs** act on the open Lens from any mode's keys: `lens step next`, `lens step prev`, `lens step <direction>` for left, right, up and down; `lens focus`; `lens summon`; `lens peek`; `lens close`; `lens close-window`; `lens sections next`; `lens mark`; `lens pane next`; `lens presentation <name>`, which converts the open Lens keeping its selection; `lens caret left` and `lens caret right`, which move the Search field's caret; `lens settle <mode>`, defined by **Trackpad gestures as held modes**. With no Lens open each exits 1 and does nothing. Entering Search is `mode search`, not a verb.
- **`lens <name>` alone changes no mode.** An opener is a pair, `["lens search", "mode search"]`, or a mode whose `on-enter` opens the Lens, as the shipped Cmd-Tab is. Either way the Lens opens once. A Lens opened from `main` with no mode is drawn and inert to plain keys, which pass to the app as `main`'s `unbound` says.
- **A Presentation's direction keys are keymap blocks on `presentation`**, not rules inside the Presentation. The shipped blocks: under `presentation == list && mode == search`, left and right move the caret; under `presentation == list && mode == browse`, `h` and `l` do nothing; under `presentation == strip && (mode == browse || mode == cmd-tab || mode == cmd-backtick)`, up and `k` step back and down and `j` step forward. Each is more specific than the mode's own block, so it wins. A user who wants a list's left and right to step Tiles overrides one block.
- **Commit timing is a mode property.** A held mode whose `on-release` runs `lens focus` draws its Lens after `draw-delay`, 100 ms by default, so a quick Cmd-Tab release never flashes a panel; a release before the Lens is ready runs `on-release` once it is, and a latch during opening cancels that release. Every other mode draws at once.
- **A held mode reads the modifiers it waits on after the queued keys have run**, not before. A Cmd-Tab held back behind a Lens opening that failed starts the switcher against the modifiers actually down when it runs, so it does not commit while Command is still held.
- **Hints discount the held modifiers.** While a held mode is current, its entry modifiers do not count as the hints key or as a Summon key's modifiers. After release or a mode change they count again.
- **`list-modes --current` reports the real mode** while a Lens is open, `cmd-tab` or `browse`, not `main`; the menu bar's mode letter and the HUD follow.
- **A gesture enters a mode** the same way a chord does, as **Trackpad gestures as held modes** says; this issue builds the lifetimes and the gesture issue binds them.
- **The glossary changes.** `CONTEXT.md` gains **Mode** with the six properties and **Keymap** with the context vocabulary; **Lens** becomes a view opened by a key in any mode, a gesture or the CLI, with the view state above; **Trigger** and **Hold** are deleted; **Search** stays as the text typed into a Lens; **Hold**, **held mode** and **strip mode** go on Mode's avoid list.

## The shipped modes

`defaults.ncl` defines them through the library; this block is its `mode` and `keymap` part, and the rest of the file, Lenses, Filters, gaps and the sidebar, is unchanged. `W.keys.main-today` is today's 40 `main` chords, kept whole here and shrunk by **The shipped keyboard: a minimal main and a full window mode**; `W.keys.navigate`, `.workspaces`, `.columns` and `.lenses` are today's 45 `window` keys split into four groups, with the Column and mark keys added by that issue. `W.keymap` is the library's own blocks, `browse` and `search` as `W.modes` defines them below, so a user's block merges beside them. The Cmd-Tab and Cmd-backtick modes ship but nothing binds them: the opt-in stays the user's three lines, now in mode form, shown in the comment.

```nickel
mode = W.modes & {
  cmd-tab = W.switcher { lens = "recent", key = "tab" },
  cmd-tab-back = W.switcher { lens = "recent", key = "tab", start = 'prev },
  cmd-backtick = W.switcher { lens = "app-windows", key = "backtick" },
  search-hold = W.hold { lens = "search", latch = "search" },
  overview-hold = W.hold { lens = "overview", latch = "browse" },
  window-once = W.transient { bindings = W.keys.navigate & W.keys.workspaces & W.keys.columns },
},
keymap = W.keymap & {
  main = W.when "mode == main" (W.keys.main-today & {
    alt-slash = W.open "search" 'search, alt-shift-o = W.open "overview" 'browse,
    alt-semicolon = "mode window", alt-shift-semicolon = "mode window-once",
    # The Cmd-Tab opt-in, a block the user adds:
    #   keymap.cmd-tab-opt-in = W.when "mode == main" { cmd-tab = "mode cmd-tab", cmd-shift-tab = "mode cmd-tab-back", cmd-backtick = "mode cmd-backtick" }
  }),
  window = W.when "mode == window" (W.keys.navigate & W.keys.workspaces & W.keys.columns & W.keys.lenses
    & { "m <r>" = "mark <r>", "quote <r>" = "jump <r>" }),
  list-search = W.when "presentation == list && mode == search" { left = "lens caret left", right = "lens caret right" },
  list-browse = W.when "presentation == list && mode == browse" { h = [], l = [] },
  strip = W.when "presentation == strip && (mode == browse || mode == cmd-tab || mode == cmd-backtick)"
    { up = "lens step prev", k = "lens step prev", down = "lens step next", j = "lens step next" },
}
```

What each library call returns, written once so that the semantics are specified without five copies.

- **`W.switcher { lens, key, start }`** is a held committing mode: `lifetime = 'held`, `unbound = 'latch`, `latch-to = "browse"`, `draw-delay = 100`, `on-enter = ["lens <lens>"]` with `"lens step prev"` appended when `start = 'prev`, `on-release = ["lens focus", "mode main"]`, and a record binding `<key>` to `lens step next`, `shift-<key>` to `lens step prev`, the other switcher key, backtick or tab, to `[]` so it is consumed, the arrows to `lens step` in their directions, `enter` to `["lens focus", "mode main"]`, `shift-enter` to `["lens summon", "mode main"]`, `w` to `lens close-window`, `y` to `lens peek`, `g` to `lens sections next`, `slash` to `["lens presentation list", "mode search"]`, and `esc` to `["lens close", "mode main"]`.
- **`W.hold { lens, latch }`** is a held staying mode: `lifetime = 'held`, `unbound = 'latch`, `latch-to = <latch>`, `on-enter = ["lens <lens>"]`, `on-release = ["mode <latch>"]`, with `tab` and `shift-tab` stepping, `enter` focusing, `esc` closing as above, and `slash` bound to `["lens presentation list", "mode search"]`, so `/` starts Search from a hold as it does today; a bound key is never consumed by the latch policy.
- **`W.open "<lens>" '<mode>`** is the pair `["lens <lens>", "mode <mode>"]`.
- **`W.transient { bindings, on-enter }`** is `lifetime = 'transient`, `unbound = 'consume`, with `on-enter` optional, and it also emits the keymap block `mode-<name>` holding `bindings`, which is what makes it one call.
- **`W.when "<context>" { … }`** is one keymap block, `{ context = "<context>", bindings = { … }, priority = 0 }`. A key written `"m <r>"` with `<r>` on both sides of the binding expands over the registers `a` to `z`; the sequence itself needs no helper, since a space-separated key is the keymap's own syntax.
- **`W.modes.browse`** is latched and consuming, and `W.keymap` carries its block under `mode == browse`: `h`, `j`, `k`, `l` and the arrows step, `tab` marks, `enter` focuses and `shift-enter` summons then return to `main`, `y` peeks, `g` changes sections, `slash` converts to a list and enters `search`, the Option openers close the Lens and return to `main`, `esc` closes and returns to `main`.
- **`W.modes.search`** is latched and typing, with its block under `mode == search`: the arrows step, `enter` and `shift-enter` as in `browse`, `cmd-w`, `cmd-y` and `cmd-g` as `w`, `y` and `g` there, Option-slash closes, `esc` returns to `browse` with the text kept.
- **`W.keys.main-today`**, **`.navigate`**, **`.workspaces`**, **`.columns`** and **`.lenses`** are today's keys regrouped, as said above; the six Lens letters in `.lenses` are `W.open` pairs ending in `browse` or `search`.

## Where each rule of the Hold goes

Every rule in `docs/lenses.md`, "The Hold", "Release and appearance" and the Search paragraphs, and its home after this issue.

| Rule today | Home |
| --- | --- |
| Return matches with the opening modifiers removed before the pressed chord; Shift-Return Summons | Matching in a held mode; `enter` and `shift-enter` in each shipped mode |
| The opening key steps, Shift reverses; the other opener's key is consumed | `W.switcher`'s `key`, its Shift form, and the other switcher key consumed |
| In a staying held list, Tab steps the matches | `tab` in `search-hold` |
| Arrows move and Escape dismisses with the modifiers removed | Matching in a held mode |
| The first unbound letter or `/` ends the Hold; the letter is read in the starting state; `/` starts Search; a strip stays a strip at a letter; `/` converts a strip to a list keeping its selection; a list configured to start in Search types the letter | `W.switcher` latches into `browse`, `W.hold` into its `latch`; both bind `slash` to `["lens presentation list", "mode search"]` |
| Backspace, digits, Space, punctuation and function keys do nothing during a Hold | The `'latch` policy consumes them |
| A foreign-modifier chord belongs to its global binding and dismisses | Foreign-modifier rule |
| Peek matches with the modifiers removed; Cmd-Y during Cmd-Tab | Matching in a held mode; `y` in `cmd-tab` |
| Release ends the Hold; commit for a strip, stay otherwise | `on-release` of `W.switcher` and `W.hold` |
| A Hold ended by a key never commits on release, a release received while opening included | A latch replaces the held mode, so release runs nothing; commit timing rule |
| One session never starts a second Hold; repeating the chord after a letter toggles the Lens closed; ad-hoc identity | No stack; the entry chord bound to close in `browse` and `search` |
| Every committing Hold uses the 100 ms display deadline | `draw-delay` |
| Normal mode: a bound key wins, `hjkl` move, list `h`/`l` do nothing, one-row strip `j`/`k` cycle, `/` enters Search, Return runs, Escape dismisses, Tab marks, other plain keys are consumed | `browse` with `unbound = 'consume`; the `list-browse` and `strip` blocks |
| An unbound modifier chord belongs to its global binding | Latched-mode rule |
| Search: the editor owns letters, Backspace and clipboard chords, Command-A and Command-V included, while the opening modifiers are still down; a bound chord wins; plain-letter bindings are typed | `search` with `unbound = 'type`: an unbound chord of any modifier goes to the editor, a bound one runs |
| Search: up and down move selection; left and right move Tiles in grid and miniatures and the caret in a list | `search` binds the arrows; the `list-search` block binds left and right to the caret |
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

- [x] `winmux.ncl` exposes `W.Mode`, `W.Keymap`, `W.switcher`, `W.hold`, `W.open`, `W.transient`, `W.when`, `W.keys`, `W.modes` and `W.keymap`, every returned field at `| default`; `defaults.ncl`'s `mode` and `keymap` are the block above and the file loads under `config check` with every chord of today's `main` and `window` still bound; a config written in the `mode.<name>.binding` shape loads unchanged; the opt-in's three lines in mode form, Option-slash, Option-Shift-o and the six `window` letters open each Lens exactly once; and a config that merges the opt-in lines over defaults gets Cmd-Tab while one that does not leaves the system's switcher alone.
- [x] A Nickel config with `lenses.<name>.keys`, `on-release` or `starts-in` fails `config check` with a message naming the mode property that replaces it, and the docs' migration section shows the rewrite.
- [x] Tests cover each row of the table above: at least one test per row, named for the rule.
- [x] Tests cover the context evaluator on every variable and operator, including an unknown variable failing `config check`; a more specific block winning, `priority` deciding a tie, and an equal tie failing `config check`; a sequence `"m a"` with its pending state named by the HUD and cancelled by a chord that continues no sequence; `"m <r>"` expanding over the registers; `window-once` running one key and returning; `count = true` repeating a command; an unbound Escape cancelling a latched and a transient mode; and `'pass` under an `app` context leaving the chord to that app.
- [x] Tests cover the lifetime rules: held release runs `on-release`; a latch makes a later release run nothing; a foreign-modifier chord leaves a held mode and its global binding runs; `lens <name>` alone leaves `main` current and plain keys reach the app; closing a Lens by key and by the CLI ends in `main`; Cmd-Shift-Tab repeated steps back; `list-modes --current` reports `browse` while a browsed Lens is open.
- [x] In a guest, Cmd-Tab, Cmd-Shift-Tab, Cmd-W during the hold, release, Option-slash then typing, Escape twice, and Option-Shift-o then `hjkl` all behave as `docs/lenses.md` describes today, and the docs describe them as modes.
- [x] `CONTEXT.md` has the new Mode entry with the three lifetimes and the six properties, a Keymap entry with the context vocabulary, and the Lens entry and no Trigger or Hold entry; `docs/lenses.md` has no section named The Hold; `docs/default-config.md` lists the shipped modes with their properties, `draw-delay` included, and the keymap's context vocabulary with one example per variable.
- [x] A line in **Prateek's checks on an installed build and real hardware**: Cmd-Tab and Option-slash under his own config, with the modes his config defines.

## Built and checked

Modes own keyboard modality through `ModeEngine` and the pure `resolveModeKey`.
Carbon callbacks and panel input use that resolver; `Common/modes` owns the
context parser and the compiler shared by offline checking and the app. No
keyboard event tap was added. Registration follows context and pending input,
omits winning `'pass` chords and Space, and uses only entry-modified aliases
while entry modifiers are held. A key Lens panel owns plain and Shift keys,
including composition; Command, Control and Option chords stay with Carbon.
Main's global command chords remain registered over an open Lens. Continuations
register synchronously at a sequence prefix, and Return registers keypad Enter too.
Outside a key Lens panel, unregistered keys reach the app, cancel pending input
and end transient modes. The docs state this limit.

The Lens is a view with selection, Search, marks and Presentation state. Its
old keys, three input states, `starts-in` and `on-release` are removed. New Lens
verbs operate on that state; `lens run` carries selection/mark command dispatch.
Closing a Lens a mode owns ends that mode in `main`; closing a Lens no mode owns
changes no mode. Ready input and later input share a queue, replacement
invalidates old entry work, and a foreign global chord interrupts opening.
Held release uses event modifiers; readiness and the draw deadline alone sample
live flags. Native Search preserves caret, selection, clipboard and composition.

Ordinary queued input carries an epoch. Interrupting opening advances it,
drops all unstarted old actions and queues the global action ahead of later
input. Readiness follows `on-enter`, including failed or cancelled Lens
preparation and modes that open no Lens. Parked keys and release keep their
arrival order. CLI readiness owns the queue too. Editor pass-through is decided
synchronously only when that queue is idle.

Cancelled openings drain parked keys and releases into the current mode, even
when it changed during the opening. A newer Lens drops that parked work. One
readiness drain keeps typing modifiers and stops on cancellation. Lens ownership
is recorded by mode generation: `on-enter` owns its opening, and a mode that needs
a Lens adopts one already open when it enters. Other openers own no mode. A failed
owned opening ends its owner after the drain, unless a parked key replaced that
mode. Unknown and disabled names, invalid Filter syntax, incompatible miniature
options and URL refusals validate before beginning a Lens or recording a trace;
an `on-enter` rejected there follows the same owner cleanup. A cancelled drain
never clears a newer opening's parked work. Held and typing modifiers are read
live after parked actions, or from the supplied event when none ran. Dismissal
uses a mode-generation guard and runs ahead of an in-flight input action, surviving
reloads and input-epoch changes. Interrupt actions serialize with each other while
bypassing ordinary input in flight. Release closes only the mode's owned Lens,
including an in-place Presentation change; a Lens opened by `on-release` stays.
A failed `on-release` logs and follows the same return to `main`. Held latch redispatch strips
entry modifiers without replaying the original modified event; unmodified
composition keeps native replay.

The ownership/release check passes on the host and pinned-version guest:
1,817 Swift, 94 Rust/helper and 171 script tests (one existing guest-only script
skip). All 27 input-order tests and 16 ownership scenarios pass. Thirteen
regressions produced 31 failing assertions with the implementation reverted;
isolated reversions also reproduced the newer-opening drain, entry/replacement
ownership, adoption and unowned-cancellation defects. The cache is structurally
verified and covered by adoption behavior, without a timing claim.
The guest run checks selected-window focus on held Cmd-Tab release, Escape
returning typing to the prior app, a missing named Lens leaving browse and its
Lens untouched, and an unowned Lens toggle preserving a held pass mode until
release runs its command. The two windows are on one workspace; no nonempty
Search or permission grant is involved.

Showing with entry modifiers and latching from that visible Lens take key focus
without activating WinMux.
Ad-hoc identity includes Search again, distinguishing omission from an explicit
empty Search. App loading and offline checking reject
missing or latching latch targets; Search-row transitions use configured targets
through the input queue. `lens run`, close-window and Summon share the real
marked-action path and preserve URL provenance. One parsed command-list helper
owns Lens-opener, reverse-step and focus recognition. Carbon registration applies
only the difference, and Lens command maps cache by context and engine revision.
`ModePassTwoTest` adds twenty regressions, each observed failing without its fix.
The deliberate bound-Escape mismatch and zero-count behaviors remain covered.

The library exports all requested contracts, constructors, modes and key sets.
Main has 41 chords and window 45. Cmd-Tab remains opt-in. Popup classes are a
Boolean record; migration errors name the replacement properties. Conversion
retains shipped modes/keymaps while replacing main/window with converted sugar.
`CONTEXT.md`, the Lens/default-config/event/trace guides, generated help and the
compiled agent skill describe the new model. The dotfiles handoff records the
manual opener migration; installed checks remain unchecked in the hardware brief.
The same brief records `brew upgrade --cask --greedy winmux` for the new CLI;
Sparkle updates the app alone.

### Departures settled by the builder rulings

The Decisions and Defaults above retain their original wording. The settled
builder rulings refine the example block: `W.when` defaults to priority 1 and
shipped blocks explicitly use 0; `W.transient` emits mode `binding` sugar.
Option-slash and Option-Shift-O enter `search-hold` and `overview-hold`.
Window letters use pairs, with recent/app-windows kept as text lists. `m` stays
fullscreen and no mark sequence ships. The HUD names the mode and pending
chords; a which-key legend belongs to **The HUD can show the current mode's keys**.
The `lens run` verb preserves the shipped Cmd-digit workspace actions. Space
peek, Option-Enter Summon and Cmd-digits remain in the appropriate shipped modes.
No Default chosen for you changed.

Decided: Counts saturate at 9999; zero runs zero copies of the command list.

Decided: An explicit keymap block cannot reuse `mode-<name>` while that mode has
nonempty binding sugar; checking reports the collision instead of replacing it.

Decided: A replaced mode's remaining `on-enter` commands are discarded. Ordinary
binding and release lists retain their command-list semantics. Reload preserves
held entry modifiers without rerunning entry commands and reconciles registration.

Decided: The Lens action legend keeps its existing action groups and custom
actions; mode transitions, navigation, caret, presentation, marking and Lens-close
controls are omitted. Its action chords still come from resolved mode bindings.

### Behavioral test seams

| Table rules | Tests |
| --- | --- |
| Return discount, extra Shift, opening key and reverse stepping | `ModeResolverTest.testHeldMatchingDiscountsEntryModifiersAndForeignModifiersLeave`, `ModeIntegrationTest.testHeldReturnDiscountsFullEntryChordAndPeekPrefersDiscountedBinding`, `StripSessionTest.testInitialSelectionForwardReverseWrapAndOnlyInvokingKeyCycles` |
| Staying list Tab and release selection | `LensHoldTest.testStayingHeldListTabStepsMatchesAndReleaseKeepsSelection` |
| Arrows, Escape, plain-key latch and consumed nonletters | `ModeResolverTest.testLatchOnlyReinterpretsLettersAndConsumesOtherUnboundKeys`, `testUnboundEscapeCancelsLatchedAndTransientAndMainPassesIt`, `StripSessionTest.testSingleRowArrowsCycleAndWrappedVerticalArrowsStayAtEdges` |
| Slash conversion, retained selection, recall and queued editor input | `LensHoldTest.testExplicitSearchAppliesInBrowseAndPresentationChangeKeepsSelectionMarksAndSearch`, `testStripSlashSelectsRecalledSearchForReplacement`, `testPanelKeepsBothLettersAndBackspaceAcrossConversionAtBothEntryPoints`, `testPanelStripKeepsDormantRememberedSearchUntilSlash` |
| Foreign chord and immediate global dispatch during opening | `ModeIntegrationTest.testForeignChordInterruptsOpeningAndDropsRemainingEntryCommands`, `testObservedForeignChordLeavesHeldModeBeforePanelCanTakeKeys` |
| Discounted peek, queued peek/Escape and composition | `ModeIntegrationTest.testHeldReturnDiscountsFullEntryChordAndPeekPrefersDiscountedBinding`, `LensPeekTest.testOpeningHoldQueuesAndReplaysPeekThenEscapeWithoutDismissing`, `testEscapeQueuedAfterPeekDoesNotCancelOpeningHold`, `testEveryKeyGoesToTheInputMethodWhileComposing` |
| Release, key-latch cancellation, opening order and draw deadline | `LensReleaseTest`'s eight injected-engine/clock tests, `ModeIntegrationTest.testOpeningLatchBeforeReleaseCancelsCommitButReleaseBeforeLatchCommits`, `testQuickReleaseCanFinishFocusAfterClosingWithoutCancellingItself`, `testReadinessActionsAndLaterInputKeepArrivalOrderAcrossAnAwait` |
| No stack, toggle and ad-hoc identity | `LensLifecycleTest.testSameLensTogglesAndAnotherReplacesRememberingSearch`, `testAdHocIdentityTogglesOnlyWhenFilterAndResolvedSettingsMatch`, `LensHoldTest.testNoStackModeReplacementAndCLIClosingEndsMain` |
| Browse navigation, list sideways keys, Search editing and Escape twice | `LensHoldTest.testNormalGridNavigationAndListSidewaysOverrides`, `testBrowseConsumesPlainLettersAndSearchEscapeKeepsTextAndMatches`, `ModeIntegrationTest.testTypingUsesSearchSelectionAndCaretRatherThanAppending`, `LensPeekTest.testSearchSpaceAlwaysTypesAndBrowseSpaceKeepsItsPeek` |
| Search caret, marks and selection command targeting | `ModeIntegrationTest.testLensVerbsUseSelectionAndMarksInMarkOrderAndClosingReportsMain` |
| Search-row click, panel/editor focus and no input state | `LensHoldTest.testSearchClickNamesSearchAndBindingsHaveNoLensSpecificInputState`, `testSelectionAndModifiersDoNotStealKeyboardOutsideModeChanges`, `ModeIntegrationTest.testOpenPairGivesTheDrawnInertLensKeyFocusWhenItsModeEnters` |
| Pre-key-panel limit, inert opener and mode-named starts | `LensHoldTest.testInertLensDoesNotChangeMainAndItsPlainKeysPass`, `ModeIntegrationTest.testObservedUnboundKeyCancelsTransientSequenceAndCountOutsideLens`, `DefaultConfigTest.testSixLensesTriggersAndLeaderEscape` |
| Hints and Summon modifier discount | `LensHintsTest.testEnterAndClicksUseModeModifiersInEveryPresentation`, `testLegendReadsCurrentModeBindingsForEveryLens`, `testWorkspaceChipRequiresExactCommandAndSummonChordPrefersHintsKey` |
| Rebindable mode keys, selection/mark actions and standalone peek | `ModeResolverTest.testSearchBoundKeysWinAndUnboundClipboardAndLettersType`, `ModeIntegrationTest.testLensVerbsUseSelectionAndMarksInMarkOrderAndClosingReportsMain`, `LensPeekTest.testConfigAcceptsPeekAloneAndNamesMixedListError` |

Context/operator/specificity/priority/conflict/prefix tests are in
`ModeResolverTest`; actual registration, pending HUD, one-shot, counts, closing,
CLI failure, trace and reload paths are in `ModeIntegrationTest`. Helper tests
exercise library override priority, register expansion, sugar `'pass`, migrations
and conversion. Existing view geometry, thumbnail, pointer, window restoration,
URL gate and ordinary binding assertions remain covered through the new APIs.

### Guest checks

One proof script runs against the base and the new build on the standing desk.
It verifies Cmd-Tab stepping, reverse opening/repetition, Cmd-W closing the
selected window, release focus, Option-slash with Tab while held, a typed letter,
Escape to browse with text kept then Main, and overview hjkl. Selection, Search
and active/dismissed readbacks match the base. The new mode CLI reports the held
mode, `search`, `browse` and then `main`; the HUD shows browse/search below the Lens.
A defaults-only configuration also leaves Cmd-Tab with macOS: the system app
switcher appears and WinMux stays in `main` before and after release.
Additional asserted runs cover all six window letters, Cmd-backtick, quick tap,
foreign modifiers, CLI held entry, `window-once`, `g t` pending/cancellation and
completion, `2l`, and contextual terminal `'pass`. Screenshots accompany mode,
focus, trace and agent-tree readbacks. Workspace moves were checked on screen as
well as in the tree and inventory. Proof sources are in `proofs/modes/`.
Every Lens verb was exercised: inert opening passes typed text to the terminal;
steps, grouping, presentation, caret and peek change the open view; Cmd-digit
targets its selection; Summon and focus close into Main; marks feed `lens run`
in mark order; marked and selected closes remove their windows. Pane reports its
explicit unsupported error. The existing six action groups stay in the hint
legend; navigation/editor controls are omitted from it.

The follow-up repeats the base/head, advanced and verbs runs. All 22 interaction
phases plus the initial desk agree between base and head by selection, Search,
open status and Presentation. Extra checks show held Cmd-Tab/Escape returning
typing to Ghostty, Cmd-Tab from latched browse reopening WinMux's strip without
the native switcher, and the app-specific pass block reaching Ghostty. The
ad-hoc CLI checks change Search, toggle identical Search, recall it, and clear
the recall explicitly. Offline checking names both invalid latch targets.
With no Lens open, fast `g t` completes its global sequence and keypad Enter
fires the Return binding. Both read back `main` after their bound mode command.

Host and pinned-version guest `make check` pass: 1,774 Swift tests, 94 Rust/helper
tests and 171 script tests, with the guest's existing committed-hash skip. The
guest is a debug build; CI's swift.org toolchain remains the merge gate.
Installed-build use, a second
display and real sleep/wake/unlock are not checked here. The installed check line
requested above is present and remains unchecked in the hardware brief.

## Sources

- The grilling record, 2026-10-19: [what WinMux becomes](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/issues/36-grilling-what-winmux-becomes.md), "Modality".
- Prateek, 2026-10-19: "i should be able to be in a mode while holding a key, that's all cmd-tab is, if i then need to switch to a different mode where i don't need to be holding command any more, i should express that - it doesn't need to be coupled to every lens".
- `docs/lenses.md`, "The Hold", for the rules the table places.
