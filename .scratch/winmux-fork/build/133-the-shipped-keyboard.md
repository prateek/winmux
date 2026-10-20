# The shipped keyboard: a minimal main and a full window mode

Part of {{UMBRELLA}}.

## What to build

Of the 40 shipped `main` chords, 31 use Option and nine are the Ctrl-digits. On a US layout they type characters, `…`, `Ø`, `¡`, when WinMux is not listening; in a terminal they shadow Meta-h, Meta-l, Meta-digit, Meta-slash and Meta-semicolon; and Option-Shift-o is Organize Imports in Cursor and VS Code. Prateek's own config removed every one of them and kept Ctrl-digits and the `window` mode. The `window` mode has 45 keys and no Column operations.

Ship a `main` that nobody has to remove, make `window` the product's keyboard, and put the full layout beside the defaults as a module a user imports with one line.

## Decisions

- **`main` keeps three kinds of chord**: Ctrl-1 to 9 for `workspace 1` to `9`, Ctrl-semicolon for `mode window`, and the opt-in Cmd-Tab and Cmd-backtick lines a user merges. Option-semicolon no longer enters `window`; it typed an ellipsis. Gesture bindings are not chords: the workspace swipes **Trackpad gestures as held modes** adds to `main` sit beside these.
- **Tab focus by digit leaves the shipped defaults.** Option-1 to 9 ran `focus --tab-index`; no shipped mode binds it afterwards, since `window`'s bare digits are workspaces and its Ctrl-digits are Columns. The example module binds it on Ctrl-Option-1 to 9 in `main`, and the tab hints follow that binding there; with the minimal defaults there is no tab-digit binding and so no tab-digit hint, and `n` and `p` in `window` step tabs.
- **`window` keeps its 45 keys and gains Columns and marks.** Ctrl-1 to 9 run `focus-column 1` to `9`; Ctrl-Shift-1 to 9 run `move-node-to-column 1` to `9`; comma and period run `column-width prev` and `column-width next`; minus and equals step `column-count` down and up. `m` and quote are the first chords of sequences, written in the keymap as `"m <r>" = "mark <r>"` and `"quote <r>" = "jump <r>"`, so `m` then `a` sets mark `a` and quote then `a` jumps to it, as **focus-back, mark and jump** defines the commands; fullscreen moves from `m` to Shift-m; backtick runs `focus-back`. The `floating` Lens opener moves from `f` to `x`, so `f` is free for **Hint mode: type a label to reach a window**, which binds it. No Column sub-mode.
- **The shipped Lens set grows, mostly by configuration.** `recent`, the Cmd-Tab Lens, filters to the current workspace. `recent-all` keeps every window. `app-windows`, `floating`, `windows`, `search` and `overview` stay. `floating` takes a scope, workspace, project or everything, through three shipped Lenses, `floating`, `floating-project` and `floating-all`. Three scoped switchers ship: `mouse-app`, the app under the pointer; `project-windows`, every window in the current project; `column-windows`, the windows in the focused Column. The first two are Filters over existing Filter context fields.
- **The Filter context gains Column membership**, which `column-windows` needs and nothing exposes today: the window record gains `column`, its Column's one-based index or null when it is floating or its workspace has Columns off, and the context gains `focused-column`. `winmux agent query` reports the same field. This is the one code change in the Lens set.
- **Shared key records are the library's `W.keys`**: `navigate`, `workspaces`, `columns` and `lenses`, plain records of the `{ _ | Commands }` shape exposed by `winmux.ncl`, as **Modes are the only modality** defines the library. `defaults.ncl`'s `window` block is `W.when "mode == window"` over their merge plus the mark sequences, so the composition is visible, and a user's own block in `keymap` is a `&` away. `W.keys.main-today` goes away with this issue, since `main` keeps only the chords below.
- **The full layout ships as `winmux/examples/keyboard.ncl`**, imported with one line over defaults and never imported by defaults. It carries Prateek's left-hand, home-row arrangement generalized: direction chords on a silent modifier pair, Ctrl-Option, in `main`; the same `window` mode; Ctrl-f for `search`; Lens openers on the home row; and one mode with `count = true`, so `3l` has a shipped example. `docs/default-config.md` shows it as the second example after the minimal default, with one sentence on what it assumes.
- **A recipe, not a default, for single-stroke directions in `main`**: the docs show Ctrl-Option-h/j/k/l as the way to get them back.
- **Per-app exceptions are keymap blocks**: the docs show `W.when "app == 'com.googlecode.iterm2'" { ctrl-semicolon = 'pass }` as the way to keep a chord an app's own, beside the Cmd-Tab opt-in.

## Not in this issue

- The mode rewrite the pairs depend on: **Modes are the only modality**.
- The `focus-back`, `mark` and `jump` commands: **focus-back, mark and jump**.

## Depends on

- **Modes are the only modality**.
- **focus-back, mark and jump**.

## Defaults chosen for you

- **`column-count` stepping**: minus and equals step the count for the current workspace by one, floored at one and capped at the configured maximum; `config check` reports a count the display cannot fit.
- **The example module's `main` chords may be visible to a terminal**, Ctrl-f and the Ctrl-Option directions among them; the docs list which ones, and the person importing it chooses.
- **`winmux config convert`** writes the new `main` and `window` records, and names each removed Option chord in its output so a user can put it back.

## Done when

- [ ] `defaults.ncl`'s `main` has exactly the Ctrl-digits and Ctrl-semicolon as chords, plus any gesture bindings the gestures issue has added, and the docs show the opt-in lines in mode form; `docs/default-config.md`'s table matches it, and the `window` table lists the Column and mark keys.
- [ ] `W.keys` has the four sets and no `main-today`, `winmux/examples/keyboard.ncl` exists, `(import "winmux/examples/keyboard.ncl") | W.Config` passes `config check`, and the docs show both.
- [ ] A test loads the defaults and asserts that no chord bound in `main` produces a printable character under `UCKeyTranslate` on the US and ABC layouts, control characters not counting; `window` mode's bare letters are exempt by design, and the example module is checked only for the list of terminal-visible chords its docs name.
- [ ] A test of `column-windows` on a workspace with three Columns shows only the focused Column's windows, and `agent query` reports each window's `column`.
- [ ] In a guest: Ctrl-semicolon, then Ctrl-2 focuses Column 2, Ctrl-Shift-3 moves the window to Column 3, comma and period change its width preset, minus and equals change the count, `m` then `a` and quote then `a` set and reach a mark, and the HUD names `window` throughout and shows the pending `m` while it waits.
- [ ] Cmd-Tab shows only the current workspace's windows; `winmux lens recent-all` shows every window.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: his dotfiles config imports the example module instead of carrying the layout, and nothing he uses daily is lost.

## Sources

- The grilling record, 2026-10-19, "The keyboard".
- #268's handoff, "WinMux's shipped Option chords break special characters".
- `docs/default-config.md`, "The 40 default shortcuts" and "The windowing mode".
