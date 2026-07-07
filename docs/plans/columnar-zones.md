# Columnar Zones Plan

Base decision: zone == virtual monitor.
Scope: make ultrawide monitors ergonomic by letting one physical display
expose several named workspace viewports.

This document is the design and the current plan: the design spec
(Decision through Core Invariants), a slice inventory, and the call-site,
validation, and risk notes. The shipped per-slice acceptance record lives
in `columnar-zones-history.md`; the active Slice 56 redesign lives in
`slice-56-domain-model.md`.

## Status and remaining work

- Slices 0-50 are Tart-accepted.
- Slices 51-56 have shipped implementations but no accepted Tart artifact.
  Their acceptance is batched so recordings capture the final Slice 56
  vocabulary.
- Slice 56's domain-model redesign is implemented across phases A-G (see
  `docs/plans/slice-56-domain-model.md`). Follow-up code vocabulary cleanup
  through Phase 8 is complete and tracked in `docs/plans/zone-rename.md`; it
  is not Tart acceptance evidence by itself.
- Remaining gates before beta acceptance: cut the cleanup dogfood release, run
  the batched Tart acceptance phase for Slices 51-56, then make the
  beta-readiness decision after a multi-day dogfood soak on the ultrawide.
  Slice 51 still carries the acceptance-package cleanup and review gates
  from the beta path.

## Decision

WinMux should model a configured zone as a monitor-like workspace viewport, not as a new tiling container type inside one workspace.

That means a physical ultrawide can expose zones such as `left`, `main`, and `right`. Each zone gets its own active workspace, its own layout pass, and its own target for focus and move commands. A tab group is "bound to a zone" by living in the workspace currently shown in that zone. Moving the focused tab group to another zone moves that group to the target zone's active workspace instead of teaching tab groups about screen geometry.

This fits the current architecture because WinMux already treats monitors as independent workspace viewports:

- `MonitorViewportId` is the key used by workspace state.
- `Workspace.workspaceMonitor` resolves a workspace to a monitor-like viewport.
- `layoutWorkspace` lays out a workspace inside `workspaceMonitor.visibleRectPaddedByOuterGaps`.
- retained empty workspace slots already exist for monitor viewports.

The implementation should make zones feel like a first-class monitor surface to workspace code, while keeping physical-display code explicit.

Identity rule for call sites:

- use `WorkspaceViewport` / stable viewport identity when the operation targets
  where a workspace lives: zone focus, relative `next`/`prev` movement,
  directional movement, layout, active workspace slots, and sidebar zone targets;
- use `PhysicalMonitor` identity when the operation is about real display
  hardware or a user-supplied physical monitor selector: display numbering,
  `.main` / `.secondary`, monitor-pattern commands, permissions, display
  topology changes, and `on-focused-monitor-changed`;
- pattern-addressed `move-workspace-to-monitor 1` should no-op when the
  workspace is already anywhere on display 1, while viewport-addressed
  `move-workspace-to-monitor next` may move it to the next zone on that display;
- assignment validation must require the candidate point to be contained in a
  live physical display. Nearest-monitor fallback is acceptable for ergonomic
  mouse approximations, but not for deciding whether a persisted or
  force-assigned workspace is valid.

Input-path rule:

- input event handlers (global/local mouse and key monitors, event-tap
  callbacks, hover tracking) must not perform synchronous AX calls,
  `CGWindowListCopyWindowInfo`, layout passes, or full refresh sessions;
  they may only read cached state and schedule work;
- any refresh session that enumerates windows over AX must be bounded by a
  per-app time budget and must not be triggered by interactions that cannot
  have changed window state;
- reviewers must treat a violation of this rule as blocking, the same as a
  monitor-identity violation. Fixing a correctness bug by adding synchronous
  window-system queries to an input path is not an acceptable fix.

## Domain Model

Keep these concepts separate in code, config, tests, and demos:

- `PhysicalMonitor`: the real macOS display. Physical monitor numbering,
  `.secondary`, screen-change handling, and global display capture remain
  physical.
- `ZoneLayout`: a named shape for one physical monitor. The first layout kind
  is `columns`; later shape kinds can add grids or explicit rectangles without
  changing workspace ownership.
- `Zone`: a named region inside a physical monitor. A zone has a stable id,
  optional display name, enabled state, layout membership, configured width,
  runtime effective width, and a derived rect.
- `VirtualMonitor`: the runtime monitor-like viewport produced from an enabled
  zone. Existing focus, layout, and workspace code should see this as a
  `Monitor`; code that needs display hardware must ask for the physical monitor.
- `WorkspaceViewport`: the stable assignment slot for a physical monitor or a
  zone. This is where active and previous workspace state lives.
- `Workspace`: the content surface visible in a viewport. A zone never owns
  windows directly; it shows the workspace currently active in that zone
  viewport.
- `WindowOrTabGroup`: the movable content unit. Binding a tab group to a zone
  means moving the group into the target zone's active workspace.
- `ZoneBinding`: a durable user intent that a window, tab group, app rule,
  workspace, or scene member should prefer a zone. Slice 14 implements
  workspace-to-zone bindings as config plus an explicit apply command. Slice 15
  adds runtime window/tab-group bindings and inspection without claiming
  relaunch persistence. App-rule bindings remain a separate future entity.
- `ZoneScene`: a named macro that applies a zone layout and activates named
  workspaces in named zones.
