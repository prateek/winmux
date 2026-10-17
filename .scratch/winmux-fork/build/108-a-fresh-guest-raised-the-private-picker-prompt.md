# A fresh guest raised the private-picker prompt

Part of {{UMBRELLA}}.

## What to build

**A long guest session raises the private-picker prompt** renews replayd's approval for the ssh wrapper at boot, and the preflight checks its dates. The prompt still appeared in a guest about fifteen minutes after a fresh clone booted and passed preflight, during the live run of **A strip with one entry per app draws badly**: "com.apple.sshd-session is requesting to bypass the system private window picker and directly access your screen and audio."

At that moment `ScreenCaptureApprovals.plist` held one record, for `/usr/libexec/sshd-keygen-wrapper`, last used a few seconds earlier, last alerted at boot, with a 2099 privacy-hint date. The image's approval check passed with no output. The run was a debug WinMux started over ssh from a second source tree (`~/winmux-base`), beside the staged rich desk, taking `screencapture -x` stills; the debug build had been restarted once. A second fresh clone ran the same script on both trees and never showed the prompt.

**Reproduce:** not yet. The first guest's prompt screenshot, plist, process list and replayd and tccd logs are kept with the relay's state for that issue.

## Decisions

- No permission prompt is ever answered in a guest; the image settles it ahead of time.

## Not in this issue

- Long-session lapses, which the boot renewal covers.

## Depends on

Nothing.

## Done when

- [ ] The cause is named, or a run that reproduces it is written down with what it rules out.
- [ ] If it is the image, the golden image is rebuilt and the run passes in a fresh clone.

## Sources

- The builder's live run for **A strip with one entry per app draws badly**, 2026-10-17.
