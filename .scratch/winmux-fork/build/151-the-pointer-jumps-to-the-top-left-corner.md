# The pointer jumps to the top-left corner

Part of {{UMBRELLA}}.

## What to build

Sometimes the pointer jumps to the top-left of the display. Prateek suspects the shipped `on-focused-monitor-changed` `move-mouse` interacting with a menu bar manager; there is no reproduction yet.

This issue makes the next occurrence diagnosable, and fixes it if the logging finds it.

## Decisions

- **Every `move-mouse` logs** its trigger, the monitor it believes focused, the frame it computed and the point it moved to, in the `mouse` unified log category, before it moves the pointer.
- **A move to a point within 4 points of the display's origin logs at error level** with the full reasoning, so it stands out in `winmux report` and `doctor`.
- **If a run on Prateek's machine shows the cause**, the fix goes in this issue; if it shows `move-mouse` innocent, the issue closes with the log attached and a new one names the real cause.

## Depends on

Nothing.

## Done when

- [ ] A test asserts the log line's fields for a `move-mouse` on monitor change.
- [ ] `docs/` names the log category.
- [ ] A line in **Prateek's checks on an installed build and real hardware**: run with the logging for a day and attach the `mouse` category's lines from the next jump.

## Sources

- #268, "The mouse cursor sometimes jumps to the top-left".