- `ZoneRuntimeOverlay`: per-physical-monitor runtime state layered over config:
  active layout id, disabled zone ids, parked workspaces, width overrides, style
  overrides, current-toggle restore memory, optional active scene id, and later
  active snap policy.
- `ZoneAvailabilitySet`: a named runtime/config concept for groups such as
  `focus-only`, `comms-open`, or `full-dashboard`. This is separate from a
  scene because users need to toggle visibility without necessarily changing
  workspace bindings.
- `ZoneStyle`: a config-defined style token applied to zone chrome. This is not
  a layout.
- `ZoneSnapPolicy`: the mouse behavior contract for dragging around zones:
  freeform, snap only with a modifier, snap to a zone, and later snap to a
  window or slot within a zone.
- `InputBinding`: the user-facing invocation surface. Keyboard bindings,
  mouse gestures, launch rules, and automatic window routing should all call
  the same commands or command handlers rather than duplicating zone logic.

Current implementation comparison:

- `PhysicalMonitor`, `VirtualMonitor`, `WorkspaceViewport`, `Workspace`, and
  `WindowOrTabGroup` are real code concepts. Zones are exposed as `Monitor`
  viewports through `ZoneMonitor`; stable zone viewport identity lives in
  `MonitorViewportId`; moving a tab group to a zone means moving the nearest
  tab-group node into the target zone's active workspace.
- `ZoneLayout`, `Zone`, `ZoneScene`, `ZoneRuntimeOverlay`, and `ZoneStyle` are
  partially or fully represented in config and runtime state. A `Zone` is not a
  durable object; it is a configured column plus a runtime `ConfiguredZoneSummary`
  or `ZoneMonitor`.
- `ZoneRuntimeOverlay` currently carries active layout, active availability set,
  disabled zones, parked workspaces, width overrides, style overrides, and
  current-toggle restore memory. Parked workspaces survive lifecycle pruning while
  their zone is hidden, so a hidden zone can restore its previous workspace
  instead of losing an empty placeholder before re-enable. Runtime snap-policy
  overrides are also stored in the overlay and layered over the configured
  mouse snap policy.
- `InputBinding` exists through command parsing and normal key bindings. Mouse
  sidebar drag to a zone row calls the same move logic. Normal desktop window
  dragging now has configured and runtime whole-zone snap policy in code, with
  Slice 12 and Slice 20 Tart proof.
- `ZoneAvailabilitySet` is implemented. `ZoneSnapPolicy` now has an initial
  config/model seam, runtime policy switching commands, and a fast-tested
  whole-zone drag resolver for desktop window drags into whole-zone targets.
- `ZoneBinding` is first-class for workspace preferences through
  `[[zone-bindings]]` and `apply-zone-bindings`. The implementation can also
  move a window or focused tab group into a zone and can route new windows with
  `on-window-detected`. Slice 15 added the runtime `WindowOrTabGroup` binding
  entity through `bind-node-to-zone`,
  `unbind-node-zone-binding`, and `list-zone-bindings`.

## Interaction Model

Keyboard and command workflows should stay thin over the same zone model:

- `focus-zone <zone>` moves focus to a zone's active workspace.
- `move-node-to-zone <zone>` moves the focused window or nearest tab group to
  the target zone's active workspace.
- `bind-node-to-zone <zone>`, `unbind-node-zone-binding`, and
  `list-zone-bindings` record and inspect runtime intent that a specific window
  or tab group belongs in a zone. The binding points at a zone id; it does not
  make the zone own the window directly.
- `use-zone-layout`, `cycle-zone-layout`, `resize-zone`, and `balance-zones`
  change zone geometry on the target physical monitor.
- `enable-zone`, `disable-zone`, `toggle-zone`, `use-zone-availability`, and
  `cycle-zone-availability` change visibility at one-zone or named-set scope.
- `set-zone-style` and `cycle-zone-style` change zone chrome without changing
  layout or workspace binding.
- `set-zone-snap-policy` and `cycle-zone-snap-policy` change the effective
  desktop-drag snap policy at runtime without changing the configured modifier,
  gesture, or target.
- `use-zone-scene` and `cycle-zone-scene` switch a physical monitor between
  named scene states that combine layout preset plus zone workspace bindings.
- Example key bindings should compose these commands directly. The default idiom
  should use portable relative selectors when possible, for example a modal
  `alt-z` zone mode that maps `h`/`l` to `focus-zone prev`/`focus-zone next`
  and `shift-h`/`shift-l` to
  `move-node-to-zone --focus-follows-window prev`/`next`.
- Zone selectors should include `current`, `focused`, `next`, and `prev`.
  Bare relative selectors resolve within the focused physical monitor so
  default bindings do not depend on user zone names.
- Qualified relative selectors such as `2:next` resolve within the named
  physical monitor. `--monitor` and a qualified selector are mutually exclusive,
  because they would otherwise provide two physical scopes for one command.
- `toggle-zone current` keeps a short restore target so pressing the same binding
  again can restore the hidden current zone. Explicit availability operations and
  named availability sets clear that restore memory.
- Cross-zone keyboard functions are part of the product surface, not just a CLI
  convenience. Default bindings should cover focusing adjacent zones, moving the
  focused window or tab group between zones, resizing the current zone,
  balancing enabled zones, toggling one zone, applying a named availability set,
  and switching layouts/scenes for the focused physical monitor.
