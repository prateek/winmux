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
- Without a Place hook, a drop fills the pointed Column or joins its occupied tab group. With a hook, the pointed slot supplies the focused target and nearest-empty anchor; a hook's explicit Column answer wins over the pointer. Dragged leaves are excluded from hook records, including after earlier leaves of a group have moved.
- Preview and binding share `ColumnPlacement.resolve`, and Lens and drag previews share `ColumnPlacement.frame`. Attach uses the whole Column, split its lower half, squeeze the resolved extra rightmost Column, and float hides the Column overlay. The existing workspace-move preview style uses a plain-target mode on the existing overlay model instead of per-window zone symbols.
- One drag cache coalesces asynchronous decisions per full key, retaining requests across workspace round trips so revisiting a key does not call the hook again. Until an answer arrives, it previews the pointed Column with tab-group Overflow. Only the current context may redraw or complete an awaiting drop. A queued drag event arriving after mouse-up preserves the pending Column intent until final apply; clearing it early had caused a second hook call in the live run. The corrected live workspace round trip records one hook evaluation, including the drop. Drag end, cancellation and config reload clear the generation. Ordered group drops reuse the dragged leaf's preview answer even when that leaf is not first, run each leaf's commands after binding, and skip a second Place pass.
- Fourteen new behavior tests and host and pinned-version guest `make check` pass: 1,648 Swift tests, helper suites and 171 script tests. The guest skips the existing committed-hash check because its sync snapshot is not a host commit; that check passes on the host. The four specified Column Policy regressions and existing drag-zone tests pass unchanged. The existing placement test only changes the geometry helper's name. Disabled-routing, lost group-cache reuse, stale-answer, workspace-round-trip and late-mouse-up mutations each fail their regression checks.
- Final-implementation guest stills and CLI/native-frame readbacks cover each of the three Columns, empty and occupied drops, focused split, full-workspace squeeze, fixed Column 3 while pointing at Column 1, float, and a cross-workspace Column 3 drop after changing workspace while the mouse is held. Sidebar hover did not switch the active workspace in this one-display guest; no second display was available. The same Columns-off script against the archived base and branch shows the same overlay and identical final layouts and native frames. Its setup explicitly resets workspace and floating state before each run.
- No Default changed. The Decisions and Defaults above remain as written. Builder evidence uses screenshots and readbacks; the pull request's final-commit clip is filmed separately.
- [ ] Installed-build drag checks, a second display and real sleep, wake and unlock remain Prateek's.
