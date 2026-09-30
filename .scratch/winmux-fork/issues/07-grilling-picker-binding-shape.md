# Grilling: Lens configuration shape

Type: grilling
Status: resolved
Blocked by: 01, 06

## Question

What exactly does a Picker binding declare, and how is it configured? Trigger syntax (key chords, gestures from the gesture research), Filter reference, Presentation, grouping (window vs app), sort (MRU, spatial, by workspace), actions and their modifiers (focus default, Summon, close, float/tile toggle, move to workspace), and whether one Trigger can open different Filters depending on the Display profile. Also the CLI surface (`winmux picker ...`).

From the thumbnails research: WinMux has no global MRU (only recent children per tree node, plus the previous two focused windows). Decide where the per-window focus timestamp is written, and adopt AltTab's rule of writing it only after the OS confirms focus. AltTab's per-shortcut options (apps to show, spaces, screens, minimized, hidden, fullscreen, window order) are candidate built-in Filter vocabulary.

## Answer

> Amended (2026-09-30): [Grilling: cmd-K search Lens](19-grilling-cmd-k-search.md) added a fourth Presentation, `'list`, and Search (typed text) in every Lens. A fourth default Lens, `search`, ships unbound, and `winmux palette` becomes an alias for `lens search`.

> Amended (2026-09-30): [Prototype: grid Presentation look and behaviour](08-prototype-grid-presentation.md) added a third Presentation, `'miniatures`, configured by a `miniatures` record. Under it the contract rejects `sections`, `entries` and `sort`, because windows keep their real positions. The default `overview` Lens is now `presentation = 'miniatures`, not a grid.

> Amended (2026-09-29): [Prototype: config and scripting language](27-prototype-config-language.md) made the config Nickel, so `[lenses.<name>]` is now the `lenses.<name>` record, and inline Filters are Nickel functions rather than CEL. The shapes below otherwise stand.

Grilled with Prateek on 2026-09-29. "Picker" is retired as a term: the configured unit is a **Lens** (see `CONTEXT.md`).

- **Lens table.** `[lenses.<name>]` holds `filter` (a name or inline CEL), `presentation` (`grid`/`strip`), `entries` (what one tile is: `window` or `app`; the native-tab grouping ticket may add `tab-group`), `sections` (grid only: `none`/`workspace`/`project`/`monitor`/`app`; the strip ignores it), `sort` and `keys`. Defaults are `entries = "window"` for both Presentations, and `sections = "workspace"` for the grid.
- **Sort keys.** An ordered list from `mru`, `previous`, `spatial` (tree order, left to right), `workspace` (sidebar order), `app`, `title` and `created` (registration order), all ascending, with no `-desc` variants yet. Within sections, sort applies per section and sections follow sidebar order. Defaults are `["mru"]` for the strip, with the current window first and the selection starting on the second, and `["spatial"]` for the grid.
- **Triggers are ordinary bindings.** The command `lens <name>` goes in `[mode.<mode>.binding]` or the new `[mode.<mode>.gesture]` table, and a gesture can run any command, not only `lens`. A strip records which modifiers were held when it was invoked and commits when they're released.
- **Actions.** `[lenses.<name>.keys]` maps a key to any winmux command, run against the selected window the way `on-window-detected` targets a window. The defaults are `enter` → `focus`, `shift-enter` → `summon`, `cmd-w` → `close` and `cmd-<n>` → `move-node-to-workspace <n>`. Summon becomes a real command, `summon [--window-id]`. On release, a strip runs `enter`'s command unless a modifier held at release selects another binding; how that modifier is shown belongs to the strip fog. With the mouse, hovering moves the selection, a click runs `enter`, a modifier-click runs the matching modifier-enter binding, and scrolling pages the grid.
- **Per-Display-profile variants.** `[lenses.<name>.when.<profile>]` tables are merged over the base Lens while that Display profile is active, and `enabled = false` switches the Lens off: its Trigger then does nothing, and `winmux lens` exits non-zero with a message. **This replaces** the `profiles = [...]` gate from [Prototype: filter language worked examples](06-prototype-filter-language.md).
- **Global MRU.** Each `Window` gets a monotonic `lastFocusedSeq`, written in `checkOnFocusChangedCallbacks` (`Sources/AppBundle/focus.swift`), after refresh has read the OS's focused window, and never in `setFocus`, which is only a request. It's kept in memory only; after a restart, windows fall back to `created` order. Windows never focused sort after focused ones, by `created`. It isn't exposed to Filters.
- **CLI (this ticket's part).** `winmux lens <name>` opens a Lens; `winmux lens --filter '<cel|name>' [--presentation grid|strip] [--sort mru,…]` opens an ad-hoc one; `winmux list-lenses [--json]` prints the names plus the settings resolved for the active Display profile. [Grilling: CLI surface for the fork's features](20-grilling-cli-surface.md) owns the rest.
- **Default Lenses.** Three ship:
  - `recent`: a strip, every window, sorted by `mru`, on `cmd-tab`.
  - `app-windows`: a strip with the filter `focused.?app.bundleId.orValue('') == w.app.bundleId`, sorted by `mru`, on `cmd-backtick` (WinMux's spelling of cmd+`). A quick tap swaps windows without the strip appearing, thanks to the 100 ms display delay.
  - `overview`: a grid, every window, in `workspace` sections, sorted by `spatial`, on `three-finger-swipe-up`, pending [Grilling: which trackpad gestures WinMux owns](17-grilling-gesture-ownership.md).

  Taking over cmd+tab and cmd+` from the system is unverified, because WinMux's `HotKey`/Carbon registration probably can't do it. That's [Research: taking over cmd+tab and cmd+` from the system](25-research-system-switcher-takeover.md); the fallback is `alt-tab`.
- **Gesture Trigger grammar.** `[<location>-][<modifiers>-]<fingers>-finger-<motion>`:
  - location is `titlebar`, `tabbar`, `dock` or `menubar`; leaving it out means anywhere.
  - modifiers are spelled as for keys.
  - fingers is `two`, `three` or `four`. Two needs a location or a modifier, since bare two-finger input is scrolling.
  - motion is `swipe-<dir>`, `pinch-in`, `pinch-out`, `double-tap` or `tap-hold-swipe-<dir>`.

  The v1 recognizer handles three- and four-finger swipes only; other names parse and are rejected at config load as not yet supported. Direction paths (`swipe-left-up`) are rejected: refining a snap within one gesture is a behaviour of the command, not a separate Trigger. Swish prior art: [research/07-swish-gestures.md](../research/07-swish-gestures.md).
- **Continuous-gesture rule** (now a standing decision on the map). A gesture that moves or resizes a window shows a ghost preview, commits on lift, cancels on Esc or after 0.8 s at rest, and gives a haptic tick at each step. A destructive command is never a single-motion gesture.
- **Spun off.** Swish-style gestures and snapping, both two-finger location-qualified and three- and four-finger, go to [Grilling: Swish-style gestures and snapping](26-grilling-swish-gestures-and-snapping.md).