- Commands that use `current` must make the resolved target auditable in demos
  and logs. A viewer should be able to tell whether the operation targeted the
  focused zone, a hidden zone being restored, all enabled zones, or a layout/set
  on the physical monitor.

Mouse workflows should use a separate snap-policy layer:

- default drag behavior stays freeform unless the active policy says otherwise;
- configured drag policies can preview a whole-zone target and snap the window
  or tab group into that zone's active workspace on release;
- the first snap target is the zone itself, not a window or slot inside the
  zone;
- gesture configuration is an input layer over the same move/focus/layout
  handlers used by keyboard commands.
- Future gesture work should make one-handed mouse flows explicit: freeform
  drag by default, snap only while a configured modifier or gesture is active,
  and no snap when the source or target policy is float/freeform.

## End-User Shape

The user configures named zones on a physical monitor:

```toml
[[zones]]
monitor = 1
layout = "columns"
default-zone = "main"

columns = [
  { id = "left",  name = "Reference", width = 0.24 },
  { id = "main",  name = "Work",      width = 0.52 },
  { id = "right", name = "Comms",     width = 0.24 },
]
```

Bindings target zones by name:

```toml
[mode.main.binding]
alt-h = 'focus-zone left'
alt-l = 'focus-zone right'
alt-shift-h = 'move-node-to-zone left'
alt-shift-l = 'move-node-to-zone right'
```

The simple mental model is:

- a physical monitor can have named zones;
- each zone shows a workspace;
- focusing a zone focuses the workspace visible there;
- moving a window or tab group to a zone sends it to that zone's workspace;
- launching a new window uses the currently focused zone because it uses the focused workspace.

The ergonomic control surface should stay small and composable:

- `focus-zone <zone>` focuses a zone.
- `move-node-to-zone <zone>` moves the focused window or focused tab group
  across zones.
- `toggle-zone <zone>`, `enable-zone <zone>`, and `disable-zone <zone>` change
  availability for one zone.
- `use-zone-layout <layout-id>` and `cycle-zone-layout <a> <b>...` switch or
  cycle sizing presets.
- `resize-zone <zone> width [+|-]<percent>%` and `balance-zones` tune zone
  sizing without editing config.
- `use-zone-scene <scene-id>` switches layout and workspace bindings together.
- `cycle-zone-scene <scene-id> <scene-id>...` advances a monitor through named
  whole-layout states such as `triage` and `deep-work`.
- `set-zone-style <zone> <style-id>` and
  `cycle-zone-style <zone> <style-id>...` change visible zone chrome without
  changing layout, size, or workspace bindings.
- `use-zone-availability <set-id>` and `cycle-zone-availability <a> <b>...`
  toggle groups such as `focus-only`, `comms-open`, and `mail-open` at the
  layout level.

Mouse behavior should be explicit, configurable, and demoable:

- dragging a floating window inside a zone stays freeform by default;
- snap overlays appear only when policy says they should, such as while holding
  a configured modifier;
- the overlay must state whether the drop target is a whole zone or a position
  inside a window/tab group within that zone;
- one-handed mouse workflows should be possible through configurable gestures,
  but gesture recognition must call the same zone commands as keyboard
  bindings.
- The current implementation claims both whole-zone snap and the first
  window-slot snap target. Whole-zone snap uses `target = 'zone'`; window-slot
  snap uses `target = 'window'` and existing intent-zone split/tab/swap
  behavior. Richer gesture editing, empty-space snapping, and persistence need
  their own slices with video proof.

## Product Semantics

Columnar layouts are the first product surface. They cover the ultrawide case without making users draw rectangles.

Required MVP behavior:

- A zone layout can be enabled per physical monitor.
- A column zone has a stable `id`, optional display `name`, and width ratio.
- Width ratios must sum to `1.0` within a small tolerance; otherwise config validation should fail with a concrete message.
- One zone can be marked as the physical monitor's default zone for compatibility commands.
- Zones are ordered left to right.
- Zones cannot overlap.
- Gaps and the physical sidebar are applied before zone rectangles are derived.
- A zone can be empty but selected, using the existing retained empty workspace behavior.

Deferred behavior:

- grid or rectangle layouts;
- automatic persistence or TOML write-back for every divider drag without an
  explicit `save-zone-layout`;
- per-zone sidebar panels;
- visual editor;
- direct tab-group-to-zone persistence beyond the workspace binding model.

Validation is not deferred. Build the Tart VM recording harness first, then require a short Tart video at the end of every slice. Fast behavior tests still come first inside each slice, but a slice is not done until it has a video artifact showing the current behavior in a real macOS desktop.

Slice progression rule:

