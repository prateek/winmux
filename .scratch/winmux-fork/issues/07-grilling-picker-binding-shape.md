# Grilling: Picker binding configuration shape

Type: grilling
Status: open
Blocked by: 01, 06

## Question

What exactly does a Picker binding declare, and how is it configured? Trigger syntax (key chords, gestures from the gesture research), Filter reference, Presentation, grouping (window vs app), sort (MRU, spatial, by workspace), actions and their modifiers (focus default, Summon, close, float/tile toggle, move to workspace), and whether one Trigger can open different Filters depending on the Display profile. Also the CLI surface (`winmux picker ...`).

From the thumbnails research: WinMux has no global MRU (only recent children per tree node, plus the previous two focused windows). Decide where the per-window focus timestamp is written, and adopt AltTab's rule of writing it only after the OS confirms focus. AltTab's per-shortcut options (apps to show, spaces, screens, minimized, hidden, fullscreen, window order) are candidate built-in Filter vocabulary.
