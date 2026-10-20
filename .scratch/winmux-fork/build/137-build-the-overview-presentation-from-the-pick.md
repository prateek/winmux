# Build the overview Presentation from the pick

Part of {{UMBRELLA}}. **Blocked on Prateek** until he picks from **Prototype: the overview as a stack of panes**.

## What to build

The arrangement the prototype's pick names: a two-pane stack, a one-row miniatures strip of the project's workspaces linked to a grid of the selected workspace's windows, with drops between the panes, the menu bar hidden while open, and a transition the gesture can drive. The shipped `overview` Lens switches to it; `'miniatures` stays available by name.

This draft is rewritten from the pick before it is built; what stands now is what the grilling settled.

## Decisions

- **The Presentation is an arrangement**, as `CONTEXT.md` defines after the prototype: a stack of two panes with one link. Each pane is a primitive Presentation with its own Tile sizing; the arrangement owns only the panes' placement, the focused pane and the link.
- **Keys are a mode.** The Presentation reads no keys. The shipped `browse` mode gains `lens pane next`. A swipe enters the held `overview-swipe` mode of **Trackpad gestures as held modes**, whose release settles into `browse` or closes; a chord enters `overview-hold`. The transition is a Presentation property the gesture drives with a progress value from 0 to 1, reversible, as the grilling requires for native gestures.
- **The menu bar is hidden while it is open only if the pick says so**; the prototype shows both and **Prototype: the overview as a stack of panes** leaves it to feasibility and the pick.
- **The Lens session has one selection** in the focused pane; the link sets the other pane's scope from it.
- **`overview` switches to the new Presentation** in `defaults.ncl`; `winmux lens overview --presentation miniatures` still works.

## Not in this issue

- The gesture that opens it: **Trackpad gestures as held modes**.

## Depends on

- **Prototype: the overview as a stack of panes**, and Prateek's pick.
- **Modes are the only modality**.

## Done when

- [ ] Rewritten from the pick, then: the arrangement draws on the rich desk in a guest as the pick shows, with the row, the grid, the link, a drop between panes, and the menu bar as the pick decided.
- [ ] Tests cover the link, pane focus, `lens pane next`, and the transition's progress value.
- [ ] `CONTEXT.md` has the arrangement's name and the pane and link entries; `docs/lenses.md` has a section for it.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: the overview on the ultrawide and on the laptop panel, with his workspaces.

## Sources

- The grilling record, 2026-10-19, "Presentations".
