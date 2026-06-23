# Columnar Zones Plan

Status: proposal
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

Do not start with scenes, visual editing, overlapping rectangles, or automatic app rules. Add those after zones are stable.

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

- named layout presets and scene switching;
- grid or rectangle layouts;
- draggable zone dividers;
- app/window rules that route to zones;
- per-zone sidebar panels;
- visual editor.

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

The verifier must check:

- exactly one recording exists and is playable;
- decoded duration is at least 80% of the requested duration;
- decoded resolution matches the configured ultrawide Tart display unless an override is documented;
- product slices used `require_guest_control=1` and `capture_mode=guest`;
- when `annotate_recording=1`, annotation logs, caption timing, and the preserved raw capture exist;
- guest-control, privacy, clean-slate, capture-readiness, and recording logs show success;
- before/after screenshots exist;
- a contact sheet exists or can be generated;
- when `--require-review` is set, the review exists and ends in `PASS` or `PASS_WITH_NOTES`.

Gate order for every product slice:

1. Run the fast pre-Tart gate.
2. Run the Tart scenario.
3. Run `make e2e-verify-slice RUN_DIR=...`.
4. Locally inspect screenshots and contact sheet for obvious hard failures.
5. Run the no-context artifact review.
6. Run `make e2e-verify-slice RUN_DIR=... ARGS=--require-review`.
7. Run the three no-context retrospection agents.
8. Update this plan with slice result, accepted findings, and the next pre-slice cleanup checklist.
9. Start the next slice only after the checklist is complete.

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
- `list-monitors` should remain physical; add `list-zones` or include a separate zones section in machine-readable output.

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

### Slice 4: Commands and Selectors

Goal: make zones ergonomic without breaking monitor commands.

Add:

- `focus-zone <zone>`
- `move-node-to-zone <zone>`
- `move-workspace-to-zone <workspace> <zone>` if the existing command shape makes this cheap;
- `list-zones` for scripts and debugging;
- JSON output fields that include both physical monitor and zone id where relevant.

Preserve:

- `focus-monitor 1` targets physical monitor 1, focusing its last-focused zone or configured default zone;
- `move-node-to-monitor 1` moves to the last-focused/default zone on physical monitor 1 when zones are configured;
- `.secondary` means the second physical monitor, not the second zone;
- current configs without zones have no behavior change.

For tab groups, make `move-node-to-zone` move the nearest tab group when the focused node is inside a tab group; otherwise move the focused node using the same binding policy as monitor/workspace moves. Do not add zone geometry to `TilingContainer`.

Tart video gate: record `focus-zone`, `move-node-to-zone`, and the compatibility behavior for `focus-monitor 1`.

Artifact review gate: no-context subagent confirms the command workflow is understandable from the recording and stays consistent with WinMux's sidebar/tab/intent-zone positioning before Slice 5 starts.

### Slice 5: Sidebar and Drag UX

Goal: make zones visible and usable from the sidebar.

Work:

- keep one sidebar panel per configured physical monitor;
- add zone sections or a compact zone selector inside the panel;
- show which workspace is active in each zone;
- allow dragging a workspace, window, or tab group to a zone target;
- make sidebar monitor scope models distinguish physical monitor scope from zone viewport scope.

This slice should not add per-zone sidebars. If that becomes useful, add it later behind explicit config with a clear inset policy.

Tart video gate: record the sidebar showing zone/workspace state and at least one drag or move into a zone target.

Artifact review gate: no-context subagent confirms the sidebar zone UX is visible, legible, and consistent with the baseline screenshots before Slice 6 starts.

### Slice 6: Presets, Scenes, and Freeform Layouts

Goal: add the behaviors inspired by StackWM, BentoBox, and BetterStage after the core model is stable.

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
