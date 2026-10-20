# Double-sided windows hides the tab strip of a two-window group with no clue

Part of {{UMBRELLA}}.

## What to build

With the menu's double-sided windows toggle on, a tab group of exactly two windows shows no tab strip: `showsWindowTabs` is false when `usesDoubleSidedWindows`. The toggle is a UserDefaults key, `doubleSidedWindows`, not config, so a person who flipped it sees "tabs missing" and finds nothing in their config or in `config status` to explain it. After turning it off, the strip came back only once the workspace was laid out again.

## Decisions

- **The toggle moves into config** as `window-tabs.double-sided`, and the menu item goes away: WinMux never writes a person's config, so a setting that lives there has one place to change it. The UserDefaults key is read once on the first launch after this lands, applied as the config's value if the config does not set one, and the log says it was migrated, as **Scope and compatibility** asks for state a release leaves behind.
- **Turning it off redraws the strip at once**, without waiting for a layout.
- **`config status` and `doctor` report it**, so a missing strip has one place to look.

## Depends on

Nothing.

## Done when

- [ ] A test toggles the setting on a two-window group and asserts the strip's presence both ways, immediately.
- [ ] In a guest, a reload that flips the setting shows and hides the strip at once, `config status` names the value, and the menu item is gone.
- [ ] `docs/` describes the setting where window tabs are described.

## Sources

- #268's handoff, "Double-sided windows hides the tab strip".
