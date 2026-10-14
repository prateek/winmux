# Hints shown while a key is held

Part of {{UMBRELLA}}.

## What to build

A Lens previously drew its Summon label and dashed landing spot while the modifiers of a configured Summon binding were held, subtracting a live Hold’s invoking modifiers. They are noise when the person only wants to switch, and the other keys a Lens has (close, send to a workspace, change the grouping) are shown nowhere. This issue shows all of it while one key is held, and none of it otherwise.

Prateek confirmed this design from the prototype on 2026-10-04.

## Decisions

- **While the hints key is held, the Lens shows:**
  - the Summon label on the selected Tile, when a Summon would move it;
  - the landing spot, where the window would land;
  - on each Tile, the workspace its window is on, as the number key that sends a window there;
  - a legend of the Lens's own `keys`, read from the config, below the panel.
- **Releasing the key hides them.**
- **The panel thins while hints show**, so a landing spot behind a large grid can be seen.
- **`hints = 'held` is the default.** `hints = 'always` shows them all the time.
- **The default key is Option**, set as `hints-key`. It is the modifier that the default Summon binding, `alt-enter`, already uses, so holding it shows what pressing Enter would then do.
- **`summon-hints` keeps its meaning**: it picks which of the Summon hints exist at all.
- **The look is the prototype's**: [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html). Click the desk and hold Option.

## Not in this issue

- A hint that types a key for the person, or a clickable legend.
- Hints for keys outside the Lens's own `keys`.

## Depends on

- **Sections, and a control to change the grouping**, whose key the legend lists.

## Defaults chosen for you

- **A strip whose Trigger holds the hints key.** The key is already down for as long as the strip is open, so that strip shows its hints all the time.
- **The legend's wording** comes from the command each key runs: `focus`, `summon`, `close`, `move-node-to-workspace <n>` collapsed to one entry for the digits.
- **In `'miniatures`** the landing spot and the label draw as they do today, shown only while the key is held.

## Done when

- [x] With the default config, an open Lens shows no Summon label and no landing spot until Option is held.
- [x] Holding Option shows the label, the landing spot, the workspace keys and the legend; releasing hides them.
- [x] `hints = 'always` restores hints that never hide.
- [x] The legend lists the keys of the Lens that is open, including one changed in the config.
- [x] A test covers the legend built from a Lens's `keys`.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)

## Built

- `hints = 'held` and `hints-key = 'alt` resolve in shared Lens defaults and `when`, accepting tags or their string spellings. Miniatures accepts both; `summon-hints` and its `current-workspace = 'hide` restriction keep their contracts.
- `hintsShown` is the one published visibility predicate. A live Hold subtracts its invoking modifiers; after release or the first letter ends it, physically held modifiers count. Other Triggers ignore each invoking modifier until its first release. Strips sample physical opening modifiers and show an invoking hints key from their first frame. Shift alone no longer shows hints with the default key. Action routing is unchanged.
- The Summon label includes its chord, preferring a Summon key with exactly the hints modifier, then the first in legend order. Lists, grids and strips require another workspace and a configured Summon key; miniatures retains its same-workspace behavior. Hiding cancels the landing calculation.
- Picture/card chips come from exact workspace-move commands in the Lens’s active keys and sit inside the fitted picture at bottom-right. Rows, text Tiles and miniatures omit them. App entries use their first window’s workspace.
- The pure legend groups identical command lists and workspace digits, omits empty commands and inactive section keys, and shares the Settings chord formatter. Reload leaves an open Lens’s keys intact; the next Lens reads the new config. The bar sits below the painted panel with 52 scaled points of bottom clearance; miniatures uses that clearance directly.
- Only list/strip/grid glass thins to 55%; content and the miniature backdrop keep their opacity. Trace text and JSON report `hints=shown|hidden`.
- Seam tests and guest standing-desk readbacks cover the five Done-when items, all four Presentations, Hold/Trigger suppression, Shift-Enter, the strip exception, always-visible hints, Control hints, changed keys and another Lens’s own keys. One live action probe runs against the base and feature builds. Reproducible proof tools are in `.scratch/winmux-fork/proofs/held-hints/`.

No named default changed. Host and pinned-version guest `make check` pass: 1,173 Swift, 75 helper and 75 plain-Python script tests, with no skipped Swift tests. The builder’s live evidence includes the exact earlier `len saf` held-strip query as well as `saf` in the action comparison.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] Real keyboard timing, including rapid Trigger releases and held typing.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

The builder publishes no release. Final-commit demos and landing belong to the relay driver.
