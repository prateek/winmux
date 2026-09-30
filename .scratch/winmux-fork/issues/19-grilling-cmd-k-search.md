# Grilling: cmd-K search Lens

Type: grilling
Status: resolved
Blocked by: 07

## Question

What is the cmd-K search, in the Lens model, and how does it grow out of the existing `winmux palette`? `SwitcherPalette` (`Sources/AppBundle/ui/hud/SwitcherPalette.swift`) already lists every bound window, focused workspace first, fuzzy-matches the query against app name, title and workspace, and focuses the pick. Decide:

- Whether it's a third Presentation (a searchable list) or a mode of the grid and strip where typing filters in place, and whether `CONTEXT.md` gains a term for it.
- What the search matches: app name, title, workspace, project, and tabs if the tab research makes them readable. How it ranks (AltTab's tiered exact / prefix / word-prefix / substring / acronym / fuzzy scoring is the reference; GPL-3, design only), and how that relates to the Lens's Filter and sort.
- Actions: focus by default, Summon on a modifier (standing decision), and whether several windows can be selected and Summoned at once ("window(s)").
- Whether the query can be a Nickel Filter expression (for example a prefix that switches from fuzzy text to a Filter), or stays plain text.
- The CLI side: opening it with a preset query or Filter, and a non-interactive `search` that prints matches for scripts.

## Answer

Grilled with Prateek on 2026-09-30. "cmd-K search" names the idea, not the key.

- **Search is a Lens-wide capability, plus a fourth Presentation, `'list`.** `CONTEXT.md` gains **Search** (the text typed into an open Lens: it narrows the Lens's matches and ranks them; the Filter decides what's eligible, the Search picks among them) and the **list** Presentation (a Search box above ranked rows). `'list` grows out of upstream's `SwitcherPalette`, which Zimeng added on 2026-06-12 (`edc1bc63`), and v1 builds it alongside `'miniatures` and `'strip`.
- **Search per Presentation.**
  - `'list`: the box is always shown, and non-matches are hidden.
  - `'miniatures`: a box appears when you start typing. Non-matching windows dim in place, because positions are fixed. The selection jumps to the best match, and arrow keys move among matches only.
  - `'strip`: no Search box, because letters held with cmd are chords. The strip hands off instead (below).
- **What Search matches:** app name, window title, workspace name, project name, and tab titles and URLs when the `w.tabs` cache has them. It doesn't match the bundle id or the document path. A window matched through a tab shows that tab's title in its row. Whether tabs become their own entries stays in the tab fog.
- **Ranking:** the Search splits into words, and every word must match some field, in any order. Each word gets a tier: exact > prefix > word-prefix > substring > acronym (`vsc` → Visual Studio Code) > fuzzy subsequence. Title and app matches outrank workspace and project matches. An empty Search shows the Lens's `sort` order unchanged; a non-empty one ranks by score, with the Lens's `sort` (MRU by default) breaking ties. AltTab's tiers are design reference only (GPL-3).
- **Inline Nickel in the box.** A leading `=` switches the whole box to Nickel: the rest is a function body with `w` and `ctx` bound, such as `= w.class == 'floating && w.app.name == "Ghostty"`. Text and Nickel don't mix. Named Filters are callable inside it (`= filters.floating w ctx`), so there are no `@name` tokens. It's evaluated 150 ms after typing stops. While the text doesn't parse, the last good result stays up, the first line of Nickel's error shows under the box, and the border turns amber; an error never closes or empties the Lens. Each evaluation gets a 50 ms budget over the whole window set; past it, the box says "Filter too slow" and keeps the last result. The real per-call cost is [Task: Nickel binding spike](28-task-nickel-binding-spike.md)'s to measure. The body-with-`w`-and-`ctx` shape should match whatever [Grilling: CLI surface for the fork's features](20-grilling-cli-surface.md) picks for `--filter`.
- **Several windows.** In any Presentation with a Search box (not the strip), `tab` toggles a mark on the selected window. When anything is marked, a key's command runs once per marked window, in the order they were marked; otherwise it runs on the selection. `focus` always acts on the selection alone. Summoning several runs `place` for each in turn.
- **Strip-to-list handoff** (AltTab's `searchOnRelease`). A new command, `lens --presentation list`, reopens the open Lens as a list, carrying over its Filter, `sort`, selection, marks and Search. The strip's `keys` map gets one default binding for it; [Prototype: strip Presentation look and keyboard model](29-prototype-strip-presentation.md) picks the key. It also works from `'miniatures`.
- **Search text across opens:** remembered per Lens and shown preselected, so the first keystroke replaces it (the Spotlight and Raycast behaviour). `--search` overrides it.
- **Default Lens and Trigger.** A `search` Lens ships: every window, `'list`, sorted by `mru`, **unbound**. Global cmd-K would steal it from Slack, Chrome, VS Code and most Electron apps. The docs show two ways to trigger it: a key inside a mode (`mode.<mode>.binding`), and `winmux lens search` from an external launcher (Raycast, Karabiner, skhd, BetterTouchTool). Prateek drives AeroSpace today with global alt-chords plus leader-key bindings, so a default leader mode covering all the fork's features is worth deciding, but in the defaults work, not here (it's in the map's fog).
- **CLI.** `winmux lens <name> --search '<text>'` opens a Lens with the Search prefilled. The non-interactive side extends `list-windows` (which [Grilling: CLI surface for the fork's features](20-grilling-cli-surface.md) already plans to give `--filter`) with `--lens <name>`, to use that Lens's Filter and `sort`, and `--search '<text>'`, to apply Search ranking. JSON output adds `score` and the matched field. There's no separate `search` subcommand. `winmux palette` becomes an alias for `lens search` and is dropped later.
- **Left open (fog):** how `'list` rows look (icon, title, app, workspace or project chip, matched tab, mark badge, maybe a small thumbnail). Until it's specified, today's palette rows are the v1 default.
- **Not done:** Prateek asked for a picture of the existing palette. It wasn't possible on the 2026-09-30 Mac mini session: `open -a WinMux` (0.51.0-dogfood.15) exits silently, and a server started from the shell registered no windows, since the Accessibility grant doesn't carry over to a shell-launched process. No screenshot exists in `resources/`.
