# WinMux (personal fork)

A sidebar-first tiling window manager for macOS, forked from AeroSpace. This glossary covers the fork's additions: finding windows through Lenses, and laying out windows in fixed columns that adapt to the attached display.

## Finding windows

**Lens**:
A named way to find windows: a Filter, a Presentation, sort order, and the actions its keys run on the selected window. A Trigger opens it as an overlay showing the matching windows.
_Avoid_: picker, picker binding, switcher, exposé, overview, Mission Control

**Filter**:
A named predicate over windows, written in CEL and type-checked when the config loads, evaluated against a Filter context each time a Lens opens. A Filter only says yes or no; ordering belongs to the Lens.
_Avoid_: query, rule, scope

**Window class**:
How WinMux classifies a window: tiled, floating, fullscreen, minimized, hidden-app, accessory-popup (a close-button-less window of an Accessory app) or app-popup (a regular app's popup, such as an autofill dropdown). Lenses leave out both popup classes unless the Filter names them.
_Avoid_: kind, type, layout

**Filter context**:
The live state a Filter can read when it runs: focused window and app, window and app under the mouse, current workspace, project and monitor, the previously focused window, and the active Display profile.
_Avoid_: environment, state

**Presentation**:
How a Lens lays out its matches: **grid** (every match at once, as thumbnails) or **strip** (a single row cycled while a modifier is held).
_Avoid_: view, mode, style

**Trigger**:
A key or trackpad-gesture binding whose command opens a Lens.
_Avoid_: shortcut, hotkey

**Summon**:
To move the selected window into the current workspace, rather than going to the window's workspace.
_Avoid_: pull, bring, fetch

**Accessory app**:
An app with no Dock icon and no entry in the native cmd+tab (LSUIElement), such as a menu-bar utility.
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

**Policy hook**:
A decision point where WinMux asks the config what to do, given the window and its context, and gets back one of a fixed set of actions. For example, where a new window goes, or what a move does at a Column edge.
_Avoid_: rule, callback

**Display profile**:
A named condition that holds while a given display is attached. Settings such as the Column count, widths and Lenses can be given per Display profile, and the matching variant applies while that profile is active.
_Avoid_: display mode, monitor config, layout preset
