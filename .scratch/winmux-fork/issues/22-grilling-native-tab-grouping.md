# Grilling: grouping native macOS tabs in Lenses

Type: grilling
Status: out of scope
Blocked by: 07, 21

Deferred 2026-09-30: Prateek put tabs off to a later effort so the foundation can be built first. See the map's Out of scope section.

## Question

Apps that use `NSWindow` tabbing (Finder, Terminal, TextEdit, Ghostty) give each tab its own window, and WinMux (from AeroSpace #68) registers them as separate windows. How should Lenses treat them? Decide whether a tab group shows as one entry or one entry per tab, whether that's `entries = "tab-group"` on the Lens, next to `window` and `app` (see [Grilling: Lens configuration shape](07-grilling-picker-binding-shape.md)), how the group is identified (shared `AXTabGroup` element identity plus same-frame siblings; see §3 of [the tab research](../research/18-reading-app-tabs.md)), what thumbnails background tabs get (the inherited blank-tile problem), and whether these windows fill `w.tabs` for Filters. Probe 1 in the probes task confirms the starting behaviour.
