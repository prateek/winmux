# A long guest session raises the private-picker prompt

Part of {{UMBRELLA}}.

## What to build

The golden image writes a ScreenCaptureKit approvals file (`guest/grant.sh`) so that recording over ssh never asks. In a long session it asks anyway: macOS shows "bypass the system private window picker" and waits for a click. It has appeared three times.

- For `com.apple.sshd-session`, in a builder's guest after a reboot and several hundred captures.
- For `WinMuxApp`, a debug build, at the end of a two-hour guest session.
- For `tart-guest-agent`, when a builder took a screenshot through Tart's guest agent and not over ssh.

Nobody granted it. A fresh guest has not shown it, so every driver works around it by bringing up a new guest to film. A prompt that nothing dismisses stops a live run, and a builder cannot tell a defect in the image from a defect in WinMux.

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

- [ ] The pull request states what makes the prompt appear, with the run that showed it, or the bound within which it could not be made to appear.
- [ ] A guest that has taken 1,000 captures over ssh and been rebooted records again with no prompt.
- [ ] A debug `WinMuxApp` left running for two hours with a Lens opened every minute raises no prompt.
- [ ] The preflight fails on a guest whose approvals file is missing.

## Sources

- Pull requests [#80](https://github.com/prateek/winmux/pull/80), [#81](https://github.com/prateek/winmux/pull/81) and [#82](https://github.com/prateek/winmux/pull/82), under **Seen on the way** and in their handoffs.
