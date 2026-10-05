# A fresh guest stages the desk with no first-run screens

Part of {{UMBRELLA}}.

## What to build

The staged desk was dressed once, by hand, in one guest. In a fresh clone of the golden image the set's apps each open on a screen of their own the first time, and each needed a click:

- **Zed**: "Unrecognized Project", with a "Trust and Continue" button, on first opening a folder.
- **Ghostty**: a "Dock Tile Extension Added" notification that stays on screen.
- **Notes**: a "Welcome to Notes" sheet, then a "Turn On iCloud" dialog.

Later live runs in fresh clones met more, from macOS and from Ghostty:

- **macOS**: a Tips card; calendar, weather and photos widgets on the desktop, although the recipe already sets `StandardHideWidgets`; and a "Click Wallpaper to Show Desktop Items" tip the first time the wallpaper is clicked.
- **Ghostty**: an "Enable Automatic Updates?" prompt.
- **Notifications** in general: every run so far has turned Do Not Disturb on by hand first.

The relay films every pull request in a fresh clone, so each of these lands in a demo or blocks the stage script. This issue makes `stage-desk.sh` on a fresh clone end on the dressed desk and nothing else.

## Decisions

- The fix lives in the recipe, not in a guest: `.claude/skills/vm/guest/provision.sh` for what can be settled when the image is built, and `.claude/skills/demo/desk/stage-desk.sh` for what has to happen at staging time.
- A setting beats a click. A screen is dismissed by clicking only when no preference, file or grant prevents it, and the script then waits for the screen and checks it is gone.
- The proof is a fresh clone. The guest named `demo-set`, where the screens were already clicked, proves nothing.
- The golden image is rebuilt from the recipe as part of this issue. The preflight and `make check` pass in a clone of the new image before the old image is deleted.
- The guest still holds no credential and signs in to nothing. Notes keeps its notes in "On My Mac".

## Not in this issue

- **Calendar and Music on the set, a grievance struck out, and a `render` width** covers the two apps not yet on the set.
- A newer base image. `ghcr.io/cirruslabs/macos-tahoe-xcode:26.3` stays: Xcode 27 cannot build WinMux.
- Any change to WinMux.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **Zed.** Try its settings first, in the `settings.json` the desk already copies in; Zed has had more than one way to trust a project, so check the installed version's.
- **Ghostty.** Turn the notification off for Ghostty in the image, or keep the extension from being offered. `stage-desk.sh` already kills NotificationCenter twice; a banner that survives that needs the setting.
- **Tips, widgets and the wallpaper tip.** Settle each with a preference in the image; find why `StandardHideWidgets` does not hide the widgets in a clone. The wallpaper tip is dismissed once in the image if no preference records it.
- **Ghostty's update prompt.** Set its auto-update option in the config the desk already copies in.
- **Do Not Disturb.** The image has it on, or a Focus that silences every banner, so no run turns it on by hand.
- **Notes.** Launch it once during the image build, dismiss its two screens there, and quit it, so the image carries the dismissed state. If the state does not survive into a clone, find the preference that records it.
- **Clicks as the last resort.** At 1280 × 720 the buttons were at: Notes "Continue" 1199,648; Notes "Turn On iCloud" Cancel 1024,430. At 1680 × 720: Zed "Trust and Continue" 672,381; the Ghostty banner's close button 1322,50, shown only while the pointer is over the banner. Find a button by its accessibility label rather than by these numbers where that works.
- **Keeping the old image.** Rename `winmux-golden` aside before the rebuild and delete it once the new one passes.
- **A preflight for the set.** `vm up` gains nothing; the check belongs to `stage-desk.sh`, which ends by listing the windows on the desk and fails when one is not the set's.

## Done when

- [ ] In a fresh clone of the rebuilt golden image, `stage-desk.sh` runs to the end with no input and exits 0.
- [ ] A screenshot of each workspace of that clone, taken straight after, shows Zed and Ghostty on workspace 1 and Safari and Notes on workspace 2, with no sheet, dialog, banner, prompt, Tips card, widget or trust screen.
- [ ] Clicking the wallpaper in that clone shows no tip, and a notification posted in it shows no banner.
- [ ] `winmux list-windows --all` in that clone lists the four set windows and nothing else.
- [ ] Run a second time in the same clone, `stage-desk.sh` gives the same result.
- [ ] The rebuilt image passes the `vm` preflight and `vm check` in a fresh clone.
- [ ] The `vm` and `demo` skills say what the recipe now handles, and no longer leave a first-run screen to the reader.

## Sources

- Pull requests [#34](https://github.com/prateek/winmux/pull/34) and [#36](https://github.com/prateek/winmux/pull/36).
- [`.claude/skills/vm/SKILL.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/vm/SKILL.md) and [`.claude/skills/demo/SKILL.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/demo/SKILL.md)
