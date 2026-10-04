# Storyboard format

One file per pull request. A heading per group, a block per demo, the table last.

```markdown
# Storyboard: <pull request title>

## Hero

### strip-cycle (demo)
- **Claim:** Holding cmd and tapping tab cycles the strip; releasing cmd focuses the selection.
- **Setup:** Ghostty and Zed on workspace 1, Safari and Notes on workspace 2. Zed is focused.
- **Action:** hold cmd; tab; tab; release cmd.
- **Watch:** The row opens on Ghostty and steps to Safari. On release workspace 2 is on screen with Safari focused.
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
- The kind in parentheses is `demo`, `still` or `transcript`.
- **Action** lists the chords and commands in order, as they will go to `film` as steps.
- **Watch** names the last frame: what is on screen when the take ends.
