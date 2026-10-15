# A fresh guest can open with Ghostty running

Part of {{UMBRELLA}}.

## What to build

A guest cloned from the golden image should start on a clean desktop. Once, while building **Peek: see the selected window at full size before switching**, it did not: `vm up` on a fresh clone of `winmux-golden` printed `FAIL clean desktop: Ghostty`, and `pgrep` in the guest showed `/Applications/Ghostty.app/Contents/MacOS/ghostty` running at login, with no take or script of ours having started it. `vm down` and a second `vm up` from the same golden image passed the preflight. The same image had passed in a fresh clone earlier that day.

The `vm` skill makes a fresh guest's failed preflight a stop for the relay, so a transient like this one stops a relay that a retry would have let through. Ghostty's window restoration is disabled in the image; what started it at login was not found.

## Decisions

- **A fresh clone starts with no app of the sets running**, every time.
- **The preflight stays strict.** A guest that shows a stranger is not filmed in; the fix is in the image or in `up`, not in the check.

## Not in this issue

The private-picker prompt in a long guest session, which is its own issue, and the first-run screens of the sets' apps.

## Depends on

Nothing.

## Done when

- [ ] What starts Ghostty at login in a fresh clone is found, from the image's login items, launch agents and saved application state, and removed or disabled in `guest/provision.sh` or `guest/first-run.sh`.
- [ ] Twenty fresh clones in a row from a rebuilt image pass the preflight's clean-desktop check on their first `up`.
- [ ] If the cause cannot be removed from the image, `vm up` quits a stray app of the sets before the preflight and says so in its output, and the `vm` skill says when that happens.

## Sources

- `.claude/skills/vm/guest/preflight.swift`: the clean-desktop check.
- `.claude/skills/vm/guest/first-run.sh` and `guest/provision.sh`: Ghostty's settings in the image.
