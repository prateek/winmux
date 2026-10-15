# Storyboard: Hero demos in the README and the docs

Every take is filmed on the standing desk (`stage-desk.sh`) at 1280 × 720, with the debug build of `bfa97034`. MRU after staging is Zed, Ghostty, Safari, Notes; Zed is focused on workspace 1; Safari and Notes are on workspace 2. Counts below were read on that desk on 2026-10-15: `list-windows --search l` matches all four windows, `--search le` matches only Safari ("Lenses and Search", workspace 2).

The Lens takes use the desk's own `winmux.ncl`, which opts in to Cmd-Tab. The Columns takes use `desk/hero/columns.ncl` (three equal Columns on workspace 1, `alt-w` bound to `column-width next`) or `desk/hero/columns-place.ncl` (the same, plus a `place` hook that sends Ghostty windows to Column 3), copied over `~/.config/winmux/winmux.ncl` and reloaded. Reloading puts Zed and Ghostty into Columns; `move-node-to-column` arranges them before each take.

Every GIF goes to `docs/demos/<id>.gif`.

## Hero

### strip-hero (demo)
- **Claim:** Holding Cmd and tapping Tab steps through every window on every workspace; letting go focuses the one selected.
- **Setup:** standing desk, then `~/desk/strike 1`, so the Grievances note reads "Alt-tab is a slot machine" struck out. Zed focused on workspace 1.
- **Action:** hold cmd; tab; tab; tab; release cmd. About a second between taps.
- **Watch:** The strip opens on Ghostty, steps to Safari, then Notes. On release workspace 2 is on screen with Notes focused, the struck grievance in view. `list-windows --focused` is Notes; `list-workspaces --focused` is 2.
- **Crop:** whole screen.
- **Pages:** README (hero), `docs/lenses.md` (first).

## Lenses

Finding a window without leaving the keyboard.

### overview-enter (demo)
- **Claim:** Option-Shift-O shows every workspace at once; Enter focuses the window selected.
- **Setup:** standing desk, every workspace shown once since WinMux started, then back on workspace 1 with Zed focused and pictures drawn.
- **Action:** alt-shift-o; arrow keys to Safari on workspace 2; return.
- **Watch:** Both workspaces draw in the overview with their windows in place. On Enter the overview closes on workspace 2 with Safari focused.
- **Crop:** whole screen.

### search-two-letters (demo)
- **Claim:** Option-Slash opens Search: two letters narrow four windows to one, and Enter goes to it.
- **Setup:** standing desk, WinMux freshly started so Search starts empty. Zed focused on workspace 1.
- **Action:** alt-slash; l; e; return.
- **Watch:** `l` leaves all four windows listed; `le` leaves only Safari, "Lenses and Search". On Enter workspace 2 is on screen with Safari focused. `debug-lens-trace --last 1` shows Search `le`.
- **Crop:** the list and the windows behind it; whole screen if the list is small.

### summon-landing (demo)
- **Claim:** Holding Option in the strip shows where a window from another workspace will land; Option-Return brings it here.
- **Setup:** standing desk, Zed focused on workspace 1.
- **Action:** hold cmd; tab; tab; hold alt; return; release alt; release cmd.
- **Watch:** On Safari the label reads `⌥↩ Summon to 1` and an outline marks its landing spot on workspace 1. After Return, Safari is on workspace 1 at the outline’s origin, and workspace 1 stays on screen. Its 574-point native minimum extends beyond the narrower outline and the screen’s right edge; the take records that limitation rather than changing WinMux. `list-windows --workspace 1` lists Zed, Ghostty and Safari.
- **Crop:** whole screen.

## Columns

A workspace with a fixed number of places, which keep their width when empty.

### columns-land (demo)
- **Claim:** A new window lands in the nearest empty Column, and the others keep their places.
- **Setup:** `desk/hero/columns.ncl`. Workspace 1: Ghostty in Column 1, focused; Column 2 empty; Zed in Column 3.
- **Action:** cmd-n in Ghostty.
- **Watch:** The new terminal lands in Column 2. `list-columns` reads 1 Ghostty, 2 the new Ghostty, 3 Zed.
- **Crop:** whole screen.
- **Pages:** README (second), `docs/columns.md` (first).