- Slice 0 is the Tart recording harness. No product implementation is accepted before this harness can produce screenshots, a video, logs, and the config used for the run.
- Every later slice starts by naming its Tart scenario and expected video evidence.
- Every later slice ends by attaching the artifact directory and recording path to the slice notes before work starts on the next slice.
- Product slices must run in strict guest-control mode with guest display capture, using `WINMUX_E2E_REQUIRE_GUEST_CONTROL=1 WINMUX_E2E_CAPTURE_MODE=guest` or an equivalent scenario runner. A host-only recording can debug the harness, but it cannot satisfy a product slice.
- Product slice videos must be understandable from the recording alone. The final reviewed `recordings/<name>.mov` should include polished, legible caption overlays that explain the visible action in WinMux's restrained product style and expose the user-facing WinMux config, command, or action used for that step. Preserve the untouched guest capture under `recordings/raw/` for debugging.
- Every slice must then pass a no-context artifact review by a fresh subagent. The subagent must receive only the slice goal, artifact paths, baseline artifact paths, and product-surface references. It must not receive implementation history, the author's explanation, or prior review conclusions.
- Artifact review prompts must use `script/e2e/prompts/no-context-artifact-review.md`. Unclean desktop state, permission prompts, sshd prompts, unrelated windows, host-only product recordings, weak visual proof, and uninspected video frames are hard failures, not notes.
- After each accepted slice, run the three-agent no-context retrospection gate from `script/e2e/prompts/no-context-retrospection.md`. Bake accepted findings into the next slice as a pre-slice cleanup checklist.
- If the VM cannot be controlled reliably, the current slice is blocked. Do not replace the missing Tart video with manual notes.
- Do not proceed beyond a slice until the no-context artifact review and three-agent retrospection are done, and any blocking artifact/process issues are fixed or explicitly re-recorded.

## No-Context Artifact Review Gate

Each slice produces output artifacts for humans to judge, so each slice needs an independent review pass in addition to tests. The reviewer should approach the artifacts as a product reviewer, not as the implementing agent.

Baseline inputs:

- root demo videos: `demo.mp4`, `demo2.mp4`, `demo3.mp4`;
- local screenshots: `resources/screenshots/winmux-overview.png`, `resources/screenshots/tab-groups.png`;
- repo product surface: `README.md` and the GitHub README at `https://github.com/zimengxiong/winmux`;
- public product listing when reachable: `https://macoswm.com/wm/winmux`.

For each slice, spawn a no-context subagent with `fork_context=false`. Give it:

- the slice name and stated behavior;
- the artifact directory path;
- the exact recording and screenshot paths;
- the copied config path and relevant logs;
- the baseline inputs above;
- the product-surface URLs to refresh if network is available.

The subagent must verify:

- the video exists, is playable, has the requested duration, and shows the intended slice behavior;
- screenshots are non-empty and taken at meaningful checkpoints;
- logs prove strict guest control for product slices;
- the artifact content matches WinMux's product language: sidebar-first workspace visibility, tab groups, intent-zone/drag affordances, restrained macOS desktop presentation, and clear evidence of window-management behavior;
- caption overlays, when enabled, are legible, tasteful, specific to the current action, include the relevant user-facing command/config/action, and do not hide the behavior under review;
- the visual/stylistic choices do not drift from the root demo videos, screenshots, README, GitHub README, and public listing;
- the artifact would make sense to an end user reviewing the feature without reading the implementation notes.

The review output goes in the slice artifact directory as
`reviews/no-ctx-artifact-review.md`. The first nonblank line must start with
`PASS:`, `PASS_WITH_NOTES:`, or `FAIL:`. The final line must be exactly
`next slice allowed: yes` or `next slice allowed: no`.

Only `PASS:` or `PASS_WITH_NOTES:` with final line `next slice allowed: yes`
allows the next slice to start.

Use the prompt template in `script/e2e/prompts/no-context-artifact-review.md`.

Hard failures include:

- before screenshot or recording shows Terminal, sshd prompts, permission prompts, setup screens, widgets, notification banners, or unrelated windows after capture begins;
- product-slice recording is missing, too short, corrupt, host-only, or not inspected through video playback or representative frames;
- intended behavior is only present in logs and not visible in the media;
- caption overlays are missing when enabled, illegible, distracting, generic, omit the user-facing WinMux command/config/action, or obscure the windows/workspaces that prove the slice;
- live-window slices do not show live managed windows in the claimed zones;
- logs omit strict guest-control proof or show command failures that the scenario silently ignored.

Do not advance on a hard failure. Re-record the slice or fix the harness first.

## No-Context Retrospection Gate

After each accepted artifact review, run three fresh no-context subagents with
`fork_context=false` before starting the next slice. This is a process-quality
gate: the agents inspect repo files, the current diff, slice artifacts, failed
attempt directories, logs, media, and durable docs to find preventable failures
or cheaper proof paths. They do not inspect Codex/Orca session history unless
the coordinator explicitly requests forensic mode for a specific question.

Use the prompt template in `script/e2e/prompts/no-context-retrospection.md`.

The three perspectives are:

- process/plan: gates, ordering, user feedback, and whether the agent advanced too early;
- code/harness: brittle shell, missing assertions, retry failures, logs, and checks that should happen before Tart;
- artifact/product: whether the artifact-review prompt, screenshots, video, and baseline comparisons would catch visual or stylistic drift.

Coordinator rules:

- read all three reports before starting the next slice;
- convert accepted blocking findings into the next slice's "Pre-slice cleanup" checklist in this plan;
- complete that cleanup before the next Tart run;
- if a recommendation is rejected, record the reason in the slice notes.

## Mechanical Artifact Verifier

The mechanical verifier is a tripwire before the human-like artifact review. It does not replace media inspection.

Use:

```bash
make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-N-<timestamp>
make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-N-<timestamp> ARGS=--require-review
```

Root-demo packaging slices use a separate non-mutating check because they package
an already accepted Tart recording rather than producing a fresh guest run:

```bash
make e2e-verify-root-demo-check RUN_DIR=artifacts/e2e/slice-7-root-demo-<timestamp> ARGS=--require-review
```

The verifier must check:

