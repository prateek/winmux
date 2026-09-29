# Research: how WinMux sees Accessory app windows

Type: research
Status: resolved

## Question

Does WinMux's AX observation discover windows belonging to Accessory apps (LSUIElement; e.g. Ghost Pepper, `com.github.matthartman.ghostpepper` Prateek can't find in cmd+tab)? Trace app discovery (`MacApp.swift`, `GlobalObserver.swift`, `MacosUnconventionalWindowsContainer.swift`, window-detected callbacks): which activation policies are observed, how such windows are classified (tiled, floating, 'unconventional', ignored), and what attributes are available to tell them apart (activation policy, AX subrole, window level). Deliverable: current behaviour, and what it would take for a Filter to match 'all floating windows' including Accessory app windows.

## Answer

- WinMux scans only `.regular` apps. An Accessory app is registered, and its windows seen, only after it has been frontmost once (clicking one of its windows does it). Registration lasts until the app quits. An Accessory app that never activates is invisible.
- Accessory windows without a close button are classified as popups. They live outside every workspace, so the switcher, `list-windows`, and `on-window-detected` never see them.
- Other Accessory windows get the normal heuristics: floating if the subrole isn't `AXStandardWindow` or there's no enabled fullscreen button, otherwise tiled.
- Filters can't use activation policy, AX subrole, or window level today. Only `debug-windows` shows them.
- To make "all floating windows including Accessory apps" work: register Accessory apps proactively (all of them, or only those owning on-screen CG windows), decide whether popups are visible to Pickers, and expose those attributes to Filters.
- Ghost Pepper is `com.github.matthartman.ghostpepper`, with `LSUIElement=true`.

[findings](../research/02-accessory-app-windows.md)
