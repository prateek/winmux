# Performance Comparison: winmux vs AeroSpace vs FlashSpace vs Rift vs Hammerspoon WMs

Code-path analysis, 2026-07-02, motivated by dogfood lag reports
(`docs/dogfood-notes.md`). Sources: this tree at `f36ee615`; upstream
AeroSpace at `cfd4eab` (v0.21.1-Beta, 2026-07-01); FlashSpace at `main`;
Rift (acsandmann/rift) at v0.4.3-beta; PaperWM.spoon, hhtwm, and
Hammerspoon core at `main`. This is architectural comparison with
file-level evidence, not empirical benchmarking.

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

**Rift** is, in its author's words, "essentially AeroSpace but implemented
in a yabai style" — and it is the existence proof that an AX-writing tiler
can feel instant without disabling SIP. Its window *writes* are the same AX
`set_position`/`set_size` calls every tiler makes (no private setFrame
exists below the SIP line). The speed is pure architecture: a dedicated
input thread owns the CGEventTap so tap callbacks are never stalled by
layout or IPC; a reactor thread owns authoritative state and the layout
engine; one thread per managed app runs that app's AX so a beachballing app
stalls only itself; mouse-moved handling is throttled (8 ms / 2 px);
per-window transaction IDs let the reactor discard echo notifications from
its own frame writes; reads and change events come from bulk private
SkyLight queries (`SLSWindowQueryWindows`, connection notifications) that
beat AX latency; and workspaces are virtual (the same corner-parking trick
as AeroSpace), never round-tripping through Mission Control. Animations are
off by default because animating through AX is the slow path. Costs: ~70
undocumented SkyLight externs and hand-packed event records that need
per-macOS-release maintenance.

**Hammerspoon WMs (PaperWM.spoon, hhtwm, on hs.window/hs.window.filter)**
are the cautionary tale: every AX read and write is synchronous IPC on one
shared main thread that also runs the Lua VM, the event taps, and all
timers. One slow AX server (WebKit, Firefox, Electron) freezes the whole
WM for up to the ~6 s system AX timeout — Hammerspoon core carries a
hardcoded `SKIP_APPS` blacklist and a profiling helper (`_timed_allWindows`)
just to find the offender, and a blocked in-process CGEventTap gets
disabled by the OS system-wide. One logical `setFrame` costs up to six AX
round-trips (enhanced-UI toggle plus the size/position/size dance);
animation is a 60 Hz Lua timer issuing full AX transactions per window per
tick, which is why the ecosystem-wide advice is `animationDuration = 0`.
PaperWM tried debouncing its tiling and reverted it because focus got
slower; its space switching literally opens Mission Control, busy-waits,
and AX-clicks (or drags thumbnails matched by title substring). hhtwm
re-enumerates every window of every app on every change. The defenses that
earned their keep — app blacklists, per-window frame caches, move-event
debouncing, watcher suppression around self-initiated writes, hard
wall-clock bailouts — are all workarounds for the missing threading model.

**Commercial zone managers (BentoBox, BetterStage; binary-inspected, no
source).** Both are public-AX-only with SIP intact — no private SkyLight
symbols — so their per-operation window-move cost is identical to ours;
the differentiation is scope and mitigation. BentoBox (v1.1.8) is a
FancyZones-style snap helper: no AX observers, no event tap, no window
state ownership — it sleeps until a modifier-drag or hotkey, issues a few
AX setFrames, and goes back to sleep. It cannot lag because it is not
running between user actions. BetterStage (v1.2.3) is the closest
commercial analog to winmux's ambitions: up to 9 "stages" (virtual
workspaces spanning monitors) implemented by hiding/stashing non-active
windows and batch-restoring frames via AX — explicitly not macOS Spaces,
marketed as "&lt;16 ms, no animation." It is the only system in this whole
comparison that ships `AXUIElementSetMessagingTimeout` (their changelog:
"a slow or unresponsive app is far less likely to hold things up"), plus
batched AX reads (`AXUIElementCopyMultipleAttributeValues`) and per-app
operation routing ("one slow app can't hold up the rest", claimed ~50%
latency win on busy stages). Their scar tissue matches our rule exactly:
v1.1.2 fixed system-wide typing stutter caused by a periodic task holding
up their active CGEventTap's hand-off. Both ship Sparkle 2.8 with EdDSA
appcasts.

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

