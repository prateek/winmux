# WinMux (personal fork)

A sidebar-first tiling window manager for macOS, forked from AeroSpace. This glossary covers the fork's additions: finding windows through Lenses, and laying out windows in fixed columns that adapt to the attached display.

## Finding windows

**Lens**:
A view of matching windows: a Filter, a Presentation, sort order and shared Tile settings. A command in any Mode, a gesture or the CLI opens it. Its view state is selection, Search text, marks in mark order and the focused pane; keys belong to Modes. A mode and its Lens are one thing exactly when the mode opened the Lens. Closing a Lens a mode owns ends that mode in `main`; closing a Lens no mode owns changes no mode. A Lens that replaces the one a mode owns is still that mode's.
_Avoid_: picker, picker binding, switcher, exposé, overview, Mission Control

**Filter**:
A named yes/no function over windows, checked when the config loads, evaluated against a Filter context each time a Lens opens. A Filter only says yes or no; ordering belongs to the Lens.
_Avoid_: query, rule, scope

**Window class**:
How WinMux classifies a window: tiled, floating, fullscreen, minimized, hidden-app, accessory-popup (a close-button-less window of an app that has no Dock icon at that moment) or app-popup (a regular app's popup, such as an autofill dropdown). Lenses leave out both popup classes unless the Lens lists them.
_Avoid_: kind, type, layout

**Filter context**:
The live state a Filter can read when it runs: focused window and app, window and app under the mouse, current workspace, project and monitor, the previously focused window, and the active Display profile.
_Avoid_: environment, state

**Presentation**:
How a Lens lays out its matches: **grid** (every match at once, as thumbnails packed into sections), **miniatures** (every workspace drawn as a small copy of itself, with each window where it actually sits) **strip** (rows sized to fit, cycled while a modifier is held) or **list** (a Search box above ranked rows of windows).
_Avoid_: view, mode, style

**Tile**:
The drawing of one Lens entry: its picture, icon, title and badges. Every **Presentation** lays out Tiles and draws nothing of its own inside them, so a change to the Tile shows in all of them.
_Avoid_: cell, card, thumbnail, row

**Section**:
A labelled group of a Lens's entries, by workspace, project, monitor or app. Lists and grids draw sections; the grouping can change while the Lens stays open.
_Avoid_: category, bucket

**Search**:
The text typed into an open Lens. It narrows the Lens's matches and ranks them by how well they match; the Filter decides which windows are eligible, and the Search picks among them.
_Avoid_: query, filter text

**Frozen thumbnail**:
A thumbnail showing a window as it was when it was last on screen, not as it is now. Most apps stop painting a window once it's parked or covered, so every thumbnail outside the current workspace is usually frozen.
_Avoid_: stale thumbnail, cached thumbnail, snapshot

**Tab**:
Something inside a window that can be switched to but isn't a window of its own, such as a browser tab, an editor file or a terminal in a sidebar app. A native macOS tab is a window, not a Tab.
_Avoid_: tab group, pane, surface

**Tab provider**:
The source that lists an app's Tabs and brings a chosen one to the front, either asked by WinMux when a Lens opens or publishing to WinMux on its own.
_Avoid_: tab source, adapter, integration

**Mode**:
The one owner of keyboard modality. A named mode has a lifetime (`latched`, until replaced; `held`, until all entry modifiers are released; or `transient`, for one key), an unbound-key policy (`pass`, `consume`, `type` into Search, or `latch` into another mode and reread an unbound letter), `on-enter`, `on-release`, `draw-delay`, and `count`. `latch-to` names the latch target. Entering a mode replaces the current one. A Lens opened by its `on-enter` belongs to it; a mode that needs a Lens adopts one already open when it enters. Closing a Lens a mode owns ends that mode in `main`; closing a Lens no mode owns changes no mode, including its lifetime and entry modifiers.
_Avoid_: Hold, strip mode, binding mode, input state

**Keymap**:
Named blocks of chord or sequence bindings, conditioned on `mode`, `app` (the front app's bundle id), `lens`, `presentation`, `columns` (the focused workspace's Column count), and `profile` (`default` until Display profiles land). Greater specificity wins, then greater priority; an unresolved tie is a config error. `mode.<name>.binding` is sugar for a block on that mode. A binding's `'pass` value leaves its chord to the app.

A collection a person extends is a record keyed by name: Lenses, modes, keymap blocks, Filters, profiles and popup-class booleans. A list is an ordered value replaced whole, such as commands, sort keys, width presets or Column widths. Nickel merges records field by field; it does not extend lists.

**Summon**:
To move the selected window into the current workspace, rather than going to the window's workspace.
_Avoid_: pull, bring, fetch

**Accessory app**:
An app declared to have no Dock icon and no entry in the native cmd+tab (LSUIElement), such as a menu-bar utility. Some take a Dock icon for as long as they have a window open; they are still Accessory apps.
_Avoid_: menubar app, agent app, background app

## Layout

**Column**:
A fixed position and width on a workspace that holds any arrangement of windows: one window, a tab group, or splits of them. A Column keeps its place when it's empty, and switching workspace changes every Column at once.
_Avoid_: pane, split, tile

**Width preset**:
One of a small set of fractions (e.g. 1/3, 1/2, 2/3) that a Column's width can be cycled through.
_Avoid_: size, ratio

**Overflow policy**:
The action taken when a window's target Column is already occupied: join its tab group, split it, float the window, or squeeze in an extra Column.
_Avoid_: fallback

**Resolved placement**:
Where an incoming window or group would land, including its Column, the action to take there and the resulting widths. A landing hint uses a resolved placement; moving the window resolves again against the current workspace.

**Policy hook**:
A decision point where WinMux asks the config what to do, given the window and its context, and gets back one of a fixed set of actions, optionally followed by commands to run once the action has settled. For example, where an arriving window goes (workspace, floating, Column), or what a move does at a Column edge.
_Avoid_: rule, callback

**Display profile**:
A named condition that holds while a given display is attached. Settings such as the Column count, widths and Lenses can be given per Display profile, and the matching variant applies while that profile is active.
_Avoid_: display mode, monitor config, layout preset
