# Prototype: the overview as a stack of panes

Part of {{UMBRELLA}}.

## What to build

The shipped `overview` is `'miniatures`: every workspace as a small copy of itself. Prateek wants the thing Mission Control does: the current workspace's windows spread out and animated in the centre, a Spaces-style row of the project's workspaces above, drops between them, the menu bar hidden while it is open. No existing Presentation gives both halves: `'grid` spreads one workspace's windows, `'miniatures` draws the row.

Build a throwaway prototype of a Presentation made of two panes, and bring him a choice of looks. The prototype also fixes the grammar the build will follow.

## Decisions

- **Three kinds, two panes, one link.** A Presentation is a **primitive**, the four today plus new ones, or an **arrangement**, a stack or a row of **panes**, each pane a primitive with its own scope. One pane's selection may scope another: the link. A Lens session has one focused pane, moved with `lens pane next`. This goes into `CONTEXT.md` with the pick.
- **The first arrangement is a two-pane stack**: a one-row miniatures strip of the project's workspaces above, a grid of the selected workspace's windows below, linked. Selecting a workspace above changes the grid below; the grid opens on the current workspace.
- **A drop between panes moves the window**: a window dragged from the grid onto a workspace miniature moves it there, as a sidebar drop does, through the same placement.
- **The menu bar is hidden while it is open**, if the API allows a non-fullscreen app to hide it; the prototype shows both and the pick decides.
- **The sidebar stays out.** It is a persistent window with a hover lifecycle, not a Lens; a tree pane waits for a second consumer.
- **It gets a name of its own at the pick.** `CONTEXT.md` keeps "overview", "exposé" and "Mission Control" on the avoid list.
- **The prototype is a clickable page** on the captured rich desk, as the sidebar tree and the tab strip prototypes were, with two or three variants side by side; the swipe-driven transition is animated in the page from a slider so the pick can judge it.
- **A prototype answers questions; it does not ship.**

## Questions to answer

- How large is the row, and does it show window pictures inside each miniature or only the workspace's shape?
- Does the grid below show the selected workspace only, or the selected workspace large and the others' windows small at the sides, as Mission Control's "a home for other projects' windows" suggests?
- Which pane has focus on opening, and what does Escape do in each?
- Does a drop onto the row's miniature place by `place`, or into the pointed position inside the miniature?

## Depends on

Nothing.

## Done when

- [ ] A clickable page under `.scratch/winmux-fork/prototypes/` on the rich desk's layout, with two or three variants, each showing the row, the grid, a drop and the swipe transition from a slider.
- [ ] Captures of native Mission Control on the same desk beside it, reusing the Lens look prototype's where they fit.
- [ ] A recommendation and a draft issue for the recommended variant, written so that **Build the overview Presentation from the pick** can be rewritten from whichever he picks.
- [ ] A line under **Open with Prateek: questions and checks that wait on him** asking for the pick, with the page's link. The pick itself is not this issue's to tick.

## Sources

- The grilling record, 2026-10-19, "Presentations": "three kinds, two panes, one link".
- #268, "Exposé and gestures".
- `docs/lenses.md`, "Grid" and "Overview and miniatures".
