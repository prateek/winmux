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
- before screenshot: <artifact-dir>/screenshots/<before>.png
- after screenshot: <artifact-dir>/screenshots/<after>.png
- sample manifest, required when the reviewer packet lists one:
  <artifact-dir>/logs/<recording>.sample-manifest.tsv
- copied config: <artifact-dir>/config/winmux.toml
- guest transport summary, required for product-slice acceptance:
  <artifact-dir>/logs/guest-transport-summary.tsv
- relevant logs: <list exact log paths>
- baseline media: demo.mp4, demo2.mp4, demo3.mp4,
  resources/screenshots/winmux-overview.png, resources/screenshots/tab-groups.png
- product surfaces: README.md, https://github.com/zimengxiong/winmux,
  https://macoswm.com/wm/winmux

Write the review to <artifact-dir>/reviews/no-ctx-artifact-review.md.

Required checks:
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
   The primary recording should include legible, restrained demo captions when
   `preflight.log` says `annotate_recording=1`; confirm the captions explain the
   visible action without hiding the windows or making the artifact look generic.
   The captions must also expose the user-facing WinMux config, command, or
   action that corresponds to the visible step, such as `winmux reload-config`,
   `winmux move-node-to-monitor Reference`, or the `[[zones]]` config surface.
   Prefer explicit chips such as `Run: ...`, `Config: ...`, `Edit: ...`, or
   `Action: ...`. When the slice proves a before/action/after transition, inspect
   generated boundary frames such as `caption-NN-boundary-before.png`,
   `caption-NN-boundary-start.png`, and `caption-NN-boundary-end.png`.
4. Verify the logs prove strict guest control for product slices:
   guest control ready, guest privacy setup done, guest clean slate done, guest
   capture readiness succeeded, and guest screencapture produced the recording.
   If `logs/guest-transport-summary.tsv` exists, read it first and use it to
   identify retry counts, failed transport attempts, final results, and whether
   failures happened before recording. Retry noise before recording is not a
   hard failure by itself, but missing final success or semantic proof failure is.
   If annotation is enabled, also verify the annotation log reports success, the
   caption plan exists, and the raw guest capture is preserved under
   `recordings/raw/`.
5. Verify the artifact demonstrates the slice behavior visually without reading
   implementation notes. CLI logs can support the proof, but they cannot be the
   only proof.
6. Compare the artifact's content and style against the baseline media and
   product surfaces. Look for WinMux's existing product language: macOS desktop,
   visible workspace/window-management behavior, tab group/sidebar/intent-zone
   affordances when the slice claims them, restrained presentation, and no
   generic demo clutter.
   For config reload or command-selector slices, compare copied configs against
   preflight source paths and checksums when available. A copied input config
   mutated in place is a hard failure unless the slice notes explicitly call out
   a historical exception.
7. Check that the artifact would make sense to an end user reviewing the feature.
8. State whether the artifact shows a clean start state, action in progress,
   final expected state, visible WinMux/product surface relevant to the slice,
   and logs that correlate with what is visible.

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

Verdict rules:
- Use FAIL for any hard FAIL condition. Do not use PASS_WITH_NOTES for blockers.
- Use PASS_WITH_NOTES only for polish that does not block the next slice.
- Include a line `next slice allowed: yes` or `next slice allowed: no`.
- End the file with exactly one of: PASS, PASS_WITH_NOTES, FAIL.
```
