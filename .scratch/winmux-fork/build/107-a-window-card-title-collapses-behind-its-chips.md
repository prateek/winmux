# A window card's title collapses behind its chips

Part of {{UMBRELLA}}.

## What to build

A card's bar draws the icon, the title and the chips in one row. The chips keep their whole width, and the title takes what is left. **A strip with one entry per app draws badly** made a per-app card as wide as its bar needs. A window card (`entries = 'window`, the default) still gets only the card title floor, 110 to 200 points at a 1920 by 1080 scale, which knows nothing of the chips.

So a window card on another workspace that is also floating, minimized or hidden draws its title as "…": a card about 130 points wide, with `W3` and `floating` beside a short title such as "Inbox", has almost no room left for the title.

**Reproduce:** a grid or strip of window cards at fourteen windows on the rich desk, with Calculator (floating, on workspace 3) among them. Its card shows the chips and an ellipsis.

## Decisions

- A window card's title shows at least a readable part of itself beside its chips.

## Defaults chosen for you

- **Reserve the chips, not the title.** A window card is at least as wide as its icon, its chips and a short title allowance (about 80 points at scale 1), using the measurement the per-app card uses. A window title is often long, so reserving the whole title as a per-app card does would make every card wide. Say in the pull request how far this moves the strip's and the grid's wrapping at fourteen and twenty-five windows.

## Not in this issue

- Per-app cards, which reserve their whole bar.
- Picture and text Tiles, which have no chips beside a title.

## Depends on

**A strip with one entry per app draws badly**.

## Done when

- [ ] A test renders a window card with two chips at the width the strip gives fourteen windows and shows part of its title; it fails on the base.
- [ ] The pull request shows the fourteen-window card grid before and after.

## Sources

- The review of the pull request for **A strip with one entry per app draws badly**.
