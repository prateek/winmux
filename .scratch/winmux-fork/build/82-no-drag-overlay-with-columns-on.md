# Dragging a window shows no overlay when Columns are on

Part of {{UMBRELLA}}.

## What to build

Dragging a window shows an overlay of where it will land. With Columns on, Prateek dragged a window and saw no overlay at all. The drag zones and previews (`Sources/AppBundle/mouse/`) were written before fixed Columns, and a drop is now placed by the Column Policy.

## Decisions

- **Reproduce first**, in a guest with Columns on.
- **A drag shows where the window will land**: the Column, and what Overflow will do there, whether a tab group, a split or a squeeze.

## Not in this issue

- A change to what `place` decides.

## Depends on

Nothing.

## Defaults chosen for you

- **The overlay asks the Policy** what a drop at that point would do, as `place --dry-run` does, and draws the answer. It does not carry a second copy of the rules.
- **An empty Column shows its outline as the target.**

## Done when

- [ ] With three Columns, dragging a window over each Column shows an overlay, and the drop lands where the overlay showed.
- [ ] With Columns off, the overlays are as before.
- [ ] The pull request has a clip of a drag across three Columns.

## Sources

- Prateek, 2026-10-07: "the hover affordances (eg overlay that shows up on windows) when dragging a window need to be made column aware". Asked what he saw: "i saw nothing."
