# Three screens a fresh guest still shows

Part of {{UMBRELLA}}.

## What to build

A builder working in a fresh clone of the golden image met three screens that are not WinMux's and that the image recipe does not settle. Each had to be dismissed by hand before a live run could go on.

- **Zed asks whether to trust a scratch folder** when a file outside the desk's trusted folders is opened.
- **Zed shows a promotion**, "Introducing Delta", on a first launch. It went away after Zed restarted.
- **Ghostty asks for confirmation before quitting** a window with a running shell.

## Decisions

- **A fresh clone shows none of the three.** The image recipe settles them, as it settles Notes, widgets and Ghostty's update prompt.

## Not in this issue

- A permission prompt for WinMux or for the tool driving it. That is **A long guest session raises the private-picker prompt**.

## Depends on

Nothing.

## Defaults chosen for you

- **Zed**: trust for the guest's home folder, or whatever setting covers a file opened from anywhere under it, and the setting that turns off first-run promotions if there is one. If there is none, say so and leave it.
- **Ghostty**: `confirm-close-surface = false` in the image's config.

## Done when

- [ ] In a fresh clone of a rebuilt image, opening a new text file in Zed from a scratch directory shows no trust screen and no promotion.
- [ ] Quitting Ghostty with a shell running asks nothing.
- [ ] The preflight still passes, and both desks stage.

## Sources

- The builder's reports while building **The system's Cmd-Tab stays the system's unless the config asks for it**, 2026-10-13.
