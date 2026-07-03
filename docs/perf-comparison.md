# Performance Comparison: winmux vs AeroSpace vs FlashSpace

Code-path analysis, 2026-07-02, motivated by dogfood lag reports
(`docs/dogfood-notes.md`). Sources: this tree at `f36ee615`; upstream
AeroSpace at `cfd4eab` (v0.21.1-Beta, 2026-07-01); FlashSpace at `main`.
This is architectural comparison with file-level evidence, not empirical
benchmarking.

## Lineage note

This fork's base includes upstream AeroSpace commits through 2026-03-09, so
it already contains upstream's v0.18.0 thread-per-app AX rework and the
v0.20.0 focus AX-avoidance. Claims that winmux refresh "blocks the main
thread on AX" are wrong: AX enumeration fans out to per-app CFRunLoop
threads (`Sources/AppBundle/tree/MacApp.swift:285`) and the main actor only
awaits. The perceived lag has different mechanics, itemized below.

## The three architectures in one paragraph each

**FlashSpace** does no window management at all in its hot path: a workspace
is a list of apps, switching is `raise()` on shown apps and Cocoa `hide()`
on everything else, so the cost is O(running apps) cheap calls with no
per-window AX frame writes, no layout engine, and no tree model. Hotkeys
are Carbon-registered (no tap), the only event tap is gesture-mask-only and
pass-through, AX reads happen on demand at action time, and its Exposé
renders pre-captured JPEGs. It is fast because it refuses to do the work a
tiler does.

**AeroSpace (current)** keeps a refresh-heavy event model — every global
left mouse up and every app activation schedules a complete refresh that
re-enumerates all windows of all apps — but has spent 2025 making that
model non-blocking: one CFRunLoop thread per app owns all AX for that app,
every AX job is cancellable, sessions coalesce (a new refresh cancels the
in-flight one), light sessions take priority, and focus paths dodge AX when
the answer is already known. Workspace switching still parks invisible
windows in a screen corner (per-window AX moves, async on app threads).
Acknowledged remaining costs: refresh awaits all apps before layouting
(issue #1615, unshipped), full enumeration is never incremental, corner
parking survives (issue #235).

**winmux (this fork)** inherits AeroSpace's refresh-heavy model AND its
thread-per-app fix, then adds zone and tab-group machinery on top, several
pieces of which run at pointer rate on the main actor: global+local
monitors for mouseMoved/drag/scroll feed sidebar cursor trapping and zone
divider hover tracking on every event (`GlobalObserver.swift:189`,
`onPointerActivityMain`); divider-proximity mouse downs run
`CGWindowListCopyWindowInfo` synchronously on the main thread
(`ZoneDividerDragController.swift:172`); a 60 Hz main-actor timer drives
overlay/sidebar animations while active (`DisplayRefreshDriver.swift:78`);
and every refresh session also rebuilds tab-group and sidebar view models.
Zones multiply layout work: each zone is a monitor-like viewport, so
`layoutWorkspaces()` passes cover more viewports per session, and the
activation path still does the inherited optimistic double layout.

## Issue-by-issue

| Issue | FlashSpace | AeroSpace v0.21.1 | winmux |
| --- | --- | --- | --- |
| Refresh on every mouse-up | No such concept | Yes, inherited design; coalesced + cancellable + off-main AX | Yes, same model (light session then scheduled complete refresh) |
| Double session on app activation | N/A | Yes (`optimisticallyPreLayoutWorkspaces` double layout, cancellable) | Yes, inherited |
| Await-all-apps before layout | N/A (no layout) | Yes; maintainer's issue #1615, unshipped | Yes, inherited |
| Pointer-rate main-thread work | None (gesture tap is pass-through) | Only opt-in focus-follows-mouse, off-main probe, per-event cancel | Always-on: sidebar cursor trap + divider hover per event, main actor |
| Sync window-system query on click path | None | None | `CGWindowListCopyWindowInfo` on divider-proximity mouse down |
| Animation timers | None | None (zero display-link/timer hits) | 60 Hz main-actor driver while overlays/sidebar animate |
| Workspace switch mechanics | raise/hide apps, no frame writes | Corner-park invisible windows, per-window AX moves async | Same corner parking; zones add per-viewport layout passes |
| Slow-app defense | Hard blacklist (pygame) | Cancellable jobs; focus-path AX dodges; no timeout/budget | Same as upstream base; no budget |
| Instrumentation | None | Always-on signposts around every AX call and session | Signposts on sessions; doctor per-app AX latency probe |

## Where winmux lag actually comes from (corrected)

1. **Fork-added pointer-rate main-actor work.** `onPointerActivityMain`
   runs on every mouse move/drag/scroll (60-120 Hz): sidebar cursor
   trapping geometry plus divider hover hit-testing. Individually cheap,
   but it contends with session/layout work on the same actor and is the
   kind of standing load neither upstream nor FlashSpace carries.
2. **Sync `CGWindowListCopyWindowInfo` on divider-proximity clicks** — a
   system-wide window-list copy on the input path, added by a correctness
   review fix. Neither comparator does anything similar.
3. **Session pipeline latency, amplified by zones.** The inherited model
   (mouse-up refresh, activation double-layout, await-all-apps) means the
   *reaction* to any interaction waits for the slowest app's enumeration
   plus layout passes over every viewport — and zones multiply viewports.
   A desktop click (Show Desktop) is the worst case: two sessions, plus
   macOS itself moving every window aside, firing AX move notifications
   that schedule further refreshes.
4. **60 Hz animation driver + tab-group/sidebar model rebuilds** inside
   sessions add steady main-actor load the comparators don't have.

## What each comparator teaches Slice 53

From AeroSpace (already partly inherited; finish the job):
- make winmux's added input handlers schedule-only, like upstream's
  focus-follows-mouse handler (cancel previous task per event, probe
  off-main);
- verify our session scheduling kept upstream's cancellable semantics
  everywhere the fork added call sites;
- adopt the v0.20.0 pattern of dodging AX when cached state answers the
  question (focus, titles) in fork-added paths;
- keep the signpost discipline on new zone code paths.

From FlashSpace:
- per-app AX time budget / hostile-app skip (upstream has cancellation but
  no budget; FlashSpace proves a blunt skip is livable);
- pre-captured previews for the zone Exposé (Slice 55), never live capture
  at open time;
- suspend own observers around self-initiated operations plus a timestamp
  guard, rather than reacting to our own events.

Fork-specific must-fixes with no upstream/FlashSpace equivalent to copy:
- divider veto off the click path (async or cached);
- divider hover tracking gated to zone mode (Slice 54 removes most of the
  pointer-rate work for free);
- bound the per-session layout cost as viewport count grows (zones), and
  drop the optimistic double layout for interactions that cannot have
  changed window state.