- exactly one recording exists and is playable;
- decoded duration is at least 80% of the requested duration;
- decoded resolution matches the configured ultrawide Tart display unless an override is documented;
- product slices used `require_guest_control=1` and `capture_mode=guest`;
- when `annotate_recording=1`, annotation logs, caption timing, and the preserved raw capture exist;
- caption command/action chips are exact user-facing commands or config/action references, with placeholders rejected;
- immutable input config hashes match preflight when recorded;
- guest-control, privacy, clean-slate, capture-readiness, and recording logs show success;
- before/after screenshots exist;
- standard timeline samples and a contact sheet exist or can be generated;
- drag/action manifests include exact snap-target semantics, per-beat media,
  full-frame in-drag screenshots matching the recording resolution, and distinct
  hashes so stale or duplicate stills cannot satisfy pickup/path/hover proof;
- slice-specific proof logs satisfy that slice's behavioral invariants when the verifier knows the recording name;
- when `--require-review` is set, the review exists, its first nonblank line
  starts with `PASS:` or `PASS_WITH_NOTES:`, and its final line is
  `next slice allowed: yes`.

Gate order for every product slice:

1. Run the fast pre-Tart gate.
2. Run the Tart scenario.
3. Run `make e2e-verify-slice RUN_DIR=...`.
4. Locally inspect screenshots, standard samples, and contact sheet for obvious hard failures.
5. Run the no-context artifact review.
6. Run `make e2e-review-lint RUN_DIR=...` and tee the transcript to
   `logs/review-lint.log`.
7. Run `make e2e-verify-slice-check RUN_DIR=... ARGS=--require-review` and tee
   the transcript to `logs/post-review-verify.log` so the
   post-review gate cannot silently regenerate missing packet or sample files.
8. Run the three no-context retrospection agents.
9. Update this plan with slice result, accepted findings, and the next pre-slice cleanup checklist.
10. Run `make e2e-slice-closeout-check RUN_DIR=...` and tee the transcript to
    `logs/closeout-check.log`.
11. Start the next slice only after the checklist is complete.

Reusable pre-slice cleanup floor:

- Read the prior slice's no-context artifact review and all three retrospection
  reports before writing new scenario code.
- Carry accepted blockers into this plan as checked or unchecked cleanup items.
- Make the mechanical verifier fail for every accepted blocker that can be
  checked from artifacts or source logs.
- Add slice-specific review-packet checks before recording, not after a weak
  review passes.
- Re-run annotation preflight after changing captions or semantic samples.
- Keep demo copy state-neutral. Do not put initial zone names or future-state
  claims inside windows that later move across zones unless the live state board
  makes the current state unambiguous.
- If a command uses a relative selector such as `current`, `next`, or `prev`,
  expose the resolved target in visible demo state and logs.

Packaging-slice artifacts must still include enough stored evidence to verify
the root output and source provenance without chat history: source review
verdict, source capture mode, source guest-control flag, source recording hash,
root output hash, artifact-copy hash, duration, codec, pixel format, resolution,
samples, caption-boundary frames for transition demos, and a no-context review.

Documentation-only slices may reuse already accepted Tart-derived media instead
of producing a fresh recording. Their artifact directory must include the
reviewed docs snapshot, snapshot hash, referenced artifact paths, verifier
commands and results for the referenced media, review output, and a short
manifest under `logs/` that records the evidence chain without relying on chat
history.

## Terminology

Use these terms consistently in code and docs:

- Physical monitor: an actual `NSScreen`/display.
- Workspace viewport: any surface that can show an active workspace. This is a physical monitor when zones are disabled, or a zone when zones are enabled for that physical monitor.
- Zone monitor: a `Monitor` implementation backed by a sub-rectangle of a physical monitor.
- Zone id: user-facing stable identifier such as `left` or `main`.

The current global `monitors` API is used by workspace layout code. To keep the first implementation small, do not rename every call site up front. Instead introduce clearer helpers and then move call sites deliberately:

- `physicalMonitors`: the raw physical displays from AppKit.
- `workspaceViewports`: physical monitors expanded through the active zone topology.
- `monitors`: temporary compatibility alias for `workspaceViewports`.

After the feature settles, a cleanup can rename `monitors` to `workspaceViewports` where that improves readability.

## Core Invariants

### Physical and Zone APIs Must Be Separate

Most of the risk in the virtual-monitor approach comes from code that really means "physical display" but currently says "monitor".

Use workspace viewports for:

- workspace assignment and active workspace lookup;
- `Workspace.workspaceMonitor`;
- layout and window frame placement;
- directional focus across visible workspaces;
- move window/tab group to target viewport;
- list windows/workspaces when the user asks for workspace placement.

Use physical monitors for:

- reading `NSScreen.screens`;
- `mainMonitor`;
- `.secondary` monitor description semantics;
- native macOS focus optimization that checks physical monitor count;
- sidebar panel placement and sidebar width insets;
- physical monitor listing and display diagnostics;
- screen configuration observer/cache invalidation.

Mixed call sites need explicit handling:

- `MonitorDescription` should keep numeric monitor selectors physical for compatibility.
- Zone selectors should be explicit: `zone:left`, `focus-zone left`, `move-node-to-zone right`.
- Numeric monitor commands should select a physical display, then resolve to that display's last-focused zone or configured default zone. They should never mean "the Nth zone".
- Directional monitor focus can traverse workspace viewports once zones are enabled, because that is the ergonomic behavior on an ultrawide.
- `list-zones` is the canonical zone enumeration surface. During these implementation slices, `list-monitors` remains a legacy workspace-viewport listing because earlier proofs and scripts use it for zone geometry. New zone-specific scripts should prefer `list-zones`; a later cleanup can split `list-monitors` back to physical-only output without changing selector semantics.

