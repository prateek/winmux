# Grilling: cmd-K search Lens

Type: grilling
Status: open
Blocked by: 07

## Question

What is the cmd-K search, in the Lens model, and how does it grow out of the existing `winmux palette`? `SwitcherPalette` (`Sources/AppBundle/ui/hud/SwitcherPalette.swift`) already lists every bound window, focused workspace first, fuzzy-matches the query against app name, title and workspace, and focuses the pick. Decide:

- Whether it's a third Presentation (a searchable list) or a mode of the grid and strip where typing filters in place, and whether `CONTEXT.md` gains a term for it.
- What the search matches: app name, title, workspace, project, and tabs if the tab research makes them readable. How it ranks (AltTab's tiered exact / prefix / word-prefix / substring / acronym / fuzzy scoring is the reference; GPL-3, design only), and how that relates to the Lens's Filter and sort.
- Actions: focus by default, Summon on a modifier (standing decision), and whether several windows can be selected and Summoned at once ("window(s)").
- Whether the query can be a Nickel Filter expression (for example a prefix that switches from fuzzy text to a Filter), or stays plain text.
- The CLI side: opening it with a preset query or Filter, and a non-interactive `search` that prints matches for scripts.
