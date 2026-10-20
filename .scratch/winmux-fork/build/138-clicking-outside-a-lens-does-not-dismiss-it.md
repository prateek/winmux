# Clicking outside a Lens does not dismiss it

Part of {{UMBRELLA}}.

## What to build

With `overview` open, a click on the desktop or on a window outside the panel leaves the Lens open. Every native overlay, Mission Control, Spotlight, the app switcher, closes on a click outside it. Prateek hit it on his first day with the overview and expects the native behaviour.

## Decisions

- **A click outside an open Lens's panel closes the Lens** and the click goes through to what was under it, so a click on a window both dismisses and focuses.
- **It applies to every Presentation**, grid, list, strip, miniatures and an arrangement, and to every mode: a click outside closes the Lens and leaves the mode as **Modes are the only modality** says closing does, ending in `main`; a held mode's `on-release` does not run after it.
- **A click on the sidebar while a Lens is open** closes the Lens and reaches the sidebar.

## Depends on

Nothing.

## Defaults chosen for you

- **A drag that starts outside the panel** closes the Lens on mouse-down, not on release.

## Done when

- [ ] A test with a staying Lens open and a click outside its panel shows the session closed and the click delivered.
- [ ] In a guest, `overview` and `windows` each close on a click on the desktop and on a click on another window, which then has focus.
- [ ] `docs/lenses.md` says so under "Release and appearance".

## Sources

- #268, "Clicking outside the overview doesn't dismiss it".
