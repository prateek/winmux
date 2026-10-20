# Grilling: what WinMux becomes, and what stays outside it

Type: grilling
Status: resolved

## Question

A day of adopting dogfood.66 on a laptop ([Adoption tracker from a day of daily use](https://github.com/prateek/winmux/issues/268)) left three helper scripts in the dotfiles, each covering a feature WinMux lacks, and a list of thirty items across the switcher, the overview, windows, status, defaults and gestures. Before more of them land: what is WinMux, what is the launcher's, what is the dotfiles', and what is the grammar a user composes with?

## Answer

Resolved 2026-10-19 with Prateek, in six rounds.

### The boundary

- **WinMux is a window manager with an integration surface**: layout, focus and finding windows, plus the CLI, the socket, events and the URL scheme that other tools compose. Not the whole desktop layer.
- **A helper becomes a WinMux feature when any of these holds**: it needs state the surface cannot expose, or can only expose by polling; it fights WinMux when both act, as BetterTouchTool's move and resize do on tiled windows; or it must be continuous and instant, as a finger-tracked animation must. Otherwise it stays a script over the CLI, and the gap it exposes becomes a CLI or events issue. Applied to the three helpers: display switching is native (**Display profiles: match a profile to the attached display**), the rows toggle is a CLI command plus a script, the gesture bridge is native. The test goes into `AGENTS.md`'s **Scope and compatibility**.
- **Tuna stays the launcher.** WinMux ships no leader and no command bar. Fuzzy-finding windows is a Lens with Search; saving and restoring layouts, if it is built, is commands that Tuna and the CLI call.
- **Status displays consume WinMux; they are not WinMux surfaces.** `subscribe` sends the state on connect and covers mode, workspace, project and the open Lens. The menu bar item is the one native piece: mode, workspace and project at a glance, and a pause state that reads. Notch indicators and SketchyBar are dotfiles.
- **Gestures go native**, through the mode model below. The BetterTouchTool bridge stays until they land.
- **The fork tracks upstream for a while longer** and changes whatever it wants meanwhile. Prateek: "lets track upstream for a bit longer. we can make whatever changes we want tho".
- **The relay keeps taking #55's defects** while this lands. The large features wait for the adoption umbrella.

### Modality

- **Modes are the only modal concept.** A mode is a named record of chords to command lists, with a lifetime. A Lens is a view, Filter plus Presentation plus sort, opened and closed by commands; while open it has a selection and nothing else. Keys never belong to a Lens. Prateek: "it feels like we're coupling application state (held v normal v search) with modality as a concept. i should be able to be in a mode while holding a key, that's all cmd-tab is, if i then need to switch to a different mode where i don't need to be holding command any more, i should express that".
- **A mode has four properties**: a lifetime, `'latched` until a command changes the mode or `'held` while the modifiers of the chord that entered it stay down; a policy for unbound keys, `'pass` to the app, `'consume`, or `'type` into the open Lens's Search; `on-enter` commands; and `on-release` commands for a held mode; a held mode that commits also has a `draw-delay`. A held mode's keys match as pressed first, then with the entry modifiers removed, so its record says `tab`, not `cmd-tab`.
- **Lens verbs** work from any mode's keys while a Lens is open: `lens step next`, `lens step prev`, `lens focus`, `lens summon`, `lens peek`, `lens close`. Entering Search is `mode search`, not a verb; `lens search` means opening the Lens named `search`.
- **`lens <name>` alone changes no mode.** Every opener in the shipped defaults is a pair, `lens recent` and `mode cmd-tab`. There is no convenience that lets a Lens name a default mode.
- **A gesture enters a mode too.** `'held` for a gesture means while the fingers are on the pad; `on-release` runs when they lift. The swipe-driven overview is a held mode whose Presentation follows the finger.
- **No stack.** Entering a mode or a Lens leaves whatever was active. Closing a Lens returns to `main`, not to the mode that opened it.
- **The glossary changes**: Mode enters with its lifetime; Lens becomes a view; Trigger and Hold leave; the Lens session's held, normal and Search states leave with them.
- **Which-key**: the HUD can draw the current mode's keys as a legend after a short delay, with the Lens legend renderer. Off by default, `hud = 'name`; `hud = 'legend` turns it on. Prateek: "maybe we have disabled by default and enable on".

### The keyboard

- **The shipped `main` is minimal**: Ctrl-1 to 9 for workspaces, Ctrl-semicolon into `window`, and the opt-in Cmd-Tab. Every Option chord types a character or shadows a terminal Meta key, so none ships. Single-stroke direction chords on a silent modifier pair are a documented recipe, not a default.
- **`window` mode is the product's keyboard.** It keeps its 45 keys and gains Columns on Ctrl-1 to 9 to focus and Ctrl-Shift-1 to 9 to move, comma and period for the width preset, minus and equals for the count; no Column sub-mode. Marks go on `m` plus a letter and quote plus a letter, with fullscreen moving to Shift-m, and a key for `focus-back`.
- **Marks are commands**: `focus-back`, `mark <register>`, `jump <register>`.
- **A batteries-included layout ships as an importable module**, `winmux/examples/keyboard.ncl`, never imported by defaults, built from shared key records in `winmux/keys.ncl`. Prateek: "We should also have a more 'batteries included' or suggested example configuration that people can take inspiration from, but it shouldn't be the one enabled by default."

### Presentations

- **Three kinds, two panes, one link.** A Presentation is a primitive, the four today plus new ones such as a one-row miniatures strip of workspaces, or an arrangement, a stack or row of panes, each pane a primitive with its own scope, where one pane's selection may scope another. One focused pane, moved with a Lens verb. Built first as a two-pane stack for the Mission Control overview. The sidebar stays out until a second consumer appears.
- **The overview is a new Presentation, prototype first**, then Prateek's pick, then the build, the way the sidebar tree and the tab strip went. It gets a name of its own; `CONTEXT.md` keeps "overview" and "exposé" on the avoid list.

### Features

- **The switcher is config plus one command.** Cmd-Tab's Lens shows the current workspace's windows; the wider scopes are shipped Lenses with Filters; the home-row modal switcher is a list Lens opened from Tuna; the new code is a command that hands a chord to the system switcher. The strip's buttons and the Ctrl-F search polish are Lens look children.
- **Fullscreen is a round trip on the same Space**: regular size, whole-screen view, the original size; WinMux's own fullscreen class, never a native Space; the menu bar hidden if the API allows.
- **Modifier move and resize cover tiled windows from the start**: Ctrl-drag moves the window under the pointer, Ctrl-Cmd-drag resizes it; floating windows freely, tiled windows as a node move with the drag overlay and as a Column width or split ratio.
- **Floating windows are a Lens** with a floating Filter and a scope.
- **Layouts and rules are a research child first**; its outcome decides whether layout commands get built.
- **Crash reporting merges into #106**, following AltTab, Rectangle and Ice: a "report a bug" entry that gathers diagnostics and opens a prefilled GitHub issue, collection off until the user opts in, dSYMs published with every release as a public release asset. #263 keeps the crash and a relaunch after a crash.
- **The integration gaps are defects**: workspaces from the CLI, `place --dry-run` for a named workspace, a root split orientation command, `subscribe`'s initial state, `config check` evaluating hooks.
- **Status is two small children**, the menu bar item with its pause state and the sidebar accents, plus a logging step for the pointer jump.

### Process

- **The tracker moves to beads.** Every open issue imports; GitHub issues stay for outsiders. The relay skill is revised first. A phone view is a bead of its own. **Deferred on 2026-10-19**: Prateek chose to stay on GitHub for now, file the adoption umbrella and its children there, and close the five issues the decisions supersede, #144, #145, #213, #227 and #228. Prateek: "maybe we close old issues and file new issues instead of beads for now?" The two beads drafts are kept under the umbrella's Later section.
- **One umbrella**, with the mode rewrite as its first large child and the independent children free for the relay's next-child rule.
- **The outcome lives in three places**: the test in `AGENTS.md`, the vocabulary in `CONTEXT.md`, the decisions in the umbrella's body. No new document.

## Sources

- #268 and its handoff file, 2026-10-19.
- The vocabulary review by a fresh agent, 2026-10-19, which found that a mode has no entry chord or exit rules of its own and that Lens keys and mode bindings are one Nickel shape, `{ _ | Commands }`.
- `docs/lenses.md`, "The Hold", for the rules the mode model replaces.
