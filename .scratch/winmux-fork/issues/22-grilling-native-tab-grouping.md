# Grilling: grouping native macOS tabs in Pickers

Type: grilling
Status: open
Blocked by: 07, 21

## Question

Apps that use `NSWindow` tabbing (Finder, Terminal, TextEdit, Ghostty) give each tab its own window, and WinMux (from AeroSpace #68) registers them as separate windows. How should Pickers treat them? Decide whether a tab group shows as one entry or one entry per tab, whether that's a grouping option on the Picker binding (a `tab group` mode next to window and app), how the group is identified (shared `AXTabGroup` element identity plus same-frame siblings; see §3 of [the tab research](../research/18-reading-app-tabs.md)), what thumbnails background tabs get (the inherited blank-tile problem), and whether these windows fill `w.tabs` for Filters. Probe 1 in the probes task confirms the starting behaviour.
