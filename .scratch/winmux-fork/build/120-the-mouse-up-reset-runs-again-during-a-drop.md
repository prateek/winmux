# The mouse-up reset can run again while a drop is still being applied

Part of {{UMBRELLA}}.

## What to build

`resetManipulatedWithMouseIfPossible` (`Sources/AppBundle/mouse/resize/resizeWithMouse.swift`) flushes the drag, awaits `applyPendingWindowDragIntentWithPolicy()`, and only then calls `cancelManipulatedWithMouseState()` and stops the interaction driver. While it awaits, the move session and `currentlyManipulatedWithMouseWindowId` stay live. A second reset can start in that time: the display link's `finishAfterMissedMouseUpIfNeeded` and the global observer's mouse-up handler both call it, and the observer path does not mark a reset as scheduled. The second reset's `flushBeforeMouseUp` renders a forced move frame, which looks up a destination for the still-live session, builds a fresh intent, and the second apply drops the window again.

The await is real for any drop that suspends: a Column drop running its `place` hook's `run` list, and every other drop kind's post-drop Place pass, which awaits the hook. **Dragging a window shows no overlay when Columns are on** tried a guard in the shared destination lookup, keyed on the dropped window, and removed it in review: it blocked a new drag of that window for the whole run list, a second window's drop overwrote it, and it treated a symptom of the reset being re-entered.

## Decisions

- **One mouse-up applies one drop.** The fix is at the reset: the session that dropped can build no second intent, whether by ending the move session before the first await or by making the reset non-reentrant. No per-kind or per-window guard in the destination lookup.

## Depends on

Nothing.

## Done when

- [ ] A test runs a second reset while the first awaits a drop's run list (a Column drop) and while it awaits the post-drop Place pass (a tab-stack drop across Columns), and the window is placed once in each.
- [ ] A new drag of the same window, started while the first drop's run list runs, gets its destinations as usual.

## Sources

- Found while building **Dragging a window shows no overlay when Columns are on**, 2026-10-18, in `/code-review` rounds 4 and 5 on its pull request.
