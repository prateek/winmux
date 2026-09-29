# WinMux (personal fork)

A sidebar-first tiling window manager for macOS, forked from AeroSpace. This glossary covers the fork's additions: finding windows through filtered pickers, and laying out windows in fixed columns that adapt to the attached display.

## Finding windows

**Picker**:
An overlay that shows the windows matching a Filter and lets the user act on one.
_Avoid_: switcher, exposé, overview, Mission Control

**Filter**:
A named predicate over windows, written in CEL and type-checked when the config loads, evaluated against a Filter context each time a Picker opens. A Filter only says yes or no; ordering belongs to the Picker binding.
_Avoid_: query, rule, scope

**Window class**:
How WinMux classifies a window: tiled, floating, fullscreen, minimized, hidden-app, accessory-popup (a close-button-less window of an Accessory app) or app-popup (a regular app's popup, such as an autofill dropdown). Pickers leave out both popup classes unless the Filter names them.
_Avoid_: kind, type, layout

**Filter context**:
The live state a Filter can read when it runs: focused window and app, window and app under the mouse, current workspace, project and monitor, the previously focused window, and the active Display profile.
_Avoid_: environment, state

**Presentation**:
How a Picker lays out its matches: **grid** (every match at once, as thumbnails) or **strip** (a single row cycled while a modifier is held).
_Avoid_: view, mode, style

**Trigger**:
A key chord or trackpad gesture that opens a Picker.
_Avoid_: shortcut, hotkey

**Picker binding**:
A Trigger paired with a Filter, a Presentation, and grouping and sort options.
_Avoid_: switcher config

**Summon**:
To move the selected window into the current workspace, rather than going to the window's workspace.
_Avoid_: pull, bring, fetch

**Accessory app**:
An app with no Dock icon and no entry in the native cmd+tab (LSUIElement), such as a menu-bar utility.
_Avoid_: menubar app, agent app, background app

## Layout

**Column**:
A vertical slot of fixed width on a workspace, holding one window or one tab group.
_Avoid_: pane, split, tile

**Width preset**:
One of a small set of fractions (e.g. 1/3, 1/2, 2/3) that a Column's width can be cycled through.
_Avoid_: size, ratio

**Overflow policy**:
What happens when a new window opens and every Column is already occupied.
_Avoid_: fallback

**Display profile**:
A named bundle of layout settings (Column count, Overflow policy, sidebar mode, gaps) applied while a given display is attached.
_Avoid_: display mode, monitor config, layout preset
