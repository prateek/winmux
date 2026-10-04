# Storyboard format

One file per pull request. A heading per group, a block per demo, the table last.

```markdown
# Storyboard: <pull request title>

## Hero

### strip-cycle (demo, card)
- **Claim:** Holding cmd and tapping tab cycles the strip; releasing cmd focuses the selection.
- **Setup:** Four owned windows on one workspace: red, blue, green, yellow. Red is focused.
- **Action:** hold cmd; tab; tab; release cmd.
- **Watch:** The highlight steps blue, then green. On release the strip closes and green is focused.
- **Crop:** the strip and the windows under it.

## Everyday use

Reaching a window on another workspace without leaving this one.

### strip-summon (demo)
- **Claim:** …

## CLI

### lenses-json (transcript)
- **Claim:** `winmux list-lenses --json` lists the five shipped Lenses.
- **Command:** `winmux list-lenses --json`

## Done-when table

| Done when | Shown by |
| --- | --- |
| `cmd-tab` opens `recent` as a strip | strip-cycle |
| A second display … | not shown: needs two displays; covered by `StripLayoutTest` |
```

- The id is the demo's file name: `demos/strip-cycle.gif`.
- The kind in parentheses is `demo`, `still` or `transcript`; `card` marks the hero.
- **Action** lists the chords and commands in order, as they will go into the take's event log.
- **Watch** names the last frame: what is on screen when the take ends.
