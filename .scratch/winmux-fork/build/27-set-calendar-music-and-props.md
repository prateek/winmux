# Calendar and Music on the set, a grievance struck out, and a `render` width

Part of {{UMBRELLA}}.

## What to build

The set has four apps: Zed, Ghostty, Safari and Notes. Its plan has two more, and one running gag that nothing performs yet. This issue adds them, and one option the demo renderer lacks.

- **Calendar**, showing one day. It raised its own permission prompt ("would like to add to your Calendar") and then hung on its first-run screens under AppleScript.
- **Music**, with a track name in the mini player. It has not been tried.
- **The struck-out grievance.** The Grievances note is a numbered list, and a demo that fixes a grievance is meant to end with that line struck out. Nothing edits the note between takes.
- **`render` at another width.** `.claude/skills/demo/render` has `WIDTH = 960` fixed.

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
- **Music's tracks.** Short silent audio files made with `ffmpeg`, tagged with the album and track names, added to the local library by script. No Apple Music account.
- **How the props are called.** A script beside `stage-desk.sh`, such as `desk/props calendar` and `desk/props music`, which opens the app, fills it and leaves its window on the focused workspace.
- **Striking a line.** `desk/strike <n>` rewrites the Grievances note with line `n` struck out, and `desk/strike reset` restores it. The lines are numbered 1 to 5 in `props.applescript`.
- **The width.** `render --width <pixels>`, default 960.

## Done when

- [ ] In a fresh clone of the golden image, the Calendar prop opens Calendar on a day holding the four events, with no prompt and no first-run screen. A still shows it.
- [ ] In the same clone, the Music prop shows the mini player with a track from the album. A still shows it.
- [ ] Or, for either app, the pull request explains why it resisted and a still shows its lines in Zed.
- [ ] `desk/strike 1` strikes out the first grievance and leaves the other four as they were; `desk/strike reset` restores the note. A demo shows the line being struck after a take.
- [ ] `render --width 1280` writes a 1280-wide card and refuses one over 8 seconds or 3 MB; `render` with no width writes 960.
- [ ] `stage-desk.sh` still ends on the same four windows.
- [ ] The `demo` skill documents the props, `strike` and `--width`.

## Sources

- The set bible: the lines above are its Calendar and Music entries.
- Pull request [#34](https://github.com/prateek/winmux/pull/34), which added the set.
- [`.claude/skills/demo/SKILL.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/demo/SKILL.md)