### Config Must Not Be Read From Off-Main Monitor Computation

`config` is `@MainActor`, while `monitors` can currently compute fresh values off the main thread. Zone expansion must not reach into `config` from `computeMonitors()`.

Introduce a small topology store:

- `ZoneTopologySnapshot`: immutable, `Sendable`, derived from config on the main actor.
- `ZoneTopologyStore`: nonisolated read of the latest snapshot, updated when config loads or reloads.
- `computePhysicalMonitors()`: reads only AppKit screens.
- `workspaceViewports`: reads physical monitors and expands them through the snapshot.

On config reload or screen change, update the snapshot and invalidate monitor caches together. Off-main callers may read the last completed snapshot, but they must not touch main-actor config.

### Zone Identity Is Stable For Configured Zones

`MonitorViewportId` now carries a `stableIdentity` in addition to the current geometry point. Physical monitor viewports preserve the legacy top-left identity, while configured zone viewports use physical monitor identity plus stable zone id. This prevents width changes from remapping active workspaces while keeping physical-monitor hooks keyed to real display changes.

Keep these invariants intact:

- physical viewport id: top-left based id, preserving legacy behavior;
- zone viewport id: physical monitor identity plus stable zone id;
- optional namespace only if future scene/layout switching needs two different logical zones with the same id on one physical monitor;
- legacy decode path for existing top-left encoded viewport ids if any persisted state uses them;
- geometry lookups may still use the current point, but configured-zone durability must use the stable identity.

Future identity work should be compatibility-focused, not a prerequisite for config-backed zones.

### Sidebar Insets Are Physical By Default

The sidebar is a physical-monitor affordance, not one panel per zone.

For MVP:

- resolve sidebar panels against physical monitors;
- subtract the sidebar inset once from the physical monitor's visible rect;
- derive zone rectangles inside that remaining physical area;
- let the sidebar show zone/workspace sections for the physical monitor.

Do not treat every zone as a sidebar panel monitor. That would shrink every column by the sidebar width and make the feature feel broken on day one.

### Overlap Is Out of Scope For MVP

`monitorApproximation` and several workspace lookups assume a point maps cleanly to one monitor-like rectangle. Overlapping zones break that assumption.

MVP validation should reject overlapping zones. Grid/freeform layouts can be added later with an explicit hit-test priority policy.

## Implementation Slices

Compact slice inventory:

