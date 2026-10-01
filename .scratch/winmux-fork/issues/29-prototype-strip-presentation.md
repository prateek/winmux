# Prototype: strip Presentation look and keyboard model

Type: prototype
Status: resolved
Blocked by: 25

## Question

What should the strip Presentation look like and how should it behave, for the `recent` (cmd-tab) and `app-windows` (cmd-backtick) Lenses? Build a rough UI prototype covering:

- Hold and release: the strip commits when the invoking modifiers are released, and `enter`'s command runs unless a modifier held at release selects another binding (settled in [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md)). Decide reverse cycling (shift, or the backtick key), what a quick tap does under the 100 ms display delay, and AltTab's three release styles (focus, hold, search) as the starting point.
- How Summon's modifier is shown while it's held. `'miniatures` shows a "Summon to N" label and the landing spot ([Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md)), and the strip should agree with it.
- Tile content: thumbnails with the Frozen thumbnail treatment used by `'miniatures`, or icon and title. Whether the strip takes a `strip` record like the `miniatures` record, and which of its settings (`frozen_thumbnail`, `accessory_window`, `summon_hints`) carry over.
- Gesture Triggers are deferred with the rest of the gesture work (2026-09-30); the prototype covers keyboard Triggers only.
- Laptop against ultrawide: where the strip sits on a 32:9 screen, and how many tiles show before it scrolls.

Typing to filter inside a Lens belongs to [Grilling: cmd-K search Lens](19-grilling-cmd-k-search.md); this prototype only needs to leave room for it. That ticket settled that the strip has no Search box and hands off to `'list` through `lens --presentation list`; pick the strip's default key for it here.

## Answer

Resolved 2026-09-30 with Prateek. The strip is not a second system: it is the Lens machinery (Filter, MRU order, selection, key actions, Summon, thumbnail cache, overlay panel) with a one-row layout and hold-to-cycle. So it inherits nearly everything, and only three things are specific to it.

**Inherited**

- **Tile look.** Thumbnail with app icon and title, with Frozen thumbnails dimmed and Summon shown as a "Summon to N" label plus the landing spot: the choices Prateek made for `'miniatures`.
- **Shared look settings move to the Lens.** `frozen_thumbnail`, `accessory_window` and `summon_hints` become fields of the Lens, read by every Presentation, and leave the `miniatures` record, which keeps only its layout settings. The strip has no record of its own. This amends [Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md).
- **Hold and release.** Releasing the invoking modifiers commits, and a release within the 100 ms display delay swaps to the previous window without the strip appearing, as [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md) decided. There is no stay-open mode; that's what `'list` is for.
- **Placement.** Centred on the screen. When the row runs out of room it scrolls, keeping the selection in view, with a "+N" count at each end.

**Specific to the strip**

- **Reverse is `shift` plus the invoking key**: `shift-tab` in `recent`, `shift-backtick` in `app-windows`. The backtick key does not reverse `recent` (Prateek turned that down), so it differs from native cmd+tab here.
- **Summon at release is Option.** Shift is already reverse, so holding it at release can't also mean Summon. `shift-enter` stays Summon in `'list` and `'miniatures`, where shift doesn't cycle.
- **Hand-off to Search.** Typing a letter turns the strip into the `'list` Presentation of the same Lens (`lens --presentation list`), with that letter in the Search box and the selection kept.

Gesture Triggers are deferred with the rest of the gesture work, and placement over the focused Column on an ultrawide waits for Display profiles.

[prototype](../prototypes/29-strip-presentation.html) (Option stands in for Cmd; its switches show the alternatives that were turned down)
