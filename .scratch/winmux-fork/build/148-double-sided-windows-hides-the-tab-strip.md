# Double-sided windows hides the tab strip of a two-window group with no clue

Part of {{UMBRELLA}}.

## What to build

With the menu's double-sided windows toggle on, a tab group of exactly two windows shows no tab strip: `showsWindowTabs` is false when `usesDoubleSidedWindows`. The toggle is a UserDefaults key, `doubleSidedWindows`, not config, so a person who flipped it sees "tabs missing" and finds nothing in their config or in `config status` to explain it. After turning it off, the strip came back only once the workspace was laid out again.

## Decisions

- **The toggle moves into config** as `window-tabs.double-sided`, with the menu item reading and writing the config value as the sidebar's own writes do; the UserDefaults key is read once for migration and then ignored.
- **Turning it off redraws the strip at once**, without waiting for a layout.
- **`config status` and `doctor` report it**, so a missing strip has one place to look.

## Depends on

Nothing.

## Done when

- [ ] A test toggles the setting on a two-window group and asserts the strip's presence both ways, immediately.
- [ ] In a guest, flipping the menu item shows and hides the strip at once, and `config status` names the value.
- [ ] `docs/` describes the setting where window tabs are described.

## Sources

- #268's handoff, "Double-sided windows hides the tab strip".