| Slice | Scope |
| --- | --- |
| 0 | Tart VM recording harness with clean desktop setup, screenshots, video, logs, and no-context artifact review. |
| 1 | Config-backed zone viewports proving one physical ultrawide can expose independent virtual-monitor workspaces. |
| 2 | User config for column zones, validation, and visible live windows in each configured zone. |
| 3 | Stable zone viewport identity across config reload and width changes. |
| 4 | Zone commands and selectors: focus and move nodes to named zones while preserving physical monitor command compatibility. |
| 5 | Sidebar zone sections and drag-to-zone UX, with corrected proof that sidebar drag snaps to a zone row. |
| 6A | Named zone layout presets plus `use-zone-layout` runtime switching. |
| 6B | Zone scenes that apply a layout preset and activate named workspaces per zone. |
| 7 | Root product demo packaging from accepted Tart-captured columnar-zone evidence. |
| 8 | Window detection rules route matching windows to zones through config. |
| 9 | User-facing columnar-zones docs tied to accepted video evidence. |
| 10 | Runtime zone availability: hide and restore one zone without losing its parked workspace. |
| 11A | Runtime zone sizing: `resize-zone`, `balance-zones`, layout cycling tests, and numeric geometry proof. |
| 11B | Runtime zone style tokens and visible sidebar row styling. |
| 11C | Availability sets and cross-zone availability commands for focus-only or communications-style layouts. |
| 12 | Initial mouse zone-snap policy, modifier-gated whole-zone drag, and freeform no-snap behavior. |
| 13 | Portable `alt-z` zone mode with relative selectors such as `current`, `next`, and `prev`. |
| 14 | Workspace-to-zone bindings through `[[zone-bindings]]` and `apply-zone-bindings`. |
| 15 | Runtime window/tab-group zone binding with `bind-node-to-zone` and `list-zone-bindings`. |
| 16 | Mouse snap affordance semantics, including visible proof that the target is a whole zone. |
| 17 | Node-binding guardrails and machine-safe `list-zone-bindings` output. |
| 18 | Durable zone affinity routing for newly detected matching windows. |
| 19 | Ergonomic `cycle-zone-style` command for compact keyboard workflows. |
| 20 | Runtime mouse snap policy switching without editing TOML. |
| 21 | Ergonomic zone mode v2, covering keyboard control for focus, move, layout, style, and availability. |
| 22 | Float-unless-snap mouse policy: ordinary drags stay floating unless snap activation is held. |
| 23 | Product whole-zone snap overlay label so the drag target is legible in-app. |
| 24 | Secondary-button mouse snap gesture for one-handed whole-zone snapping. |
| 25 | Hardened mouse demo artifact contract with trimmed demo cut, input-state cues, and strict review media. |
| 26 | Draggable zone dividers: drag a visible Work/Comms divider to update adjacent runtime widths only. |
| 27 | Window-slot snap target inside a zone, separate from whole-zone snapping. |
| 28 | Export the effective runtime zone layout as pasteable TOML after resize, balance, or divider drag. |
| 29 | Explicitly save the effective runtime zone layout back to config with reviewable backup, dry-run, and diff behavior. |
| 30 | Harness/review gate hardening for future product-bearing artifact contracts. |
| 31 | Relaunch-safe saved-layout showcase with product-shaped fixture, measurement chips, and demo cut. |
| 32 | Divider drag plus explicit save/relaunch proof for persisted dragged widths. |
| 33 | Scene cycling: one repeated command switches triage -> deep-work -> triage. |
| 34 | Ready-to-use scene binding showcase: `alt-tab` runs scene cycling through `trigger-binding`. |
| 35 | Starter ultrawide template: first-run config includes a commented, parse-tested zones setup and a Tart demo of uncommenting and validating it. |
| 36 | Current root demo refresh: package the accepted Slice 32 divider drag plus save/relaunch demo as `demo-columnar-zones.mp4`. |
| 37 | Starter template onboarding companion: document and demo enabling the ultrawide template from a companion config. |
| 38 | Normal user readiness walkthrough: prove the normal config path works without harness-only launch overrides. |
| 39 | Real dogfood install and permissions: install `/Applications/WinMux.app`, prepare permissions, run `doctor`, and relaunch normally. |
| 40 | Zone setup assistant: generate balanced ultrawide zones from a normal user config with dry-run, write, backup, and validation. |
| 41 | Beta-hardened app and window affinities: route newly detected windows into zones with dogfood-ready guardrails. |
| 42 | Zone availability and profile workflows: toggle zones and whole-layout availability profiles through user-facing commands. |
| 43 | Mouse gesture configurability: prove secondary-button and configurable gesture paths for whole-zone snap. |
| 44 | Drag overlay and snap semantics polish: make whole-zone snap overlays and release semantics visually unambiguous. |
| 45 | Multi-monitor, hotplug, and sleep/wake hardening: prove topology recovery and clearly mark deterministic Tart simulation boundaries. |
| 46 | Persistence, rollback, and config doctor: make saved zone layouts recoverable, auditable, and safe for beta testers. |
| 47 | Product UI and zone chrome polish: make current zone state readable without a heavy dashboard. |
| 48 | Support bundle and diagnostics: collect redacted zone/debug state for dogfood and beta reports. |
| 49 | Ultrawide zones documentation: turn accepted demos and commands into README/docs/sample configs users can follow. |
| 50 | Beta packaging and release candidate: build, package, verify, and document the beta install path. |
| 51 | Beta acceptance and dogfood soak: run the package through the end-to-end acceptance path and classify remaining blockers. |
| 52 | Sparkle auto-update channel: installed builds self-update from a signed appcast published by the release script. |
| 53 | Input latency and refresh diet: ordinary interactions and desktop clicks respond without a full AX refresh sweep. |
| 54 | Explicit zone resize affordance: divider dragging is gated behind zone mode, not always-on near boundaries. |
| 55 | Zone Exposé overview: Ctrl+Up and Ctrl+Down show a display or focused-zone overview from cached previews. |
| 56 | Domain model simplification: replace the conflated noun surface with Display > Scene > Column > Card plus Rules. |

Per-slice detail — goals, required scope, and the accepted acceptance
evidence for each slice as it shipped — lives in
`columnar-zones-history.md`. That archive is a historical record, not a
forward plan; the table above and the status section near the top of this
document are the evergreen summary.

## Call-Site Audit

The first implementation should touch these seams deliberately:

- `Sources/AppBundle/model/Monitor.swift`: physical monitor computation, `ZoneMonitor`, caches, `physicalMonitors`, `workspaceViewports`.
- `Sources/AppBundle/tree/WorkspaceIdentity.swift`: stable viewport identity.
- `Sources/AppBundle/tree/WinMuxWorkspaceState.swift`: viewport state keyed by stable ids.
- `Sources/AppBundle/tree/WorkspaceMonitorAssignment.swift`: rearrange viewports when zones appear/disappear.
- `Sources/AppBundle/tree/WorkspaceType.swift`: workspace monitor resolution.
- `Sources/AppBundle/model/MonitorEx.swift`: sidebar inset, monitor numbering, visible rect helpers.
- `Sources/AppBundle/model/MonitorDescriptionEx.swift`: physical `.secondary` semantics.
- `Sources/AppBundle/command/impl/FocusMonitorCommand.swift`: directional viewport focus vs numeric physical monitor focus.
- `Sources/AppBundle/command/impl/MoveNodeToMonitorCommand.swift`: compatibility and zone command reuse.
- `Sources/AppBundle/command/impl/ListMonitorsCommand.swift`: keep physical listing stable and add zone output elsewhere.
- `Sources/AppBundle/config/Config.swift` and `parseConfig.swift`: zone config model and parser.
- `Sources/AppBundle/ui/sidebar`: physical panel, zone sections, drag targets.
- `Sources/AppBundle/util/appBundleUtil.swift`: `monitorApproximation` remains valid only because zones do not overlap.

## Validation Strategy

