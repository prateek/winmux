# Grilling: default handling of floating and Accessory app windows

Type: grilling
Status: open
Blocked by: 02, 12

## Question

Beyond making them findable through a Filter, should WinMux change how floating and Accessory app windows behave by default? For example: float Accessory apps automatically, remember their positions, keep floaters visible across workspace switches, or re-place them on a Display profile switch. Decide the minimum, given what the Accessory-app research shows.

Sub-questions surfaced by the Accessory-app research:
- Should Accessory windows float by default? Today one with a standard subrole and an enabled fullscreen button gets tiled.
- How are Accessory apps registered: all of them (an AX observer per menu-bar app), or only those that own an on-screen window in the CG window list at scan time? Should activation-policy changes at runtime be watched?
- Should popup-classified windows (Accessory windows with no close button) be reachable at all, and if so, only through an opt-in on the Filter?

Partly settled by [Prototype: filter language worked examples](06-prototype-filter-language.md): popup-classified windows are reachable, as the `accessory-popup` and `app-popup` window classes, and Pickers drop them unless a Filter mentions them. `floating` keeps today's meaning.
