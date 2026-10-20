# The HUD can show the current mode's keys

Part of {{UMBRELLA}}.

## What to build

The HUD shows the current mode's name. A Lens draws a legend of its keys below its panel. With `window` holding fifty keys and the Lens-operating modes holding a dozen each, a mode's keys are the thing a person cannot remember on their first day, and the renderer that would show them exists.

Let a mode's HUD draw its key record as a legend, which-key style, after a short delay.

## Decisions

- **`hud` is a mode property**: `'name`, the default, draws the mode's name as today; `'legend` draws the name and the mode's keys; `'none` draws nothing.
- **The legend uses the Lens legend renderer**: chords grouped by equal command lists, digit runs collapsed to a range, custom commands joined by `; `, truncated at the tail. It sits where the HUD sits, bottom centre of the focused monitor.
- **It appears after a delay, 400 ms by default**, so a chain of keys never sees it; the first key after entering the mode restarts the delay. `hud-delay` in milliseconds sets it.
- **Off by default.** Shipped modes use `'name`. The example keyboard module turns `'legend` on for `window`, so a person who imports the full layout gets the help with it.
- **Tuna's menus are not this.** The legend shows WinMux's own mode and nothing else.

## Depends on

- **Modes are the only modality**.
- **The shipped keyboard: a minimal main and a full window mode**, for the example module this turns the legend on in.

## Defaults chosen for you

- **A held mode's legend** appears on the same delay; a strip's own legend takes precedence while a Lens is open, so a mode with an open Lens shows one legend, the Lens's, with the mode's name beside it.
- **The legend's width** is bounded as the Lens legend is, with the same 32-point inset from the screen's sides.

## Done when

- [ ] `hud = 'legend` on `window` shows its keys after 400 ms and hides them on the next key; `'name` shows the name only; `'none` shows nothing. Tests cover the delay and the restart.
- [ ] In a guest, a capture of `window` with the legend on, and one of Cmd-Tab with the legend on showing the Lens legend and the mode name together.
- [ ] `docs/default-config.md` documents `hud` and `hud-delay`.

## Sources

- The grilling record, 2026-10-19, "Modality": "maybe we have disabled by default and enable on".