Follow `testing-philosophy`: push as much proof as possible into fast deterministic tests, then use Tart only for behavior that needs a real macOS desktop. The Tart run is high-value evidence, but it should not be the first place parser, topology, or command bugs are discovered.

Validation layers:

- Pure or mostly pure tests for config parsing, zone topology expansion, identity, command resolution, and sidebar inset math.
- In-process command tests for focus and move behavior using the existing test tree and fake monitors.
- Manual smoke tests during early slices when the feature is still changing quickly.
- Tart VM video checks for every slice, starting with the harness itself.
- No-context artifact review for every slice, after the Tart artifact exists and before the next slice starts.

Unit tests:

- parse valid column zone config;
- reject duplicate zone ids on one monitor;
- reject invalid width sums;
- reject overlapping or empty generated rects;
- expand one physical monitor into ordered zone monitors;
- keep physical monitors unchanged when zones are disabled;
- keep `.secondary` and physical monitor count behavior physical;
- ensure sidebar inset is applied once per physical monitor;
- preserve active workspace assignment when a zone width changes but its id stays the same;
- move a workspace from one zone viewport to another without duplicating active workspace state.

Command tests:

- `focus-zone left` resolves a unique zone;
- duplicate bare zone ids require a physical qualifier;
- `focus-monitor 1` remains physical;
- directional focus traverses zone viewports in screen order;
- `move-node-to-zone` moves a focused tab group as a group.

Manual config checklist:

- run with no zones and verify behavior is unchanged;
- run with an explicit left/main/right `[[zones]]` config on an ultrawide;
- create or move windows into each zone;
- switch workspaces independently per zone;
- move a tab group from `main` to `right`;
- resize or reload config and verify active workspaces remain attached to zone ids;
- confirm sidebar width is not multiplied by the number of zones.

Tart e2e checklist:

- preflight confirms `TART_HOME` points at the external SSD-backed location;
- preflight records the Tart display size, and product slices use an ultrawide guest display unless a debug override is documented;
- VM boot and teardown are repeatable;
- host and guest clocks/log paths are captured so failures can be correlated;
- guest privacy permissions are prepared before guest screenshots or videos are captured;
- guest desktop state is cleaned before the first screenshot, and the resulting media is free of setup prompts, unrelated windows, widgets, and notification banners;
- guest `screencapture` is probed until it can produce a non-empty image before screenshots or videos start;
- screenshot capture works before each slice scenario starts;
- video recording starts before the first slice action and stops after the final screenshot;
- artifacts are copied to `artifacts/e2e/slice-N-<timestamp>/`;
- each scenario fails if expected windows are absent, zones are blank, or commands return errors;
- each slice video is watchable and shows the behavior added by that slice;
- drag or move-proof slices include action frames where the source item, target, and drop or hover path are visible enough for a reviewer to judge without relying on logs;
- each slice artifact directory contains `reviews/no-ctx-artifact-review.md`;
- the review result is `PASS` or `PASS_WITH_NOTES` before the next slice starts.

Do not use Tart as a substitute for the fast tests. Use it as the per-slice desktop proof: real Accessibility permissions, real window frames, real desktop rendering, and reviewable media.

Do not let the implementing agent self-certify artifacts. The no-context review is part of the gate because it catches mismatches a code-focused pass tends to miss: unclear demo framing, blank or visually noisy recordings, behavior that is technically present but not visible, or visuals that drift from WinMux's existing product demos.

## Risks

- Some code assumes `monitors.count == physical display count`. Fix physical-only call sites early and add tests for them.
- Stable zone identity is more invasive than the initial prototype. Do it before making zones user-facing.
- Sidebar scope types may be more monitor-shaped than they look. Keep the first UX to one physical panel with zone sections.
- Existing command names may make `monitor` and `zone` semantics confusing. Prefer explicit new zone commands rather than changing numeric monitor behavior.
- Freeform rectangles are tempting, but overlap and hit-testing make them a separate feature.

## Milestones

1. Tart harness boots from external SSD-backed storage, captures screenshots, records video, exports artifacts, and passes no-context artifact review.
2. Config-backed virtual monitor zones work with independent workspaces and have a Tart video plus no-context artifact review.
3. Zone config parses and validates column layouts and has a Tart video plus no-context artifact review.
4. Stable zone viewport ids survive config changes and have a Tart video plus no-context artifact review.
5. Zone commands make focus and movement ergonomic and have a Tart video plus no-context artifact review.
6. Sidebar shows zones without per-zone inset bugs and has a Tart video plus no-context artifact review.
7. A root-level demo video shows the columnar zone workflow end to end and passes no-context artifact review against the repo/product baselines.
8. Scenes and visual editing are designed on top of the stable model, with per-slice videos and no-context artifact reviews if they are split out.
9. Normal-user readiness proves the default config path and live commands without harness-only launch arguments.
10. Dogfood install and permissions prove a packaged app can launch cleanly on a fresh desktop.
11. Setup assistant, affinity routing, profiles, mouse gestures, drag overlays, hotplug handling, persistence, UI polish, and diagnostics are beta-hardened through Slices 40-48.
12. Documentation and sample configs are reviewed as their own artifact-producing slice.
13. A reproducible beta package is built, installed, launched, and reviewed with stored provenance.
14. Beta acceptance covers fresh install through support-bundle generation and records dogfood blockers before external testers use the fork.
15. Installed builds self-update through a Sparkle appcast published by the dogfood release script, proven by an in-place update recording.
