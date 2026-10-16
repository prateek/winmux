# Staging the standing desk raises Python's local-network prompt

Part of {{UMBRELLA}}.

## What to build

While filming the demos for **`close` reports success on a window with no close button, and the strip drops its entry**, staging the standing desk in a guest that had been up for about an hour raised the macOS dialog "Allow “Python” to find devices on local networks?" over the desk. `desk/stage-desk.sh` serves `docs/lenses.md` to Safari with `python3 -m http.server 8765 --bind 127.0.0.1`, so the server is already loopback-only, and macOS 26 asked anyway. The dialog was left unanswered. Stopping the docs server and closing UserNotificationCenter cleared it, and Safari kept the page it had already loaded.

A demo pass that meets it has to stop, and a take filmed under it is lost. The preflight's `clean desktop` line runs before staging, so it cannot catch it.

## Decisions

- **No permission is granted or denied at run time.** The fix is in the image recipe or in how the desk serves its page.
- **Safari still shows `docs/lenses.md` on workspace 2**, with the same title, so the standing set's four windows do not change.

## Not in this issue

- **A macOS Tips banner can appear on a guest's desktop**, which is a notification, not a permission prompt.
- WinMux's own permission prompts.

## Depends on

Nothing.

## Defaults chosen for you

- **The fix.** First, find out whether the image can settle Local Network access for the guest's `python3` when it is built, as it settles TCC grants. If it can't, serve the page without a listening socket: open it in Safari from a `file://` URL, keeping the title the set checks for.

## Done when

- [ ] In a fresh clone of the rebuilt image, staging the standing desk ten times in a row, with the guest up for over an hour before the last run, raises no local-network prompt, checked by a watcher over every window layer.
- [ ] Both desks still stage, and the preflight still passes.

## Sources

- The demo pass for **`close` reports success on a window with no close button, and the strip drops its entry**, 2026-10-16, with a screenshot of the dialog over the staged desk.
