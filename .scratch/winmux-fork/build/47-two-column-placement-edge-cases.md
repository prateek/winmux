# Three landing and placement edge cases: a float hint across displays, an empty container, and Columns turned off

Part of {{UMBRELLA}}.

## What to build

The reviews of **One meaning for Column placement, shared by the Lens landing hint** and **Lens state, events and effect lifetimes, with controlled time** each found places where placement or its hint gives a wrong answer. All were there before those changes and were left alone, because each change claimed to alter no behaviour. This issue fixes the three.

**1. The landing hint for a window that will float is drawn in the wrong place across two displays.**

Hold the Summon modifier over a window on another workspace and the Lens draws where it would land. When the Place hook's Overflow answer is to float the window, the hint is the window's own frame carried over to the destination. To carry it over, the code needs the rectangle of the display the window is on now. It passes the destination's instead (`source: workspace.source` in the Column branch of `LensLifecycle.updateMiniatureLanding`; the branch above it, for a window that is already floating, looks the entry's own workspace up correctly).

- A hidden window restores its saved proportional position against the destination monitor's full rectangle, clamped inside it. This applies on one display too: a saved x=-60 restores at x=0.
- A window on a visible workspace uses the visible rectangle of the monitor under its centre, mapped into the destination monitor's visible rectangle, with its size kept and position clamped. With one monitor this path does not move it.
- The hint follows these two production paths through their shared pure geometry functions; hiding itself stays in `MacWindow`.

**2. A Column holding only an empty container is both empty and occupied.**

This needs flattening off (`enable-normalization-flatten-containers = false`), so a Column can hold a container with no window in it.

- Choosing a slot (`Columns.swift`), and the records the hooks see (`columnRecords` in `ColumnPolicy.swift`), call a Column occupied only when it holds a window other than the one arriving.
- The resolver (`ColumnPlacement.swift`) calls it occupied when it holds any child at all.

`place` takes the window out of the tree before resolving and normalizes afterwards. So a window that was alone in a container leaves an empty container behind; the hook is told its Column is empty, and the resolver then treats the same Column as occupied and applies the Overflow policy. The window is floated, or squeezed into an extra slot, out of a Column it had to itself.

**3. A landing hint outlives the Columns it was computed for.**

With the hint on screen, turn Columns off for the destination (a config reload) while the same selection and modifier are held. The hint stays where it was until the selection moves. The check that skips re-evaluation compares the Column state it evaluated against with the current one, weakly held; once Columns are off both read as absent, so nothing looks changed. Turning Columns on does recompute.

## Decisions

- **One answer to "is this Column occupied".** Slot selection, the hook records and the resolver ask one function. A Column is occupied when it holds a window, at any depth, other than the one arriving. A container with no window in it does not occupy a Column.
- **The float hint follows the hidden state**, for both an already-floating window and a Place answer of Overflow float. Hidden windows use the saved full-monitor proportion; visible windows measure from the monitor under their centre. Each production mapping and its hint share one pure function.
- **The hint equals what Summon does.** For a floating landing across two displays, a test compares the hint with the frame Summon gives the window. If they differ after the fix above, the hint follows Summon; what Summon does is not changed here.
- **Columns turned off is a change.** The landing is evaluated again when the destination's Columns go from present to absent, as it is for every other change of Column state.
- **Each gets a test that fails first.** The first with two synthetic monitors, same size side by side and different sizes; the second with flattening off, under each Overflow policy; the third on the controlled clock.
- **Nothing else changes.** With flattening on, on one display, with Columns left alone, every existing placement and landing test passes unchanged.

## Not in this issue

- The other findings declined in those reviews: widths assigned on every bind, the second slot lookup in `bindToColumn`, the helper records cache, the members that only tests read.
- Whether empty containers should exist at all with flattening off.

## Depends on

Nothing.

## Defaults chosen for you

No ticket settled these. Each is a starting default: change one if the code argues for it, and say so in the pull request.

- **One dead field goes with it.** `stripReleasedWhileOpening` in `LensLifecycle` is written and never read outside tests; the release it mirrors is read from the opening state. Delete it and point its test at the state.
- **The live run.** A guest has one display, so the first case is shown by tests only; say so. The second is a transcript in a guest with flattening off: `list-columns` and `place --dry-run` before and after. The third is a short recording: the hint up, a config save that turns Columns off, the hint gone or redrawn.

## Done when

- [x] With two monitors in a test, the landing hint for a window that will float on arrival equals the frame Summon gives it, for monitors of the same size and of different sizes.
- [x] With flattening off, a window alone in a container that is placed again stays in its Column under every Overflow policy: not floated, no extra slot.
- [x] One function decides occupancy, and slot selection, the hook records and the resolver call it.
- [x] Turning the destination's Columns off while a hint is shown replaces the hint with the ordinary landing.
- [x] The existing flattening-on Column placement and landing tests pass unchanged. The driver-authorized flattening-off `soleNested` float/squeeze rows now expect attach in Column 2 at unchanged widths; split uses the same corrected occupancy and tab-group is covered too.

