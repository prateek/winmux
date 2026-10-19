# Dragging a window shows no overlay when Columns are on

Part of {{UMBRELLA}}.

## What to build

Dragging a window shows an overlay of where it will land. With Columns on, Prateek dragged a window and saw no overlay at all. The drag zones and previews (`Sources/AppBundle/mouse/`) were written before fixed Columns, and a drop is now placed by the Column Policy.

## Decisions

- **Reproduce first**, in a guest with Columns on.
- **A drag shows where the window will land**: the Column, and what Overflow will do there, whether a tab group, a split or a squeeze.

## Not in this issue

- A change to what `place` decides.

## Depends on

Nothing.

## Defaults chosen for you

- **The overlay asks the Policy** what a drop at that point would do, as `place --dry-run` does, and draws the answer. It does not carry a second copy of the rules.
- **An empty Column shows its outline as the target.**

## Done when

- [x] With three Columns, dragging a window over each Column shows an overlay, and the drop lands where the overlay showed.
- [x] With Columns off, the overlays are as before.
- [ ] The pull request has a clip of a drag across three Columns.

## Sources

- Prateek, 2026-10-07: "the hover affordances (eg overlay that shows up on windows) when dragging a window need to be made column aware". Asked what he saw: "i saw nothing."

## Built and checked

- Reproduction confirmed that an empty Column had no overlay: the old surface lookup required a window under the pointer. An occupied Column did show the old per-window zone overlay, specifically a top split in the recorded take. The Columns root is excluded as a matching split insertion parent, but the fallback can still wrap the target window; it does not prohibit every split. The failure was an absent empty-Column destination and previews that described tree zones rather than Column Policy placement.
- A tiling window or group over another Column now has a Column destination before per-window and workspace-zone lookup. Physical slot frames include the squeeze slot; gaps choose the nearer Column. Own-Column, tab-strip, sidebar and floating-source behavior stays on its existing path.
- Without a Place hook, a drop fills the pointed Column or joins its occupied tab group. With a hook, the pointed slot supplies the focused target and nearest-empty anchor; a hook's explicit Column answer wins over the pointer. A hook that fails, or whose records cannot be read, leaves the pointed Column as with no hook. The whole dragged subject is excluded from the hook's records and from `'mru`.
- Preview and binding share `ColumnPlacement.resolve`, and Lens and drag previews share `ColumnPlacement.frame`. Attach uses the whole Column, split its lower half, squeeze the resolved extra rightmost Column, and float hides the Column overlay. The existing workspace-move preview style uses a plain-target mode on the existing overlay model instead of per-window zone symbols.
- The preview-only cache coalesces asynchronous decisions per full key (window, workspace, Column state, each slot's windows and the pointed slot), retaining requests across workspace round trips. Until an answer arrives, it previews the pointed Column with tab-group Overflow. An answer under changed occupancy is discarded but redraws the pointed slot, so the next lookup requests the new occupancy. Drag end, cancellation and config reload clear the cache; reload also clears the pending intent.
- The pending intent carries the decision used to draw the overlay. Mouse-up applies that decision synchronously through `PolicyHookCompletion`, without waiting for or asking the hook. A release before the answer arrives takes the pointed Column as a tab group, with no hook or run list. A queued drag event after mouse-up preserves the pending Column intent until final apply. A group binds once, as one node: an empty Column or a split keeps it a tab group, a join merges it into the occupant's tab group, and a float floats each window (`bindToColumn` never makes a container a floating child). The decision's commands run after binding, and the drop skips the second Place pass. A cross-workspace drop binds straight into the Column.
- Twenty-two Column drop behavior tests and host and pinned-version guest `make check` pass: 1,656 Swift tests, helper suites and 171 script tests. The guest skips the existing committed-hash check because its sync snapshot is not a host commit; that check passes on the host. The four specified Column Policy regressions and existing drag-zone tests pass unchanged. The existing placement test only changes the geometry helper's name. Mutation checks cover drop re-evaluation, intent equality with unchanged geometry, reload clearing the intent, stale-occupancy redraw and unreadable records' failure reason. Abandonment-during-evaluation and re-ask-loop tests were removed with the suspended drop path.
- Final-implementation guest stills and CLI/native-frame readbacks cover each of the three Columns, empty and occupied drops, focused split, full-workspace squeeze, fixed Column 3 while pointing at Column 1, float, and a cross-workspace Column 3 drop after changing workspace while the mouse is held. Sidebar hover did not switch the active workspace in this one-display guest; no second display was available. The same Columns-off script against the archived base and branch shows the same overlay and identical final layouts and native frames. Its setup explicitly resets workspace and floating state before each run.
- One defect found on the way is a follow-up: a drag event queued behind mouse-up can lose the drop for the other drag kinds.
- The synchronous-drop follow-up repeats the single-window split, an Option-drag of a two-window tab group onto an occupied Column with window tabs on, and a no-hook empty-Column drop. Mid-drag stills and settled CLI/native-frame readbacks agree: the group stays a two-tab group in the lower half. In this guest, holding Option through mouse-up also invokes macOS half-screen tiling; the accepted group take releases Option while the mouse stays down, then continues the group drag before dropping.
- No Default changed. The Decisions and Defaults above remain as written. Builder evidence uses screenshots and readbacks; the pull request's final-commit clip is filmed separately.
- [ ] Installed-build drag checks, a second display and real sleep, wake and unlock remain Prateek's.
