# Task: live check of Ghost Pepper's windows under WinMux

Type: task
Status: resolved

## Question

With WinMux running, what does it actually see of Ghost Pepper (`com.github.matthartman.ghostpepper`)? Before and after clicking its menu-bar item, capture `winmux debug-windows` and `winmux list-windows --all`. Record whether its window is registered only after the app has been frontmost, and its subrole, window level, close-button presence and WinMux classification. This is HITL where it needs Prateek to open Ghost Pepper's window. It confirms or refutes the 'registered only after frontmost' claim before the defaults for floating and Accessory app windows are decided.

## Answer

The 'registered only after frontmost' claim is refuted for Ghost Pepper and confirmed for apps that stay Accessory. Ghost Pepper changes its activation policy: `accessory` while it has no window, `regular` from the moment a window opens, and `accessory` again when the last one closes. While it is `regular`, WinMux finds it like any Dock app. Checked 2026-09-30 on the Mac mini (macOS 26.4.1, one 1512×920 Jump Desktop display) with Ghost Pepper 2.4.4, first on Prateek's 0.51.0-dogfood.15 build and then on upstream 0.5.6 with its default config.

- **No window open:** Ghost Pepper is `accessory`, owns no on-screen CG window, and is absent from `list-apps` and `list-windows --all`. Restarting WinMux in this state leaves it unregistered (upstream).
- **Window open, app not frontmost:** WinMux was restarted with Orca frontmost and Ghost Pepper's window open. Ghost Pepper was in `list-apps`, and its window in `list-windows --all`, as soon as the server answered (upstream). Being frontmost is not needed.
- **Opening a window from the menu-bar item** made Ghost Pepper frontmost and `regular` within the same half-second sample in which WinMux listed the window (dogfood build; the live open wasn't repeated on upstream, where the window was already open at launch).
- **The window Prateek cares about** (he calls it the IDE view; untitled, resizable, 960×890 at first) has subrole `AXStandardWindow`, level `normalWindow`, enabled close, minimize and zoom buttons, and no fullscreen button. WinMux types it `dialog` and floats it on the focused workspace. The onboarding window ("Ghost Pepper") and "Ghost Pepper Settings" get the same classification.
- **A modal dialog** (`AXDialog`, level 8, no close button, 260×322) was also listed as floating. The no-close-button popup rule applies only to Accessory apps, and Ghost Pepper was `regular` at that moment (dogfood build).
- **Not seen by WinMux at all:** a full-screen layer-500 overlay and small layer-101 panels. `debug-windows --window-id` can't find them. Prateek doesn't need these findable, so they weren't chased further.
- `winmux close --window-id` closes the IDE view, and Ghost Pepper drops back to `accessory` within a few seconds. It was still in `list-apps` after that, until WinMux was restarted.

What this changes for the tickets waiting on it:

- Ghost Pepper's windows are already registered and floating in upstream WinMux, so a Filter on `floating` finds them today. The "can't find it" problem for this app is one of presentation (a floater hidden behind tiles, no Lens to reach it), not discovery.
- Proactive registration of Accessory apps still matters, but only for apps that show windows while staying `accessory`. No such app was tested here.
- Activation policy changes at runtime, so it can't identify "Accessory app windows" on its own: at the moment Ghost Pepper has a window, the policy reads `regular`. `LSUIElement` in the bundle's `Info.plist` is the stable signal.

The machine was changed to run this, at Prateek's request: Ghost Pepper installed from the upstream cask; WinMux switched from the `prateek/tap` dogfood cask to upstream 0.5.6 (`ZimengXiong/homebrew`, tap trusted, `xattr -cr` applied); the old config moved to `~/.config/winmux.dogfood-backup-20260930`; and a `winmux` CLI built from v0.5.6 copied to `/opt/homebrew/bin/winmux`, because the upstream cask ships only the app.

[probe scripts and captures](../prototypes/12-ghost-pepper-probe/)
