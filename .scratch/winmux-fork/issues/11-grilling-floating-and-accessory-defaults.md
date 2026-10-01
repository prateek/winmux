# Grilling: default handling of floating and Accessory app windows

Type: grilling
Status: resolved
Blocked by: 02, 12

## Question

Beyond making them findable through a Filter, should WinMux change how floating and Accessory app windows behave by default? For example: float Accessory apps automatically, remember their positions, keep floaters visible across workspace switches, or re-place them on a Display profile switch. Decide the minimum, given what the Accessory-app research shows.

Sub-questions surfaced by the Accessory-app research:
- Should Accessory windows float by default? Today one with a standard subrole and an enabled fullscreen button gets tiled.
- How are Accessory apps registered: all of them (an AX observer per menu-bar app), or only those that own an on-screen window in the CG window list at scan time? Should activation-policy changes at runtime be watched?
- Should popup-classified windows (Accessory windows with no close button) be reachable at all, and if so, only through an opt-in on the Filter?

Partly settled by [Prototype: filter language worked examples](06-prototype-filter-language.md): popup-classified windows are reachable, as the `accessory-popup` and `app-popup` window classes, and Lenses drop them unless a Filter mentions them. `floating` keeps today's meaning.

Sub-questions surfaced by [Task: live check of Ghost Pepper's windows under WinMux](12-task-live-check-ghost-pepper.md):
- Ghost Pepper is `regular` whenever it has a window, so WinMux already registers and floats its windows. What Prateek can't do is reach a floater buried behind tiles. Is a Lens over floating windows the whole fix for this app, or does a default have to change too?
- How does a Filter say "window of an Accessory app" when the activation policy reads `regular` at the moment the window exists? `CONTEXT.md` already defines an Accessory app by `LSUIElement`, so the Filter contract ([Grilling: the Filter contract's final field list](33-grilling-filter-contract-field-list.md)) needs a field derived from the bundle's `LSUIElement`, next to or instead of the live activation policy.
- Is proactive registration still worth building when the one app that prompted it doesn't need it? No app that shows windows while staying `accessory` has been tested.

## Answer

Resolved 2026-09-30 with Prateek. The minimum: floaters keep today's behaviour, and a Lens makes them reachable.

- **Floater behaviour is unchanged.** No remembered positions and no staying visible across workspace switches. The live check showed the problem is a floater buried behind tiles, which a Lens solves.
- **A default `floating` Lens.** The default config ships a `floating` Lens: Filter on the floating Window class across all workspaces, `'list` Presentation, enter to focus, shift-enter to Summon. It ships unbound, like `search`, until default Triggers are decided.
- **Accessory app windows float.** A window of an Accessory app that would be tiled today (standard subrole, enabled fullscreen button) floats by default. The `arrive` hook can override it.
- **No proactive registration.** WinMux keeps upstream's behaviour: an app that is Accessory at the time is registered once it has been frontmost. Ghost Pepper doesn't need more, and no app that shows windows while staying Accessory has turned up. Revisit when one does.
- **Two Filter fields.** `a.accessory` is a boolean read from the bundle's `LSUIElement` and never changes while the app runs. `a.activationPolicy` is the live value (`'regular`, `'accessory`, `'prohibited`). "Windows of Accessory apps" is `w.app.accessory`. Both go into [Grilling: the Filter contract's final field list](33-grilling-filter-contract-field-list.md).
- **accessory-popup follows the live policy**, as upstream does: a close-button-less window is an accessory-popup only while its app has no Dock icon. Ghost Pepper's modal dialog therefore stays floating and stays in Lenses, because the app is `regular` while it's open. Hiding a dialog that needs an answer is the worse failure. `CONTEXT.md` now says so under Window class and Accessory app.