### column-width (demo)
- **Claim:** `column-width next` steps the focused Column through its width presets; the other Columns give up the room in proportion.
- **Setup:** `desk/hero/columns.ncl`. Workspace 1: Ghostty alone in Column 1, focused; Column 2 empty; a second Ghostty in Column 3. Zed is on workspace 2: its measured 360-point minimum does not fit the final one-sixth Column, so this take uses the ruled terminal fallback.
- **Action:** alt-w; alt-w. About a second between.
- **Watch:** Column 1 goes from a third to a half to two thirds. `list-columns` ends with widths 2/3, 1/6, 1/6.
- **Crop:** whole screen.

### move-join (demo)
- **Claim:** Moving a window into an occupied Column joins it as a tab group, and the Column it left stays empty.
- **Setup:** `desk/hero/columns.ncl`. Workspace 1: Ghostty in Column 1, focused; Zed in Column 2; Column 3 empty.
- **Action:** alt-shift-l (`move right`).
- **Watch:** Ghostty joins Zed in Column 2 as a tab group; Column 1 is left as an empty gap at its width. `list-columns` reads 1 empty, 2 Zed and Ghostty, 3 empty.
- **Crop:** whole screen.

### place-hook (demo)
- **Claim:** A `place` hook decides where a window lands: this one sends every terminal to Column 3.
- **Setup:** `desk/hero/columns-place.ncl`. Workspace 1: Ghostty in Column 1, focused; Columns 2 and 3 empty, so built-in placement would choose Column 2. Zed is out of the way (joined to Column 1 as a tab, or on workspace 2).
- **Action:** cmd-n in Ghostty.
- **Watch:** The new terminal lands in Column 3, and Column 2 stays empty. `list-columns` shows the new window in Column 3.
- **Crop:** whole screen.

## Done-when table

| Done when | Shown by |
| --- | --- |
| The storyboard lists each demo with its claim, setup, action, what to watch and crop | this file |
| The README shows two demos under captions, playing on the front page | strip-hero, columns-land |
| `docs/lenses.md` shows four demos | strip-hero, overview-enter, search-two-letters, summon-landing |
| `docs/columns.md` shows four demos | columns-land, column-width, move-join, place-hook |
| Every demo passes the `demo` skill's check | every demo, step 5 |
| After each take, what WinMux reported matches **Watch** | each demo's read-back |
| Every GIF within 8 s and 3 MB, total under 12 MB | the eight files in `docs/demos/` |
| The docs' Nickel examples still pass `winmux-nickel check` | transcript of the check |

## Re-filming notes

The accepted takes use `.claude/skills/demo/desk/hero/film` and its full-screen snapshot recorder. At 4 cores / 6144 MB the stream recorder omitted the settled workspace redraw, while timed full-screen snapshots captured it. The raw movie and its sample clock remain beside the constant-frame-rate copy and actual key-event log; no still is substituted for a result.

Run `desk/hero/prepare.zsh` in the guest before staging. It gives every terminal the desk’s git history, suppresses the login banner and disables terminal close confirmation. The strip hero hides Notes’ folder sidebar after striking grievance 1. Restore the MRU order Notes, Safari, Ghostty, Zed after striking. For Search, restart **and restage** with `desk/hero/restart.zsh`: restarting alone can reverse the sidebar’s displayed numbers. Show both workspaces and wait for pictures before overview. `desk/hero/film` parks the pointer, refuses an active Lens and saves setup and end-state read-backs beside each take.

The Place take joins Zed and the original Ghostty as tabs in Column 1. Column 2 stays empty before and after Cmd-N; the new terminal goes to Column 3. `keys` labels Return as `Return`, because the card font has no arrow glyph. All demos use the whole screen; text, titles and key chips remain readable at the rendered size. `strip-hero` uses the allowed 1280-pixel card; the other seven use 960.
