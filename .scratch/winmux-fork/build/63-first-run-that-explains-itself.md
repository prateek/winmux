# A first run that explains itself

Part of {{UMBRELLA}}.

## What to build

Prateek's first install on his daily machine took an agent, a handoff note and several round trips. What went wrong, in order:

- Gatekeeper blocked the app and the cask's printed steps did not work.
- WinMux needs Accessibility and Screen Recording, says so nowhere, and needs a quit and relaunch after they are granted. With only one granted, the app ran and the CLI answered "Can't connect to WinMux server".
- The first launch re-tiled every window with no warning.
- It replaced the system's Cmd-Tab unasked.

This issue is the note to fix that as one experience, once the pieces it leans on have landed.

## Decisions

None yet. Prateek asked for a follow-up issue; the shape below is a starting point.

## Not in this issue

- Notarizing, which removes the Gatekeeper step: **Sign with the Developer ID and notarize**.
- The Cmd-Tab default: **The system's Cmd-Tab stays the system's unless the config asks for it**.
- Putting windows back on quit: **Quitting WinMux puts windows back where they were**.

## Depends on

- **The system's Cmd-Tab stays the system's unless the config asks for it**.
- **Quitting WinMux puts windows back where they were**.

## Defaults chosen for you

- **A first-run window** shown until both permissions are granted: each permission with its live state, a button that opens the right pane of System Settings, and no need to quit and relaunch by hand.
- **Before the first tile**, the window says that WinMux will arrange the windows on screen and that quitting puts them back, and waits for a click.
- **The CLI with the app half set up** says which permission is missing instead of "Can't connect".
- **The cask's caveats** say only what is still true.
- **A fresh guest with no grants** is the test bed: the `vm` skill's image grants them, so this issue needs a way to bring a guest up without them.

## Done when

- [ ] On a guest with no grants, a person reaches a tiled desktop from the first launch using only what WinMux shows them, filmed.
- [ ] With one permission missing, `winmux config status` names it.
- [ ] No window moves before the person says go.

## Sources

- The install on Prateek's daily machine, 2026-10-06, and his note: "make onboarding not suck".
