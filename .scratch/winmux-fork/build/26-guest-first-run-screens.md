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
- The golden image is rebuilt from the recipe as part of this issue. The preflight, `make check` and every desk check pass in fresh clones of `winmux-golden-next` while the old image stays in place. Only then is the old image renamed to `winmux-golden-prev` and the passing image to `winmux-golden`; the driver deletes the previous image at Land.
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
- **Ghostty.** Changed: initialize Ghostty in the image and dismiss the system Dock tile registration notice through its labelled Close button. This notice is a Login Items system alert, survives Notification Center restarts and is not controlled by Ghostty's notification preference. Clones inherit the completed registration.
- **Tips, widgets and the wallpaper tip.** Settle each with a preference in the image; find why `StandardHideWidgets` does not hide the widgets in a clone. The wallpaper tip is dismissed once in the image if no preference records it.
- **Ghostty's update prompt.** Changed: neither desk copies a Ghostty config. Set `auto-update = off` in the image's `~/.config/ghostty/config` before its initialization launch. Both desks inherit it.
- **Do Not Disturb.** The image has it on, or a Focus that silences every banner, so no run turns it on by hand.
- **Notes.** Changed: launch Notes once to initialize On My Mac, quit it, then write `hasShownWelcomeScreen`, `bypassICloudAlert` and `lastShownStartupVersion-1` into its initialized container preferences. The version is the guest OS version.
- **Clicks as the last resort.** At 1280 × 720 the buttons were at: Notes "Continue" 1199,648; Notes "Turn On iCloud" Cancel 1024,430. At 1680 × 720: Zed "Trust and Continue" 672,381; the Ghostty banner's close button 1322,50, shown only while the pointer is over the banner. Find a button by its accessibility label rather than by these numbers where that works.
- **Keeping the old image.** Changed by the driver: build `winmux-golden-next` beside the old image, prove it in fresh clones, then rename the old image to `winmux-golden-prev` and the new image to `winmux-golden`. Keep the previous image until Land.
- **A preflight for the set.** Changed by the driver: the desk check belongs to `stage-desk.sh`: require exactly one window per set app, inspect both workspaces through CoreGraphics and AX, and recognize first-run text rendered inside Zed's window. Name a stranger and exit non-zero. `vm up` also fixes the separate stopped-guest regression: require the golden image only when cloning.

## Done when

- [x] In a fresh clone of the rebuilt golden image, `stage-desk.sh` runs to the end with no input and exits 0.
- [x] A screenshot of each workspace of that clone, taken straight after, shows Zed and Ghostty on workspace 1 and Safari and Notes on workspace 2, with no sheet, dialog, banner, prompt, Tips card, widget or trust screen.
- [x] Clicking the wallpaper in that clone shows no tip, and a notification posted in it shows no banner.
- [x] `winmux list-windows --all` in that clone lists the four set windows and nothing else.
- [x] Run a second time in the same clone, `stage-desk.sh` gives the same result.
- [x] The rebuilt image passes the `vm` preflight and `vm check` in a fresh clone.
- [x] The `vm` and `demo` skills say what the recipe now handles, and no longer leave a first-run screen to the reader.

## Recipe

- Zed: `session.trust_all_worktrees` in the desk's copied `zed/settings.json`, verified against the installed release's default settings.
- Ghostty updates: `auto-update = off` in `guest/first-run.sh`; `window-save-state = never` and quitting its lowercase `ghostty` process prevent its initialization window returning at clone login.
- Dock tile notice: launch Ghostty once in the image; `guest/dismiss-registration.swift` waits for the notice, hovers its AX frame to expose the labelled Close button, presses it and verifies the notice disappeared. No fixed coordinate is used.
- Notes: local-account initialization, then `hasShownWelcomeScreen`, `bypassICloudAlert` and the current OS in `lastShownStartupVersion-1`, in its initialized container preferences (`guest/first-run.sh`).
- Widgets: clear Notification Center's saved widget instances, in addition to both WindowManager hide settings. The hide setting alone preserves instances that can return on desktop reveal.
- Wallpaper: `EnableStandardClickToShowDesktop = false`.
- Tips and notifications: Do Not Disturb's persisted date-interval assertion in `guest/quiet-desktop.py`, with intelligent breakthrough disabled; `TipsEnabled = false` is also set. The notification proof uses already-granted System Events and verifies a delivered record.

Decided: Use CoreGraphics for banners/widgets, AX for sheets and dialogs, and Vision text recognition for first-run screens rendered inside Zed's normal window.
Decided: Trust all worktrees only in the disposable, credential-free guest, using Zed's `session` settings section shared by both desks.
Decided: Persist the observed Focus date-interval format through 2099; posting through granted System Events needs no new permission.
Decided: Serve the standing desk's docs at localhost so Safari does not show a home path.
Decided: Keep the base image and both app sets unchanged; check the fourteen-window set at 1920 × 1080 as well.

## Validation

Host and fresh-clone `make check` pass (59 helper tests, 954 Swift tests and 65 script tests); the guest uses Swift 6.2.4. The standing desk runs twice without input, exits 0 both times and lists only Zed/Ghostty on workspace 1 and Safari/Notes on workspace 2. Full-screen captures after each run show no first-run UI. A wallpaper click shows no tip; a notification posted through granted System Events is delivered without a banner at 0.5, 2 and 5 seconds.

The image was built beside the old image. Fresh-clone checks exposed Ghostty's lowercase process and Notes' sandbox/version gating before the passing rebuild. After review the recipe changed once more (a resumed image build skips the Dock tile step, and the desk check gained its grant, dialog, desktop-element and docs-page checks), and the image was rebuilt from the final recipe and proved the same way. The old image was kept as `winmux-golden-prev` until the issue landed.

The unchanged rich script has a separate staging limitation: its first cold run can miss the separate Lenses Safari window, and retries can create an extra plain Ghostty terminal and report Column placement errors. Wait and rerun it; the live report records each result and any CLI dismissal of that extra terminal. These are not first-run screens. No app was added and the script was not redesigned.

## Sources

- [Zed 1.22.0 default settings](https://github.com/zed-industries/zed/blob/v1.22.0/assets/settings/default.json) (`session.trust_all_worktrees`).
- Pull requests [#34](https://github.com/prateek/winmux/pull/34) and [#36](https://github.com/prateek/winmux/pull/36).
- [`.claude/skills/vm/SKILL.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/vm/SKILL.md) and [`.claude/skills/demo/SKILL.md`](https://github.com/prateek/winmux/blob/fork/.claude/skills/demo/SKILL.md)
