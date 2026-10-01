# Grilling: Swish-style gestures and snapping

Type: grilling
Status: out of scope
Blocked by: 09, 16, 17

Deferred 2026-09-30: Prateek put trackpad gestures off to a later effort so the keyboard-driven foundation can be built first. See the map's Out of scope section.

## Question

Which trackpad gestures move and resize windows, and how do they map onto Columns and Width presets? That covers both Swish-style two-finger gestures limited to a location (titlebar, tab bar, Dock, menubar, or with a modifier held) and three- and four-finger ones. The gesture grammar and the continuous-gesture rule (ghost preview, commit on lift, cancel with Esc or after resting, haptic tick, no destructive single-motion gestures) are set by [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md). Decide:

- The default mapping: which gesture moves a window to the neighbouring Column, cycles its Width preset, stacks it above or below in a Column (Swish's quarter-refinement within one gesture), floats it, or moves it to another workspace or monitor. The candidates are in the table in §6 of [research/07-swish-gestures.md](../research/07-swish-gestures.md).
- Which locations v1 supports, and how the titlebar is hit-tested (AX, or a titlebar-height band).
- How scroll and pinch are suppressed in the app underneath during a two-finger gesture, building on the finger-down scroll tap from [the gesture research](01-research-gesture-interception.md), and what happens with apps that scroll inside their titlebar (Firefox).
- How snapping behaves for floating windows, if at all.
