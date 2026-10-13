# Long names and titles in a Tile

Part of {{UMBRELLA}}.

## What to build

Two defects seen with titles of 80 to 95 characters on the staged desk, in `0.5.6-dogfood.13`.

- **A text Tile never truncates a long app name.** The name pushes the title out and runs across the neighbouring Tiles.
- **A card cuts its title at the tail**, near 16 characters at fourteen windows and near nine at twenty-five. Windows that share a prefix, such as pull requests of one repository, lose the part that tells them apart.

## Decisions

- **Text in a Tile stays inside the Tile.** A long app name is truncated.

## Not in this issue

- A wider panel for long titles.
- A change to the footer, which already shows the whole title.

## Depends on

Nothing.

## Defaults chosen for you

- **A title is cut in the middle**, keeping its start and its end, as the system's switcher and DockDoor do. Say so in the pull request if a tail cut reads better at some width.
- **The app name gives way before the title** when both cannot fit.

## Done when

- [ ] A text Tile with a 92-character app name draws inside its own bounds, in a strip and in a list.
- [ ] Two cards whose titles differ only after the twentieth character can be told apart at fourteen windows.
- [ ] A layout or snapshot test covers both.

## Sources

- The switching comparison, 2026-10-07: long-title desks at three and fourteen windows.
- Prateek, 2026-10-07: "long titles" on his list from a day of use.
