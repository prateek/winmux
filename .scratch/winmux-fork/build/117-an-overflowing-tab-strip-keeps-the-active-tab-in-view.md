# An overflowing tab strip keeps the active tab in view

Part of {{UMBRELLA}}.

## What to build

A tab group with more tabs than fit puts the rest past the strip's right edge, in a scroll view. Focusing a tab that is out of view, with Option-9, `focus --tab-index`, `tab-next` or a click on the window, leaves the strip where it was: the window comes forward, and its tab stays hidden. At 1280 × 720 a group of twelve shows eight tabs and part of a ninth, so Option-9 lands on a tab nobody can see.

`WindowTabStripView`'s tab scroll view has no `ScrollViewReader` or `scrollPosition`, and nothing scrolls it when the active tab changes.

## Decisions

- **The active tab is always in view.** When focus moves to a tab outside the visible part of the strip, the strip scrolls until that tab is whole.

## Defaults chosen for you

- **How far**: the least scroll that shows the tab whole, as browsers do, not centring it.
- **Animation**: the strip's existing tab animation, and none under Reduce Motion.

## Depends on

Nothing.

## Done when

- [ ] In a group of twelve at 1280 × 720, Option-9 from the first tab shows the twelfth tab whole and active in the strip.
- [ ] Option-1 afterwards brings the first tab back into view.
- [ ] A test covers the scroll offset the strip asks for when the active tab is past either edge, and none when it is in view.

## Sources

- Found while building **The ninth tab digit goes to the last tab**, 2026-10-18: a twelve-tab group's Option-9 focused Tab12 while its tab stayed past the strip's edge.
