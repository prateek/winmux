# Columnar Zones Plan

Status: slices 0-48 accepted; Slices 49-51 planned
Base decision: zone == virtual monitor
Scope: make ultrawide monitors ergonomic by letting one physical display expose several named workspace viewports.

## Decision

WinMux should model a configured zone as a monitor-like workspace viewport, not as a new tiling container type inside one workspace.

That means a physical ultrawide can expose zones such as `left`, `main`, and `right`. Each zone gets its own active workspace, its own layout pass, and its own target for focus and move commands. A tab group is "bound to a zone" by living in the workspace currently shown in that zone. Moving the focused tab group to another zone moves that group to the target zone's active workspace instead of teaching tab groups about screen geometry.

This fits the current architecture because WinMux already treats monitors as independent workspace viewports:

- `MonitorViewportId` is the key used by workspace state.
- `Workspace.workspaceMonitor` resolves a workspace to a monitor-like viewport.
- `layoutWorkspace` lays out a workspace inside `workspaceMonitor.visibleRectPaddedByOuterGaps`.
- retained empty workspace slots already exist for monitor viewports.

The implementation should make zones feel like a first-class monitor surface to workspace code, while keeping physical-display code explicit.

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

### Zone Identity Must Become Stable Before User-Facing Config

`MonitorViewportId` is currently based on `rect.topLeftCorner`. That is good enough for a hardcoded spike, but it is too fragile for user-facing zones because changing a column width can change a zone's point and remap active workspaces.

Before shipping config-backed zones, add stable viewport identity:

- physical viewport id: current top-left based id, preserving legacy behavior;
- zone viewport id: physical monitor identity plus stable zone id;
- optional namespace only if future scene/layout switching needs two different logical zones with the same id on one physical monitor;
- legacy decode path for existing top-left encoded viewport ids if any persisted state uses them.

Keep the current point available for geometry lookups, but do not make it the durable identity for a configured zone.

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
| 1 | Hardcoded zone spike proving one physical ultrawide can expose independent virtual-monitor workspaces. |
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

### Slice 0: Tart Recording Harness

Goal: create the VM and recording pipeline before product work begins, so every later slice can produce evidence.

Build the Tart-based harness at `script/e2e/tart-recording-harness`, with Make targets for `e2e-preflight` and `e2e-smoke`. The harness should be able to:

- use an external SSD for VM storage by requiring or setting `TART_HOME`;
- fail early if the configured SSD path is missing, not mounted, or not writable;
- clone or restore a known base macOS VM image;
- install or stage the current WinMux build inside the VM;
- install a scenario-specific WinMux config;
- launch deterministic test apps or windows;
- prepare required macOS privacy permissions for guest-driven capture and automation;
- clean stale guest desktop state before the first screenshot, including setup prompts, notification banners, widgets, and stray app windows;
- drive WinMux commands through the CLI or socket;
- capture screenshots at named checkpoints;
- record a video of the scenario from inside the guest for strict/product runs;
- copy screenshots, videos, logs, and the config used for the run back to the host.

Expected artifacts:

- `artifacts/e2e/slice-0-<timestamp>/screenshots/*.png`
- `artifacts/e2e/slice-0-<timestamp>/recordings/*.mp4` or `.mov`
- `artifacts/e2e/slice-0-<timestamp>/logs/*.log`
- `artifacts/e2e/slice-0-<timestamp>/config/winmux.toml`

Exit criteria:

- preflight prints the VM name, Tart home, external disk free space, WinMux build path, config path, and artifact directory without booting the VM;
- a smoke scenario boots the VM from the external SSD-backed Tart home;
- product slices set a deterministic ultrawide Tart display, defaulting to `WINMUX_E2E_VM_DISPLAY=3440x1440px`;
- screenshot capture works before any zone code exists;
- guest `screencapture` readiness is probed before the first screenshot;
- video recording starts and stops reliably;
- video duration is checked by the harness;
- artifacts copy back to the host;
- the slice produces a short harness-smoke video;
- strict guest-control smoke passes against a controllable base image;
- strict guest-control smoke starts from a clean desktop with no `sshd` prompt, Terminal, System Settings, TextEdit, Photos, widgets, notification banners, boot screen, or setup screen visible after capture begins;
- logs prove guest privacy setup and clean-slate setup before capture begins;
- no-context artifact review compares the smoke artifacts against the baseline media and product surfaces before Slice 1 starts.

Use `script/e2e/configs/harness-smoke.toml` as the default config for Slice 0. Keep generated media under ignored `artifacts/e2e/` paths.

Slice 0 result:

- superseded unclean artifact: `artifacts/e2e/slice-0-20260623T194048Z` had a `PASS_WITH_NOTES` review, but it showed setup prompts and stray windows. It is kept only as historical evidence of the first harness pass.
- clean artifact directory: `artifacts/e2e/slice-0-20260623T201905Z`;
- recording: `artifacts/e2e/slice-0-20260623T201905Z/recordings/harness-smoke.mov`;
- review: `artifacts/e2e/slice-0-20260623T201905Z/reviews/no-ctx-artifact-review.md`;
- verdict: `PASS_WITH_NOTES`;
- notes to carry forward: product slices need longer and smoother recordings, visible WinMux sidebar behavior, visible zone/tab/workspace interactions, and more explicit logging of state files cleaned or confirmed absent.

### Slice 1: Hardcoded Zone Spike

Goal: prove that zones as virtual monitors work with the existing workspace and layout pipeline.

Add a temporary `WINMUX_ZONES_SPIKE=1` path that splits the main physical monitor into three non-overlapping columns.

Work:

- add private `ZoneMonitor` conforming to `Monitor`;
- add `physicalMonitors` and `workspaceViewports`;
- keep `monitors` as the workspace-viewport alias;
- sort zones left to right within their physical monitor;
- ensure `layoutWorkspace` receives zone rects;
- verify each zone can show a different workspace.

Exit criteria:

- disabled spike has no behavior change;
- enabled spike gives independent active workspaces per column;
- moving focus between columns works;
- moving a window or tab group to another column works through existing move-to-monitor plumbing or a small temporary helper;
- no sidebar width is subtracted more than once per physical monitor.
- Tart video gate: record the hardcoded three-column spike showing independent workspaces, focus movement, and window or tab-group movement.
- Artifact review gate: no-context subagent confirms the recording demonstrates the spike and matches the baseline product style before Slice 2 starts.

Slice 1 result:

- artifact directory: `artifacts/e2e/slice-1-20260623T211027Z`;
- recording: `artifacts/e2e/slice-1-20260623T211027Z/recordings/slice-1-zone-spike.mov`;
- proof: `artifacts/e2e/slice-1-20260623T211027Z/slice-1-zone-spike-proof.txt`;
- review: `artifacts/e2e/slice-1-20260623T211027Z/reviews/no-ctx-artifact-review.md`;
- verdict: `PASS_WITH_NOTES`;
- notes to carry forward: the artifact proves three zone viewports, focus traversal, and independent visible workspaces through CLI/TextEdit output on a clean ultrawide desktop. Slice 2 should add live windows in each zone and visible focus or movement cues so the recording reads less like a raw engineering proof.

### Slice 2: Config Model and Validation

Goal: turn the spike topology into parsed config without widening the feature.

Add config structs:

- `ZoneConfig`
- `ZoneColumnConfig`
- `ZoneLayoutKind.columns`
- `ZoneTopologySnapshot`

Parser validation:

- zone ids are required, unique per physical monitor, and command-safe;
- `monitor` resolves to one physical monitor selector;
- column widths are positive;
- widths either sum to `1.0` within tolerance or fail with a message;
- `default-zone`, when provided, must name one of the configured zones;
- computed zone rects are non-empty;
- computed zone rects do not overlap;
- zone ids do not collide across physical monitors unless commands require a physical qualifier.

Command ergonomics should allow bare ids only when they are unique. If the same zone id appears on multiple physical monitors, require a qualifier such as `1:left` or `monitor:1/left`.

Tart video gate: record the same three-column scenario driven by config, and include the config file in the artifact bundle.

Carry-forward artifact requirement from Slice 1: include visible windows in each zone, not only CLI/TextEdit proof. The recording should make the configured zones legible without reading logs.

Artifact review gate: no-context subagent confirms the recording makes config-backed columns clear to a viewer and matches the baseline product style before Slice 3 starts.

Slice 2 result:

- superseded artifact directory: `artifacts/e2e/slice-2-20260623T213058Z`; this proved live windows but accepted a no-op movement warning, so it is not the accepted Slice 2 artifact;
- accepted candidate artifact directory: `artifacts/e2e/slice-2-20260623T214656Z`;
- annotated recording: `artifacts/e2e/slice-2-20260623T214656Z/recordings/slice-2-config-zones.mov`;
- raw guest recording: `artifacts/e2e/slice-2-20260623T214656Z/recordings/raw/slice-2-config-zones.raw.mov`;
- annotation proof: `artifacts/e2e/slice-2-20260623T214656Z/logs/slice-2-config-zones.annotation.log` and `artifacts/e2e/slice-2-20260623T214656Z/logs/slice-2-config-zones.annotations.tsv`; the visible chips expose `Config: [[zones]] columns = left, main, right`, `Run: winmux focus-monitor Work`, `Run: winmux move-node-to-monitor Reference`, and `Run: winmux list-windows --monitor all`;
- contact sheet: `artifacts/e2e/slice-2-20260623T214656Z/screenshots/slice-2-config-zones.contact-sheet.jpg`;
- proof: `artifacts/e2e/slice-2-20260623T214656Z/slice-2-config-zones-proof.txt`;
- mechanical verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-2-20260623T214656Z` passed;
- review: `artifacts/e2e/slice-2-20260623T214656Z/reviews/no-ctx-artifact-review.md`;
- verdict: `PASS_WITH_NOTES`;
- annotated-media follow-up: after the first accepted artifact was hard to follow from video alone, the primary recording was post-produced with restrained lower-third captions plus command/action chips, the raw capture was preserved, no-context reviewers replaced the review with fresh `PASS_WITH_NOTES` verdicts, and `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-2-20260623T214656Z ARGS=--require-review` passed again;
- retrospection directory: `artifacts/e2e/retrospectives/slice-2-catchup-20260623T213058Z`;
- artifact claim: this artifact proves config-backed column geometry, strict named-target movement proof for left/right windows, focus traversal across configured zone names, and live windows in all three configured zones. It does not prove sidebar UX, tab groups, drag affordances, or stable viewport identity.

### Slice 3: Stable Viewport Identity

Goal: prevent config edits from scrambling active workspace assignment.

Change viewport identity before config-backed zones become the default path.

Work:

- add a stable viewport identity value to `Monitor` or to a helper used by `MonitorViewportId`;
- make physical monitor ids preserve existing top-left behavior;
- make zone monitor ids use physical monitor identity plus zone id;
- update `WinMuxWorkspaceState` and workspace assignment helpers to use stable viewport ids;
- keep geometry lookup explicit when code needs `topLeftCorner.monitorApproximation`;
- add migration/compat decode for existing `MonitorViewportId` values.

Tests should cover changing a zone width while keeping the same zone id. The active workspace should remain attached to that zone.

Tart video gate: record a config reload or width change where workspaces remain attached to the same zone ids.

Artifact review gate: no-context subagent confirms the recording makes stable zone identity visible enough to evaluate before Slice 4 starts.

Pre-slice cleanup before Slice 3 starts:

- [x] Read the three Slice 2 catch-up retrospection reports.
- [x] Harden the no-context artifact reviewer prompt with hard-fail rules for unclean desktop state, prompt windows, weak visual proof, host-only product capture, and uninspected video frames.
- [x] Add the recurring three-agent no-context retrospection gate to the plan and prompt templates.
- [x] Add a mechanical artifact verifier and run it on the accepted Slice 2 candidate artifact.
- [x] Add automatic contact-sheet generation for product recordings.
- [x] Add a fast pre-Tart gate for harness syntax, shell lint, and focused parser/topology/listing tests.
- [x] Remove Slice 2 numeric move fallback and re-record with strict named-target proof moves using `--fail-if-noop`.
- [x] Add fast parser tests for invalid zone ids, invalid widths, and duplicate exact monitor selectors.
- [x] Run and pass the Slice 2 no-context artifact review using the hardened prompt.
- [x] Run `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-2-20260623T214656Z ARGS=--require-review` after the review exists.
- [x] Add showcase-quality caption overlays to product recordings, preserve raw captures under `recordings/raw/`, update verifier/reviewer prompts, retrofit the accepted Slice 2 recording, rerun no-context artifact review, and rerun post-review verification.
- [x] Extend caption overlays so each slice step exposes the user-facing WinMux command, config, or action that achieves the visible behavior; retrofit the accepted Slice 2 recording again with command chips, rerun no-context artifact review, and rerun post-review verification.
- [x] Define Slice 3's exact Tart proof before implementation: stage three labeled windows in the original `left`/`main`/`right` config, write before logs for workspace, window, zone id, and viewport point, copy in a changed-width config, run `reload-config`, then write after logs proving the same workspace/window labels remain on the same zone ids while at least one viewport point changes.
- [x] Decide before Slice 3 whether duplicate monitor selectors that resolve to the same physical display through different descriptions, tiny-display empty rectangles, and stable-id migration are implemented now or explicitly deferred to Slice 3's identity work. Stable-id migration is in scope through legacy `MonitorViewportId` decode fallback. Cross-description duplicate selector detection and tiny-display empty-rect hardening are deferred unless they block this slice's stable identity proof.

Slice 3 result:

- failed artifact directory: `artifacts/e2e/slice-3-20260623T233026Z`; the guest proof and recording completed, but harness contact-sheet post-processing failed before the after screenshot. This run is superseded.
- accepted artifact directory: `artifacts/e2e/slice-3-20260623T234421Z`;
- annotated recording: `artifacts/e2e/slice-3-20260623T234421Z/recordings/slice-3-stable-identity.mov`;
- raw guest recording: `artifacts/e2e/slice-3-20260623T234421Z/recordings/raw/slice-3-stable-identity.raw.mov`;
- screenshots: `artifacts/e2e/slice-3-20260623T234421Z/screenshots/00-before-slice-3.png` and `artifacts/e2e/slice-3-20260623T234421Z/screenshots/99-after-slice-3.png`;
- proof: `artifacts/e2e/slice-3-20260623T234421Z/slice-3-stable-identity-proof.txt`;
- mechanical verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-3-20260623T234421Z` passed;
- no-context review: `artifacts/e2e/slice-3-20260623T234421Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS_WITH_NOTES`, `next slice allowed: yes`;
- post-review verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-3-20260623T234421Z ARGS=--require-review` passed;
- retrospectives: `artifacts/e2e/slice-3-20260623T234421Z/retrospectives/process-plan.md`, `code-harness.md`, and `artifact-product.md`;
- artifact claim: config reload changed zone geometry from `1032/1376/1032` to `688/2064/688` while the same live TextEdit windows, zone ids, and workspace ids stayed bound to `left`, `main`, and `right`.
- non-claims: this slice does not prove sidebar UX, tab groups, drag affordances, `focus-zone`, `move-node-to-zone`, or physical-monitor command compatibility.
- accepted note: the accepted artifact mutated `config/winmux.toml` in place, so the copied configs are not reliable before/after evidence in that historical artifact. The media and logs still prove the slice. Future reload runs preserve immutable `config/winmux.toml` and `config/winmux-shifted.toml`, mutate only `config/winmux-active.toml`, and record/verify config hashes.

### Slice 4: Commands and Selectors

Goal: make zones ergonomic without breaking monitor commands.

Pre-slice cleanup before Slice 4 starts:

- [x] Read all three Slice 3 retrospection reports.
- [x] Preserve immutable config inputs for future reload artifacts by using `config/winmux-active.toml` as the guest-mutated config.
- [x] Capture the after screenshot before recording post-processing so a contact-sheet or annotation failure cannot erase final-state visual evidence.
- [x] Fix contact-sheet generation with `-frames:v 1` so one tiled image is written to one `.jpg` path.
- [x] Add verifier rejection for `.DS_Store` artifact noise.
- [x] Add verifier checks for config hashes when preflight records them.
- [x] Add Slice 3-specific verifier checks for before/after monitor, window, workspace, and proof logs.
- [x] Reject placeholder command chips such as `...`, `<command>`, and `winmux <command>` in annotation plans.
- [x] Update the no-context artifact-review prompt to harden config-provenance checks for reload/config-change slices.
- [x] Update the no-context retrospection prompt to inspect slice guest scripts and config fixtures.
- [x] Record the Slice 3 result, accepted historical config-packaging note, and this Slice 4 cleanup checklist in the plan.
- [x] Define the Slice 4 proof storyboard before command implementation: exact commands, visible before/after checkpoints, strict `--fail-if-noop` movement proof, compatibility proof for `focus-monitor 1`, captions with exact command chips, and verifier assertions.
- [x] Add focused command-selector tests before the Slice 4 Tart run. `swift test --filter ZoneCommandTest` and `make e2e-pre-tart-checks` pass with parser, selector, physical-monitor compatibility, window move, tab-group move, and `list-zones` coverage.

Add:

- `focus-zone <zone>`
- `move-node-to-zone <zone>`
- `list-zones` for scripts and debugging;
- JSON output fields that include both physical monitor and zone id where relevant.

Deferred from this slice unless it blocks Tart proof: `move-workspace-to-zone <workspace> <zone>`. The existing workspace move command has monitor-assignment semantics that need a narrower design than the window/tab-group command path.

Preserve:

- `focus-monitor 1` targets physical monitor 1, focusing its last-focused zone or configured default zone;
- `move-node-to-monitor 1` moves to the last-focused/default zone on physical monitor 1 when zones are configured;
- `.secondary` means the second physical monitor, not the second zone;
- current configs without zones have no behavior change.

For tab groups, make `move-node-to-zone` move the nearest tab group when the focused node is inside a tab group; otherwise move the focused node using the same binding policy as monitor/workspace moves. Do not add zone geometry to `TilingContainer`.

Tart video gate: record `focus-zone`, `move-node-to-zone`, and the compatibility behavior for `focus-monitor 1`.

Slice 4 proof storyboard:

- Prepare three labeled TextEdit windows before the proof actions if possible, then capture a `01-ready-slice-4.png` checkpoint with windows visible in `Reference`, `Work`, and `Comms`.
- Caption 1: `Run: winmux focus-zone Reference`. The recording must visibly move focus to the left zone and log `focused-zone=left`.
- Caption 2: `Run: winmux focus-zone Work`. The recording must visibly return focus to the main zone and log `focused-zone=main`.
- Caption 3: `Run: winmux move-node-to-zone Comms --fail-if-noop`. The proof must start with a focused labeled window outside `Comms`, run a no-op-sensitive move, and show/log that the same window moved to zone id `right`.
- Caption 4: `Run: winmux focus-monitor 1`. The proof must show that physical monitor compatibility still targets the configured default or last-focused zone on physical monitor 1, not "zone number 1" as a separate physical display.
- Logs must include `slice-4-focus-zone.log`, `slice-4-move-node-to-zone.log`, `slice-4-focus-monitor-compat.log`, `slice-4-windows-before.log`, `slice-4-windows-after.log`, and `slice-4-zones.log`.
- Verifier assertions must require exact command chips, strict guest capture, successful focus/move command logs, at least one no-op-sensitive movement proof, and media checkpoints that correspond to the logged actions.

Artifact review gate: no-context subagent confirms the command workflow is understandable from the recording and stays consistent with WinMux's sidebar/tab/intent-zone positioning before Slice 5 starts.

Slice 4 result:

- stale artifact directory: `artifacts/e2e/slice-4-20260624T002446Z`; the command proof and recording completed, but the guest success marker was empty, so current verifier hardening supersedes this run.
- accepted artifact directory: `artifacts/e2e/slice-4-20260624T002907Z`;
- annotated recording: `artifacts/e2e/slice-4-20260624T002907Z/recordings/slice-4-zone-commands.mov`;
- raw guest recording: `artifacts/e2e/slice-4-20260624T002907Z/recordings/raw/slice-4-zone-commands.raw.mov`;
- screenshots: `00-before-slice-4.png`, `01-ready-slice-4.png`, `99-after-slice-4.png`, and `slice-4-zone-commands.contact-sheet.jpg`;
- proof: `artifacts/e2e/slice-4-20260624T002907Z/slice-4-zone-commands-proof.txt`;
- mechanical verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-4-20260624T002907Z` passed;
- no-context review: `artifacts/e2e/slice-4-20260624T002907Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS_WITH_NOTES`, `next slice allowed: yes`;
- post-review verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-4-20260624T002907Z ARGS=--require-review` passed;
- retrospectives: `artifacts/e2e/slice-4-20260624T002907Z/retrospectives/process-plan.md`, `code-harness.md`, and `artifact-product.md`;
- artifact claim: `list-zones`, `focus-zone Reference`, `focus-zone Work`, `move-node-to-zone Comms --fail-if-noop`, and physical `focus-monitor 1` compatibility are visible enough in the media and proven in logs under strict guest capture. The moved `move-demo.rtf` window keeps the same window id and moves from Work/main to Comms/right.
- accepted notes: the first focus caption starts before the managed windows are visible, so the first visual beat is weak. Future product slices must start proof captions from a prepared visible state and include better timeline samples.
- non-claims: this slice does not prove sidebar UX, drag targets, per-zone sidebar rendering, intent-zone hover behavior, or root-demo-level polish.

### Slice 5: Sidebar and Drag UX

Goal: make zones visible and usable from the sidebar.

Pre-slice cleanup before Slice 5 starts:

- [x] Read all three Slice 4 retrospection reports and keep the accepted blockers in this checklist.
- [x] Define the exact Slice 5 proof storyboard before UI implementation: sidebar-visible ready state, one chosen object type for drag or move proof, before/after logs, `01-ready-slice-5.png`, final screenshot, exact caption chips, and explicit non-claims.
- [x] Add a pre-record setup or ready-state phase so proof captions begin only after the sidebar and zone state they describe are visible.
- [x] Add standard sampled frames or an improved contact sheet that includes start, ready state, each caption/action boundary, and near-end final state for every product recording.
- [x] Strengthen `verify-artifact` so slice `.done` markers must contain `result=success`, not just non-empty content. The historical accepted Slice 3 artifact has a named exception; current Slice 3 reruns write `result=success`.
- [x] Keep artifacts free of Finder metadata before review handoff and rerun the verifier immediately after local media inspection.
- [x] Wire Slice 5 into the harness before Tart: Make target, guest script scaffold, sidebar-enabled config, harness action, annotation plan, verifier case, README, and prompt/doc updates.
- [x] Warm guest transport before recording so transient SSH/auth failures happen before proof captions start.
- [x] Add fast tests for `move-node-to-zone --fail-if-noop`, `--window-id`, no-zone failure paths, `zone:` selector execution, and `list-zones --count`/JSON output.
- [x] Add at least one pure sidebar scope test proving sidebar physical-monitor scope remains distinct from zone viewport scope.
- [x] Decide and document the `list-monitors` versus `list-zones` contract before further scripts depend on listing output.
- [x] Restore current-verifier reproducibility for the accepted Slice 3 baseline, or explicitly document a versioned historical exception before treating old artifacts as regression inputs.
- [x] Inventory untracked required Slice 4 files and commit or otherwise intentionally carry them forward before starting Slice 5. Committed in `6ee808e3`.
- [x] Replace the Slice 5 guest-script scaffold with the real idempotent setup/proof implementation before running `make e2e-slice-5`.

Work:

- keep one sidebar panel per configured physical monitor;
- add zone sections or a compact zone selector inside the panel;
- show which workspace is active in each zone;
- allow dragging a workspace, window, or tab group to a zone target;
- make sidebar monitor scope models distinguish physical monitor scope from zone viewport scope.

This slice should not add per-zone sidebars. If that becomes useful, add it later behind explicit config with a clear inset policy.

Tart video gate: record the sidebar showing zone/workspace state and a visible
drag into a zone target. The video must show source pickup, dragged proxy/path,
Comms zone-row hover highlight, release, and final placement. Logs alone and
final-placement-only media do not satisfy this slice.

Slice 5 proof storyboard:

- Use `script/e2e/configs/column-zones-sidebar.toml`, which enables one physical sidebar panel and the same `Reference`, `Work`, and `Comms` zones.
- Keep `00-before-slice-5.png` as the clean desktop proof before setup.
- Run setup before the reviewed recording: launch WinMux, open the sidebar, stage visible workspace/window state for all three zones, make one window item or tab-group item visible in the sidebar, and capture `01-ready-slice-5.png`.
- Record only the proof action after the ready screenshot. The chosen first proof object is a window sidebar item. Workspace and tab-group drags are explicitly deferred unless needed to implement the same target plumbing.
- Caption chips:
  - `Config: [workspace-sidebar] enabled = true`;
  - `Action: drag sidebar item move-demo.rtf`;
  - `Action: hover over Comms zone target`;
  - `Action: release on Comms zone target`;
  - `Run: winmux list-zones`;
  - `Run: winmux list-windows --monitor all`.
- Logs must include `slice-5-sidebar-state-before.log`, `slice-5-sidebar-action.log`, `slice-5-sidebar-state-after.log`, `slice-5-windows-before.log`, `slice-5-windows-after.log`, `slice-5-zones.log`, and `slice-5-sidebar-drag.proof-manifest.tsv`.
- The artifact must include in-drag screenshots `02-drag-pickup-slice-5.png`, `03-drag-path-slice-5.png`, and `04-drag-hover-comms-slice-5.png`.
- The verifier must prove the ready screenshot exists, the `.done` marker contains `result=success`, the sidebar logs list all three zone sections, the action targets `right`/Comms, the action log and manifest identify the snap target as the sidebar zone row and not a window within the zone, in-drag screenshots exist, hover lasts long enough to inspect the affordance, and the same object ends in the right zone.
- Non-claims: this slice does not add per-zone sidebars, freeform layouts, app routing rules, or scene switching.

Artifact review gate: no-context subagent confirms the sidebar zone UX is visible, legible, and consistent with the baseline screenshots before Slice 6 starts.

Accepted Slice 5 replacement result:

- artifact: `artifacts/e2e/slice-5-20260624T054827Z`;
- recording: `artifacts/e2e/slice-5-20260624T054827Z/recordings/slice-5-sidebar-drag.mov`;
- raw recording: `artifacts/e2e/slice-5-20260624T054827Z/recordings/raw/slice-5-sidebar-drag.raw.mov`;
- contact sheet: `artifacts/e2e/slice-5-20260624T054827Z/screenshots/slice-5-sidebar-drag.contact-sheet.jpg`;
- in-drag screenshots: `02-drag-pickup-slice-5.png`, `03-drag-path-slice-5.png`, and `04-drag-hover-comms-slice-5.png`;
- proof manifest: `artifacts/e2e/slice-5-20260624T054827Z/logs/slice-5-sidebar-drag.proof-manifest.tsv`;
- proof: `artifacts/e2e/slice-5-20260624T054827Z/slice-5-sidebar-drag-proof.txt`;
- no-context review: `artifacts/e2e/slice-5-20260624T054827Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS`, `next slice allowed: yes`;
- post-review verifier: `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-5-20260624T054827Z ARGS=--require-review` passed after the reviewer packet was regenerated with manifest-listed drag screenshot paths;
- retrospectives: `artifacts/e2e/slice-5-20260624T054827Z/retrospectives/process-plan.md`, `code-harness.md`, and `artifact-product.md`;
- failed correction attempt: `artifacts/e2e/slice-5-20260624T054533Z` failed before product proof during guest transport warm-up, which is now covered by `warmup-policy-self-test`.

What the accepted replacement proves:

- the sidebar exposes physical-monitor zone rows for `Reference`, `Work`, and `Comms`;
- the visible drag starts from the `move-demo.rtf` Work sidebar item, shows a dragged proxy/path, holds over the highlighted `Comms` zone row, releases onto that row, and ends with the same window id in the Comms/right zone;
- the snap/drop target is the sidebar zone row, not a window inside the destination zone and not the normal window intent-zone overlay;
- `move-demo.rtf` moves from `main` / workspace `2` to `right` / workspace `3`;
- the reviewed video is a strict guest-captured 3440x1440 Tart artifact with polished captions, preserved raw capture, and per-beat user-facing action chips.

Slice 5 replacement non-claims:

- no workspace-row drag proof, tab-group drag proof, per-zone sidebars, freeform layouts, app routing rules, scene switching, or visual editor behavior is claimed by this slice.

Slice 5 correction cleanup completed:

- [x] Hardened the no-context review prompt and reviewer packet so drag reviewers must name exact media files for source pickup, proxy/path, hover highlight, release/drop, and final placement.
- [x] Hardened `verify-artifact` so Slice 5 requires zone-row snap semantics, not-window snap semantics, a long hover beat, full-resolution distinct in-drag screenshots, and per-beat screenshot paths in the reviewer packet.
- [x] Added `warmup-policy-self-test` to the pre-Tart gate for the guest transport readiness policy that recovered from the observed SSH auth flake.
- [x] Reran the Slice 5 replacement Tart capture, manually inspected pickup/path/hover/final screenshots, reran the strict verifier, reran no-context artifact review, and ran all three no-context retrospections before closing the slice.

Superseded Slice 5 result:

- artifact: `artifacts/e2e/slice-5-20260624T013034Z`;
- recording: `artifacts/e2e/slice-5-20260624T013034Z/recordings/slice-5-sidebar-drag.mov`;
- raw recording: `artifacts/e2e/slice-5-20260624T013034Z/recordings/raw/slice-5-sidebar-drag.raw.mov`;
- contact sheet: `artifacts/e2e/slice-5-20260624T013034Z/screenshots/slice-5-sidebar-drag.contact-sheet.jpg`;
- proof: `artifacts/e2e/slice-5-20260624T013034Z/slice-5-sidebar-drag-proof.txt`;
- no-context review: `artifacts/e2e/slice-5-20260624T013034Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS_WITH_NOTES`, `next slice allowed: yes`, now superseded;
- post-review verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-5-20260624T013034Z ARGS=--require-review` passed;
- retrospectives: `artifacts/e2e/slice-5-20260624T013034Z/retrospectives/testing-artifact-gates.md`, `code-harness.md`, and `artifact-product.md`.

Why it is superseded:

- the video and review did not conclusively show the drag affordance in progress;
- the action was too fast and concentrated in the far-left sidebar;
- the reviewer inferred the drag from final placement and logs instead of proving source pickup, proxy/path, hover highlight, release, and snap semantics from frames;
- the artifact predates the manifest/in-drag-screenshot hardening.

What the superseded artifact still proves:

- the sidebar can show physical-monitor zone targets for `Reference`, `Work`, and `Comms`;
- the same `move-demo.rtf` window id moves from `main` / workspace `2` to `right` / workspace `3`;
- the reviewed video is a strict guest-captured 3440x1440 Tart artifact with polished captions and preserved raw capture.

### Slice 6: Presets, Scenes, and Freeform Layouts

Goal: add the behaviors inspired by StackWM, BentoBox, and BetterStage after the core model is stable.

Pre-slice cleanup before Slice 6 starts:

- [x] Read all three Slice 5 retrospection reports and keep accepted blockers in this checklist.
- [x] Centralize sidebar zone-target resolution into one helper that returns the resolved monitor, active workspace, and display name for a `WorkspaceSidebarDropTargetKind.zone`.
- [x] Add a fast multi-monitor sidebar zone-target test with duplicate zone ids across two physical monitors, proving panel filtering and zone resolution stay scoped to the intended physical monitor.
- [x] Replace or explicitly justify fixed sidebar drag coordinates for future drag proofs. Fixed points now require `logs/<recording>.proof-manifest.tsv` with source item, target row/zone, points, coordinate policy, caption chip, and before/after state logs.
- [x] Add a visible-action proof floor for future drag artifacts: drag manifests and reviewer prompts require source item, zone target/section, and drop or hover path in sampled full-frame action frames. Final placement alone is not enough.
- [x] Add a product-quality floor for new recordings: generated reviewer packets and prompts require clean desktop state, restrained concrete captions, full-frame legibility, and comparison against baseline WinMux media/product surfaces.
- [x] Consider a filled reviewer packet helper that prints artifact paths, baseline surfaces, required logs, review output path, and verifier command for the no-context reviewer.

Possible additions:

- named zone layouts per monitor;
- commands to switch a monitor between zone layouts;
- scenes that bind zone ids to workspace names;
- optional app/window rules that route new windows to a zone;
- grid layouts with row/column spans;
- visual editor for dragging zone dividers.

Do not start this slice until column zones pass the validation and sidebar tests.

Tart video gate: record layout switching or scene behavior introduced by this slice. If this slice is split later, each sub-slice keeps the same video gate.

Artifact review gate: no-context subagent confirms any new scene or layout UI reads as an extension of WinMux rather than a separate product.

Slice 6A scope:

- Add top-level `[[zone-layouts]]` presets with stable ids, layout kind, default zone, and columns.
- Let `[[zones]]` choose a preset with `layout-preset = '<id>'`.
- Reject configs that combine `layout-preset` with inline `layout`, `default-zone`, or `columns`, and reject missing preset references.
- Add `use-zone-layout [--monitor <monitor-pattern>] <layout-id>` as a runtime switch. The command targets the focused physical monitor by default and does not rewrite the config file.
- Add `%{monitor-zone-layout-id}` so `list-zones` can prove which preset is active.
- Keep scene binding, app rules, grid/freeform layouts, and visual editing deferred.

Slice 6A Tart storyboard:

- Use `script/e2e/configs/zone-layout-presets.toml`, with `balanced` and `focus` presets on monitor 1.
- Run setup before the reviewed recording: launch WinMux, place live TextEdit windows into `Reference`, `Work`, and `Comms`, confirm `balanced`, and capture `01-ready-slice-6.png`.
- Record only the proof action after the ready screenshot. The proof command is `winmux use-zone-layout focus`.
- Caption chips:
  - `Config: [[zone-layouts]] balanced + focus`;
  - `Run: winmux use-zone-layout focus`;
  - `Run: winmux list-zones --format '%{monitor-zone-id}|%{monitor-zone-layout-id}'`;
  - `Run: winmux list-windows --monitor all`.
- Logs must include `slice-6-layout-before.log`, `slice-6-use-zone-layout.log`, `slice-6-layout-after.log`, `slice-6-windows-before.log`, and `slice-6-windows-after.log`.
- The verifier must prove the `.done` marker contains `result=success`, the ready screenshot exists, the layout id changes from `balanced` to `focus`, the Work/main width grows while Reference/Comms shrink, and the same TextEdit window ids remain in the same zone ids and workspaces.
- Non-claims: this sub-slice does not add scenes, app routing rules, grid/freeform layouts, draggable dividers, or a visual editor.

Accepted Slice 6A result:

- artifact: `artifacts/e2e/slice-6-20260624T021954Z`;
- recording: `artifacts/e2e/slice-6-20260624T021954Z/recordings/slice-6-zone-layout-presets.mov`;
- raw recording: `artifacts/e2e/slice-6-20260624T021954Z/recordings/raw/slice-6-zone-layout-presets.raw.mov`;
- screenshots: `00-before-slice-6.png`, `01-ready-slice-6.png`, `99-after-slice-6.png`, and `slice-6-zone-layout-presets.contact-sheet.jpg`;
- proof: `artifacts/e2e/slice-6-20260624T021954Z/slice-6-zone-layout-presets-proof.txt`;
- mechanical verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-6-20260624T021954Z` passed;
- no-context review: `artifacts/e2e/slice-6-20260624T021954Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS`, `next slice allowed: yes`;
- post-review verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-6-20260624T021954Z ARGS=--require-review` and the same command with an absolute `RUN_DIR` both passed;
- retrospectives: `artifacts/e2e/slice-6-20260624T021954Z/retrospectives/process-plan.md`, `code-harness.md`, and `artifact-product.md`;
- accepted post-production note: the artifact was re-annotated from its preserved raw guest capture to fix command-chip clipping and ImageMagick `%{...}` interpolation, then re-sampled, re-reviewed, and reverified.

What the accepted artifact proves:

- top-level `[[zone-layouts]]` presets can define reusable `balanced` and `focus` column layouts;
- a monitor configured with `layout-preset = 'balanced'` starts with the balanced geometry;
- `winmux use-zone-layout focus` switches the current physical monitor to the `focus` preset at runtime;
- `list-zones --format '%{monitor-zone-id}|%{monitor-zone-layout-id}'` exposes the active layout id;
- the same TextEdit window ids remain in the same zone ids and workspaces while Work grows and Reference/Comms shrink.

Slice 6A non-claims:

- no scene binding, app routing rules, grid/freeform layouts, draggable dividers, visual editor, sidebar UX, or tab-group UI behavior beyond stable window bindings.

Pre-slice cleanup before the next slice starts:

- [x] Read all three Slice 6A retrospective reports and keep accepted blockers in this checklist.
- [x] Close Slice 6A in this plan with artifact paths, verifier/review evidence, retrospectives, claims, and non-claims.
- [x] Commit or intentionally inventory all required Slice 6A source, harness, config, guest-script, test, prompt, and doc files before starting the next slice.
- [x] Add a cheap annotation render preflight to `make e2e-pre-tart-checks` so caption clipping/interpolation failures are caught before Tart.
- [x] Align Slice 6A's visible command chip with the actual layout-id proof command and re-run artifact review on the final video.
- [x] Decide and test the `use-zone-layout` inline-zone behavior. The accepted contract is that a runtime preset can override any zone-enabled physical monitor, including monitors configured with inline columns.
- [x] Add prompt guidance that no-context retrospection agents should not run repair-capable artifact commands unless explicitly asked.
- [x] Make reviewer packets mark drag proof manifests as not applicable for non-drag slices.
- [x] Name the next slice's exact proof target, storyboard, expected logs, screenshots, caption chips, verifier assertions, and non-claims before its Tart run.
- [x] For the next layout/scene/freeform recording, avoid stale final-state labels such as documents that still say `Balanced preset` after switching away from balanced.
- [x] For the next transition recording, add explicit before/action/after media anchors to the storyboard and verifier/reviewer handoff so samples cannot skip the actual switch moment.
- [x] Add or explicitly run relative and absolute `RUN_DIR` verifier coverage for reviewer-packet paths before the next Tart run.
- [x] Add a non-mutating artifact verifier mode so report-only agents can validate existing outputs without generating samples or reviewer packets.

Slice 6B scope:

- Add top-level `[[zone-scenes]]` with stable ids, a `layout-preset`, and per-zone workspace bindings.
- Add `use-zone-scene [--monitor <monitor-pattern>] <scene-id>` as a runtime switch. The command targets the focused physical monitor by default, creates missing named workspaces, applies the scene layout preset, and activates the configured workspace in each zone.
- Reject scenes with missing ids, missing layout presets, unknown layout presets, missing or duplicate zone bindings, empty workspace names, or zone ids that are not present in the referenced layout preset.
- Keep app/window routing rules, grid/freeform layouts, draggable dividers, and visual editing deferred.

Slice 6B Tart storyboard:

- Use `script/e2e/configs/zone-scenes.toml`, with `balanced` and `focus` layouts and `triage` plus `deep-work` scenes.
- Setup before the reviewed recording: launch WinMux, stage live TextEdit windows named for the `triage` scene in `Triage Inbox`, `Triage Draft`, and `Triage Updates`, stage separate windows named for the `deep-work` scene in `Focus Queue`, `Focus Build`, and `Focus Notes`, activate `triage`, and capture `01-ready-slice-6b.png`.
- Record a clean before/action/after transition. The proof command is `winmux use-zone-scene deep-work`.
- Avoid stale labels: all visible document titles and contents must name either the active `triage` scene before the action or the active `deep-work` scene after it.
- Caption chips:
  - `Config: [[zone-scenes]] triage + deep-work`;
  - `Action: before scene = triage`;
  - `Run: winmux use-zone-scene deep-work`;
  - `Action: after scene = deep-work`;
  - `Run: winmux list-zones --format '%{monitor-zone-id}|%{monitor-active-workspace}'`;
  - `Run: winmux list-windows --workspace visible`.
- Logs must include `slice-6b-scene-before.log`, `slice-6b-use-zone-scene.log`, `slice-6b-scene-after.log`, `slice-6b-windows-before.log`, `slice-6b-windows-after.log`, `slice-6b-zone-scene.done`, and `slice-6b-zone-scene-proof.txt`.
- The verifier must prove the `.done` marker contains `result=success`, the ready screenshot exists, the action caption rows exist, the layout id changes from `balanced` to `focus`, the active workspaces change from the `triage` workspace set to the `deep-work` workspace set, the Work/main zone grows, and the visible TextEdit window titles after the action belong to the `deep-work` scene in the expected zones.
- Non-claims: this sub-slice does not add app routing rules, grid/freeform layouts, draggable dividers, visual editor, sidebar UX changes, or automatic tab-group rules beyond making zone scene workspace bindings first-class.

Accepted Slice 6B result:

- failed setup artifact: `artifacts/e2e/slice-6b-20260624T031738Z`; setup retried the same semantic state failure because inactive deep-work windows were still visible in the triage-ready window log. This run is superseded.
- failed review artifact: `artifacts/e2e/slice-6b-20260624T033255Z`; state logs and final media were correct, but the scene switched before the `Run: winmux use-zone-scene deep-work` caption, so the before/action/after video was out of order. This run is superseded.
- accepted artifact: `artifacts/e2e/slice-6b-20260624T034817Z`;
- recording: `artifacts/e2e/slice-6b-20260624T034817Z/recordings/slice-6b-zone-scenes.mov`;
- raw recording: `artifacts/e2e/slice-6b-20260624T034817Z/recordings/raw/slice-6b-zone-scenes.raw.mov`;
- screenshots: `00-before-slice-6b.png`, `01-ready-slice-6b.png`, `99-after-slice-6b.png`, and `slice-6b-zone-scenes.contact-sheet.jpg`;
- proof: `artifacts/e2e/slice-6b-20260624T034817Z/slice-6b-zone-scene-proof.txt`;
- mechanical verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-6b-20260624T034817Z` passed;
- no-context review: `artifacts/e2e/slice-6b-20260624T034817Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS`, `next slice allowed: yes`;
- post-review verifier: `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-6b-20260624T034817Z ARGS=--require-review` and `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-6b-20260624T034817Z ARGS=--require-review` passed;
- retrospectives: `artifacts/e2e/slice-6b-20260624T034817Z/retrospectives/process-plan.md`, `code-harness.md`, and `artifact-product.md`.

What the accepted artifact proves:

- top-level `[[zone-scenes]]` entries can bind a named zone layout preset to per-zone workspace names;
- `winmux use-zone-scene deep-work` applies the `focus` layout and activates `FocusQueue`, `FocusBuild`, and `FocusNotes` in the left, main, and right zones;
- the visible TextEdit documents change from triage documents to deep-work documents under strict guest capture;
- `list-zones --format '%{monitor-zone-id}|%{monitor-active-workspace}'` exposes the active workspace in each zone, and `list-windows --workspace visible` proves only the deep-work TextEdit documents are visible after the switch.

Slice 6B non-claims:

- no app/window routing rules, grid/freeform layouts, draggable dividers, visual editor, sidebar UX changes, or automatic tab-group rules.

Pre-slice cleanup before the next slice starts:

- [x] Read all three Slice 6B retrospective reports and keep accepted blockers in this checklist.
- [x] Close Slice 6B in this plan with artifact paths, verifier/review evidence, retrospectives, claims, non-claims, and failed-attempt notes.
- [x] Align the Slice 6B storyboard with the accepted command chips, especially `Run: winmux list-windows --workspace visible`.
- [x] Commit or intentionally inventory all required Slice 6B source, harness, config, guest-script, test, prompt, and doc files before adding new slice changes.
- [x] Add semantic-failure handling for stateful guest scenarios so invariant failures stop retries instead of replaying a half-mutated VM state.
- [x] Generate caption-boundary sample frames and require them in check-only verification so transition timing is inspectable before no-context review.
- [x] Update the shared no-context artifact-review prompt with Slice 6A and Slice 6B checks, plus guidance to inspect generated boundary frames.

### Slice 7: Root Columnar Demo

Goal: add a root-level product demo video that shows the columnar zone workflow
end to end.

This slice does not add new product behavior. It packages an already accepted
strict Tart recording into a tracked repo-root demo video, then runs a fresh
no-context product/artifact review against the root demo, baseline videos,
screenshots, README, GitHub README, and public listing.

Pre-slice cleanup before Slice 7 starts:

- [x] Read all three Slice 6B retrospective reports and keep accepted blockers in this checklist.
- [x] Use the accepted Slice 6B artifact as the source so the root demo inherits a strict guest-captured Tart proof instead of a host-only recording.
- [x] Keep root-demo packaging repeatable with a script/Make target rather than a one-off ffmpeg command.
- [x] Update the no-context artifact-review prompt with Slice 7-specific rules for repo-root videos.

Slice 7 scope:

- Add `demo-columnar-zones.mp4` at the repo root.
- Add `script/e2e/package-root-demo` and `make e2e-package-root-demo`.
- Require the source artifact to have an accepted no-context review, `require_guest_control=1`, `capture_mode=guest`, successful guest screencapture proof, and a playable 3440x1440 recording.
- Generate a Slice 7 packaging artifact under `artifacts/e2e/slice-7-root-demo-<timestamp>/` with ffprobe metadata, hashes, sample frames, contact sheet, and a no-context reviewer packet.
- Run a fresh no-context artifact review with `fork_context=false` before treating the root demo as accepted.

Slice 7 proof source:

- source artifact: `artifacts/e2e/slice-6b-20260624T034817Z`;
- source recording: `artifacts/e2e/slice-6b-20260624T034817Z/recordings/slice-6b-zone-scenes.mov`;
- source review: `artifacts/e2e/slice-6b-20260624T034817Z/reviews/no-ctx-artifact-review.md`, verdict `PASS`.

Slice 7 review requirements:

- inspect the generated root `demo-columnar-zones.mp4` directly;
- compare it against `demo.mp4`, `demo2.mp4`, `demo3.mp4`, `resources/screenshots/winmux-overview.png`, `resources/screenshots/tab-groups.png`, `README.md`, the GitHub README, and the public product listing when reachable;
- confirm the root demo is legible and stylistically compatible with WinMux's existing root demos;
- confirm the source package log proves strict guest capture and accepted source review;
- confirm the video shows the triage scene before `winmux use-zone-scene deep-work` and the deep-work scene after it;
- confirm the root demo makes no claims about sidebar drag UX, app routing rules, freeform layouts, draggable dividers, or visual editing.

Non-claims:

- this slice does not add new commands, config, sidebar behavior, tab-group routing, app rules, freeform layouts, draggable dividers, or visual editing;
- this slice packages an accepted Tart artifact, so it does not boot a fresh Tart VM unless the source artifact is replaced.

Accepted Slice 7 result:

- root demo: `demo-columnar-zones.mp4`;
- artifact directory: `artifacts/e2e/slice-7-root-demo-20260624T042021Z`;
- artifact recording copy: `artifacts/e2e/slice-7-root-demo-20260624T042021Z/recordings/demo-columnar-zones.mp4`;
- package log: `artifacts/e2e/slice-7-root-demo-20260624T042021Z/logs/root-demo-package.log`;
- ffprobe metadata: `artifacts/e2e/slice-7-root-demo-20260624T042021Z/logs/root-demo.ffprobe.json`;
- samples and boundary frames: `artifacts/e2e/slice-7-root-demo-20260624T042021Z/screenshots/demo-columnar-zones.samples/`;
- root demo SHA-256: `bd772ca45ffa9706ed21096d85c2ba2a93555b3f31c7d7dad9f9fdf284ad63ba`;
- media summary: H.264 High profile, `yuv420p`, 3440x1440, 41.983333s, 1747 frames;
- source artifact: `artifacts/e2e/slice-6b-20260624T034817Z`, source review verdict `PASS`, `require_guest_control=1`, `capture_mode=guest`;
- package verifier: `make e2e-verify-root-demo-check RUN_DIR=artifacts/e2e/slice-7-root-demo-20260624T042021Z ARGS=--require-review` passed;
- no-context review: `artifacts/e2e/slice-7-root-demo-20260624T042021Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS_WITH_NOTES`, `next slice allowed: yes`;
- retrospectives: `artifacts/e2e/slice-7-root-demo-20260624T042021Z/retrospectives/process-plan.md`, `code-harness.md`, and `artifact-product.md`.

What the accepted artifact proves:

- the repo-root `demo-columnar-zones.mp4` is a playable, root-showcase-ready columnar-zones demo;
- the video packages the accepted strict guest-captured Slice 6B scene workflow, with provenance back to the Tart run and source review;
- the demo shows triage documents before `winmux use-zone-scene deep-work`, then deep-work documents after it;
- root-demo caption-boundary samples preserve the command timing evidence that caught the earlier Slice 6B review failure.

Accepted notes:

- `demo-columnar-zones.mp4` is a supplemental columnar-zones/scene-switching demo. It should not replace the existing sidebar/tab-group/product demos or be described as proving sidebar drag UX, app routing, freeform layouts, draggable dividers, tab groups, or visual editing.
- The no-context reviewer noted that `demo-columnar-zones.mp4` must be added to git before it can actually publish as a root showcase asset. That is part of the Slice 7 commit scope.

Slice 7 non-claims:

- no new commands, config semantics, sidebar behavior, tab-group routing, app/window routing, grid/freeform layouts, draggable dividers, or visual editor.

Pre-slice cleanup before the next slice starts:

- [x] Read all three Slice 7 retrospective reports and keep accepted blockers in this checklist.
- [x] Close Slice 7 in this plan with artifact paths, root demo path, package provenance, verifier/review evidence, retrospectives, claims, non-claims, and accepted notes.
- [x] Add and run a non-mutating root-demo package verifier.
- [x] Preserve root-demo transition timing evidence by generating root MP4 caption-boundary frames from the source annotation plan.
- [x] Add a `package-root-demo --self-test` fixture check and wire it into `make e2e-pre-tart-checks`.
- [x] Clarify that `script/e2e/package-root-demo --source-run-dir` expects a Slice 6B-compatible source artifact unless the packager is generalized later.
- [x] Add `demo-columnar-zones.mp4` and the Slice 7 harness/docs changes to the next commit before starting new slice work.
- [x] Before the next stateful guest scenario, confirm semantic invariant failures exit with `WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT` and do not retry against mutated state.
- [x] Before the next Tart transition slice, write exact before/action/after timing into the storyboard and verifier/reviewer handoff.

### Slice 8: Window Rules Route To Zones

Goal: make automatic routing ergonomic by proving that existing
`[[on-window-detected]]` rules can send matching windows to a named zone with
`move-node-to-zone`.

This slice should not add a second app-rule DSL. The end-user shape is:

```toml
[[on-window-detected]]
if.window-title-regex-substring = 'route-comms'
run = ['move-node-to-zone Comms --fail-if-noop']
```

The rule runs with `WINMUX_WINDOW_ID` set by the existing window-detected hook,
so `move-node-to-zone` targets the detected window instead of relying on global
focus.

Pre-slice cleanup before Slice 8 starts:

- [x] Confirmed `guest_script_retry` stops immediately when a guest script exits with `WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT`, and Slice 6B already uses that pattern for stateful proof assertions.
- [x] Define the exact before/action/after timing before implementation: ready state from 0-8s, open routed window at 16s, automatic rule movement visible by 28s, final inspection by 36s.
- [x] Keep this as an `on-window-detected` plus `move-node-to-zone` workflow unless implementation proves the existing hook cannot target `WINMUX_WINDOW_ID` reliably.

Slice 8 scope:

- Add a config fixture with `[[on-window-detected]]` routing a new TextEdit document whose title matches `route-comms` to the `Comms` zone.
- Add focused parser/command behavior tests proving `move-node-to-zone` works when the target window is supplied by command environment, the same way `on-window-detected` invokes callback commands.
- Add a Tart scenario that starts from visible `Reference`, `Work`, and `Comms` zones, opens the matching document while Work is active, and proves the matching window is automatically moved to Comms/right.
- Add mechanical verifier checks for the rule config, before/action/after window logs, no manual move command in the recorded proof action log, and exact caption chips.
- Keep a clean non-claim boundary: no new app-rule DSL, no background daemon, no visual editor, no freeform layouts, and no tab-group-specific routing beyond routing the detected window.

Slice 8 Tart storyboard:

- Use `script/e2e/configs/zone-window-routing.toml`.
- Setup before the reviewed recording: launch WinMux with three configured zones, stage persistent visible windows in Reference, Work, and Comms, focus Work, confirm no `route-comms.rtf` window is visible, and capture `01-ready-slice-8.png`.
- Record a clean before/action/after transition. The proof action is opening `route-comms.rtf`; the config rule should move that new window to Comms/right without a manual move command.
- Captions:
  - `Config: [[on-window-detected]] move-node-to-zone Comms --fail-if-noop`;
  - `Action: before route, Work is active`;
  - `Run: open -a TextEdit route-comms.rtf`;
  - `Action: rule moved route-comms.rtf to Comms`;
  - `Run: winmux list-windows --workspace visible`;
  - `Run: winmux list-zones`.
- Logs must include `slice-8-routing-setup.log`, `slice-8-routing-before.log`, `slice-8-open-routed-window.log`, `slice-8-routing-after.log`, `slice-8-zones.log`, `slice-8-window-routing.done`, and `slice-8-window-routing-proof.txt`.
- The verifier must prove the `.done` marker contains `result=success`, the ready screenshot exists, the config contains the `on-window-detected` rule, the before log has no `route-comms.rtf`, the open/action log shows the user-facing `open -a TextEdit route-comms.rtf` action and no manual `move-node-to-zone` command, the after log shows `route-comms.rtf` in `right`/Comms, and the annotation plan has the exact config/action/listing chips.

Artifact review gate: no-context subagent confirms the recording makes automatic rule-based routing visible without reading code, and that it stays visually consistent with the existing product demos and Slice 7 root demo.

Slice 8 non-claims:

- no new rule language beyond `on-window-detected`;
- no app bundle id routing proof unless the title-based proof fails and the slice is revised;
- no tab-group-specific automatic routing, app launch management, grid/freeform layouts, draggable dividers, or visual editor.

Slice 8 accepted artifact:

- artifact directory: `artifacts/e2e/slice-8-20260624T045815Z`;
- primary recording: `artifacts/e2e/slice-8-20260624T045815Z/recordings/slice-8-window-routing.mov`;
- raw recording: `artifacts/e2e/slice-8-20260624T045815Z/recordings/raw/slice-8-window-routing.raw.mov`;
- screenshots: `00-before-slice-8.png`, `01-ready-slice-8.png`, `99-after-slice-8.png`, and `slice-8-window-routing.contact-sheet.jpg`;
- proof file: `artifacts/e2e/slice-8-20260624T045815Z/slice-8-window-routing-proof.txt`;
- copied config hash: `ce33a9318783a481f0753d57152decbc758f1dcf9e7d9917f46069e1880f8be2`;
- media metadata: H.264, 3440x1440, 43.983333s, 1949 frames.

Verification:

- `swift test --filter 'ZoneCommandTest/testMoveNodeToZoneUsesEnvironmentWindowId|ConfigTest/testParseOnWindowDetectedZoneRouting'` passed after rerunning the parser test with its real `ConfigTest/...` XCTest filter.
- `make e2e-pre-tart-checks` passed, including shell syntax/lint, package-root self-test, annotation preflight, and 50 focused Swift tests.
- `TART_HOME=/Volumes/RiftTartVMs make e2e-slice-8` passed and deleted the temporary Tart VM.
- `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-8-20260624T045815Z` passed.
- `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-8-20260624T045815Z ARGS=--require-review` passed after no-context review.
- review: `artifacts/e2e/slice-8-20260624T045815Z/reviews/no-ctx-artifact-review.md`, verdict `PASS_WITH_NOTES`, `next slice allowed: yes`.
- retrospectives:
  - `artifacts/e2e/slice-8-20260624T045815Z/retrospectives/process-plan.md`;
  - `artifacts/e2e/slice-8-20260624T045815Z/retrospectives/code-harness.md`;
  - `artifacts/e2e/slice-8-20260624T045815Z/retrospectives/artifact-product.md`.

What the accepted artifact proves:

- a user can configure a title-matching `[[on-window-detected]]` rule that runs `move-node-to-zone Comms --fail-if-noop`;
- `move-node-to-zone` can target the detected window through the command environment instead of relying on global focus;
- the recording starts with Reference, Work, and Comms anchor windows, Work active, and no `route-comms.rtf`;
- the recorded proof action is `open -a TextEdit route-comms.rtf`;
- after the action, `route-comms.rtf` is visible in the Comms/right zone without a recorded manual move command.

Accepted notes:

- The accepted artifact contains transient pre-proof transport/TCC retry noise: `guest-privacy-setup.log` retried after a locked TCC database and an SSH auth failure, and `slice-8-run.log` retried once after an SSH auth failure before the guest proof script ran. The final guest-control, privacy, clean-slate, capture, annotation, and scenario logs all report success, and the reviewer accepted the noise as non-blocking.
- The accepted primary caption chip abbreviated the rule as `move-node-to-zone Comms` while the copied config and proof include `--fail-if-noop`. This artifact is a documented historical exception; future Slice 8-style artifacts require the full `Config: [[on-window-detected]] move-node-to-zone Comms --fail-if-noop` chip.
- The accepted artifact does not include a dedicated callback-execution log. The proof is config plus absence-before, exact open action, no manual move command in the proof action log, and final routed state. Future routing/automation slices should add either a fast hook-level callback test or structured callback evidence if the routing contract expands.

Pre-slice cleanup before the next slice starts:

- [x] Read all three Slice 8 retrospective reports and carry accepted blockers into this checklist.
- [x] Close Slice 8 in this plan with artifact paths, media metadata, proof, verifier/review evidence, retrospectives, claims, non-claims, and accepted notes.
- [x] Tighten future Slice 8-style captions and verifier checks to require the strict `--fail-if-noop` callback command, while preserving the accepted artifact as a historical exception.
- [x] Resolve the plan's callback-log mismatch by making the accepted Slice 8 evidence explicit and not promising a separate callback log for this artifact.
- [x] Add a verifier guard that rejects manual `move-node-to-zone` commands in the recorded automatic-routing proof action log.
- [x] Before the next Tart product run, reduce reviewer-facing retry noise by adding clearer retry summaries and stronger SSH/TCC readiness checks.
- [x] Before any future routing or automation slice, add either a fast hook-level callback behavior test or first-class callback evidence logs.
- [x] Inventory the accepted Slice 8 dirty set, including the untracked config and guest script, and exclude accidental `gitHashGenerated.swift` churn from the commit.

### Slice 9: User-Facing Columnar Zones Docs

Goal: publish the feature in the user-facing README so an ultrawide user can
configure zones, bindings, presets, scenes, and simple window routing without
reading the implementation plan.

This is a documentation slice, not a new desktop-behavior slice. It must still
attach accepted Tart-derived video evidence:

- root demo video: `demo-columnar-zones.mp4`;
- source Tart artifact: `artifacts/e2e/slice-7-root-demo-20260624T042021Z`;
- routing proof artifact: `artifacts/e2e/slice-8-20260624T045815Z`.

Slice 9 scope:

- Add a concise README section after multi-monitor behavior, because zones are
  an ultrawide extension of the monitor mental model.
- Include one inline `[[zones]]` columns example, ergonomic bindings, `list-zones`
  inspection guidance, selector disambiguation, one preset/scene example, and
  one `[[on-window-detected]]` routing example.
- Link the root columnar-zones demo video from the README.
- Keep non-claims explicit by avoiding grid/freeform layouts, draggable dividers,
  per-zone sidebars, or a visual editor.

Slice 9 validation:

- Run a fast markdown/config-surface sanity check by comparing README examples
  against the accepted e2e fixtures and command names.
- Re-run the root demo verifier with `--require-review`.
- Re-run the Slice 8 artifact verifier with `--require-review`.
- Run a no-context subagent review of the README section and attached video
  evidence before closing this slice.
- Run the three no-context retrospection agents and bake any accepted blocking
  findings into the next checklist, or record that the implementation plan is
  complete if there is no next slice.

Slice 9 accepted artifact:

- artifact directory: `artifacts/e2e/slice-9-docs-20260624T052928Z`;
- README snapshot: `artifacts/e2e/slice-9-docs-20260624T052928Z/README.md`;
- README snapshot SHA-256: `dc451683c64e7958dacd4514f30ea1c7c4227399116bea941ca8b694238c1054`;
- docs-slice manifest: `artifacts/e2e/slice-9-docs-20260624T052928Z/logs/docs-slice-manifest.txt`;
- review: `artifacts/e2e/slice-9-docs-20260624T052928Z/reviews/no-ctx-artifact-review.md`;
- verdict: `PASS_WITH_NOTES`, `next slice allowed: yes`;
- referenced root demo: `demo-columnar-zones.mp4`, SHA-256 `bd772ca45ffa9706ed21096d85c2ba2a93555b3f31c7d7dad9f9fdf284ad63ba`;
- root demo source artifact: `artifacts/e2e/slice-7-root-demo-20260624T042021Z`;
- routing proof artifact: `artifacts/e2e/slice-8-20260624T045815Z`;
- retrospectives:
  - `artifacts/e2e/slice-9-docs-20260624T052928Z/retrospectives/process-plan.md`;
  - `artifacts/e2e/slice-9-docs-20260624T052928Z/retrospectives/code-harness.md`;
  - `artifacts/e2e/slice-9-docs-20260624T052928Z/retrospectives/artifact-product.md`.

Verification:

- `make e2e-verify-root-demo-check RUN_DIR=artifacts/e2e/slice-7-root-demo-20260624T042021Z ARGS=--require-review` passed with H.264, 3440x1440, duration `41.983333s`, and `yuv420p`.
- `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-8-20260624T045815Z ARGS=--require-review` passed with H.264, 3440x1440, duration `43.983333s`, 1949 frames, and the documented historical strict-caption exception.
- `git ls-files --error-unmatch demo-columnar-zones.mp4` passed, proving the linked root demo is tracked.
- README and artifact snapshot hashes match.

What the accepted docs prove:

- the public README now explains the ultrawide columnar-zones mental model;
- the README gives a working `[[zones]]` columns example, focus/move bindings,
  `list-zones` inspection guidance, selector disambiguation, `[[zone-layouts]]`,
  `[[zone-scenes]]`, `use-zone-layout`, `use-zone-scene`, and
  `[[on-window-detected]]` routing;
- the linked root demo is a tracked, accepted Tart-derived product demo;
- the routing example is backed by the accepted Slice 8 title-routing proof.

Accepted notes:

- The README routing regex intentionally uses `Slack|Messages|route-comms` as a
  broader user-facing example. The accepted Slice 8 media/proof uses the exact
  `route-comms` fixture, with the same `[[on-window-detected]]` plus
  `move-node-to-zone Comms --fail-if-noop` command shape.
- The root demo primarily demonstrates scenes and inspection commands. Earlier
  accepted artifacts cover `focus-zone` and `move-node-to-zone`, while Slice 8
  covers automatic title routing.
- The Slice 8 artifact keeps its documented historical caption exception; future
  routing docs and recordings should use the strict `--fail-if-noop` form.

Plan completion cleanup:

- [x] Read all three Slice 9 retrospective reports and carry accepted blockers.
- [x] Preserve docs-slice validation evidence in a manifest under the Slice 9
  artifact logs.
- [x] Close Slice 9 in this plan with artifact paths, hashes, review verdict,
  verifier evidence, claims, non-claims, notes, and retrospectives.
- [x] Record that the columnar-zones implementation plan is complete after Slice
  9. Future docs/release slices should add a reusable docs-slice verifier or
  reviewer packet before relying on this pattern again.

### Slice 10: Runtime Zone Availability

Goal: let users temporarily hide and restore named zones such as `Comms` or
`Email` without editing TOML or losing the workspace that was parked in that
zone.

This slice reopens the post-MVP plan because the keyboard and mouse control
surface needs more than static layouts, scenes, and routing. Availability is the
smallest control primitive: a user can bind one command to make a zone available
or unavailable, then later use the same model for full-layout availability,
resizing, style, and mouse snap policy.

Pre-slice cleanup before Slice 10 starts:

- [x] Run three no-context retrospection agents for process/plan, code/harness,
  and artifact/product.
- [x] Update this plan with a new slice contract before implementation.
- [x] Decide the runtime contract: availability is in-memory state, not a config
  rewrite.
- [x] Decide hidden-zone semantics: a disabled zone is removed from workspace
  viewports and sidebar zone targets, and the remaining enabled zones reflow to
  fill the physical workspace rect by normalizing their configured widths.
- [x] Decide workspace preservation: the disabled zone's active workspace is
  parked under the zone's stable id, not remapped into a neighbor. Re-enabling
  the zone restores that workspace when it still exists and is not already
  active elsewhere.
- [x] Decide the last-zone policy: reject attempts to disable the only enabled
  zone on a configured physical monitor.
- [x] Decide re-enable discoverability: `enable-zone` and `toggle-zone` resolve
  against configured zone ids and names, so a hidden zone remains addressable
  even though it is no longer an active viewport.
- [x] Add e2e plumbing before the Tart proof: Make target, guest script,
  config fixture, harness dispatch, verifier case, reviewer-packet fields, and
  prompt slice-specific checks.

User-facing command surface:

```toml
[mode.main.binding]
alt-c = 'toggle-zone Comms'
alt-shift-c = 'enable-zone Comms'
alt-ctrl-c = 'disable-zone Comms'
```

Commands:

- `toggle-zone [--monitor <monitor-pattern>] <zone>`
- `enable-zone [--monitor <monitor-pattern>] <zone>`
- `disable-zone [--monitor <monitor-pattern>] <zone>`

Selector rules:

- Bare zone ids or names work when unique.
- Duplicate zone ids across physical monitors require either `--monitor` or a
  selector such as `2:Comms`.
- Availability commands resolve configured zones, including disabled zones.
- `focus-zone` and `move-node-to-zone` only target enabled zones. If the zone is
  configured but disabled, they should fail with an error that tells the user to
  enable it first.

Runtime semantics:

- Availability is scoped by physical monitor identity plus zone id.
- Toggling availability does not mutate `ZoneColumnConfig.width` or the user's
  TOML.
- Enabled columns keep their stable `MonitorViewportId` identity.
- Remaining enabled columns fill the physical workspace rect using their
  configured widths normalized over only the enabled columns.
- If the default zone is disabled, the first enabled zone becomes the temporary
  default viewport for physical-monitor compatibility.
- Re-enabling a parked zone restores its last active workspace if that workspace
  still exists and is not visible elsewhere. Otherwise WinMux uses the normal
  retained empty workspace behavior.

Fast validation before Tart:

- parser tests for `toggle-zone`, `enable-zone`, `disable-zone`, `--monitor`,
  and qualified selectors;
- topology tests for disable -> reflow -> re-enable, including middle-zone and
  default-zone cases;
- command tests for parking/restoring the active workspace, rejecting last-zone
  disable, disabled-zone focus/move failures, duplicate selector qualification,
  and command no-ops.

Slice 10 Tart storyboard:

- Use a three-zone config with visible `Reference`, `Work`, and `Comms` windows
  plus the physical sidebar.
- Start the reviewed recording only after the clean desktop, WinMux, sidebar,
  and three visible zones are ready.
- Caption chips:
  - `Config: [[zones]] Reference + Work + Comms`;
  - `Run: winmux disable-zone Comms`;
  - `Action: Comms hidden, Work expands`;
  - `Run: winmux enable-zone Comms`;
  - `Action: Comms restored with its workspace`;
  - `Run: winmux list-zones`;
  - `Run: winmux list-windows --workspace visible`.
- Required screenshots: clean before, ready state, hidden state, restored state,
  and caption-boundary frames for disable and enable.
- Required logs: zone availability before, after disable, after enable; sidebar
  state before/hidden/restored; visible windows before/hidden/restored; command
  logs; done marker; proof file.
- Verifier assertions must prove strict guest capture, exact command chips,
  hidden Comms media, Work/main expansion, restored Comms workspace identity,
  no remap of the parked Comms workspace into another visible zone, and a
  `PASS` or `PASS_WITH_NOTES` no-context review before the next slice.

Artifact review gate:

- Add Slice 10-specific checks to
  `script/e2e/prompts/no-context-artifact-review.md`.
- The no-context reviewer must reject logs-only proof, final-state-only proof,
  missing hidden/restored frames, hidden zones that still appear as active
  sidebar targets, and command chips that omit the user-facing WinMux command.

Slice 10 non-claims:

- no persistent availability in TOML;
- no whole-layout availability toggle;
- no zone resize command;
- no per-zone style command;
- no configurable mouse gestures or modifier-held snap policy;
- no visual editor.

Slice 10 accepted result:

- artifact: `artifacts/e2e/slice-10-20260626T090359Z`;
- primary recording:
  `recordings/slice-10-zone-availability.mov`, H.264, 3440x1440,
  54.000000s, 2334 frames;
- raw guest recording:
  `recordings/raw/slice-10-zone-availability.raw.mov`, preserved for
  debugging;
- screenshots: `00-before-slice-10.png`, `01-ready-slice-10.png`,
  `02-hidden-slice-10.png`, `03-restored-slice-10.png`,
  `99-after-slice-10.png`, and
  `slice-10-zone-availability.contact-sheet.jpg`;
- proof file: `slice-10-zone-availability-proof.txt`;
- reviewer packet:
  `artifacts/e2e/slice-10-20260626T090359Z/reviews/reviewer-packet.md`;
- no-context artifact review:
  `artifacts/e2e/slice-10-20260626T090359Z/reviews/no-ctx-artifact-review.md`,
  verdict `PASS`, next slice allowed `yes`;
- verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-10-20260626T090359Z ARGS=--require-review`
  passed;
- config provenance: copied config hash matched
  `script/e2e/configs/zone-availability.toml` with
  `568c6dab32d315cc9b3ee06bd14e56fc31355be68c06964f906fe9f358aa0366`;
- retrospectives:
  `retrospectives/process-plan.md` (`FAIL`, closure blocker only),
  `retrospectives/code-harness.md` (`PASS_WITH_NOTES`), and
  `retrospectives/artifact-product.md` (`PASS_WITH_NOTES`).

Slice 10 accepted claims:

- `disable-zone Comms` hides the configured `Comms` zone from active
  workspace viewports and sidebar zone targets;
- the remaining enabled zones reflow across the physical monitor, with `Work`
  expanding from `1688.0` px to `2250.666666666667` px in the proof logs;
- the parked `Comms` workspace is not remapped into another visible zone;
- `enable-zone Comms` restores `Comms` on the right with workspace `3`;
- the recording starts from a clean desktop with no Terminal, sshd prompt,
  permission dialog, setup window, or unrelated app window visible.

Slice 10 accepted notes:

- The artifact review accepted Slice 10 because the hidden/restored behavior is
  visible in screenshots, samples, logs, and the proof file.
- The artifact/product retrospective found a timing weakness: the restore
  command caption appears late enough that some boundary frames already show
  the restored state. Do not re-record Slice 10 for that alone, but hard-fail
  this timing issue for Slice 11A and later control slices.
- Guest-control warmup had transport retry noise before final strict guest
  proof. Future reviewer packets should summarize warmup attempts and failed
  attempts so reviewers do not need to discover this from raw logs.
- The Slice 10 dirty set must be committed before Slice 11A implementation
  starts. If work resumes before a commit exists, the exact dirty file list must
  be recorded as intentionally carried Slice 10 state.

### Slice 11 Gate: Do Not Start Before Slice 10 Closes

Slice 11 work is blocked until Slice 10 has a verified Tart artifact and plan
result block. Do not implement Slice 11 code, run a Slice 11 Tart recording, or
claim control ergonomics beyond availability until all Slice 10 gates pass:

- `make e2e-slice-10`;
- `make e2e-verify-slice RUN_DIR=<slice-10-run>`;
- manual media/contact-sheet inspection;
- no-context artifact review with `PASS` or `PASS_WITH_NOTES`;
- `make e2e-verify-slice-check RUN_DIR=<slice-10-run> ARGS=--require-review`;
- three no-context post-slice retrospectives;
- this plan updated with accepted artifact paths, hashes, claims, non-claims,
  review verdict, verifier evidence, and follow-up notes.

If Slice 10 remains dirty after acceptance, either commit it or explicitly carry
its files forward before beginning Slice 11.

### Slice 11A: Zone Size and Layout Controls

Goal: expose the next keyboard controls after availability: runtime zone width
changes, balancing, and layout cycling. Keep mouse snap policy and visual style
out of this slice.

Runtime model:

- Replace the growing set of ad hoc globals with one runtime overlay per
  physical monitor identity. The overlay should eventually contain active layout
  id, disabled zone ids, parked workspaces, width overrides, style overrides, and
  optional active scene id.
- Width overrides are runtime-only. They must not mutate `ZoneConfig`,
  `ZoneLayoutConfig`, or the user's TOML.
- Key width overrides by physical monitor identity plus active layout identity
  plus zone id. A resize in the `focus` preset must not leak into the `balanced`
  preset.
- `use-zone-layout` already exists. Do not re-prove it as new work. Slice 11A
  may add layout cycling on top of the existing layout selection command.
- `list-zones` must expose enough state for proof before Tart: enabled or
  disabled state, configured width, effective width, runtime override state,
  layout id, left edge, pixel width, and active workspace.

Command surface:

```toml
[mode.main.binding]
alt-minus = 'resize-zone Work width -10%'
alt-equal = 'resize-zone Work width +10%'
alt-0 = 'balance-zones'
alt-tab = 'cycle-zone-layout balanced focus'
```

Commands:

- `resize-zone [--monitor <monitor-pattern>] <zone> width [+|-]<percent>`
- `balance-zones [--monitor <monitor-pattern>]`
- `cycle-zone-layout [--monitor <monitor-pattern>] <layout-id>...`

Resize semantics:

- Resize targets enabled zones only. If a zone is configured but disabled,
  return an error telling the user to enable it first.
- A `+10%` or `-10%` value changes the target zone by percentage points of the
  enabled zone group on that physical monitor. A bare set value should require
  `%`, for example `60%`; reject ambiguous bare numbers.
- Enabled sibling zones absorb the delta proportionally. Disabled zones keep
  their parked/configured/runtime widths.
- Reject operations that would leave any enabled zone below the minimum
  visible share. Start with a 5% minimum share unless implementation proves a
  stronger pixel minimum is needed.
- Preserve `MonitorViewportId` stable identity and each zone's active workspace
  across width changes.

Fast validation before Tart:

- pre-slice cleanup must land before implementation starts:
  - add `list-zones` proof fields for enabled state, configured width,
    effective width, runtime override state, layout id, left edge, pixel width,
    active workspace, and configured disabled zones;
  - add a reusable geometry assertion helper for e2e logs that checks sorted
    zone ids, contiguous left/width spans, total physical width, min-width
    bounds, no overlaps, no gaps, stable workspace ids, stable window ids, and
    unchanged copied config hash;
  - add a verifier self-test or fixture mode for the Slice 11A geometry helper;
  - wire Slice 11A through annotation planning, annotation preflight,
    `write-review-packet`, `verify-artifact`, `script/e2e/README.md`, and
    `make e2e-pre-tart-checks` before the Tart run;
  - resolve the command-help generation trail or add a command metadata
    consistency check before introducing the next command family;
  - add a warmup/retry summary to the reviewer packet or preflight output;
- parser tests for `resize-zone Work width +10%`, `resize-zone Work width -10%`,
  `resize-zone Work width 60%`, `balance-zones --monitor 1`, and
  `cycle-zone-layout balanced focus`;
- command tests proving negative resize values are parsed as values, not flags;
- topology tests for resize and balance preserving zone ids, active workspaces,
  total physical width, and no overlap or gap drift;
- command tests for unavailable-zone resize errors, duplicate selector
  qualification, min-width rejection, balance with a disabled zone, and layout
  switch interaction;
- `list-zones` tests proving configured/effective/runtime fields are visible.

Slice 11A Tart storyboard:

- Use one three-zone fixture with large labeled windows and a visible sidebar.
- Record only one primary claim: resize/balance ergonomics. Do not mix style or
  mouse snap behavior into the same proof.
- The command caption must appear while the pre-command geometry is still
  visible. The artifact reviewer must fail any recording where the width/layout
  state changes before the command caption appears.
- Put numeric geometry on screen for every width/layout claim. Acceptable
  surfaces include a large TextEdit geometry board, a visible
  `list-zones --format ...` output window, or a caption chip with exact before
  and after values.
- Caption chips must show the exact command and amount before state changes:
  - `Run: winmux resize-zone Work width +10%`;
  - `Action: Work expands, side zones shrink`;
  - `Run: winmux balance-zones`;
  - `Action: zones return to equal widths`;
  - `Run: winmux list-zones --format ...`.
- Required named sample frames or contact-sheet row: `before-resize`,
  `resize-command-start`, `after-resize`, `list-zones-after-resize`,
  `before-balance`, `balance-command-start`, `after-balance`, and
  `list-zones-after-balance`.
- Verifier assertions must compare numeric geometry before and after: zone id,
  layout id, left edge, width, total contiguous width, min-width bounds, same
  window ids, same workspace ids, and unchanged copied config hash.
- The reviewer prompt must reject logs-only sizing proof, final-state-only
  proof, unreadable geometry changes, stale document labels, command captions
  that omit target zone or amount, captions that appear after the visible state
  changed, geometry numbers that exist only in logs, missing
  before/command/after samples, and artifacts where zone boundaries are obscured
  by captions.

Slice 11A accepted result:

- artifact: `artifacts/e2e/slice-11a-20260626T102409Z`;
- primary recording:
  `recordings/slice-11a-zone-width-controls.mov`, H.264, 3440x1440,
  53.983333s, 2335 frames;
- raw guest recording:
  `recordings/raw/slice-11a-zone-width-controls.raw.mov`, preserved for
  debugging;
- screenshots: `00-before-slice-11a.png`, `01-ready-slice-11a.png`,
  `02-before-resize-slice-11a.png`, `03-after-resize-slice-11a.png`,
  `04-before-balance-slice-11a.png`, `05-after-balance-slice-11a.png`,
  `99-after-slice-11a.png`, and
  `slice-11a-zone-width-controls.contact-sheet.jpg`;
- proof file: `slice-11a-zone-width-controls-proof.txt`;
- visible geometry board:
  `logs/slice-11a-visible-geometry-board.txt`, mirrored in the live TextEdit
  zone windows and showing `zone-id`, enabled state, configured width,
  effective width, runtime width, override state, left edge, pixel width, and
  active workspace;
- sample manifest:
  `logs/slice-11a-zone-width-controls.sample-manifest.tsv`, mapping the
  required semantic proof beats to exact screenshot/sample-frame paths;
- transport summary:
  `logs/guest-transport-summary.tsv`, showing guest-control, warmup, privacy,
  clean-slate, capture-ready, and recording phases with attempts, failures,
  final results, and whether they happened before recording;
- reviewer packet:
  `artifacts/e2e/slice-11a-20260626T102409Z/reviews/reviewer-packet.md`;
- no-context artifact review:
  `artifacts/e2e/slice-11a-20260626T102409Z/reviews/no-ctx-artifact-review.md`,
  verdict `PASS`, next slice allowed `yes`;
- verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-11a-20260626T102409Z ARGS=--require-review`
  passed;
- config provenance: copied config hash matched
  `script/e2e/configs/zone-width-controls.toml` with
  `c6639412d06e5f03cc51ed550decfe7165fec5465bb490bac4f1c8d6b3f23ba7`;
- command timing proof:
  `resize-command-offset-seconds=15` and
  `balance-command-offset-seconds=33`, so each command ran while its command
  caption was visible and before the corresponding state transition completed;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`, all ending
  `RETROSPECTION_COMPLETE`.

Superseded Slice 11A attempts:

- `artifacts/e2e/slice-11a-20260626T095539Z`: rejected after verifier
  hardening because the command timing proof was missing and manual inspection
  showed the resize command caption after the geometry had already changed;
- `artifacts/e2e/slice-11a-20260626T100241Z`: rejected by the hardened
  verifier because `balance-command-offset-seconds=30`, before the
  `balance-zones` command caption window;
- `artifacts/e2e/slice-11a-20260626T100906Z`: mechanically valid after timing
  fixes, but failed no-context review because the full numeric geometry fields
  were present only in logs/proof text and not visible in the media.

Slice 11A accepted claims:

- `resize-zone Work width +10%` changes runtime width overrides on the target
  physical monitor without mutating the copied TOML;
- the `Work` zone grows from `1688.0` px to `2025.6` px, while `Reference` and
  `Comms` shrink from `844.0` px to about `675.2` px;
- `balance-zones` returns all three enabled zones to about `1125.3` px while
  preserving stable zone ids, window ids, and active workspaces;
- runtime width overrides are scoped by physical monitor identity, active
  layout identity, and zone id in code tests;
- `list-zones` exposes enabled state, configured width, effective width,
  runtime override state, layout id, left edge, pixel width, and active
  workspace for proof and user inspection;
- the recording starts from a clean desktop with no Terminal, sshd prompt,
  permission dialog, setup window, or unrelated app window visible.

Slice 11A accepted non-claims:

- layout cycling is covered by parser/command tests and the fixture config, but
  the accepted Tart media proves only resize and balance;
- no persistent width editing in TOML;
- no visual zone editor or draggable divider;
- no per-zone style command;
- no mouse snap policy, gesture configuration, or whole-zone drag overlay;
- no availability-set command beyond the Slice 10 one-off zone toggles.

Pre-slice cleanup before Slice 11B starts:

- [x] Commit the Slice 11A dirty set before implementing or recording the next
  slice. This changeset is the intended Slice 11A implementation and artifact
  gate boundary.
- [x] Add a stale-proof guard for visible proof boards: either generate the
  visible board from runtime `list-zones` logs, or verify every visible board
  value against the runtime logs. Do not reuse static all-state boards as the
  only visible proof for future measurement/control slices.
- [x] Add a semantic sample manifest that maps planned proof beats such as
  `before-resize`, `resize-command-start`, `after-resize`,
  `balance-command-start`, and `after-balance` to exact sample frame paths, and
  require it in the non-mutating verifier for future ordered visual proofs.
- [x] Add a guest transport/warmup summary to the artifact directory and
  reviewer packet, with attempt counts, failed attempts, final result, and
  whether failures happened before recording.
- [x] Add focused fast tests for width-command safety not yet covered:
  duplicate zone selector qualification across physical monitors,
  monitor-qualified resize/balance/cycle behavior, minimum-width rejection, and
  absolute width values that would force siblings below the minimum share.
- [x] Resolve the command-help/generated metadata consistency trail before the
  next command family lands, either with a deterministic generator/check or an
  explicit documented source-of-truth workflow.
- [x] Tighten reviewer packet language so evidence that is required for a slice
  is not described as optional or "when present".

Pre-Slice-11B cleanup evidence:

- `swift test --filter ZoneCommandTest` passed with 31 command tests, including
  the duplicate-scope, monitor-qualified resize/balance/cycle, and minimum-share
  width-command cases added after Slice 11A acceptance.
- `script/check-command-metadata` is now wired into `make e2e-pre-tart-checks`.
  It compares `CmdKind`, generated help vars, and CLI descriptions, with only
  the current documented legacy exceptions allowed.
- `script/e2e/prompts/no-context-artifact-review.md` and
  `script/e2e/write-review-packet` now state that product-slice reviewer
  packets, transport summaries, listed media/log evidence, and slice-specific
  checks are acceptance requirements.
- `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-11a-20260626T102409Z ARGS=--require-review`
  passed after regenerating the Slice 11A reviewer packet with the stricter
  wording.

### Slice 11B: Zone Style Controls

Goal: add style controls on top of the runtime overlay model proven by Slice 11A.

Command:

- `set-zone-style [--monitor <monitor-pattern>] <zone> <style-id>`

Style requirements:

- Styles must be config-defined tokens, not arbitrary command-only strings.
- The first visible consumer is the sidebar zone row with an explicit color
  swatch. Do not accept
  `set-zone-style` if the only proof is logs.
- Applying a style must not change layout, width overrides, enabled zones, active
  workspaces, or window/tab-group membership.
- Fast tests must prove style id resolution, unavailable-zone errors, duplicate
  selector qualification, and that the style id reaches the visible view model.
- The Tart verifier must reject subtle style changes that cannot be seen in the
  recording, final-state-only proof, and any proof where a reviewer cannot tell
  whether the feature changed style, layout, or workspace binding.

Slice 11B implementation checklist:

- [x] Add `[[zone-styles]]` config parsing with normalized hex colors and
  duplicate style-id validation.
- [x] Add runtime style overrides to `ZoneRuntimeOverlay` and expose
  `zoneStyleId` / `zoneStyleColorHex` through `Monitor`,
  `ConfiguredZoneSummary`, `list-zones`, and sidebar zone target view models.
- [x] Add `set-zone-style` parsing, command dispatch, generated help metadata,
  and style-specific command output.
- [x] Add focused fast tests for parser validation, style application, unknown
  style rejection, disabled-zone rejection, duplicate physical scope handling,
  `list-zones` output, and sidebar view-model propagation.
- [x] Add Tart scenario, captions, semantic sample manifest, verifier checks,
  and reviewer-packet checks for unstyled -> urgent -> calm.
- [x] Record the strict guest-captured Tart artifact, run no-context review, run
  the three no-context retrospectives, bake accepted findings into the next
  pre-slice cleanup, then commit the accepted Slice 11B boundary.

Slice 11B Tart proof:

- start from a clean desktop with Reference, Work, and Comms visible and the
  sidebar open;
- show the Comms zone row unstyled before the first command;
- run `winmux set-zone-style Comms urgent` while its command caption is visible
  and the old state is still visible;
- show the Comms row visibly tinted urgent red `#D3455B`, including the row
  swatch;
- run `winmux set-zone-style Comms calm` while its command caption is visible
  and the urgent state is still visible;
- show the same Comms row visibly tinted calm blue `#3EA2FF`, including the row
  swatch;
- prove in logs and screenshots that Reference and Work stay unstyled and all
  windows/workspaces remain in the same zone ids.

Slice 11B non-claims:

- no per-zone style persistence back into TOML;
- no style editor UI beyond the runtime command and visible sidebar row;
- no layout resize, availability-set change, scene change, or mouse snap policy.

Slice 11B accepted result:

- artifact: `artifacts/e2e/slice-11b-20260626T113708Z`;
- primary recording:
  `recordings/slice-11b-zone-style-controls.mov`, H.264, 3440x1440,
  43.972891s, 1512 frames;
- raw guest recording:
  `recordings/raw/slice-11b-zone-style-controls.raw.mov`;
- proof: `slice-11b-zone-style-controls-proof.txt`;
- required screenshots:
  `00-before-slice-11b.png`, `01-ready-slice-11b.png`,
  `02-before-style-slice-11b.png`, `03-after-urgent-style-slice-11b.png`,
  `04-after-calm-style-slice-11b.png`, and `99-after-slice-11b.png`;
- no-context artifact review:
  `reviews/no-ctx-artifact-review.md`, verdict `PASS`,
  `next slice allowed: yes`;
- no-context retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`;
- verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-11b-20260626T113708Z ARGS=--require-review`
  passed;
- command timing:
  urgent command at 14s, calm command at 32s, both inside the visible command
  caption windows.

Slice 11B accepted claims:

- `set-zone-style Comms urgent` applies the configured `urgent` style token to
  the Comms sidebar zone row and visible swatch;
- `set-zone-style Comms calm` applies the configured `calm` style token to the
  same row and swatch;
- Reference and Work remain unstyled;
- the same Reference, Work, and Comms windows keep the same window ids,
  workspaces, and zone ids across before, urgent, and calm phases;
- the feature changes zone chrome only, not layout, availability, scene, or
  workspace binding.

Superseded Slice 11B attempts:

- `artifacts/e2e/slice-11b-20260626T112738Z` was mechanically valid enough to
  inspect but was not accepted and did not receive a no-context review. The
  visual style proof was too subtle, so the row/swatch styling and reviewer
  prompt were hardened before rerunning the accepted `113708Z` artifact.

Pre-slice cleanup before Slice 11C starts:

- [x] Read all three Slice 11B no-context retrospectives and fold shared
  blockers into this checklist.
- [x] Restore generated-hash churn so the Slice 11B dirty set stays scoped to
  product, tests, harness, generated command metadata, and plan changes.
- [x] Add verifier checks proving style changes do not alter zone name,
  enabled state, workspace, geometry, or physical-monitor identity. Future logs
  also compare layout id when present.
- [x] Add a focused fast test proving `set-zone-style` preserves active layout,
  width overrides, active workspaces, focus, and window membership.
- [x] Make Slice 11B guest state assertions use
  `WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT` so semantic failures stop
  retries instead of replaying a half-mutated proof state.
- [x] Commit the accepted Slice 11B dirty set before implementing Slice 11C:
  `0d240ab3` (`Add runtime zone style controls`).
- [x] Define the Slice 11C availability-set contract before code changes.
- [x] Save pre-Tart gate output into future run directories, starting with the
  next product Tart proof.
- [x] Add a Slice 11C mechanical swatch/color sentinel. Slice 11C media will
  carry a styled Comms zone as the preservation proof, so the verifier must
  mechanically sample the visible swatch before hide, while restored, and after
  restore.

### Slice 11C: Availability Sets and Cross-Zone Commands

Goal: make zone-level and layout-level availability ergonomic enough for real
ultrawide workflows such as "open Comms", "hide Email", and "focus-only".

Config shape:

```toml
[[zone-availability-sets]]
id = 'focus-only'
enabled-zones = ['main']

[[zone-availability-sets]]
id = 'communications'
enabled-zones = ['main', 'right']

[[zone-availability-sets]]
id = 'full-dashboard'
enabled-zones = ['left', 'main', 'right']
```

Command surface:

- `use-zone-availability [--monitor <monitor-pattern>] <set-id>`
- `cycle-zone-availability [--monitor <monitor-pattern>] <set-id>...`
- keep `toggle-zone`, `enable-zone`, and `disable-zone` for one-off zone-level
  changes.

Runtime contract:

- Add `zoneAvailabilitySets` to config and `activeAvailabilitySetId` to
  `ZoneRuntimeOverlay`.
- `disabledZoneIds` remains the source of truth for effective enabled and
  disabled zones. A named availability set mutates `disabledZoneIds` to the
  complement of its `enabled-zones` for the target physical monitor's current
  resolved layout.
- `activeAvailabilitySetId` is a label for the state last produced by
  `use-zone-availability` or `cycle-zone-availability`, not a second source of
  enabled-zone truth.
- `enable-zone`, `disable-zone`, and `toggle-zone` are manual overrides. They
  continue to operate on configured zones, including currently hidden zones, and
  clear `activeAvailabilitySetId` on the target physical monitor when they
  change the effective enabled set.
- `cycle-zone-availability` resolves the current set by
  `activeAvailabilitySetId` when present. If no active id is present, it may
  match the current enabled-zone set against the provided ids; otherwise it
  starts from the first provided id.
- Width overrides remain keyed by physical monitor identity plus active layout
  identity. Applying an availability set must not rewrite
  `widthOverridesByLayoutIdentity`.
- Style overrides remain keyed by physical monitor identity plus zone id.
  Applying an availability set must not rewrite `styleOverridesByZoneId`, even
  for hidden zones. A restored styled zone must show the same style token.
- Applying an availability set must preserve `activeLayoutId`; it does not
  switch layouts and is not a scene.
- Workspace parking uses the Slice 10 semantics: newly hidden zones park their
  current active workspace under zone id; restored zones reactivate that
  workspace only when it still exists and is not active elsewhere.
- If a parked workspace cannot be restored because it was deleted or is already
  active elsewhere, the restored zone uses normal workspace reconciliation and
  the stale parked entry is cleared.

Validation contract:

- Config validation rejects duplicate availability-set ids and empty
  `enabled-zones`.
- Config validation rejects a zone id that does not exist in any configured
  inline zone or named zone layout.
- Command-time validation rejects a set whose `enabled-zones` are not all
  present in the target physical monitor's current resolved layout.
- Command-time validation rejects a set that would leave zero enabled zones.
- Duplicate physical monitor scopes follow the existing zone-command selector
  rules: use `--monitor` when a target physical display cannot be inferred from
  focus or command context.

Required behavior:

- Availability sets apply only to configured zones on the target physical
  monitor.
- At least one zone must remain enabled.
- Hidden zones park their active workspace and restore it when the zone returns.
- Applying an availability set must not change active layout, width overrides,
  style overrides, or workspace bindings except where a hidden zone must be
  parked.
- `list-zones` must show enough state to prove which availability set is active
  and which zones are enabled. Add a formatted field for active availability set
  id and include it in the Slice 11C proof logs.

Fast validation before Tart:

- parser and config validation tests for duplicate ids, unknown zone ids, empty
  enabled zone lists, and valid sets;
- command tests for `use-zone-availability`, cycling, unknown ids, duplicate
  selectors, and preservation of parked workspaces;
- topology tests proving width and style overrides survive availability set
  changes, including hidden and restored zones.

Tart proof:

- [x] show a three-zone layout with Reference, Work, and Comms visible;
- [x] apply `set-zone-style Comms urgent` before the availability-set sequence so
  the proof carries a styled Comms zone across hide and restore;
- [x] run `winmux use-zone-availability focus-only` while the command caption is
  visible before the state change;
- [x] show Comms/Reference disappear and Work expand;
- [x] run `winmux use-zone-availability communications`;
- [x] show Comms return with the same workspace/window identity and the urgent
  swatch still visible;
- [x] write `logs/<slice-11c-recording>.color-sentinel.tsv` with Comms-row swatch
  samples before hide, during restore, and after restore. The verifier samples
  screenshot pixels from those regions, using the run-relative screenshot path,
  crop rectangle, expected `#D3455B`, minimum match percentage, and channel
  distance threshold. This tripwire supplements no-context human review; it
  does not replace it;
- reviewer and verifier must reject final-state-only proof, missing command
  captions, logs-only proof, or any recording where the user cannot tell which
  zones are toggled.

Accepted artifact:

- artifact: `artifacts/e2e/slice-11c-20260626T125442Z`;
- recording: `recordings/slice-11c-zone-availability-sets.mov`, H.264,
  3440x1440, annotated with exact user-facing commands;
- raw recording: `recordings/raw/slice-11c-zone-availability-sets.raw.mov`;
- proof: `slice-11c-zone-availability-sets-proof.txt`;
- key screenshots: `02-before-availability-slice-11c.png`,
  `03-before-hide-urgent-slice-11c.png`, `04-after-focus-only-slice-11c.png`,
  `05-during-communications-restore-slice-11c.png`, and
  `06-after-communications-restore-slice-11c.png`;
- mechanical verifier: `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-11c-20260626T125442Z`;
- post-review closeout verifier:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-11c-20260626T125442Z`;
- pre-Tart gate log:
  `artifacts/e2e/slice-11c-20260626T125442Z/logs/pre-tart-checks.log`;
- no-context review: `PASS`, `next slice allowed: yes`, at
  `artifacts/e2e/slice-11c-20260626T125442Z/reviews/no-ctx-artifact-review.md`;
- retrospective reports:
  `retrospection-process-plan.md`, `retrospection-code-harness.md`, and
  `retrospection-artifact-product.md` under
  `artifacts/e2e/slice-11c-20260626T125442Z/reviews/`;
- accepted claims: `set-zone-style Comms urgent`,
  `use-zone-availability focus-only`, `use-zone-availability communications`,
  Work expansion, Comms/right restore with the same workspace/window, and urgent
  style preservation across hide/restore;
- non-claims: this Tart artifact does not visually prove
  `cycle-zone-availability`, the `full-dashboard` set, persistent TOML edits,
  mouse gestures, snap policy, or tab-group drag behavior.

Pre-Slice-12 cleanup:

- [x] Complete the Slice 11C no-context artifact review and require `PASS` or
  `PASS_WITH_NOTES` plus `next slice allowed: yes`.
- [x] Run the post-review closeout verifier with `--require-review`:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-11c-20260626T125442Z`.
- [x] Read all three Slice 11C retrospection reports and fold accepted findings
  into this plan.
- [x] Add monitor-scoped `use-zone-availability --monitor` and
  `cycle-zone-availability --monitor` fast tests.
- [x] Add stale parked-workspace restore tests for deleted workspaces and
  workspaces that became active elsewhere.
- [x] Add a non-mutating product-slice closeout make target that requires the
  no-context review, `--require-review` verifier pass, and three retrospection
  reports.
- [x] Harden artifact-review guidance for availability-set slices so reviewers
  distinguish the top sidebar `Zones` section from parked workspace rows.
- [x] Commit the Slice 11C dirty set or write an explicit carry-forward
  inventory before starting Slice 12 implementation. Slice 11C was committed as
  `998fe97b`.
- [x] Define Slice 12's first Tart proof scope before implementation: whole-zone
  snap target, modifier/freeform cases, required in-drag frames, exact captions,
  logs, color/geometry sentinels if needed, and verifier/reviewer checks.

### Slice 12: Mouse Snap Policy and Gestures

Goal: make mouse interaction deliberate enough for one-handed use on an
ultrawide.

Model the drag policy explicitly:

- `freeform`: moving a floating window inside a zone stays freeform;
- `snap-on-modifier`: dragging does not snap unless the configured modifier is
  held;
- `snap-to-zone`: drag previews the target zone and snaps on release without
  requiring a modifier;
- `snap-to-window`: later, preview a slot/window target inside a zone.
- `float-unless-snap`: moving a managed window with the mouse leaves it floating
  unless the snap modifier is held for the drop.

Config should describe gestures and snap policy separately from zones:

```toml
[mouse.zone-snap]
policy = 'snap-on-modifier'
modifier = 'alt'
gesture = 'drag'
target = 'zone'
```

Initial Slice 12 implementation scope:

- add `mouse.zone-snap` config parsing with defaults:
  `policy = 'freeform'`, `modifier = 'alt'`, `gesture = 'drag'`, and
  `target = 'zone'`;
- accept policies `freeform`, `snap-on-modifier`, `snap-to-zone`, and
  `float-unless-snap`;
- accept only the first target, `zone`; `snap-to-window` remains out of scope;
- add fast parser tests for valid config, concise default config, and invalid
  policy/modifier/gesture/target values;
- add a desktop drag resolver that:
  - leaves tab-strip drags and non-zone monitors on the existing path;
  - suppresses accidental zone snap destinations under `freeform` or a missing
    `snap-on-modifier` / `float-unless-snap` modifier;
  - creates a whole-zone `.moveToZone` destination when the policy is active;
  - uses the zone monitor rect for preview geometry and applies the existing
    workspace move into the target zone's active workspace on release;
- add fast mouse-policy tests for freeform suppression, modifier activation,
  `snap-to-zone` activation without a modifier, `float-unless-snap` modifier
  gating, non-zone/non-window-drag fallthrough, and whole-zone destination
  metadata;
- render a whole-zone drag overlay when the destination targets the zone itself
  rather than a sub-zone drop cell;
- this config/runtime seam is not an accepted standalone slice. Do not claim
  completed desktop snapping until the Slice 12 behavior proof records the
  actual pointer path, drag overlay, release, and final window movement.

The first mouse implementation should target whole zones, not windows inside a
zone. Window/slot snap can come after the zone-level affordance is proven.

Required behavior:

- Freeform drag without the modifier does not snap and does not show a zone snap
  overlay.
- Drag with the modifier shows configured zone boundaries, highlights the target
  zone under the pointer, and snaps the window or tab group to that zone's active
  workspace on release.
- Dragging across zones must preserve the same source window id or tab-group
  membership and must make the target zone obvious in the overlay.
- Gesture configuration must be a thin input layer over the same command/model
  logic used by keyboard actions.

Tart proof:

- show pickup, in-drag overlay, target zone highlight, release, and final
  placement;
- include one freeform drag where no snap occurs;
- include one modifier-held drag where the item snaps to a whole zone;
- expose the configured gesture/policy on screen;
- state on screen whether the current target is a zone, a window inside a zone,
  or freeform placement;
- reject any proof where the reviewer cannot see the pointer path, target
  overlay, snap boundary, or final destination without relying on logs.

Slice 12 accepted result:

- artifact: `artifacts/e2e/slice-12-20260626T134813Z`;
- recording: `recordings/slice-12-mouse-zone-snap-drag.mov`, H.264,
  3440x1440, annotated with desktop drag actions and mouse snap config context;
- raw recording: `recordings/raw/slice-12-mouse-zone-snap-drag.raw.mov`;
- proof: `slice-12-mouse-zone-snap-proof.txt`;
- key screenshots: `02-freeform-pickup-slice-12.png`,
  `03-freeform-hover-no-overlay-slice-12.png`,
  `04-reset-before-snap-slice-12.png`, `05-snap-pickup-slice-12.png`,
  `06-snap-path-slice-12.png`, `07-snap-hover-comms-slice-12.png`, and
  `99-after-slice-12.png`;
- no-context artifact review:
  `artifacts/e2e/slice-12-20260626T134813Z/reviews/no-ctx-artifact-review.md`,
  verdict `PASS_WITH_NOTES`, `next slice allowed: yes`;
- mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-12-20260626T134813Z ARGS=--require-review`;
- post-review closeout verifier:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-12-20260626T134813Z`;
- supplemental pre-Tart gate after retrospection fixes:
  `make e2e-pre-tart-checks`, passing 84 selected tests including the mouse
  parser tests and `WindowZoneSnapPolicyTest`;
- retrospective reports:
  `retrospection-process-plan.md`, `retrospection-code-harness.md`, and
  `retrospection-artifact-product.md` under
  `artifacts/e2e/slice-12-20260626T134813Z/reviews/`;
- accepted claims: `[mouse.zone-snap]` parses with the configured policy,
  modifier, gesture, and target; no-Alt desktop window drag stays freeform and
  does not move the window to another zone; Alt-held desktop drag previews a
  whole Comms/right zone target; release moves the same `snap-demo.rtf` window
  id from Work/main to Comms/right;
- accepted note: the reviewed video's first caption chip abbreviates the
  literal modifier/target config, while the caption prose/action chips, copied
  config, proof manifest, and logs expose `modifier = 'alt'` and
  `target = 'zone'`. The future caption template now emits the full literal
  config chip; this exception is not reusable for later mouse-policy artifacts;
- non-claims: this Tart artifact does not prove snap-to-window, slot targeting,
  tab-group mouse snap, persistent float-mode policy, runtime snap-policy
  overlays, mouse gestures beyond desktop drag, a visual config editor, or
  automatic overlay/no-overlay image sentinels.

Superseded Slice 12 attempt:

- `artifacts/e2e/slice-12-20260626T134736Z` contains a passing pre-Tart log but
  no guest media, scenario log, or Tart proof. It is not an accepted artifact.

Pre-Slice-13 cleanup:

- [x] Complete the Slice 12 no-context artifact review and require `PASS` or
  `PASS_WITH_NOTES` plus `next slice allowed: yes`.
- [x] Run the post-review closeout verifier:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-12-20260626T134813Z`.
- [x] Read all three Slice 12 retrospection reports and fold accepted findings
  into this plan.
- [x] Add the Slice 12 mouse parser and zone snap policy tests to
  `make e2e-pre-tart-checks`.
- [x] Add direct fast tests for `snap-to-zone` and `float-unless-snap` resolver
  semantics before expanding mouse policy behavior.
- [x] Tighten the future Slice 12-style caption template so the config chip
  includes literal `policy = 'snap-on-modifier'`, `modifier = 'alt'`, and
  `target = 'zone'`.
- [x] Add future semantic sample-manifest labels for snap release and final
  placement.
- [x] Commit the accepted Slice 12 dirty set or write an explicit carry-forward
  inventory before starting implementation for the next slice. This changeset
  is the Slice 12 boundary.
- [x] Before another drag-heavy Tart run, add a mechanical overlay/no-overlay
  sentinel or write an explicit plan waiver for why that run does not need one.
  Slice 16 adds `logs/slice-16-mouse-snap-affordance.overlay-sentinel.tsv`
  with no-Option and Option-held target-zone crops plus an RMSE floor.
- [x] Before another movement-proof artifact, avoid static initial-zone labels
  inside movable proof documents or pair them with a visible live state board.
  Slice 13 requires a visible live state board with current zone, active
  workspace, selected window id, and zone widths.

## Slice 13 - Portable Zone Mode and Relative Selectors

Goal: make the keyboard path ergonomic without forcing users to hardcode
`Reference`, `Work`, or `Comms` into starter bindings.

Implementation scope:

- Add `current`, `focused`, `next`, and `prev` zone selectors to the common zone
  selector resolver.
- Bare relative selectors resolve only within the focused physical monitor.
  Qualified selectors such as `2:next` resolve within the qualified physical
  monitor.
- Reuse the same selector resolver for `focus-zone`, `move-node-to-zone`,
  `resize-zone`, `toggle-zone`, `enable-zone`, `disable-zone`, and
  `set-zone-style`.
- Add a default `alt-z` zone mode with portable bindings:
  - `h` / `l`: focus previous or next zone;
  - `shift-h` / `shift-l`: move the focused window or tab group to the previous
    or next zone and follow focus;
  - `minus` / `equal`: resize the current zone width by 10%;
  - `0`: balance zone widths;
  - `t`: toggle the current zone;
  - `space`: toggle the focused workspace between floating and tiling layout;
  - `esc`: return to `main`.

Fast validation:

- Parser tests for relative selectors in focus, move, and resize commands.
- Command tests proving relative focus stays within the focused physical monitor
  even when zone ids repeat across monitors.
- Command tests proving `move-node-to-zone next` moves a focused tab group as a
  group and can follow focus.
- Command tests proving `resize-zone current` targets the focused zone.
- Starter-config tests proving `alt-z` and `[mode.zone.binding]` parse into the
  expected command sequences.

Tart video gate:

- Record a real desktop proof with clean state and caption chips for the user
  commands/actions:
  - `Alt-Z, L`: focus next zone;
  - `Alt-Z, Shift-L`: move the focused tab group to the next zone;
  - `Alt-Z, Equal`: widen the current zone;
  - `Alt-Z, 0`: balance zones;
  - `Alt-Z, T`: toggle a zone and restore it.
- The video must include a visible live state board or non-static labels showing
  current zone, resolved target zone, active workspace, selected window id, and
  zone widths before and after each command.
- Because this is a movement-proof artifact, do not rely on fixed document text
  inside the moved window as proof of current placement.
- Semantic screenshots must be fresh at their named checkpoint. A screenshot
  whose live state board is one checkpoint behind fails the slice.
- Movable TextEdit document copy must avoid stale labels such as `zone: Work`,
  `zone: Comms`, or future-state text like "right zone restored after toggle".
- Both hide and restore captions must name the actual user command:
  `toggle-zone current`.
- Run the no-context artifact verifier against the artifact directory before
  accepting the slice. The verifier must reject missing command captions,
  missing movement frames, missing before/after state, or any ambiguous claim
  about whether the action changed focus, workspace membership, or zone width.

Slice 13 accepted result:

- artifact: `artifacts/e2e/slice-13-20260626T153608Z`;
- recording: `recordings/slice-13-zone-mode-bindings.mov`, H.264, 3440x1440,
  annotated with exact `Alt-Z` binding captions and a live state board;
- raw recording: `recordings/raw/slice-13-zone-mode-bindings.raw.mov`;
- proof: `slice-13-zone-mode-bindings-proof.txt`;
- key screenshots: `02-before-focus-next-slice-13.png`,
  `03-after-focus-next-slice-13.png`, `04-after-move-next-slice-13.png`,
  `05-after-resize-slice-13.png`, `06-after-balance-slice-13.png`,
  `07-after-toggle-hidden-slice-13.png`, and
  `08-after-toggle-restored-slice-13.png`;
- no-context artifact review:
  `artifacts/e2e/slice-13-20260626T153608Z/reviews/no-ctx-artifact-review.md`,
  verdict `PASS_WITH_NOTES`, `next slice allowed: yes`;
- preserved failed review:
  `artifacts/e2e/slice-13-20260626T153608Z/reviews/no-ctx-artifact-review.failed-caption-exactness.md`;
- mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-13-20260626T153608Z ARGS=--require-review`;
- closeout gates: `swift test --filter ZoneCommandTest`,
  `swift test --filter 'ConfigTest|ConfigBootstrapTest|WindowZoneSnapPolicyTest'`,
  `make e2e-pre-tart-checks`,
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-13-20260626T153608Z`,
  and `git diff --check`;
- retrospective reports:
  `artifacts/e2e/slice-13-20260626T153608Z/retrospectives/process-plan.md`,
  `code-harness.md`, and `artifact-product.md`;
- accepted claims: the starter config exposes `alt-z = 'mode zone'`; `Alt-Z, L`
  runs `focus-zone next` and resolves to Work/main; `Alt-Z, Shift-L` runs
  `move-node-to-zone --focus-follows-window next` and moves Work Alpha and Work
  Beta together as one tab group into Comms/right; `Alt-Z, Equal` runs
  `resize-zone current width +10%` and widens Comms/right; `Alt-Z, 0` runs
  `balance-zones`; two `Alt-Z, T` actions run `toggle-zone current` and hide then
  restore Comms/right with the same tab group;
- accepted implementation follow-up: command/config tests now cover bare,
  qualified, and monitor-scoped relative selectors, configured-zone command reuse,
  current-toggle restore memory, and parked workspace survival during hidden-zone
  reconciliation;
- accepted notes: the hide-current proof has a small related Work Beta window
  edge visible at the bottom-right. Logs, board state, and after media still prove
  Comms/right is disabled and restored, but future hide/availability demos should
  stage windows so the hidden-state frame is visually clean;
- non-claims: Slice 13 does not prove mouse gestures, drag snap affordances,
  snap-to-window, runtime snap-policy overlays, a visual config editor, persisted
  first-class `ZoneBinding` records, or a perfect hidden-window polish frame.

Superseded Slice 13 attempts:

- `artifacts/e2e/slice-13-20260626T145851Z` failed during setup when TextEdit
  Apple Events authorization remained unavailable after retries. It has no
  accepted product proof.
- `artifacts/e2e/slice-13-20260626T150348Z` was rejected for stale semantic
  screenshots, stale movable document labels, and restore captions that did not
  name `toggle-zone current`.
- The first review of `slice-13-20260626T153608Z` failed caption exactness because
  the visible chips omitted `--focus-follows-window` and `width +10%`. The
  artifact was repaired through annotation refresh, the failed review was
  preserved under a different filename, and the final review accepted the
  refreshed artifact.

Pre-Slice-14 cleanup:

- [x] Run the Slice 13 no-context artifact review and require `PASS` or
  `PASS_WITH_NOTES` plus `next slice allowed: yes`.
- [x] Run all three Slice 13 no-context retrospectives and fold accepted findings
  into this plan.
- [x] Correct prior accepted-artifact references: `slice-12-20260626T134813Z` is
  the accepted Slice 12 artifact; `slice-12-20260626T134736Z` is pre-Tart-only
  and superseded.
- [x] Add or verify tests for qualified relative selectors, monitor-scoped
  relative selectors, configured-zone command reuse, and `toggle-zone current`
  restore-memory lifetime.
- [x] Re-run closeout gates for the source boundary and stage the accepted Slice
  13 dirty set for the closeout commit before feature work for Slice 14 starts.
- [x] Handle `Sources/Common/gitHashGenerated.swift` deliberately before commit;
  do not let generated hash churn hide among source changes.
- [x] Before the next live-board or semantic-screenshot proof, add a mechanical
  board freshness sentinel or write an explicit plan waiver explaining why the
  slice does not need one. Slice 13 now logs checkpoint freshness before each
  semantic screenshot when re-run.
- [x] Before the next mutating guest setup script, add semantic-failure retry
  protection or a reliable cleanup/reset stage so authorization failures do not
  replay against partially mutated desktop state. `guest_script_retry` stops on
  the semantic exit code and the retry contract is covered by the warmup-policy
  self-test.
- [x] Add a standard failed-attempt abort marker, such as
  `logs/run-abort-status.txt`, before relying on another stateful Tart attempt.

## Slice 14: Workspace Zone Bindings

Goal: make `ZoneBinding` first-class for the simplest durable user intent:
"this workspace should be shown in this zone." This keeps the chosen model
intact: a zone is a virtual monitor viewport, and a binding activates a
workspace in that viewport. It does not attach geometry to windows or tab
groups.

End-user config:

```toml
[[zone-bindings]]
zone = 'left'
workspace = 'ReferenceDesk'

[[zone-bindings]]
zone = 'main'
workspace = 'WorkDesk'

[[zone-bindings]]
zone = 'right'
workspace = 'CommsDesk'
```

Optional monitor scoping:

```toml
[[zone-bindings]]
monitor = 2
zone = 'right'
workspace = 'SecondaryComms'
```

Command surface:

- `apply-zone-bindings [--monitor <monitor-pattern>]`
- Without `--monitor`, the command targets the focused physical monitor.
- Generic bindings apply to the target monitor.
- Monitor-scoped bindings apply only when their monitor selector resolves to
  the target physical monitor.
- A scoped binding overrides a generic binding for the same zone on that target.
- The command creates missing named workspaces, activates each one in its bound
  zone viewport, and does not change layout, zone width, availability, or style.
- If a binding references a zone that is missing from the target monitor's
  active layout, fail with an explicit error.
- If a binding references a hidden zone, fail with an explicit error; users must
  enable the zone or apply an availability set first.

Implementation checklist:

- [x] Add `ZoneBindingConfig` to `Config`.
- [x] Parse `[[zone-bindings]]` with required `zone` and `workspace`, plus
  optional `monitor`.
- [x] Validate duplicate zone targets and duplicate workspaces within one raw
  monitor scope.
- [x] Validate binding zone ids against inline `[[zones]]` columns and
  `[[zone-layouts]]` columns.
- [x] Add `apply-zone-bindings` parser, help metadata, CLI description, command
  dispatch, and post-command refresh policy.
- [x] Apply bindings through the same workspace viewport activation path used by
  `use-zone-scene`.
- [x] Preserve layout, widths, availability, and styles while changing active
  workspaces.
- [x] Fast tests cover parsing, invalid config, command parsing, workspace
  activation, monitor-scoped overrides, hidden target zones, and zones missing
  from the target monitor's active layout.
- [x] Add `script/e2e/configs/zone-bindings.toml` for the Tart proof.

Fast validation already run:

- `swift test --filter 'ZoneCommandTest|ConfigTest/testParseZoneBindings|ConfigTest/testRejectInvalidZoneBindings'`
  passed with 54 selected tests.
- `python3 script/check-command-metadata` passed.

Tart video gate:

- Use a new config fixture, `script/e2e/configs/zone-bindings.toml`, with
  `[[zones]]` columns and `[[zone-bindings]]` for `ReferenceDesk`, `WorkDesk`,
  and `CommsDesk`.
- The guest script must start from a clean desktop, show the config chip
  `Config: [[zone-bindings]] ReferenceDesk + WorkDesk + CommsDesk`, and show the
  exact command chip `Run: winmux apply-zone-bindings`.
- Large labeled TextEdit documents must show the before-state zone workspaces
  and the after-state bound workspaces. The viewer must be able to understand
  the transition without reading logs: BEFORE documents are visible before the
  command, then BOUND documents appear in the same zones after the command.
- The on-screen command/actions panel must expose the user-facing WinMux command:
  `winmux apply-zone-bindings`, plus the proof command
  `winmux list-zones --format '%{monitor-zone-id}|%{monitor-active-workspace}'`.
- Required proof logs: `slice-14-bindings-before.log`,
  `slice-14-apply-zone-bindings.log`, `slice-14-command-timing.log`,
  `slice-14-bindings-after.log`, `slice-14-windows-before.log`,
  `slice-14-windows-after.log`, and `slice-14-zone-bindings.done`.
- The command timing log must prove `apply-command-offset-seconds` is inside the
  `Run: winmux apply-zone-bindings` caption interval. This explicitly rejects a
  recording where BOUND documents appear before the command chip.
- Required media: `recordings/slice-14-zone-bindings.mov`, raw recording,
  ready/before/after screenshots, and a contact sheet.
- The verifier must reject any artifact where the workspace change is inferred
  only from logs, where the BEFORE/BOUND documents are not visible in the
  expected zones, where command chips omit `apply-zone-bindings`, where the
  config chip omits `[[zone-bindings]]`, where unrelated setup windows are
  visible, or where stale semantic screenshots are reused from an older
  recording.
- A no-context artifact reviewer must compare the recording to the repo root
  videos and product-site style: clean desktop, legible text, exact command
  chips, no setup prompts, and visible before/action/after motion.
- Do not mark Slice 14 accepted, start Slice 15, or commit an accepted-artifact
  claim until the mechanical verifier passes and the no-context review says
  `PASS` or `PASS_WITH_NOTES` with `next slice allowed: yes`.
- After the artifact review, run three no-context retrospective subagents over
  the Codex session history and fold accepted plan/code/harness optimizations
  into the Pre-Slice-15 cleanup checklist.

Artifact review hardening added during Slice 14:

- `artifacts/e2e/slice-14-20260626T173701Z` failed no-context review because
  BOUND documents appeared before the `Run: winmux apply-zone-bindings` command
  chip.
- The guest script now delays the command until the command caption interval and
  writes `slice-14-command-timing.log`.
- The verifier rejects artifacts without `apply-command-offset-seconds` inside
  the command caption interval and the review prompt includes a Slice
  14-specific boundary-frame check.
- `artifacts/e2e/slice-14-20260626T174756Z` passed mechanical verification but
  lost a BOUND Work document in later samples after closing hidden BEFORE
  windows through WinMux. Hidden-node closure is not accepted for this proof.
- `artifacts/e2e/slice-14-20260626T175215Z` passed mechanical verification but
  failed no-context review because a clipped `before-work-zone-binding.rtf`
  setup window remained visible at the final bottom-right edge.
- `artifacts/e2e/slice-14-20260626T180249Z` tried TextEdit document cleanup
  through AppleScript and failed with macOS Automation permission error `-1743`.
  Permission-dependent AppleScript cleanup is not accepted for this proof.
- The guest script now rechecks the final after-state after the hold period.
- Product fix added: inactive workspace window parking uses the physical
  monitor boundary, not the zone viewport boundary, so hidden windows from a
  middle/right virtual monitor are not parked inside the visible ultrawide.

Non-claims:

- Slice 14 does not prove tab-group-specific persisted binding records,
  app-rule-specific binding records, snap-to-window, visual zone editing, or
  runtime snap-policy overlays.
- Slice 14 does not replace `use-zone-scene`; scenes remain the layout plus
  workspace macro.

Accepted result:

- artifact: `artifacts/e2e/slice-14-20260626T181019Z`
- recording: `artifacts/e2e/slice-14-20260626T181019Z/recordings/slice-14-zone-bindings.mov`
- raw recording: `artifacts/e2e/slice-14-20260626T181019Z/recordings/raw/slice-14-zone-bindings.raw.mov`
- review: `artifacts/e2e/slice-14-20260626T181019Z/reviews/no-ctx-artifact-review.md`
  ended with `PASS` and `next slice allowed: yes`.
- main-thread verifier: `make e2e-verify-slice RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-14-20260626T181019Z ARGS=--require-review`
  passed.
- focused validation: `swift test --filter 'ZoneCommandTest|ConfigTest/testParseZoneBindings|ConfigTest/testRejectInvalidZoneBindings|MonitorTopologyTest/testZoneHiddenWindowParkingUsesPhysicalMonitorBoundary'`
  passed with 55 selected tests.
- pre-Tart gate: `make e2e-pre-tart-checks` passed, including shell checks,
  command metadata, harness self-tests, annotation preflight, warmup-policy
  self-test, and 99 selected Swift tests.
- accepted claim: `apply-zone-bindings` reads `[[zone-bindings]]`, activates
  ReferenceDesk, WorkDesk, and CommsDesk in left/main/right without changing
  zone geometry, and leaves the final desktop visually clean.
- accepted hardening: command/action timing is mechanically checked, the
  reviewer prompt requires Slice 14 boundary-frame inspection, final-state
  contamination is visually rejected, and inactive workspace parking uses the
  physical monitor boundary rather than the zone viewport boundary.
- failed-attempt ledger:
  `slice-14-20260626T173701Z` failed command-chip ordering;
  `slice-14-20260626T174756Z` exposed unsafe hidden-node closure;
  `slice-14-20260626T175215Z` exposed a final edge sliver;
  `slice-14-20260626T180249Z` exposed permission-dependent AppleScript cleanup
  and post-mutation retry risk.
- three no-context retrospective reports:
  `retrospective-agent-a.md`, `retrospective-agent-b.md`, and
  `retrospective-agent-c.md` under the accepted artifact's `reviews/`
  directory.

Pre-Slice-15 cleanup:

- [x] Add a Slice 15 section with exactly one primary product claim and explicit
  non-claims before implementation.
- [x] Before any Slice 15 Tart run, write a visual storyboard contract: caption
  intervals, expected state at caption starts, command/action timing, after-state
  hold, boundary-frame names, and required logs.
- [x] Add expected-chip exactness for Slice 15's main commands/config surfaces
  and require the verifier to compare those strings against the annotation TSV.
- [x] Require the no-context reviewer packet/prompt to map every important
  predicate to exact media/log filenames, not only to the recording or contact
  sheet.
- [x] Add final-state edge/corner crops to reviewer packets for slices that hide,
  restore, route, swap, or park windows, so partial setup-window contamination is
  fast to inspect.
- [x] Keep proof-time cleanup limited to pre-recording setup. Do not use
  post-command AppleScript, app automation, or hidden-node closure to hide visual
  leftovers unless that cleanup behavior is the feature under test.
- [x] Make recorded proof actions terminal after the first product mutation;
  setup/warmup can retry, but proof scripts must not replay a mutated scenario.
- [x] Add one harness self-test for a post-mutation non-semantic failure and
  assert that it is not retried.
- [x] Expand the inactive-workspace parking regression across left/main/right
  zone monitors and both hide corners. This keeps the source-level geometry seam
  covered; a higher-level MacWindow layout-path test remains deferred until the
  code has a non-AX seam for it.
- [x] Add an all-or-nothing follow-up for multi-zone workspace mutations in
  `apply-zone-bindings` and `use-zone-scene`, with a regression proving that a
  later binding failure does not leave earlier bindings applied.
- [x] Before the next commit/closeout, print generated-file diffs separately and
  decide whether `Sources/Common/gitHashGenerated.swift` is intentionally kept
  or reset. Decision: reset it, because the diff was build metadata generated
  from the local checkout rather than Slice 15 feature logic.
- [x] Close completed reviewer/subagent slots before spawning the next
  three-agent retrospection gate.

## Slice 15: Runtime Tab-Group Zone Binding

Goal: add the first node-level binding so a user can say "this tab group belongs
in this zone" without changing the zone layout or workspace-scene model.

Primary product claim:

- `bind-node-to-zone <zone>` binds the focused tab group, or the focused window
  when it is not in a tab group, to the target zone on the focused physical
  monitor and moves that node into the target zone's active workspace.

Why this is the next narrow slice:

- Slice 14 made workspace-to-zone binding first-class. This slice adds the next
  entity in the domain model: `WindowOrTabGroup` as a bindable content unit.
- The command should reuse the existing `move-node-to-zone` resolution and tab
  group movement semantics, then add durable binding state and an inspection
  surface.
- This keeps tab groups out of geometry math: the binding points to a zone id,
  and the move still targets that zone's active workspace.

Expected command/config surface:

- `bind-node-to-zone [--window-id <id>] <zone>`
- `unbind-node-zone-binding [--window-id <id>]`
- `list-zone-bindings`
- Optional mode binding in the slice config: `alt-z, b` or an equivalent
  discoverable key that runs `bind-node-to-zone current` or a named target.

Implementation checklist:

- [x] Add parser, dispatch, help metadata, and CLI descriptions for
  `bind-node-to-zone`, `unbind-node-zone-binding`, and `list-zone-bindings`.
- [x] Add a runtime node binding store keyed by `window:<id>` or
  `tab-group:<sorted-window-ids>`, with list rows that expose node id, node
  type, title, zone id, workspace, and physical monitor.
- [x] Reuse the existing zone selector and tab-group move semantics so binding a
  tab group still means moving that group into the target zone's active
  workspace.
- [x] Add fast command tests for parse coverage, focused tab-group binding,
  `--window-id` binding, list output, and unbind.
- [x] Add Slice 15 Tart scenario, annotated recording plan, semantic sample
  manifest, verifier rules, reviewer-packet checks, and no-context artifact
  prompt hardening.
- [x] Record Slice 15 Tart artifact, run mechanical verification, run
  no-context artifact review, rerun verification with `--require-review`, and
  complete the three retrospective subagents before claiming the slice
  accepted.

Slice 15 storyboard contract:

- 0-8s: show a Work tab group with two documents visible as tabs or a tab-group
  proof surface; caption chip exposes the command/config surface.
- 8-18s: before-state proof; the tab group is in Work/main and no node binding
  exists in `list-zone-bindings`.
- 18-30s: command/action boundary; caption chip shows
  `Run: winmux bind-node-to-zone Comms` while the tab group is still in Work.
  The guest proof must emit `winmux-e2e-mutation-started=1` immediately before
  the command.
- 30-44s: after-state proof; the same tab group/window ids are in Comms/right
  and `list-zone-bindings` shows the bound node id/type/title and zone id.
- 44-54s: persistence/inspection hold; the same binding remains visible after a
  refresh or another harmless inspection command.
- Required timing log: `slice-15-command-timing.log`, with the bind command
  offset inside the command caption interval.
- Required media: annotated recording, raw recording, ready/before/after
  screenshots, caption boundary samples, final edge/corner crops, and contact
  sheet.

Expected verifier/reviewer checks:

- Before media shows the same tab group/window ids in Work/main and no binding.
- Command caption starts before the tab group appears in Comms/right.
- After media shows the same tab group/window ids in Comms/right.
- `list-zone-bindings` proves the binding record by node id, node type, title,
  zone id, workspace, and physical monitor.
- No post-command cleanup hides stale windows; if the final state is dirty, fix
  product behavior or scenario setup and rerecord.

Non-claims:

- No app-rule matchers, launch-time routing by binding, snap-to-window, visual
  zone editor, or gesture configuration.
- No claim that a binding follows a tab group across app relaunch until the
  backing persistence seam is designed and tested.
- No change to `[[zone-bindings]]`; workspace bindings and node bindings remain
  separate entity types.

Accepted result:

- artifact: `artifacts/e2e/slice-15-20260626T191732Z`
- recording:
  `artifacts/e2e/slice-15-20260626T191732Z/recordings/slice-15-node-zone-binding.mov`
- raw recording:
  `artifacts/e2e/slice-15-20260626T191732Z/recordings/raw/slice-15-node-zone-binding.raw.mov`
- review:
  `artifacts/e2e/slice-15-20260626T191732Z/reviews/no-ctx-artifact-review.md`
  ended with `PASS` and `next slice allowed: yes`.
- main-thread closeout:
  `make e2e-slice-closeout-check RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-15-20260626T191732Z`
  passed.
- fresh no-context reviewer reran:
  `make e2e-verify-slice-check RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-15-20260626T191732Z ARGS=--require-review`
  and reported `PASS`.
- focused validation:
  `swift test --filter 'ConfigTest.testParseZoneNodeBindingsE2EConfig|ConfigTest.testParseZoneBindings|ConfigTest.testRejectInvalidZoneBindings|ZoneCommandTest'`
  passed with 59 selected tests.
- pre-Tart gate: `make e2e-pre-tart-checks` passed, including shell checks,
  command metadata, package/verifier self-tests, annotation preflight,
  warmup-policy self-test, and 106 selected Swift tests.
- accepted claim: `bind-node-to-zone Comms` binds the focused Work Alpha/Beta
  tab group, moves the group into Comms/right, and
  `list-zone-bindings` exposes node id, node type, title, zone, workspace, and
  monitor.
- accepted notes: visible media proves tab titles/grouping and placement; logs
  support internal window ids and the `list-zone-bindings` fields. The artifact
  does not prove workspace `[[zone-bindings]]` or relaunch persistence.
- accepted hardening: reviewer packets now require the non-mutating
  `e2e-verify-slice-check`, refresh archives stale reviews, `--check-only`
  validates derived media/review freshness, Slice 15 TOML fixture parsing is in
  the pre-Tart gate, and reviewer prompts distinguish visible evidence from
  log-supported identity evidence.
- three no-context retrospective reports:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md` under the accepted artifact directory.
- failed-review ledger: the first post-hardening fresh review failed because the
  verifier used a strict `-nt` check that rejected a sample generated in the same
  filesystem timestamp second as the recording. The verifier now uses epoch
  timestamps with a one-second tolerance; the artifact then passed a fresh review
  and closeout.

Pre-Slice-16 cleanup from Slice 15 retrospectives:

- [x] Run three no-context retrospectives after the Slice 15 artifact review and
  compare findings before proceeding.
- [x] Add a durable `make e2e-slice-15` target and document the exact command in
  `script/e2e/README.md`.
- [x] Switch reviewer packets to the non-mutating
  `make e2e-verify-slice-check RUN_DIR=... ARGS=--require-review` command and
  include `make e2e-slice-closeout-check RUN_DIR=...`.
- [x] Harden artifact refresh so regenerated annotated media archives any stale
  no-context review.
- [x] Harden `--check-only` verification for stale samples, contact sheets,
  sample manifests, edge/corner crops, and reviews.
- [x] Add parser coverage for the actual Slice 15 E2E TOML fixture and include
  zone-binding parser tests in the pre-Tart gate.
- [x] Clarify reviewer prompts so visible media proves titles/tab grouping and
  placement, while logs may support internal window id identity unless ids are
  visibly rendered.
- [x] Regenerate the Slice 15 reviewer packet after cleanup, rerun a fresh
  no-context artifact review against that packet, and pass
  `make e2e-slice-closeout-check`.

Deferred node-binding follow-ups before expanding binding semantics:

- [x] Add negative command coverage for disabled zones, no zones, rebind
  overwrite, unbind-missing, and stale-prune behavior.
- [x] Decide the current runtime node binding does not survive tab membership
  changes; because the runtime key is `tab-group:<sorted-window-ids>`, a
  membership change prunes the stale record. A future durable binding can choose
  a different stable tab-group identity deliberately.
- [x] Make `list-zone-bindings` output machine-safe for titles containing
  separator characters before treating it as a stable automation format.
- Consider factoring the duplicated `moveWindowOrTabGroupToWorkspace` overloads
  after the command semantics settle.

## Slice 16: Mouse Snap Affordance Semantics

Goal: make the mouse UX impossible to misread in proof artifacts. A reviewer
should be able to tell whether a drag is freeform, snapping to a whole zone, or
targeting a position inside a zone.

Primary product claim:

- With the current mouse snap policy, the only snap target is a whole zone. The
  overlay, command chips, logs, and final media must say "Snap to zone" and must
  not imply snapping to a window or tab slot.

Implementation and proof requirements:

- Keep `mouse.zone-snap.target = "zone"` as the only implemented target for this
  slice; add explicit negative docs/tests for `window` or `slot` targets if those
  names enter config later.
- Record both freeform and modifier-activated snap paths in one clean Tart video.
  The freeform path must leave the window floating where dragged. The snap path
  must move the same window or tab group to the target zone's active workspace.
- The overlay and on-screen caption must expose the expected user action, for
  example `Hold Option while dragging: snap to Comms zone`.
- The verifier packet must include exact media samples for freeform-before,
  snap-overlay, post-drop zone membership, and final edge/corner crops.
- The no-context reviewer must reject any artifact that claims snap-to-window or
  snap-to-slot unless the media shows that target explicitly.

Pre-slice cleanup:

- [x] Reuse the accepted Slice 12 mouse-drag scenario with Slice 16-specific
  artifact names, captions, and sample manifest rows instead of creating a
  second mouse automation path.
- [x] Add a mechanical overlay sentinel: crop the target zone during the
  no-Option hover and the Option-held hover, compute their RMSE, and require a
  visible difference before the artifact can pass.
- [x] Harden `write-review-packet`, `verify-artifact`, and the no-context review
  prompt so Slice 16 fails if the artifact only proves final placement, omits the
  drag affordance, or leaves the snap target ambiguous.
- [x] Add `make e2e-slice-16`, annotation preflight rows, README usage, and a
  `configs/zone-mouse-snap.toml` Tart scenario entry for Slice 16.
- [x] Run the pre-Tart gate after the cleanup:
  `make e2e-pre-tart-checks`.
- [x] Record the Tart video and screenshots with
  `TART_HOME=/Volumes/RiftTartVMs make e2e-slice-16`.
- [x] Run no-context artifact review and `make e2e-slice-closeout-check` before
  any next slice starts.

Non-claims:

- No configurable gesture vocabulary beyond the existing modifier-gated drag
  policy.
- No snap target inside a window, tab group, or layout slot.
- No persistence of mouse policy in runtime overlay state.

Accepted result:

- artifact: `artifacts/e2e/slice-16-20260626T205458Z`
- recording:
  `artifacts/e2e/slice-16-20260626T205458Z/recordings/slice-16-mouse-snap-affordance.mov`
- raw recording:
  `artifacts/e2e/slice-16-20260626T205458Z/recordings/raw/slice-16-mouse-snap-affordance.raw.mov`
- review:
  `artifacts/e2e/slice-16-20260626T205458Z/reviews/no-ctx-artifact-review.md`
  starts with `PASS`, says `next slice allowed: yes`, and ends with `PASS`.
- mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-16-20260626T205458Z`
  passed with duration `71.983333s`, 3440x1440 H.264 video, 3429 frames, and
  a generated contact sheet.
- no-context reviewer reran:
  `make e2e-verify-slice-check RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-16-20260626T205458Z ARGS=--require-review`
  and reported `PASS`.
- main-thread closeout:
  `make e2e-slice-closeout-check RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-16-20260626T205458Z`
  passed.
- pre-Tart gate:
  `make e2e-pre-tart-checks` passed after the Slice 16 modifier-label cleanup,
  including shell checks, command metadata, package/verifier self-tests,
  annotation preflight, warmup-policy self-test, and 106 selected Swift tests.
- accepted claim: the recording shows two desktop TextEdit drags of the same
  `snap-demo.rtf` window. Dragging without Option leaves the window in Work/main
  and shows no whole-zone overlay. Holding Option while dragging shows the whole
  Comms/right zone overlay and moves the same window id into Comms/right on
  release.
- accepted target semantics: whole zone. The artifact does not claim
  snap-to-window or snap-to-slot.
- overlay sentinel: `logs/slice-16-mouse-snap-affordance.overlay-sentinel.tsv`
  reports `target-semantics=whole-zone` and
  `overlay-rmse-normalized=0.0578709`, above the `0.025` minimum, with target
  crops in `screenshots/slice-16-mouse-snap-affordance.overlay-sentinel/`.
- accepted notation split: config and internal event flags use `alt`; visible
  macOS-facing captions and user actions use `Option`.
- three no-context retrospective reports:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md` under the accepted artifact directory.
- superseded attempt:
  `artifacts/e2e/slice-16-20260626T204655Z` produced media and a reviewer
  packet, but had no accepted no-context review and failed
  `e2e-verify-slice-check` because its proof manifest still expected an
  `Action: hold Alt while dragging snap-demo.rtf` caption while the Slice 16
  annotation contract used the macOS-facing Option wording. It is now marked
  with `reviews/superseded.md` and `logs/run-abort-status.txt`.

Pre-Slice-17 cleanup from Slice 16 retrospectives:

- [x] Read all three Slice 16 retrospectives and fold accepted blockers into
  this checklist.
- [x] Run the post-review closeout verifier:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-16-20260626T205458Z`.
- [x] Close Slice 16 in this plan with accepted artifact paths, verifier/review
  evidence, claims, non-claims, the superseded-attempt ledger, and
  retrospective paths.
- [x] Isolate the accepted Slice 14-16 dirty work before starting Slice 17:
  split generated-file diffs from source/harness/docs, then commit the accepted
  state as this slice-boundary commit.

Additional hardening:

- [x] Before the next mouse-proof slice, remove remaining hard-coded
  reviewer-facing `Alt` wording from generated proof text and
  overlay-sentinel notes where the user-facing key should be `Option`; keep
  `modifier = 'alt'` when quoting config. Historical accepted artifacts remain
  verifier-compatible.
- [x] Add a durable failed-attempt marker convention:
  `./script/e2e/tart-recording-harness mark-superseded` writes
  `reviews/superseded.md` and `logs/run-abort-status.txt` for runs that produce
  media but are replaced before review.

Deferred non-blocking hardening:

- Consider a verifier-owned expected-caption contract for future slices so
  `expected-chips.txt` is not only regenerated from the annotation TSV it is
  meant to help review.
- Consider labeling command timing logs as proof-script-relative versus
  recording-relative before a future reviewer needs to use those offsets.

## Slice 17: Node Binding Guardrails and Machine-Safe Inspection

Goal: make runtime window/tab-group zone bindings reliable enough to build on
without overclaiming persistence. This slice hardens the command surface around
bad targets, stale records, rebinding, and automation-safe inspection.

Primary product claim:

- `bind-node-to-zone`, `unbind-node-zone-binding`, and `list-zone-bindings`
  behave predictably for disabled/no-zone targets, rebinding, missing unbinds,
  stale tab-group membership, and titles containing separator characters.

Implementation requirements:

- Keep `list-zone-bindings` as the current command surface, but make every field
  value backslash-escaped for `\`, `|`, `=`, LF, and CR so scripts can parse the
  pipe-delimited format without title ambiguity.
- Add in-process command tests for no zones, disabled zones, rebind overwrite,
  unbind-missing, stale tab-group prune, and escaped title output.
- Preserve the Slice 15 non-claim: runtime node bindings are not durable across
  relaunch, and tab-group bindings use current membership as identity.
- Do not add app-rule, launch-time, or persistent tab-group binding semantics in
  this slice.

Tart proof requirement:

- Record a short Slice 17 video that shows the user-facing command surface and
  state board for the guardrails:
  - escaped `list-zone-bindings` output for a title containing separators;
  - rebinding the same window from Reference to Comms with the count staying at
    one;
  - disabled-zone and missing-unbind failures shown as expected guardrails;
  - stale tab-group binding pruning after a visible membership change.
- The no-zone rejection path is covered by the in-process command test because a
  Tart recording must run with configured zones to demonstrate the other
  guardrails; do not overclaim no-zone desktop behavior in the video.
- On-screen captions must expose the WinMux commands exactly, for example
  `winmux bind-node-to-zone Comms`,
  `winmux list-zone-bindings`, and
  `winmux unbind-node-zone-binding`.
- The no-context artifact reviewer must reject the slice if the video only shows
  final state, hides the command/error text, or claims relaunch persistence.
- Do not proceed to Slice 18 until the Slice 17 Tart artifact has mechanical
  verification, no-context artifact review, `--require-review` verification,
  closeout, and the three no-context retrospectives.

Current status:

- [x] Source guardrail implementation started.
- [x] Focused command tests added for the intended Slice 17 guardrails.
- [x] Tart harness scenario, semantic sample manifest, and mechanical verifier
  added for Slice 17.
- [x] Review packet, no-context prompt, README, and plan updated to require
  visible Slice 17 command/error/action proof before acceptance.
- [x] Focused Swift validation passed:
  `swift test --filter ZoneCommandTest`.
- [x] `make e2e-pre-tart-checks` passed after source/doc changes.
- [x] Re-run focused Swift, shell, annotation, verifier self-test, and
  pre-Tart checks after the Slice 17 harness/reviewer edits.
- [x] Slice 17 Tart artifact recorded.
- [x] No-context artifact review passed and `next slice allowed: yes`.
- [x] Three no-context retrospectives completed and baked into pre-Slice-18
  cleanup.
- [x] Slice 17 accepted and committed.

Accepted result:

- artifact: `artifacts/e2e/slice-17-20260626T221824Z`
- recording:
  `artifacts/e2e/slice-17-20260626T221824Z/recordings/slice-17-node-binding-guardrails.mov`
- raw recording:
  `artifacts/e2e/slice-17-20260626T221824Z/recordings/raw/slice-17-node-binding-guardrails.raw.mov`
- review:
  `artifacts/e2e/slice-17-20260626T221824Z/reviews/no-ctx-artifact-review.md`
  reports `Verdict: PASS_WITH_NOTES`, has the exact line
  `next slice allowed: yes`, and ends with `PASS_WITH_NOTES`.
- mechanical verifier:
  `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-17-20260626T221824Z`
  passed with a 3440x1440 H.264 annotated video, duration `69.983333s`, and
  3032 frames.
- post-review verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-17-20260626T221824Z ARGS=--require-review`
  passed.
- main-thread closeout:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-17-20260626T221824Z`
  passed after the sibling-artifact hygiene check, the no-context review, and
  all three retrospectives were present.
- pre-Tart gate:
  `TART_HOME=/Volumes/RiftTartVMs make e2e-slice-17` embedded
  `make e2e-pre-tart-checks`, including shell checks, command metadata,
  package/verifier self-tests, annotation preflight, warmup-policy self-test,
  and 112 selected Swift tests.
- accepted claim: runtime node-binding commands reject disabled targets, report
  missing unbinds, overwrite rebinds for the same window, expose
  machine-safe escaped `list-zone-bindings` rows for separator-containing
  titles, and prune stale tab-group bindings after a visible membership change.
- accepted non-claims: no relaunch persistence, no app-rule bindings, no
  launch-time rebinding, and no durable tab-group identity. Tab-group bindings
  still use current membership as identity.
- accepted review note: `screenshots/01-ready-slice-17.png` is a
  setup/staging checkpoint. The count-zero proof-ready board is visible in the
  primary recording samples, especially `standard-00-start.png` and
  `caption-01.png`.
- three no-context retrospective reports:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md` under the accepted artifact directory.

Failed and superseded attempt ledger:

- `artifacts/e2e/slice-17-20260626T215835Z`: pre-recording semantic setup
  failure. It has no accepted media; `logs/run-abort-status.txt` reports
  `recording_started=no`.
- `artifacts/e2e/slice-17-20260626T220321Z`: produced media and a reviewer
  packet, but the mechanical verifier rejected placeholder command chips such
  as `--window-id <id>` in the captions. It is marked with
  `reviews/superseded.md` and `logs/run-abort-status.txt`, superseded by
  `slice-17-20260626T221824Z`.
- `artifacts/e2e/slice-17-20260626T221450Z`: pre-recording capture-readiness
  failure. It has no product media and is not an accepted artifact.

Pre-Slice-18 cleanup from Slice 17 retrospectives:

- [x] Read all three Slice 17 retrospectives and fold accepted blockers into
  this checklist.
- [x] Mark the media-producing stale run
  `artifacts/e2e/slice-17-20260626T220321Z` superseded before relying on
  Slice 17 artifact globs.
- [x] Add a sibling-artifact hygiene check to closeout so same-slice media
  artifacts must be either accepted or explicitly superseded.
- [x] Tighten no-context review verification to require the exact lowercase
  line `next slice allowed: yes`.
- [x] Add `demo-columnar-zones.mp4` to the product baseline list used by
  reviewer packets and no-context artifact reviews.
- [x] Run the post-review closeout verifier:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-17-20260626T221824Z`.
- [x] Isolate the accepted Slice 17 dirty work and commit it before starting
  Slice 18.
- [ ] Conditional for future proof-board slices: make semantic ready labels
  point at recording-time evidence, or name setup-only screenshots as setup
  checkpoints, before the Tart proof run.

## Slice 18: Durable Zone Affinity Routing

Goal: give users a concise config surface for app/window routing to zones,
without making them write `on-window-detected` command hooks for common cases.

Primary product claim:

- `[[zone-affinities]]` routes newly detected matching windows to the target
  zone's active workspace, using the detected window id rather than the focused
  window.

Why this is the next narrow slice:

- The original product goal includes binding tab groups or application groups
  to specific zones. Workspace bindings and runtime node bindings already exist;
  this slice adds the durable rule form for new windows.
- The implementation should reuse the existing window-detected matcher and
  `move-node-to-zone` behavior, but expose a purpose-built config shape:

```toml
[[zone-affinities]]
zone = "Comms"
if.app-id = "com.apple.mail"

[[zone-affinities]]
zone = "Reference"
if.window-title-regex-substring = "reference"
```

Implementation requirements:

- Add `ZoneAffinityConfig` under `Config` with matcher, target zone,
  `check-further-callbacks`, `focus-follows-window`, and `fail-if-noop`.
- Parse `[[zone-affinities]]` as a root config array and reject entries without
  `zone`.
- Run affinities before generic `[[on-window-detected]]` callbacks. By default,
  a matching affinity stops further callbacks, matching the callback idiom.
- Execute routing through `MoveNodeToZoneCommand` with the detected window id in
  the command environment, so the focused window cannot be moved by accident.
- Add fast behavior tests for parsing, missing `zone`, detected-window routing,
  and default callback stopping.
- Do not add relaunch persistence, durable tab-group identity, app lifecycle
  reconciliation, or automatic rebinding of already-open windows in this slice.

Tart proof requirement:

- Record a clean Slice 18 video that shows the user-facing config, the action,
  and the visible result:
  - the config chip includes `[[zone-affinities]]`, target zone `Comms`, and the
    matcher for `affinity-comms`;
  - a visible Work/main window stays put as focus/source context;
  - opening or detecting `affinity-comms.rtf` moves that matching window into
    Comms/right;
  - the proof board or caption states that routing used the detected window id,
    not the focused window.
- The recording must not rely on final state alone. It must include a visible
  before state, a recorded action boundary, and an after state with the matched
  window in the target zone.
- The no-context reviewer must reject the artifact if it only proves generic
  `on-window-detected`, hides the config/action, moves the focused window
  instead of the detected window, or claims persistent tab-group/app-session
  binding.

Pre-slice cleanup:

- [x] Satisfy the remaining proof-board cleanup item from Slice 17: any ready
  screenshot label must be setup-only, or it must point at recording-time
  evidence. Slice 18 labels `01-ready-slice-18.png` as a setup checkpoint and
  uses recording-time semantic samples for the proof beats.
- [x] Add Slice 18 verifier/reviewer hard failures before recording so a weak
  affinity video cannot pass by showing only final placement.

Current status:

- [x] Source config/runtime implementation completed for the Slice 18 scope.
- [x] Focused parse and in-process routing tests added, including regression
  coverage for `check-further-callbacks = true` and `fail-if-noop` command
  failure fallthrough.
- [x] Slice 18 plan section added before e2e implementation.
- [x] Tart config, scenario, annotation plan, semantic samples, verifier,
  review packet, no-context prompt, and README entries added.
- [x] Focused Swift tests and pre-Tart checks passed.
- [x] Slice 18 Tart artifact recorded.
- [x] Mechanical verifier, no-context artifact review, `--require-review`
  verifier, closeout, and three retrospectives completed before Slice 19.

Accepted Slice 18 result:

- artifact directory:
  `artifacts/e2e/slice-18-20260626T231352Z`;
- annotated recording:
  `artifacts/e2e/slice-18-20260626T231352Z/recordings/slice-18-zone-affinity-routing.mov`;
- raw guest recording:
  `artifacts/e2e/slice-18-20260626T231352Z/recordings/raw/slice-18-zone-affinity-routing.raw.mov`;
- mechanical verifier:
  `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-18-20260626T231352Z`
  passed, proving a 3440x1440 H.264 recording, duration `49.983333s`,
  2244 frames, required logs, semantic samples, and contact sheet;
- no-context artifact review:
  `artifacts/e2e/slice-18-20260626T231352Z/reviews/no-ctx-artifact-review.md`
  ends in `PASS` and includes `next slice allowed: yes`;
- require-review gate:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-18-20260626T231352Z ARGS=--require-review`
  passed;
- closeout gate:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-18-20260626T231352Z`
  passed after all three retrospectives existed;
- fast regression gate:
  `swift test --filter 'ConfigTest.testParseZoneAffinities|ConfigTest.testParseZoneAffinitiesRequiresZone|ConfigTest.testParseZoneAffinitiesRejectsUnknownNamedZone|ConfigTest.testParseZoneAffinitiesE2EConfig|ZoneCommandTest/testZoneAffinityRoutesDetectedWindowToZone|ZoneCommandTest/testZoneAffinityStopsFurtherCallbacksByDefault|ZoneCommandTest/testZoneAffinityCheckFurtherCallbacksAllowsGenericCallback|ZoneCommandTest/testZoneAffinityFailedCommandFallsThroughToGenericCallback'`
  passed;
- retrospectives:
  `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`;
- failed or superseded Slice 18 attempts: none found.

Accepted claim:

- `[[zone-affinities]]` routes a newly detected matching window to Comms/right
  using the detected window id, while the visible focused Work/main window stays
  in Work/main.

Non-claims:

- no relaunch persistence;
- no automatic rebinding of already-open windows;
- no durable tab-group identity.

Pre-Slice-19 cleanup from Slice 18 retrospectives:

- [x] Read all three Slice 18 retrospectives together and fold accepted
  findings into this plan.
- [x] Fix zone-affinity command-result handling so a failed affinity command
  does not silently suppress generic `[[on-window-detected]]` fallbacks.
- [x] Add focused regression tests for `check-further-callbacks = true` and
  `fail-if-noop` fallthrough.
- [x] Widen the Slice 18 verifier's proof-phase manual-move scan to include
  the open-action, run, and CLI logs while continuing to allow setup staging
  moves.
- [x] Update future Slice 18 semantic manifests so `after-affinity-routing`
  points at a recording-time frame instead of only the final post-run
  screenshot.
- [x] Improve `e2e-slice-closeout-check` diagnostics so missing retrospective
  reports name the missing accepted paths instead of failing as an anonymous
  `test -s`.
- [x] Isolate the accepted Slice 18 dirty set in the Slice 18 closeout commit
  before starting Slice 19.

## Slice 19: Ergonomic Zone Style Cycling

Goal: make per-zone styling practical from a compact keyboard or command
workflow. Users should not need one binding per style token just to switch a
zone between configured states such as `urgent`, `calm`, and `muted`.

Primary product claim:

- `cycle-zone-style <zone> <style-id>...` advances the target zone through the
  provided configured style ids, wrapping back to the first style. It reuses the
  same zone selector and physical-monitor scoping rules as `set-zone-style`.

Why this is the next narrow slice:

- The user called out style changes as part of the cross-zone control surface.
  `set-zone-style` exists, but cycling is the missing ergonomic command for
  modal bindings and one-handed command workflows.
- This slice strengthens `ZoneStyle` as a real command surface without adding a
  visual editor, draggable dividers, or new mouse gesture semantics.

Implementation requirements:

- Add `cycle-zone-style [--monitor <monitor-pattern>] <zone> <style-id>...`.
- Reject an empty cycle, duplicate style ids, unknown style ids, disabled target
  zones, ambiguous zone selectors, and over-scoped selectors in the same style
  as the existing zone commands.
- If the target zone has no current style, or its current style is not in the
  provided cycle, choose the first style id.
- If the target zone's current style is in the cycle, choose the next style id,
  wrapping to the first id at the end.
- Keep style changes non-structural: active layout, active availability set,
  zone widths, active workspaces, focused workspace, and window membership must
  not change.
- Add parser, command dispatch, generated help/description metadata, and focused
  command tests.

Tart proof requirement:

- Record a clean Slice 19 video using the existing style-control visual surface:
  visible Reference, Work, and Comms zones, sidebar zone rows, and a configured
  style cycle such as `urgent calm`.
- The recording must expose the exact command/action surface:
  `winmux cycle-zone-style Comms urgent calm`.
- The video must show at least three command beats: no style -> urgent,
  urgent -> calm, and calm -> urgent wraparound.
- Captions and logs must state that this changes chrome only. The same Comms
  workspace/window should remain in the Comms zone throughout.
- The verifier and no-context reviewer must reject a Slice 19 artifact that only
  replays `set-zone-style`, omits wraparound, hides the command surface, or
  claims visual editing, draggable dividers, or snap/gesture behavior.

Current status:

- [x] Slice 18 closeout committed as `f4c14285` before Slice 19 edits started.
- [x] Plan scope for Slice 19 added before e2e implementation.
- [x] Source command implementation complete.
- [x] Focused parser and command behavior tests passing.
- [x] Tart config, scenario, annotation plan, semantic samples, verifier, review packet,
  prompt hardening, and README entries added.
- [x] Shell syntax, command metadata, and whitespace checks passed for the
  touched harness/code surfaces.
- [x] Slice 19 Tart artifact recorded and mechanically verified.
- [x] No-context artifact review, closeout verifier, and three no-context
  retrospectives completed before Slice 20.

Accepted Slice 19 result:

- accepted artifact: `artifacts/e2e/slice-19-20260627T001414Z`;
- recording: `recordings/slice-19-zone-style-cycle.mov`;
- raw recording: `recordings/raw/slice-19-zone-style-cycle.raw.mov`;
- mechanical verifier:
  `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-19-20260627T001414Z`
  passed, reporting a 59.983333s 3440x1440 H.264 recording and contact sheet;
- no-context artifact review:
  `artifacts/e2e/slice-19-20260627T001414Z/reviews/no-ctx-artifact-review.md`,
  verdict `PASS`, `next slice allowed: yes`;
- post-review verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-19-20260627T001414Z ARGS=--require-review`
  passed;
- closeout gate:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-19-20260627T001414Z`
  passed after sibling-artifact hygiene, accepted review, and all three
  retrospectives were present;
- retrospectives:
  `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`;
- accepted claim: `cycle-zone-style Comms urgent calm` advances Comms from no
  runtime style to urgent red, calm blue, then urgent red again while Reference
  and Work remain unstyled and the same windows/workspaces stay in the same
  zone ids;
- accepted non-claims: no visual style editor, no draggable dividers, no
  snap/gesture behavior, no relaunch persistence, and no new app/tab-group
  binding semantics.

Failed/pre-Tart Slice 19 attempts:

- `artifacts/e2e/slice-19-20260627T001009Z`: pre-Tart-only run. It contains
  `logs/pre-tart-checks.log` and no product media or accepted review because
  `TART_HOME` was not set to the external SSD-backed Tart home.
- `artifacts/e2e/slice-19-20260627T001055Z`: failed setup before recording.
  It has no accepted recording or review; `logs/run-abort-status.txt` reports a
  semantic failure before recording, and the setup log showed only one TextEdit
  document visible when three were expected.

Pre-Slice-20 cleanup from Slice 19 retrospectives:

- [x] Read all three Slice 19 retrospectives and fold accepted blockers into
  this checklist.
- [x] Label the accepted Slice 19 artifact and failed/pre-Tart attempts in this
  plan so future reviewers do not compare against stale paths.
- [x] Run the post-review closeout verifier:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-19-20260627T001414Z`.
- [x] Replace Slice 19's count-only TextEdit setup wait with a title-specific
  wait that retries missing documents and logs expected, observed, and missing
  titles on failure. Future multi-document TextEdit slices must reuse this
  pattern before Tart recording.
- [x] Add focused `cycle-zone-style` fast tests for current-style-outside-cycle,
  physical scoping/ambiguity, and non-structural preservation of layout,
  availability state, widths, workspaces, focus, and window membership.
- [x] Add a cheap parser test for `script/e2e/configs/zone-style-cycle.toml`.
- [x] Align future Slice 19 caption output with the full binding
  `alt-y = 'cycle-zone-style Comms urgent calm'` while keeping the verifier
  compatible with the already accepted artifact's shorter config chip.
- [x] Record the recurring style/color proof rule: any future slice whose claim
  depends on visible color or tint must add `color-sentinel.tsv` support or an
  explicit plan waiver before recording.
- [x] Isolate and commit the accepted Slice 19 dirty set before starting Slice
  20.

Non-claims:

- no new style persistence beyond the existing runtime overlay;
- no visual zone editor or draggable divider;
- no snap-to-window, snap-to-slot, or new mouse gesture vocabulary;
- no new app or tab-group binding semantics.

## Slice 20: Runtime Mouse Snap Policy Switching

Goal: make the mouse snap mode ergonomic enough to bind to a key or invoke from
the command line during a drag-focused workflow. Users should be able to switch
between freeform mouse movement and whole-zone snapping without editing config or
restarting WinMux.

Primary product claim:

- `set-zone-snap-policy` changes the effective `mouse.zone-snap.policy` for the
  current or selected physical monitor at runtime.
- `cycle-zone-snap-policy` advances that same runtime policy through a
  user-provided policy list, so a compact binding can toggle between
  `freeform`, `snap-on-modifier`, `snap-to-zone`, and `float-unless-snap`.
- The desktop drag resolver uses the runtime policy override before falling back
  to config, while preserving the existing configured modifier, gesture, and
  target.

User-facing command shape:

- `set-zone-snap-policy [--monitor <monitor-pattern>] <policy>`
- `cycle-zone-snap-policy [--monitor <monitor-pattern>] <policy>...`

Implementation requirements:

- Store the policy override on `ZoneRuntimeOverlay`, scoped by physical monitor
  identity, alongside layout, availability, width, and style runtime state.
- Resolve the target physical monitor using the same monitor scoping idioms as
  `use-zone-layout`, `cycle-zone-layout`, `balance-zones`, and runtime style
  controls. When `--monitor` is omitted, use the focused monitor's physical
  monitor.
- Validate policy ids against the existing `ZoneSnapPolicy` cases and reject
  duplicate policy ids in `cycle-zone-snap-policy`.
- Preserve all non-policy config fields. Slice 20 must not silently change
  `modifier`, `gesture`, or `target`.
- Update command metadata/help and keep `script/check-command-metadata` green.
- Add fast tests for parsing, command output, invalid policy ids, duplicate
  cycle ids, physical-monitor scoping, cycle wraparound, config fallback, and
  drag resolver behavior under runtime override.

Tart proof:

- record one clean Slice 20 video using Tart from the external SSD-backed
  `TART_HOME`;
- start with visible config showing `policy = 'freeform'`,
  `modifier = 'alt'`, `gesture = 'drag'`, and `target = 'zone'`;
- show a first drag that remains freeform with no snap overlay and no zone move;
- show the exact command or binding that changes runtime policy, for example
  `winmux set-zone-snap-policy snap-to-zone`;
- show a second drag of the same window where the whole-zone snap overlay is
  visible and release moves the window to the target zone;
- show the exact command or binding for cycling, for example
  `winmux cycle-zone-snap-policy freeform snap-to-zone`;
- include legible showcase-style captions that state the current mode, expected
  user action, and target semantics: freeform placement vs whole-zone snap.

Artifact gate:

- The mechanical verifier must reject missing command captions, missing
  `mouse.zone-snap` config, missing policy-transition logs, a hidden pointer
  path, missing overlay/no-overlay screenshots, or final-state-only proof.
- The no-context reviewer must reject any Slice 20 artifact that does not
  visually prove both runtime policy states, does not expose the exact WinMux
  commands/bindings, implies snap-to-window/slot behavior, or relies on logs
  instead of visible drag media.
- Do not proceed beyond Slice 20 until the no-context artifact review returns
  `PASS` or `PASS_WITH_NOTES` with `next slice allowed: yes`, the closeout gate
  passes, all three no-context retrospectives are complete, accepted findings
  are folded into the next pre-slice checklist, and the dirty set is committed.

Pre-Slice-20 cleanup:

- [x] Confirm Slice 19 accepted artifact, post-review verifier, closeout check,
  three retrospectives, and commit are complete before changing Slice 20 code.
- [x] Re-read Slice 12 and Slice 16 mouse proof rules so Slice 20 does not
  regress into logs-only proof.
- [x] Add Slice 20 command/model tests before recording Tart media.
- [x] Harden Slice 20 verifier and no-context review prompts before recording.
- [x] Run the full pre-Tart gate before recording:
  `make e2e-pre-tart-checks` passed with 133 selected Swift tests.

Non-claims:

- no new gesture vocabulary beyond the existing desktop drag seam;
- no snap-to-window, snap-to-slot, or in-zone slot placement;
- no visual settings/editor UI;
- no relaunch persistence for runtime snap-policy overrides;
- no change to tab-strip dragging or non-zone monitor drag behavior.

Slice 20 accepted result:

- Accepted artifact: `artifacts/e2e/slice-20-20260627T195858Z`.
- Published recording:
  `artifacts/e2e/slice-20-20260627T195858Z/recordings/slice-20-zone-snap-policy-switch.mov`.
- Raw recording:
  `artifacts/e2e/slice-20-20260627T195858Z/recordings/raw/slice-20-zone-snap-policy-switch.raw.mov`.
- Mechanical verifier passed:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-20-20260627T195858Z`.
- Post-review verifier passed:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-20-20260627T195858Z ARGS=--require-review`.
- Closeout verifier passed:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-20-20260627T195858Z`.
- No-context artifact review:
  `artifacts/e2e/slice-20-20260627T195858Z/reviews/no-ctx-artifact-review.md`
  returned `PASS_WITH_NOTES` and `next slice allowed: yes`.
- No-context retrospectives completed:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.
- Accepted claim: the video visibly shows a clean desktop, freeform drag with
  no overlay, the exact `winmux set-zone-snap-policy snap-to-zone` command
  before the snap affordance, a whole-zone target overlay and release, and the
  exact `winmux cycle-zone-snap-policy freeform snap-to-zone` command.
- Accepted note: the timing log's `snap-drag-start-offset-seconds` label is
  coarse and points at the command-caption section. Future transition or mouse
  slices must split command-caption, visible drag start, first affordance,
  release, and final placement into separate event names.

Superseded Slice 20 attempt:

- `artifacts/e2e/slice-20-20260627T192813Z` is superseded. It failed the
  stricter review because the snap overlay appeared before the
  `Run: winmux set-zone-snap-policy snap-to-zone` caption. It is marked
  superseded and the verifier now rejects it instead of treating it as accepted
  proof.

Pre-Slice-21 cleanup from Slice 20 retrospectives:

- [x] Read all three Slice 20 retrospectives and fold accepted findings into
  this checklist.
- [x] Record accepted Slice 20 artifact paths, review verdict, verifier
  commands, closeout, retrospectives, superseded artifact, claims, notes, and
  non-claims in this plan.
- [x] Replace full-frame transparent caption overlays with small caption-card
  assets so annotation refreshes complete in about one minute instead of
  several minutes.
- [x] Add a focused fast test for `cycle-zone-snap-policy` when the current
  effective policy is outside the supplied cycle list.
- [x] Before the next transition or mouse artifact, add an explicit event
  manifest under the run logs with labeled subsecond events for command
  start/end, drag pickup/path/hover/release, post-state inspection, and any
  first-affordance frame. Slice 20-style artifacts now write
  `<recording>.event-manifest.tsv` and drive semantic command/release/cycle
  sample rows from it.
- [x] Update the verifier to validate command-caption, drag-sample,
  overlay-sample, and post-command-inspection ordering from the event manifest
  when the manifest exists, rather than relying only on caption start times.
- [x] Add overlay sentinel freshness and crop-dimension validation relative to
  the source screenshots.
- [x] Normalize guest proof/action manifest paths to artifact-relative paths for
  future mouse snap proof manifests.
- [x] Update the next reviewer packet to require concrete baseline-media
  evidence from actual local media/screenshots, including
  `demo-columnar-zones.mp4` for columnar-zone demos.
- [x] Write the next slice storyboard, caption budget, accepted claims, and
  explicit non-claims before recording.
- [x] If the next slice has transitions, keep command-caption start, visible
  drag start, first affordance, release, and final placement as separate log
  fields and verifier assertions; the event-manifest contract is the required
  mechanism for this.

## Slice 21: Ergonomic Zone Mode V2

Goal: make the implemented zone controls discoverable from one compact keyboard
surface instead of scattered one-off bindings. Users on an ultrawide should be
able to enter zone mode and perform common cross-zone work without memorizing
the full CLI.

Product claim:

- The starter config exposes a universal zone-mode snap-policy cycle binding
  that toggles desktop dragging between freeform and whole-zone snapping without
  requiring user-specific zone names.
- The README and Slice 21 example config show the fuller ergonomic pattern when
  the user's config defines layout presets, availability sets, and styles:
  focus/move, resize/balance, toggle current zone, cycle layout, cycle
  availability, cycle current-zone style, and cycle snap policy.
- All bindings are thin wrappers over the existing commands. No new hidden
  zone-mode semantics are introduced.

Binding shape:

```toml
[mode.main.binding]
alt-z = 'mode zone'

[mode.zone.binding]
esc = 'mode main'
h = ['focus-zone prev', 'mode main']
l = ['focus-zone next', 'mode main']
shift-h = ['move-node-to-zone --focus-follows-window prev', 'mode main']
shift-l = ['move-node-to-zone --focus-follows-window next', 'mode main']
minus = ['resize-zone current width -10%', 'mode main']
equal = ['resize-zone current width +10%', 'mode main']
"0" = ['balance-zones', 'mode main']
t = ['toggle-zone current', 'mode main']
space = ['layout floating tiling', 'mode main']
s = ['cycle-zone-snap-policy freeform snap-to-zone', 'mode main']
tab = ['cycle-zone-layout balanced focus', 'mode main']
a = ['cycle-zone-availability focus-only communications full-dashboard', 'mode main']
y = ['cycle-zone-style current urgent calm', 'mode main']
```

Implementation scope:

- Add only the universal `s` snap-policy cycle binding to
  `resources/default-config.toml` and `starterConfigText()`, because it does not
  depend on user-defined layout, availability-set, style, or zone ids.
- Add `zone-mode-v2.toml` as the e2e/demo config that defines the required
  layout presets, availability sets, and style tokens for the richer bindings.
- Update README columnar-zone examples so users see the full ergonomic pattern
  and understand which bindings require named presets/sets/styles.
- Add parser/bootstrap tests proving starter `s` and example `tab`/`a`/`y`/`s`
  bindings parse to the expected commands.

Storyboard and caption budget:

- Start on a clean ultrawide desktop with a visible state board listing the
  zone-mode keys and the exact command behind each key.
- Show `Alt-Z, S`: cycle snap policy from freeform to snap-to-zone. The caption
  must expose `cycle-zone-snap-policy freeform snap-to-zone`.
- Show `Alt-Z, Tab`: cycle layout from balanced to focus. The caption must
  expose `cycle-zone-layout balanced focus`.
- Show `Alt-Z, A`: cycle availability to a named set. The caption must expose
  `cycle-zone-availability focus-only communications full-dashboard`.
- Show `Alt-Z, Y`: cycle the current zone style. The caption must expose
  `cycle-zone-style current urgent calm`.
- End with `winmux list-zones` / `winmux list-windows` inspection visible on the
  state board. Keep captions short and do not obscure zone edges or style
  swatches.

Tart proof:

- Record `slice-21-zone-mode-v2.mov` from the guest display using the
  external-SSD-backed Tart harness.
- Add `slice-21-zone-mode-v2.event-manifest.tsv` with command-start and
  result-state rows for every keyboard binding beat. Mouse and transition
  slices still require the stricter command start/end, drag
  pickup/path/hover/release, first-affordance, and post-state inspection rows.
- Mechanical verifier must reject missing config chips, missing event manifest,
  missing semantic samples, stale state-board frames, hidden command surfaces,
  or any claim that a binding worked when the target preset/set/style id was not
  defined in config.
- No-context artifact review must compare the video against
  `demo-columnar-zones.mp4`, root product demos, and the product screenshots;
  it must name exact media for each binding beat before allowing the next slice.
- Do not proceed beyond Slice 21 until the video, mechanical verifier,
  no-context artifact review, closeout gate, three retrospectives, accepted
  findings, and commit are complete.

Accepted claims:

- starter config adds only a universal snap-policy cycle binding;
- the richer example config demonstrates the complete ergonomic zone mode when
  its referenced ids are defined;
- the bindings call existing commands and preserve the existing zone entity
  model.

Non-claims:

- no new keybinding engine behavior;
- no default hardcoded layout/style/availability ids in starter config;
- no mouse gesture recognizer beyond existing desktop drag and snap-policy
  commands;
- no snap-to-window, snap-to-slot, visual zone editor, or relaunch persistence.

Slice 21 accepted result:

- accepted artifact: `artifacts/e2e/slice-21-20260627T213416Z`;
- recording: `recordings/slice-21-zone-mode-v2.mov`;
- raw recording: `recordings/raw/slice-21-zone-mode-v2.raw.mov`;
- contact sheet:
  `screenshots/slice-21-zone-mode-v2.contact-sheet.jpg`;
- reviewer packet: `reviews/reviewer-packet.md`;
- no-context artifact review: `reviews/no-ctx-artifact-review.md`, ending
  `next slice allowed: yes` and `PASS`;
- mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-21-20260627T213416Z ARGS=--require-review`,
  passed with a 3440x1440 H.264 recording, 91.950000s duration, and 4074
  frames;
- retrospectives: `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and `retrospectives/artifact-product.md`;
- accepted event-manifest contract: keyboard-mode Slice 21 uses ordered
  command-start and result-state events. The richer command-end/visual-change
  wording is reserved for mouse and transition slices where a visible affordance
  or release timing is the product behavior.

Accepted claims:

- the starter config adds the universal `Alt-Z, S` zone-mode binding for
  `cycle-zone-snap-policy freeform snap-to-zone`;
- the README and `zone-mode-v2.toml` example show the richer ergonomic zone
  surface for layout, availability, style, and snap-policy cycling when the
  referenced ids are defined;
- the Slice 21 video visibly shows the user-facing `Alt-Z, S`, `Alt-Z, Tab`,
  `Alt-Z, A`, and `Alt-Z, Y` actions, the corresponding WinMux commands, and
  runtime state changes for snap policy, layout width, availability visibility,
  and urgent zone styling;
- each demonstrated binding enters zone mode through `Alt-Z`, runs the existing
  command through `trigger-binding`, and returns to main mode.

Accepted non-claims:

- Slice 21 does not prove new keybinding-engine semantics;
- Slice 21 does not add default hardcoded layout/style/availability ids to the
  starter config;
- Slice 21 does not prove mouse gesture recognition, drag snapping,
  snap-to-window, snap-to-slot, a visual zone editor, persistence, or relaunch
  routing.

Failed Slice 21 attempts:

- `artifacts/e2e/slice-21-20260627T212033Z` is pre-Tart-only. It contains
  `logs/pre-tart-checks.log` and no product media, reviewer packet, or accepted
  review.
- `artifacts/e2e/slice-21-20260627T212108Z` is a superseded pre-recording
  semantic setup failure. It failed before recording because the Safari-backed
  board path did not become reliable on the fresh VM. It has no accepted media
  or review.

Pre-Slice-22 cleanup from Slice 21 retrospectives:

- [x] Read all three Slice 21 retrospection reports and fold accepted findings
  into this checklist.
- [x] Close the Slice 21 durable plan status with accepted artifact, media,
  review, verifier, retrospective, failed-attempt, claim, and non-claim
  evidence.
- [x] Reconcile the Slice 21 event-manifest contract: keyboard-mode proof uses
  ordered command-start/result-state rows; mouse and transition proof keeps the
  stricter command-end, affordance, release, and inspection event contract.
- [x] Rerun `make e2e-slice-closeout-check
  RUN_DIR=artifacts/e2e/slice-21-20260627T213416Z` after this plan update.
- [x] Decide generated `Sources/Common/gitHashGenerated.swift` churn before the
  Slice 21 closeout commit. The generated hash update was excluded as local
  build noise.
- [x] Before the next live-board proof, stop reusing setup window logs for
  proof-board placement or add phase-specific board/window freshness rows so
  setup evidence cannot satisfy proof evidence.
- [x] Before the next keyboard-surface artifact, make the ready board list exact
  key-to-command mappings instead of only the compact summary.
- [x] Before the next Slice 21-style keyboard verifier, add an ordered action-log
  assertion that checks the exact five binding blocks instead of only required
  substrings and counts.
- [x] Improve future TextEdit setup diagnostics so timeout logs show which
  titles were missing, which titles were seen, and whether placement or window
  existence failed.

## Slice 22: Float-Unless-Snap Mouse Policy

Goal: make the mouse path match the user's preferred one-handed default:
dragging a managed window with the mouse leaves it floating/freeform, while
holding the configured snap modifier turns the same drag into a deliberate
whole-zone snap.

Product claim:

- `[mouse.zone-snap] policy = 'float-unless-snap'` no longer means only
  "modifier-gated zone snap." It also makes an ordinary no-modifier mouse move
  detach a tiled window into the active zone workspace as a floating window.
- Holding the configured modifier preserves the existing whole-zone snap path:
  a zone overlay appears, the target is the whole zone, and release moves the
  same window into that zone's active workspace.
- The behavior is scoped to ordinary window drags over configured zones. It does
  not alter keyboard `layout floating`, sidebar drags, tab-strip drags, group
  drags, non-zone monitors, or snap-to-window/slot behavior.

Implementation scope:

- Add a fast behavior seam for `float-unless-snap` no-modifier drags:
  `Window` + target `Workspace` + subject + modifier flags in, bool result out.
- Use that seam from `moveWithMouse` before creating a pending tiling/zone-snap
  drag intent.
- Preserve the existing snap behavior when the configured modifier is held.
- Add focused `WindowZoneSnapPolicyTest` cases proving:
  - no-modifier `float-unless-snap` turns a tiled window into a floating window
    in the target zone workspace;
  - held modifier does not float the window, leaving it eligible for the
    existing snap-to-zone path;
  - group drags and non-zone monitor drags do not use this float conversion.

Storyboard and caption budget:

- Start on a clean ultrawide desktop with `policy = 'float-unless-snap'`,
  `modifier = 'alt'`, `gesture = 'drag'`, and `target = 'zone'` visible.
- Show a no-modifier drag of a tiled Work/main window. The board/caption must
  state `mode: freeform float`, `snap target: none`, and the final state must
  show the same window as floating in the visible zone workspace.
- Reset to a tiled Work/main source.
- Show an Option-held drag of the same kind of window toward Comms/right. The
  board/caption must state `mode: zone snap`, `target: whole Comms zone`, show
  the overlay/target path, and show the same window id placed in Comms/right on
  release.
- End with visible `list-windows`/state-board proof of source id, layout/floating
  state, before/after zones, and the effective policy.

Tart proof:

- Record `slice-22-float-unless-snap.mov` from the external-SSD-backed Tart
  harness.
- Use the stricter mouse/transition event-manifest contract: command/config
  context, no-modifier pickup/path/release/post-state inspection,
  modifier-held pickup/path/first-affordance/release/post-state inspection, and
  final inspection.
- The verifier must reject missing visible no-modifier freeform action frames,
  missing modifier-held overlay frames, missing source-window id continuity,
  missing floating-state proof after the no-modifier drag, hidden command/config
  surfaces, or any target that looks like a window/slot inside a zone.
- The no-context reviewer must compare the artifact against root product demos,
  `demo-columnar-zones.mp4`, and prior mouse-policy artifacts. It must reject
  logs-only proof or any video where the viewer cannot tell whether the first
  drag floated or snapped.
- Do not proceed beyond Slice 22 until the video, mechanical verifier,
  no-context artifact review, closeout gate, three retrospectives, accepted
  findings, and commit are complete.

Accepted claims:

- no-modifier `float-unless-snap` detaches an ordinary tiled window into a
  floating window in the active zone workspace;
- held configured modifier keeps the existing whole-zone snap path available;
- the behavior is scoped to configured zones and ordinary window drags.

Non-claims:

- no snap-to-window or snap-to-slot behavior;
- no new mouse gesture recognizer beyond `gesture = 'drag'`;
- no visual settings editor;
- no relaunch persistence claim;
- no group-drag or tab-strip drag float conversion.

Accepted result:

- Artifact: `artifacts/e2e/slice-22-20260627T221503Z`.
- Recording: `recordings/slice-22-float-unless-snap.mov`.
- Contact sheet: `screenshots/slice-22-float-unless-snap.contact-sheet.jpg`.
- Mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-22-20260627T221503Z ARGS=--require-review`
  passed after the no-context review was written and amended.
- Closeout gate:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-22-20260627T221503Z`
  passed with all three retrospectives present.
- No-context artifact review:
  `reviews/no-ctx-artifact-review.md` verdict `PASS`; final gate line
  `next slice allowed: yes`.
- Retrospectives:
  `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.
- Setup note: the first guest scenario setup attempt failed before recording
  with an SSH authentication retry; attempt 2 succeeded. The final artifact
  started from a clean guest desktop and passed the verifier/review gates.

Pre-Slice-23 cleanup from Slice 22 retrospectives:

- [x] Surface scenario setup/proof retries in `guest-transport-summary.tsv` or
  a review-packet-linked retry summary so reviewers see attempts, failures,
  final result, and whether each failure occurred before recording.
  Implemented by `guest-script-retry-summary.tsv` plus appended rows in
  `guest-transport-summary.tsv`; mechanically checked with `bash -n`,
  `shellcheck`, and `verify-artifact --check-only` on the Slice 22 artifact.
- [x] For the next mouse/transition proof, generate event-manifest rows from
  actual guest action timestamps for pickup, path, hover, first affordance,
  release, and post-state; use that table as the single timing source for
  captions, samples, and verifier checks.
  Implemented for the shared mouse snap scenario via
  `<recording>.mouse-events.tsv`; Slice 20 and Slice 22 event manifests use
  those rows when present, and `verify-artifact` rejects mismatched timestamps.
- [x] Bound local session-history retrospection prompts: search by artifact id
  or recording name, inspect at most three exact-hit rollout files, ignore the
  current session, and fall back to plan/diff/artifacts when no exact session is
  found.
- [x] Add review verdict fixtures to `script/e2e/verify-artifact --self-test`
  for legacy final-line `PASS`, first-line `PASS:` plus final
  `next slice allowed: yes`, missing allow line, and `FAIL`; update
  `script/e2e/prompts/no-context-artifact-review.md` and
  `script/e2e/write-review-packet` to one footer contract.
  Verified with `./script/e2e/verify-artifact --self-test`.
- [x] Introduce a table-driven mouse-drag event spec used by Slice 20 and Slice
  22 for event manifest generation, sample-label requirements, and ordering
  assertions.
  Implemented in `script/e2e/specs/mouse-drag-events.tsv`; the harness now
  generates Slice 20/22 event manifests from that table, and
  `verify-artifact` uses the same table for required event ids, kinds, sample
  labels, mouse-event timestamp checks, and before/after ordering.
- [x] Replace duplicate action-log/proof-manifest emission in
  `script/e2e/guest/slice-12-mouse-zone-snap.sh` with one schema helper, and
  make `verify-artifact` read that schema before consulting human-oriented
  logs.
  Implemented with shared action-schema emitters and manifest-first verifier
  fallbacks for the Slice 12, Slice 20, and Slice 22 mouse snap proof paths;
  verified with `bash -n`, `shellcheck`,
  `./script/e2e/verify-artifact --self-test`,
  `swift test --filter WindowZoneSnapPolicyTest`,
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-22-20260627T221503Z ARGS=--require-review`,
  and `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-22-20260627T221503Z`.
- [x] Add one behavior-level Swift test for `float-unless-snap` through the
  tiling mouse-drag caller or an extracted policy-plus-caller seam, covering
  no-modifier float and held-modifier snap eligibility.
  Added `moveTilingWindowForMouseDrag` seam coverage for no-modifier floating
  and held-modifier normal move behavior; verified with
  `swift test --filter WindowZoneSnapPolicyTest`.
- [x] Add an artifact-generation or verifier check that rejects annotated
  recordings when the last caption ends more than a short hold before video end,
  unless the run declares an intentional uncaptained tail.
  New harness runs write `<recording>.caption-tail.tsv`; the verifier requires
  an explicit reason for tails beyond `WINMUX_E2E_CAPTION_TAIL_MAX_SECONDS`.
- [x] Generate a labeled event-manifest contact sheet for mouse/transition
  slices, including overlay sentinel crops and separate no-modifier versus
  modifier branches.
  Generated as `<recording>.event-contact-sheet.jpg` from the event manifest
  and overlay sentinel crops; Slice 22 derived artifact was regenerated.
- [x] Require captioned target/release sample frames to show the visual
  affordance named by the caption, not only the after-state.
  `verify-artifact` now rejects mouse snap target/release events without
  concrete hover or release/target sample media.
- [x] Strengthen proof-only zone snap affordances with a clearer whole-zone
  outline or target label, then capture an artifact crop that makes the target
  readable without opening logs.
  Added a labeled overlay sentinel crop with
  `target-label=WHOLE ZONE TARGET: COMMS`, required it in the verifier, updated
  reviewer prompts/packets to require inspection, refreshed the Slice 22 derived
  artifact, and obtained a fresh no-context review. Verified with
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-22-20260627T221503Z ARGS=--require-review`
  and `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-22-20260627T221503Z`.

## Slice 23: Product Whole-Zone Snap Overlay Label

Goal: make the actual WinMux desktop snap affordance say what it targets. Slice
22 proved behavior and added a harness-labeled crop; Slice 23 moves that
clarity into the product overlay so a user can tell, during the drag, that the
drop target is the whole `Comms` zone and not a window or slot inside the zone.

Implementation scope:

- Extend `WindowDropIntentOverlayModel` with optional label/subtitle text.
- Populate the model from zone-snap destinations using the existing
  destination zone name, for example `Whole zone: Comms` and
  `Drop to move to Comms`.
- Render that text only for whole-zone overlays (`activeZone == nil`) so normal
  window/tab split overlays stay icon-first and unchanged.
- Add fast behavior/view-model tests that prove a zone snap destination carries
  the label while ordinary window split/tab overlays do not require one.
- Keep the overlay restrained and legible. It should improve the actual product
  affordance without depending on harness-only labels.

Tart proof:

- Record `slice-23-product-snap-overlay-label.mov` from the external-SSD-backed
  Tart harness.
- Reuse the `float-unless-snap` desktop drag scenario with a Slice 23 recording
  name/title. The Alt-held branch must show the product overlay text during
  hover, not only the generated reviewer crop.
- The harness/verifier must reject an artifact whose snap-hover media lacks a
  product-visible whole-zone label, whose no-Alt branch shows a snap label, or
  whose event manifest omits separate pickup/path/first-affordance/release
  events.
- The no-context review must inspect the full video, event contact sheet,
  `07-snap-hover-comms-slice-23.png`, the labeled overlay sentinel crop, and
  the baseline demos/product surfaces before allowing the next slice.
- After acceptance, run the three no-context retrospectives and fold findings
  into the next pre-slice cleanup before continuing.

Accepted claims:

- whole-zone desktop snap overlays expose a readable product label during drag;
- the label is tied to the target zone name and existing zone-snap destination;
- existing normal window split/tab overlays are not converted into marketing
  cards or unrelated caption surfaces.

Non-claims:

- no snap-to-window or snap-to-slot behavior;
- no new gesture recognizer;
- no visual settings editor;
- no persistence or launch-routing change.

Accepted result:

- Artifact: `artifacts/e2e/slice-23-20260628T052231Z`.
- Recording: `recordings/slice-23-product-snap-overlay-label.mov`.
- Raw guest recording:
  `recordings/raw/slice-23-product-snap-overlay-label.raw.mov`.
- Contact sheets:
  `screenshots/slice-23-product-snap-overlay-label.contact-sheet.jpg` and
  `screenshots/slice-23-product-snap-overlay-label.event-contact-sheet.jpg`.
- Product-label proof frame:
  `screenshots/07-snap-hover-comms-slice-23.png`; the actual product overlay
  reads `Whole zone: Comms` and `Drop to move to Comms`.
- Mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-23-20260628T052231Z ARGS=--require-review`
  passed.
- Closeout gate:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-23-20260628T052231Z`
  passed with all three retrospectives present.
- No-context artifact review:
  `reviews/no-ctx-artifact-review.md` verdict `PASS`; it includes
  `NO ACTIONABLE ISSUES` and final gate line `next slice allowed: yes`.
- Retrospectives:
  `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.
- Focused implementation checks:
  `bash -n` and `shellcheck` for the touched e2e scripts,
  `./script/e2e/verify-artifact --self-test`,
  `swift test --filter WindowZoneSnapPolicyTest`, and the Slice 23 pre-Tart
  gate's selected 143-test suite passed.
- Superseded Slice 23 attempts:
  `slice-23-20260628T045521Z-precheck` was pre-Tart only;
  `slice-23-20260628T045601Z` hit macOS Bash 3 `mapfile`;
  `slice-23-20260628T050034Z` missed guest mouse-event rows;
  `slice-23-20260628T050608Z` used absent guest `/bin/printf`;
  `slice-23-20260628T050900Z` concatenated event rows with literal `n`;
  `slice-23-20260628T051443Z` had a JXA string escape error;
  `slice-23-20260628T051729Z` missed `snap-drag-start` and failed the
  explicit verifier. All same-slice media attempts are accepted or formally
  superseded for the sibling-artifact closeout gate.

Pre-Slice-24 cleanup from Slice 23 retrospectives:

- [x] Run all three Slice 23 no-context retrospectives and read the reports.
- [x] Close Slice 23 in this plan with accepted artifact paths, verifier and
  review evidence, closeout evidence, retrospectives, accepted claims,
  non-claims, and superseded-attempt notes.
- [x] Align the durable review-verdict wording with the current
  first-line verdict plus final `next slice allowed: yes/no` contract.
- [x] Formally supersede stale Slice 23 media attempts so the sibling-artifact
  closeout gate compares Slice 24 only against accepted evidence.
- [x] Rerun
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-23-20260628T052231Z ARGS=--require-review`
  and
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-23-20260628T052231Z`.
- [x] Commit the accepted Slice 23 dirty set before starting Slice 24
  implementation.

Deferred hardening before the next mouse-drag proof slice:

- [x] Add a cheap guest/JXA mouse-event writer self-test that proves newline
  emission, shell quoting, `/usr/bin/printf`, and branch-specific event ids
  such as `snap-drag-start` before a full Tart recording starts.
- [x] Add local verifier fixtures for missing `snap-drag-start`, literal `n`
  separators, concatenated mouse-event rows, duplicate event ids, and missing
  first-affordance rows.
- [x] Continue reducing Slice 22/23 mouse-snap duplication by moving event
  generation, sample labels, and ordering checks behind the table-driven
  `script/e2e/specs/mouse-drag-events.tsv` seam.
- [x] Make generic `require_float_unless_snap_proof` diagnostics use the caller's
  slice label consistently.

## Slice 24: Secondary-Button Mouse Snap Gesture

Goal: make the one-handed mouse path explicit and configurable. With
`[mouse.zone-snap] policy = 'float-unless-snap'`,
`gesture = 'secondary-button-drag'`, and `target = 'zone'`, an ordinary drag
keeps the window in floating/freeform mode. Holding the secondary mouse button
while dragging activates whole-zone snapping.

User-facing behavior:

- Config:
  `policy = 'float-unless-snap'`, `modifier = 'alt'`,
  `gesture = 'secondary-button-drag'`, `target = 'zone'`.
- Ordinary left-drag of `snap-demo.rtf` moves it freely into Comms/right,
  leaves it floating, and does not show the snap overlay.
- Reset returns the same window to Work/main tiling.
- Secondary-button-held drag of the same window shows the whole Comms zone
  affordance, with the product label `Whole zone: Comms`, and drops the window
  into Comms/right on release.
- This slice proves whole-zone snap semantics only. It does not claim
  snap-to-window, snap-to-slot, a gesture editor, or persistence beyond the
  copied config used by the artifact.

Implementation scope:

- Add `secondary-button-drag` to the mouse zone-snap gesture vocabulary.
- Read the current mouse-button state at drag decision points and route it
  through the existing zone-snap policy resolver.
- Keep `snap-on-modifier` modifier-driven even if a config also names the
  secondary-button gesture.
- Add the Slice 24 E2E config, recording action, annotation plan, event
  manifest, verifier proof, review-packet entry, and strict review prompt.

Pre-Tart evidence:

- `bash -n` and `shellcheck` passed for the touched e2e scripts.
- `./script/e2e/verify-artifact --self-test` passed, including malformed
  mouse-event fixtures.
- The guest mouse-event writer self-test passed and emitted
  `snap-drag-start`, `snap-first-affordance`, and `snap-release`.
- Focused Swift coverage passed:
  `swift test --filter 'ConfigTest.testParseSecondaryButtonDragMouseZoneSnapGesture|ConfigTest.testParseFloatUnlessSnapSecondaryButtonE2EConfig|WindowZoneSnapPolicyTest'`.
- Full pre-Tart gate passed:
  `WINMUX_E2E_ALLOW_INTERNAL_DISK=1 WINMUX_E2E_MIN_FREE_GB=0 TART_HOME=/tmp/winmux-tart make e2e-pre-tart-checks`.
- Backward compatibility gate passed:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-23-20260628T052231Z ARGS=--require-review`.

Acceptance gate:

- Run `TART_HOME=/Volumes/RiftTartVMs/tart make e2e-slice-24`.
- The artifact must include a video and event contact sheet that visibly show
  both the ordinary drag and the secondary-button snap drag.
- The video must expose the relevant WinMux config/actions on screen, including
  the secondary-button gesture and whole-zone target.
- A no-context artifact reviewer must inspect the recording, contact sheets,
  event manifest, proof manifest, and baseline visual artifacts before the next
  slice starts. Logs-only or final-state-only review is not accepted.
- Closeout must pass with `--require-review`, the slice closeout gate, and all
  three post-slice retrospectives folded into the next pre-slice cleanup.

Accepted result:

- Artifact: `artifacts/e2e/slice-24-20260628T061218Z`.
- Recording: `recordings/slice-24-secondary-button-snap.mov`.
- Raw guest recording:
  `recordings/raw/slice-24-secondary-button-snap.raw.mov`.
- Contact sheets:
  `screenshots/slice-24-secondary-button-snap.contact-sheet.jpg` and
  `screenshots/slice-24-secondary-button-snap.event-contact-sheet.jpg`.
- Product-label proof frame:
  `screenshots/07-snap-hover-comms-slice-24.png`; the product overlay reads
  `Whole zone: Comms` and targets the whole Comms zone.
- Mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-24-20260628T061218Z ARGS=--require-review`
  passed.
- Closeout gate:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-24-20260628T061218Z`
  passed with all three retrospectives present.
- No-context artifact review:
  `reviews/no-ctx-artifact-review.md` verdict `PASS`; it includes
  `NO ACTIONABLE ISSUES` and final gate line `next slice allowed: yes`.
- Retrospectives:
  `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.
- Focused implementation checks:
  `bash -n`, `shellcheck`, `./script/e2e/verify-artifact --self-test`,
  guest mouse-event writer self-test, focused Swift coverage for
  secondary-button parsing/policy behavior, the full pre-Tart gate's selected
  147-test suite, and the Slice 23 backward-compatibility verifier passed.

Pre-Slice-25 cleanup from Slice 24 retrospectives:

- [x] Start Slice 25 from an explicit checkpoint or clean worktree; do not mix
  new slice work with the accepted Slice 24 diff.
- [x] Define the reviewer packet, event-manifest beats, and required
  before/action/after media before the next Tart run.
- [x] Add a machine-checkable no-context declaration to future artifact reviews
  or reviewer packets, while keeping retrospectives read-only unless the
  coordinator explicitly asks for repair.
- [x] Add verifier-required input-state evidence for mouse gesture proofs, such
  as raw right-button down/up rows or app-side `pressedMouseButtons` proof tied
  to `snap-drag-start`, `snap-first-affordance`, and `snap-release`.
- [x] Refactor the shared mouse-drag proof path toward a data-driven spec for
  activation input, expected negative result, expected positive result,
  captions, samples, verifier checks, and review-packet bullets.
  This cleanup does not fully replace the shared mouse proof code with a table,
  but it moves the next-slice artifact contract onto structured data:
  `script/e2e/specs/mouse-drag-events.tsv` remains the ordered event source,
  `logs/<recording>.contact-sheet-manifest.tsv` defines the summary media
  panels, `logs/<recording>.demo-cut.tsv` defines trimmed demo sidecars, and
  verifier diagnostics now use resolved slice/gesture fields instead of stale
  Slice 22 literals. Keep deeper review-packet prose extraction out of Slice 25
  unless the Slice 25 artifact review finds real drift.
- [x] Replace more long exact verifier prose matches with structured
  config/proof/event manifest assertions, and clean up stale Slice 22 wording in
  shared diagnostics.
  The shared Slice 22/23/24 verifier now reports failures through the resolved
  slice label and gesture description instead of stale Slice 22/no-Alt wording;
  current mouse-drag ordering remains asserted through the data-driven event
  spec and proof manifests.
- [x] Make product-label overlay sentinel generation fail closed for slices
  that require a product overlay label.
- [x] For future drag/product-demo slices, make the summary contact sheet show
  the first visible product affordance, release, and final placement.
  Implemented with `logs/<recording>.contact-sheet-manifest.tsv`: when
  drag/snap semantic sample labels exist, the primary contact sheet is a
  labeled semantic summary rather than a percentage-only timeline.
- [x] Add a viewer-visible mouse/input-state cue and, where needed, zoomed
  proof crops or insets so a new viewer can follow the gesture without reading
  logs.
  Future mouse annotations can render result-line cues such as
  `Input: Alt held` or `Input: secondary button held`, and semantic summary
  contact sheets now include the existing labeled whole-zone target crop when
  overlay-sentinel output is available.
- [x] Add compact command-result chips for `Run:` captions when command output
  is not visible in the recording.
  `script/e2e/annotate-recording` now accepts an optional sixth annotation TSV
  field and renders it as a compact `Result:` line in the caption card.
- [x] Keep the full acceptance recording, but produce a trimmed annotated demo
  cut when the verification tail is long.
  Future long-tail annotated runs write `recordings/<recording>.demo.mov` plus
  `logs/<recording>.demo-cut.tsv`; the verifier validates the sidecar when it
  exists, while the full recording remains the acceptance artifact.
- [x] Add a reviewer-prompt check for whether the annotated video is
  understandable without logs.

## Slice 25: Mouse Demo Artifact Contract

Goal: validate the hardened demo artifact contract on the one-handed mouse snap
workflow before adding another product behavior. Slice 25 should re-prove the
secondary-button whole-zone snap path with a fresh Tart recording that is easier
to follow as product media. It does not add new WinMux runtime behavior beyond
Slice 24.

Required user-visible story:

- Start from `[mouse.zone-snap] policy = 'float-unless-snap'`,
  `gesture = 'secondary-button-drag'`, and `target = 'zone'`.
- Show an ordinary drag of `snap-demo.rtf` into the Comms area with no snap
  overlay and a floating/freeform result.
- Reset the same source window to Work/main tiling.
- Show a secondary-button drag of the same source window with a visible input
  cue, pointer/path movement, the product `Whole zone: Comms` overlay, release,
  and final Comms/right placement.
- State in the review whether the positive branch targets a whole zone or a
  window/slot inside a zone. Expected answer: whole Comms zone.

Required artifact contract before no-context review:

- Full acceptance recording:
  `recordings/slice-25-mouse-demo-contract.mov`.
- Raw guest recording preserved under `recordings/raw/`.
- Trimmed sidecar demo:
  `recordings/slice-25-mouse-demo-contract.demo.mov`, with
  `logs/slice-25-mouse-demo-contract.demo-cut.tsv`.
- Primary contact sheet:
  `screenshots/slice-25-mouse-demo-contract.contact-sheet.jpg`, backed by
  `logs/slice-25-mouse-demo-contract.contact-sheet-manifest.tsv`.
  The manifest must include `snap-hover-comms`, `snap-release`,
  `snap-final-placement`, and a `target-zone-crop` proof-crop row when the
  overlay sentinel writes the labeled crop.
- Annotation TSV must include the visible input cue
  `Input: secondary button held` on the secondary-button drag caption.
- Event manifest must keep the Slice 24 mouse-drag beats split: config, ordinary
  drag start/hover/release/post-state, reset, snap pickup/path/first affordance,
  snap hover, release, and post-state.
- Mouse event timing must include `snap-secondary-button-down`,
  `snap-secondary-button-held`, and `snap-secondary-button-up` in order around
  snap pickup, first affordance, and release.
- Reviewer packet must list the full recording, raw recording, demo cut,
  contact-sheet manifest, event contact sheet, event manifest, mouse timing
  table, proof manifest, overlay sentinel, sample manifest, caption tail, demo
  cut manifest, and baseline media.

Validation gate:

- Run focused shell checks and `./script/e2e/verify-artifact --self-test`.
- Run the full pre-Tart gate with external-SSD Tart configuration.
- Produce the Slice 25 Tart artifact with `TART_HOME=/Volumes/RiftTartVMs/tart`.
- Run `make e2e-verify-slice-check RUN_DIR=<slice-25-dir> ARGS=--require-review`
  only after the no-context artifact review exists.
- Run `make e2e-slice-closeout-check RUN_DIR=<slice-25-dir>`.
- Run three no-context retrospectives and fold accepted findings into the next
  pre-slice cleanup before any Slice 26 work starts.

Accepted result:

- Artifact: `artifacts/e2e/slice-25-20260628T070737Z`.
- Full acceptance recording:
  `recordings/slice-25-mouse-demo-contract.mov`.
- Raw guest recording:
  `recordings/raw/slice-25-mouse-demo-contract.raw.mov`.
- Trimmed demo sidecar:
  `recordings/slice-25-mouse-demo-contract.demo.mov`, backed by
  `logs/slice-25-mouse-demo-contract.demo-cut.tsv`.
- Contact sheets:
  `screenshots/slice-25-mouse-demo-contract.contact-sheet.jpg` and
  `screenshots/slice-25-mouse-demo-contract.event-contact-sheet.jpg`.
- Whole-zone proof crop:
  `screenshots/slice-25-mouse-demo-contract.overlay-sentinel/snap-target-zone-labeled.png`,
  labeled `WHOLE ZONE TARGET: COMMS`.
- Mechanical verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-25-20260628T070737Z ARGS=--require-review`
  passed.
- Closeout gate:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-25-20260628T070737Z`
  passed with all three retrospectives present and sibling artifact hygiene
  clean.
- No-context artifact review:
  `reviews/no-ctx-artifact-review.md` verdict `PASS_WITH_NOTES`, final gate
  line `next slice allowed: yes`.
- Review note accepted for cleanup: the visible media and mouse timing prove
  secondary-button activation, but the copied config and legacy proof surface
  still mention `modifier = 'alt'`. This is treated as a compatibility config
  field, not the positive user activation.
- Retrospectives:
  `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.
- Superseded failed attempt:
  `artifacts/e2e/slice-25-20260628T070500Z` is marked superseded by the
  accepted artifact. It failed before product recording because the first Slice
  25 harness revision called the missing `quote_for_remote` helper.
- Accepted claims:
  ordinary drag under `float-unless-snap` plus `secondary-button-drag` remains
  freeform/floating with no snap overlay; the reset returns the same window to
  Work/main; the secondary-button-held drag targets the whole Comms zone,
  releases into Comms/right, and preserves the same window id.
- Non-claims:
  Slice 25 does not add new runtime behavior beyond Slice 24, does not prove
  snap-to-window or snap-to-slot, and does not introduce a gesture editor.

Pre-Slice-26 cleanup from Slice 25 retrospectives:

- [x] Run all three Slice 25 no-context retrospectives and read the reports.
- [x] Close Slice 25 in this plan with artifact paths, media, review verdict,
  verifier evidence, closeout evidence, retrospectives, accepted claims,
  non-claims, and the failed-attempt note.
- [x] Mark `artifacts/e2e/slice-25-20260628T070500Z` as superseded and write a
  canonical `logs/run-abort-status.txt`.
- [x] Add future abort-status coverage: `run_recorded_scenario` now writes
  `logs/run-abort-status.txt` on nonzero exit before VM cleanup, and
  `abort-status-self-test` is wired into `make e2e-pre-tart-checks`.
- [x] Resolve the secondary-button/Alt proof wording for future artifacts:
  secondary-button proof manifests now emit
  `drag-policy	configured-modifier	alt` and
  `drag-policy	activation-input	secondary-button` instead of presenting Alt
  as the positive activation input.
- [x] Update verifier coverage for the secondary-button proof contract. The
  self-test now rejects bad `activation-input` values, accepts existing legacy
  Slice 24/25 artifacts, and keeps mouse-event ordering checks for
  secondary-button down/held/up.
- [x] Harden the no-context artifact review and retrospection prompts so
  reviewers treat `configured-modifier = alt` as compatibility context for
  secondary-button proofs and recognize the current review verdict contract:
  first-line `PASS:` / `PASS_WITH_NOTES:` plus final
  `next slice allowed: yes`.
- [x] Rerun `bash -n`, `shellcheck`, `./script/e2e/verify-artifact --self-test`,
  `abort-status-self-test`, annotation preflight, Slice 25
  `--require-review`, Slice 24 backward verifier, and the Slice 25 closeout
  gate after the cleanup changes.
- Deferred: collapse the Slice 24/25 mouse-snap guest-wrapper duplication into
  a parameterized helper before the next mouse-drag product proof. This is not
  blocking for Slice 26 unless Slice 26 is another mouse-drag proof.

## Slice 26: Draggable Zone Dividers

Goal: make runtime zone sizing direct-manipulation. A user should be able to
grab the visible boundary between two enabled column zones, drag it horizontally,
and release to update runtime width overrides for the active layout on that
physical monitor.

Pre-Slice-26 cleanup from the three no-context preflight retrospectives:

- [x] Run three fresh no-context retrospection agents for process/plan,
  code/harness, and artifact/product before starting Slice 26 implementation.
  Reports:
  `artifacts/e2e/slice-26-preflight-retrospectives/process-plan.md`,
  `artifacts/e2e/slice-26-preflight-retrospectives/code-harness.md`, and
  `artifacts/e2e/slice-26-preflight-retrospectives/artifact-product.md`.
- [x] Pin the accepted runtime-width baseline to
  `artifacts/e2e/slice-11a-20260626T102409Z`. The older
  `slice-11a-20260626T100241Z` directory is historical only because it lacks an
  accepted no-context artifact review.
- [x] Define divider width semantics before implementation: dragging a divider
  changes only the two adjacent enabled zones that share that boundary; all
  non-adjacent enabled zones keep their effective width unless normalization is
  required by the existing model.
- [x] Reuse the existing runtime width model:
  `ZoneRuntimeOverlay.widthOverridesByLayoutIdentity`, physical-monitor
  identity scope, active-layout identity scope, `list-zones` runtime override
  fields, `refreshZoneTopologySnapshot()`, and
  `Workspace.reconcileWorkspaceState()`.
- [x] Keep the existing 5% minimum zone share for both adjacent zones. A drag
  that would cross the minimum clamps or rejects deterministically; it must not
  leave a hidden gap, overlap, or negative-width zone.
- [x] Define input architecture before implementation: use a dedicated
  zone-divider drag state/session. Do not piggyback on window AX resize,
  `currentlyManipulatedWithMouseWindowId`, desktop window snap, sidebar drag, or
  tab-strip drag.
- [x] Add fast behavior tests for adjacent-only divider math, min-share
  handling, disabled-zone behavior, active-layout/physical-monitor scoping, and
  workspace/window preservation.
- [x] Add Slice 26 e2e harness, guest script, config fixture, annotation plan,
  verifier branch, reviewer-packet branch, and no-context reviewer prompt checks
  before recording Tart media.

User-visible story:

- Start with three visible live windows in Reference/left, Work/main, and
  Comms/right, plus a readable state board generated from `list-zones`.
- Show a visible divider affordance between adjacent enabled zones. The first
  proof uses the Work/Comms divider.
- Hover or pick up the divider so the active handle is visually distinct from
  window resize handles and whole-zone snap overlays.
- Drag the divider horizontally, showing a live preview of the boundary and
  adjacent width labels.
- Release the divider. Work/main and Comms/right change width; Reference/left
  keeps its width. The same windows and workspaces remain attached to the same
  zone ids.
- Inspect `list-zones` after release. The changed zones report
  `monitor-zone-runtime-width-override-state = runtime`; copied config remains
  unchanged.

Product semantics:

- Divider handles exist only between adjacent enabled column zones on the same
  physical monitor and active layout.
- A disabled zone has no active divider handle.
- Divider drag is a runtime width-control input surface, not a new layout kind,
  TOML editor, sidebar drag, window movement, window resize, or zone-snap
  gesture.
- The direct-manipulation rule is adjacent-pair-only. For example, dragging the
  Work/Comms divider left grows Comms and shrinks Work while Reference stays the
  same.
- Width state remains runtime-only for this slice. Persistence across relaunch
  and writing updated zone widths back into TOML are not claimed.

Implementation scope:

- Extract a model-level divider operation before UI wiring. The operation should
  accept an adjacent left/right zone pair plus a delta or target x-position,
  apply the existing min-share and runtime-overlay invariants, refresh topology,
  and reconcile workspace state.
- Add a `ZoneDividerDragSession` or equivalent dedicated session that owns the
  physical monitor, active layout id, left/right zone ids, initial boundary x,
  initial adjacent widths, active pointer x, and final result.
- Render a restrained product affordance using the existing overlay/panel visual
  language. The active state must include readable labels such as
  `Work 55% | Comms 20%` without obscuring the managed windows.
- Suppress normal mouse-up focus side effects while a divider drag is finishing.
- Keep other mouse systems out of scope: window drop overlays, whole-zone snap
  overlays, sidebar row drag, and tab-strip reorder must not activate during a
  divider drag.

Fast validation:

- Add a focused pure/helper test showing `main|right` divider movement changes
  only Work/main and Comms/right.
- Cover min-share clamping or rejection for both sides.
- Cover disabled-zone boundaries: no divider operation should target a hidden
  zone.
- Cover duplicate physical monitors and active-layout scoping: a drag on monitor
  2 must not change monitor 1, and an override for layout `focus` must not
  change layout `balanced`.
- Cover workspace/window preservation after the divider update.

Tart video gate:

- Use `TART_HOME=/Volumes/RiftTartVMs/tart` and strict guest control with guest
  display capture.
- Scenario name:
  `slice-26-zone-divider-drag`.
- Config fixture:
  `script/e2e/configs/zone-divider-drag.toml`, derived from the Slice 11A width
  config.
- Guest script:
  `script/e2e/guest/slice-26-zone-divider-drag.sh`.
- The guest script must compute divider start/end coordinates from live
  `list-zones` geometry, not hardcoded ultrawide constants.
- Captions should expose the user action, for example
  `Action: drag zone divider Work | Comms`, and result chips from `list-zones`.
  Do not present the proof as `Run: winmux resize-zone ...`; CLI logs are
  supporting evidence, not the user action.

Required artifact contract before no-context review:

- Full acceptance recording:
  `recordings/slice-26-zone-divider-drag.mov`.
- Raw guest recording under `recordings/raw/`.
- Before/ready/after screenshots, including a clean before screenshot and
  after-state edge crops.
- In-action screenshots:
  `02-divider-hover-slice-26.png`, `03-divider-pickup-slice-26.png`,
  `04-divider-drag-path-slice-26.png`, `05-divider-preview-slice-26.png`, and
  `06-divider-release-slice-26.png`.
- Before/after logs:
  `slice-26-zones-before.log`, `slice-26-zones-after.log`,
  `slice-26-windows-before.log`, `slice-26-windows-after.log`, and a copied
  config checksum proving TOML was not edited by the scenario.
- Proof manifest:
  `logs/slice-26-zone-divider-drag.proof-manifest.tsv`, with divider pair,
  old boundary x, new boundary x, delta px, coordinate policy, affected zones,
  unchanged zones, min-share policy, before/after effective widths, before/after
  pixel widths, and workspace/window identity checks.
- Event manifest with divider-specific beats:
  `divider-hover`, `divider-pickup`, `divider-drag-path`,
  `divider-live-preview`, `divider-release`, and `after-divider-resize`.
- Semantic contact sheet backed by
  `logs/slice-26-zone-divider-drag.contact-sheet-manifest.tsv`, including
  divider pickup, in-drag preview, release, final geometry, and a boundary crop.
- Reviewer packet listing the accepted Slice 11A width baseline and the root
  product demos.

No-context artifact review requirements:

- The reviewer must inspect the full recording, semantic contact sheet,
  in-action screenshots, proof manifest, event manifest, before/after zone logs,
  and copied config checksum.
- The reviewer must answer which divider moved, which adjacent zones changed,
  which zone stayed unchanged, whether any window moved, and whether the change
  was runtime-only.
- Hard failures: command-only resize proof, final-width-only proof, invisible
  divider handle, stale/static measurement board, geometry numbers only in logs,
  copied config mutation, window movement presented as divider movement, whole
  zone snap overlay, or review that infers the drag without naming per-beat
  media files.

Validation gate:

- Run focused Swift tests for the divider width helper and interaction guard.
- Run `bash -n`, `shellcheck`, `./script/e2e/verify-artifact --self-test`, and
  `make e2e-pre-tart-checks`.
- Produce the strict Tart artifact.
- Run the no-context artifact review with `fork_context=false` using
  `script/e2e/prompts/no-context-artifact-review.md`.
- Run `make e2e-verify-slice-check RUN_DIR=<slice-26-dir> ARGS=--require-review`
  only after the no-context review exists.
- Run `make e2e-slice-closeout-check RUN_DIR=<slice-26-dir>`.
- Run the three post-slice no-context retrospectives and fold accepted findings
  into the next pre-slice cleanup before Slice 27.

Slice 26 accepted artifact:

- Accepted run:
  `artifacts/e2e/slice-26-20260628T191207Z`.
- Product recording:
  `recordings/slice-26-zone-divider-drag.mov` at 3440x1440, 79.98s, guest
  captured with annotated command/action chips.
- Mechanical proof:
  `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-26-20260628T191207Z`,
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-26-20260628T191207Z ARGS=--require-review`
  and
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-26-20260628T191207Z`
  pass after the final no-context review cited every semantic sample row
  required by `logs/slice-26-zone-divider-drag.sample-manifest.tsv`.
- No-context artifact review:
  `artifacts/e2e/slice-26-20260628T191207Z/reviews/no-ctx-artifact-review.md`
  returned `PASS` and `next slice allowed: yes`.
- Behavior proven:
  dragging the Work/main | Comms/right divider changed adjacent runtime widths
  only. Work grew from 1688px to 1941px, Comms shrank from 844px to 591px, and
  Reference stayed 844px. Window ids and workspace attachments stayed stable.
  The config checksum stayed unchanged.
- Dedicated divider proof:
  `logs/winmux-app.log` contains `zoneDivider.start` and `zoneDivider.commit`
  for the Work/Comms boundary, and the verifier rejects
  `resize.start ... kind=zoneDivider`.
- Superseded-run lessons:
  - `slice-26-20260628T184751Z` proved the width change but also let native
    window resize start, so it was rejected as contaminated.
  - `slice-26-20260628T185936Z` and `slice-26-20260628T190507Z` showed that an
    interactive near-transparent hit panel can blackhole Tart-posted mouse
    events; the accepted implementation uses pass-through divider visuals plus
    global/local event monitoring.
  - `slice-26-20260628T185640Z` and `slice-26-20260628T190851Z` failed before
    product recording because guest `screencapture` did not become ready.
    Rerunning with a larger capture-ready budget produced the accepted artifact.
  - The first successful review was human-acceptable but failed the machine gate
    because it did not cite the exact `config-ready` semantic sample. The
    reviewer prompt now requires every semantic sample row to be cited by label
    or exact path.
  - A follow-up review after packet regeneration found `.DS_Store` in the
    artifact root. `write-review-packet` now scrubs Finder sidecars before
    review handoff, and the verifier rejects them.
  - Another follow-up review found FinderInfo, last-used, quarantine, and other
    non-portable xattrs. The harness and packet writer now run `xattr -cr`
    during artifact cleanup, and the verifier rejects non-provenance xattrs.
    `com.apple.provenance` is tolerated because this macOS volume attaches it
    automatically and does not clear it with `xattr -c`.

Post-Slice-26 retrospectives:

- Process/plan:
  `artifacts/e2e/slice-26-20260628T191207Z/retrospectives/process-plan.md`.
- Code/harness:
  `artifacts/e2e/slice-26-20260628T191207Z/retrospectives/code-harness.md`.
- Artifact/product:
  `artifacts/e2e/slice-26-20260628T191207Z/retrospectives/artifact-product.md`.

Pre-Slice-27 cleanup from the three post-Slice-26 retrospectives:

- [x] Generate or copy a reviewer citation checklist into the Slice 27 reviewer
  packet from the slice artifact contract, including every semantic sample row,
  expected chip, required log, and negative assertion. Run a pre-review lint
  before the full `--require-review` verifier so citation misses are caught
  before a no-context review is accepted. `write-review-packet` now emits a
  semantic-sample citation checklist, and `make e2e-review-lint` checks review
  freshness, accepted verdict, baseline citations, and semantic citations before
  the full media verifier.
- [x] Keep one source of truth for the Slice 27 artifact contract. The plan,
  reviewer packet, verifier, expected chips, and prompt must agree before the
  first Tart recording; do not let the plan require a sidecar that the packet
  marks not applicable. The accepted Slice 27 packet, verifier, expected chips,
  prompt checks, and proof manifests all agree on `target = 'window'`,
  `window-slot`, `not-snap-target whole-zone`, and `Window slot: Right`.
- [x] Harden capture readiness before the next product run: run a pre-recording
  guest `screencapture` smoke with the final timeout/budget, and on repeated
  `could not create image from display` failures write
  `primary_log=logs/guest-capture-ready.log` plus display diagnostics into
  `run-abort-status.txt`. Capture-ready failure now writes the primary log,
  display diagnostics, WindowServer/Dock process state, and abort status.
- [x] Resolve the Slice 27 mouse-smoke requirement explicitly. No separate
  unrecorded guest smoke artifact was retained; the first strict recorded Tart
  attempts served as semantic smoke and exposed the `target = 'window'`
  float-unless-snap bug before the accepted run. Future mouse or
  direct-manipulation slices must either run an explicit pre-record smoke or
  record a plan waiver before recording.
- [x] Treat transparent or near-transparent interactive panels as e2e capture-risky
  until proven with Tart-posted `CGEvent` input. Prefer pass-through visuals
  plus global/local event monitors for proof artifacts.
- [x] Add focused verifier self-tests for the Slice 27 mouse path so the event
  manifest timing comes from mouse-event logs and missing app-log start/commit
  evidence is rejected. `./script/e2e/verify-artifact --self-test` now covers
  the window-slot proof contract, semantic citation lint, artifact hygiene, and
  the refreshed contact-sheet label path. Release-screenshot and spec
  `path-kind` checks are carried into Pre-Slice-28 cleanup.
- [x] Improve final-result visibility in Slice 27 demos. Use a `Result:` chip or
  compact result card, show actual `winmux list-zones` output or equivalent
  in-frame evidence, and include before/after values when geometry changes.
  `Result:` chips are now allowed by the annotation validator and required in
  reviewer guidance when they are part of a slice contract.
- [x] Keep the current `Config:`, `Action:`, and `Run:` chip structure, but clean
  semantic contact-sheet labels so tiles show one short beat name. Event
  contact sheet labels now avoid duplicated labels when the event id and sample
  label match.
- [x] Make fixtures more self-explanatory and product-aligned: larger semantic
  labels or width markers inside zones, caption placement that does not cover
  evidence-heavy regions, and product-native surfaces or visible WinMux sidebar
  context when the slice does not require plain fixture windows. Slice 27 uses
  full-resolution action screenshots, the product overlay label
  `Window slot: Right`, and a labeled window-slot crop; caption footprint and
  demo-cut defaults are carried into Pre-Slice-28 cleanup.

Non-claims:

- no TOML visual editor or persistence of divider changes across relaunch;
- no grid, freeform, or arbitrary rectangle layout editing;
- no per-zone sidebar panels;
- Slice 26 itself does not cover window-slot or snap-to-slot behavior;
- no change to existing `resize-zone`, `balance-zones`, sidebar drag, tab-strip
  drag, or desktop whole-zone snap semantics except preventing them from
  stealing active divider drags.

## Slice 27: Window Slot Snap Target

Goal: make the second snap target explicit and ergonomic. Whole-zone snap is
already implemented as `target = 'zone'`. Slice 27 adds
`target = 'window'`, where an active snap drag over a managed window previews a
slot inside that target window or tab group and releases through the existing
tab/split/swap intent logic.

Pre-slice cleanup:

- [x] Complete the final Slice 26 no-context review after artifact hygiene
  cleanup and rerun `make e2e-review-lint`,
  `make e2e-verify-slice-check ... ARGS=--require-review`, and
  `make e2e-slice-closeout-check`.
- [x] Keep the Slice 27 artifact contract in one source of truth before code:
  this section defines config, behavior, visible beats, expected logs, verifier
  checks, prompt checks, and non-claims.
- [x] Add fast parser/resolver/overlay tests before Tart. Focused
  `WindowZoneSnapPolicyTest`, config parser coverage, list-window geometry
  coverage, and the Slice 27 pre-Tart selected suite passed before the accepted
  artifact.
- [x] Add the Slice 27 e2e config, guest script, recording action, annotation
  plan, semantic sample manifest, verifier branch, review-packet branch, and
  no-context prompt checks before recording.
- [x] Resolve the short unrecorded guest interaction smoke requirement. No
  separate smoke artifact was kept; the strict Tart attempts and accepted proof
  cover app-log, overlay, release, and negative whole-zone assertions. Future
  mouse slices keep this as a required pre-record smoke or explicit waiver.

User-facing config:

```toml
[mouse.zone-snap]
policy = 'float-unless-snap'
gesture = 'secondary-button-drag'
target = 'window'
```

Product semantics:

- `target = 'zone'` keeps the existing whole-zone overlay and final
  `moveToZone` behavior.
- `target = 'window'` activates only when the configured policy/gesture is
  active and the pointer is over a target window inside a zone.
- The overlay must say it is a window/slot target, for example
  `Window slot: Right` and `Drop to split this window`. It must not use the
  whole-zone label.
- Release uses the existing window intent-zone behaviors: tab insert, split
  left/right/above/below, or swap/middle. This slice should not invent a second
  tiling engine.
- If the policy/gesture is inactive, ordinary `float-unless-snap` behavior
  remains freeform/floating and no window-slot overlay is shown.
- If the policy/gesture is active but no target window is under the pointer,
  no snap destination is offered; do not fall back to whole-zone snap.

Implementation scope:

- Add `window` to `ZoneSnapTarget` parsing and validation.
- Extend the zone-snap resolver with a "window destinations only" mode for
  active `target = 'window'` drags. This mode should allow the existing
  `currentWindowSurfaceDestination` and sticky target paths, then stop rather
  than falling through to workspace or whole-zone destinations.
- Add product overlay text for active window intent zones. The label should be
  specific enough for users and reviewers to distinguish `tab`, `left`,
  `right`, `top`, `bottom`, and `middle` targets.
- Keep existing same-workspace window intent gating unless the active snap
  policy intentionally opens it; do not regress tab-strip drag semantics.
- Add behavior tests for parser acceptance/rejection, inactive suppression,
  active window-only routing, no-window no-fallback behavior, whole-zone
  target preservation, and overlay label content.

Tart storyboard:

- Use an ultrawide zone config with Work/main containing two tiled windows and
  Comms/right visible.
- Start from `policy = 'float-unless-snap'`,
  `gesture = 'secondary-button-drag'`, and `target = 'window'`.
- Show an ordinary left drag of `snap-demo.rtf` over a Work/main target window:
  no window-slot overlay appears and the source stays freeform/floating.
- Reset the same source window to a tiled state.
- Show a secondary-button-held drag over the right slot of the target window:
  the product overlay must label `Window slot: Right`, show the active right
  slot inside the target window, and not show `Whole zone: ...`.
- Release and show the same source window inserted/split to the right of the
  target window in Work/main.
- Include a negative in-frame check or result chip that says
  `Result: target = window slot, not whole zone`.

Required artifact contract before review:

- Primary recording: `recordings/slice-27-window-slot-snap.mov`.
- Raw guest recording under `recordings/raw/`.
- Before/ready/after screenshots plus action screenshots for ordinary pickup,
  ordinary no-overlay hover, reset, secondary-button pickup, slot-hover,
  release, and final layout.
- Logs: before/after windows, before/after layout tree or list-windows output,
  mouse-event timings, event manifest, proof manifest, overlay sentinel, and
  app log.
- Proof manifest must name `drag-policy	target	window`, the exact active
  slot, the target window id/title, the source window id/title, and a negative
  `whole-zone-overlay-absent` assertion.
- Reviewer packet must list every semantic sample row, expected chip, and
  negative target-semantics assertion.

No-context review requirements:

- The reviewer must inspect the full video, event contact sheet, action
  screenshots, proof manifest, overlay sentinel, window/layout logs, and
  baseline product media.
- The reviewer must answer whether the drop target is a whole zone or a slot
  inside a window. Expected answer: a slot inside the Work/main target window.
- Hard failures: whole-zone overlay, final-layout-only proof, logs-only proof,
  missing secondary-button evidence, inactive branch showing a slot overlay,
  no active-slot label, no target window id/title proof, or fallback to
  whole-zone `moveToZone`.

Validation gate:

- Run focused Swift parser/resolver/overlay tests.
- Run `bash -n`, `shellcheck`, `./script/e2e/verify-artifact --self-test`, and
  `make e2e-pre-tart-checks`.
- Resolve the unrecorded guest interaction smoke requirement before acceptance:
  either run it or record the accepted waiver described in the pre-slice
  cleanup notes above.
- Produce the strict Tart artifact from the external SSD-backed Tart home.
- Run no-context artifact review with `fork_context=false`.
- Run `make e2e-review-lint`, `make e2e-verify-slice-check ... ARGS=--require-review`,
  and `make e2e-slice-closeout-check`.
- Run three post-slice no-context retrospectives and fold accepted findings
  into the next pre-slice cleanup.

Non-claims:

- no grid/freeform rectangle editor;
- no arbitrary snap-to-empty-position behavior;
- no persistence of window-slot snap choices;
- no new gesture editor UI;
- no change to whole-zone `target = 'zone'` semantics.

Accepted Slice 27 result:

- Accepted artifact:
  `artifacts/e2e/slice-27-20260630T043500Z`.
- Primary recording:
  `recordings/slice-27-window-slot-snap.mov`, H.264, 3440x1440,
  86.000000s, 4045 frames.
- Raw guest recording:
  `recordings/raw/slice-27-window-slot-snap.raw.mov`.
- Demo cut:
  `recordings/slice-27-window-slot-snap.demo.mov`, backed by
  `logs/slice-27-window-slot-snap.demo-cut.tsv`.
- Decisive product overlay frame:
  `screenshots/07-slot-hover-right-slice-27.png`, where the actual product
  overlay reads `Window slot: Right`.
- Labeled target crop:
  `screenshots/slice-27-window-slot-snap.overlay-sentinel/slot-target-window-labeled.png`.
- Refreshed contact-sheet manifest:
  `logs/slice-27-window-slot-snap.contact-sheet-manifest.tsv` now labels the
  proof crop as `zoomed labeled window-slot target crop`; the stale
  whole-zone wording was regenerated before the final review.
- No-context artifact review:
  `reviews/no-ctx-artifact-review.md` returned `PASS` with final gate line
  `next slice allowed: yes` after the artifact refresh. The pre-refresh review
  was archived as
  `reviews/no-ctx-artifact-review.stale-20260630T045255Z.md`.
- Mechanical proof:
  `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-27-20260630T043500Z`,
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-27-20260630T043500Z ARGS=--require-review`,
  and
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-27-20260630T043500Z`
  passed on the refreshed artifact.
- Focused source and harness checks:
  `bash -n script/e2e/tart-recording-harness script/e2e/verify-artifact script/e2e/write-review-packet script/e2e/guest/slice-12-mouse-zone-snap.sh script/e2e/guest/slice-26-zone-divider-drag.sh`,
  `./script/e2e/verify-artifact --self-test`, and
  `swift test --filter WindowZoneSnapPolicyTest` passed after the Slice 27
  artifact refresh.
- Behavior proven:
  ordinary no-secondary-button drag of `snap-demo.rtf` inside Work/main stays
  freeform/floating with no window-slot overlay; after reset, secondary-button
  drag targets `target-window.rtf`'s right slot, shows the product overlay
  `Window slot: Right`, releases through the existing window intent-zone split
  behavior, and keeps the source and target windows in Work/main. Comms/right
  remains a negative-control surface; the proof manifest records
  `drag-target snap-target window-slot` and
  `drag-target not-snap-target whole-zone`.
- Product fix discovered during Tart validation:
  `float-unless-snap` freeform conversion now applies when
  `mouse.zone-snap.target = 'window'` and the activation gesture is inactive.
  Before the fix, ordinary inactive drags could stay tiled because the float
  path was gated on `target = 'zone'`.
- Accepted non-claims:
  no arbitrary grid/rectangle editor, no empty-space snap target, no persisted
  window-slot snap choices, no new gesture editor UI, and no change to
  whole-zone `target = 'zone'` semantics.

Failed and superseded Slice 27 attempts:

- `artifacts/e2e/slice-27-20260630T041926Z`: preflight failure before product
  media. `logs/run-abort-status.txt` records `phase=preflight`,
  `final_result=failure`, and `recording_started=no`.
- `artifacts/e2e/slice-27-20260630T042242Z`: strict recorded Tart semantic
  failure. It exposed the product bug where inactive
  `float-unless-snap + target = 'window'` did not float the dragged window.
  `logs/run-abort-status.txt` records `phase=slice-27-run`,
  `final_result=semantic_failure`, and `recording_started=yes`.
- `artifacts/e2e/slice-27-20260630T042721Z`: media-producing run superseded
  after the guest proof-manifest caption chip disagreed with the annotation
  plan. It is formally marked with `reviews/superseded.md` and
  `logs/run-abort-status.txt`, superseded by
  `artifacts/e2e/slice-27-20260630T043500Z`.

Post-Slice-27 retrospectives:

- Process/plan:
  `artifacts/e2e/slice-27-20260630T043500Z/retrospectives/process-plan.md`.
- Code/harness:
  `artifacts/e2e/slice-27-20260630T043500Z/retrospectives/code-harness.md`.
- Artifact/product:
  `artifacts/e2e/slice-27-20260630T043500Z/retrospectives/artifact-product.md`.

Pre-Slice-28 cleanup from Slice 27 retrospectives:

- [x] Refresh derived Slice 27 media after the contact-sheet proof-crop wording
  fix, rerun the no-context artifact review with `fork_context=false`, and pass
  review lint, require-review verification, and closeout on the refreshed
  artifact.
- [x] Record the accepted Slice 27 artifact, failed-attempt ledger, verification
  commands, review verdict, accepted claims, non-claims, and retrospective paths
  in this plan.
- [x] Preserve the Slice 27 citation-checklist pattern for Slice 28: reviewer
  packets must list exact semantic sample rows, negative assertions, expected
  chips, and baseline/product-surface citations.
- [x] Add a pre-review consistency check for future mouse slices: generated
  proof-manifest caption chips, annotation TSV, expected chips, reviewer
  packet, and verifier-required chips must match before no-context review.
  `verify-artifact` now requires every expected-chip row to appear in both the
  annotation TSV and reviewer packet, and requires proof-manifest
  `caption/chip` rows to appear in both the annotation TSV and reviewer packet.
  Future slice-specific verifier-required chips must be listed in the
  expected-chips file when they are part of the user-facing review surface.
- [x] Decide before Slice 28 whether `Result:` lines are required user-facing
  evidence. Decision: `Result:` lines are required when command output or final
  state is central to viewer comprehension and is not otherwise visible in the
  desktop video; otherwise they are optional. When a slice uses `Result:` as
  proof evidence, include the exact line in expected chips so the annotation TSV
  and reviewer packet checks enforce it.
- [x] Extend `require_drag_proof_manifest` to validate optional release
  screenshots and cross-check the `snap-release` event path against the manifest
  release screenshot.
- [x] Add spec-driven `path-kind` validation to
  `require_mouse_drag_event_manifest`, with a self-test fixture that fails when
  `mouse-drag-events.tsv` and the emitted event manifest disagree.
- [x] Remove non-portable FinderInfo and last-used-date xattrs from the accepted
  Slice 23, Slice 24, and Slice 25 artifacts, verify representative PNG hashes
  stayed unchanged, and rerun their `--require-review` verifier checks so the
  shared mouse verifier has clean backward-compatibility evidence.
- [x] Split the shared mouse snap guest script into common helpers plus explicit
  whole-zone and window-slot profiles, starting with geometry derivation,
  screenshot naming, and proof-manifest fields. The shared guest script now
  routes through `SNAP_TARGET_PROFILE`, profile-owned screenshot naming,
  `derive_positive_drag_geometry`, and whole-zone/window-slot manifest profile
  helpers while keeping the existing harness entry point and slice env vars
  stable. Verified with `bash -n`, `shellcheck`,
  `./script/e2e/verify-artifact --self-test`,
  `./script/e2e/tart-recording-harness warmup-policy-self-test`, and
  representative Slice 25 whole-zone plus Slice 27 window-slot
  `--require-review` verifier checks.
- [x] Add retry-summary columns for per-attempt status and compact
  first/last-failure reason while keeping raw phase logs linked from the summary.
  New `guest-script-retry-summary.tsv` and `guest-transport-summary.tsv` rows
  include `attempt_statuses`, `first_failure_reason`, and
  `last_failure_reason`; the verifier reads the header so older accepted
  six-column summaries remain valid. Verified with `bash -n`, `shellcheck`,
  `./script/e2e/tart-recording-harness warmup-policy-self-test`,
  `./script/e2e/verify-artifact --self-test`, Slice 23-27
  `--require-review` verifier checks, and Slice 27 review lint.
- [x] Add an integrated unit test for the `.allowWindowDestinationsOnly` lookup
  branch proving same-workspace target-window destinations are allowed, slot
  labels are attached, and whole-zone/default destinations do not leak through.
  `WindowZoneSnapPolicyTest.testWindowTargetLookupAllowsSameWorkspaceWindowSlotWithoutWholeZoneLeak`
  drives `currentWindowDragIntentDestination` and passed in the focused test and
  full `WindowZoneSnapPolicyTest` run.
- [x] For long-tail recordings, make the product-facing demo cut the default
  review video or add a strict tail policy: trim the primary, add a final
  clean-state hold caption, or require an explicit accepted exception when
  `tail-seconds` exceeds `max-tail-seconds`.
  Decision: keep the full recording as the acceptance artifact and enforce the
  strict tail policy. `caption-tail.tsv` remains mandatory for annotated runs,
  long intentional tails require a reason, and `verify-artifact` now requires
  the `.demo.mov` sidecar plus `demo-cut.tsv` whenever the long tail is
  trim-worthy. Narrow historical exception: the accepted Slice 23 and Slice 24
  artifacts predate the demo-cut sidecar requirement and keep their existing
  accepted reviews instead of changing packets after the fact.
- [x] Generate a zoomed product-overlay crop or inset for the decisive hover
  beat in future slot/overlay demos, and require reviewers to inspect both the
  full-resolution frame and the contact sheet.
  The overlay-sentinel/contact-sheet path already emits labeled proof crops:
  the accepted Slice 27 manifest includes
  `proof-crop	target-zone-crop	...	slot-target-window-labeled.png`, and
  future reviewer packets list the overlay sentinel plus semantic contact sheet
  as required evidence.
- [x] Capture a release-boundary frame that still shows the active affordance,
  then keep post-drop placement as a separate final-state beat. When a snap
  release screenshot is configured, the guest JXA now captures it before mouse
  up, emits `snap-release` as release-boundary evidence, and keeps `99-after`
  as the separate post-drop placement proof. The Slice 27 event spec, sample
  manifest wording, reviewer packet, prompt, and verifier diagnostics now use
  that distinction. Verified with `bash -n`, `shellcheck`,
  `./script/e2e/verify-artifact --self-test`,
  `./script/e2e/tart-recording-harness warmup-policy-self-test`, and Slice 27
  `--require-review` verification.
- [x] Reduce caption footprint for dense desktop demos so captions expose the
  config/action without covering target windows, slot affordances, or measured
  geometry. `annotate-recording` now supports
  `WINMUX_E2E_CAPTION_FOOTPRINT=standard|compact` and
  `WINMUX_E2E_CAPTION_ANCHOR=bottom-left|bottom-right|top-left|top-right`.
  The harness defaults Slice 26 and Slice 27 to compact captions, and
  `annotation-preflight` renders with the same per-recording footprint so dense
  caption layout is tested before Tart. Verified with `bash -n`, `shellcheck`,
  `./script/e2e/verify-artifact --self-test`,
  `./script/e2e/tart-recording-harness annotation-preflight`, explicit
  `WINMUX_E2E_CAPTION_FOOTPRINT=compact WINMUX_E2E_CAPTION_ANCHOR=top-right`
  annotation preflight,
  `./script/e2e/tart-recording-harness warmup-policy-self-test`, Slice 26 and
  Slice 27 `--require-review` verifier checks, and `git diff --check`.
- [x] Harden no-context reviewer prompts with a concrete target-semantics
  question: "Could a reviewer understand target semantics from the video alone
  before reading logs?" Require exact media citations for the answer.
  The shared no-context prompt and reviewer packet now require that exact
  question for drag/divider/snap artifacts. Review lint now rejects accepted
  reviews that omit the declared `target-semantics` value or its exact media
  path when an overlay-sentinel manifest provides one.

## Slice 28: Export Runtime Zone Layout

Goal: give users a safe bridge from direct manipulation to durable config.
After resizing zones with `resize-zone`, `balance-zones`, or the Slice 26
divider drag, a user should be able to run one command and get a pasteable
`[[zone-layouts]]` TOML preset that reflects the current effective column
widths.

Pre-slice cleanup:

- [x] Complete all Pre-Slice-28 cleanup items from the Slice 27 retrospectives
  before writing implementation code.
- [x] Keep the Slice 28 scope narrower than automatic persistence: export a
  config snippet, do not rewrite the user's config file.

User-visible story:

- Start with the accepted three-zone ultrawide layout.
- Resize the Work/Comms boundary through the current runtime width model.
- Run `winmux export-zone-layout my-ultrawide --monitor 1`.
- Show the emitted TOML snippet with `[[zone-layouts]]`, `id`,
  `layout = 'columns'`, `default-zone`, and `columns` entries that preserve
  zone ids, display names, and current effective widths.
- Re-parse the emitted snippet with the copied base config or a small parser
  check so the artifact proves the output is usable config, not prose.

Product semantics:

- `export-zone-layout <layout-id>` reads the current effective layout for one
  physical monitor. Without `--monitor`, it uses the focused workspace's
  physical monitor, matching existing zone commands.
- The command is read-only. It writes TOML to stdout and never mutates
  `configUrl`, `config/winmux.toml`, runtime overlay state, workspace
  assignment, window layout, or active layout id.
- It exports the full current column layout only when all configured zones for
  that physical monitor are enabled. If a zone is hidden, the command fails with
  a concrete message instructing the user to enable zones first. Availability
  sets remain separate from layout presets.
- The exported width values are normalized for config readability and must sum
  to `1.0` within the existing parser tolerance.
- The command preserves zone ids, optional names, and default-zone. It does not
  export availability, style, workspace bindings, scenes, mouse snap policy, or
  runtime node bindings.

Implementation scope:

- Add `ExportZoneLayoutCmdArgs` with `--monitor <monitor-pattern>` and mandatory
  `<layout-id>`.
- Add `ExportZoneLayoutCommand` that resolves the target physical monitor,
  reads `getCurrentZoneTopologySnapshot().configuredZones`, groups rows by
  physical monitor, rejects missing or hidden zone data, and renders a TOML
  snippet.
- Add small TOML string/width formatting helpers close to the command, with
  tests covering quote escaping and width sums if the helpers are not trivial.
- Keep `list-zones` unchanged. It remains the inspection surface; the new
  command is the copy/paste config surface.

Fast validation:

- Parser test: `export-zone-layout saved --monitor 1`.
- Command test: after `resize-zone Work width +10%`, exporting `saved` emits a
  `[[zone-layouts]]` snippet where Work is wider, side zones are narrower, ids
  and names are preserved, and parsing the snippet as part of a config succeeds.
- Command test: duplicate physical monitors require `--monitor` or focused
  monitor resolution, and `--monitor 2` exports only monitor 2 widths.
- Command test: disabled zones make export fail without mutating state.
- Command test: inline zones without a named active layout still export as a
  named preset.

Tart video gate:

- Scenario name:
  `slice-28-export-zone-layout`.
- Config fixture should reuse the Slice 26/11A three-zone width setup unless a
  smaller fixture is enough.
- The recording must show a runtime width change before export, the exact
  `winmux export-zone-layout saved-ultrawide --monitor 1` command surface, the
  emitted TOML in-frame, and a parse/proof command that validates the snippet.
- Required logs: before/after `list-zones`, export stdout, parser check output,
  copied config checksum proving no config rewrite, annotation TSV, expected
  chips, event/sample manifest, reviewer packet, and no-context review.
- The semantic contact sheet must include before widths, changed widths, export
  output, parser success, and final unchanged desktop state.

No-context artifact review requirements:

- The reviewer must be able to tell from the video that runtime widths changed
  first and the export command emitted a config snippet after the change.
- The review must cite the exact media frame or semantic panel showing the TOML
  output, plus the log proving the emitted snippet parsed successfully.
- Hard failures: command mutates config, output is only logs and not visible,
  exported widths are stale configured widths instead of current effective
  widths, hidden-zone export silently emits a partial layout, or the artifact
  claims relaunch persistence.

Slice 28 non-claims:

- no automatic config write-back;
- no config editor UI;
- no persistence of runtime overlays across relaunch;
- no export of availability sets, scenes, styles, mouse policy, or node
  bindings;
- no new divider behavior beyond using the runtime widths Slice 26 already
  proved.

Accepted artifact:

- run directory: `artifacts/e2e/slice-28-20260630T060514Z`;
- recording:
  `artifacts/e2e/slice-28-20260630T060514Z/recordings/slice-28-export-zone-layout.mov`;
- proof:
  `artifacts/e2e/slice-28-20260630T060514Z/slice-28-export-zone-layout-proof.txt`;
- reviewer packet:
  `artifacts/e2e/slice-28-20260630T060514Z/reviews/reviewer-packet.md`;
- no-context review:
  `artifacts/e2e/slice-28-20260630T060514Z/reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS: Slice 28 demonstrates runtime read-only zone layout
  export after a visible runtime resize.`, `NO ACTIONABLE ISSUES`, final gate
  line `next slice allowed: yes`;
- retrospectives:
  `artifacts/e2e/slice-28-20260630T060514Z/retrospectives/process-plan.md`,
  `artifacts/e2e/slice-28-20260630T060514Z/retrospectives/code-harness.md`,
  and
  `artifacts/e2e/slice-28-20260630T060514Z/retrospectives/artifact-product.md`.

Accepted proof:

- The artifact shows a clean 3440x1440 Tart desktop, strict guest control,
  prepared privacy permissions, and clean before/after screenshots.
- The video shows the runtime sequence: start from 25/50/25 zones, run
  `winmux resize-zone Work width +10%`, show Work/main widened to `0.6`, run
  `winmux export-zone-layout saved-ultrawide --monitor 1`, show the emitted
  `[[zone-layouts]]` TOML in-frame, and run `winmux config --check` on the
  emitted file.
- `logs/slice-28-zones-before.log`,
  `logs/slice-28-zones-after-resize.log`, and
  `logs/slice-28-export-zone-layout.toml` prove the export used current runtime
  effective widths `0.2 / 0.6 / 0.2`, not stale configured widths.
- `logs/slice-28-config-before.sha256` and
  `logs/slice-28-config-after.sha256` match, proving the command did not mutate
  the copied config.

Accepted validation:

- `swift test --filter ZoneCommandTest/testExportZoneLayout`;
- `swift test --filter ZoneCommandTest`;
- `make e2e-pre-tart-checks`;
- `TART_HOME=/Volumes/RiftTartVMs/tart make e2e-slice-28`;
- `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-28-20260630T060514Z`;
- `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-28-20260630T060514Z`;
- `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-28-20260630T060514Z ARGS=--require-review`;
- `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-28-20260630T060514Z`.

Saved post-review gate logs:

- `artifacts/e2e/slice-28-20260630T060514Z/logs/review-lint.log`;
- `artifacts/e2e/slice-28-20260630T060514Z/logs/post-review-verify.log`;
- `artifacts/e2e/slice-28-20260630T060514Z/logs/closeout-check.log`;
- accepted dirty baseline:
  `artifacts/e2e/slice-28-20260630T060514Z/logs/accepted-dirty-baseline.status.txt`
  and
  `artifacts/e2e/slice-28-20260630T060514Z/logs/accepted-dirty-baseline.diffstat.txt`.

Pre-Slice-29 cleanup from blocking or low-risk retrospective findings:

- [x] Close Slice 28 in this plan with the accepted run, review, proof,
  verifier, retrospection, and dirty-baseline paths.
- [x] Replace stale artifact-review wording that said reviews must end with
  `PASS`, `PASS_WITH_NOTES`, or `FAIL`; durable docs now require first-line
  `PASS:` / `PASS_WITH_NOTES:` / `FAIL:` plus final line
  `next slice allowed: yes/no`.
- [x] Make no-context retrospection disk-only by default. Session history is
  now an explicit forensic mode, not part of the normal gate.
- [x] Persist post-review gate transcripts for Slice 28.
- [x] Record the accepted dirty baseline for Slice 26-28 because the worktree is
  intentionally not clean yet.
- [x] Add a `WINMUX_E2E_SLICE28_PHASE=self-test` guest-script self-test and
  wire it into `make e2e-pre-tart-checks` so Slice 28 shell helpers fail before
  Tart.
- [x] Add focused export tests for TOML escaping and width normalization edge
  cases.
- [x] Make the Slice 28 exported-TOML shell proof data-derived from
  `slice-28-zones-after-resize.log` rather than exact row greps.
- [x] Add the Slice 7 root-demo contact sheet and sample-frame directory to
  future baseline lists when comparing against `demo-columnar-zones.mp4`.

Deferred non-blocking follow-ups:

- Reduce future packet drift by centralizing each slice's artifact contract:
  expected chips, semantic sample labels, event ids, and named screenshot paths.
  Deferred because the Slice 28 packet/verifier is already passing and the
  refactor should happen when a new slice first adds or changes contract rows.
- For future text-first proof slices, generate close-up proof crops and cite
  those crops in reviewer packets beside the full-frame screenshot. This is
  conditional on the next slice depending on small TOML, shell output, or config
  text.
- For future packets, cite annotated caption samples when the overlay carries
  the proof. Do not cite a semantic screenshot unless the claimed text is
  actually visible in that screenshot. This is conditional on the proof living
  primarily in captions.
- Decide in the next slice storyboard whether its artifact is proof-only or a
  shareable demo. Product-facing slices should emit a compressed MP4 cut plus
  ffprobe metadata.

## Slice 29: Explicit Runtime Zone Layout Save

Goal: close the runtime-width loop without hiding writes from the user. After a
user changes zone sizes with `resize-zone`, `balance-zones`, or the Slice 26
divider drag, they should be able to save the effective column widths back to
their WinMux config deliberately, with a visible backup and a dry-run diff.

Primary product claim:

- `save-zone-layout [--monitor <monitor-pattern>] [--layout <layout-id>]`
  updates the configured column widths for the target physical monitor and
  layout to match the current effective runtime widths.

Pre-Slice-29 cleanup:

- [x] Commit the accepted Slice 26-28 dirty stack or write an explicit
  carry-forward inventory before any Slice 29 source changes. Do not mix the
  new save behavior into the accepted divider, slot-snap, and export diff.
  Accepted boundary commit: `ebbbb3ce`.
- [x] Keep `Sources/Common/gitHashGenerated.swift` out of the Slice 29 source
  diff unless the build system intentionally regenerated it for release. The
  generated hash churn was reset before `ebbbb3ce`.
- [x] Fold the Slice 28 retrospection follow-up about text-first proof crops
  into the Slice 29 packet, because this slice will likely prove config text,
  dry-run output, and file diffs on screen. Slice 29 now requires screenshots
  for dry-run output, save output, saved config text, and reload inspection;
  the verifier and reviewer packet inspect those files directly.
- [x] Decide whether the Slice 29 product artifact emits a trimmed demo sidecar
  in addition to the full acceptance recording. If it does, add the demo cut
  manifest to the verifier before recording. Decision: do not emit a sidecar
  before first acceptance; keep the proof in the full recording and add a demo
  cut only if artifact review finds the acceptance video unsuitable as product
  evidence.

Command surface:

```toml
[mode.zone.binding]
s = 'save-zone-layout --dry-run'
shift-s = 'save-zone-layout'
```

Commands:

- `export-zone-layout [--monitor <monitor-pattern>] [--layout <layout-id>]`
  remains the read-only escape hatch from Slice 28.
- `save-zone-layout [--monitor <monitor-pattern>] [--layout <layout-id>]`
  writes the current effective widths to the config file.
- `save-zone-layout --dry-run [--monitor <monitor-pattern>] [--layout <layout-id>]`
  prints the same planned edit and backup path but does not modify the file.

Safety and config semantics:

- The command must update only the targeted column widths. It must preserve
  unrelated config content, including comments when the existing TOML editing
  library can do so safely. If comments cannot be preserved by the selected
  writer, the slice must stop at dry-run plus export and keep write-back
  deferred.
- The write path must create a timestamped backup beside the config file before
  replacing it. The command output must print the backup path and the changed
  zone widths.
- `--dry-run` must not write the config file or create a backup.
- The command targets the focused physical monitor by default. `--monitor` uses
  the existing physical-monitor selector behavior. `--layout` defaults to the
  active layout id on that monitor.
- Inline `[[zones]]` columns and named `[[zone-layouts]]` are both in scope.
  The command must reject configs where the target monitor resolves through a
  layout kind it cannot edit safely.
- Runtime width overrides should remain in effect after save until the user
  changes layout state again. A follow-up relaunch or reload can verify that the
  saved widths become the configured baseline, but this slice should not add
  automatic persistence on every drag.

Fast validation:

- Add command parser and help metadata tests for `save-zone-layout`,
  `--dry-run`, `--monitor`, and `--layout`.
- Add config-edit tests using temporary files that prove:
  - dry-run leaves the file byte-identical and creates no backup;
  - save writes only the targeted inline layout widths;
  - save writes only the targeted named layout preset widths;
  - unrelated zone layouts, availability sets, styles, bindings, affinities,
    and mouse config survive unchanged;
  - invalid targets fail with clear errors and no partial write;
  - backup creation happens before replacement.
- Add command tests proving the saved widths are the current runtime effective
  widths after a resize or divider-width operation.

Implementation progress:

- `save-zone-layout` command, parser/help metadata, named-layout write-back,
  inline-zone write-back, dry-run, backup creation, edited-config parse
  validation, and shared export/save width formatting are implemented.
- Slice 29 e2e config, guest script, annotation plan, event manifest, artifact
  verifier, reviewer packet requirements, README note, and Make target are
  wired.
- `make e2e-pre-tart-checks` passed after the Slice 29 harness was added. The
  gate covered shell syntax, `shellcheck`, command metadata, verifier
  self-test, Slice 12/26/28/29 guest helper self-tests, annotation preflight,
  warm-up policy self-test, `ConfigTest.testParseZoneSaveLayoutE2EConfig`, and
  `ZoneCommandTest` including the new save-layout cases.

Tart video gate:

- Use the accepted three-zone ultrawide setup from Slice 26 and Slice 28.
- Start from a clean desktop with Reference, Work, and Comms visible.
- Change runtime widths in the recording with either a divider drag or a concise
  command-backed setup step. If the runtime width change is setup-only, the
  video must say that the save command is the slice's product claim and cite
  Slice 26 as the accepted divider proof.
- Show `winmux save-zone-layout --dry-run` before the write. The video must
  make it readable that the config file did not change.
- Show `winmux save-zone-layout`, the backup path, and the changed widths.
- Show the config file or a readable config excerpt after save, with the saved
  widths matching `list-zones` effective widths.
- Reload WinMux or run an equivalent config parse/inspect command proving the
  saved widths are now the configured baseline. If a full app reload makes the
  recording too noisy, the proof may use a focused command-level reload with
  before/after logs and a visible state board.

Required artifact contract:

- Full recording:
  `recordings/slice-29-save-zone-layout.mov`.
- Raw guest recording under `recordings/raw/`.
- Optional demo sidecar:
  `recordings/slice-29-save-zone-layout.demo.mov`, if the storyboard chooses a
  shareable demo cut.
- Screenshots for ready state, dry-run output, save output, config before,
  config after, and post-reload configured/effective widths.
- Text proof crops for the dry-run output, backup path, and saved TOML width
  lines.
- Logs for `list-zones` before save, after runtime resize, after dry-run, after
  save, copied config hash before/after, backup file hash, and reload/inspect
  output.
- Proof manifest with target monitor, target layout id, old configured widths,
  runtime effective widths, saved configured widths, backup path, dry-run
  mutation status, and unchanged unrelated config sections.

No-context artifact review requirements:

- The reviewer must inspect the full recording, text proof crops, proof
  manifest, before/after config hashes, backup file, post-save config excerpt,
  and baseline product videos.
- The reviewer must answer whether the slice proves dry-run safety, explicit
  write-back, backup creation, and saved widths matching runtime widths.
- Hard failures: automatic background persistence presented as an explicit save,
  config text too small to read, no backup evidence, dry-run mutating files,
  width values only present in logs, unrelated TOML sections rewritten without
  explanation, or a review that does not compare against the baseline product
  style and root demo artifacts.

Validation gate:

- Run focused Swift tests for the save command and config edit path.
- Run `bash -n`, `shellcheck`, `./script/e2e/verify-artifact --self-test`, and
  `make e2e-pre-tart-checks`.
- Produce the strict Tart artifact with
  `TART_HOME=/Volumes/RiftTartVMs/tart`.
- Run a fresh no-context artifact review with `fork_context=false`.
- Run
  `make e2e-verify-slice-check RUN_DIR=<slice-29-dir> ARGS=--require-review`.
- Run `make e2e-slice-closeout-check RUN_DIR=<slice-29-dir>`.
- Run the three post-slice no-context retrospectives and fold accepted findings
  into the next pre-slice cleanup before Slice 30.

Slice 29 accepted result:

- accepted artifact: `artifacts/e2e/slice-29-20260630T070758Z`;
- recording:
  `artifacts/e2e/slice-29-20260630T070758Z/recordings/slice-29-save-zone-layout.mov`;
- raw recording:
  `artifacts/e2e/slice-29-20260630T070758Z/recordings/raw/slice-29-save-zone-layout.raw.mov`;
- screenshots: `01-ready-slice-29.png`,
  `02-before-save-resize-slice-29.png`,
  `03-after-runtime-resize-slice-29.png`,
  `04-dry-run-output-slice-29.png`,
  `05-save-output-slice-29.png`,
  `06-config-after-save-slice-29.png`,
  `07-after-reload-inspect-slice-29.png`, `99-after-slice-29.png`, contact
  sheet, event contact sheet, samples, and edge crops under the artifact
  `screenshots/` directory;
- proof: `slice-29-save-zone-layout-proof.txt`;
- review: `reviews/no-ctx-artifact-review.md`;
- review verdict: `PASS`, `Next slice allowed: yes`;
- mechanical verifier:
  `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z`
  passed;
- post-review verifier:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z ARGS=--require-review`
  passed;
- review lint:
  `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z`
  passed;
- closeout check:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z`
  passed;
- retrospectives:
  `artifacts/e2e/slice-29-20260630T070758Z/retrospectives/process-plan.md`,
  `code-harness.md`, and `artifact-product.md`.

What the accepted artifact proves:

- `winmux resize-zone Work width +10%` changes the runtime effective widths
  from `0.25 / 0.5 / 0.25` to `0.2 / 0.6 / 0.2`;
- `winmux save-zone-layout --dry-run` prints the planned width changes and
  leaves the active config hash unchanged;
- `winmux save-zone-layout` writes the current runtime effective widths into
  the active named `balanced` layout only after the explicit command;
- the save output shows a backup path, and the backup hash matches the original
  config hash;
- the saved config keeps the unrelated `focus` layout, availability sets,
  zone bindings, affinities, mouse config, mode bindings, and column comment;
- `reload-config` plus `config --check` and `list-zones` show the saved widths
  as configured baseline values.

Slice 29 accepted notes:

- The accepted artifact has readable full-resolution proof screenshots for
  dry-run output, save output, saved config text, and reload inspection, rather
  than separate named text-proof crops. Future text-first slices must either
  produce named close-up crops plus a manifest/verifier checks, or avoid
  promising proof crops in the contract.
- After acceptance, the harness was hardened so Slice 29 declares
  `active_config_hash_policy=mutates`, the verifier reads that metadata instead
  of matching the slice name, and the guest script emits the mutation marker
  before `save-zone-layout` so post-save failures do not retry against an
  already-mutated config. The accepted artifact's `preflight.log` was updated
  with the same metadata row and reverified.
- A CRLF named-layout write-back bug was fixed after the retrospective and
  covered by `ZoneCommandTest.testSaveZoneLayoutWritesCRLFNamedLayoutAndBackup`.

Slice 29 non-claims:

- no automatic persistence on every divider drag or resize command;
- no settings UI or visual config editor;
- no relaunch-persistence proof beyond focused `reload-config` and
  `config --check` inspection;
- no write-back for styles, availability, scenes, affinities, or unrelated
  layout kinds.

Pre-Slice-30 cleanup from Slice 29 retrospectives:

- [x] Close accepted slices in the plan before new feature implementation starts:
  record artifact path, review verdict, verifier commands, closeout command,
  retrospection paths, claims, non-claims, and dirty-baseline files.
- [x] Decide whether the next product-bearing slice emits both a full proof
  recording and a shorter `*-product-demo` cut. If yes, add the demo-cut
  manifest/verifier before recording. Decision: Slice 30 is harness-only; the
  next product-bearing visual slice must storyboard the existing
  `recordings/<name>.demo.mov` sidecar up front when the full acceptance video
  has setup/proof tail that would weaken a product demo. The existing
  demo-cut manifest/verifier remains the accepted sidecar format.
- [x] Add named close-up crop support for text-first proof artifacts, or make
  future contracts explicitly require readable full-frame screenshots instead
  of "text proof crops." Decision: until named crop support is implemented, a
  slice may not promise text-proof crops unless its verifier names those crop
  files. Text-first slices must otherwise require readable full-frame
  screenshots.
- [x] Make review lint enforce the baseline list from the reviewer packet for
  columnar-zone artifacts, including `demo-columnar-zones.mp4` and Slice 7
  root-demo samples. Slice 30 adds a future-artifact `review_baseline_policy`
  preflight flag and verifier self-tests for full packet baseline citation.
- [x] Add a post-recording retry policy to reviewer packets: if
  `guest-script-retry-summary.tsv` has `before_recording=no` and failures, the
  reviewer must name the retry and decide whether it occurred before the first
  product action. High-risk proof slices should re-record after post-recording
  transport failure. Slice 30 adds a future-artifact `review_retry_policy`
  preflight flag, packet wording, prompt wording, and verifier self-tests.
- [x] Add a closeout or pre-Tart guard that fails if
  `Sources/Common/gitHashGenerated.swift` or
  `Sources/Common/versionGenerated.swift` is dirty after validation. Slice 30
  wires `script/e2e/check-generated-version-clean` into pre-Tart and closeout.
- [x] Replace setup movement helpers that emit benign `move-node-to-zone`
  warnings with an `ensure_window_in_zone` style helper that inspects state
  first and logs intentional setup no-ops cleanly. Resolved in Pre-Slice-31
  cleanup with `script/e2e/guest/zone-window-helpers.sh`.
- [ ] Consider moving repeated shell TOML/zone-width parsing into a shared e2e
  helper or a structured proof manifest that the verifier can consume.
- [ ] For the next visual layout demo, make the width/layout change more
  obvious with measurement chips or a lightweight overlay, use a more
  product-shaped fixture, and avoid accumulating proof windows in the
  product-facing view.

## Slice 30: Artifact Review Gate Hardening

Goal: make the reviewer/verifier contract catch the classes of misses that
caused earlier slice rework before any new feature slice starts.

Primary product claim:

- No new user-facing WinMux behavior. This slice hardens the e2e harness,
  no-context reviewer packet, review prompt, and closeout checks for future
  product-bearing slices.

Implementation scope:

- Add preflight metadata for future artifacts:
  `review_baseline_policy=full-packet` and
  `review_retry_policy=post-recording-analysis`.
- Make reviewer packets list `logs/guest-script-retry-summary.tsv` and require
  post-recording retry rows to be discussed explicitly.
- Make the no-context artifact-review prompt require reviewers to inspect
  `guest-script-retry-summary.tsv`, name any `before_recording=no` failures,
  and cite Slice 7 root-demo baselines when the packet lists them.
- Make `verify-artifact --review-lint` and `--require-review` enforce full
  local baseline citations for future artifacts that opt into the full-packet
  policy.
- Make `verify-artifact --review-lint` and `--require-review` enforce
  post-recording retry citations for future artifacts that opt into the retry
  policy.
- Add a generated-version-file guard and run it in both `make
  e2e-pre-tart-checks` and `make e2e-slice-closeout-check`.
- Add verifier self-tests for the new baseline and retry-review checks.

Fast validation:

- `bash -n script/e2e/check-generated-version-clean script/e2e/verify-artifact script/e2e/write-review-packet script/e2e/tart-recording-harness`
- `shellcheck script/e2e/check-generated-version-clean script/e2e/verify-artifact script/e2e/write-review-packet script/e2e/tart-recording-harness`
- `./script/e2e/check-generated-version-clean`
- `./script/e2e/verify-artifact --self-test`
- `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z`
- `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z ARGS=--require-review`
- `make e2e-pre-tart-checks`

Tart artifact decision:

- Slice 30 is harness/review-contract-only, so it does not need a fresh Tart
  product video. The next product-bearing slice still must produce a strict
  Tart video and pass the no-context artifact review before work proceeds.

Post-slice gate:

- Run three no-context retrospection agents over the Slice 30 diff before
  committing, because this slice hardens the review gate itself.
- First retrospection round found four blocker classes and they were fixed
  before the slice could close:
  - generated-version guard had to run again after `swift test`, not only
    before the long validation tail;
  - baseline lint had to enforce Slice 7 root-demo media, resource
    screenshots, and product-surface URLs from the reviewer packet;
  - retry lint had to require a decision about whether a post-recording retry
    happened before the first visible product action;
  - explicit preflight policies had to apply directly, not only inside the
    slice-name `requires_current_artifact_contract` heuristic.
- Run a second no-context retrospection pass after those fixes and do not move
  to the next feature slice until it is clean or all new findings are fixed.
- The second retrospection round found additional verifier/harness blockers and
  they were fixed before the slice could close:
  - the new helper file had to be included in the tracked diff, not left
    untracked;
  - post-recording retry lint had to require both a phase-tied first visible
    product-action decision and mutation/re-record/non-stateful evidence;
  - no-context reviews had to declare `fork_context=false` or equivalent no
    chat-history posture;
  - retry summaries had to be parsed by header and reject failed post-recording
    rows that omit attempt statuses;
  - packet-listed local baseline paths had to exist on disk before their
    citations could satisfy review lint;
  - recorded Tart scenarios had to run the generated-version guard immediately
    after host build and before VM startup, not only in pre-Tart/closeout.
- Run a third no-context retrospection pass after those fixes and do not move
  to the next feature slice until it is clean or all new findings are fixed.
- The third retrospection round found additional verifier edge cases and they
  were fixed before the slice could close:
  - demo sidecar artifacts must be all-or-nothing: orphan
    `recordings/<name>.demo.mov` or orphan
    `logs/<name>.demo-cut.tsv` now fail packet generation and verification;
  - retry mutation evidence must be positive evidence such as "did not mutate",
    "no proof-state change", "non-stateful", or "re-recorded after", not loose
    words like "proof state" or "re-record";
  - failed post-recording retry rows must have non-empty, non-`-`
    `attempt_statuses`;
  - retry summary phase lookup is header-based, not positional;
  - no-context declaration lint applies to future policy artifacts and remains
    compatible with historical accepted artifacts;
  - the missing-local-baseline self-test now uses a path that matches the
    enforced baseline selector.
- Run another no-context retrospection pass after these fixes and do not move
  to the next feature slice until it is clean or all new findings are fixed.
- Final no-context retrospection pass result: process/plan, code/harness, and
  artifact/product reviewers all returned `NO ACTIONABLE ISSUES`.

Slice 30 accepted result:

- no Tart artifact: harness/review-contract-only slice; no user-facing WinMux
  behavior or product video claim;
- focused validation:
  `bash -n script/e2e/check-generated-version-clean script/e2e/verify-artifact script/e2e/write-review-packet script/e2e/tart-recording-harness`,
  `shellcheck script/e2e/check-generated-version-clean script/e2e/verify-artifact script/e2e/write-review-packet script/e2e/tart-recording-harness`,
  `./script/e2e/verify-artifact --self-test`,
  `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z`,
  and
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-29-20260630T070758Z ARGS=--require-review`
  passed;
- full validation:
  `make e2e-pre-tart-checks` passed after the final Slice 30 verifier and
  harness changes, including 173 selected Swift tests and the final
  generated-version-file guard;
- final no-context retrospection agents:
  process/plan, code/harness, and artifact/product all reported
  `NO ACTIONABLE ISSUES`.

Slice 30 accepted notes:

- Future harness-generated artifacts declare
  `review_baseline_policy=full-packet` and
  `review_retry_policy=post-recording-analysis` in `logs/preflight.log`.
- `verify-artifact --review-lint` and `--require-review` now enforce those
  explicit policy flags independently of slice-name heuristics.
- Full-packet baseline enforcement requires local baseline paths listed in the
  reviewer packet to exist and requires reviews to cite tracked/root demo
  baselines plus product-surface URLs.
- Post-recording retry lint parses retry summaries by header, rejects missing
  or `-` attempt statuses for failed post-recording rows, requires phase/log
  path/final result/attempt statuses, and requires phase-scoped first visible
  product-action and mutation/re-record/non-stateful analysis.
- No-context declaration lint applies to future policy artifacts while
  historical accepted artifacts remain re-verifiable.
- Demo-cut sidecars are now all-or-nothing: orphan `.demo.mov` or
  `.demo-cut.tsv` files fail packet generation and verification.
- Generated version/hash files are guarded in pre-Tart, after recorded-scenario
  host build and before VM startup, and during closeout.

Slice 30 non-claims:

- no new WinMux command, zone behavior, or user-facing interaction;
- no fresh Tart product video;
- no `ensure_window_in_zone` setup helper yet at Slice 30 closeout; the
  Pre-Slice-31 cleanup adds the guest helper before the next product slice;
- no new named close-up crop generator; text-first future slices must either
  produce verifier-backed named crops or require readable full-frame
  screenshots;
- no automatic product-demo sidecar for every future slice; future
  product-bearing slices must choose whether the existing demo-cut sidecar is
  required before recording.

Pre-Slice-31 cleanup:

- [x] Replace setup movement helpers that emit benign `move-node-to-zone`
  warnings with an `ensure_window_in_zone` style helper that inspects state
  first and logs intentional setup no-ops cleanly. Implemented in
  `script/e2e/guest/zone-window-helpers.sh`, self-tested directly in
  `make e2e-pre-tart-checks`, and adopted by the recent Slice 26/28/29 guest
  scripts so layout-demo setup no longer invokes `move-node-to-zone` for an
  already-correct window.
- [x] Run the required three no-context pre-slice retrospectives before starting
  Slice 31 implementation. Reports:
  `artifacts/e2e/slice-31-preflight-retrospectives/process-plan.md`,
  `code-harness.md`, and `artifact-product.md`.
- [x] Persist the missing Slice 29 post-review gate transcripts before relying on
  it as the latest baseline. Added
  `artifacts/e2e/slice-29-20260630T070758Z/logs/review-lint.log`,
  `post-review-verify.log`, and `slice-closeout.log`; all reruns passed.
- [x] For the next visual layout demo, make the width/layout change more
  obvious with measurement chips or a lightweight overlay, use a more
  product-shaped fixture, and avoid accumulating proof windows in the
  product-facing view. Slice 31 is a visual/product-bearing slice and requires
  before/resized/relaunched measurement chips, task-shaped zone documents, no
  proof-output windows in the product-facing final view, and a structured proof
  manifest for the logged width values.
- [x] Decide whether Slice 31 is a product-bearing visual feature slice. If yes,
  storyboard both the full acceptance recording and the optional
  `recordings/<name>.demo.mov` sidecar before Tart. Decision: Slice 31 is
  product-bearing visual and the demo sidecar is mandatory because the full proof
  includes save/relaunch verification.
- [x] If Slice 31 is text-first, either add named close-up crop support with
  verifier checks or explicitly require readable full-frame screenshots only.
  Decision: Slice 31 is not text-first; it must not promise text-proof crops.
  Any visible command/config text must be readable in full-frame screenshots and
  backed by structured logs.
- [x] Handle the repeated shell TOML/zone-width parsing cleanup for this slice.
  Decision: Slice 31 must not add another local TOML width parser. It emits
  `logs/slice-31-relaunch-saved-layout.proof-manifest.tsv` and
  `logs/slice-31-relaunch-saved-layout.measurements.tsv`; the verifier consumes
  those structured rows and cross-checks them against config hashes, backup
  output, and `list-zones` logs.

## Slice 31: Relaunch-Safe Saved Layout Showcase

Goal: make the explicit save loop feel durable in the product, not just
technically correct. A user should see that after resizing and saving a zone
layout, quitting and relaunching WinMux brings the same ultrawide column widths
back without another runtime resize command.

Primary product claim:

- `save-zone-layout` writes the current effective column widths to config, and a
  fresh WinMux launch reads those saved widths as the configured baseline for the
  active layout.

User-visible story:

- Start on a clean ultrawide desktop with three task-shaped documents:
  Research/Reference, Draft/Work, and Inbox/Comms.
- Show the starting measurement chip:
  `Reference 25% | Work 50% | Comms 25%`.
- Run the visible user command
  `winmux resize-zone Work width +10%`.
- Show the resized measurement chip:
  `Reference 20% | Work 60% | Comms 20%`.
- Run the visible user command `winmux save-zone-layout`.
- Quit WinMux and relaunch it from the same saved config. Do not use
  `reload-config` as the relaunch proof.
- Show the relaunched measurement chip:
  `Reference 20% | Work 60% | Comms 20%`, with the task documents still in the
  same zone ids/workspaces. Window ids may be logged as diagnostics, but the
  acceptance proof is title-based document continuity, zone identity, workspace
  continuity, and saved width restoration after a fresh WinMux launch.

Product/demo framing:

- Slice 31 is product-bearing visual, not text-first.
- The full acceptance recording is
  `recordings/slice-31-relaunch-saved-layout.mov`.
- The raw guest recording is preserved under `recordings/raw/`.
- A shorter product/demo sidecar is required:
  `recordings/slice-31-relaunch-saved-layout.demo.mov` with
  `logs/slice-31-relaunch-saved-layout.demo-cut.tsv`.
  Reviewer-packet generation must fail for Slice 31 if either sidecar file is
  missing, so a no-context reviewer cannot treat the demo as optional.
- Caption chips must expose the user-facing WinMux actions and relaunch cues:
  `Run: winmux resize-zone Work width +10%`,
  `Run: winmux save-zone-layout`, `Action: quit WinMux`,
  `Result: WinMux sidebar absent`, `Action: relaunch WinMux`,
  `Result: WinMux sidebar restored`, and `Run: winmux list-zones`.
- The annotator and verifier must render and validate every chip column from
  the annotation TSV, not only columns 5 and 6. Stale expected chips, overlong
  chips, placeholder chips, and unrendered column 7+ chips are hard failures.
- Result chips must expose the measurement changes:
  `Result: Reference 25% | Work 50% | Comms 25%`,
  `Result: Work 50% -> 60%`,
  `Result: Reference 20% | Work 60% | Comms 20%`, and
  `Result: relaunch kept Reference 20% | Work 60% | Comms 20%`.
- The product-facing view should avoid extra proof-output windows. Proof text
  belongs in logs/manifests and caption chips, while the visible desktop remains
  the three task documents plus WinMux sidebar/zone chrome.

Implementation scope:

- Add `script/e2e/configs/zone-relaunch-saved-layout.toml` from the Slice 29
  saved-layout fixture.
- Add `script/e2e/guest/slice-31-relaunch-saved-layout.sh` with setup/proof and
  self-test phases.
- Reuse `ensure_window_in_zone` for setup-only placement.
- Save through the real CLI, stop the LaunchAgent/app, relaunch it from the same
  config path, and wait for `list-zones` after relaunch. The debug app must
  handle the LaunchAgent stop path as a restart, persist `window-state.json`
  before exit, and the relaunch must load that persisted restart state.
- Emit structured proof rows instead of adding another shell TOML-width parser:
  `logs/slice-31-relaunch-saved-layout.measurements.tsv` and
  `logs/slice-31-relaunch-saved-layout.proof-manifest.tsv`.

Required artifact contract:

- Screenshots:
  `01-ready-slice-31.png`, `02-after-runtime-resize-slice-31.png`,
  `03-after-save-slice-31.png`, `04-after-quit-slice-31.png`,
  `05-after-relaunch-slice-31.png`, and `99-after-slice-31.png`.
- Logs:
  `slice-31-zones-before.log`, `slice-31-zones-after-resize.log`,
  `slice-31-zones-after-save.log`, `slice-31-zones-after-relaunch.log`,
  `slice-31-windows-before.log`, `slice-31-windows-after-relaunch.log`,
  `slice-31-save-zone-layout.log`, `slice-31-relaunch.log`,
  `winmux-startup-trace.log`,
  `slice-31-config-before.sha256`, `slice-31-config-after-save.sha256`,
  `slice-31-config-backup.sha256`, the measurement TSV, the proof manifest, the
  event manifest, expected chips, demo-cut manifest, contact sheets, and
  reviewer packet.
- Proof manifest rows must include:
  `target	layout-id	balanced`, `safety	backup-matches-original	yes`,
  `relaunch	app-restarted	yes`, `relaunch	widths-restored	yes`,
  `relaunch	no-runtime-resize-after-launch	yes`,
  `relaunch	runtime-override-values-cleared	yes`,
  `relaunch	persisted-restart-state-loaded	yes`,
  `clean-view	before-visible-textedit-window-count	3`,
  `clean-view	relaunched-visible-textedit-window-count	3`, and per-zone
  before/resized/saved/relaunched effective widths.
- The guest proof must fail before writing `DONE` unless before widths are exactly
  `25/50/25`, resized widths are exactly `20/60/20`, relaunched configured and
  effective widths match the saved `20/60/20` layout, and relaunched
  `override-state` is `configured` with an empty or `none` `override` value. It
  must also fail if the visible TextEdit window set before resize or after
  relaunch is anything other than the three task documents
  `research-reference.rtf`, `focus-draft.rtf`, and `team-inbox.rtf`. The proof
  phase must re-run this exact-title check immediately before the first
  stateful mutation, not only during setup.
- The guest proof must emit unfiltered visible-window cleanliness logs for the
  ready, after-save, after-relaunch, and final product views. Each log must show
  exactly the three intended TextEdit task documents, may include WinMux's own
  sidebar/chrome, and must fail on Terminal, permission prompts, System
  Settings, Finder, proof-output windows, or any other unrelated visible app.
- The guest proof and host verifier must cross-check the product-window
  `x`/`width` coordinates against the matching zone logs. Research must be
  physically inside Reference, focus-draft inside Work, and team-inbox inside
  Comms for the ready, after-save, after-relaunch, and final product views. A
  correct logical `list-windows` zone is not enough if the visible TextEdit
  rectangle is in the wrong column.
- The verifier must parse `slice-31-command-timing.log` and require the actual
  resize/save/quit/relaunch/list-zones offsets to fall inside the matching
  visible caption windows.
- The verifier must require exact command lines in the resize/save/aggregate CLI
  logs and reject extra or variant `resize-zone` or `save-zone-layout` command
  lines, including lines hidden by leading whitespace.
- The verifier must also require exact `launchctl bootout WinMux slice service`
  and `launchctl bootstrap WinMux slice service` command lines in the relaunch
  and aggregate CLI logs, and reject leading-whitespace or suffixed variants.
- The verifier must require `logs/winmux-startup-trace.log` to contain
  `persisted frozen world loaded: false` for the initial launch and
  `persisted frozen world loaded: true` for the relaunch. If the relaunch did
  not load persisted restart state, the slice fails even when the final
  screenshot appears correct.
- The guest script must emit the post-recording retry mutation marker before the
  first visible stateful mutation, which for Slice 31 is
  `winmux resize-zone Work width +10%`; any failure after that point must not be
  retried inside the same recording.
- The measurement TSV must have exactly the expected header and exactly the
  before/resized/saved/relaunched rows for left/main/right, with the expected
  zone names and measurement chips on every row. Duplicate, missing, or extra
  rows are hard verifier failures.
- The verifier must cross-check every measurement TSV configured/effective/pixel
  width row against the source `list-zones` logs for before, resized, saved, and
  relaunched phases.
- The recording harness must snapshot
  `Sources/Common/gitHashGenerated.swift` and
  `Sources/Common/versionGenerated.swift` before its host build, restore those
  tracked files immediately after the build or on harness exit, and then run
  `check-generated-version-clean` before VM startup. `make build` legitimately
  embeds the current commit hash into `.debug/WinMuxApp`; the Tart gate must
  preserve a clean source tree without weakening the generated-file guard.
- `make e2e-pre-tart-checks` must include the pure restart placement regression
  test (`AppBundleUtilTest`) so the LaunchAgent relaunch fix cannot regress
  outside the VM harness.
- `expected-chips.txt` must be an exact, fresh derivation of columns 5..N from
  the annotation TSV. A stale, partial, or hand-trimmed expected-chip file is a
  hard verifier failure.
- Event and semantic sample rows that claim to show measurement chips must cite
  annotated caption boundary frames, not raw guest screenshots without caption
  chips. Raw screenshots remain required as geometry/sidebar state evidence.
- Event and semantic sample rows for `Action: quit WinMux`,
  `Result: WinMux sidebar absent`, `Action: relaunch WinMux`, and
  `Result: WinMux sidebar restored` must cite annotated caption boundary frames;
  raw quit/relaunch screenshots are additional geometry evidence, not a
  substitute for the visible command/action/result chips.
- `make e2e-review-lint` must require an accepted Slice 31 review to cite the
  primary full recording, demo sidecar, demo-cut manifest, event contact sheet,
  expected chips,
  measurement TSV, proof manifest, relaunch log, startup trace, aggregate CLI log, timing log,
  config hashes, before/after zone and window logs, unfiltered product-window
  cleanliness logs, guest privacy/clean-slate logs, clean/ready/final
  screenshots, every semantic sample path, edge/corner crop paths when present,
  the visual absent/restored relaunch cues, every expected caption chip, and the
  Slice 7/root-demo baselines. The accepted review must cite both
  `persisted frozen world loaded: false` and
  `persisted frozen world loaded: true` from the startup trace. Review
  freshness must include this full Slice 31 evidence set, not only the media
  files.
- Accepted Slice 31 reviews must include a `Baseline comparison:` paragraph that
  names the primary recording path, `demo-columnar-zones.mp4`, the Slice 7
  root-demo package, and at least one product screenshot or product surface. The
  paragraph must make explicit comparison claims for clean desktop, restrained
  captions, live windows/task documents, and command/config chips against those
  baselines, not merely list those keywords.

No-context artifact review requirements:

- The reviewer must inspect the full recording, demo sidecar, event contact
  sheet, measurement TSV, proof manifest, before/after zone logs, relaunch log,
  startup trace, saved config/backup hashes, and baseline product media
  including the root demo videos and Slice 7 root-demo package.
- The reviewer must answer from media alone whether the final widths are the
  saved `20/60/20` layout after a real app relaunch.
- Hard failures: relaunch is only a `reload-config`, final widths are only in
  logs, measurement chips are missing or unreadable, proof-output windows crowd
  the final product view, a task document is physically visible in the wrong
  zone column, the startup trace does not prove relaunch loaded persisted
  restart state, the demo sidecar is missing while the full recording has proof
  tail, or the review does not cite the Slice 7/root-demo baselines listed in
  the packet.

Validation gate:

- Add focused guest-script self-tests for measurement/proof manifest writing.
- Add an offline config-parse test for
  `script/e2e/configs/zone-relaunch-saved-layout.toml` and keep it in
  `make e2e-pre-tart-checks`.
- Run `bash -n`, `shellcheck`, `./script/e2e/verify-artifact --self-test`, and
  `make e2e-pre-tart-checks`.
- Produce the strict Tart artifact with `TART_HOME=/Volumes/RiftTartVMs/tart`.
- Run a fresh no-context artifact review with `fork_context=false`.
- Run and persist:
  `make e2e-review-lint RUN_DIR=<slice-31-dir>`,
  `make e2e-verify-slice-check RUN_DIR=<slice-31-dir> ARGS=--require-review`,
  and `make e2e-slice-closeout-check RUN_DIR=<slice-31-dir>`.
- Run three post-slice no-context retrospectives and fold accepted findings into
  the next pre-slice cleanup before Slice 32.

Slice 31 non-claims:

- no automatic persistence on every divider drag or resize command;
- no visual config editor;
- no new WinMux command syntax beyond the existing `resize-zone` and
  `save-zone-layout`;
- no proof of persistence across macOS reboot, only WinMux app relaunch;
- no named text-proof crop support;
- no grid/freeform zone layout editor.

Slice 31 accepted result:

- accepted artifact:
  `artifacts/e2e/slice-31-20260630T123932Z`;
- recordings:
  `recordings/slice-31-relaunch-saved-layout.mov`,
  `recordings/raw/slice-31-relaunch-saved-layout.raw.mov`, and
  `recordings/slice-31-relaunch-saved-layout.demo.mov`;
- media metadata: H.264, 3440x1440, 77.933333 seconds, 3426 frames for the
  full recording; 3440x1440, 64.150000 seconds for the demo sidecar;
- proof files:
  `logs/slice-31-relaunch-saved-layout.measurements.tsv`,
  `logs/slice-31-relaunch-saved-layout.proof-manifest.tsv`,
  `logs/winmux-startup-trace.log`,
  `logs/slice-31-relaunch.log`,
  `logs/slice-31-product-windows-after-relaunch.log`, and
  `logs/slice-31-zones-after-relaunch.log`;
- accepted claim: after `winmux resize-zone Work width +10%` and
  `winmux save-zone-layout`, a real `launchctl bootout` / `launchctl bootstrap`
  relaunch restores the saved `Reference 20% | Work 60% | Comms 20%` layout as
  configured widths, with `research-reference.rtf`, `focus-draft.rtf`, and
  `team-inbox.rtf` physically inside Reference, Work, and Comms;
- startup-state evidence: `logs/winmux-startup-trace.log` contains
  `persisted frozen world loaded: false` for the initial launch and
  `persisted frozen world loaded: true` for the relaunch;
- no-context artifact review:
  `reviews/no-ctx-artifact-review.md` returned `PASS_WITH_NOTES:` and final
  line `next slice allowed: yes`;
- artifact review note: the relaunch/result boundary-start caption frames show
  result cues before the visible transition fully settles. Later caption frames,
  `screenshots/04-after-quit-slice-31.png`,
  `screenshots/05-after-relaunch-slice-31.png`,
  `screenshots/99-after-slice-31.png`, and the logs prove the settled state, so
  the accepted artifact does not need re-recording. Future async lifecycle
  proofs should split action-start rows from settled-result rows.
- verification transcripts:
  `logs/review-lint.log`,
  `logs/post-review-verify.log`, and
  `logs/closeout-check.log` all pass against the final accepted review;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.

Slice 31 failed-attempt notes:

- `artifacts/e2e/slice-31-20260630T103835Z` failed before recording at
  `phase=host-build-generated-clean`; the abort status did not include a
  primary log. The accepted run's `logs/pre-tart-checks.log` and
  `logs/closeout-check.log` both end with generated version files clean.
- `artifacts/e2e/slice-31-20260630T115356Z` failed after recording started with
  `after relaunch zone mismatch for focus-draft.rtf: expected 'main', got
  'left'`. The accepted run fixes this with
  `logs/slice-31-windows-after-relaunch.log`,
  `logs/slice-31-product-windows-after-relaunch.log`, the startup trace, and
  the `restartRestoreTopLeft` monitor-origin regression test.

Pre-Slice-32 cleanup from Slice 31 retrospectives:

- [x] Finish all three Slice 31 no-context retrospectives and read them
  together.
- [x] Repair the accepted Slice 31 review so the current verifier accepts the
  full reviewer-packet baseline set, including `demo.mp4`, `demo2.mp4`,
  `demo3.mp4`, `demo-columnar-zones.mp4`, Slice 7 root-demo evidence, product
  screenshots, README, and product URLs.
- [x] Persist successful `make e2e-review-lint
  RUN_DIR=artifacts/e2e/slice-31-20260630T123932Z` output to
  `logs/review-lint.log`.
- [x] Persist successful `make e2e-verify-slice-check
  RUN_DIR=artifacts/e2e/slice-31-20260630T123932Z ARGS=--require-review`
  output to `logs/post-review-verify.log`.
- [x] Rerun and persist successful `make e2e-slice-closeout-check
  RUN_DIR=artifacts/e2e/slice-31-20260630T123932Z` output to
  `logs/closeout-check.log`.
- [x] Update this plan with the accepted Slice 31 result, failed-attempt notes,
  review caveat, gate transcripts, retrospectives, claims, and non-claims.
- [x] Add a `script/e2e/README.md` entry for `make e2e-slice-31`.
- [x] Before starting Slice 32 implementation, either commit the accepted Slice
  31 dirty set or record an explicit dirty-baseline diffstat/status for the
  current Slice 31 changes. Dirty baseline recorded on 2026-06-30 before Slice
  32 work: modified
  `Sources/AppBundle/initAppBundle.swift`,
  `Sources/AppBundle/util/appBundleUtil.swift`,
  `Sources/AppBundleTests/config/ConfigTest.swift`,
  `docs/plans/columnar-zones.md`, `makefile`, `script/e2e/README.md`,
  `script/e2e/annotate-recording`, `script/e2e/tart-recording-harness`,
  `script/e2e/verify-artifact`, and `script/e2e/write-review-packet`;
  untracked
  `Sources/AppBundleTests/util/AppBundleUtilTest.swift`,
  `script/e2e/configs/zone-relaunch-saved-layout.toml`, and
  `script/e2e/guest/slice-31-relaunch-saved-layout.sh`. Tracked diffstat before
  this note: 10 files changed, 2081 insertions, 76 deletions; `git diff
  --check` passed.
- [ ] Before any future lifecycle or async-state proof, update event/sample rows
  so `sidebar-absent`, `sidebar-restored`, and equivalent result predicates cite
  settled evidence frames or named state screenshots, not the same action-start
  boundary frame.
- [x] Finish the Slice 31 harness follow-ups before another long-running
  lifecycle slice. `host-build-generated-clean` now writes
  `logs/host-build-generated-clean.log` as the abort primary log; guest retry
  summaries include `mutation_started` and `first_mutation_line`; generic
  reviewer packets say `proof manifest` instead of `drag proof manifest`;
  no-context review prompts and verifier checks require mutation metadata when
  present; and `require_annotation_chip_covers_offset` scans caption columns
  5..N. Verified on 2026-06-30 with `bash -n`, `shellcheck`,
  `./script/e2e/verify-artifact --self-test`,
  `./script/e2e/tart-recording-harness warmup-policy-self-test`,
  `make e2e-pre-tart-checks`, `git diff --check`, and
  `./script/e2e/check-generated-version-clean`.

### Slice 32: Divider Drag Save/Relaunch

Status: accepted.

Goal:

- Prove the user-visible Work/Comms divider drag can be made durable with the
  same explicit `winmux save-zone-layout` command that Slice 31 validated for
  keyboard-driven `resize-zone`.
- Keep the UX claim narrow: this slice proves explicit save/relaunch durability
  after a visible divider drag. It does not prove automatic persistence after
  every drag, macOS reboot restore, a visual config editor, or arbitrary
  grid/freeform zone layout editing.

Storyboard:

- Start from the accepted three-zone ultrawide layout using
  `script/e2e/configs/zone-divider-drag.toml`.
- Show a clean ready desktop with Reference, Work, and Comms task documents.
- Drag the Work/Comms divider with the Slice 26 hover, pickup, drag-path,
  live-preview, release, and after-resize proof frames.
- Hold the dragged state on screen long enough for the demo captions to explain
  that runtime width overrides are visible.
- Run `winmux save-zone-layout`.
- Quit WinMux with the slice LaunchAgent service, then relaunch it with
  `launchctl bootstrap`.
- Run `winmux list-zones` after relaunch.
- Show the dragged widths restored as configured widths with runtime override
  values cleared.

Required artifacts:

- `recordings/slice-32-divider-save-relaunch.mov`;
- `recordings/raw/slice-32-divider-save-relaunch.raw.mov`;
- `recordings/slice-32-divider-save-relaunch.demo.mov`;
- `screenshots/02-divider-hover-slice-26.png`,
  `03-divider-pickup-slice-26.png`,
  `04-divider-drag-path-slice-26.png`,
  `05-divider-preview-slice-26.png`,
  `06-divider-release-slice-26.png`, and
  `07-after-divider-resize-slice-26.png`;
- `screenshots/08-after-save-slice-32.png`,
  `09-after-quit-slice-32.png`,
  `10-after-relaunch-slice-32.png`, and `99-after-slice-32.png`;
- `logs/slice-26-zone-divider-drag.proof-manifest.tsv`;
- `logs/slice-26-zone-divider-drag.mouse-events.tsv`;
- `logs/slice-32-divider-save-relaunch.event-manifest.tsv`;
- `logs/slice-32-divider-save-relaunch.measurements.tsv`;
- `logs/slice-32-divider-save-relaunch.proof-manifest.tsv`;
- `logs/slice-32-save-zone-layout.log`;
- `logs/slice-32-relaunch.log`;
- `logs/winmux-startup-trace.log`;
- config hash, backup, sample-manifest, event-manifest, expected-chip, review,
  post-review verifier, and closeout logs.

Verifier requirements:

- The delegated Slice 26 proof manifest must show
  `drag-target/snap-target=zone-divider`,
  `divider-policy/target=adjacent-zone-boundary`, and
  `divider-policy/config-persistence=no-config-rewrite`.
- The Slice 32 event manifest must split the delegated divider drag into
  `divider-hover`, `divider-pickup`, `divider-drag-path`,
  `divider-live-preview`, `divider-release`, and `after-divider-resize`, with
  seconds matching `logs/slice-26-zone-divider-drag.mouse-events.tsv`.
- Measurements must include `before`, `dragged`, `saved`, and `relaunched`
  rows for `left`, `main`, and `right`.
- Dragged Work/main must grow, dragged Comms/right must shrink, and
  Reference/left must stay stable.
- Saved effective widths must match the dragged widths.
- Relaunched configured and effective widths must match the dragged widths.
- Relaunched zones must report `override-state=configured` and empty runtime
  override values.
- The save log must contain exactly `$ winmux save-zone-layout`, saved output,
  and a backup path.
- The relaunch log must contain exactly one `launchctl bootout` and one
  `launchctl bootstrap`, plus `stopped=yes`; `reload-config` and post-relaunch
  `resize-zone` are forbidden.
- The startup trace must include initial `persisted frozen world loaded: false`
  and relaunch `persisted frozen world loaded: true`.
- The no-context review must cite the divider media, save/backup evidence,
  relaunch evidence, expected caption chips, product baselines, and full-packet
  baseline comparison before the next slice starts.

Execution gate:

- Run focused host checks, then three no-context pre-Tart reviewers. Each
  pre-Tart reviewer must inspect the current Slice 32 harness/verifier wiring
  without chat history and finish with `NO ACTIONABLE ISSUES` before Tart
  starts.
- Run `TART_HOME=/Volumes/RiftTartVMs/tart make e2e-slice-32`.
- Run `make e2e-verify-slice RUN_DIR=<slice-32-run-dir>`.
- Run the no-context artifact review, `make e2e-review-lint`,
  `make e2e-verify-slice-check ARGS=--require-review`, and
  `make e2e-slice-closeout-check`.
- Run three no-context retrospectives and fold accepted findings into the next
  pre-slice cleanup.

Slice 32 accepted result:

- accepted artifact:
  `artifacts/e2e/slice-32-20260630T181608Z`;
- recordings:
  `recordings/slice-32-divider-save-relaunch.mov`,
  `recordings/raw/slice-32-divider-save-relaunch.raw.mov`, and
  `recordings/slice-32-divider-save-relaunch.demo.mov`;
- media metadata: H.264, 3440x1440, 104.000000 seconds, 4658 frames for the
  full recording; the demo sidecar is 90.000000 seconds;
- proof files:
  `logs/slice-26-zone-divider-drag.proof-manifest.tsv`,
  `logs/slice-26-zone-divider-drag.mouse-events.tsv`,
  `logs/slice-32-divider-save-relaunch.event-manifest.tsv`,
  `logs/slice-32-divider-save-relaunch.measurements.tsv`,
  `logs/slice-32-divider-save-relaunch.proof-manifest.tsv`,
  `logs/slice-32-save-zone-layout.log`,
  `logs/slice-32-relaunch.log`,
  `logs/slice-32-zones-after-relaunch.log`,
  `logs/slice-32-windows-after-relaunch.log`, and
  `logs/winmux-startup-trace.log`;
- accepted claim: after a visible Work/Comms zone-divider drag,
  `winmux save-zone-layout`, and a real `launchctl bootout` / `launchctl
  bootstrap` relaunch, `winmux list-zones` reports the dragged widths restored
  as configured widths and runtime override values cleared;
- accepted divider proof: Slice 32 delegates the mouse drag affordance media to
  the accepted Slice 26 frames and carries those timings into
  `logs/slice-32-divider-save-relaunch.event-manifest.tsv` as separate
  `divider-hover`, `divider-pickup`, `divider-drag-path`,
  `divider-live-preview`, `divider-release`, and `after-divider-resize` rows;
- accepted measurements: Work grows from `0.5` to `0.5749407582938388` during
  the drag, Comms shrinks from `0.25` to `0.17505924170616113`, saved effective
  widths match the dragged widths, and relaunched configured/effective widths
  are `0.574941` for Work and `0.175059` for Comms;
- startup-state evidence: `logs/winmux-startup-trace.log` contains
  `persisted frozen world loaded: false` for initial launch and
  `persisted frozen world loaded: true` for relaunch;
- no-context artifact review:
  `reviews/no-ctx-artifact-review.md` returned `PASS:` and final line
  `next slice allowed: yes`;
- pre-Tart review gate: Hubble, Hilbert, and Turing each finished with
  `NO ACTIONABLE ISSUES` after the Slice 32 harness/verifier fixes;
- validation commands:
  `make e2e-pre-tart-checks`,
  `TART_HOME=/Volumes/RiftTartVMs/tart make e2e-slice-32`,
  `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-32-20260630T181608Z`,
  `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-32-20260630T181608Z`,
  and
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-32-20260630T181608Z ARGS=--require-review`
  all pass against the accepted artifact;
- verification transcripts:
  `logs/review-lint.log`, `logs/post-review-verify.log`, and
  `logs/closeout-check.log`;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`;
- dirty baseline:
  `logs/accepted-dirty-baseline.status.txt`,
  `logs/accepted-dirty-baseline.diffstat.txt`, and
  `logs/accepted-dirty-baseline.cached-diffstat.txt`.

Slice 32 accepted notes:

- The guest transport had retry noise before recording started:
  `00-before-slice-32.screencapture` retried SSH setup and
  `warmup-before-recording` retried once. Post-recording phases
  `slice-32-run` and `99-after-slice-32.screencapture` had zero failures, so
  no product action was hidden by a retry.
- Two derived-sidecar verifier issues were fixed after recording: the
  event-sample label changed from `config-ready` to `ready-divider-zones`, and
  the verifier learned that Slice 32's delegated Slice 26 drag proof has an
  external caption plan. The raw and primary recordings did not change; the
  accepted sidecars were refreshed from
  `recordings/raw/slice-32-divider-save-relaunch.raw.mov`.
- Slice 32 lifecycle proof still reuses some Slice 26 service/path names for
  delegated divider evidence. This is accepted for Slice 32 because verifier and
  review evidence disambiguate the delegation, but future lifecycle slices
  should use slice-local service names for their relaunch proof.

Slice 32 non-claims:

- no automatic persistence after every divider drag without explicit
  `winmux save-zone-layout`;
- no persistence proof across macOS reboot;
- no visual config editor;
- no arbitrary grid/rectangle/freeform zone layout editor;
- no proof that changing layouts, styles, or zone availability persists through
  the same relaunch path.

Pre-Slice-33 cleanup from Slice 32 retrospectives:

- [x] Finish all three Slice 32 no-context retrospectives and read them
  together.
- [x] Persist successful `make e2e-review-lint
  RUN_DIR=artifacts/e2e/slice-32-20260630T181608Z` output to
  `logs/review-lint.log`.
- [x] Persist successful `make e2e-verify-slice-check
  RUN_DIR=artifacts/e2e/slice-32-20260630T181608Z ARGS=--require-review`
  output to `logs/post-review-verify.log`.
- [x] Record an explicit dirty-baseline inventory for the accepted Slice 32
  dirty set in `logs/accepted-dirty-baseline.status.txt`,
  `logs/accepted-dirty-baseline.diffstat.txt`, and
  `logs/accepted-dirty-baseline.cached-diffstat.txt`.
- [x] Update this plan with the accepted Slice 32 result, review/verifier
  evidence, transcripts, retrospectives, claims, non-claims, and sidecar repair
  notes.
- [x] Rerun and persist successful `make e2e-slice-closeout-check
  RUN_DIR=artifacts/e2e/slice-32-20260630T181608Z` output to
  `logs/closeout-check.log`.
- [ ] Before the next lifecycle proof, rename slice-specific LaunchAgent labels,
  plist names, temp logs, and startup traces so the proof does not look like the
  wrong slice.
- [ ] Before the next measurement-heavy proof, factor the repeated
  `list-zones`/`list-windows` parsing used by Slice 29/31/32 into a shared guest
  helper or generated TSV contract.
- [ ] Before the next async lifecycle proof, prefer observable settled-state
  waits over fixed sleeps for relaunch, sidebar/chrome readiness, and final
  product screenshots.
- [x] Decide whether to commit the accepted Slice 31/32 dirty set or carry the
  explicit dirty baseline forward in the next slice notes before starting a new
  Tart run. Decision: carry the explicit dirty baseline forward for Slice 33;
  do not commit mid-slice unless requested.

### Slice 33: Scene Cycling for Whole-Layout State

Status: accepted.

Goal: make whole-monitor scene changes ergonomic enough for one-key workflows.
Users should be able to bind one command to cycle an ultrawide layout through
states such as triage, deep-work, and back to triage. A scene remains a virtual
monitor-level state: layout preset plus active workspace per zone.

Implementation scope:

- Add `cycle-zone-scene [--monitor <monitor-pattern>] <scene-id>...`.
- Track the active scene per physical monitor runtime overlay.
- If the current active scene is in the provided cycle list, advance to the next
  scene and wrap at the end.
- If the runtime overlay has no active scene but the current layout/workspace
  state exactly matches one of the cycle entries, advance from that matched
  scene.
- If the current state does not match the list, apply the first scene.
- Reject duplicate or unknown scene ids without mutating state.
- Clear active scene state when `use-zone-layout` directly overrides the
  monitor layout.
- Expose the workflow in example configs:
  `alt-tab = 'cycle-zone-scene triage deep-work'` for direct mode and
  `c = ['cycle-zone-scene triage deep-work', 'mode main']` in zone mode.

Required fast checks before Tart:

- `python3 ./script/check-command-metadata`;
- `swift test --filter ZoneCommandTest`;
- `swift test --filter ConfigTest.testParseZoneModeV2E2EConfig`;
- `git diff --check`;
- `bash -n script/e2e/tart-recording-harness script/e2e/verify-artifact
  script/e2e/write-review-packet script/e2e/guest/slice-6b-zone-scenes.sh`;
- `./script/e2e/tart-recording-harness annotation-preflight`.

Required pre-Tart no-context gate:

- Run three no-context reviewers against the Slice 33 code, config, harness, and
  verifier diff.
- Each reviewer must answer either `NO ACTIONABLE ISSUES` or list blocking
  issues. Silence, generic approval, or failure to inspect the exact Slice 33
  files is not a pass.
- Do not run `TART_HOME=/Volumes/RiftTartVMs/tart make e2e-slice-33` until all
  three pre-Tart reviewers are clean.

Required Tart artifact:

- `recordings/slice-33-cycle-zone-scene.mov`;
- `recordings/raw/slice-33-cycle-zone-scene.raw.mov`;
- `logs/slice-33-cycle-zone-scene.annotations.tsv`;
- `logs/slice-33-cycle-zone-scene.expected-chips.txt`;
- `logs/slice-33-cycle-zone-scene.event-manifest.tsv`;
- `logs/slice-33-scene-before.log`;
- `logs/slice-33-scene-after.log`;
- `logs/slice-33-scene-wrap.log`;
- `logs/slice-33-cycle-zone-scene.log`;
- `logs/slice-33-cycle-zone-scene-wrap.log`;
- `logs/slice-33-windows-before.log`;
- `logs/slice-33-windows-after.log`;
- `logs/slice-33-windows-wrap.log`;
- `screenshots/00-before-slice-33.png`,
  `01-ready-slice-33.png`, and `99-after-slice-33.png`.

Video contract:

- The video must show triage before the first command.
- The first mutating command/action caption must be
  `Run: winmux cycle-zone-scene triage deep-work`.
- Deep-work documents must appear after the first command, not before it.
- The same command must appear a second time.
- Triage documents must appear again after the second command, proving
  wraparound.
- Captions must expose the exact user-facing binding/config surface and the
  exact inspection commands.

Post-artifact gates:

- Run `make e2e-verify-slice RUN_DIR=<slice-33-run-dir>`.
- Generate a no-context artifact review packet and run the no-context artifact
  reviewer.
- Run `make e2e-review-lint RUN_DIR=<slice-33-run-dir>`.
- Run `make e2e-verify-slice-check RUN_DIR=<slice-33-run-dir>
  ARGS=--require-review`.
- Run three no-context retrospectives over plan/process, code/harness, and
  artifact/product quality, then carry actionable findings into Pre-Slice-34
  cleanup before proceeding.

Slice 33 accepted result:

- accepted artifact:
  `artifacts/e2e/slice-33-20260630T200032Z`;
- primary recording:
  `artifacts/e2e/slice-33-20260630T200032Z/recordings/slice-33-cycle-zone-scene.mov`;
- raw guest recording:
  `artifacts/e2e/slice-33-20260630T200032Z/recordings/raw/slice-33-cycle-zone-scene.raw.mov`;
- accepted review:
  `artifacts/e2e/slice-33-20260630T200032Z/reviews/no-ctx-artifact-review.md`
  with verdict `PASS` and `next slice allowed: yes`;
- reviewer packet:
  `artifacts/e2e/slice-33-20260630T200032Z/reviews/reviewer-packet.md`;
- proof file:
  `artifacts/e2e/slice-33-20260630T200032Z/slice-33-zone-scene-proof.txt`;
- post-review gate logs:
  `artifacts/e2e/slice-33-20260630T200032Z/logs/review-lint.log`,
  `artifacts/e2e/slice-33-20260630T200032Z/logs/post-review-verify.log`,
  and
  `artifacts/e2e/slice-33-20260630T200032Z/logs/closeout-check.log`;
- retrospectives:
  `artifacts/e2e/slice-33-20260630T200032Z/retrospectives/process-plan.md`,
  `artifacts/e2e/slice-33-20260630T200032Z/retrospectives/code-harness.md`,
  and
  `artifacts/e2e/slice-33-20260630T200032Z/retrospectives/artifact-product.md`.

What the accepted artifact proves:

- `cycle-zone-scene triage deep-work` advances the active monitor from the
  triage scene to the deep-work scene, then wraps back to triage when run again;
- the same command is visible twice in the annotated 3440x1440 guest recording;
- the first command starts while Triage Inbox, Triage Draft, and Triage Updates
  are still visible;
- Focus Queue, Focus Build, and Focus Notes are visible after the first command;
- the second command starts while Focus Queue, Focus Build, and Focus Notes are
  still visible;
- Triage Inbox, Triage Draft, and Triage Updates return after the second command;
- scene logs, window logs, expected caption chips, and the event manifest agree
  with the video sequence.

Accepted claims:

- `cycle-zone-scene [--monitor <monitor-pattern>] <scene-id>...` is wired into
  command parsing, manifests, generated help, config examples, and command
  execution;
- the runtime overlay tracks the active scene per physical monitor and wraps
  through the supplied scene list;
- if no active scene is recorded, the command can advance from the scene that
  matches the current layout/workspace state;
- duplicate or unknown scene ids fail without mutating state;
- direct `use-zone-layout` clears active scene state;
- the e2e config exposes `alt-tab = 'cycle-zone-scene triage deep-work'` and
  the zone-mode binding `c = ['cycle-zone-scene triage deep-work',
  'mode main']`.

Accepted non-claims:

- no visual scene editor;
- no sidebar, tab-group, drag, snap, or style-control UX claim;
- no persistence or relaunch claim for active scene state;
- no multi-monitor scene-cycle proof beyond the selected physical monitor;
- no claim that verifier image-content checks can replace no-context media
  review for command/result timing.

Slice 33 failed-attempt ledger:

- `artifacts/e2e/slice-33-20260630T192903Z` is superseded by
  `artifacts/e2e/slice-33-20260630T200032Z`. Its no-context artifact review
  failed because the second `Run: winmux cycle-zone-scene triage deep-work`
  caption appeared after the video had already wrapped back to triage. The run
  is formally marked with `reviews/superseded.md` and
  `logs/run-abort-status.txt`.

Slice 33 accepted notes:

- The accepted Tart run used `TART_HOME=/Volumes/RiftTartVMs/tart`; preflight
  recorded 1.8 TiB available on `/Volumes/RiftTartVMs`.
- The accepted artifact's guest retry summaries have no failed attempts. The
  only mutable product phase is `slice-33-run`, with
  `mutation_started=yes`.
- The no-context artifact review required targeted citation/language amendments
  before the machine review lint accepted it; the final review and both
  post-review verifier gates pass.
- The pre-Tart no-context reviewer gate passed with three clean
  `NO ACTIONABLE ISSUES` results, but those reviewer outputs were not persisted
  into the artifact. Future slices should store pre-Tart reviewer reports if the
  plan treats that gate as auditable artifact evidence.

Pre-Slice-34 cleanup:

- [x] Persist successful `make e2e-review-lint
  RUN_DIR=artifacts/e2e/slice-33-20260630T200032Z` output to
  `logs/review-lint.log`.
- [x] Persist successful `make e2e-verify-slice-check
  RUN_DIR=artifacts/e2e/slice-33-20260630T200032Z ARGS=--require-review`
  output to `logs/post-review-verify.log`.
- [x] Run all three Slice 33 no-context retrospectives and fold their blocking
  findings into this checklist.
- [x] Run and persist successful `make e2e-slice-closeout-check
  RUN_DIR=artifacts/e2e/slice-33-20260630T200032Z` output to
  `logs/closeout-check.log`.
- [x] Mark the failed media-producing Slice 33 attempt as superseded by the
  accepted artifact.
- [x] Record an explicit dirty-baseline inventory for the accepted Slice 33
  dirty set in `logs/accepted-dirty-baseline.status.txt`,
  `logs/accepted-dirty-baseline.diffstat.txt`, and
  `logs/accepted-dirty-baseline.cached-diffstat.txt`.
- [x] Update this plan with the accepted Slice 33 result, failed-attempt note,
  review/verifier evidence, retrospectives, claims, non-claims, and closeout
  evidence.
- [x] Before the next Tart run, either commit the accepted Slice 31-33 dirty set
  or explicitly decide to carry the Slice 33 dirty-baseline inventory forward.
  Decision: commit the accepted Slice 31-33 dirty set as the Slice 33 closeout
  boundary before starting the next product slice.
- [x] Before the next action-sensitive command-transition proof, add either
  command timing evidence or frame-content verifier checks for the command
  boundary that failed in the first Slice 33 attempt. Future Slice 33 reruns now
  emit `logs/slice-33-command-timing.log`, and the verifier requires both
  `cycle-zone-scene` command starts to occur under their matching `Run:`
  captions. The accepted `slice-33-20260630T200032Z` artifact is a documented
  historical exception because it predates the timing log but passed media
  review.
- [x] Before the next transition proof, tighten the slice-specific reviewer
  packet so reviewers reject target-state visibility before the relevant
  command caption starts. The Slice 33 packet now fails triage visibility before
  or at the second command-caption start.
- [x] Before the next reusable zone-scene proof, rename the leftover
  `slice-6b-zone-count.txt` guest log to use `${SLICE_PREFIX}`.
- [x] Before another non-Slice-31 review path uses it, rename
  `require_review_mentions_slice_31_sample_paths` to a generic helper and fix
  its error text.
- [x] If future pre-Tart no-context reviewer gates remain required, write their
  outputs to a named artifact directory and cite them in the plan before
  starting the Tart recording. Convention: when the coordinator runs pre-Tart
  reviewers, write their reports under
  `<run-dir>/reviews/pre-tart/{process-plan,code-harness,artifact-product}.md`
  and cite those paths in the slice result or pre-slice checklist.

### Slice 34: Ready-to-Use Scene Binding Showcase

Status: accepted.

Goal: prove the user-facing binding path for whole-layout scene cycling. Slice
33 proved the direct command. Slice 34 proves the configured shortcut surface:
`alt-tab = 'cycle-zone-scene triage deep-work'`, invoked through
`winmux trigger-binding --mode main alt-tab`, advances triage -> deep-work and
wraps back to triage.

Implementation scope:

- Add `e2e-slice-34` and Tart action `slice-34`.
- Reuse the parameterized zone-scene guest harness with
  `WINMUX_E2E_ZONE_SCENE_SLICE_PREFIX=slice-34`.
- Run the proof action through
  `WINMUX_E2E_ZONE_SCENE_COMMAND_ARGS='trigger-binding --mode main alt-tab'`.
- Keep Slice 34 logs, LaunchAgent labels, timing logs, screenshots, captions,
  and verifier paths unique to `slice-34`; no Slice 33 filenames may satisfy
  this slice.
- Add a Slice 34 verifier that requires:
  `alt-tab = 'cycle-zone-scene triage deep-work'` in the copied config; both
  command logs to show `$ winmux trigger-binding --mode main alt-tab`; the
  nested scene command output to report `deep-work` then `triage`; command
  timing under the matching command captions; and triage/deep-work/triage
  window and zone logs.
- Add reviewer-packet checks that reject direct-command-only proof, stale
  command/result timing, missing binding citation, or final-state-only proof.
- Add a machine pre-Tart review gate so `make e2e-slice-34` fails before Tart
  unless all three persisted no-context pre-Tart reports are clean and name the
  Slice 34 plan, harness, verifier, packet, and guest-script files.

Required fast checks before Tart:

- `bash -n script/e2e/tart-recording-harness script/e2e/verify-artifact
  script/e2e/write-review-packet script/e2e/guest/slice-6b-zone-scenes.sh`;
- `git diff --check`;
- `./script/e2e/tart-recording-harness annotation-preflight`;
- `./script/e2e/verify-artifact --self-test`;
- `make e2e-pre-tart-checks`, whose logged transcript must include
  `git diff --check`.

Required pre-Tart no-context gate:

- Run three no-context reviewers after the fast checks and before Tart.
- Persist reports under
  `<run-dir>/reviews/pre-tart/{process-plan,code-harness,artifact-product}.md`.
- Each reviewer must inspect current Slice 34 plan/code/harness/verifier
  wiring and end with `NO ACTIONABLE ISSUES`; generic approval, silence, or a
  review that does not name the Slice 34 files is not a pass.
- `make e2e-slice-34` must run
  `script/e2e/check-pre-tart-review-gate <run-dir> slice-34` before the Tart
  harness starts. A manual Tart invocation that bypasses this gate is not an
  accepted Slice 34 run.

Required Tart artifact:

- `recordings/slice-34-zone-mode-scene.mov`;
- `recordings/raw/slice-34-zone-mode-scene.raw.mov`;
- `logs/slice-34-zone-mode-scene.annotations.tsv`;
- `logs/slice-34-zone-mode-scene.expected-chips.txt`;
- `logs/slice-34-zone-mode-scene.event-manifest.tsv`;
- `logs/slice-34-zone-mode-scene.sample-manifest.tsv`;
- `logs/slice-34-command-timing.log`;
- `logs/slice-34-trigger-binding-alt-tab.log`;
- `logs/slice-34-trigger-binding-alt-tab-wrap.log`;
- `logs/slice-34-scene-before.log`;
- `logs/slice-34-scene-after.log`;
- `logs/slice-34-scene-wrap.log`;
- `logs/slice-34-windows-before.log`;
- `logs/slice-34-windows-after.log`;
- `logs/slice-34-windows-wrap.log`;
- `screenshots/00-before-slice-34.png`,
  `01-ready-slice-34.png`, and `99-after-slice-34.png`.

Video contract:

- The video must show triage before the first trigger-binding command.
- The first mutating command/action caption must be
  `Run: winmux trigger-binding --mode main alt-tab`.
- Deep-work documents must appear after the first trigger-binding command, not
  before it.
- The same trigger-binding command must appear a second time.
- Triage documents must appear again after the second trigger-binding command,
  proving wraparound.
- Captions must expose both the configured shortcut surface and the exact proof
  command: `Config: alt-tab = 'cycle-zone-scene triage deep-work'` and
  `Run: winmux trigger-binding --mode main alt-tab`.

Post-artifact gates:

- Run `make e2e-verify-slice RUN_DIR=<slice-34-run-dir>`.
- Generate a no-context artifact review packet and run the no-context artifact
  reviewer.
- Run `make e2e-review-lint RUN_DIR=<slice-34-run-dir>`.
- Run `make e2e-verify-slice-check RUN_DIR=<slice-34-run-dir>
  ARGS=--require-review`.
- Run three no-context retrospectives over plan/process, code/harness, and
  artifact/product quality, then carry actionable findings into Pre-Slice-35
  cleanup before proceeding.
- Run `make e2e-slice-closeout-check RUN_DIR=<slice-34-run-dir>` only after
  those retrospectives exist; closeout is the final blocking gate before
  proceeding.

Slice 34 accepted result:

- accepted artifact:
  `artifacts/e2e/slice-34-20260630T212647Z`;
- primary recording:
  `artifacts/e2e/slice-34-20260630T212647Z/recordings/slice-34-zone-mode-scene.mov`;
- raw guest recording:
  `artifacts/e2e/slice-34-20260630T212647Z/recordings/raw/slice-34-zone-mode-scene.raw.mov`;
- accepted review:
  `artifacts/e2e/slice-34-20260630T212647Z/reviews/no-ctx-artifact-review.md`
  with verdict `PASS` and `next slice allowed: yes`;
- reviewer packet:
  `artifacts/e2e/slice-34-20260630T212647Z/reviews/reviewer-packet.md`;
- proof file:
  `artifacts/e2e/slice-34-20260630T212647Z/slice-34-zone-scene-proof.txt`;
- pre-Tart clean reports:
  `artifacts/e2e/slice-34-20260630T212647Z/reviews/pre-tart/process-plan.md`,
  `artifacts/e2e/slice-34-20260630T212647Z/reviews/pre-tart/code-harness.md`,
  and
  `artifacts/e2e/slice-34-20260630T212647Z/reviews/pre-tart/artifact-product.md`;
- post-review gate logs:
  `artifacts/e2e/slice-34-20260630T212647Z/logs/review-lint.log`,
  `artifacts/e2e/slice-34-20260630T212647Z/logs/post-review-verify.log`,
  and
  `artifacts/e2e/slice-34-20260630T212647Z/logs/closeout-check.log`;
- retrospectives:
  `artifacts/e2e/slice-34-20260630T212647Z/retrospectives/process-plan.md`,
  `artifacts/e2e/slice-34-20260630T212647Z/retrospectives/code-harness.md`,
  and
  `artifacts/e2e/slice-34-20260630T212647Z/retrospectives/artifact-product.md`.

What the accepted artifact proves:

- `alt-tab = 'cycle-zone-scene triage deep-work'` in main mode can be invoked
  through the user-facing binding path with
  `winmux trigger-binding --mode main alt-tab`;
- the first binding invocation advances the focused physical monitor from
  triage to deep-work;
- the second invocation wraps the same monitor back to triage;
- both identical trigger-binding command captions occur while their matching
  pre-result scene is still visible;
- the deep-work result appears after the first binding command completes, and
  the triage wrap result appears after the second binding command completes;
- scene logs, window logs, timing logs, semantic samples, expected caption chips,
  and the event manifest agree with the 3440x1440 guest recording.

Accepted claims:

- `trigger-binding --mode main alt-tab` runs the configured
  `cycle-zone-scene triage deep-work` binding rather than relying on a direct
  `cycle-zone-scene` proof;
- the Slice 34 artifact names the second command log as
  `slice-34-trigger-binding-alt-tab-wrap.log`, not as a direct
  `cycle-zone-scene` log;
- the verifier rejects the generic direct-command PASS claim for Slice 34 and
  requires the binding-specific PASS claim;
- review lint requires semantic sample citations, event ids, exact binding text,
  exact trigger-binding command text, and the timing-value keys from
  `logs/slice-34-command-timing.log`;
- the pre-Tart review gate is executable for Slice 34 and fails before Tart when
  the three persisted clean pre-Tart reports are absent.

Accepted non-claims:

- no visual shortcut editor or keybinding recorder UI;
- no sidebar, tab-group, drag, snap, divider, or style-control UX claim;
- no claim that `Alt-Tab` was pressed through macOS global hotkey capture in the
  recording; the proof intentionally uses `winmux trigger-binding --mode main
  alt-tab` as the visible user-facing command path;
- no persistence or relaunch claim for active scene state;
- no multi-monitor scene-cycle proof beyond the selected physical monitor.

Slice 34 pre-Tart lineage:

- `artifacts/e2e/slice-34-pre-tart-20260630T210624Z` is a blocked pre-Tart
  review directory, not a product artifact. It found the missing executable
  pre-Tart report gate, missing logged `git diff --check` enforcement, stale
  direct-command proof wording, stale direct-command wrap-log naming, missing
  Slice 34 semantic sample rows, and weak timing-value review lint.
- `artifacts/e2e/slice-34-pre-tart-20260630T211859Z` is the clean pre-Tart
  evidence source. All three pre-Tart reports end with `NO ACTIONABLE ISSUES`,
  and `script/e2e/check-pre-tart-review-gate
  artifacts/e2e/slice-34-pre-tart-20260630T211859Z slice-34` passed.
- The accepted product artifact copies the clean pre-Tart reports under
  `artifacts/e2e/slice-34-20260630T212647Z/reviews/pre-tart/` and reran the
  pre-Tart checks before Tart.

Slice 34 accepted notes:

- The accepted Tart run used `TART_HOME=/Volumes/RiftTartVMs/tart`; preflight
  recorded 1.8 TiB available on `/Volumes/RiftTartVMs`.
- The accepted artifact has pre-recording SSH retry noise in
  `guest-artifacts-check`, `warmup-before-privacy`, and `clean-slate`, all with
  `final_result=success` before product recording. The stateful `slice-34-run`
  phase has `failures=0`, `final_result=success`, and
  `mutation_started=yes`.
- The no-context artifact review passed on the first written review and machine
  review lint accepted its timing values, semantic sample labels, event ids,
  command/config citations, and baseline comparisons.
- The Slice 34 README sync was added after the accepted artifact so future
  operators can find `make e2e-slice-34` and its binding-path contract from the
  e2e guide.

Pre-Slice-35 cleanup:

- [x] Finish all three Slice 34 retrospectives and read their findings together.
- [x] Update this plan with the accepted Slice 34 result, pre-Tart lineage,
  review/verifier evidence, retrospectives, claims, non-claims, and accepted
  notes.
- [x] Record an explicit dirty-baseline inventory for the accepted Slice 34
  dirty set in `logs/accepted-dirty-baseline.status.txt`,
  `logs/accepted-dirty-baseline.diffstat.txt`, and
  `logs/accepted-dirty-baseline.cached-diffstat.txt`.
- [x] Add a `make e2e-slice-34` paragraph to `script/e2e/README.md`.
- [x] Run and persist successful `make e2e-slice-closeout-check
  RUN_DIR=artifacts/e2e/slice-34-20260630T212647Z` output to
  `logs/closeout-check.log`.
- [x] Before starting Slice 35, either commit the accepted Slice 34 dirty set or
  explicitly decide to carry the Slice 34 dirty-baseline inventory forward.
  Current decision: carry the dirty-baseline inventory until the user requests a
  commit or the next slice boundary requires one.

Non-blocking follow-ups from Slice 34 retrospectives:

- [x] Add an explicit success marker around `git diff --check` in
  `make e2e-pre-tart-checks` before relying on the transcript text as proof of
  that command. Verified in
  `logs/pre-slice-35-cleanup-pre-tart-checks.log`.
- [x] Add a small self-test mode for `script/e2e/check-pre-tart-review-gate`
  and wire it into `make e2e-pre-tart-checks`.
- [x] Harden `script/e2e/check-pre-tart-review-gate` before reusing it for
  future slices. The gate now writes and validates a freshness manifest, requires
  reports to cite `candidate_head`, `candidate_state_sha256`,
  `git_status_sha256`, and `pre_tart_log_sha256`, and requires reviewers to
  mention both `makefile` and the gate script.
- For future ready-to-use binding demos, prefer a product-native visible state
  board or UI surface in addition to caption overlays when feasible.

Pre-Slice-35 optimization review:

- Three no-context optimization reviewers ran after Slice 34 closeout and found
  actionable cleanup issues before product work:
  `retrospectives/pre-slice-35-optimization-process-plan.md`,
  `retrospectives/pre-slice-35-optimization-code-harness.md`, and
  `retrospectives/pre-slice-35-optimization-artifact-product.md`.
- Implemented cleanup: `make e2e-pre-tart-checks` emits
  `[winmux-e2e] git diff --check PASS`, runs
  `script/e2e/check-pre-tart-review-gate --self-test`, and saved the transcript
  at `logs/pre-slice-35-cleanup-pre-tart-checks.log`.
- Implemented cleanup: `make e2e-run-product-slice` supports a two-phase
  pre-Tart review gate. The first run writes
  `reviews/pre-tart/freshness.env` after fast checks and stops for reviewers if
  reports are missing. The second run validates that the repo candidate and
  pre-Tart log still match the manifest before Tart starts.
- Implemented cleanup: `make e2e-slice-closeout-check` now emits
  `[winmux-e2e] slice closeout PASS: <run-dir>` after verifier,
  generated-version, and retrospection checks.
- Implemented cleanup: future Slice 34 binding manifests use
  `before-binding-triage` instead of the direct-command `before-cycle` id. The
  verifier keeps compatibility for the accepted Slice 34 artifact.
- Implemented cleanup: refreshed the dirty-baseline files after this hardening.
  The inventory includes `logs/accepted-dirty-baseline.status.txt`,
  `logs/accepted-dirty-baseline.diffstat.txt`,
  `logs/accepted-dirty-baseline.cached-diffstat.txt`, and
  `logs/accepted-dirty-baseline.untracked-sha256.tsv` for
  `script/e2e/check-pre-tart-review-gate`.

### Slice 35: Starter Ultrawide Template

Status: accepted.

Goal: make columnar zones usable from a fresh WinMux config without sending the
user on a documentation hunt. A new config should keep zones disabled by default,
but include a commented `WINMUX ULTRAWIDE ZONES TEMPLATE` that becomes a valid
three-zone setup when uncommented.

Implementation scope:

- Add the commented starter template to `resources/default-config.toml` so
  `starterConfigText()` and first-run bootstrap configs include it.
- Keep the active starter config behavior unchanged: no configured zones,
  layouts, scenes, availability sets, or named style/layout/scene bindings until
  the user opts in.
- The template must include a practical ultrawide setup: `Reference`, `Work`,
  and `Comms` zones; `balanced` and `focus` layouts; `triage` and `deep-work`
  scenes; `focus-only`, `communications`, and `full-dashboard` availability
  sets; `urgent`/`calm` styles; app affinity routing to `Comms`; mouse snap
  policy defaults; and compact zone-mode bindings for layout, availability,
  style, and scene cycling.
- Add fast parser coverage that validates both the inactive starter config and
  the same starter text with only the marked template uncommented.
- Add `ConfigBootstrapTest` to the pre-Tart Swift test filter so this starter
  proof runs before every future product Tart slice.
- Sync README language so users know the first-run config contains the template.

Required fast checks before Tart:

- `swift test --filter 'ConfigBootstrapTest|ConfigTest.testParseDefaultConfig'`;
- `git diff --check`;
- `bash -n script/e2e/check-pre-tart-review-gate script/e2e/tart-recording-harness
  script/e2e/verify-artifact script/e2e/write-review-packet`;
- `./script/e2e/check-pre-tart-review-gate --self-test`;
- `make e2e-pre-tart-checks`, with the transcript saved under the Slice 35 run
  directory and including `[winmux-e2e] git diff --check PASS`.

Required pre-Tart no-context gate:

- Register Slice 35 in `script/e2e/check-pre-tart-review-gate`.
- Run three no-context reviewers against the current Slice 35 plan, source,
  tests, README, makefile, pre-Tart gate, harness, verifier, packet writer, and
  guest script.
- Persist reports under
  `<run-dir>/reviews/pre-tart/{process-plan,code-harness,artifact-product}.md`.
- Each report must cite the freshness manifest lines, name the Slice 35 files it
  inspected, and end with `NO ACTIONABLE ISSUES`.
- Do not start Tart until `script/e2e/check-pre-tart-review-gate <run-dir>
  slice-35` passes.

Required Tart artifact:

- A strict guest-captured ultrawide recording showing:
  - the generated/staged starter config with the template still commented;
  - a visible, demo-quality action that uncomments the marked template;
  - a visible focused active-TOML excerpt proving the uncommented template is on
    screen, with active `[[zones]]` above the fold rather than only commented
    source or a full-file view that could hide the zone table;
  - WinMux launching from the uncommented config, then `winmux config --check
    <uncommented-config>` accepting that file through the running server;
  - `winmux list-zones` or another product command showing the resulting
    Reference, Work, and Comms zones;
  - lower-third captions exposing the user actions and exact WinMux commands.
- Required media/logs:
  `recordings/slice-35-starter-ultrawide-template.mov`,
  `recordings/raw/slice-35-starter-ultrawide-template.raw.mov`,
  `screenshots/00-before-slice-35.png`,
  `screenshots/01-starter-template-commented-slice-35.png`,
  `screenshots/02-template-uncommented-slice-35.png`,
  `screenshots/03-config-check-and-zones-slice-35.png`,
  `screenshots/99-after-slice-35.png`,
  `logs/slice-35-starter-config-before.toml`,
  `logs/slice-35-starter-config-uncommented.toml`,
  `logs/slice-35-visible-uncommented-template.txt`,
  `logs/slice-35-config-check.log`,
  `logs/slice-35-list-zones.log`,
  annotation sidecars, semantic sample manifests, event manifest, expected chips,
  and a reviewer packet.

Post-artifact gates:

- Run `make e2e-verify-slice RUN_DIR=<slice-35-run-dir>`.
- Generate the no-context artifact review packet and run a no-context artifact
  reviewer against the video, screenshots, commands, and repo/product baseline
  media.
- Run `make e2e-review-lint RUN_DIR=<slice-35-run-dir>`.
- Run `make e2e-verify-slice-check RUN_DIR=<slice-35-run-dir>
  ARGS=--require-review`.
- Run three no-context retrospectives over plan/process, code/harness, and
  artifact/product quality; carry actionable findings into the next pre-slice
  cleanup.
- Run `make e2e-slice-closeout-check RUN_DIR=<slice-35-run-dir>` after the
  retrospectives exist.

Slice 35 accepted result:

- accepted artifact:
  `artifacts/e2e/slice-35-20260630T225258Z`;
- primary recording:
  `artifacts/e2e/slice-35-20260630T225258Z/recordings/slice-35-starter-ultrawide-template.mov`;
- raw guest recording:
  `artifacts/e2e/slice-35-20260630T225258Z/recordings/raw/slice-35-starter-ultrawide-template.raw.mov`;
- accepted review:
  `artifacts/e2e/slice-35-20260630T225258Z/reviews/no-ctx-artifact-review.md`
  with verdict `PASS_WITH_NOTES` and `next slice allowed: yes`;
- reviewer packet:
  `artifacts/e2e/slice-35-20260630T225258Z/reviews/reviewer-packet.md`;
- proof file:
  `artifacts/e2e/slice-35-20260630T225258Z/slice-35-starter-ultrawide-template-proof.txt`;
- focused active-TOML excerpt:
  `artifacts/e2e/slice-35-20260630T225258Z/logs/slice-35-visible-uncommented-template.txt`;
- key screenshots:
  `screenshots/01-starter-template-commented-slice-35.png`,
  `screenshots/02-template-uncommented-slice-35.png`, and
  `screenshots/03-config-check-and-zones-slice-35.png`;
- pre-Tart clean reports:
  `artifacts/e2e/slice-35-20260630T225258Z/reviews/pre-tart/process-plan.md`,
  `artifacts/e2e/slice-35-20260630T225258Z/reviews/pre-tart/code-harness.md`,
  and
  `artifacts/e2e/slice-35-20260630T225258Z/reviews/pre-tart/artifact-product.md`;
- post-review gate logs:
  `artifacts/e2e/slice-35-20260630T225258Z/logs/review-lint.log`,
  `artifacts/e2e/slice-35-20260630T225258Z/logs/post-review-verify.log`,
  and
  `artifacts/e2e/slice-35-20260630T225258Z/logs/closeout-check.log`;
- retrospectives:
  `artifacts/e2e/slice-35-20260630T225258Z/retrospectives/process-plan.md`,
  `artifacts/e2e/slice-35-20260630T225258Z/retrospectives/code-harness.md`,
  and
  `artifacts/e2e/slice-35-20260630T225258Z/retrospectives/artifact-product.md`.

What the accepted artifact proves:

- a fresh/starter WinMux config includes the commented
  `WINMUX ULTRAWIDE ZONES TEMPLATE`;
- zones remain disabled by default until the user edits the config;
- uncommenting only the marked template produces active TOML with `[[zones]]`,
  zone-mode bindings, layouts, scenes, availability sets, styles, affinity, and
  mouse zone-snap examples;
- the recording shows a focused active-TOML excerpt with `[[zones]]` visible
  above the fold, not just a full-file view or final-state-only proof;
- `winmux config --check <uncommented-config>` accepts the uncommented starter
  config through the running server;
- `winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'`
  reports Reference/left, Work/main, and Comms/right;
- captions expose the user-facing config/action/commands for the full workflow:
  template marker, uncomment action, `WinMuxApp --config-path`, `config --check`,
  `list-zones`, and the Reference | Work | Comms result.

Slice 35 pre-Tart lineage:

- `artifacts/e2e/slice-35-pre-tart-20260630T223435Z` and
  `artifacts/e2e/slice-35-pre-tart-20260630T224127Z` are blocked pre-Tart
  review directories. Artifact-product reviewers correctly rejected the first
  design because the uncommented template was not visibly shown, then rejected
  the full-file view because active `[[zones]]` could be below the fold.
- `artifacts/e2e/slice-35-pre-tart-20260630T224813Z` is the clean pre-Tart
  evidence source. All three reports end with `NO ACTIONABLE ISSUES`, and
  `script/e2e/check-pre-tart-review-gate
  artifacts/e2e/slice-35-pre-tart-20260630T224813Z slice-35` passed.
- `artifacts/e2e/slice-35-pre-tart-20260630T225103Z` is a stale
  media-producing attempt with a stale artifact review. It is formally marked
  superseded by `artifacts/e2e/slice-35-20260630T225258Z` via
  `reviews/superseded.md` and `logs/run-abort-status.txt`.

Slice 35 accepted notes:

- The accepted Tart run used `TART_HOME=/Volumes/RiftTartVMs/tart`; preflight
  recorded 1.8 TiB available on `/Volumes/RiftTartVMs`.
- The accepted artifact has one pre-recording `guest-desktop-check` SSH retry
  and one post-recording final screenshot SSH retry. Both ended with
  `final_result=success`; the post-recording retry had `mutation_started=no`,
  so no re-record was required.
- The current no-context artifact review was regenerated after reviewer-packet
  hardening and accepts the refreshed reviewer-attempt ledger with
  `PASS_WITH_NOTES`.
- `make e2e-verify-slice`, `make e2e-review-lint`, `make
  e2e-verify-slice-check ARGS=--require-review`, and `make
  e2e-slice-closeout-check` passed for the accepted artifact.
- The refreshed sample manifest uses resolved numeric sample timestamps. The
  verifier rejects expression timestamps such as `0-0.500` and `8+0.100`
  instead of accepting them as boundary shorthand.

Slice 35 non-claims:

- no GUI config editor;
- no claim that zones are enabled for fresh users before they uncomment the
  template;
- no new zone runtime behavior beyond proving the starter opt-in path;
- no replacement for the root product demo.

Pre-Slice-36 cleanup:

- [x] Add a reusable helper for focused visible proof excerpts. It should take
  an input config plus a marker/table selector, write a compact reviewer-facing
  excerpt, and enforce that the required active table appears within a small
  line budget. Implemented as `script/e2e/write-visible-proof-excerpt`.
- [x] Extend the Slice 35 guest self-test or a shared guest-script self-test to
  cover `write_visible_uncommented_template`: active `[[zones]]` within the
  first 12 lines, no `# [[zones]]`, the `tab`/`a`/`y`/`c` bindings, and the
  Reference/Work/Comms summary. The `make e2e-pre-tart-checks` target now runs
  the Slice 35 guest self-test.
- [x] Move the "active TOML above the fold" rule into a reusable verifier helper
  for future config-demo slices rather than keeping it Slice 35-specific. The
  verifier now uses `require_visible_proof_active_table_above_fold`.
- [x] Add a reviewer-attempt ledger under each run directory, for example
  `reviews/reviewer-attempts.tsv`, recording role, start time, finish time,
  status, output path, and replacement reason for stalled or superseded
  reviewers. Implemented via `script/e2e/record-reviewer-attempt` and listed in
  reviewer packets.
- [x] Put the guest retry summary near the top of reviewer packets whenever any
  post-recording retry occurred.
- [x] Add a caption/proof placement check or guideline for text-heavy demos so
  proof windows do not sit under the caption anchor.
- [x] Make `make build` restore tracked generated version sources after the
  debug binaries are built, so local dogfood builds can embed the current
  `HEAD` hash without leaving `Sources/Common/gitHashGenerated.swift` dirty.

Pre-Slice-36 cleanup evidence:

- `make build` now snapshots `Sources/Common/gitHashGenerated.swift` and
  `Sources/Common/versionGenerated.swift`, stamps the debug build, copies
  `.debug/winmux` and `.debug/WinMuxApp`, and restores the tracked generated
  sources on exit.
- `make e2e-pre-tart-checks` passed with the new visible-proof helper,
  reviewer-attempt helper, Slice 35 guest self-test, annotation preflight, and
  focused Swift suite.
- `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-35-20260630T225258Z`
  passed after regenerating the Slice 35 reviewer packet and replacing the stale
  no-context review.
- `make e2e-slice-closeout-check` passed for
  `RUN_DIR=artifacts/e2e/slice-35-20260630T225258Z` with the refreshed numeric
  sample manifest and synchronized reviewer-attempt ledger.

### Slice 36: Current Root Demo Refresh

Status: accepted.

Goal: make the repo-root `demo-columnar-zones.mp4` reflect the current
columnar-zones UX instead of the older Slice 6B-only scene demo. The chosen
source is the accepted Slice 32 `.demo.mov` sidecar because it shows the
current visible divider affordance, explicit `save-zone-layout`, app relaunch,
and restored dragged widths in a clean 3440x1440 Tart-derived recording.

Implementation scope:

- Generalize `script/e2e/package-root-demo` so `--source-recording` can point at
  a newer accepted recording or `.demo.mov` sidecar, while keeping the old
  Slice 6B default working.
- Write source guest-capture, annotation, contact-sheet, sample, proof, and
  review paths into `logs/root-demo-package.log`.
- Generalize `script/e2e/verify-root-demo` to read the source guest-capture log
  from package metadata, with the historical Slice 6B path as a fallback for
  older accepted artifacts.
- Keep the root-demo package contract strict: accepted source review,
  `require_guest_control=1`, `capture_mode=guest`, successful source guest
  capture, playable H.264/yuv420p root MP4, 3440x1440 resolution, generated
  samples, caption-boundary frames, contact sheet, and no-context artifact
  review.

Required package command:

```bash
./script/e2e/package-root-demo \
  --source-run-dir artifacts/e2e/slice-32-20260630T181608Z \
  --source-recording recordings/slice-32-divider-save-relaunch.demo.mov \
  --slice-name slice-36-root-current-demo \
  --intended-behavior "package the accepted Slice 32 divider drag plus save/relaunch demo as the current repo-root columnar-zones showcase." \
  --output demo-columnar-zones.mp4
```

Accepted artifact:

- artifact directory:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z`;
- root demo:
  `demo-columnar-zones.mp4`;
- artifact copy:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/recordings/demo-columnar-zones.mp4`;
- package log:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/logs/root-demo-package.log`;
- reviewer packet:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/reviews/reviewer-packet.md`;
- contact sheet:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/screenshots/demo-columnar-zones.contact-sheet.jpg`;
- sample frames and caption-boundary frames:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/screenshots/demo-columnar-zones.samples/`;
- source artifact:
  `artifacts/e2e/slice-32-20260630T181608Z`;
- source recording:
  `artifacts/e2e/slice-32-20260630T181608Z/recordings/slice-32-divider-save-relaunch.demo.mov`.

Accepted mechanical evidence:

- `bash -n script/e2e/package-root-demo script/e2e/verify-root-demo` passed;
- `shellcheck script/e2e/package-root-demo script/e2e/verify-root-demo`
  passed;
- `./script/e2e/package-root-demo --self-test` passed;
- `make e2e-verify-root-demo-check
  RUN_DIR=artifacts/e2e/slice-36-root-current-demo-20260701T004813Z` passed;
- `make e2e-verify-root-demo-check
  RUN_DIR=artifacts/e2e/slice-36-root-current-demo-20260701T004813Z
  ARGS=--require-review` passed after the hardened no-context review landed;
- `make e2e-root-demo-closeout-check
  RUN_DIR=artifacts/e2e/slice-36-root-current-demo-20260701T004813Z` passed
  and wrote
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/logs/root-demo-closeout.log`;
- `verify-root-demo --require-review` now verifies the packaged source
  recording hash, source guest-capture hash, source review hash, and current
  parsed source review verdict from `logs/root-demo-package.log`;
- the root package includes copied source semantic proof:
  `logs/root-demo.source-sample-manifest.tsv` and
  `screenshots/demo-columnar-zones.source-event-contact-sheet.jpg`;
- root demo media summary: H.264 High profile, `yuv420p`, 3440x1440,
  90.000000 seconds, 4,039 frames, SHA-256
  `1a4dfbfe732cc4f413a3311516fdd0e99f8c3a6178178585b0383cd2faa4ac4e`.

Accepted no-context artifact review:

- accepted review:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/reviews/no-ctx-artifact-review.md`;
- verdict: `PASS`, `next slice allowed: yes`;
- reviewer-attempt ledger:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/reviews/reviewer-attempts.tsv`;
- accepted note: the first accepted review was archived at
  `reviews/no-ctx-artifact-review.stale-20260701T010931Z.md` after the
  retrospectives found that it did not cite the reviewer-attempt ledger. The
  current hardened replacement review cites the ledger's stalled and replacement
  attempts, names the stale/stalled rows, and passes `verify-root-demo
  --require-review`.

What the accepted artifact proves:

- the repo-root `demo-columnar-zones.mp4` is now a playable 3440x1440
  H.264/yuv420p showcase video sourced from an accepted strict guest-captured
  Tart artifact;
- the packaged source is the accepted Slice 32 demo sidecar, which shows a
  Work|Comms divider drag, explicit `winmux save-zone-layout`, WinMux quit and
  relaunch, `winmux list-zones`, and restored dragged widths;
- the package verifier and no-context review both compare the root demo against
  the repo baseline demos and product surfaces.

Accepted non-claims:

- no fresh Tart VM boot for Slice 36; the slice packages an already accepted
  Tart-derived video and verifies provenance;
- no claim that `demo-columnar-zones.mp4` covers starter-template onboarding,
  scene binding, app routing, sidebar drag, or arbitrary visual layout editing;
- no claim that dragged divider widths save automatically without
  `winmux save-zone-layout`.

Pre-Slice-37 cleanup:

- [x] Run three no-context retrospectives over Slice 36 plan/process,
  code/harness, and artifact/product quality:
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/retrospectives/process-plan.md`,
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/retrospectives/code-harness.md`,
  and
  `artifacts/e2e/slice-36-root-current-demo-20260701T004813Z/retrospectives/artifact-product.md`.
- [x] Harden `verify-root-demo --require-review` so an accepted root-demo review
  must cite the reviewer-attempt ledger whenever non-pass attempt rows exist.
- [x] Replace the stale Slice 36 root-demo review after the hardened verifier
  rejected it; record the stalled and replacement reviewer attempts in
  `reviews/reviewer-attempts.tsv`.
- [x] Fix the root-demo reviewer packet verdict guidance to require a first-line
  verdict and final `next slice allowed: yes/no`.
- [x] Verify source recording, source guest-capture, source review hash, and
  source review verdict provenance during root-demo verification.
- [x] Restore documented Slice 6B fallback packaging by accepting the historical
  `slice-6b-zone-scene-proof.txt` proof filename.
- [x] Copy source semantic proof into root-demo packages via
  `logs/root-demo.source-sample-manifest.tsv` and
  `screenshots/demo-columnar-zones.source-event-contact-sheet.jpg`.
- [x] Add README guidance for draggable zone dividers and
  `winmux save-zone-layout`.
- [x] Add a root-demo closeout target and log. `script/e2e/root-demo-closeout`
  and `make e2e-root-demo-closeout-check` run root-demo review lint through
  `verify-root-demo --require-review`, require the three retrospectives, verify
  generated version cleanliness, run `git diff --check`, and persist
  `logs/root-demo-closeout.log`.
- [x] Decide whether the next user-facing slice should package an onboarding
  companion for the Slice 35 starter-template flow, since the root demo now
  prioritizes the current divider/save/relaunch UX. Decision: yes; Slice 37 is
  the onboarding companion, not another replacement of the root demo.
- [x] Decide whether to commit the accepted Slice 34-36 dirty set before
  starting another feature-bearing slice. Decision: commit the accepted
  Slice 34-36 plus root-demo closeout changes before starting Slice 37 Tart
  work.
- [x] Re-run the focused host gate after adding the root-demo closeout target.
  `make e2e-pre-tart-checks` passed with shell checks, helper self-tests,
  root-demo closeout self-test, guest-script self-tests, annotation preflight,
  and 183 focused Swift tests.

### Slice 37: Starter Template Onboarding Companion

Status: accepted via
`artifacts/e2e/slice-37-starter-onboarding-20260701T045012Z`.

Goal: add a short companion demo that answers "how do I turn this on?" for a
new ultrawide user. The current root demo proves the mature divider drag,
`save-zone-layout`, relaunch, and restored widths flow. Slice 37 should show
the starter-template path from a clean config to visible zones without replacing
the root showcase video.

User-facing story:

- start from the generated starter config or a fresh config copied into the
  guest;
- expose the relevant `resources/default-config.toml` ultrawide starter block
  on screen with restrained caption chips;
- show the user action that enables the starter zones;
- run and show the WinMux commands a user would use next, including
  `winmux list-zones` and a minimal focus or move command;
- end with Reference, Work, and Comms zones visible on a clean 3440x1440 Tart
  desktop.

Required implementation shape:

- reuse the Slice 35 starter-template parser/bootstrap work instead of adding a
  second starter-template format;
- record through `make e2e-slice-37`, which runs
  `script/e2e/guest/slice-37-starter-onboarding.sh` in a Tart guest and uses
  `resources/default-config.toml` as the staged starter config;
- require deterministic host checks before Tart. The first focused pass after
  wiring Slice 37 completed `make e2e-pre-tart-checks` with shell syntax,
  shellcheck, generated-version cleanliness, helper self-tests, guest-script
  self-tests, annotation preflight, and 183 focused Swift tests;
- require three clean no-context pre-Tart reviewer reports under
  `reviews/pre-tart/` before the Tart recording starts. The reviewers must cite
  the Slice 37 plan, README, default config, guest script, make target,
  pre-Tart review gate, recorder, verifier, and reviewer packet. A stale
  pre-Tart run, `artifacts/e2e/slice-37-starter-onboarding-20260701T042559Z`,
  is rejected because its process reviewer correctly found that this plan
  overclaimed the gate state before the current reports passed. A recorded
  Tart run, `artifacts/e2e/slice-37-starter-onboarding-20260701T043138Z`,
  is also rejected because `focus-zone-offset-seconds=49` landed before the
  `Run: winmux focus-zone Comms` caption window. A later pre-Tart run,
  `artifacts/e2e/slice-37-starter-onboarding-20260701T044347Z`, is rejected
  before Tart because its process reviewer correctly found the timing contract
  still ambiguous. The current contract must keep `list-zones` in the
  `38-48` caption window and start `Run: winmux focus-zone Comms` at `48` so
  an observed `focus-zone-offset-seconds=49` is valid;
- record a fresh Tart guest-captured video for the companion artifact;
- keep the video self-explanatory with visible action and command chips;
- make the visible caption chips expose the exact user commands and actions:
  `Config: # BEGIN WINMUX ULTRAWIDE ZONES TEMPLATE`,
  `Action: uncomment WINMUX ULTRAWIDE ZONES TEMPLATE`,
  `Run: WinMuxApp --config-path slice-37-starter-config-uncommented.toml`,
  `Run: winmux config --check slice-37-starter-config-uncommented.toml`,
  `Run: winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'`,
  `Run: winmux focus-zone Comms`, and
  `Result: Reference | Work | Comms ready`;
- verify the artifact with `script/e2e/verify-artifact` requirements for the
  commented template, uncommented TOML excerpt, config-check log, list-zones
  log, focus-zone log, command timing, event manifest, semantic samples,
  screenshots, and caption chips;
- write a reviewer packet that compares against `demo-columnar-zones.mp4`, the
  Slice 36 root-demo package, repo root demos, README guidance, and product
  screenshots;
- require a no-context artifact review before acceptance;
- run three no-context retrospectives after the review and fold accepted
  findings into the next pre-slice cleanup before moving on.

Accepted artifact:

- accepted run:
  `artifacts/e2e/slice-37-starter-onboarding-20260701T045012Z`;
- recording:
  `recordings/slice-37-starter-onboarding.mov`;
- raw recording:
  `recordings/raw/slice-37-starter-onboarding.raw.mov`;
- no-context artifact review:
  `reviews/no-ctx-artifact-review.md`, first line `PASS: Slice 37 proves the
  opt-in starter onboarding path for ultrawide zones and the first useful
  command after enabling them.`, final line `next slice allowed: yes`;
- post-review gate logs:
  `logs/review-lint.log` and `logs/post-review-verify.log`;
- `make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-37-starter-onboarding-20260701T045012Z`
  passed with a 3440x1440 H.264 recording, 71.983333 seconds, 3155 frames;
- `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-37-starter-onboarding-20260701T045012Z`
  passed;
- `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-37-starter-onboarding-20260701T045012Z ARGS=--require-review`
  passed;
- command timing accepted:
  `focus-zone-offset-seconds=51` in `logs/slice-37-command-timing.log`, inside
  the `48 60` `Run: winmux focus-zone Comms` caption in
  `logs/slice-37-starter-onboarding.annotations.tsv`;
- accepted claims: starter config is opt-in/commented by default, the marked
  template uncomments into active TOML, `WinMuxApp --config-path` launches that
  config, `winmux config --check`, `winmux list-zones`, and
  `winmux focus-zone Comms` work against Reference, Work, and Comms zones;
- accepted non-claims: Slice 37 does not replace `demo-columnar-zones.mp4`,
  does not claim zones are enabled by default, does not claim a GUI config
  editor, and does not claim full command coverage;
- reviewer-attempt ledger: `reviews/reviewer-attempts.tsv` records one stalled
  `no-context-artifact-review` attempt, replaced because it timed out without
  writing a report;
- superseded recorded attempts:
  `artifacts/e2e/slice-37-starter-onboarding-20260701T020144Z` and
  `artifacts/e2e/slice-37-starter-onboarding-20260701T043138Z`, both marked
  superseded by `045012Z` because their focus-zone command landed outside the
  then-current caption window;
- blocked pre-Tart timing attempt:
  `artifacts/e2e/slice-37-starter-onboarding-20260701T044347Z`, whose
  process-plan reviewer blocked before Tart because the focus timing contract
  was still ambiguous;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.

Accepted non-goals:

- do not replace `demo-columnar-zones.mp4`;
- do not claim every zone command is taught in the onboarding demo;
- do not add another config DSL for starter templates.

Pre-Slice-38 cleanup from Slice 37 retrospectives:

- [x] Add a reusable guest timing helper,
  `script/e2e/guest/recording-timing-helpers.sh`, with
  `sleep_until_recording_offset <start> <end> <label>` for timed-caption guest
  scripts. It fails with the semantic failure exit if the command is already
  past its caption window and has a self-test in `make e2e-pre-tart-checks`.
- [x] Replace raw sleeps around action-sensitive Slice 37 command captions with
  the timing helper. Future timed-caption scripts should use the same helper
  whenever they record command offsets in `logs/*command-timing.log`.
- [x] Add reviewer-attempt ledger citation lint to `script/e2e/verify-artifact`
  for product slices when `reviews/reviewer-attempts.tsv` has stalled, failed,
  superseded, or replaced rows. The final review must cite the ledger path,
  role, status, output path, and replacement reason.
- [x] Have `script/e2e/write-review-packet` generate
  `reviews/reviewer-citation-checklist.tsv` from paths, event ids, timing keys,
  expected chips, edge crops, retry rows, reviewer attempts, and baseline
  citations so reviewers can repair citation omissions in one pass.
- [x] Validate the cleanup with focused shell syntax, shellcheck,
  `verify-artifact --self-test`, Slice 37 guest self-test, review lint against
  the accepted Slice 37 run, and the pre-Tart check suite.
- [x] Keep the Slice 37 product polish note non-blocking: text-heavy onboarding
  demos should keep both event contact sheets and full-size semantic
  screenshots; future product-facing cuts can consider ending with less dense
  final proof once the before/after relationship is established.

### Slice 38: Normal User Readiness Walkthrough

Status: accepted via `artifacts/e2e/slice-38-pre-tart-20260701T075713Z`.

Carry decision: proceed with the dirty Slice 37 and pre-Slice-38 source set as
the Slice 38 candidate instead of committing before recording. This is scoped to
the Tart proof only: the pre-Tart freshness manifest must hash the full dirty
state, the three no-context reviewers must cite that hash, and the accepted
artifact must keep the dirty-baseline logs before closeout.

Attempt lineage and accepted artifact:

- `artifacts/e2e/slice-38-pre-tart-20260701T061609Z` is a blocked pre-Tart
  review run. The process and artifact/product reviewers correctly blocked on
  the missing carry decision. The code-harness reviewer also found two verifier
  gaps: the Slice 38 LaunchAgent plist proof did not require an exact staged
  `WinMuxApp` ProgramArguments entry or matching repo WorkingDirectory, and the
  main `--require-review` closeout path did not call the Slice 38 evidence
  review checks. This run is superseded by the cleanup below.
- `artifacts/e2e/slice-38-pre-tart-20260701T074119Z` reached product media, but
  was replaced after the post-recording verifier found the aggregate
  `slice-38-cli.log` omitted the exact `winmux list-zones --format
  'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'` command header. It is
  formally marked superseded by `075713Z` in `reviews/superseded.md` and
  `logs/run-abort-status.txt`.
- `artifacts/e2e/slice-38-pre-tart-20260701T075713Z` is the accepted run. Its
  pre-Tart freshness manifest hashes the carried dirty candidate, and
  `script/e2e/check-pre-tart-review-gate
  artifacts/e2e/slice-38-pre-tart-20260701T075713Z slice-38` passed after all
  three no-context pre-Tart reports were clean.

Goal: prove the shortest normal path from a fresh WinMux config to usable
ultrawide zones. Slice 37 uses an explicit `--config-path` companion config so
the onboarding artifact can stay isolated. Slice 38 should use the normal user
config path, `~/.config/winmux/winmux.toml`, and show that the README/default
config instructions work without a harness-only launch mode.

User-facing story:

- start from a clean Tart desktop and a fresh generated WinMux config;
- expose the `WINMUX ULTRAWIDE ZONES TEMPLATE` block as the user sees it in
  `~/.config/winmux/winmux.toml`;
- uncomment the block in place;
- launch WinMux normally, without `--config-path` or
  `WINMUX_DEFAULT_CONFIG_PATH`;
- run `winmux config --config-path` to prove the server is using
  `~/.config/winmux/winmux.toml`;
- run `winmux config --check ~/.config/winmux/winmux.toml`. The CLI talks to
  the running server, so this happens after launch in the proof;
- run `winmux list-zones`, `winmux focus-zone Comms`, and
  `winmux move-node-to-zone --focus-follows-window Work` against live windows;
- resize the Work zone with `winmux resize-zone Work width +10%`, then run
  `winmux save-zone-layout --dry-run` so the user sees the saved-layout surface
  without rewriting the config during the proof;
- end with Reference, Work, and Comms visible on the ultrawide display and the
  final caption stating exactly what the user can try next.

Required implementation shape:

- [x] Add `script/e2e/guest/slice-38-user-readiness.sh`.
- [x] Add `make e2e-slice-38`, a Slice 38 recorder action, annotation plan,
  event manifest, verifier branch, reviewer-packet checks, and README harness
  entry.
- [x] Use `script/e2e/guest/recording-timing-helpers.sh` for every visible
  command caption that also writes a command timing row.
- [x] Use the normal config path in the guest. The verifier rejects
  `WinMuxApp --config-path` and `WINMUX_DEFAULT_CONFIG_PATH` in the Slice 38
  LaunchAgent proof.
- [x] Harden debug `WinMuxApp` default-config lookup so the Tart bare executable
  can launch from the repo working directory without `WINMUX_DEFAULT_CONFIG_PATH`.
- [x] Require a visible live window move, not only `list-zones`.
- [x] Require a dry-run save proof and forbid a config hash change during the
  run.
- [x] Require `reviews/reviewer-citation-checklist.tsv` in the reviewer packet for
  the Slice 38 run;
- [x] Require three clean no-context pre-Tart reviewer reports before recording;
- [x] Require a no-context artifact review after recording and before Slice 39 or
  any later slice starts;
- [x] After the artifact review, run three no-context retrospectives and fold their
  accepted findings into pre-Slice-39 cleanup.

Accepted result:

- artifact directory: `artifacts/e2e/slice-38-pre-tart-20260701T075713Z`;
- recording: `recordings/slice-38-user-readiness.mov`;
- raw recording: `recordings/raw/slice-38-user-readiness.raw.mov`;
- media metadata: 3440x1440 H.264, `119.983333s`, 5,217 frames;
- no-context artifact review:
  `reviews/no-ctx-artifact-review.md` (`PASS: Slice 38 proves normal config path
  readiness for the current columnar-zone command surfaces.`,
  `next slice allowed: yes`);
- review lint log: `logs/review-lint.log`;
- post-review verifier log: `logs/post-review-verify.log`;
- closeout log: `logs/closeout-check.log`;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`;
- dirty-baseline inventory:
  `logs/accepted-dirty-baseline.status.txt`,
  `logs/accepted-dirty-baseline.diffstat.txt`,
  `logs/accepted-dirty-baseline.cached-diffstat.txt`, and
  `logs/accepted-dirty-baseline.untracked-sha256.tsv`;
- closeout command:
  `make e2e-slice-closeout-check
  RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-38-pre-tart-20260701T075713Z`
  passed after `074119Z` was marked superseded.

Expected caption chips:

- `Config: ~/.config/winmux/winmux.toml`;
- `Action: uncomment WINMUX ULTRAWIDE ZONES TEMPLATE`;
- `Run: WinMuxApp`;
- `Run: winmux config --config-path`;
- `Run: winmux config --check ~/.config/winmux/winmux.toml`;
- `Run: winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'`;
- `Run: winmux focus-zone Comms`;
- `Action: open TextEdit readiness-move.rtf in Comms`;
- `Run: winmux move-node-to-zone --focus-follows-window Work`;
- `Run: winmux resize-zone Work width +10%`;
- `Run: winmux save-zone-layout --dry-run`;
- `Result: normal config path is ready for Reference | Work | Comms`.

Non-claims:

- Slice 38 does not prove a GUI setup flow;
- Slice 38 does not prove every zone command;
- Slice 38 does not replace the root `demo-columnar-zones.mp4`;
- Slice 38 does not claim the feature is release-ready until its Tart artifact,
  review lint, closeout, and three retrospectives pass.

### Slice 39: Real Dogfood Install and Permissions

Status: accepted via `artifacts/e2e/slice-39-pre-tart-20260701T093003Z`.

Pre-Slice-39 cleanup from Slice 38 retrospectives:

- [x] Correct the Slice 38 accepted artifact path in this plan to
  `artifacts/e2e/slice-38-pre-tart-20260701T075713Z`.
- [x] Mark the replaced media-producing attempt
  `artifacts/e2e/slice-38-pre-tart-20260701T074119Z` superseded by `075713Z`.
- [x] Persist the accepted dirty-baseline inventory in the `075713Z` artifact.
- [x] Persist `review-lint`, post-review verifier, and closeout logs in the
  accepted artifact.
- [x] Verify the prior Slice 37 accepted baseline path is
  `artifacts/e2e/slice-37-starter-onboarding-20260701T045012Z`, not the stale
  non-existent `artifacts/e2e/slice-37-20260701T034141Z`.
- [x] Commit the accepted Slice 37/38 dirty source set before Slice 39.
  Completed by `d91d2819 Close Slice 38 readiness artifact`; the Slice 39
  freshness manifest must start from that clean commit plus the Slice 39 scaffold
  diff.
- [x] Run three no-context pre-slice cleanup reviewers before implementation.
  `artifacts/e2e/pre-slice-39-20260701T084006Z/retrospectives/process-plan.md`,
  `code-harness.md`, and `artifact-product.md` all returned `BLOCKED`; their
  accepted findings are the Slice 39 scaffold checklist below.
- [x] Add the Slice 39 source scaffold before Tart: `make e2e-slice-39`,
  `script/e2e/guest/slice-39-dogfood-install-permissions.sh`, annotation/event
  manifests, pre-Tart gate requirements, reviewer packet instructions, and
  verifier/review-lint checks.
- [x] Keep the Slice 39 visual proof less dense than Slice 38's final board by
  using a dedicated install/permission status board, `winmux doctor`, and a
  compact final result board instead of packing all command output into one
  frame.
- [x] Extend `winmux doctor` to expose install path, executable path, normal
  config path, Accessibility, Screen Recording, Automation/Input Monitoring
  status guidance, and TCC reset commands.
- [x] Run `make e2e-pre-tart-checks` after the scaffold. It passed with shell
  syntax checks, command metadata, `git diff --check`, shellcheck, helper
  self-tests, Slice 39 guest self-test, annotation preflight, warmup policy
  self-test, and 184 focused Swift tests.
- [x] Treat the first Slice 39 pre-Tart artifact/product review as a hard stop.
  `artifacts/e2e/slice-39-pre-tart-20260701T090112Z/reviews/pre-tart/artifact-product.md`
  returned `BLOCKED` because Slice 39 lacked required semantic sample rows and
  `doctor-status` pointed at a screenshot captured before the doctor output was
  visibly rendered.
- [x] Harden the scaffold after that review: add a visible doctor status
  document before `screenshots/03-doctor-status-slice-39.png`, add exact Slice
  39 semantic sample rows for every proof beat, add
  `require_slice_39_sample_manifest`, and update the review packet/prompt to
  reject doctor-status proof that exists only in logs.
- [x] Re-run `make e2e-pre-tart-checks` after the hardening in
  `artifacts/e2e/slice-39-pre-tart-20260701T091349Z/logs/pre-tart-checks.log`;
  it passed shell syntax, command metadata, `git diff --check`, shellcheck,
  helper self-tests, Slice 39 guest self-test, annotation preflight, warmup
  policy self-test, generated-version cleanliness, and 184 focused Swift tests.
- [x] Treat the second fresh pre-Tart review pass as another hard stop.
  `process-plan.md` blocked on direct `script/e2e/tart-recording-harness
  slice-39` bypassing the Makefile pre-Tart review gate, and `code-harness.md`
  blocked on the staged `.app` missing
  `Contents/Resources/default-config.toml`.
- [x] Harden both issues before recording: `script/e2e/tart-recording-harness`
  now runs `script/e2e/check-pre-tart-review-gate` before any VM preflight for
  pre-Tart-gated product slices, with `pre-tart-gate-self-test` in
  `make e2e-pre-tart-checks`; Slice 39 also copies
  `resources/default-config.toml` into the staged app bundle and the verifier
  requires the installed resource path in `logs/slice-39-install.log`.
- [x] Re-run `make e2e-pre-tart-checks` after the direct-gate and bundle-resource
  hardening in
  `artifacts/e2e/slice-39-pre-tart-20260701T093003Z/logs/pre-tart-checks.log`;
  it passed the direct recorder gate self-test, Slice 39 bundle-resource
  self-test, annotation preflight, warmup policy self-test, generated-version
  cleanliness, and 184 focused Swift tests.
- [x] Generate fresh clean pre-Tart no-context reports under the Slice 39 run
  directory. Each report must end with `NO ACTIONABLE ISSUES`, cite the Slice 39
  freshness manifest, and mention every registered Slice 39 source/review
  surface before Tart starts. Completed in
  `artifacts/e2e/slice-39-pre-tart-20260701T093003Z/reviews/pre-tart/`;
  `script/e2e/check-pre-tart-review-gate
  artifacts/e2e/slice-39-pre-tart-20260701T093003Z slice-39` passed before the
  Tart VM started.

Goal: prove WinMux can be installed and launched through the normal dogfood path
on a clean macOS desktop, with required privacy permissions accepted before the
recorded proof begins.

Required scope:

- package or stage the app the same way a dogfood user would run it, rather than
  relying on harness-only `.debug` launch assumptions;
- prove Accessibility, Screen Recording, Automation, and any required helper
  permissions are requested, granted, and recoverable through a documented
  `doctor` or status surface;
- launch WinMux from the packaged app path and show that it reads the normal
  user config path;
- reject recordings that show permission prompts, setup windows, sshd prompts,
  or stale app windows after capture begins;
- end with WinMux running, zones visible, and at least one live focus or move
  command succeeding after relaunch.

Required artifact: a fresh strict guest-captured Tart video with polished action
captions. The video must visibly expose the user commands/actions:

- `Action: install WinMux.app to /Applications`;
- `Action: prepare Accessibility | Screen Recording | Automation before recording`;
- `Run: WinMuxApp from /Applications/WinMux.app`;
- `Run: winmux doctor`;
- `Run: winmux config --config-path`;
- `Run: winmux config --check ~/.config/winmux/winmux.toml`;
- `Run: winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'`;
- `Action: relaunch WinMux from /Applications/WinMux.app`;
- `Run: winmux focus-zone Comms`;
- `Result: dogfood install path is ready`.

Accepted result:

- artifact directory:
  `artifacts/e2e/slice-39-pre-tart-20260701T093003Z`;
- recording: `recordings/slice-39-dogfood-install-permissions.mov`;
- raw recording:
  `recordings/raw/slice-39-dogfood-install-permissions.raw.mov`;
- media metadata: 3440x1440 H.264, `108.000000s`, 4,717 frames;
- no-context artifact review:
  `reviews/no-ctx-artifact-review.md` (`PASS_WITH_NOTES: Slice 39 proves the
  staged dogfood install/status path for /Applications/WinMux.app,
  pre-recording permissions, winmux doctor, the normal config path,
  installed-app relaunch, and winmux focus-zone Comms after relaunch.`,
  `next slice allowed: yes`);
- reviewer attempt ledger: `reviews/reviewer-attempts.tsv` records two stalled
  `artifact-product` attempts followed by the accepted image-attached
  `pass_with_notes` review;
- review lint log: `logs/review-lint.log`;
- post-review verifier log: `logs/post-review-verify.log`;
- closeout log: `logs/closeout-check.log`;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`;
- closeout command:
  `make e2e-slice-closeout-check
  RUN_DIR=/Users/prateek/orca/workspaces/winmux/codex-columns/artifacts/e2e/slice-39-pre-tart-20260701T093003Z`
  passed after the three retrospectives were written.

What the accepted artifact proves:

- the staged dogfood app bundle is installed at `/Applications/WinMux.app`;
- the LaunchAgent runs
  `/Applications/WinMux.app/Contents/MacOS/WinMuxApp` without `--config-path`
  or `WINMUX_DEFAULT_CONFIG_PATH`;
- the staged bundle includes `Contents/Resources/default-config.toml`;
- Accessibility, Screen Recording, Automation, and Input Monitoring are prepared
  before recording, with no permission prompts after capture begins;
- `winmux doctor` visibly reports the installed app identity, normal config
  path, permission status, and TCC reset commands;
- `winmux config --config-path`, `winmux config --check`, and `winmux
  list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}'`
  run against the normal user config path;
- the installed app relaunches from `/Applications/WinMux.app`;
- `winmux focus-zone Comms` succeeds after relaunch.

Accepted retrospective findings:

- the Slice 39 harness and artifact contract fixed both blocked pre-Tart
  attempts before recording;
- future long, text-heavy artifact reviews should start with the reviewer packet
  plus key contact sheets and semantic screenshots, since two text-only
  artifact-product review attempts stalled before the image-attached review
  passed;
- closeout should persist `logs/review-lint.log`, `logs/post-review-verify.log`,
  and `logs/closeout-check.log` for every product slice;
- the Slice 39 contract is duplicated across several shell/verifier/reviewer
  surfaces, so future slices should prefer a small registry or generated review
  skeleton when extending this pattern.

Non-claims:

- Slice 39 does not create the public beta package;
- Slice 39 does not add a setup assistant;
- Slice 39 does not prove every permission recovery path.
- Slice 39 does not prove all command, key-binding, or mouse-gesture coverage.

### Slice 40: Zone Setup Assistant

Status: accepted.

Accepted artifact: `artifacts/e2e/slice-40-pre-tart-20260701T130717Z`.

Primary media:

- `recordings/slice-40-zone-setup-assistant.mov`
- `recordings/raw/slice-40-zone-setup-assistant.raw.mov`

Accepted review and gates:

- `reviews/no-ctx-artifact-review.md`: `PASS_WITH_NOTES` with
  `next slice allowed: yes`;
- `logs/review-lint.log`: review lint passed after the replacement review cited
  the aggregate CLI log;
- `logs/post-review-verify.log`: post-review artifact verification passed with
  `--require-review`;
- `logs/closeout-check.log`: closeout passed with sibling-artifact checking and
  all three retrospectives present.

Accepted evidence:

- the artifact starts from a clean desktop and a normal user config with no
  active `[[zones]]`;
- `winmux zone init --dry-run --preset balanced` previews Reference, Work, and
  Comms without changing the config hash;
- `winmux zone init --preset balanced --write` writes a managed block and
  preserves a backup;
- `winmux config --check ~/.config/winmux/winmux.toml` passes;
- the installed app launches normally from `/Applications/WinMux.app`, without
  `--config-path` or `WINMUX_DEFAULT_CONFIG_PATH`;
- startup trace includes the socket start path, and `list-zones` reports
  Reference, Work, and Comms with workspaces.

Superseded artifact: `artifacts/e2e/slice-40-pre-tart-20260701T121930Z` is
marked superseded by `reviews/superseded.md`. It reached the mutation marker but
failed before completing the storyboard because the app was not serving the
WinMux socket; the accepted `130717Z` run stages `default-config.toml`, launches
normally, and records the startup trace.

Retrospectives:

- `retrospectives/process-plan.md`
- `retrospectives/code-harness.md`
- `retrospectives/artifact-product.md`

Pre-Slice-40 cleanup from Slice 39 retrospectives:

- [x] Persist Slice 39 review lint in
  `artifacts/e2e/slice-39-pre-tart-20260701T093003Z/logs/review-lint.log`.
- [x] Persist Slice 39 post-review verifier output in
  `artifacts/e2e/slice-39-pre-tart-20260701T093003Z/logs/post-review-verify.log`.
- [x] Persist Slice 39 closeout output in
  `artifacts/e2e/slice-39-pre-tart-20260701T093003Z/logs/closeout-check.log`.
- [x] Record all three Slice 39 retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.
- [x] Update this plan with the accepted Slice 39 artifact, review verdict,
  persisted gate logs, closeout command, accepted findings, and non-claims.
- [x] Add a generated review skeleton spike without delaying the setup
  assistant. `script/e2e/write-review-packet` now writes
  `reviews/no-ctx-artifact-review.skeleton.md` from
  `reviews/reviewer-citation-checklist.tsv`, and `script/e2e/README.md`
  documents that the skeleton is a media-first drafting aid, not an accepted
  review.
- [x] Define the Slice 40 pre-Tart storyboard below. The Slice 40 artifact must
  prove setup-assistant behavior visually; Slice 39 install/status proof is
  baseline context only.

Goal: make first-time ultrawide setup possible without hand-editing the large
starter TOML block.

Required scope:

- add a CLI-first setup flow such as `winmux zone init`;
- detect physical monitor geometry and propose zone layouts that fit the active
  ultrawide display;
- support dry-run, backup, overwrite confirmation, and idempotent reruns;
- offer a small preset set: balanced columns, focus-only, comms-open, and
  dashboard;
- write or update `~/.config/winmux/winmux.toml` without destroying unrelated
  user config;
- make generated config pass `winmux config --check` and show the resulting
  zones through `winmux list-zones`.

Required artifact: a fresh Tart video starting from no zone config, running the
setup assistant, launching WinMux, and showing Reference, Work, and Comms.

Required storyboard beats:

- start from a clean desktop and a normal user config with no active
  `[[zones]]`;
- run `winmux zone init --dry-run --preset balanced` and show the proposed
  Reference, Work, and Comms columns without writing the config;
- run `winmux zone init --preset balanced --write` and show the backup path plus
  the inserted TOML block;
- run `winmux config --check ~/.config/winmux/winmux.toml`;
- launch WinMux normally, without `--config-path` or
  `WINMUX_DEFAULT_CONFIG_PATH`;
- run `winmux list-zones --format
  'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}'`;
- finish with live Reference, Work, and Comms zones visible and a concise result
  board that names the setup command the user should run.

Artifact-review requirement: launch the first Slice 40 artifact-product reviewer
with the reviewer packet plus key contact sheets and semantic screenshots, using
the generated `reviews/no-ctx-artifact-review.skeleton.md` as the checklist
starting point instead of waiting for a stalled text-only review path.

Non-claims:

- Slice 40 does not require a GUI setup wizard;
- Slice 40 does not tune every possible monitor size;
- Slice 40 does not replace the default template;
- Slice 40 does not prove every setup preset beyond the balanced starter path;
- Slice 40 does not prove all key bindings, mouse gestures, or cross-zone
  movement.

### Slice 41: Beta-Hardened App and Window Affinities

Status: accepted.

Pre-Slice-41 cleanup from Slice 40 retrospectives:

- [x] Keep the accepted Slice 40 baseline isolated: commit this Slice 40
  source, harness, and plan update before starting Slice 41 pre-Tart freshness.
- [x] Define the Slice 41 storyboard, verifier contract, and reviewer packet
  before recording. It must prove live app/window routing after launch, after
  reload, and after relaunch; it must also show match/no-match explanations and
  hidden or disabled zone target behavior. The exact contract is below.
- [x] Carry the reviewer-ledger lesson forward: for command-board or routing
  slices, the packet and citation checklist must name any aggregate CLI or
  routing log that post-review verification requires.
- [x] Keep `zone init` preset coverage honest: either add all-preset validation
  tests before advertising every preset as supported, or keep public claims
  scoped to the balanced first-run setup path. Slice 41 keeps setup claims scoped
  to the accepted balanced path and does not expand setup-preset docs.
- [x] Fix generated review skeleton ready-screenshot handling when the next
  packet-generator change touches that area; Slice 40 had
  `screenshots/01-zone-init-ready-slice-40.png`, but the skeleton said the ready
  screenshot was not present. `script/e2e/write-review-packet` now recognizes
  `01-*-ready-*.png`, and the Slice 41 skeleton cites
  `01-affinity-ready-slice-41.png`.
- [x] For dense proof-board videos, include native-scale crops or top-safe
  result boards so reviewers can audit the visible text without relying on tiny
  contact-sheet text. Slice 41 verifier/reviewer contract requires native-scale
  proof crops for routing explanation boards.

Goal: make automatic routing to zones dependable enough for dogfood and early
beta users.

Required scope:

- audit current `on-window-detected`, `ZoneBinding`, and runtime binding
  behavior against the entity model;
- support bundle id, app name, title regex, workspace, and zone targets with
  clear precedence;
- make failure and noop behavior explicit, including hidden or disabled zone
  targets;
- add reload and relaunch proof so Slack, Messages, Mail, browser, editor, and
  terminal windows route consistently;
- expose inspection output that explains why a window did or did not match a
  rule.

Required artifact: a fresh Tart video with multiple apps or representative test
windows being routed into zones after launch and after config reload.

Required Slice 41 storyboard:

- start from the accepted Slice 40 first-run setup path or an equivalent normal
  user config generated by `winmux zone init --preset balanced --write`;
- launch WinMux normally from the installed app with no `--config-path` or
  `WINMUX_DEFAULT_CONFIG_PATH`;
- show a config excerpt with at least three `[[zone-affinities]]` rules:
  bundle id to Comms, app-name regex to Reference, and title regex plus
  workspace constraint to Work;
- include `[[zone-bindings]]` for the balanced zones and visibly run
  `winmux apply-zone-bindings` before claiming the title-plus-workspace route,
  so the artifact proves the Work zone is actually on workspace `work`;
- include one no-match rule and one disabled-zone target so the diagnostic
  surface explains both non-routing cases;
- open or simulate representative windows in a visible sequence: browser or
  reference window to Reference, mail or comms window to Comms, editor or work
  window to Work, and a no-match window that stays put;
- run `winmux debug-windows --window-id <id>` or a successor inspection command
  for at least one matched window, one no-match window, and one disabled-zone
  target. The visible board and logs must show matcher terms, failed terms,
  target zone status, and the route command;
- run `winmux reload-config`, update or swap the affinity config, and prove the
  next newly detected matching window follows the reloaded rule;
- relaunch the installed app and prove the same config still routes newly
  detected windows after restart;
- finish with `list-windows --all` and `list-zones` output so routed
  representative windows remain auditable even after relaunch resets active
  zone workspaces.

Required verifier/reviewer contract:

- reject final-state-only proof, hidden config, hidden user actions, or any
  artifact that uses a manual `move-node-to-zone` command during the routing
  proof phase;
- require an aggregate routing log that includes every user-visible command,
  every opened representative window, every `debug-windows` or inspection call,
  and each reload/relaunch boundary;
- require `slice-41-apply-zone-bindings.log` plus
  `slice-41-after-apply-zone-bindings-zones.log` proving
  `Reference=reference`, `Work=work`, and `Comms=comms` before the
  title-plus-workspace Work route;
- require native-scale crops or top-safe boards for dense diagnostic output;
- require explicit checks that a disabled-zone affinity does not silently claim
  success and that the diagnostic output names the target as disabled;
- require a no-context reviewer to compare the recording against the repo-root
  demo/product-site style and the accepted Slice 36-40 artifact language before
  Slice 42 may start.

Current Slice 41 implementation progress:

- [x] Add reusable zone-affinity evaluation that reports matched terms, failed
  terms, target zone status, and route command metadata.
- [x] Add `debug-windows` output for `WinMux.zone-affinities`, including
  matched, no-match, enabled target, disabled target, and unresolved target
  diagnostics.
- [x] Add focused in-process tests for matched affinity inspection, no-match
  field explanations, disabled target inspection, and disabled-target fallthrough
  to the next generic callback.
- [x] Add Slice 41 Tart harness, verifier checks, and reviewer packet checklist
  for the normal-config affinity proof.
- [x] Add focused local validation for the Slice 41 config, affinity
  diagnostics, guest self-test, annotation plan, and pre-Tart gate.
- [x] Run no-context pre-Tart reviews for Slice 41 and persist clean reviewer
  reports before recording.
- [x] Record, review, lint, verify, close out, and run the three retrospective
  subagents for the Slice 41 product artifact.

Accepted artifact: `artifacts/e2e/slice-41-20260701T173400Z`.

Primary media:

- `recordings/slice-41-zone-affinity-beta.mov`
- `recordings/raw/slice-41-zone-affinity-beta.raw.mov`
- `screenshots/06-final-affinity-proof-slice-41.png`
- `screenshots/slice-41-zone-affinity-beta.contact-sheet.jpg`
- `screenshots/slice-41-zone-affinity-beta.event-contact-sheet.jpg`

Accepted review and gates:

- `reviews/no-ctx-artifact-review.md`: `PASS` with
  `next slice allowed: yes`;
- `logs/review-lint.log`: review lint passed;
- `logs/post-review-verify.log`: post-review verification passed with
  `--require-review`;
- `logs/closeout-check.log`: closeout passed with sibling-artifact checking,
  generated-version cleanliness, and all three retrospectives present.

Retrospectives:

- `retrospectives/process-plan.md`
- `retrospectives/code-harness.md`
- `retrospectives/artifact-product.md`

Accepted evidence:

- WinMux launches from the normal user config path, without `--config-path` or
  `WINMUX_DEFAULT_CONFIG_PATH`;
- `[[zone-affinities]]` routes newly detected representative windows by bundle
  id, app-name regex, title regex, and workspace;
- `winmux apply-zone-bindings` runs before the title-plus-workspace route, and
  the binding snapshot proves `Reference=reference`, `Work=work`, and
  `Comms=comms`;
- `debug-windows` exposes `WinMux.zone-affinities` for matched, no-match,
  disabled target, reload, and relaunch cases;
- the proof uses per-beat window logs for placement, then a final unfiltered
  `winmux list-windows --all` plus `winmux list-zones` board as an
  all-workspaces audit;
- `logs/slice-41-final-visual-ready.log` proves the final board was visible
  before `screenshots/06-final-affinity-proof-slice-41.png`;
- `logs/guest-transport-summary.tsv` has no unknown status for required
  successful guest-control phases.

Superseded Slice 41 attempts and lessons:

- `slice-41-20260701T154932Z`: stale workspace setup used
  `$ winmux workspace work`; the accepted proof uses `apply-zone-bindings`;
- `slice-41-20260701T160825Z`: final visible-window audit was too narrow after
  relaunch changed visible workspaces;
- `slice-41-20260701T162103Z`: invalid `list-windows --workspace all`;
- `slice-41-20260701T163119Z`: invalid `list-windows --all --app-bundle-id`;
- `slice-41-20260701T164437Z`: final assertions rechecked early per-beat zone
  placement after later workspace/relaunch effects;
- `slice-41-20260701T165518Z`: no-context review failed because
  `screenshots/06-final-affinity-proof-slice-41.png` showed the earlier ready
  board, not the final `list-windows --all` / `list-zones` board. It is marked
  superseded by the accepted artifact.

Pre-Slice-42 cleanup from Slice 41 retrospectives:

- [x] Add `slice-41-apply-zone-bindings.log` and
  `slice-41-after-apply-zone-bindings-zones.log` to Slice 41 review freshness
  dependencies.
- [x] Fix capture-ready transport summaries so a successful required phase does
  not report `attempt_statuses=unknown`; add a verifier self-test that rejects
  that state.
- [x] Persist Slice 41 `review-lint`, `post-review-verify`, and
  `closeout-check` logs.
- [x] Record all three Slice 41 retrospectives and fold their blocking findings
  into this checklist.
- [x] Update this plan with the accepted Slice 41 artifact, review verdict,
  failed-attempt lineage, closeout evidence, retrospectives, accepted claims,
  and non-claims.
- [x] Isolate the accepted Slice 41 source, harness, prompt, test, and plan
  changes in this closeout commit before starting Slice 42 pre-Tart freshness.
- [x] Before Slice 42 recording, lock the final audit command shape in the plan
  and pre-Tart/reviewer contract: state whether the final audit is visible-only
  or all-workspaces, list the exact command, and identify which per-beat logs
  prove placement before any later reload/workspace side effects. Slice 42 uses
  the contract below: per-beat visible-window logs prove each hide/restore
  transition before later profile changes; the final audit is all-workspaces
  with exact `list-zones` and `list-windows --all` commands.
- [x] For the next dense final-board slice, use the Slice 41 pattern: write the
  board, wait for the expected board title into a readiness log, then capture
  the manifest-listed screenshot. Slice 42 requires
  `logs/slice-42-final-visual-ready.log` before
  `screenshots/06-final-availability-proof-slice-42.png`.

Non-claims:

- Slice 41 does not add ML or historical app placement;
- Slice 41 does not rebind already-open windows automatically;
- Slice 41 does not prove durable tab-group identity;
- Slice 41 does not require persistence for runtime tab-group bindings unless
  the rule is expressed in config;
- Slice 41 does not prove every real app bundle users may configure.

### Slice 42: Zone Availability and Profile Workflows

Status: accepted.

Pre-Slice-42 cleanup from Slice 41 retrospectives and no-context optimization
agents:

- [x] Run the required three no-context pre-slice optimization agents and
  persist their reports under
  `artifacts/e2e/slice-42-pre-slice-cleanup/reviews/process-plan.md`,
  `code-harness.md`, and `artifact-product.md`.
- [x] Decide the profile vocabulary before recording. Slice 42 treats a "zone
  profile" as the ergonomic command alias for a named
  `[[zone-availability-sets]]` entry, not a second state model. The underlying
  source of truth remains `disabledZoneIds` plus `activeAvailabilitySetId`.
- [x] Add thin CLI aliases `use-zone-profile` and `cycle-zone-profile` with
  parser, dispatch, help/description metadata, and focused command tests before
  captions claim profile commands.
- [x] Add Slice 42-specific harness, verifier, reviewer-packet, prompt, and
  pre-Tart review-gate registration before recording.
- [x] Add a Slice 42 guest-script self-test that exercises the command sequence
  and rejects missing parked-workspace restoration evidence without Tart.
- [x] Run three clean no-context pre-Tart reviewer reports against the Slice 42
  candidate after pre-Tart freshness is written and before Tart starts.
  Accepted reports live under
  `artifacts/e2e/slice-42-pre-tart-20260701T210703Z/reviews/pre-tart/`.

Goal: turn zone-level and whole-layout visibility into a clear daily workflow:
for example, Comms available, Mail hidden, Focus Only, and Full Dashboard.

Required scope:

- consolidate `toggle-zone`, `use-zone-availability`,
  `cycle-zone-availability`, and scene behavior into documented profile
  patterns;
- provide ergonomic commands or aliases for switching the focused monitor
  between named availability profiles;
- preserve parked workspaces and restore focus predictably when zones hide and
  reappear;
- show zone-level toggles and whole-layout profile toggles in one scenario;
- make hidden-zone state visible in inspection output and demo captions.

Required artifact: a fresh Tart video toggling one zone, switching a whole
layout profile, restoring the hidden zone, and proving the parked workspace
comes back.

Required Slice 42 storyboard:

- start from the accepted Slice 40 normal setup path or an equivalent normal
  user config with Reference, Work, and Comms zones and three availability
  profiles: `focus-only`, `communications`, and `full-dashboard`;
- show a visible config/profile board that maps profiles to
  `[[zone-availability-sets]]` ids before commands run;
- start with Reference, Work, and Comms visible and live labeled documents in
  each zone;
- run `winmux toggle-zone Comms` or `winmux disable-zone Comms` as the
  zone-level toggle beat, then show Comms hidden, Work expanded, and the Comms
  workspace/window absent from visible windows but still identified in a
  parked-workspace proof board;
- run `winmux enable-zone Comms` or `winmux toggle-zone Comms` to restore the
  hidden zone, and prove the same Comms workspace/window returns to Comms/right;
- run `winmux use-zone-profile focus-only` and show Reference plus Comms hidden
  while Work/main remains available;
- run `winmux use-zone-profile communications` and show Comms/right restored
  while Reference/left remains hidden;
- run `winmux use-zone-profile full-dashboard` and show all zones restored with
  the same Reference, Work, and Comms workspaces;
- finish with a top-safe final board titled
  `Slice 42 availability final audit`, write
  `logs/slice-42-final-visual-ready.log` after that title is visible, then
  capture `screenshots/06-final-availability-proof-slice-42.png`.

Required final audit commands:

- `winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|availability=%{monitor-zone-availability-set-id}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'`;
- `winmux list-windows --all --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'`.

Both final audit commands must appear as ordered segmented command-caption
sequences, with every format fragment visible and legible, not only as text
inside the final board.

Per-beat logs, not the final audit alone, must prove placement and parking:

- ready: all three zones enabled, labeled documents visible, and profile ids
  empty;
- zone-level hidden: Comms disabled, Work expanded, Comms document absent from
  `--workspace visible`, and the parked Comms workspace/window identified;
- zone-level restored: the same Comms workspace/window visible in Comms/right;
- focus-only profile: only Work/main enabled, active profile `focus-only`;
- communications profile: Work/main and Comms/right enabled, active profile
  `communications`, Reference still hidden;
- full-dashboard profile: all three zones restored with active profile
  `full-dashboard`.

Required verifier/reviewer contract:

- reject final-state-only proof, logs-only proof, stale final screenshots, hidden
  commands, hidden profile config, or command captions that use profile wording
  without exact `use-zone-profile` / `cycle-zone-profile` CLI evidence;
- reject proof that uses `move-node-to-zone`, manual workspace reassignment, or
  cleanup commands to manufacture the parked-workspace return;
- require semantic samples and event-manifest rows for ready, zone-toggle
  command, zone-toggle result, explicit restore, focus-only profile command,
  communications/full-dashboard profile commands, and final audit;
- require the no-context reviewer to compare Slice 42 against accepted Slice
  36-41 artifacts and repo-root/product media, and to name the exact media
  frames or native-scale crops used for each state transition;
- require final edge/corner crops that prove no setup windows, permission
  prompts, Terminal clutter, or occluded proof text remain visible.

Non-claims:

- Slice 42 does not replace scenes;
- Slice 42 does not add a visual profile editor.

Accepted Slice 42 result:

- accepted artifact:
  `artifacts/e2e/slice-42-pre-tart-20260701T210703Z`;
- recording:
  `recordings/slice-42-zone-availability-profiles.mov`;
- raw guest capture:
  `recordings/raw/slice-42-zone-availability-profiles.raw.mov`;
- contact sheets:
  `screenshots/slice-42-zone-availability-profiles.contact-sheet.jpg` and
  `screenshots/slice-42-zone-availability-profiles.event-contact-sheet.jpg`;
- final screenshot:
  `screenshots/06-final-availability-proof-slice-42.png`;
- pre-Tart gate:
  `reviews/pre-tart/freshness.env`, `process-plan.md`, `code-harness.md`,
  and `artifact-product.md`, accepted by `check-pre-tart-review-gate`;
- artifact review:
  `reviews/no-ctx-artifact-review.md`, first line
  `PASS: Slice 42 proves zone-level hide/restore plus whole-layout profile switching through zone-profile aliases while preserving parked workspace/window ids.`
  and final line `next slice allowed: yes`;
- persisted verifier logs:
  `logs/review-lint.log`, `logs/post-review-verify.log`, and
  `logs/closeout-check.log`;
- closeout command:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-42-pre-tart-20260701T210703Z`,
  passed;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.

Claims:

- `toggle-zone Comms` hides and restores the Comms zone while preserving the
  same parked workspace/window id;
- `use-zone-profile focus-only`, `communications`, and `full-dashboard` apply
  named `[[zone-availability-sets]]` as ergonomic profile aliases;
- final `list-zones` and `list-windows --all` audits are visible as segmented
  command captions and stored logs.

Superseded Slice 42 attempts:

- `artifacts/e2e/slice-42-pre-tart-20260701T194151Z`: pre-Tart-only, no
  product media or accepted review;
- `artifacts/e2e/slice-42-pre-tart-20260701T195314Z`: pre-Tart-only, no
  product media or accepted review;
- `artifacts/e2e/slice-42-pre-tart-20260701T200032Z`: pre-Tart-only, no
  product media or accepted review;
- `artifacts/e2e/slice-42-pre-tart-20260701T200802Z`: pre-Tart-only, no
  product media or accepted review;
- `artifacts/e2e/slice-42-pre-tart-20260701T203131Z`: failed annotation
  preflight because a final audit caption chip was too long; the accepted run
  splits the command into ordered caption fragments;
- `artifacts/e2e/slice-42-pre-tart-20260701T204550Z`: pre-Tart-only and stale
  after later source changes, no product media or accepted review.

### Slice 43: Mouse Gesture Configurability

Status: accepted via `artifacts/e2e/slice-43-pre-tart-20260701T223610Z`.

Pre-Slice-43 cleanup from Slice 42 retrospectives:

- [x] Persist Slice 42 review lint, post-review verifier, and closeout logs.
- [x] Read all three Slice 42 retrospectives and fold accepted blockers into
  this checklist.
- [x] Record Slice 42 accepted artifact, review verdict, claims, non-claims,
  closeout status, and superseded-attempt lineage in this plan.
- [x] Isolate the accepted Slice 42 source, generated files, harness, prompt,
  config, guest script, and plan updates in this closeout commit before starting
  Slice 43 pre-Tart freshness.
- [x] Resolve command metadata provenance before the next command-heavy slice:
  either restore the real source/generator for generated command help and
  descriptions, or change the headers/docs so they match the maintained-source
  policy.
- [x] Add focused alias parity tests for monitor-scoped `use-zone-profile` /
  `cycle-zone-profile` and restore-memory clearing, or explicitly defer them in
  the Slice 43 notes before pre-Tart freshness.
- [x] Add a cheap duplicate-command-line lint for visible proof boards, or
  document the crop/excerpt requirement before the next text-heavy proof board.

Goal: make mouse-driven zone snapping ergonomic and configurable, especially for
one-handed workflows.

Required scope:

- expose the configured gesture trigger in user-facing config and inspection
  output;
- support freeform drag by default with snap only while the configured modifier,
  button, or gesture is active;
- prove that dragging in freeform mode leaves the window floating where the user
  dropped it;
- prove that the same drag with the configured gesture snaps to the intended
  zone;
- keep the gesture handler routed through the same command or move logic used by
  keyboard workflows.

Required artifact: a fresh Tart drag video with per-beat proof frames,
captions, and manifest rows for freeform no-op and gesture-held snap.

Implementation checklist:

- [x] Add `script/e2e/configs/mouse-gesture-configurability.toml` as the
  Slice 43 fixture with `policy = 'float-unless-snap'`,
  `gesture = 'secondary-button-drag'`, and `target = 'zone'`.
- [x] Add a focused config parser test for the Slice 43 fixture.
- [x] Register `make e2e-slice-43` with the mandatory pre-Tart review gate.
- [x] Add a fresh Slice 43 recording name,
  `slice-43-mouse-gesture-configurability`, instead of reusing Slice 24 or
  Slice 25 media.
- [x] Add Slice 43 event-manifest rows so pickup, path, hover target, release,
  and final placement are all reviewer-visible.
- [x] Extend artifact verification to require the secondary-button input
  evidence, overlay sentinel, semantic samples, timing alignment, and exact
  user-action captions for Slice 43.
- [x] Harden the Slice 43 verifier so secondary-button activation and
  `secondary-button-events` evidence are mandatory, and the annotated video must
  include `Input: secondary button held`.
- [x] Add Slice 43-specific reviewer-packet guidance so no-context artifact
  review must inspect the fresh media, secondary-button input events,
  whole-zone target semantics, and every pickup/path/hover/release/post-state
  beat before accepting the artifact.
- [x] Run focused local checks for the new config, harness, annotation
  preflight, and verifier self-test.
- [x] Run three clean no-context pre-Tart reviewers before any Tart recording.
- [x] Record the fresh Tart video and run artifact review, review lint,
  post-review verifier, closeout, and retrospectives.

Accepted result:

- artifact directory:
  `artifacts/e2e/slice-43-pre-tart-20260701T223610Z`;
- recording:
  `recordings/slice-43-mouse-gesture-configurability.mov`;
- raw guest capture:
  `recordings/raw/slice-43-mouse-gesture-configurability.raw.mov`;
- demo cut:
  `recordings/slice-43-mouse-gesture-configurability.demo.mov`;
- contact sheets:
  `screenshots/slice-43-mouse-gesture-configurability.contact-sheet.jpg` and
  `screenshots/slice-43-mouse-gesture-configurability.event-contact-sheet.jpg`;
- primary drag proof frames:
  `screenshots/02-freeform-pickup-slice-43.png`,
  `screenshots/03-freeform-hover-no-overlay-slice-43.png`,
  `screenshots/05-snap-pickup-slice-43.png`,
  `screenshots/06-snap-path-slice-43.png`, and
  `screenshots/07-snap-hover-comms-slice-43.png`;
- pre-Tart gate:
  `reviews/pre-tart/freshness.env`, `process-plan.md`, `code-harness.md`,
  and `artifact-product.md`, accepted by `check-pre-tart-review-gate`;
- artifact review:
  `reviews/no-ctx-artifact-review.md`, first line
  `PASS_WITH_NOTES: Slice 43 visually proves the configured secondary-button mouse gesture policy, with one nonblocking sidecar note about the snap-release sample path.`
  and final line `next slice allowed: yes`;
- persisted verifier logs:
  `logs/review-lint.log`, `logs/post-review-verify.log`, and
  `logs/closeout-check.log`;
- closeout command:
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-43-pre-tart-20260701T223610Z`,
  passed;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.

Claims:

- ordinary/no-secondary drag of `snap-demo.rtf` visibly picks up and hovers over
  Comms without a whole-zone snap overlay, then leaves the same window id
  floating in Comms/right;
- reset returns the same source window to Work/main tiling before the positive
  gesture proof;
- secondary-button-held drag visibly picks up, travels toward Comms, shows the
  product label `Whole zone: Comms`, releases on the whole Comms zone, and ends
  with the same window id placed in Comms/right;
- `mouse-events.tsv` proves `snap-secondary-button-down`,
  `snap-secondary-button-held`, and `snap-secondary-button-up` around the snap
  pickup, target affordance, release, and post-state;
- the artifact exposes the user-facing config/action captions, including
  `Config: policy='float-unless-snap'; gesture='secondary-button-drag'; target='zone'`
  and `Input: secondary button held`.

Accepted sidecar note:

- The accepted review is `PASS_WITH_NOTES` because `snap-release` has correct
  event timing in the full/raw recording and event manifests, but the generated
  reviewer-facing sample path
  `screenshots/slice-43-mouse-gesture-configurability.samples/caption-07-boundary-start.png`
  starts after the target overlay has cleared. This does not invalidate Slice
  43 because the video and hover/release timing prove the behavior, but it is a
  blocking pre-Slice-44 cleanup item for all future drag/overlay proofs.

Superseded Slice 43 attempts:

- `artifacts/e2e/slice-43-pre-tart-20260701T221322Z`: pre-Tart-only, no
  accepted product media or artifact review;
- `artifacts/e2e/slice-43-pre-tart-20260701T221455Z`: pre-Tart-only and stale
  after later source changes, no accepted product media or artifact review;
- `artifacts/e2e/slice-43-pre-tart-20260701T222830Z`: pre-Tart-only and stale
  after verifier hardening, no accepted product media or artifact review.

Non-claims:

- Slice 43 does not introduce window-slot snap polish;
- Slice 43 does not require every mouse device to expose the same extra buttons.

### Slice 44: Drag Overlay and Snap Semantics Polish

Status: accepted via `artifacts/e2e/slice-44-pre-tart-20260702T003639Z`.

Pre-Slice-44 cleanup from Slice 43 retrospectives:

- [x] Fix release-sidecar generation before any Slice 44 Tart recording:
  drag release rows must point at an event-time release frame that still shows
  the active target preview, not a later caption-boundary sample after the
  overlay has cleared. `slice-12-mouse-zone-snap.sh` now captures
  `08-snap-release-*.png` for whole-zone snap branches, and
  `mouse-drag-events.tsv` expects that frame for fresh whole-zone drag runs.
- [x] Harden `verify-artifact` so future drag artifacts fail when an event row
  such as `snap-release` reuses a sample path whose canonical sample timestamp
  does not match the event timing, unless the manifest declares an explicit
  alias/source-label model. The guard is active for Slice 44+ drag artifacts;
  named accepted pre-sidecar artifacts retain a logged historical exception.
- [x] Add a verifier self-test fixture for the Slice 43 regression: an event
  row at release time pointing to a later `caption-*-boundary-start.png` sample
  must fail.
- [x] Update the Slice 44 reviewer packet/checklist so every drag branch has
  separate required citations for hover target, release-on-active-target, and
  post-drop final placement. The Slice 43 reviewer wording has been corrected as
  carry-forward guidance, and the Slice 44 packet now requires separate
  hover, release-boundary, and final-placement citations.
- [x] Treat overlay sentinel crops as corroboration only; the primary product
  frame must visibly show the target label or target semantics. The Slice 44
  reviewer packet and prompt reject crop-only proof.
- [x] Keep the Slice 43 closeout evidence and `PASS_WITH_NOTES` sidecar note in
  the plan before starting Slice 44 pre-Tart freshness.

Current implementation progress:

- [x] Add `script/e2e/configs/drag-overlay-semantics.toml` and parser coverage
  for the Slice 44 config.
- [x] Add `make e2e-slice-44`, recorder action
  `slice-44-drag-overlay-semantics`, annotation plan, event-manifest rows,
  semantic samples, overlay-sentinel registration, and verifier dispatch.
- [x] Add an explicit slot-noop proof-manifest field:
  `drag-target	slot-noop	whole-zone target; no window-slot target active`.
- [x] Run focused local validation, then generate the pre-Tart freshness
  manifest and three no-context pre-Tart reports before any Tart recording.
- [x] Record the fresh Tart artifact, run no-context artifact review, persist
  review lint and post-review verification, and run three no-context
  retrospectives.

Goal: make drag affordances understandable from the video without reading logs:
what is being dragged, what target will receive it, and whether the target is a
whole zone or a position inside a zone.

Required scope:

- improve overlay labels, hover states, target previews, and cancel behavior;
- make whole-zone targets visually distinct from window-slot targets;
- tune threshold and release behavior so the final placement matches the visible
  preview;
- reject final-placement-only videos; the proof must show pickup, path, hover,
  snap preview, release, and post-release state;
- add verifier checks for target semantics, overlay frames, and distinct
  in-drag screenshots.

Required artifact: a fresh Tart drag video showing at least one whole-zone snap
and an explicit slot-noop. The accepted Slice 27 artifact remains the
window-slot proof; Slice 44 must instead prove that the new whole-zone hover and
release affordances are visually distinct from a window-slot target and
reviewer-visible without reading logs.

Accepted result:

- artifact directory: `artifacts/e2e/slice-44-pre-tart-20260702T003639Z`;
- recording: `recordings/slice-44-drag-overlay-semantics.mov`;
- raw guest capture:
  `recordings/raw/slice-44-drag-overlay-semantics.raw.mov`;
- demo cut: `recordings/slice-44-drag-overlay-semantics.demo.mov`;
- contact sheets:
  `screenshots/slice-44-drag-overlay-semantics.contact-sheet.jpg` and
  `screenshots/slice-44-drag-overlay-semantics.event-contact-sheet.jpg`;
- primary product frames:
  `screenshots/03-freeform-hover-no-overlay-slice-44.png`,
  `screenshots/07-snap-hover-comms-slice-44.png`,
  `screenshots/08-snap-release-slice-44.png`, and
  `screenshots/99-after-slice-44.png`;
- pre-Tart freshness:
  `reviews/pre-tart/freshness.env`, with `candidate_head=4e2fd29708a64bb968c6354b24d72e9eebde0131`;
- pre-Tart no-context reviewers:
  `reviews/pre-tart/process-plan.md`,
  `reviews/pre-tart/code-harness.md`, and
  `reviews/pre-tart/artifact-product.md`, each `Verdict: CLEAN` and ending
  with `NO ACTIONABLE ISSUES`;
- artifact review: `reviews/no-ctx-artifact-review.md`, first line `PASS:`,
  final line `next slice allowed: yes`;
- persisted verifier logs: `logs/review-lint.log`,
  `logs/post-review-verify.log`, and `logs/closeout-check.log`;
- retrospectives: `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.

Accepted claims:

- ordinary drag under `policy='float-unless-snap'` and no secondary button
  floats without a snap overlay;
- secondary-button drag targets the whole Comms zone, not a window slot inside
  that zone;
- hover and release frames show the `Whole zone: Comms` product label on the
  full product frame, with crops and logs used only as corroboration;
- event, mouse, proof, and window-state manifests prove pickup, path, hover,
  release, and post-release state for the ordinary and snap branches.

Superseded Slice 44 attempts:

- `artifacts/e2e/slice-44-pre-tart-20260702T000853Z`: pre-Tart run blocked by
  process-plan review because it attempted to bypass the direct recorder gate;
- `artifacts/e2e/slice-44-pre-tart-20260702T001716Z`: clean pre-Tart run, but
  stale after later Slice 44 commits and no accepted product media.

Non-claims:

- Slice 44 does not change the core layout model;
- Slice 44 does not require animation polish beyond clear product affordances;
- Slice 44 does not claim persistence, settings UI coverage, or generic slot
  snapping.

### Slice 45: Multi-Monitor, Hotplug, and Sleep/Wake Hardening

Status: accepted.

Pre-Slice-45 cleanup from Slice 44 retrospectives:

- [x] Mark Slice 44 accepted in this plan and record the accepted artifact,
  review, verifier, retrospective, claim, and non-claim evidence above.
- [x] Run `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-44-pre-tart-20260702T003639Z`
  after this plan update and tee it to `logs/closeout-check.log`; do not begin
  Slice 45 implementation until it passes.
- [x] Before Slice 45 Tart, update `script/e2e/verify-artifact` so
  `require_mouse_snap_overlay_sentinel` derives source screenshot freshness
  from the recording name or manifest paths instead of a hard-coded case list,
  covering Slice 25, Slice 43, and Slice 44. Add a self-test that touches or
  swaps a source hover screenshot after overlay crops are generated and fails
  unless the overlay crop, labeled crop, and sentinel TSV are fresher than the
  source frames.
- [x] Before Slice 45 reviewer closeout, extend `require_review_freshness` with
  current-recording evidence dependencies when present:
  `logs/${recording_name}.proof-manifest.tsv`,
  `logs/${recording_name}.overlay-sentinel.tsv`,
  `logs/${recording_name}.mouse-events.tsv`,
  `logs/${slice_prefix}-command-timing.log`,
  `logs/${slice_prefix}-mouse-zone-snap-action.log`, and the before/freeform/
  reset/after window logs. Add a review-freshness self-test that writes a
  passing review, touches one proof-manifest field, and expects `--review-lint`
  or `--require-review` check-only verification to fail as stale.
- [x] Before Slice 45 Tart if hotplug, monitor identity, or multi-monitor
  behavior is touched, add a local pre-Tart self-test for overlay crop geometry
  using a synthetic zones log with a non-zero physical monitor origin and a
  generated screenshot. The test should fail until crop code normalizes global
  zone coordinates into the captured display's local coordinate space or
  records/crops from an all-display screenshot. If Slice 45 remains
  single-display, state hotplug/multi-monitor behavior as a non-claim in the
  plan and reviewer packet.
  Done as a verifier guard: overlay sentinel crop geometry must fit inside the
  cited source screenshot, and the self-test rejects a non-zero-origin global
  crop against a display-local source. Slice 45 Tart must therefore emit
  display-local crop coordinates or cite all-display source screenshots before
  the artifact can pass.
- Validation after this cleanup:
  `bash -n script/e2e/verify-artifact`,
  `./script/e2e/verify-artifact --self-test`,
  `./script/e2e/verify-artifact --check-only --require-review artifacts/e2e/slice-43-pre-tart-20260701T223610Z`,
  and
  `./script/e2e/verify-artifact --check-only --require-review artifacts/e2e/slice-44-pre-tart-20260702T003639Z`
  all passed. `make e2e-pre-tart-checks` also passed end to end, including
  shellcheck, verifier self-test, guest-script self-tests, CLI build, and the
  filtered 200-test Swift suite. Slice 25 full artifact verification remains
  blocked by historical expected-chip drift/FinderInfo noise outside the
  overlay-sentinel change; the verifier self-test now exercises Slice 25,
  Slice 43, and Slice 44 overlay source lookup directly.
- [x] Define the exact topology transition path before scenario code:
  Tart-simulated display change if available; otherwise deterministic topology
  harness plus real-machine video. Record why the chosen path can prove
  disconnect/reconnect or resolution/id churn.
  Slice 45 will use a deterministic Tart topology harness first: the guest
  records a visible topology board with real `winmux list-zones` and
  `winmux list-windows --all` output for before, simulated-loss, recovery,
  simulated-return/resolution-change, after, and final recoverability beats.
  This proves the recoverability policy, window-zone/workspace state, and no
  offscreen windows in the reproducible Tart pipeline. If Tart cannot perform a
  real display disconnect/reconnect, true hardware hotplug remains a
  supplemental real-machine artifact requirement before claiming real physical
  disconnect/reconnect support.
- [x] Define the topology-event storyboard before implementation. Required
  media: topology-before, display-loss or simulated-loss, recovery-visible,
  display-return or resolution-change, topology-after, and final
  recoverability. Generate `logs/<recording>.topology-event-manifest.tsv` and
  `screenshots/<recording>.topology-contact-sheet.jpg`; the reviewer packet
  must name exact full-frame screenshot paths for every row and reject
  final-state-only or logs-only topology proof.
  Storyboard beats are:
  `topology-before` (`screenshots/02-topology-before-slice-45.png`),
  `simulated-loss` (`screenshots/03-simulated-loss-slice-45.png`),
  `recovery-visible` (`screenshots/04-recovery-visible-slice-45.png`),
  `simulated-return` (`screenshots/05-simulated-return-slice-45.png`),
  `topology-after` (`screenshots/06-topology-after-slice-45.png`), and
  `final-recoverability` (`screenshots/07-final-recoverability-slice-45.png`).
  Each beat must be backed by a topology event manifest row, a full-frame
  screenshot, and visible board text that names physical monitor identity,
  resolution, active zones, active workspaces, and recoverability status.
- [x] Add Slice 45 caption chips before wiring the harness:
  `Config: zones bind to physical monitor; display ids may churn`,
  `Action: disconnect ultrawide`,
  `Result: windows recover on the remaining display`,
  `Action: reconnect ultrawide at 3440x1440`,
  `Run: winmux list-zones --format 'physical=%{monitor-physical-id}|zone=%{monitor-zone-id}|name=%{monitor-zone-name}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}'`,
  `Run: winmux list-windows --all --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'`,
  and `Result: Reference | Work | Comms restored; no offscreen windows`.
- [x] Add a visible topology board or product overlay to the Slice 45 proof
  frames. During before/loss/recovery/return/after beats, the full frame must
  show physical monitor identity, resolution, active zone names, active
  workspaces, and recoverability status. Crops, support logs, and topology logs
  may corroborate only.
  The Slice 45 guest script now writes a visible TextEdit topology board for
  each proof beat with the simulation boundary, full `list-zones` /
  `list-windows` command surfaces, topology log path, zone state, and window
  state.
- [x] The required no-context review question for Slice 45 is: "Could a
  reviewer understand the display topology transition from the video alone
  before reading logs?" The accepted review must answer yes with exact media
  paths.
  The no-context artifact review prompt and generated reviewer packet now make
  video-alone topology comprehension, exact media citations, and the
  deterministic-simulation/non-hardware-hotplug boundary hard requirements.
- [x] Wire the final-media gate so Slice 45 must include a topology contact
  sheet and an event contact sheet that read as a storyboard without opening
  logs.
  The harness now generates
  `logs/slice-45-display-topology-recovery.topology-event-manifest.tsv`,
  `screenshots/slice-45-display-topology-recovery.topology-contact-sheet.jpg`,
  the normal event manifest/contact sheet, and verifier checks that reject
  missing or logs-only topology proof.
- [x] Register `make e2e-slice-45` with the mandatory pre-Tart review gate and
  document the target in the E2E README.
  Follow-up: `script/e2e/check-pre-tart-review-gate` now has an explicit
  Slice 45 required-mentions registry entry and self-test coverage, so the
  first pre-Tart run can write a Slice 45 freshness manifest instead of failing
  as an unregistered slice.
  Follow-up hardening: `script/e2e/tart-recording-harness pre-tart-gate-self-test`
  now probes direct `slice-45` invocation too, so the direct recorder path must
  stop at the no-context pre-Tart gate before Tart preflight when reports are
  absent.
- Local Slice 45 prep validation passed:
  `bash -n script/e2e/tart-recording-harness script/e2e/guest/slice-45-display-topology-recovery.sh script/e2e/verify-artifact script/e2e/write-review-packet`,
  Slice 45 guest `self-test`, `./script/e2e/tart-recording-harness annotation-preflight`,
  `./script/e2e/verify-artifact --self-test`,
  `shellcheck script/e2e/tart-recording-harness script/e2e/guest/slice-45-display-topology-recovery.sh script/e2e/verify-artifact script/e2e/write-review-packet`,
  `swift test --filter MonitorTopologyTest/testZoneWorkspacesSurviveDisplayIdChurnAndResolutionChange`,
  and full `make e2e-pre-tart-checks` including the 201-test focused Swift
  suite.
- Superseded attempt:
  `artifacts/e2e/slice-45-pre-tart-20260702T020808Z` produced media but failed
  `./script/e2e/verify-artifact --check-only` because
  `logs/slice-45-topology-before.log` did not contain the required
  `winmux list-windows --all --format ...` audit. The guest script now keeps
  the visible-window readiness check and then writes the before-state log with
  the full user-facing all-windows command before generating topology logs. The
  run is formally marked superseded by
  `artifacts/e2e/slice-45-pre-tart-20260702T022831Z` in
  `reviews/superseded.md` and `logs/run-abort-status.txt`.

Accepted result:

- artifact directory:
  `artifacts/e2e/slice-45-pre-tart-20260702T022831Z`;
- recording: `recordings/slice-45-display-topology-recovery.mov`;
- raw guest capture:
  `recordings/raw/slice-45-display-topology-recovery.raw.mov`;
- media metadata: H.264, 3440x1440, `99.983333s`, 4,320 frames;
- contact sheets:
  `screenshots/slice-45-display-topology-recovery.contact-sheet.jpg`,
  `screenshots/slice-45-display-topology-recovery.event-contact-sheet.jpg`,
  and
  `screenshots/slice-45-display-topology-recovery.topology-contact-sheet.jpg`;
- topology proof frames:
  `screenshots/02-topology-before-slice-45.png`,
  `screenshots/03-simulated-loss-slice-45.png`,
  `screenshots/04-recovery-visible-slice-45.png`,
  `screenshots/05-simulated-return-slice-45.png`,
  `screenshots/06-topology-after-slice-45.png`, and
  `screenshots/07-final-recoverability-slice-45.png`;
- pre-Tart freshness:
  `reviews/pre-tart/freshness.env`, with
  `candidate_head=083b7ec725cd0176a428a98cc9c4b247be6bb1c5`;
- pre-Tart no-context reviewers:
  `reviews/pre-tart/process-plan.md`,
  `reviews/pre-tart/code-harness.md`, and
  `reviews/pre-tart/artifact-product.md`, each `Verdict: CLEAN` and ending
  with `NO ACTIONABLE ISSUES`;
- artifact review:
  `reviews/no-ctx-artifact-review.md`, first line `PASS: Slice 45 passes as a
  deterministic Tart topology recoverability artifact, with no real physical
  display unplug/replug claim.`, final line `next slice allowed: yes`;
- persisted verifier logs:
  `logs/review-lint.log`, `logs/post-review-verify.log`, and
  `logs/closeout-check.log`;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`, all with `ACTIONABLE FINDINGS` folded
  into pre-Slice-46 cleanup below.

Accepted claims:

- deterministic Tart topology recoverability policy is demonstrated across
  simulated display loss, recovery, simulated return/resolution churn, restored
  topology, and final recoverability;
- the artifact proves the user-facing
  `winmux list-zones --format ...` and
  `winmux list-windows --all --format ...` audit surfaces for the topology
  story;
- the video, event contact sheet, topology contact sheet, proof manifest, and
  per-beat logs make the proof reviewable without accepting logs-only or
  final-state-only evidence;
- the final zones and windows logs show Reference, Work, and Comms restored
  with `slice45-reference-topology.rtf`, `slice45-work-topology.rtf`, and
  `slice45-comms-topology.rtf` in their expected zones.

Accepted retry note:

- `slice-45-run` had one post-recording SSH/askpass transport failure before
  the successful mutating attempt. `logs/slice-45-run.log` shows the failure
  happened before the `winmux-e2e-mutation-started=1` marker, then the retry
  succeeded and produced the visible proof. The accepted artifact review treats
  this as acceptable for Slice 45, but Slice 46 stateful persistence work must
  be stricter about post-recording retries.

Unaccepted Slice 45 sibling runs:

- `artifacts/e2e/slice-45-pre-tart-20260702T015629Z`: pre-Tart-only run with
  `logs/pre-tart-checks.log`; no product media and no superseded marker needed;
- `artifacts/e2e/slice-45-pre-tart-20260702T020436Z`: pre-Tart-only run with
  `reviews/pre-tart/freshness.env` and `logs/pre-tart-checks.log`; no product
  media and no superseded marker needed;
- `artifacts/e2e/slice-45-pre-tart-20260702T020808Z`: media-producing run
  superseded by the accepted rerun after the topology-before
  `list-windows --all --format ...` audit fix; keep
  `reviews/superseded.md` and `logs/run-abort-status.txt`.

Goal: make zones survive realistic external-monitor use.

Required scope:

- handle ultrawide disconnect/reconnect, display id churn, resolution changes,
  clamshell transitions, and laptop-plus-external layouts;
- keep physical monitor identity separate from zone viewport identity;
- prevent windows from being stranded offscreen when a zone or display
  disappears;
- restore zone layout and workspace assignment when the ultrawide returns;
- add diagnostics that show the before and after monitor topology.

Required artifact: a Tart or real-machine recording that simulates or performs a
display topology change and proves windows remain recoverable. If Tart cannot
exercise the hardware transition, the slice must pair a deterministic harness
test with a real-machine video artifact and no-context review.

The reviewer packet must require visible before/action/after media, not
logs-only proof: before topology board, before window placement,
topology-change action, degraded/recovery state, final restored or recoverable
window placement, and final contamination/edge checks. The artifact must include
machine-readable topology logs for each beat: physical display id/name/frame,
zone viewport id/name/frame, active workspace, window id/title/workspace/zone,
and whether any window was recovered from an unavailable or offscreen viewport.
If using a real-machine fallback, preserve a real video artifact with the same
no-context review, review-lint, post-review verifier, and closeout flow as Tart
slices; do not accept screenshots or operator notes as the product proof.

Non-claims:

- Slice 45 does not support arbitrary overlapping rectangle layouts;
- Slice 45 does not promise identical display ids across macOS hardware events;
- Slice 45 does not prove real physical display unplug/replug, sleep/wake, or
  clamshell behavior. A supplemental real-machine video with the same review
  and closeout flow is required before making that claim.

Pre-Slice-46 cleanup from Slice 45 retrospectives:

- [x] Mark Slice 45 accepted in this plan and record the accepted artifact,
  review, verifier, retrospective, claim, non-claim, retry, and sibling-run
  evidence above.
- [x] Persist all three Slice 45 retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.
- [x] Rerun
  `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-45-pre-tart-20260702T022831Z`
  after the retrospectives are present and tee it to `logs/closeout-check.log`.
- [x] Before Slice 46 Tart, collapse the persistence/rollback/config-doctor
  artifact contract into one checked contract source. It must enumerate caption
  chips, event ids, proof-manifest keys, screenshots/log paths, final command
  logs, and reviewer packet requirements. Generate or mechanically compare the
  guest-emitted manifests, harness event/sample manifests, verifier required
  rows, and reviewer packet/checklist from that source. Implemented as
  `script/e2e/specs/slice-46-persistence-rollback-doctor.tsv`,
  `script/e2e/check-slice-46-contract`, Slice 46 annotation/event rows in
  `script/e2e/tart-recording-harness`, verifier requirements in
  `script/e2e/verify-artifact`, and reviewer packet requirements in
  `script/e2e/write-review-packet`.
- [x] Before Slice 46 Tart, make stateful proof phases no-retry after recording
  starts unless the harness discards and restarts the recording. Split
  transport probes from mutation commands, require a clean final guest-control
  probe immediately before capture, emit the mutation marker before the first
  save/backup/restore/bad-config write, and fail or restart the artifact if any
  `guest-script-retry-summary.tsv` row has `before_recording=no` and
  `failures>0`. Slice 46 forces a single recorded guest attempt and the verifier
  rejects post-recording guest retry failures.
- [x] Reuse the Slice 45 event-manifest columns and key/value diagnostic log
  style for Slice 46 persistence diagnostics. Add rows/keys for original config
  hash, dry-run hash, saved config hash, backup path, deliberately bad config
  path/hash, config doctor result, rollback result, restored config hash,
  relaunch loaded saved layout, and no user config deletion. The Slice 46 guest
  script emits `slice-46-proof-manifest.env`, `slice-46-event-manifest.tsv`,
  timing metadata, copied config snapshots, command logs, and final zone/window
  logs for these boundaries.
- [x] Define the Slice 46 Tart storyboard before implementation: save a runtime
  layout, relaunch into the saved layout, introduce a deliberately bad config,
  run `winmux config doctor` or equivalent diagnostics, restore a known-good
  backup, and show the restored layout. The artifact must include exact
  before/save/relaunch/bad-config/doctor/rollback/final media rows, a contact
  sheet, a machine-readable manifest, and command logs for every persisted file
  mutation. Implemented storyboard: original 25/50/25 layout, `resize-zone Work
  width +10%`, `save-zone-layout`, fresh relaunch into 20/60/20, deliberately
  invalid generated config, `winmux doctor`, `config --restore-backup`, final
  relaunch into restored 20/60/20.
- [x] Keep Slice 46 visually less dense than Slice 45: final frame should show
  one active user-facing result board plus, at most, one compact audit board.
  Put full TOML diffs, full doctor output, and full all-windows audits in logs
  or close-up screenshots cited from the reviewer packet. The guest script uses
  compact TextEdit proof boards and moves full config/doctor/window audits into
  cited logs and screenshots.
- [x] Use ordered command/result chips for the user workflow:
  `Run: winmux save-zone-layout`,
  `Result: backup created + config updated`,
  `Run: winmux config --check ~/.config/winmux/winmux.toml`,
  `Result: Config OK`,
  `Run: winmux doctor`,
  `Result: persistence/rollback status OK`, and the rollback/restore command
  plus restored-layout result. The annotation plan includes the corresponding
  save, relaunch, doctor, restore, final list-zones, and no-post-recording-retry
  chips.
- [x] Add Slice 46 proof-manifest boundary rows for deterministic Tart config
  persistence, rollback safety, config doctor status, and any real-machine
  supplemental claim. The review packet must reject wording that upgrades
  deterministic Tart evidence into real hardware, sleep/wake, or physical
  unplug/replug support without a separate reviewed real-machine artifact.
- [x] Keep a clean desktop and visible product anchor in Slice 46. Reference,
  Work, and Comms zones or the relevant sidebar/tab-zone surface must remain
  visible before and after save, rollback, and doctor; the proof board should
  explain the config-safety outcome, not replace the product surface. The guest
  setup stages Reference, Work, and Comms TextEdit anchors before recording and
  keeps the audit board supplemental to the zone surface.

### Slice 46: Persistence, Rollback, and Config Doctor

Status: accepted via `artifacts/e2e/slice-46-pre-tart-20260702T045535Z`.

Goal: make saving and repairing zone layouts safe enough for beta testers.

Required scope:

- promote dry-run save proof into a real save path with backups;
- add restore or rollback behavior for failed writes and bad generated config;
- add `winmux config doctor` or an equivalent command that checks zones, layout
  sums, unknown references, hidden-zone parked workspaces, styles, scenes, and
  affinity targets;
- verify that relaunch uses the saved layout and that a bad save can be
  recovered without deleting user config;
- keep all persisted changes auditable in logs and captions.

Required artifact: a fresh Tart video saving a runtime layout, relaunching into
it, detecting a deliberately bad config, and restoring a known-good backup.

Implemented product surface:

- `winmux config --restore-backup <path>` validates a backup with the same app
  parser, writes a rollback copy of the current config, and restores the backup
  atomically.
- `winmux doctor` now includes a `Config doctor:` section with config path,
  parse status, layout/reference status, and runtime zone overlay rows.
- Local CLI fallback supports `config --check` and `config --restore-backup`
  when the app server is not available.

Implemented Slice 46 artifact/harness surface:

- `script/e2e/guest/slice-46-persistence-rollback-doctor.sh`;
- `script/e2e/specs/slice-46-persistence-rollback-doctor.tsv`;
- `script/e2e/check-slice-46-contract`;
- Slice 46 dispatch, caption plan, event/sample manifests, no-post-recording
  retry gate, and `e2e-slice-46` target;
- verifier and reviewer-packet gates for the proof manifest, command logs,
  screenshots, retry summary, expected chips, and no-context review evidence.

Local validation passed:

- `swift test --filter ZoneCommandTest/testParse`;
- `swift test --filter ZoneCommandTest/testConfigRestoreBackup`;
- `swift test --filter ConfigTest/testRenderConfigDoctorLines`;
- `python3 script/check-command-metadata`;
- `./script/e2e/check-slice-46-contract`;
- `./script/e2e/verify-artifact --self-test`;
- `./script/e2e/tart-recording-harness annotation-preflight`;
- `WINMUX_E2E_ALLOW_INTERNAL_DISK=1 make e2e-pre-tart-checks`.

Accepted Slice 46 result:

- accepted artifact:
  `artifacts/e2e/slice-46-pre-tart-20260702T045535Z`;
- recording:
  `recordings/slice-46-persistence-rollback-doctor.mov`;
- raw recording:
  `recordings/raw/slice-46-persistence-rollback-doctor.raw.mov`;
- media metadata from verifier: H.264, 3440x1440, 119.883333s, 5241 frames;
- contact sheet:
  `screenshots/slice-46-persistence-rollback-doctor.contact-sheet.jpg`;
- event contact sheet:
  `screenshots/slice-46-persistence-rollback-doctor.event-contact-sheet.jpg`;
- pre-Tart gate:
  `logs/pre-tart-checks.log`,
  `reviews/pre-tart/process-plan.md`,
  `reviews/pre-tart/code-harness.md`,
  `reviews/pre-tart/artifact-product.md`, accepted by
  `script/e2e/check-pre-tart-review-gate`;
- accepted no-context artifact review:
  `reviews/no-ctx-artifact-review.md`;
- review lint:
  `logs/review-lint.log`;
- post-review verifier:
  `logs/post-review-verify.log`;
- closeout check:
  `logs/closeout-check.log`;
- retrospectives:
  `retrospectives/process-plan.md`,
  `retrospectives/code-harness.md`,
  `retrospectives/artifact-product.md`.

What the accepted artifact proves:

- `winmux save-zone-layout` persists the resized 20/60/20 zone layout;
- relaunch loads the saved layout after the app is stopped and started;
- `winmux doctor` reports a deliberately bad config with
  `Column widths must sum to 1.0`;
- `winmux config --restore-backup <path>` validates a known-good backup,
  preserves the bad file as a rollback copy, and restores the saved layout;
- the final relaunch loads the restored 20/60/20 layout with Reference, Work,
  and Comms windows still anchored to their zones;
- the recording has no post-recording guest retry, and sibling Slice 46 media
  artifacts are either accepted or marked superseded.

Superseded Slice 46 attempts:

- `artifacts/e2e/slice-46-pre-tart-20260702T040018Z` is superseded by the
  accepted run. Its no-context artifact review failed because restore/final
  frames still showed stale bad-config TextEdit proof.
- `artifacts/e2e/slice-46-pre-tart-20260702T044607Z` is superseded by the
  accepted run. Its recorded guest run failed after mutation when Apple
  Events/TCC denied the TextEdit board assertion; the accepted run replaces that
  with CLI-backed phase-specific proof-board validation.

Non-claims:

- Slice 46 does not add cloud sync or profile sharing;
- Slice 46 does not auto-save every drag unless explicitly configured.

### Slice 47: Product UI and Zone Chrome Polish

Status: accepted and closed out.

Goal: make current zone state readable in normal use without turning WinMux into
a heavy dashboard.

Required scope:

- improve visible current-zone, disabled-zone, active-profile, and active-style
  indicators;
- keep sidebar and overlay styling aligned with existing WinMux demos and
  screenshots;
- ensure labels fit on mobile-size screenshots and ultrawide captures without
  overlap or clipped text;
- prove style cycling changes only chrome, not layout or workspace assignment;
- keep the feature usable from commands and config even if visual chrome is
  disabled.

Required artifact: a fresh Tart video showing focused-zone changes, disabled
zone state, a profile switch, and a style cycle in the same clean desktop.

Pre-slice cleanup:

- [x] Commit the accepted Slice 46 source, harness, artifact metadata, and plan
  closeout boundary before starting Slice 47 code or harness work.
- [x] Before the first Slice 47 Tart run, write a checked Slice 47 artifact
  contract that names the exact beats: focused-zone indicator, disabled-zone
  state, active-profile switch, active-style cycle, and final audit.
- [x] Require Slice 47 event/sample rows and reviewer-packet checks for
  before/action/after visual chrome, including caption-boundary frames before
  each chrome change.
- [x] Add verifier checks that chrome changes do not move windows, change
  layout widths, or change workspace assignment unless the beat explicitly
  claims a profile or availability change.
- [x] Add visual stale-state checks: final screenshots must not show the
  previous profile/style indicator, hidden zones must be visually distinct from
  focused/current zones, and labels must fit without clipping or overlap.
- [x] Register Slice 47 in the pre-Tart review gate and make target before the
  first product recording.

Implemented Slice 47 artifact/harness surface:

- sidebar zone target rows now include enabled/hidden state, focused state,
  active profile id, and style id/color while disabled rows remain visible and
  non-droppable;
- `script/e2e/configs/zone-chrome-polish.toml`;
- `script/e2e/guest/slice-47-zone-chrome-polish.sh`;
- `script/e2e/specs/slice-47-zone-chrome-polish.tsv`;
- `script/e2e/check-slice-47-contract`;
- Slice 47 dispatch, caption plan, event/sample manifests, no-post-recording
  retry gate, and `e2e-slice-47` target;
- Slice 47 verifier proof and review-lint requirements for hidden rows,
  profile/style chrome, stale final-state rejection, stable window ids and
  workspaces, style-only post-profile placement stability, layout stability,
  exact caption chips, event manifest, and no post-recording retries;
- Slice 47 pre-Tart review-gate registration and no-context artifact-review
  prompt hardening.

Local validation before the first Tart attempt:

- `bash -n` for the Slice 47 harness, verifier, reviewer packet, pre-Tart gate,
  contract checker, and guest script;
- `./script/e2e/check-slice-47-contract`;
- Slice 47 guest-script self-test;
- `./script/e2e/check-pre-tart-review-gate --self-test`;
- focused Swift tests for `testParseZoneChromePolishE2EConfig`,
  `testWorkspaceSidebarKeepsDisabledZoneTargetsReadable`, existing sidebar
  zone-target scope cases, and style propagation;
- `./script/e2e/verify-artifact --self-test`;
- `./script/e2e/tart-recording-harness annotation-preflight`;
- `python3 script/check-command-metadata`;
- `git diff --check`;
- `WINMUX_E2E_ALLOW_INTERNAL_DISK=1 make e2e-pre-tart-checks`, including
  shellcheck, Slice 47 contract/self-test, annotation preflight, and 208 focused
  Swift tests.

Corrected invariant local validation:

- The first Slice 47 Tart run correctly exposed an over-strict proof contract:
  hidden Reference/Comms windows may be reported under the remaining enabled
  zone while their sidebar rows are hidden.
- The corrected invariant is stable anchor window ids/workspaces across all
  phases, expected zone placement while zones are enabled, and style-only beats
  preserving the communications-phase placement.
- `bash -n`, `./script/e2e/check-slice-47-contract`, Slice 47 guest-script
  `self-test`, and `./script/e2e/verify-artifact --self-test` passed after this
  correction.

Accepted Slice 47 result:

- accepted artifact:
  `artifacts/e2e/slice-47-pre-tart-20260702T062251Z`;
- recording:
  `recordings/slice-47-zone-chrome-polish.mov`;
- raw recording:
  `recordings/raw/slice-47-zone-chrome-polish.raw.mov`;
- proof:
  `slice-47-zone-chrome-polish-proof.txt`;
- event/contact evidence:
  `screenshots/slice-47-zone-chrome-polish.contact-sheet.jpg`,
  `screenshots/slice-47-zone-chrome-polish.event-contact-sheet.jpg`,
  `logs/slice-47-zone-chrome-polish.event-manifest.tsv`,
  `logs/slice-47-zone-chrome-polish.sample-manifest.tsv`,
  `logs/slice-47-window-stability.tsv`, and
  `logs/slice-47-layout-stability.tsv`;
- pre-Tart validation:
  `logs/pre-tart-checks.log`;
- no-context pre-Tart reviews:
  `reviews/pre-tart/process-plan.md`, `reviews/pre-tart/code-harness.md`, and
  `reviews/pre-tart/artifact-product.md`;
- no-context artifact review:
  `reviews/no-ctx-artifact-review.md`, with `PASS_WITH_NOTES` and
  `next slice allowed: yes`;
- post-review verifier and review lint:
  `make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-47-pre-tart-20260702T062251Z ARGS=--require-review`
  and
  `make e2e-review-lint RUN_DIR=artifacts/e2e/slice-47-pre-tart-20260702T062251Z`;
- closeout:
  `logs/closeout-check.log`;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.

What the accepted artifact proves:

- focused-zone chrome moves between Work, Reference, and Comms without moving
  anchor windows;
- disabled Reference/Comms rows remain visible as Hidden in profile states;
- active profile and active style are visible in product sidebar rows;
- style cycling changes zone chrome only and preserves the communications-phase
  placement;
- anchor window ids and workspace ids stay stable across the run;
- the recording has no post-recording guest retry.

Superseded Slice 47 attempts:

- `artifacts/e2e/slice-47-pre-tart-20260702T055942Z` recorded a post-recording
  failed attempt. It is rejected and must not be accepted as Slice 47 evidence.
  The guest product state was useful diagnosis, but the verifier/reviewer
  contract incorrectly required hidden Reference/Comms windows to stay reported
  in their original zones for every phase.

Non-claims:

- Slice 47 does not build a full GUI editor;
- Slice 47 does not add decorative product marketing screens.

### Slice 48: Support Bundle and Diagnostics

Status: accepted.

Goal: give dogfooders and beta testers a way to report zone bugs with enough
evidence to debug them.

Required scope:

- add a support bundle command for zones, for example
  `winmux doctor zones --support-bundle`;
- collect redacted config, monitor topology, zone runtime overlay, active
  workspaces, permission status, relevant logs, command failures, and recent
  window-routing decisions;
- redact local usernames, window titles when requested, paths outside the
  config/log scope, and app-specific sensitive fields;
- make the bundle inspectable and small enough to attach to an issue;
- include verifier coverage for redaction and required fields.

Required artifact: a fresh Tart video generating a bundle after a zone workflow,
plus stored bundle contents and a no-context review that checks redaction and
debug value.

Pre-slice cleanup from Slice 47 retrospectives:

- [x] Read all three Slice 47 retrospectives and fold accepted findings into
  this checklist.
- [x] Close Slice 47 in this plan with accepted artifact, review, verifier,
  closeout, retrospective, claim, non-claim, and superseded-attempt evidence.
- [x] Run `make e2e-slice-closeout-check RUN_DIR=artifacts/e2e/slice-47-pre-tart-20260702T062251Z`
  with all three retrospectives present and tee it to `logs/closeout-check.log`.
- [x] Before the Slice 48 Tart run, write a checked support-bundle artifact
  contract that names required bundle fields and redaction rules for usernames,
  requested window titles, non-config paths, non-log paths, and app-sensitive
  fields.
- [x] Keep Slice 48 command captions, event manifest, proof file, reviewer
  packet, and verifier in lockstep; any caption wording change must update the
  corresponding manifest and proof expectations before Tart.
- [x] Define the Slice 48 final audit before recording: the closing frame must
  show the generated bundle path, redaction summary, and the command sequence
  needed to reproduce the bundle.
- [x] Treat any Slice 48 post-recording guest retry as a rerun condition, not a
  reviewable artifact.

Implemented local Slice 48 surface before Tart:

- `doctor zones --support-bundle [--output <dir>]` writes an attachable
  redacted directory and refuses non-empty output directories.
- The local test seam drives the public command path through
  `DoctorCommandTest`, including required files and private-field redaction.
- The Slice 48 E2E contract, guest script, annotation plan, event/sample
  manifests, no-post-recording-retry rule, verifier checks, no-context prompt,
  reviewer packet, and pre-Tart review gate are registered together.
- Run-bound pre-Tart checks for `artifacts/e2e/slice-48-20260702T094800Z`
  passed with 211 focused Swift tests plus shellcheck, contract checks, guest
  self-tests, annotation preflight, and generated-version cleanliness.

Accepted Slice 48 artifact:

- run directory: `artifacts/e2e/slice-48-20260702T094800Z`;
- annotated recording:
  `recordings/slice-48-support-bundle-diagnostics.mov`;
- preserved raw recording:
  `recordings/raw/slice-48-support-bundle-diagnostics.raw.mov`;
- stored support bundle:
  `logs/slice-48-zone-support-bundle/`;
- no-context pre-Tart reviews:
  `reviews/pre-tart/process-plan.md`, `reviews/pre-tart/code-harness.md`, and
  `reviews/pre-tart/artifact-product.md`;
- no-context artifact review: `reviews/no-ctx-artifact-review.md`, ending
  `next slice allowed: yes`;
- reviewer-attempt ledger: `reviews/reviewer-attempts.tsv`, including one
  stalled reviewer replaced after no review file existed after two 15-minute
  waits;
- post-review gate logs:
  `logs/review-lint.log` and `logs/post-review-verify.log`;
- closeout log: `logs/closeout-check.log`;
- retrospectives:
  `retrospectives/process-plan.md`, `retrospectives/code-harness.md`, and
  `retrospectives/artifact-product.md`.

What the accepted artifact proves:

- `doctor zones --support-bundle --output <dir>` runs after a zone workflow and
  writes an attachable diagnostics directory;
- the bundle includes manifest, redacted config, config-doctor output,
  permissions, monitor topology, active workspaces, zone runtime overlay,
  affinities, node bindings, routing-decision retention state, command-failure
  retention state, and logs boundary files;
- configured window-title, app-identifier, token, local-username, and
  out-of-scope path canaries are redacted from the stored bundle evidence;
- command chips and proof boards expose the user-facing commands needed to
  reproduce the bundle;
- the accepted run starts from a clean desktop and has no post-recording guest
  retry.

Superseded Slice 48 attempt:

- `artifacts/e2e/slice-48-20260702T090939Z` produced product media and a
  reviewer packet but no accepted artifact review. It is marked superseded by
  `artifacts/e2e/slice-48-20260702T094800Z`, whose replacement no-context
  review, review lint, post-review verifier, closeout, and retrospectives all
  passed.

Non-claims:

- Slice 48 does not upload diagnostics automatically;
- Slice 48 does not collect private app contents;
- Slice 48 does not retain full live window-routing history, crash logs, macOS
  unified logs, or past command-failure history beyond the explicit retention
  boundary files written into the bundle.

### Slice 49: Ultrawide Zones Documentation

Status: planned.

Goal: turn the accepted demos and command surface into docs a dogfood user can
follow without reading this plan.

Required scope:

- rewrite the README quickstart around the shortest ultrawide-zones path;
- add `docs/ultrawide-zones.md` covering install, permissions, setup,
  starter config, keyboard commands, mouse gestures, profiles, app affinities,
  persistence, troubleshooting, and disabling zones;
- add sample configs for balanced, focus-only, comms-open, dashboard, and app
  affinity setups;
- link accepted Slice 36, 37, 38, and later demo artifacts by path and describe
  what each proves;
- include known limitations and a beta support-bundle section.

Required artifact: a documentation-only slice artifact with the reviewed docs
snapshot, snapshot hash, referenced accepted media, verifier commands, and a
no-context docs/product review. Reuse already accepted Tart-derived media unless
the docs introduce a new workflow that lacks video proof.

Pre-slice cleanup from Slice 48 retrospectives:

- [x] Close Slice 48 in this plan with accepted artifact, review, verifier,
  reviewer-attempt lineage, claims, non-claims, and retrospectives.
- [x] Persist Slice 48 `review-lint` and post-review verifier transcripts at
  `logs/review-lint.log` and `logs/post-review-verify.log`.
- [x] Harden `make e2e-slice-closeout-check` so future closeout requires those
  two prior gate logs before the final closeout can pass.
- [x] Mark the earlier Slice 48 media attempt
  `artifacts/e2e/slice-48-20260702T090939Z` as superseded before relying on
  sibling-artifact hygiene.
- [x] Run Slice 48 closeout again and tee it to `logs/closeout-check.log`.
- [ ] Make the Slice 49 review scope explicit before dispatching no-context
  pre-Tart reviewers, including docs snapshot, referenced media, package/docs
  links, reviewer packet, and verifier rules.
- [ ] For new contract checks, prefer semantic validators for dispatch,
  annotation plans, event manifests, retry policy, verifier hooks, and
  reviewer-lint hooks. Keep literal `source-check` rows only for prose prompts
  or exact reviewer text.
- [ ] Centralize the no-post-recording retry policy for future stateful slices
  so the harness, verifier, reviewer packet, and specs read from one contract.
- [ ] Stop guest setup scripts from clobbering retry-wrapper metadata; wrapper
  logs and guest detail logs need separate paths.
- [ ] Add a reusable support-bundle schema and redaction validator covering the
  manifest file list, actual files, TSV headers, redaction markers, sentinel
  leak scan, and `--include-window-titles` behavior.
- [ ] For text-heavy docs or diagnostics artifacts, add a readable visual
  summary sidecar before no-context review starts:
  `screenshots/<recording>.diagnostic-summary.jpg`,
  `logs/<recording>.diagnostic-summary.tsv`, and
  `logs/<recording>.diagnostic-summary.md`.
- [ ] Update reviewer packet and prompt shape for long artifacts: put a
  "Review Critical Path" before the full citation inventory and instruct
  reviewers not to treat tiny contact-sheet text as sole proof for command
  output, redaction status, required-file lists, or final audit claims.
- [ ] Future support demos should show a compact support outcome board in the
  video and leave dense directory listings to logs and native-scale proof
  images.

Non-claims:

- Slice 49 does not create new product behavior;
- Slice 49 does not replace the plan as the implementation source of truth.

### Slice 50: Beta Packaging and Release Candidate

Status: planned.

Goal: produce a reproducible beta package that installs and launches outside the
development harness.

Required scope:

- build the app and CLI from a clean checkout with version metadata;
- package the app, CLI, default config resources, docs links, and any required
  helper files;
- sign and notarize if the repo's current release path supports it; otherwise
  document the unsigned beta install path and the exact macOS warnings testers
  will see;
- verify a downloaded or copied package on a clean guest uses the normal config
  path and passes the Slice 39 permission/status checks;
- write release notes that name supported workflows and known limitations.

Required artifact: a packaging-slice artifact with source provenance, package
hashes, install proof, launch proof, media samples, and no-context review. If
the package reuses an accepted Tart recording for product behavior, the artifact
must still verify package provenance and media hashes.

Non-claims:

- Slice 50 does not imply App Store readiness;
- Slice 50 does not start external beta until Slice 51 passes.

### Slice 51: Beta Acceptance and Dogfood Soak

Status: planned.

Goal: decide whether this fork is ready for daily dogfood and a small beta.

Required scope:

- run one clean acceptance path from fresh install through permissions, setup,
  normal launch, app/window routing, keyboard movement, mouse snapping, profile
  toggle, save, relaunch, support-bundle generation, and uninstall or disable;
- run the same path against the beta package, not a local debug binary;
- dogfood on the actual ultrawide for several working days and log blockers as
  issues or plan follow-ups;
- classify remaining work as dogfood blocker, beta blocker, known limitation, or
  later enhancement;
- update README, docs, release notes, and this plan with the accepted beta
  status.

Required artifact: a beta-readiness artifact with a fresh acceptance recording
or a reviewed set of recordings, support bundle, package hashes, dogfood notes,
issue links or local issue records, no-context artifact review, review lint,
post-review verifier, closeout, and retrospectives.

Non-claims:

- Slice 51 does not mean broad public release;
- Slice 51 does not accept untriaged crashes, permission failures, or config
  corruption as known limitations.

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
- Manual smoke tests during the spike when the feature is still changing quickly.
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

Manual spike checklist:

- run with no zones and verify behavior is unchanged;
- run with `WINMUX_ZONES_SPIKE=1` on an ultrawide;
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
- Stable zone identity is more invasive than the hardcoded spike. Do it before making zones user-facing.
- Sidebar scope types may be more monitor-shaped than they look. Keep the first UX to one physical panel with zone sections.
- Existing command names may make `monitor` and `zone` semantics confusing. Prefer explicit new zone commands rather than changing numeric monitor behavior.
- Freeform rectangles are tempting, but overlap and hit-testing make them a separate feature.

## Milestones

1. Tart harness boots from external SSD-backed storage, captures screenshots, records video, exports artifacts, and passes no-context artifact review.
2. Hardcoded virtual monitor spike works with independent workspaces and has a Tart video plus no-context artifact review.
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
