# A long guest session raises the private-picker prompt

Part of {{UMBRELLA}}.

## What to build

The golden image writes a ScreenCaptureKit approvals file (`.claude/skills/vm/guest/grant.sh`) so that recording over ssh never asks. In a long session it asks anyway: macOS shows "bypass the system private window picker" and waits for a click. It has appeared three times.

- For `com.apple.sshd-session`, in a builder's guest after a reboot and several hundred captures.
- For `WinMuxApp`, a debug build, at the end of a two-hour guest session.
- For `tart-guest-agent`, when a builder took a screenshot through Tart's guest agent and not over ssh.

Nobody granted it. It also appeared about an hour into a fresh clone during a Peek demo pass, so a fresh clone is not a reliable workaround. The prompt stops a live run, and a builder cannot tell an image defect from a WinMux defect.

Find what makes the approval lapse and make the image settle it.

## Decisions

- **Reproduce it first**, in a fresh clone, by count of captures and by a reboot, for the ssh session and for a debug `WinMuxApp`. The pull request says which of the two triggers it, or that neither does within a stated bound.
- **The fix is in the image recipe**, not in a click at run time. If the approval expires by date or by count and cannot be made to last, the recipe renews it in the guest at `vm up`, and the skill says so.
- **`tart-guest-agent` gets no grant.** Every guest command goes through `vm ssh`; the builder brief says so.
- **The preflight checks it.** `vm up` fails a guest whose approvals are missing or lapsed, with a message that names the fix.

## Not in this issue

- The same prompt on an installed build on Prateek's machine. It appeared once in a guest after `brew upgrade`; it is one of his checks.

## Depends on

Nothing.

## Done when

- [x] The pull request states what makes the prompt appear, with the run that showed it, or the bound within which it could not be made to appear.
- [x] A guest that has taken 1,000 captures over ssh and been rebooted records again with no prompt.
- [x] A debug `WinMuxApp` left running for two hours with a Lens opened every minute raises no prompt.
- [x] The preflight fails on a guest whose approvals file is missing.

## Built

Replayd uses the responsible process's identity, an enclosing bundle identifier when available or its binary path. For all three ssh-launched capture paths the observed approval key is `/usr/libexec/sshd-keygen-wrapper`; the prompt's display name is a separate input. The existing key stays, and no guessed client or Tart guest-agent grant is added.

The pinned image's alert decision compares the last-use date with a 30-day interval. A 31-day-old last-use date reproduced the exact ssh-session prompt despite a 2099 hint date. A count of one million and an old last-alert date alone did not. Hint date and hint policy are separate: the hint date gates that reminder, while policy supplies its interval and day label. The historical long-session trigger remains unconfirmed. The bounded original-image run had 1,000 ssh captures, five verified minute-spaced Lens cycles and post-reboot recordings without a prompt.

The image recipe now renews the observed approval before `vm up` runs preflight. Renewal terminates replayd before an atomic write, preserves the usage count and unrelated entries, refreshes use/alert dates and keeps the hint in 2099. The shared Python validator backs the new `approvals` line and its actionable renewal/rebuild detail. Boot readiness uses ssh only; image transport skips generated directories. WinMux's Swift sources are unchanged.

In a fresh clone of the rebuilt image, the standing desk completed 900 stills and 100 one-second videos, all media-checked, beside 120 verified Lens opens/closes over two hours in one debug process. Both recorders worked after reboot without a prompt. Removing the approvals file produced `FAIL approvals` and exit 1; restoring it produced `ok approvals` and exit 0. The all-layer watcher detected the deliberately repeated 31-day date fault after capture 1, and boot renewal restored clean recording afterward. No permission dialog was answered.

Host and pinned-toolchain guest `make check` pass: 1,257 Swift, 82 helper and 99 Python tests each. Date-rule/count-preservation mutations are caught. Both desk sets were checked at the driver's 1280 by 720, without resizing. The fresh image uses the unchanged Tahoe/Xcode 26.3 base; its OS is macOS 26.2 (25C56), with Swift 6.2.4. A macOS Tips “See what's new” banner appeared during the deliberate fault run and was cleared; settling that notice remains an image-quietness follow-up. Installed-build and physical-device checks remain Prateek's; the builder publishes no release.

## Sources

- Pull requests [#80](https://github.com/prateek/winmux/pull/80), [#81](https://github.com/prateek/winmux/pull/81) and [#82](https://github.com/prateek/winmux/pull/82), under **Seen on the way** and in their handoffs.
- The [fresh-clone report](https://github.com/prateek/winmux/issues/87#issuecomment-6183923599) from the Peek demo pass.
