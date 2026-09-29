# Prototype: filter language worked examples

Type: prototype
Status: open

## Question

Which filter language should WinMux use: expression strings in `winmux.toml` or JavaScript predicates run by JavaScriptCore (current lean)? Write the same set of real Filters in both, and react to them together before choosing. Cover at least: current project; everything; all floating windows (including Accessory apps); same app as the focused window except itself; floating windows of the app under the mouse; windows on the current monitor in the ultrawide Display profile only; a named app list minus exclusions; the previously focused window first. Explore the implications: composition and reuse, error messages, how the Filter context is exposed, and how a Picker binding references a Filter.

From the Accessory-app research: "floating" today means "the window's parent is a workspace". The examples must decide whether it also covers popup-classified and never-registered windows, and should expose activation policy, AX subrole, window level, close-button presence, and WinMux's classification (tiled, floating, fullscreen, minimized, hidden-app, popup) as window attributes.

From the monitor-identity research: the Filter context should carry a monitor descriptor (UUID, built-in flag, name), not just an index, so filters can target a display reliably.
