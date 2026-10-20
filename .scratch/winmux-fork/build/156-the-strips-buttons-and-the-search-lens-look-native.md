# The strip's buttons and the search Lens look native

Part of {{UMBRELLA}}.

## What to build

Two Lens look items from a day of use. The strip's close, minimize and fullscreen buttons on a Tile do not look like macOS's traffic lights; they read as drawn by WinMux. And the search Lens as a list, Option-slash as shipped and Ctrl-F in Prateek's own config, has the pieces but not the finish: its rows carry an icon, a mark and a title, matched text is highlighted, and a legend of keys sits below the panel, yet beside Spotlight or Raycast the rows are too tall and too plain, the icons are small, the highlight is a weight change that is hard to see, the panel chrome does not match the sidebar's glass, the legend reads as debugging output rather than a hint footer, and the first frame lands late enough to notice.

## Decisions

- **The Tile's window controls draw as the system's do**: the three colours, the hover symbols, the disabled grey, at the system's size, in both appearances; the Lens look prototype's captures of native windows are the reference.
- **The list Presentation's rows** take their height, icon size, title and subtitle weights and the highlight of matched text from the native switchers captured in `prototypes/31-lens-look`, and the panel's chrome from the sidebar's `chrome-style`.
- **A keyboard-hint footer** below the list shows the mode's keys for the open Lens, which is the Lens legend as it exists; this issue sizes and places it as a footer.
- **Opening latency has a budget**: the list draws its first frame within 100 ms of the chord on the rich desk, the strip's existing deadline, measured by the Lens trace.

## Not in this issue

- The modes that drive the list: **Modes are the only modality**. The legend's content comes from there once it lands; until then it shows the Lens keys as today.

## Depends on

Nothing.

## Done when

- [ ] Side-by-side captures of a strip Tile's controls and a native window's, and of the search list and Spotlight on the same desk, with no unlisted difference.
- [ ] The Lens trace shows the search list's first frame under 100 ms on the rich desk in a guest, ten openings in a row.
- [ ] Tests cover the match highlight's ranges and the footer's presence.

## Sources

- #268, "The strip's close/minimize/fullscreen buttons don't look like macOS" and "The Ctrl-F switcher needs macOS-native polish".
