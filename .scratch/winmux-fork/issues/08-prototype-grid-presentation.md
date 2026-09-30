# Prototype: grid Presentation look and behaviour

Type: prototype
Status: resolved
Blocked by: 03, 14

## Question

What should the grid Presentation look and behave like, so it no longer 'looks awful'? Build a rough UI prototype: thumbnail layout for about 5 to 40 windows, grouping by workspace or project, how stale thumbnails of parked windows are shown, how Accessory app windows look, selection and keyboard or gesture navigation, the Summon affordance, and behaviour on the laptop panel versus the ultrawide.

Inputs from [Task: measure thumbnail capture on Prateek's machine](14-task-measure-thumbnail-capture.md): most parked thumbnails are frozen at park time, so design them as "as of when you left it"; the grid panel should be non-opaque so visible windows keep painting underneath it. That was only checked on Chrome with an 85% black backdrop; confirm Electron and Metal apps, and whether a darker non-opaque backdrop still keeps them live.

## Answer

> Amended (2026-09-30): [Grilling: cmd-K search Lens](19-grilling-cmd-k-search.md) added `'list` to what v1 builds, and specified typing in `'miniatures`: non-matches dim in place and arrows move among matches.

> Revised (2026-09-30): an adversarial review of the first answer found that it claimed more than Prateek had said, contained two false claims about the prototype, and proposed config names that clashed with existing terms. Prateek then decided four points: real positions become their own Presentation, v1 builds only that one, the default is the same on both screens, and Summon runs the `place` hook. This answer replaces the first one.

Prototyped and reacted to with Prateek on 2026-09-29 and 2026-09-30. What made Mission Control with WinMux look awful is that it doesn't know about workspaces and draws parked windows as corner slivers. The answer is a third Presentation that draws each workspace to scale.

- **New Presentation: `'miniatures`**, alongside `'grid` and `'strip`. It draws each workspace as a small copy of itself, with every window where it actually sits: tiled windows in their Columns or tree positions, floating windows on top. Workspaces are arranged in a grid of cells in sidebar order. Minimized and hidden-app windows sit in a tray under their workspace. Window titles are hidden; the selected window's title appears under its workspace. It's a Presentation rather than a grid option because real positions fix everything else: sections are always workspaces, entries are always windows, and sort does nothing. Under `'miniatures`, the contract rejects `sections`, `entries` and `sort`.
- **Settings.** A `miniatures` record on the Lens, overridable per Display profile with `when.<profile>` like everything else. Every field names something you can see on screen, is singular unless it holds a list, and uses glossary terms where they exist. Prateek's pick, prototype preset C, is the same on the laptop and the ultrawide:

  ```nickel
  lenses.overview = {
    presentation = 'miniatures,
    miniatures = {
      fit = 'page,                        # 'page | 'shrink
      current_workspace = 'highlight,     # 'plain | 'highlight | 'enlarge | 'hide
      frozen_thumbnail = 'dimmed,         # 'plain | 'age_badge | 'pause_badge | 'dimmed
      accessory_window = 'enlarged,       # 'enlarged | 'actual_size
      arrow_keys = 'nearest,              # 'nearest | 'by_workspace
      summon_hints = ['label, 'landing_spot],   # any of 'label | 'landing_spot | 'target_workspace
    },
  }
  ```

  - `fit`: when the workspaces don't fit at a readable size, show them on pages or shrink them. Scrolling turns the page, as already decided for the grid.
  - `current_workspace`: how the current workspace is marked. `'hide` leaves it out, since it's already visible behind the overlay. The contract rejects `'hide` together with `'landing_spot`, because the landing spot is drawn inside the current workspace.
  - `frozen_thumbnail`: how a Frozen thumbnail is marked. Live and fresh thumbnails are never marked.
  - `accessory_window`: a small Accessory app window, such as Ghost Pepper, is drawn with a dashed outline and a "menu-bar app" tag. `'enlarged` grows it to a readable size at its position; `'actual_size` keeps it to scale.
  - `arrow_keys`: `'nearest` moves to the nearest window in that direction; `'by_workspace` moves between windows within a workspace with ← and →, and between workspaces with ↑ and ↓.
  - `summon_hints`: what shows while Summon's modifier is held. `'label` puts "Summon to N" on the selection, `'landing_spot` draws a dashed outline where the window will land, and `'target_workspace` outlines the current workspace.

  The tuning numbers stay out of config: the readable floor (110 points of workspace height), gaps and badge sizes.
- **Summon runs `place`.** A Summoned window arrives on the current workspace like any tiling window, so [Grilling: fixed Columns, Width presets and Overflow policy semantics](09-grilling-fixed-columns-model.md)'s `place` hook picks its Column and Overflow action. Summon doesn't run `arrive`, because the window isn't new. The landing spot is `place`'s answer, computed only while Summon's modifier is held and once per selection change. Its cost is part of [Task: Nickel binding spike](28-task-nickel-binding-spike.md).
- **Thumbnail states.** Windows on the current workspace are live. Parked windows show their park-time frame. Safari keeps painting, so its thumbnails stay fresh. Minimized and hidden-app windows show the frame captured at minimize or before the hide. A window with no capture shows its app icon.
- **The default `overview` Lens becomes `'miniatures`.** This replaces the grid with `sections = 'workspace` and `sort = ['spatial]` from [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md).
- **v1 builds only `'miniatures`.** The grid keeps its place in the model: a Lens of floating windows, for example, has no positions worth keeping. Its packed arrangements (rows, cells, a sidebar of sections; cards or text tiles; paging or collapsing) were prototyped but aren't specified yet; that's in the map's fog. Until then, a Lens with `presentation = 'grid` is rejected at load as not yet supported.
- **Known risk: telling windows apart.** A workspace can shrink to 110 points tall before the view pages, so on the laptop a Column can be about 85 points wide. Two Chrome windows in one workspace then look the same until one is selected. The mitigations are the selected window's title, the app icons, and typing to filter, which [Grilling: cmd-K search Lens](19-grilling-cmd-k-search.md) already covers. Check this on the real build before tuning the floor.
- **Left to other tickets.**
  - The strip: [Prototype: strip Presentation look and keyboard model](29-prototype-strip-presentation.md).
  - The backdrop defaults to 60% black with blur, provisionally, until [Task: confirm the grid backdrop keeps Electron and Metal windows live](30-task-grid-backdrop-liveness.md) sets the allowed range.
  - Animating the real windows into place, as Mission Control does: in the map's fog.

[prototype](../prototypes/08-grid-presentation.html). It's a single HTML file where every choice is a switch; presets A–D recreate the first round's variants, and Prateek's pick is `?preset=C`. Its switch names predate this answer. `08-grid-presentation-phone.html` is a phone-friendly copy of the first round, made by another session.
