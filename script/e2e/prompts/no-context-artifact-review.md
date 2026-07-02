# No-Context Artifact Review Prompt

Use this prompt for every slice artifact review. Start the subagent with
`fork_context=false`; do not include implementation history or the author's
explanation.

```text
You are a no-context artifact reviewer for WinMux columnar-zones work. Work in
<repo-root>. Do not assume any prior chat context.

Slice:
- name: <slice-name>
- intended behavior: <one-paragraph behavior>
- artifact directory: <artifact-dir>
- reviewer packet, required for product-slice acceptance:
  <artifact-dir>/reviews/reviewer-packet.md
- recording: <artifact-dir>/recordings/<recording>.mov
- raw recording, when annotation is enabled:
  <artifact-dir>/recordings/raw/<recording>.raw.mov
- trimmed demo cut, when the reviewer packet lists one:
  <artifact-dir>/recordings/<recording>.demo.mov
- before screenshot: <artifact-dir>/screenshots/<before>.png
- after screenshot: <artifact-dir>/screenshots/<after>.png
- sample manifest, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.sample-manifest.tsv
- contact sheet manifest, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.contact-sheet-manifest.tsv
- event manifest, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.event-manifest.tsv
- mouse event timing table, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.mouse-events.tsv
- event contact sheet, required when the reviewer packet lists one:
  <artifact-dir>/screenshots/<recording>.event-contact-sheet.jpg
- topology event manifest, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.topology-event-manifest.tsv
- topology contact sheet, required when the reviewer packet lists one:
  <artifact-dir>/screenshots/<recording>.topology-contact-sheet.jpg
- copied config: <artifact-dir>/config/winmux.toml
- guest transport summary, required for product-slice acceptance:
  <artifact-dir>/logs/guest-transport-summary.tsv
- reviewer attempt ledger, required when the reviewer packet lists it:
  <artifact-dir>/reviews/reviewer-attempts.tsv
- caption tail manifest, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.caption-tail.tsv
- demo cut manifest, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.demo-cut.tsv
- relevant logs: <list exact log paths>
- baseline media: demo.mp4, demo2.mp4, demo3.mp4, demo-columnar-zones.mp4,
  resources/screenshots/winmux-overview.png, resources/screenshots/tab-groups.png
- product surfaces: README.md, https://github.com/zimengxiong/winmux,
  https://macoswm.com/wm/winmux

Write the review to <artifact-dir>/reviews/no-ctx-artifact-review.md.

Required checks:
0a. In the review body, state whether you were launched with no chat history
    (`fork_context=false` or equivalent). If you were given prior implementation
    conversation or cannot tell, FAIL the review.
0. For a product-slice acceptance review, `reviews/reviewer-packet.md` must
   exist. Read it first. Treat it as the filled path/index packet for this
   artifact, but still apply every rule in this prompt. Treat the packet's
   listed media, logs, slice-specific checks, and product-quality floor as
   required criteria for the current slice.
1. Inspect the recording metadata with ffprobe. It must be playable, non-empty,
   guest-captured for product slices, and at least 80% of the requested duration.
2. Inspect the before screenshot. It must show a clean desktop: no Terminal,
   sshd prompt, permission prompt, setup assistant, System Settings, TextEdit,
   Photos, Preview, notification banner, widgets, unrelated windows, or boot/setup
   screen.
3. Inspect the after screenshot and representative frames from the recording.
   Use existing `screenshots/<recording>.samples/*.png` and
   `screenshots/*.contact-sheet.jpg` if present; otherwise generate equivalent
   samples. When `logs/<recording>.sample-manifest.tsv` exists, use it as the
   index of exact proof beats and verify that each referenced frame exists and
   matches the named expected state. Sample the start, about 10%, 25%, 50%,
   75%, and near-end of the recording, plus frames for each caption/action beat
   when captions are present.
   Do not rely only on logs.
   If the reviewer packet lists `logs/<recording>.contact-sheet-manifest.tsv`,
   treat the primary contact sheet as a semantic proof sheet. Confirm the
   manifest rows match visible contact-sheet panels. For drag or snap demos, it
   must include and visibly show the first target affordance, the release beat,
   and the final placement; otherwise FAIL the review.
   The primary recording should include legible, restrained demo captions when
   `preflight.log` says `annotate_recording=1`; confirm the captions explain the
   visible action without hiding the windows or making the artifact look generic.
   The captions must also expose the user-facing WinMux config, command, action,
   or result that corresponds to the visible step, such as
   `winmux reload-config`, `winmux move-node-to-monitor Reference`, or the
   `[[zones]]` config surface. Prefer explicit chips such as `Run: ...`,
   `Config: ...`, `Edit: ...`, `Action: ...`, or `Result: ...`. When the slice
   proves a before/action/after transition, inspect
   generated boundary frames such as `caption-NN-boundary-before.png`,
   `caption-NN-boundary-start.png`, and `caption-NN-boundary-end.png`.
   If the reviewer packet lists expected caption chips, compare those exact
   chips with the visible captions and annotation TSV. Missing or materially
   incomplete command, config, user-action, or result chips are a failure.
   When a `Run:` caption's command output is not visible in the desktop video,
   prefer an adjacent compact `Result:` line in the annotation card. If the
   command is central to the proof and neither output nor a result line is
   visible, treat that as a comprehension failure.
   For mouse gesture proofs, also look for a visible input-state cue in the
   caption card, such as `Input: Alt held` or `Input: secondary button held`.
   Logs may corroborate the input state, but they cannot be the only way a
   viewer understands which gesture was active.
   If the reviewer packet lists final edge/corner crops, inspect them alongside
   the full after screenshot and reject any unrelated or partial setup window at
   a final screen edge.
   Judge whether a new viewer could understand the user action and result from
   the annotated recording alone, before reading logs. If the video relies on
   logs for the core user story, FAIL or PASS_WITH_NOTES according to severity.
   For drag, divider, or snap artifacts, answer this exact question in the
   review body: "Could a reviewer understand target semantics from the video
   alone before reading logs?" Cite the exact media path that proves the answer,
   such as the hover frame, labeled overlay crop, release frame, or semantic
   contact-sheet panel. If target semantics are only understandable from logs,
   FAIL the review.
   If the reviewer packet lists a caption tail manifest, verify that any
   uncaptained tail beyond the allowed hold is explicitly declared intentional
   with a concrete reason and that near-end media/edge crops support the final
   clean-state claim. When that long tail is trim-worthy, the reviewer packet
   must also list `recordings/<recording>.demo.mov` and
   `logs/<recording>.demo-cut.tsv`; absence of both requires an explicit
   accepted exception in the packet.
   If the reviewer packet lists a trimmed demo cut, inspect it as the
   product-facing short version, then still inspect the full primary recording
   for acceptance evidence. The demo cut must not replace the full recording.
   If the reviewer packet lists an event manifest, inspect it. It must split
   action-sensitive proof into named events such as command start/end, drag
   pickup/path/hover/release, first affordance, post-state inspection, and final
   inspection. Match those rows to caption boundary frames, action screenshots,
   semantic samples, and the event contact sheet when present. Reject a
   transition proof that hides all timing behind one vague offset.
   If the reviewer packet lists a mouse event timing table, compare the event
   manifest seconds for drag/hover/release/post-state events against that table;
   do not accept caption-derived timing when guest action timing is available.
4. Verify the logs prove strict guest control for product slices:
   guest control ready, guest privacy setup done, guest clean slate done, guest
   capture readiness succeeded, and guest screencapture produced the recording.
   If `logs/guest-transport-summary.tsv` exists, read it first and use it to
   identify retry counts, per-attempt statuses, compact first/last failure
   reasons, final results, and whether failures happened before recording.
   If `logs/guest-script-retry-summary.tsv` exists, read it separately. Any row
   with `before_recording=no` and a nonzero failure count must be named in the
   review with its phase, log path, attempt statuses, final result, mutation
   metadata when present, and whether it happened before the first visible
   product action. For stateful proof after product mutation, require a
   re-record or explicit evidence that the failed attempt did not mutate the
   proof state.
   Use the linked raw phase logs when a compact reason needs confirmation.
   Retry noise before recording is not a hard failure by itself, but missing
   final success or semantic proof failure is.
   If the reviewer packet lists `reviews/reviewer-attempts.tsv`, inspect it and
   mention stalled, superseded, failed, or replacement reviewer rows. A header-only
   ledger is acceptable for a first clean review attempt.
   If annotation is enabled, also verify the annotation log reports success, the
   caption plan exists, and the raw guest capture is preserved under
   `recordings/raw/`.
5. Verify the artifact demonstrates the slice behavior visually without reading
   implementation notes. CLI logs can support the proof, but they cannot be the
   only proof.
6. Compare the artifact's content and style against the baseline media and
   product surfaces. Name the exact baseline file or product page inspected.
   For columnar-zone demos, include `demo-columnar-zones.mp4` unless the slice
   is explicitly unrelated to zones. When the reviewer packet lists Slice 7
   root-demo screenshots or samples, inspect and cite those paths too. Look for
   WinMux's existing product language: macOS desktop, visible
   workspace/window-management behavior, tab group/sidebar/intent-zone
   affordances when the slice claims them, restrained presentation, and no
   generic demo clutter.
   For config reload or command-selector slices, compare copied configs against
   preflight source paths and checksums when available. A copied input config
   mutated in place is a hard failure unless the slice notes explicitly call out
   a historical exception.
7. Check that the artifact would make sense to an end user reviewing the feature.
8. State whether the artifact shows a clean start state, action in progress,
   final expected state, visible WinMux/product surface relevant to the slice,
   and logs that correlate with what is visible. Name exact media/log files for
   each important predicate; do not rely only on "the video" or "the contact
   sheet" for action-sensitive behavior.

Hard FAIL conditions:
- before screenshot or recording shows Terminal, sshd prompts, permission prompts,
  setup screens, widgets, notification banners, or unrelated windows after capture
  begins;
- recording is missing, too short, corrupt, host-only for a product slice, or not
  inspected through frames/contact sheet/video playback;
- intended behavior is only present in logs and not visible in the media;
- annotation is enabled but the primary recording lacks captions, has illegible
  captions, uses distracting/generic marketing copy, or the overlay hides the
  behavior being demonstrated;
- captions explain what happened but omit the relevant user-facing WinMux
  command/config/action needed to perform it;
- a transition, drag, or command-boundary artifact lists an event manifest but
  the review ignores it, or the manifest collapses command timing, drag timing,
  affordance timing, release, and inspection into one ambiguous event;
- proof uses post-command app automation, AppleScript cleanup, or hidden-node
  closure to hide visual leftovers, unless that cleanup behavior is itself the
  feature being demonstrated;
- live-window slices do not show live managed windows in the claimed zones;
- logs contradict the media, omit strict guest-control proof, or show command
  failures that the scenario silently ignored;
- movement or command-proof slices accept no-op moves without explicitly proving
  the no-op path with a strict flag such as `--fail-if-noop`;
- drag/action-proof slices omit a proof manifest that names the source item,
  target row/zone, snap target semantics, fixed points or exported target
  frames, caption beat, and before/after logs; fixed coordinates are acceptable
  only when the manifest and sampled frames make the mapping auditable;
- drag/action-proof slices do not visibly show the interaction in progress. The
  reviewer must inspect action frames or in-drag screenshots that show source
  pickup, dragged proxy/path, target hover/drop highlight, and release. Do not
  infer these from final placement, logs, or captions alone. The review must
  name the exact inspected media file for each required drag beat;
- a drag/snap artifact lists a contact-sheet manifest but the semantic contact
  sheet omits the target affordance, release, or final placement panels;
- screenshots are blank, not ultrawide when an ultrawide was required, or taken at
  meaningless checkpoints;
- the review cannot compare against the baseline media/product surfaces.

Slice-specific checks:
- Slice 2 must show three live windows in separate configured zones. It may pass
  as geometry/config proof with the sidebar disabled, but the review must state
  that it does not prove sidebar UX, tab groups, or drag affordances.
- Slice 3 must show before/reload/after checkpoints where the same labeled
  windows or workspaces remain attached to the same zone ids after a width/config
  change. Final-state-only media fails.
- Slice 4 must show `focus-zone`, `move-node-to-zone`, and compatibility behavior
  for `focus-monitor 1`; logs alone are not enough.
- Slice 5 must show the sidebar enabled with zone/workspace state and a visible
  drag in progress. The action frames or in-drag screenshots must visibly include
  the source sidebar item, dragged proxy, pointer/path, highlighted Comms zone
  row, hover hold, release/drop, and final placement. The review must state
  whether the UX is snapping to a sidebar zone row or to a window within a zone.
  For the Slice 5 zone proof, the expected answer is: zone row. Final placement
  alone, a too-fast blur, a review without per-beat media filenames, or a
  reviewer assumption that drag happened is a hard failure.
- Slice 6A must show `[[zone-layouts]]` plus `winmux use-zone-layout focus`.
  The proof must show live windows and changed widths while the same windows stay
  bound to their zone ids and workspaces.
- Slice 6B must show `[[zone-scenes]]` plus `winmux use-zone-scene deep-work`.
  The proof must show triage documents before the command and deep-work documents
  after it. Inspect caption-boundary frames around the command and after-state
  captions; final state plus logs is not enough.
- Slice 7 root demo may use a repo-root `.mp4` and a packaging artifact instead
  of a new Tart run, but only if the package log proves the source was an
  accepted strict guest-captured Tart artifact. Inspect the root demo directly
  against the baseline root videos and product surfaces; source-artifact review
  is supporting evidence, not a substitute for watching the root demo.
- Slice 8 must show `[[on-window-detected]]` plus
  `move-node-to-zone Comms --fail-if-noop`. The proof must show Work active with
  no `route-comms.rtf`, then the user action `open -a TextEdit route-comms.rtf`,
  then `route-comms.rtf` in the Comms/right zone. Reject any artifact where the
  recorded proof uses a manual `move-node-to-zone` command to move the routed
  window, or where the routed window is visible before the open-action caption.
- Slice 39 must prove the staged dogfood app identity and permission/status
  surface. The proof must show `/Applications/WinMux.app`, run
  `winmux doctor`, show the normal config path, relaunch the installed app, and
  run `winmux focus-zone Comms` after relaunch. Inspect the LaunchAgent plist,
  install log, permission log, TCC setup log, doctor log, visible doctor status
  text, event manifest, timing log, semantic samples, and screenshots. Reject
  debug-bin launches, missing installed-app TCC rows, a doctor-status sample
  where the video/screenshot does not visibly show the doctor/status surface,
  permission prompts or System Settings windows after capture begins, reviews
  that infer permissions from captions only, dense unreadable status boards, or
  claims about a public beta, GUI setup assistant, every permission recovery
  path, or full command/key/mouse coverage.
- Slice 40 must prove the CLI-first setup assistant from a normal user config
  with no active `[[zones]]`. The proof must show
  `winmux zone init --dry-run --preset balanced`, unchanged config hashes after
  dry-run, `winmux zone init --preset balanced --write`, a real backup path, the
  managed TOML block with Reference/Work/Comms, `winmux config --check
  ~/.config/winmux/winmux.toml`, normal `WinMuxApp` launch with no
  `--config-path` and no `WINMUX_DEFAULT_CONFIG_PATH`, a staged
  `default-config.toml` beside the raw staged `WinMuxApp`,
  `logs/winmux-startup-trace.log` proving `unix socket server started`, and
  `winmux list-zones` with workspace-bearing Reference/left, Work/main, and
  Comms/right rows. Reject manual template-uncommenting proof, README guidance
  that still treats uncommenting as the first path, missing pre-Tart proof from
  `script/e2e/check-zone-init-local-validation --self-test`, missing
  `mutation_started=yes` and `first_mutation_line` for `slice-40-run` in
  `logs/guest-transport-summary.tsv`, missing startup trace, final-state-only
  proof, missing backup evidence, dry-run proof without hash comparison, hidden
  command text, or claims about a GUI setup wizard, zones enabled by default,
  every preset, every monitor size, all commands/key bindings, or mouse
  gestures.
- Slice 18 must show `[[zone-affinities]]` plus a target zone and matcher, not
  generic `[[on-window-detected]]`. The proof must show focused Work/main with
  no `affinity-comms.rtf`, then the user action
  `open -a TextEdit affinity-comms.rtf`, then `affinity-comms.rtf` in the
  Comms/right zone while `focused-work.rtf` remains in Work/main. Reject any
  artifact where the routed window is visible before the open-action caption,
  the proof uses a manual `move-node-to-zone` command during the recording, the
  focused Work window moves instead of the detected window, or the artifact
  claims relaunch persistence, automatic rebinding of already-open windows, or
  durable tab-group identity.
- Slice 10 must show runtime zone availability with
  `disable-zone Comms` and `enable-zone Comms`. The proof must show Reference,
  Work, and Comms visible before the disable command; Comms absent and Work/main
  expanded after disable; then Comms restored with its parked workspace after
  enable. Inspect the hidden-state screenshot, restored-state screenshot,
  caption-boundary frames, and visible window logs. Reject logs-only proof,
  final-restored-state-only proof, a hidden state where Comms still appears as an
  active zone/sidebar target, or a restore where the Comms document comes back in
  the wrong zone.
- Slice 11A must show runtime zone width controls with
  `resize-zone Work width +10%` and `balance-zones`. The proof must show readable
  before geometry, the resize command caption while the old geometry is still
  visible, an after-resize state where Work is visibly wider and sibling zones
  are narrower, the balance command caption while the resized geometry is still
  visible, and an after-balance state where the zones return to equal widths.
  Inspect named before/command/after samples or caption-boundary frames for both
  resize and balance. Numeric geometry must be visible in media or screenshots,
  not only in logs: zone id, enabled state, configured/effective/runtime width,
  left edge, pixel width, active workspace, and runtime override marker. Reject
  logs-only sizing proof, final-state-only proof, subtle/unreadable geometry,
  stale labels, missing before/command/after samples, command captions that omit
  target zone or amount, geometry changes that happen before the command caption,
  and captions that obscure measured zone edges.
- Slice 11B must show runtime zone style controls with
  `set-zone-style Comms urgent` and `set-zone-style Comms calm`. The proof must
  show a readable unstyled Comms zone row before the first command, the urgent
  command caption before the row changes, an after-urgent state where Comms is
  visibly tinted red, the calm command caption before the second change, and an
  after-calm state where the same Comms row and swatch are visibly blue. Inspect named
  before/command/after samples or caption-boundary frames for both style
  commands. The visual change must be on zone chrome or the sidebar zone row,
  including the styled swatch/tint,
  not TextEdit document text, not a layout resize, and not a workspace switch.
  Confirm Reference and Work stay unstyled, and the same windows and active
  workspaces remain in the same zone ids. Reject logs-only style proof,
  final-state-only proof, subtle/unreadable swatch or tint, missing before/command/after
  samples, command captions that omit the target zone or style id, color changes
  that happen before the command caption, and any proof where the reviewer cannot
  tell whether the feature changed style, layout, or workspace binding.
- Slice 19 must show ergonomic runtime zone style cycling with three visible
  executions of `cycle-zone-style Comms urgent calm`. The proof must show a
  readable unstyled Comms zone row before the first command, the first cycle
  command caption before Comms becomes urgent red, the second cycle command
  caption before Comms becomes calm blue, and the third cycle command caption
  before Comms wraps back to urgent red. Inspect named before/command/after
  samples or caption-boundary frames for all three cycle commands. The visual
  change must be on zone chrome or the sidebar zone row, including the styled
  swatch/tint, not TextEdit document text, not a layout resize, and not a
  workspace switch. Confirm Reference and Work stay unstyled, and the same
  windows and active workspaces remain in the same zone ids. Confirm the
  caption/config surface exposes `[[zone-styles]]` and
  `alt-y = 'cycle-zone-style Comms urgent calm'`. Reject logs-only style proof,
  final-state-only proof, any proof that uses `set-zone-style`, missing
  wraparound, subtle/unreadable swatch or tint, command captions that omit the
  target zone or style ids, color changes that happen before the command
  caption, and claims about visual editing, draggable dividers, snap gestures,
  relaunch persistence, or new app/tab-group binding semantics.
- Slice 20 must show runtime mouse snap policy switching with visible
  executions of `set-zone-snap-policy snap-to-zone` and
  `cycle-zone-snap-policy freeform snap-to-zone`. The proof must show config
  `policy = 'freeform'` before the first drag; a first no-modifier desktop drag
  of `snap-demo.rtf` with no whole-zone overlay and no zone move; the
  `set-zone-snap-policy snap-to-zone` command caption before any snap overlay or
  zone move; a second no-modifier desktop drag that shows the pointer/path, a
  whole Comms zone overlay/highlight, release, and final placement in
  Comms/right; and the cycle command returning runtime policy to freeform after
  final placement. Inspect `logs/slice-20-set-zone-snap-policy.log`,
  `logs/slice-20-cycle-zone-snap-policy.log`,
  `logs/slice-20-zone-snap-policy-switch.overlay-sentinel.tsv`, semantic
  samples, `logs/slice-20-command-timing.log`, the optional
  `logs/slice-20-zone-snap-policy-switch.event-manifest.tsv`, and the video
  frames. Inspect the
  `set-policy-command-start` semantic sample and its nearby caption boundary
  frames; reject the artifact if the Comms whole-zone tint, dashed snap
  affordance, or zone move is visible before the exact
  `Run: winmux set-zone-snap-policy snap-to-zone` caption is already visible on
  a clean pre-snap frame. Reject logs-only proof, final-state-only proof, a
  positive drag that relies on a held modifier, missing set/cycle command
  captions, command captions that appear after the visual change, an unclear
  overlay/no-overlay contrast, any target that looks like a window or slot
  inside a zone, or any claim about relaunch persistence or visual settings UI.
- Slice 21 must show ergonomic zone mode V2 keyboard controls with visible
  executions of the exact user-facing key/command pairs: `Alt-Z, S` for
  `cycle-zone-snap-policy freeform snap-to-zone`, `Alt-Z, Tab` for
  `cycle-zone-layout balanced focus`, two `Alt-Z, A` beats for
  `cycle-zone-availability focus-only communications full-dashboard`, and
  `Alt-Z, Y` for `cycle-zone-style current urgent calm`. The proof must show a
  readable Work/main proof board before the sequence that names the exact
  key-to-command mappings, each command caption before the matching state
  change, the ordered action-log sequence `Alt-Z, S`, `Alt-Z, Tab`, two
  `Alt-Z, A` beats, then `Alt-Z, Y`, each binding returning to main mode in
  logs, Work/main widening after layout focus, focus-only hiding Reference and
  Comms, communications restoring Comms/right while Reference remains hidden,
  and Work/current taking urgent `#D3455B`. Inspect
  `logs/slice-21-zone-mode-v2.event-manifest.tsv`,
  `logs/slice-21-zone-mode-v2-action.log`, semantic samples, and the video
  frames. Reject logs-only proof, final-state-only proof, unreadable board text,
  missing user-facing command captions, missing event/sample manifest rows,
  command captions that appear after visual/logged state changes, or any claim
  that Slice 21 proves drag snapping, persistence, or relaunch behavior.
- Slice 22 must show float-unless-snap mouse behavior with two separate
  desktop drags of `snap-demo.rtf`: first no modifier under config
  `policy = 'float-unless-snap'`, then after reset with Alt held. The no-Alt
  drag must visibly pick up and move the source over Comms with no whole-zone
  snap overlay, and `logs/slice-22-windows-after-freeform.log` plus the action
  log must show the same source id as `zone=right`, `layout=floating`, and
  `freeform-result=floating-no-snap`. The reset beat must return the same
  window to Work/main before the Alt-held branch. The Alt-held drag must show
  source pickup, pointer/path, a whole Comms zone overlay/highlight, release,
  and final placement in Comms/right. Inspect
  `logs/slice-22-float-unless-snap.overlay-sentinel.tsv`,
  `logs/slice-22-float-unless-snap.event-manifest.tsv`,
  `logs/slice-22-mouse-zone-snap-action.log`, semantic samples, and the video
  frames. The overlay sentinel must include `target-label` equal to
  `WHOLE ZONE TARGET: COMMS` and a readable labeled target crop path; inspect
  that crop and name its exact file in the review. Confirm captions expose the
  exact user-visible actions and WinMux
  surfaces: `Config: policy='float-unless-snap'; modifier='alt'; target='zone'`,
  `Action: drag snap-demo.rtf with no modifier`,
  `Run: winmux list-windows --monitor all`,
  `Action: reset snap-demo.rtf to Work/main tiling`,
  `Action: hold Alt while dragging snap-demo.rtf`,
  `Action: target = whole Comms zone`, and `Action: release on Comms zone`.
  Reject logs-only proof, final-state-only proof, missing drag affordances, a
  second drag that starts from an already-floating source, runtime
  `set-zone-snap-policy` proof, unclear overlay/no-overlay contrast, any target
  that looks like a window or slot inside a zone, or claims about persistence,
  configurable gestures beyond this drag policy, or visual settings UI.
- Slice 23 must show the same float-unless-snap two-drag workflow as Slice 22,
  but the accepted claim is narrower: during the Alt-held branch, the actual
  product overlay must visibly label the target as `Whole zone: Comms`. Inspect
  the full video around the Alt-held hover, `screenshots/07-snap-hover-comms-slice-23.png`,
  the event contact sheet, and `logs/slice-23-product-snap-overlay-label.event-manifest.tsv`.
  Inspect `logs/slice-23-product-snap-overlay-label.proof-manifest.tsv` and
  require `visual-floor	product-overlay-label	Whole zone: Comms`, then verify the
  media agrees with it. The no-Alt branch must visibly have no snap overlay and
  no product snap label. The overlay sentinel must still include `target-label`
  equal to `WHOLE ZONE TARGET: COMMS` and a readable labeled crop path, but that
  harness-added label is not enough to pass Slice 23. Reject any review that
  accepts logs, proof-manifest text, captions, or harness crops without naming
  the actual product-overlay media where `Whole zone: Comms` is visible.
- Slice 24 must show the secondary-button mouse gesture path with two separate
  desktop drags of `snap-demo.rtf`: first an ordinary drag under config
  `policy = 'float-unless-snap'` and `gesture = 'secondary-button-drag'`, then
  after reset a drag with the secondary mouse button held. The ordinary drag
  must visibly pick up and move the source over Comms with no whole-zone snap
  overlay, and the logs must show the same source id as `zone=right`,
  `layout=floating`, and `freeform-result=floating-no-snap`. The reset beat must
  return the same window to Work/main before the gesture branch. The
  secondary-button branch must show source pickup, pointer/path, the product
  whole-zone overlay labeled `Whole zone: Comms`, release, and final placement
  in Comms/right. Inspect `logs/slice-24-secondary-button-snap.event-manifest.tsv`,
  `logs/slice-24-secondary-button-snap.proof-manifest.tsv`,
  `screenshots/07-snap-hover-comms-slice-24.png`, the event contact sheet,
  semantic samples, and the video frames. Confirm captions expose
  `Config: policy='float-unless-snap'; gesture='secondary-button-drag'; target='zone'`,
  `Action: drag snap-demo.rtf with no secondary button`, and
  `Action: hold secondary button while dragging snap-demo.rtf`. If the proof
  manifest declares `activation-input`, it must be `secondary-button`; if it
  declares `configured-modifier = alt`, treat that as config compatibility, not
  as the positive user action. If the proof manifest declares
  `input-state-evidence=secondary-button-events`, inspect the mouse event timing
  table for `snap-secondary-button-down`,
  `snap-secondary-button-held`, and `snap-secondary-button-up` in the expected
  order around pickup, affordance, release. Reject proof that uses Alt as the
  positive activation, accepts logs without media, lacks drag affordances,
  starts the second drag from an already-floating source, or implies
  snap-to-window/slot behavior.
- Slice 25 must re-prove the Slice 24 secondary-button workflow while also
  proving the hardened artifact shape. Inspect the full recording as acceptance
  evidence and the trimmed `.demo.mov` sidecar as product-facing media. Require
  visible `Input: secondary button held`, compact `Result:` cues for the
  hidden command-output inspections, `logs/<recording>.contact-sheet-manifest.tsv`
  with `snap-hover-comms`, `snap-release`, `snap-final-placement`, and
  `target-zone-crop`, plus `logs/<recording>.demo-cut.tsv` pointing at the full
  and demo recordings. The event manifest, proof manifest, mouse timings, and
  overlay sentinel must still prove whole-zone target semantics. Reject Slice 25
  if any sidecar is stale, missing from the reviewer packet, or used as a
  substitute for inspecting the full acceptance video.
- Slice 26 must show a draggable zone-divider interaction, not a desktop window
  drag, sidebar drag, or mouse snap proof. Inspect the full video plus
  `screenshots/02-divider-hover-slice-26.png`,
  `03-divider-pickup-slice-26.png`, `04-divider-drag-path-slice-26.png`,
  `05-divider-preview-slice-26.png`, `06-divider-release-slice-26.png`, and
  `07-after-divider-resize-slice-26.png`. The review must name the media file
  used for each beat: hover, pickup, drag path, live preview, release, and
  post-release inspection. Inspect the sample manifest when present and cite
  every `semantic` row by label or exact path, including `config-ready` and
  `after-divider-resize`; the machine gate rejects reviews that only cite the
  midpoint caption samples. Inspect
  `logs/slice-26-zone-divider-drag.event-manifest.tsv`,
  `logs/slice-26-zone-divider-drag.mouse-events.tsv`, and
  `logs/slice-26-zone-divider-drag.proof-manifest.tsv`; require separate rows
  for `divider-hover`, `divider-pickup`, `divider-drag-path`,
  `divider-live-preview`, `divider-release`, and `after-divider-resize`, in
  that order. The proof manifest must state `drag-target	snap-target	zone-divider`,
  `divider-policy	target	adjacent-zone-boundary`, and
  `divider-policy	config-persistence	no-config-rewrite`, and it must
  distinguish the real boundary from the click point with
  `divider-points	boundary	...` plus
  `divider-points	hit-band-offset-pixels	8`. Inspect
  `logs/winmux-app.log`; require `zoneDivider.start` and `zoneDivider.commit`,
  and reject if `resize.start ... kind=zoneDivider` appears because that means
  the demo also used native window resizing. Compare
  `logs/slice-26-zones-before.log` and `logs/slice-26-zones-after.log`: Work
  must grow, Comms must shrink, Reference must stay effectively unchanged, and
  Work/Comms must report runtime width override state. Compare
  `logs/slice-26-windows-before.log` and `logs/slice-26-windows-after.log`: the
  same Reference, Work, and Comms window ids must stay attached to the same zone
  ids and workspaces. Reject logs-only proof, final-state-only proof, missing
  pickup/path/preview/release frames, unclear target semantics, any target that
  appears to be a window or slot inside a zone, any config rewrite, and any
  review that accepts without inspecting the actual media.
- Slice 27 must show a desktop window-slot snap target, not a whole-zone target.
  Inspect the full video plus `screenshots/02-ordinary-pickup-slice-27.png`,
  `03-ordinary-hover-no-overlay-slice-27.png`,
  `04-reset-before-window-slot-slice-27.png`, `05-slot-pickup-slice-27.png`,
  `06-slot-path-slice-27.png`, `07-slot-hover-right-slice-27.png`,
  `08-slot-release-slice-27.png`, and `99-after-slice-27.png`. The first drag
  must be ordinary/no-secondary-button inside Work/main, must not show a
  window-slot overlay, and must leave the source as floating in Work/main.
  Treat `08-slot-release-slice-27.png` as the release-boundary frame with the
  active slot affordance still visible, and `99-after-slice-27.png` as the
  separate post-drop placement proof. The second drag must visibly hold the
  secondary button, hover over
  `target-window.rtf`'s right slot, show the actual product label
  `Window slot: Right`, release on that slot, and keep the source and target
  windows in Work/main. Inspect `logs/slice-27-window-slot-snap.proof-manifest.tsv`
  and require `drag-policy	target	window`, `drag-target	snap-target	window-slot`,
  `drag-target	not-snap-target	whole-zone`, `drag-target	window-title	target-window.rtf`,
  `drag-target	window-slot	right`, and `visual-floor	product-overlay-label	Window slot: Right`.
  Inspect `logs/slice-27-window-slot-snap.overlay-sentinel.tsv` and require
  `target-semantics	window-slot`; this is supporting evidence, not a substitute
  for seeing the product overlay in media. Reject any Comms/right final
  placement, whole-zone overlay, Alt-key positive activation, missing release
  frame, logs-only proof, or review that accepts without naming the exact media
  used for ordinary pickup, slot hover, slot release, and final placement.
- Slice 44 must show drag overlay target semantics for a whole-zone snap and an
  explicit no-window-slot path. It must use a fresh
  `slice-44-drag-overlay-semantics` recording, not reused Slice 24, Slice 25,
  Slice 27, or Slice 43 media. The proof must include separate visible media
  citations for ordinary pickup, ordinary no-overlay hover, secondary-button
  pickup/path, product-labeled whole-zone hover, release-boundary frame
  `08-snap-release-slice-44.png`, and final placement
  `99-after-slice-44.png`. Inspect
  `logs/slice-44-drag-overlay-semantics.proof-manifest.tsv` and require
  `drag-target	snap-target	whole-zone`,
  `drag-target	not-snap-target	window-within-zone`,
  `drag-target	slot-noop	whole-zone target; no window-slot target active`,
  and `visual-floor	product-overlay-label	Whole zone: Comms`. Inspect
  `logs/slice-44-drag-overlay-semantics.overlay-sentinel.tsv` as corroboration
  only; crop labels cannot replace full-product hover or release-frame evidence.
  Reject crop-only proof, final-state-only proof, missing hover/release/final
  separation, any product-label claim based only on logs or annotations, any
  active target that appears to be a window slot, and any review that does not
  state whether target semantics are understandable from the video alone.
- Slice 28 must show runtime layout export, not automatic persistence. Inspect
  the full video plus `screenshots/02-before-export-resize-slice-28.png`,
  `03-after-runtime-resize-slice-28.png`, `04-export-output-slice-28.png`,
  `05-config-check-slice-28.png`, and `06-final-state-slice-28.png`. The
  `resize-zone Work width +10%` command must visibly happen before
  `export-zone-layout saved-ultrawide --monitor 1`, and the TOML output must be
  visible in-frame, not only stored in logs. Inspect
  `logs/slice-28-export-zone-layout.toml`; require `[[zone-layouts]]`,
  `id = "saved-ultrawide"`, `default-zone = "main"`, and runtime widths with
  Work/main at `0.6`. Inspect `logs/slice-28-config-check.log` and require
  `Config OK`. Compare `logs/slice-28-config-before.sha256` and
  `logs/slice-28-config-after.sha256`; they must match. Compare
  `logs/slice-28-zones-before.log` and `logs/slice-28-zones-after-resize.log`
  to confirm the export used current effective widths, not stale configured
  widths. Reject logs-only TOML, final-state-only proof, copied config mutation,
  hidden-zone partial export, relaunch persistence claims, and any review that
  accepts without naming the exact media frame or semantic panel showing the
  emitted TOML.
- Slice 11C must show named zone availability sets with
  `use-zone-availability focus-only` and
  `use-zone-availability communications`. The proof must show Reference, Work,
  and Comms visible before the availability command sequence; a styled urgent
  Comms row before side zones are hidden; the focus-only command caption before
  Reference and Comms disappear; an after-focus-only state where Work/main is
  visibly expanded and both side zones are hidden; the communications command
  caption before Comms reappears; and a restored state where Comms/right returns
  beside Work/main while Reference/left remains hidden. Confirm the Comms
  document/window id and workspace return to the right zone, the active
  availability-set labels are visible in logs, and the urgent `#D3455B` swatch is
  visible before hide, during restore, and after restore. Use the color-sentinel
  rows as supporting evidence, but still inspect the media. Distinguish the
  top sidebar `Zones` section from lower parked workspace rows: parked workspace
  rows may remain listed while their zones are unavailable. Reject logs-only
  proof, final-state-only proof, command captions that omit the set id, unclear
  active-set semantics, a restore where Comms returns unstyled or in the wrong
  zone, and any video where the reviewer cannot tell whether the action is a
  named set versus a manual zone toggle.
- Slice 12 must show desktop mouse zone snap policy with `[mouse.zone-snap]`
  configured for a whole-zone target. The proof must include two separate
  visible drag attempts: first a freeform or missing-modifier drag where no snap
  overlay appears and no zone move happens, then a modifier-held drag where the
  target is visibly a whole zone, not a window or slot inside that zone. Inspect
  the exact in-drag media for source pickup, pointer/path, modifier/snap-policy
  caption, whole-zone overlay, target-zone highlight, release, and final
  placement in the target zone's active workspace. The captions must expose the
  relevant user-facing config/action, such as `[mouse.zone-snap]`,
  `policy = 'snap-on-modifier'`, `modifier = 'alt'`, and
  `Action: hold Alt while dragging`. Confirm the source window or tab group is
  the same object before and after the snap. Reject logs-only proof,
  final-state-only proof, a proof that only shows sidebar dragging, a proof
  where the reviewer cannot see whether the snap target is a whole zone versus a
  window/slot, missing freeform negative proof, missing modifier-held positive
  proof, or any review that does not name per-beat media files for the drag.
- Slice 16 must show the same desktop mouse snap workflow, but with mechanical
  affordance proof. It must include `logs/slice-16-mouse-snap-affordance.overlay-sentinel.tsv`
  with `target-semantics` equal to `whole-zone`, freeform and snap target-zone
  crop paths, `target-label` equal to `WHOLE ZONE TARGET: COMMS` when the
  artifact was generated after the labeled-crop gate, and
  `overlay-rmse-normalized` meeting its minimum. Captions must expose the
  end-user action `hold Option while dragging: snap to Comms zone`.
  Reject missing overlay sentinel, a review that does not inspect sentinel
  crops, ambiguous target semantics, snap-to-window/slot claims, logs-only
  proof, or any final-placement-only proof.
- Slice 13 must show a keyboard-led `Alt-Z` zone mode workflow. The proof must
  show `Alt-Z, L`, `Alt-Z, Shift-L`, `Alt-Z, Equal`, `Alt-Z, 0`, and two
  `Alt-Z, T` toggle actions with captions that expose the user-facing config or
  exact command: `focus-zone next`,
  `move-node-to-zone --focus-follows-window next`,
  `resize-zone current width +10%`, `balance-zones`, and
  `toggle-zone current`. Inspect the media and semantic screenshots for a live state board
  that shows Step, Action, Target, Current, Workspace, Window id, Title, Zone,
  Widths, and Checkpoint. `Target` must resolve the relative selectors:
  `main/Work` for focus-next, `right/Comms` for move/resize/toggle, and
  `all-enabled-zones` for balance. Confirm Work Alpha and Work Beta move
  together as one tab group from Work/main to Comms/right, `resize-zone current`
  widens Comms/right, `balance-zones` restores equal widths, and the two
  `toggle-zone current` actions hide then restore Comms/right. Reject stale
  board screenshots, stale TextEdit labels such as `zone: Work` or future-state
  copy, captions that describe restore without naming `toggle-zone current`,
  ambiguous `current` targets, logs-only proof, or any review that does not name
  the exact media inspected for each beat.
- Slice 14 must show workspace zone bindings with `[[zone-bindings]]` and
  `winmux apply-zone-bindings`. The proof must show BEFORE documents visible in
  Reference/left, Work/main, and Comms/right before the command; the
  `Run: winmux apply-zone-bindings` caption while the BEFORE documents are still
  visible or before the BOUND documents appear; and BOUND documents visible in
  the same three zones after the command. Inspect caption-boundary frames around
  the before and command captions, especially the frame immediately before the
  command chip starts. Reject logs-only proof, final-state-only proof, a command
  chip that appears after the BOUND documents are already visible, missing
  `[[zone-bindings]]` config chip, missing `apply-zone-bindings` command chip,
  or any unrelated/partial setup window visible in the final state.
- Slice 15 must show runtime tab-group node binding with
  `bind-node-to-zone`, not workspace `[[zone-bindings]]`. The proof must show
  Work Alpha and Work Beta as one tab group in Work/main before the command,
  `winmux list-zone-bindings --count` showing zero, the
  `Run: winmux bind-node-to-zone Comms` caption while the tab group is still in
  Work/main, the same visible titles still grouped in Comms/right after the
  command, and a `list-zone-bindings` row with node-id,
  node-type=tab-group, title, zone/right, workspace, and monitor. Reject
  logs-only proof, final-state-only proof, a single-window binding proof,
  command-after-move proof, missing tab group evidence, relaunch-persistence
  claims, or any review that does not name exact media for before, command,
  after, and list-inspection beats.
  If internal window ids are not rendered in the video, distinguish visible
  title/tab evidence from log-supported identity evidence instead of claiming
  the ids were visually inspected.
- Slice 17 must show runtime node-binding guardrails and machine-safe
  inspection. Inspect the primary annotated recording first, then use the raw
  recording, contact sheet, semantic sample manifest, caption-boundary frames,
  and final edge crops as supporting evidence. The proof must show a clean
  ready state, visible command/action text, and named semantic samples for
  `ready-guardrails`, `escaped-title-command`, `rebind-command`,
  `disabled-zone-failure`, `missing-unbind-failure`, `stale-prune-command`,
  and `final-empty-count`. Confirm the escaped-title beat shows escaped
  separators such as `escaped\|equals\=guardrail.rtf`; rebind overwrites the
  existing binding while count stays one; disabled-zone and missing-unbind
  commands fail visibly with count remaining zero; stale tab-group membership
  is changed by a visible concrete close command such as
  `winmux close --window-id "$STALE_BETA_ID"` and then pruned to zero; and the
  final count is empty. Captions or the live board must expose copyable
  user-facing commands for the action, not only say what happened. Reject
  logs-only proof, final-state-only proof, hidden command/error text, stale
  live-board content, angle-bracket placeholders in command text, missing
  stale-membership action, no comparison against the root demos/product
  surfaces, or any claim that runtime node bindings survive relaunch.
- Slice 41 must show automatic `[[zone-affinities]]` routing from the normal
  user config path, not a one-off config override. Inspect the primary
  annotated recording first, then the raw recording, contact sheet, semantic
  sample manifest, event manifest, caption-boundary frames, and logs. Require
  `[[zone-bindings]]` in the config, the command chip
  `Run: winmux apply-zone-bindings; open Reference and Work windows`,
  `logs/slice-41-apply-zone-bindings.log`, and
  `logs/slice-41-after-apply-zone-bindings-zones.log` proving
  `Reference=reference`, `Work=work`, and `Comms=comms` before the Work
  title+workspace route is claimed. Reject any artifact that still uses
  `$ winmux workspace work`, launches with `--config-path` or
  `WINMUX_DEFAULT_CONFIG_PATH`, lacks `slice-41-debug-work.log`, omits
  `workspace matched 'work'`, reports `workspace expected 'work'`, uses manual
  `move-node-to-zone` during proof, hides the command chips, or proves only the
  final state after routing has already happened. Require final inspection to
  use `winmux list-windows --all` plus `winmux list-zones`, because
  relaunch can change active zone workspaces while prior routed windows still
  need to remain auditable. Reject `winmux list-windows --all` if it is
  combined with filtering flags such as `--app-bundle-id`, `--pid`,
  `--workspace`, `--monitor`, or `--focused`; that alias is only valid for the
  unfiltered final audit. Do not accept a review that treats the final audit as
  the only proof of earlier app-id, app-name, workspace, no-match, disabled, or
  reload route placement; those zone claims must come from the per-beat logs
  captured when each window opens. Require reviewers to cite the exact media and
  logs they inspected for the app-id, app-name, workspace, no-match, disabled
  target, reload, and relaunch beats.
- Slice 42 must show zone availability profiles from user-facing profile aliases,
  not only the older availability command names. Inspect the primary annotated
  recording first, then the raw recording, contact sheet, semantic sample
  manifest, event manifest, caption-boundary frames, edge crops, and logs.
  Require visible `[[zone-availability-sets]]` config plus exact evidence text:
  `alt-c = 'toggle-zone Comms'`, `alt-f = 'use-zone-profile focus-only'`,
  `alt-m = 'use-zone-profile communications'`,
  `alt-a = 'cycle-zone-profile focus-only communications full-dashboard'`,
  `$ winmux toggle-zone Comms`, `$ winmux use-zone-profile focus-only`,
  `$ winmux use-zone-profile communications`,
  `$ winmux use-zone-profile full-dashboard`,
  the ordered segmented command-caption sequence beginning with
  `Run: winmux list-zones --format`, the ordered segmented command-caption
  sequence beginning with `Run: winmux list-windows --all --format`, the full
  exact `winmux list-zones --format 'zone=%{monitor-zone-id}|name=%{monitor-zone-name}|enabled=%{monitor-zone-enabled}|availability=%{monitor-zone-availability-set-id}|workspace=%{monitor-active-workspace}|left=%{monitor-left}|width=%{monitor-width}|physical=%{monitor-physical-id}'`
  command in the final board/logs, the full exact
  `winmux list-windows --all --format '%{window-id}|%{window-title}|zone=%{monitor-zone-id}|workspace=%{workspace}|monitor=%{monitor-name}'`
  command in the final board/logs,
  `zone=right|name=Comms|enabled=false`, `availability=focus-only`,
  `availability=communications`, `availability=full-dashboard`,
  `manual-move-node-to-zone-during-proof=no`, and
  `Slice 42 availability final audit`. Require event ids `profile-config`,
  `zone-toggle-hidden`, `zone-toggle-restored`, `focus-only-profile`,
  `communications-profile`, `full-dashboard-profile`, `final-audit`, and
  `final-windows-audit`, plus timing keys `toggle-comms-offset-seconds`,
  `restore-comms-offset-seconds`, `focus-only-offset-seconds`,
  `communications-offset-seconds`, `full-dashboard-offset-seconds`,
  `final-zones-audit-offset-seconds`, and
  `final-windows-audit-offset-seconds`. Reject
  final-state-only proof, logs-only proof, generic or unreadable command
  captions, missing any final-audit command fragment, missing parked-workspace
  proof, proof-phase `move-node-to-zone`, or any review that does not discuss
  the same parked window id returning after hide/restore and focus-only profile
  changes. Require reviewers to compare against accepted
  Slice 36-41 artifacts and the repo root/product media before allowing the next
  slice.
- Slice 45 must show display-topology recoverability as a deterministic Tart
  simulation, not a real hardware hotplug claim. Inspect the primary annotated
  recording first, then the raw recording, contact sheet, semantic sample
  manifest, event manifest, topology event manifest, topology contact sheet,
  caption-boundary frames, edge crops, proof manifest, topology logs, and final
  command logs. Require event ids `topology-contract`, `topology-before`,
  `simulated-loss`, `recovery-visible`, `simulated-return`, `topology-after`,
  `final-windows-audit`, and `final-recoverability`, plus topology rows
  `topology-before`, `simulated-loss`, `recovery-visible`,
  `simulated-return`, `topology-after`, and `final-recoverability` with concrete
  full-frame screenshot paths. Require exact non-claim evidence
  `topology-proof	hardware-hotplug-claim	no`,
  `topology-proof	real-machine-supplement-required	yes-before-real-disconnect-claim`,
  `tart_topology_mode=deterministic-simulation`, and
  `hardware_hotplug_claim=no`. Confirm final command logs show the full exact
  formatted `winmux list-zones --format ...` and
  `winmux list-windows --all --format ...` commands, Reference/left, Work/main,
  Comms/right, and the three `slice45-*-topology.rtf` documents restored with no
  offscreen-window claim. Reject final-state-only proof, logs-only topology
  proof, missing topology contact sheet, vague command captions, and any review
  that claims real physical display unplug/replug support without a supplemental
  real-machine artifact.

Verdict rules:
- Use FAIL for any hard FAIL condition. Do not use PASS_WITH_NOTES for blockers.
- Use PASS_WITH_NOTES only for polish that does not block the next slice.
- The first nonblank line must start with exactly one of `PASS:`,
  `PASS_WITH_NOTES:`, or `FAIL:`.
- End the file with the exact lowercase line `next slice allowed: yes` or
  `next slice allowed: no`; do not capitalize this key.
- Do not append another `PASS`, `PASS_WITH_NOTES`, or `FAIL` line after the
  `next slice allowed` line.
```
