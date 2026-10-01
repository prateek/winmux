# Global MRU (`lastFocusedSeq`)

Part of {{UMBRELLA}}.

## What to build

Give every window a sequence number that records when it was last focused, across all workspaces. WinMux today only keeps a recent-children order per tree node and the previous two focused windows, so nothing can list all windows in most-recently-used order. Lenses sort by this number, and Filters can read it.

## Decisions

**The field**

- Each `Window` gets a monotonic `lastFocusedSeq`. A higher number means focused more recently.
- `0` means the window has never been focused.
- It is kept in memory only. Nothing is written to disk, so after a restart every window starts at `0`.

**Where it is written**

- It is written in `checkOnFocusChangedCallbacks` (`Sources/AppBundle/focus.swift`), after the refresh has read the OS's focused window.
- It is never written in `setFocus`. `setFocus` is only a request, and the OS may not honour it.
- Selecting a window in a Lens or the palette, or running `focus`, therefore does not change the order by itself. The order changes when the next refresh confirms that the window has focus. This keeps the order from claiming a window the user never reached.

**Ordering by it**

- Most-recently-used order is `lastFocusedSeq` descending.
- Windows that were never focused sort after every focused window, in `created` order (registration order).
- After a restart, when every window is at `0`, the order is therefore `created` order until focus moves.

**Who reads it**

- The `mru` sort key of a Lens uses this order. The strip's default (`mru`, current window first, selection starting on the second) relies on it.
- Filters read it as `w.lastFocusedSeq`.

**What stays as it is**

- The per-parent recent-children order in the tree and `prevFocus` / `prevPrevFocus` keep their current behaviour. This issue adds a field next to them.

## Not in this issue

- The `w.lastFocusedSeq` field in the records passed to Nickel: "Filter contract v1 and `config schema`".
- The `sort` keys and `list-windows --lens`: "Lens core and the `'list` Presentation with Search".
- The strip that shows the order on cmd+tab: "Strip Presentation and the cmd+tab takeover".

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **The window focused at launch.** `checkOnFocusChangedCallbacks` returns early during the startup refresh, and that early return stays. The window focused at launch gets its number on the first refresh after startup. That refresh may not count as a focus change (`_lastKnownFocus` can already equal the current focus), so assign a number whenever the confirmed focused window is not the one holding the highest number, not only when the function's `hasFocusChanged` is true.
- **A CLI field for the sequence.** `list-windows --json` gains `last-focused-seq`, and `list-windows --format` gains `%{window-last-focused-seq}`.

## Done when

- [ ] Focusing window A, then B, then A gives A a higher `lastFocusedSeq` than B, and B a higher one than a window never focused.
- [ ] The order holds across workspaces: a window focused on another workspace ranks by when it was focused, wherever it sits in the tree.
- [ ] A `setFocus` call that the OS does not confirm leaves every `lastFocusedSeq` unchanged, and a test covers it.
- [ ] Focus changes that WinMux did not request (a click, an app activating itself) update the number on the next refresh.
- [ ] A helper that orders windows by most recent use puts never-focused windows last, in `created` order, and a test covers it.
- [ ] Existing `focus-back-and-forth` and recent-child behaviour is unchanged.

## Sources

- [Grilling: Lens configuration shape](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/07-grilling-picker-binding-shape.md) (the Global MRU decision)
- [Research 03: live thumbnails for parked windows, and AltTab's implementation](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/research/03-thumbnails-and-alttab.md) (AltTab writes its order only after focus is confirmed)
- [Grilling: the Filter contract's final field list](https://github.com/prateek/winmux/blob/wayfind-fork/.scratch/winmux-fork/issues/33-grilling-filter-contract-field-list.md) (exposes the field to Filters)
