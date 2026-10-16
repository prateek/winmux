# A macOS Tips banner can appear on a guest's desktop

Part of {{UMBRELLA}}.

## What to build

While building **A long guest session raises the private-picker prompt**, a fresh clone of the golden image showed the macOS Tips notification "See what's new in macOS Tahoe" in the top-right corner of the desktop, about an hour into the session. It is not a permission prompt and asks nothing, but it sits over whatever a take films, and the preflight's `clean desktop` line does not catch it, since notifications are drawn by Notification Center, which the preflight counts as furniture.

The image already persists Do Not Disturb through 2099 (`guest/first-run.sh`), and the banner showed anyway.

## Decisions

- **A fresh clone never shows it.** The image recipe settles the Tips app's notifications, as it settles Notes, widgets and Ghostty's update prompt.
- **No click at run time.** The fix is a setting written when the image is built.

## Not in this issue

- **Three screens a fresh guest still shows**, which covers Zed's and Ghostty's screens.
- Permission prompts.

## Depends on

Nothing.

## Defaults chosen for you

- **The setting.** Turn off notifications for the Tips app (`com.apple.tips`) in the image, and mark its welcome as shown, if macOS keeps such a flag. Check what the banner's owner is before choosing.

## Done when

- [ ] In a fresh clone of a rebuilt image, a session of at least two hours shows no Tips banner, checked by a watcher over every window layer.
- [ ] The preflight still passes, and both desks stage.

## Sources

- The builder's report for **A long guest session raises the private-picker prompt**, 2026-10-16, with a screenshot of the banner beside the reproduced private-picker dialog.
