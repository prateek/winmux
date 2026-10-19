# A drag event queued behind mouse-up can lose the drop

Part of {{UMBRELLA}}.

## What to build

When the mouse button comes up, `resetManipulatedWithMouseIfPossible` (`Sources/AppBundle/mouse/resize/resizeWithMouse.swift`) flushes the drag and then applies the pending drag intent. A `leftMouseDragged` sample can still be queued behind the mouse-up. When `refreshPendingWindowDragIntentFromGlobalMouseDrag` (`Sources/AppBundle/mouse/drag/WindowDragPendingIntent.swift`) handles it, the button already reads as up, so it calls `clearPendingWindowDragIntent()`, and the apply that follows finds no intent: the drop does nothing and the window goes back where it was.

**Dragging a window shows no overlay when Columns are on** saw this happen in a guest's live run for its Column drops and kept a pending Column intent through that late sample, for that kind only. Every other kind (`tabStack`, `stackSplit`, `swap`, `moveToWorkspace`, `moveToWorkspaceZone`, `createWorkspace`, `reorderTab`, `detachTab`) still goes through the same clear.

## Decisions

- **A late drag sample never clears a drop that mouse-up is about to apply.** The fix belongs in one place for every kind, by the order of events or the manipulation's state, not as a case per kind; once it is in, the Column-only exception goes.

## Depends on

Nothing.

## Done when

- [ ] A test posts a drag sample after mouse-up and before the apply, for a tab-stack drop and a workspace move, and each drop still applies.
- [ ] The Column-only early return in `refreshPendingWindowDragIntentFromGlobalMouseDrag` is gone, and the Column drop test for the late sample still passes.

## Sources

- Found while building **Dragging a window shows no overlay when Columns are on**, 2026-10-18: seen in its live run for Column drops, and named for the other kinds in its `/code-review` round 1.