| Issue | FlashSpace | Rift | AeroSpace v0.21.1 | winmux | Hammerspoon WMs |
| --- | --- | --- | --- | --- | --- |
| Window writes | None (raise/hide only) | AX setFrame, batched, per-app threads | AX setFrame, per-app threads | Same as upstream | AX setFrame, main thread, up to 6 round-trips per set |
| Change detection | NSWorkspace activation only | SkyLight connection notifications + AX observers | AX observers + NSWorkspace + refresh sweeps | Same as upstream | AX observers (window.filter) or full re-enumeration (hhtwm) |
| Refresh on every mouse-up | No such concept | No — event-driven deltas only | Yes; coalesced + cancellable + off-main AX | Yes, same model | N/A (no global refresh concept) |
| Await-all-apps before layout | N/A | No — reactor reacts per delta | Yes (issue #1615, unshipped) | Yes, inherited | N/A |
| Input handling isolation | Gesture-only pass-through tap | Dedicated input thread owns the tap; 8 ms/2 px mouse throttle | Two NSEvent monitors, off-main probes | Pointer-rate main-actor work, always on | Tap callbacks run Lua on main thread; OS disables tap when blocked |
| Sync window query on click path | None | None (bulk SLS reads, cached) | None | `CGWindowListCopyWindowInfo` on divider clicks | Common (windows() per action) |
| Animation | None | Off by default; AX tween is known slow path | None | 60 Hz main-actor driver while chrome animates | 60 Hz Lua timer, full AX transaction per window per tick |
| Workspace switch | raise/hide apps | Corner-park via batched AX, no Mission Control | Corner-park, async per-window | Corner-park + zone-multiplied layout | Real Spaces via Mission Control AX-clicking + busy-waits |
| Self-event suppression | Observer pause + timestamp guard | Per-window transaction IDs | Session coalescing | Same as upstream | Stop watcher, setFrame, restart on timer |
| Slow-app defense | Hard blacklist | Per-app threads isolate stalls | Cancellable jobs, focus AX dodges; no budget | Same as upstream; no budget | SKIP_APPS blacklist, AX timeout knob, profiling helper |
| Instrumentation | None | None found | Always-on signposts | Signposts + doctor AX probe | `_timed_allWindows` profiler |

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

From Rift (the architecture target for an AX tiler; all SIP-safe, most of
it needs no private APIs):
- never let layout or IPC share a thread with input-event callbacks;
- throttle mouse-moved handling (Rift: 8 ms / 2 px) instead of processing
  every event;
- per-window transaction IDs to drop echo notifications from our own frame
  writes, instead of watcher stop/restart dances;
- prefer event-driven deltas over scheduled full re-enumeration; Rift has
  no mouse-up-refresh concept at all and stays correct via WindowServer
  notifications plus AX observers;
- optional, higher-risk: bulk SkyLight window queries and connection
  notifications where AX latency hurts most (AeroSpace also ships some
  private calls; weigh fragility per call).

From the Hammerspoon ecosystem (what its scars prove):
- the ~6 s AX stall from one hostile app is real and recurring (WebKit,
  Firefox, Electron); a messaging-timeout budget plus a skip-list is table
  stakes, and even Hammerspoon exposes `AXUIElementSetMessagingTimeout`;
- re-enumerating the world per change (hhtwm) is the anti-pattern our
  inherited mouse-up refresh approximates; delta models win;
- animating through AX at 60 Hz is unshippable; if zones ever animate,
  frames must be rare and batched;
- real macOS Spaces integration is a dead end (Mission Control AX-clicking
  with busy-waits); the zones/virtual-viewport choice is validated.

From the commercial zone managers:
- `AXUIElementSetMessagingTimeout` is shipped, marketed, and
  changelog-proven by BetterStage; winmux setting no AX timeout anywhere is
  a gap with an off-the-shelf fix;
- batch AX reads with `AXUIElementCopyMultipleAttributeValues` where we
  fetch several attributes per window;
- BetterStage's typing-stutter regression (periodic work on the event-tap
  thread) is the exact failure mode the plan's input-path rule forbids;
- react to less: BentoBox's zero-standing-cost model is unreachable for a
  tiler, but every event class we can stop reacting to (Slice 54's divider
  gating, dropping no-op refresh triggers) moves us toward it;
- Accessibility-only with SIP intact is table stakes in this product
  category and worth preserving as a hard constraint;
- Sparkle with EdDSA appcasts is the standard update path in this market
  (BentoBox, BetterStage, Ghostty), reinforcing Slice 52's design.

Fork-specific must-fixes with no comparator equivalent to copy:
- divider veto off the click path (async or cached);
- divider hover tracking gated to zone mode (Slice 54 removes most of the
  pointer-rate work for free);
- bound the per-session layout cost as viewport count grows (zones), and
  drop the optimistic double layout for interactions that cannot have
  changed window state.
