# Calendar and Music on the set, a grievance struck out, and a `render` width

Part of {{UMBRELLA}}.

## What to build

The set has four apps: Zed, Ghostty, Safari and Notes. Its plan has two more, and one running gag that nothing performs yet. This issue adds them, and one option the demo renderer lacks.

- **Calendar**, showing one day. It raised its own permission prompt ("would like to add to your Calendar") and then hung on its first-run screens under AppleScript.
- **Music**, originally with a track name in the mini player. Its cold-library welcome resisted the image recipe, so the prop uses the allowed Zed fallback.
- **The struck-out grievance.** The Grievances note is a numbered list, and a demo that fixes a grievance is meant to end with that line struck out. `desk/strike` now edits the note between takes.
- **`render` at another width.** `.claude/skills/demo/render` had `WIDTH = 960` fixed.

## Decisions

- Every word on screen is ours, and the lines are these.
  - Calendar, one day: `9:00 Standup (floating, do not tile)`, `11:00 A meeting that could have been a window`, `2:00 Display changes resolution for no reason`, `4:30 Yell at the Dock`.
  - Music: the album *Seven Windows You Can't Tile*, with the tracks "Fullscreen Is a Cry for Help" and "I Don't Have a Problem, You Have a Layout".
- The register is the exasperated rant and the pedant picking at soft language, about windows and desktops. The lines stay clean: the repository is public. What WinMux is shown doing is never part of the joke.
- The apps are real. Calendar and Music run in the guest and are filled by script; neither signs in to anything, and Calendar's events live in a local calendar.
- An app that resists gets its lines moved to a text file open in Zed, and the pull request says which app and why. That is a finished issue, not a failed one.
- Calendar and Music are props for the demos that want them. The standing set that `stage-desk.sh` dresses stays four windows on two workspaces, so existing storyboards keep working.
- A demo is still at most 8 seconds and 3 MB at any width. 960 stays the default and is the width for a pull request's demos.

## Not in this issue

- **A fresh guest stages the desk with no first-run screens** covers the first-run screens of the four apps already on the set.
- **Hero demos in the README and the docs** films with these props.
- The Finder window of `stuff`. Its files are in the desk already and no demo has needed the window.

## Depends on

- A fresh guest stages the desk with no first-run screens

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Grants.** Guests have SIP off, so `guest/grant.sh` and `guest/automation.sh` write rows straight into the TCC database during the image build. Add Calendar access and the Automation rows for Calendar and Music the same way, and rebuild the image.
- **Calendar's first run.** Handle it as the first-run issue handles Notes.
- **Music's tracks.** The allowed fallback: album, artist and both track names in `desk/Music.txt`, opened in Zed. Tagged silent AACs were tried; Music still showed its cold-library welcome in fresh clones.
- **How the props are called.** A script beside `stage-desk.sh`, such as `desk/props calendar` and `desk/props music`, which opens the app, fills it and leaves its window on the focused workspace.
- **Striking a line.** `desk/strike <n>` rewrites the Grievances note with line `n` struck out, and `desk/strike reset` restores it. The lines are numbered 1 to 5 in `desk/grievance-lines.txt`, shared by `props.applescript` and `strike`.
- **The width.** `render --width <pixels>`, default 960.

## Build details

- `desk/props calendar` uses AppleScript to replace the local `Desk` calendar's events on the guest's today, switches to Day view and checks only Desk in Calendar's sidebar. The image initializes Calendar and sets a full-day range. The data-access requester observed in TCC is `/usr/libexec/sshd-keygen-wrapper`; its `kTCCServiceCalendar` row belongs in the user database, beside the Automation rows for Notes, Finder, System Events, Calendar and Music.
- `desk/props music` opens `desk/Music.txt` in a separate, reusable Zed workspace so the standing editor keeps its own tabs. Native Music imported two thirty-second silent AACs with the exact tags, showed the MiniPlayer and retained its name when paused after its welcome was dismissed during investigation. Its cold-library welcome nevertheless returned in fresh image clones with `whatsNewLevel = 2` and `showWelcomeScreenState = 2`; a separate `firstLaunchShowWelcomeScreenState = 2` experiment also failed. After two image builds and the bounded native-app investigation, the build uses the issue's finished fallback. The image keeps Music's Automation grant and local-library initialization, with no account.
- Both props float and size their one window, returning it to the workspace focused before the command. Restaging stops Calendar and Music and preserves the four-window standing set.
- `desk/grievance-lines.txt` supplies Notes staging and `desk/strike`; strike reads the note's current body to retain earlier strikes. `strike reset` restores the five lines. The rich set's `Grievances.txt` remains separate and unchanged.
- Width accepts even values from 320 to 1920 and scales geometry from the exact 960 baseline. Tests run with plain Python without Pillow or media tools; duration and size caps remain 8 seconds and 3 MB.
- Installed-build checks, a second display and real sleep/wake/unlock remain Prateek's. The builder publishes no release.

## Done when

- [x] In a fresh clone of the golden image, the Calendar prop opens Calendar on a day holding the four events, with no prompt and no first-run screen. A still shows it.
- [ ] In the same clone, the Music prop shows the mini player with a track from the album. A still shows it. **Native path not met; the allowed fallback below is complete.**
- [x] Or, for either app, the pull request explains why it resisted and a still shows its lines in Zed.
- [x] `desk/strike 1` strikes out the first grievance and leaves the other four as they were; `desk/strike reset` restores the note. A demo shows the line being struck after a take.
- [x] `render --width 1280` writes a 1280-wide card and refuses one over 8 seconds or 3 MB; `render` with no width writes 960.
- [x] `stage-desk.sh` still ends on the same four windows.
- [x] The `demo` skill documents the props, `strike` and `--width`.

## Verification

Host and fresh-clone `make check` pass: 1,257 Swift, 82 Rust/helper and 87 Python tests. The clone passes preflight on Swift 6.2.4 at 1280×720. Calendar and the Music fallback pass twice with focused-workspace readbacks; the standing set returns to four windows and its original editor. Native Notes bodies and the trace-recorder clip prove strike 1, retained 1/3, reset and unchanged body on invalid 9. Host rendering reads back 1280×806 and 960×604 GIFs; nine seconds and 3,000,001 bytes are refused. The exact default geometry matches `9bfda201` for both styles.

The rich set reaches fourteen windows with three/two Columns at the fixed display size. Its cold Safari failure and extra plain Ghostty terminal need the documented retry/cleanup. Repeating staging also exposed `Value is already destroyed` on Preview's AX thread; stopping the old debug app before Preview teardown allowed staging to pass. The runtime diagnostic is retained; its underlying WinMux defect is outside this tooling-only change. The system video recorder held stale/inconsistently timed frames, so the existing trace recorder supplies the strike clip. No permission was granted and no release was published. Final pull-request demos belong to the demo pass.

## Checks for Prateek

- [ ] Installed-build behavior.
- [ ] A second display.
- [ ] Real sleep, wake and unlock.

## Sources

- The set bible: the lines above are its Calendar and Music entries.
- Pull request [#34](https://github.com/prateek/winmux/pull/34), which added the set.
- [`.claude/skills/demo/SKILL.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/demo/SKILL.md)
