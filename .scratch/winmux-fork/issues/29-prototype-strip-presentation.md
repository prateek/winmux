# Prototype: strip Presentation look and keyboard model

Type: prototype
Status: open
Blocked by: 17, 25

## Question

What should the strip Presentation look like and how should it behave, for the `recent` (cmd-tab) and `app-windows` (cmd-backtick) Lenses? Build a rough UI prototype covering:

- Hold and release: the strip commits when the invoking modifiers are released, and `enter`'s command runs unless a modifier held at release selects another binding (settled in [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md)). Decide reverse cycling (shift, or the backtick key), what a quick tap does under the 100 ms display delay, and AltTab's three release styles (focus, hold, search) as the starting point.
- How Summon's modifier is shown while it's held. `'miniatures` shows a "Summon to N" label and the landing spot ([Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md)), and the strip should agree with it.
- Tile content: thumbnails with the Frozen thumbnail treatment used by `'miniatures`, or icon and title. Whether the strip takes a `strip` record like the `miniatures` record, and which of its settings (`frozen_thumbnail`, `accessory_window`, `summon_hints`) carry over.
- Gesture Triggers: a discrete open, or a continuous swipe-and-hold that cycles the strip and commits on lift, following the continuous-gesture rule on the map.
- Laptop against ultrawide: where the strip sits on a 32:9 screen, and how many tiles show before it scrolls.

Typing to filter inside a Lens belongs to [Grilling: cmd-K search Lens](19-grilling-cmd-k-search.md); this prototype only needs to leave room for it. That ticket settled that the strip has no Search box and hands off to `'list` through `lens --presentation list`; pick the strip's default key for it here.
