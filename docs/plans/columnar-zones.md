# Columnar Zones Plan

Status: slices 0-11A accepted; pre-Slice-11B cleanup pending
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
- `ZoneScene`: a named macro that applies a zone layout and activates named
  workspaces in named zones.
- `ZoneRuntimeOverlay`: per-physical-monitor runtime state layered over config:
  active layout id, disabled zone ids, parked workspaces, width overrides, style
  overrides, optional active scene id, and later active snap policy.
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
- Later, `use-zone-availability <set-id>` should toggle groups such as
  `focus-only`, `comms-open`, and `mail-open` at the layout level.
- Later, `set-zone-style <zone> <style-id>` should change visible zone chrome
  without changing layout or workspace bindings.

Mouse behavior should be explicit, configurable, and demoable:

- dragging a floating window inside a zone stays freeform by default;
- snap overlays appear only when policy says they should, such as while holding
  a configured modifier;
- the overlay must state whether the drop target is a whole zone or a position
  inside a window/tab group within that zone;
- one-handed mouse workflows should be possible through configurable gestures,
  but gesture recognition must call the same zone commands as keyboard
  bindings.

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

### Future Slice 11B: Zone Style Controls

Goal: add style controls only after Slice 11A proves the runtime overlay model.

Candidate command:

- `set-zone-style [--monitor <monitor-pattern>] <zone> <style-id>`

Style requirements:

- Styles must be config-defined tokens, not arbitrary command-only strings.
- The first visible consumer should be obvious in the artifact, likely the
  sidebar zone row. Do not ship `set-zone-style` if the only proof is logs.
- Fast tests must prove style id resolution, unavailable-zone errors, duplicate
  selector qualification, and that the style id reaches the visible view model.
- The Tart verifier must reject subtle style changes that cannot be seen in the
  recording.

### Future Slice 11C: Availability Sets and Cross-Zone Commands

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
```

Command surface:

- `use-zone-availability [--monitor <monitor-pattern>] <set-id>`
- `cycle-zone-availability [--monitor <monitor-pattern>] <set-id>...`
- keep `toggle-zone`, `enable-zone`, and `disable-zone` for one-off zone-level
  changes.

Required behavior:

- Availability sets apply only to configured zones on the target physical
  monitor.
- At least one zone must remain enabled.
- Hidden zones park their active workspace and restore it when the zone returns.
- Applying an availability set must not change active layout, width overrides,
  style overrides, or workspace bindings except where a hidden zone must be
  parked.
- `list-zones` must show enough state to prove which availability set is active
  and which zones are enabled.

Fast validation before Tart:

- parser and config validation tests for duplicate ids, unknown zone ids, empty
  enabled zone lists, and valid sets;
- command tests for `use-zone-availability`, cycling, unknown ids, duplicate
  selectors, and preservation of parked workspaces;
- topology tests proving width overrides survive availability set changes.

Tart proof:

- show a three-zone layout with Reference, Work, and Comms visible;
- run `winmux use-zone-availability focus-only` while the command caption is
  visible before the state change;
- show Comms/Reference disappear and Work expand;
- run `winmux use-zone-availability communications`;
- show Comms return with the same workspace/window identity;
- reviewer and verifier must reject final-state-only proof, missing command
  captions, logs-only proof, or any recording where the user cannot tell which
  zones are toggled.

### Future Slice 12: Mouse Snap Policy and Gestures

Goal: make mouse interaction deliberate enough for one-handed use on an
ultrawide.

Model the drag policy explicitly:

- `freeform`: moving a floating window inside a zone stays freeform;
- `snap-on-modifier`: dragging does not snap unless the configured modifier is
  held;
- `snap-to-zone`: modifier-held drag previews the target zone and snaps on
  release;
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
