# Columnar Zones Plan

Status: slices 0-18 accepted; Slice 19 must start with the Pre-Slice-19 cleanup
items below
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
  instead of losing an empty placeholder before re-enable. The first snap-policy
  implementation lives in config and the mouse drag resolver; it is not yet
  runtime overlay state.
- `InputBinding` exists through command parsing and normal key bindings. Mouse
  sidebar drag to a zone row calls the same move logic. Normal desktop window
  dragging now has initial configured whole-zone snap policy in code and has
  Slice 12 Tart proof.
- `ZoneAvailabilitySet` is implemented. `ZoneSnapPolicy` now has an initial
  config/model seam and fast-tested whole-zone drag resolver for desktop window
  drags into whole-zone targets.
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
- `set-zone-style` changes zone chrome without changing layout or workspace
  binding.
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
- `set-zone-style <zone> <style-id>` changes visible zone chrome without
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
- The current implementation only claims whole-zone snap. Snap-to-window,
  snap-to-slot, and richer one-handed gestures need their own slice, with video
  proof that distinguishes "snap to zone" from "snap within a zone".

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
- draggable zone dividers;
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

The review output goes in the slice artifact directory as `reviews/no-ctx-artifact-review.md` and must end with one of:

- `PASS`: the slice can proceed;
- `PASS_WITH_NOTES`: non-blocking polish notes are recorded;
- `FAIL`: re-record or fix before continuing.

Only `PASS` or `PASS_WITH_NOTES` allows the next slice to start.

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

After each accepted artifact review, run three fresh no-context subagents with `fork_context=false` before starting the next slice. This is a process-quality gate: the agents look backward through the available Codex/Orca session history, the repo diff, the slice artifacts, failed attempts, and durable docs to find preventable failures or cheaper proof paths.

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
- when `--require-review` is set, the review exists and ends in `PASS` or `PASS_WITH_NOTES`.

Gate order for every product slice:

1. Run the fast pre-Tart gate.
2. Run the Tart scenario.
3. Run `make e2e-verify-slice RUN_DIR=...`.
4. Locally inspect screenshots, standard samples, and contact sheet for obvious hard failures.
5. Run the no-context artifact review.
6. Run `make e2e-verify-slice-check RUN_DIR=... ARGS=--require-review` so the
   post-review gate cannot silently regenerate missing packet or sample files.
7. Run the three no-context retrospection agents.
8. Update this plan with slice result, accepted findings, and the next pre-slice cleanup checklist.
9. Start the next slice only after the checklist is complete.

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
