# WinMux (personal fork)

A sidebar-first tiling window manager for macOS, forked from AeroSpace. This glossary covers the fork's additions: finding windows through Lenses, and laying out windows in fixed columns that adapt to the attached display.

## Finding windows

**Lens**:
A named way to find windows: a Filter, a Presentation, sort order, and the actions its keys run on the selected window. A Trigger opens it as an overlay showing the matching windows.
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

**Trigger**:
A key or trackpad-gesture binding whose command opens a Lens.
_Avoid_: shortcut, hotkey

**Hold**:
The time from a **Trigger**'s key press until its invoking Command, Control and Option modifiers are released (or Shift for a Shift-only chord), or until the first unbound letter is typed, whichever comes first. Shift otherwise controls reverse stepping and capital letters. It belongs to the Lens session, not to a **Presentation**. While it lasts the Lens is a gesture: the Trigger's key steps and the Lens's own chords run. After it the Lens is modal: it stays open with nothing held, plain keys are commands as in vim's normal mode (`h`, `j`, `k`, `l` move, `/` starts Search, Escape leaves it), and a modifier means itself. What a release does (commit, or stay open) is decided for the Lens, not by the Presentation.
_Avoid_: strip mode, held mode

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
