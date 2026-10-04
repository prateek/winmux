# Hints shown while a key is held

Part of {{UMBRELLA}}.

## What to build

A Lens draws its Summon hints all the time: a label on the selected entry and a dashed landing spot. They are noise when the person only wants to switch, and the other keys a Lens has (close, send to a workspace, change the grouping) are shown nowhere. This issue shows all of it while one key is held, and none of it otherwise.

Prateek confirmed this design from the prototype on 2026-10-04.

## Decisions

- **While the hints key is held, the Lens shows:**
  - the Summon label on the selected Tile, when a Summon would move it;
  - the landing spot, where the window would land;
  - on each Tile, the workspace its window is on, as the number key that sends a window there;
  - a legend of the Lens's own `keys`, read from the config, below the panel.
- **Releasing the key hides them.**
- **The panel thins while hints show**, so a landing spot behind a large grid can be seen.
- **`hints = 'held` is the default.** `hints = 'always` shows them all the time, which is today's behaviour for the Summon hints.
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

- [ ] With the default config, an open Lens shows no Summon label and no landing spot until Option is held.
- [ ] Holding Option shows the label, the landing spot, the workspace keys and the legend; releasing hides them.
- [ ] `hints = 'always` restores hints that never hide.
- [ ] The legend lists the keys of the Lens that is open, including one changed in the config.
- [ ] A test covers the legend built from a Lens's `keys`.

## Sources

- [the Lens look prototype](https://github.com/prateek/winmux/blob/fork/.scratch/winmux-fork/prototypes/31-lens-look/index.html)
