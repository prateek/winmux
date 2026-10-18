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

No decisions were settled before the build. The built defaults and departures below record the relay's choices.

## Not in this issue

- Notarizing, which removes the Gatekeeper step: **Sign dogfood builds with the Developer ID and notarize them**.
- The Cmd-Tab default: **The system's Cmd-Tab stays the system's unless the config asks for it**.
- Putting windows back on quit: **Quitting WinMux puts windows back where they were**.

## Depends on

- **The system's Cmd-Tab stays the system's unless the config asks for it**.
- **Quitting WinMux puts windows back where they were**.

## Defaults chosen for you

- **A first-run window** requires Accessibility and offers a saved choice to continue without Screen Recording. It shows each permission's live state, requests registration before opening the right System Settings pane, and relaunches WinMux itself when needed. An existing install with Accessibility alone sees this window once, until Screen Recording is granted or declined.
- **Before the first tile**, the window says that WinMux will arrange the windows on screen and that quitting puts them back, and waits for a click.
- **The CLI with the app half set up** says which permission is missing instead of "Can't connect".
- **The cask's caveats** say only what is still true.
- **An independent bundle with no grants** is the test bed in an ordinary guest: LaunchServices gives the debug bundle its own identity instead of inheriting ssh's grants. The `vm` skill documents packaging, launch, recording and reset; no new image is needed.

## Built behavior and checks left

Setup runs after config loading and socket startup, before observers, workspaces or
window discovery. Its pending marker and optional Screen Recording decline share
one XDG state file. Only Start clears pending and allows window arrangement.
During setup, config queries and the version handshake work without a window
refresh; other commands and subscriptions return an actionable refusal. Help
and parse errors retain their existing answers. `config status` always names
both live grants and the setup state. `doctor` already names both grants.

No hotkey is registered until Start, so every chord, a configured Cmd-Tab
takeover included, reaches the system during setup. Shipped shortcut defaults
remain unchanged. The go text follows `restore-windows-on-quit`.

The cold bundled guest run registers both native permission rows and uses the
real toggles and password sheets, with no TCC database writes. A fresh child
reads a Screen Recording grant the parent cannot yet use. Both WinMux's relaunch
and macOS's Quit & Reopen return at go, since the pending marker is in the
state file the reopened process reads. macOS's reopen drops launch options and
an `open --env` environment, so a take with its own XDG directories sets them
with `launchctl setenv` in the GUI session's launchd domain. The sidebar also waits for Start. Host and pinned-version guest checks cover these paths.

- [ ] Installed, downloaded/quarantined build and Gatekeeper first launch.
- [ ] Second display and real sleep, wake or unlock.

## Done when

- [x] On a guest with no grants, a person reaches a tiled desktop from the first launch using only what WinMux shows them, filmed. Both permissions are registered and granted natively; the supported Screen Recording decline is also checked.
- [x] With one permission missing, `winmux config status` names it.
- [x] No window moves before the person says go. Independent CG frame samples of all four staged application windows agree before launch and after 22 seconds at each setup step, including after relaunch and quit-before-go; they change after Start.

## Sources

- The install on Prateek's daily machine, 2026-10-06, and his note: "make onboarding not suck".