## Built and checked

`ColumnPlacement.isOccupied` excludes all of an arriving node's leaf windows.
Slot selection, MRU selection, hook records, squeeze-slot release and resolution
use it; binding uses it too. Lens records derive `empty` from the same cached
window snapshot they send to the hook, after excluding the selected window.
A slot holding no other window attaches under every Overflow policy, discarding the empty wrapper before
binding. With flattening off the arriving window becomes the Column's top-level
node, with its original slot and widths.

Both floating-hint paths choose by the window's hidden state. Hidden windows
use the saved proportional position, destination full monitor rectangle and
`lastKnownActualRect ?? lastFloatingSize` size, through the same pure restore
function as `MacWindow.unhideFromCorner`. Visible sources use the monitor under
the frame's centre and visible rectangles, through the same pure mapping as
`layoutFloatingWindow`; the one-monitor visible-source path does not move.
Production floating layout and hiding behavior are unchanged. Synthetic tests
cover both source states, both floating outcomes and equal/unequal monitors;
both monitors' visible rectangles are smaller than their full rectangles.
Visible sources compare with real Summon/layout. `TestWindow` cannot execute
`MacWindow.unhideFromCorner`, so hidden sources compare with the shared pure
restore function it calls, including the one-display x=-60 to x=0 case.

Replacing Columns in `Workspace.applyColumns` notifies only the existing Lens
through a weak lifecycle observer registered when its session completes and
cleared on dismissal. Both config saves and the real `column-count off` command
redraw without constructing a panel on startup. An apply that leaves the count
and widths unchanged does not notify, so an unrelated config save keeps the hint
on screen, and with no Lens open applying Columns does not resolve focus.
`evaluatedColumns` retains the old state until reevaluation; `landingColumns`
remains weak. Controlled-clock saves check off/on with the same selection and
held modifier. Lens hook records keep `empty` consistent with cached `windows`
even when the live tree changes. The unused `stripReleasedWhileOpening` field
is deleted; its test observes the committed action and Hold behavior.

`miniatureColumnLanding` handles tiled placements only; its dead float branch
and floating frame/source parameters are removed. The float rows in
`ColumnPlacementTest` assert `verticalRange == nil`; all flattening-on expected
rectangles are unchanged. Binding releases an unoccupied slot only in
`columnBinding`; the incoming-group branch asks the shared occupancy function.
The empty-container hint test disables flattening and inserts the empty group
after normalization/layout (normalization removes wholly empty groups even
with flattening off). It asserts Column 2 still holds that group before
computing the hint, and fails with the resolver occupancy fix undone.

Host and pinned-version guest `make check` pass. The dedicated tree tests cover
all four policies, deeper wrappers and incoming groups, plus the no-hook
selection, records, extra-slot release and new-window binding paths. Existing
flattening-on placement and landing expectations are unchanged.

The one-display guest live run compares the base and changed trees using the
same scripts in `.scratch/winmux-fork/proofs/landing-placement/`. Both stage a
survivor alone in a tab group and record float/squeeze hook decisions; dry run
reports the hook's answer, not its resolved effect. The bounded path search
found `layout tiling` declines the tiled survivor before relayout; relayout's
other callers restore floating/native/cache state, drag/drop requires a
workspace/floating/slot change, and shake's Place branch requires a floating
window. No reliable path to actual Place in that exact staged state was found,
so the permitted transcript fallback is used and the tree tests carry the fix's
claim. The flattening-on Columns/decision transcripts agree across the builds.

Both recordings select the one Search match, Orange on workspace 2, and hold
Option through a config save turning Columns off. The base keeps its squeeze
hint; the changed build redraws the ordinary landing. Config status, Columns,
Lens traces and final windows were read back. The debug app and owned windows
were closed. No permission was granted and no builder release was published.
The final one-display guest check shows a floating Orange window hidden from
workspace 2, with saved frame (-60, 100, 400, 260). Its hint draws
(0, 100, 400, 260), and Summon places it at exactly that frame on workspace 1.
Search found one Orange match on workspace 2. The screenshot and frame readback
were retained; the debug app and owned windows were closed. No chosen default
changed.

## Checks for Prateek

- [ ] On two displays with the installed build, give a workspace Columns with a `place` hook answering Overflow `float` into an occupied Column. Hold the Summon modifier over a floating window on the other display's visible workspace, then over one on a hidden workspace: each landing outline is where Summon then puts the window.

## Sources

- The **Declined** lists of pull requests [#72](https://github.com/prateek/winmux/pull/72) and [#73](https://github.com/prateek/winmux/pull/73).
- [CONTEXT.md](https://github.com/prateek/winmux/blob/fork/CONTEXT.md)
