# WinMux Tart E2E Harness

The columnar zones plan requires a Tart video for every slice. This harness owns the VM preflight, screenshot capture, recording, and artifact layout.

Set `TART_HOME` to a directory on the external SSD before running VM actions:

```bash
export TART_HOME=/Volumes/<external-ssd>/tart
make e2e-preflight
make e2e-smoke
```

Artifacts are written under `artifacts/e2e/slice-N-<timestamp>/` with screenshots, recordings, logs, and the config used for the run.

Product recordings are post-produced by default. The final `recordings/<name>.mov` is the reviewed video and includes a restrained lower-third caption overlay that explains the visible action and shows the WinMux config, CLI command, or action a user would use to perform it. The untouched guest capture is kept under `recordings/raw/<name>.raw.mov`, with caption timing in `logs/<name>.annotations.tsv` and render proof in `logs/<name>.annotation.log`. The harness also writes standard timeline samples, caption samples, and caption-boundary frames under `screenshots/<name>.samples/`, plus a six-up contact sheet at `screenshots/<name>.contact-sheet.jpg`. Set `WINMUX_E2E_ANNOTATE_RECORDING=0` only for local capture debugging.

If a no-context review rejects caption wording but the raw guest capture is
otherwise valid, refresh the annotated artifact without booting Tart again:

```bash
WINMUX_E2E_RUN_DIR=artifacts/e2e/slice-N-<timestamp> \
  ./script/e2e/tart-recording-harness refresh-annotation-artifact
```

Set `WINMUX_E2E_RECORDING_NAME=<name>` when the artifact has more than one raw
recording. The refresh rewrites the caption plan from source, re-renders the
primary recording from `recordings/raw/<name>.raw.mov`, regenerates samples,
rewrites the sample manifest, and refreshes the reviewer packet. Preserve the
failed review under a different filename before rerunning no-context review.

Every finished recording also gets a filled no-context reviewer packet at `reviews/reviewer-packet.md`, with exact media paths, logs, baselines, product surfaces, and the verifier command. Drag proof packets also list the manifest-declared pickup/path/hover screenshots directly. Give the packet to the reviewer instead of hand-copying paths from the run directory.

Use `script/e2e/record-reviewer-attempt` to append accepted, stalled, superseded, or replaced reviewer attempts to `reviews/reviewer-attempts.tsv`. The reviewer packet lists that ledger, and review lint requires no-context reviews to cite non-pass attempt rows by role, status, output path, and replacement reason. New packets also write `reviews/reviewer-citation-checklist.tsv`, a TSV inventory of the paths, event ids, timing keys, expected chips, retry rows, reviewer attempts, and baselines the reviewer must account for.

For text-heavy config demos, use `script/e2e/write-visible-proof-excerpt` to generate a compact reviewer-facing excerpt. It enforces that the required active TOML table appears within the configured line budget, which keeps proof text above the fold in screenshots and videos.

For timed-caption guest scripts, source `script/e2e/guest/recording-timing-helpers.sh` and use `sleep_until_recording_offset <start> <end> <label>` before visible user actions or commands. The helper fails with the semantic-failure exit when the action has already missed its caption window, which keeps timing drift out of Tart recordings.

`make e2e-smoke` validates the capture pipeline and will still produce a host-visible recording if guest control is unavailable. Product slices must use strict guest control and guest display capture:

```bash
TART_HOME=/Volumes/<external-ssd>/tart make e2e-guest-smoke
```

The default control backend is SSH with the standard Tart image credentials, `admin` / `admin`. Override it with `WINMUX_E2E_CONTROL_MODE=tart-exec` only when the VM image has a working Tart Guest Agent.

`make e2e-guest-smoke` sets `WINMUX_E2E_CAPTURE_MODE=guest`, so screenshots and videos are produced by `screencapture` inside the VM and written through the shared artifact mount. For Slice 1 and later, a host-only recording is not enough. Set `WINMUX_E2E_SLICE=slice-N` and keep the artifact directory plus `recordings/*.mov` path in the slice notes before moving on.

`make e2e-slice-2` runs the config-backed column-zone scenario with `script/e2e/configs/column-zones.toml`. The recording opens three labeled TextEdit documents and places them into the configured `Reference`, `Work`, and `Comms` columns so the artifact shows live windows, not only CLI output.

`make e2e-slice-3` starts with the same config, stages `script/e2e/configs/column-zones-shifted.toml` as `config/winmux-shifted.toml`, copies the initial config to `config/winmux-active.toml` inside the guest, then runs `winmux reload-config` after replacing only the active config. `config/winmux.toml` and `config/winmux-shifted.toml` are immutable artifact evidence; reload scenarios mutate only `config/winmux-active.toml`. The proof logs compare `slice-3-monitors-before.log` and `slice-3-monitors-after.log` to show changed zone geometry, and compare the before/after window logs to show the labeled windows stayed in `left`, `main`, and `right`.

`make e2e-slice-4` records the command workflow. It uses `focus-zone Reference`, `focus-zone Work`, `move-node-to-zone Comms --fail-if-noop`, `focus-monitor 1`, and `list-zones`; the verifier requires the ready screenshot `01-ready-slice-4.png` plus the Slice 4 focus, move, compatibility, window, and zone logs.

`make e2e-slice-5` records the sidebar zone-target workflow with `script/e2e/configs/column-zones-sidebar.toml`. The setup phase opens the sidebar, stages `Reference`, `Work`, and `Comms`, captures `01-ready-slice-5.png`, then records a visible drag of `move-demo.rtf` from the Work sidebar item onto the Comms zone row. This proof is about a sidebar zone-row drop target: it is not a window-within-zone snap or normal window intent-zone overlay. The verifier checks the sidebar before/after logs, action log, proof manifest, pickup/path/hover screenshots, window before/after logs, zone log, and caption chips.

`make e2e-slice-6` records named zone layout presets with `script/e2e/configs/zone-layout-presets.toml`. The setup phase stages live TextEdit windows in `Reference`, `Work`, and `Comms` under the `balanced` preset, captures `01-ready-slice-6.png`, then records `winmux use-zone-layout focus`. The verifier checks before/after layout ids and widths, the switch command log, window before/after logs, the ready screenshot, and caption chips for `[[zone-layouts]]`, `use-zone-layout`, `list-zones`, and `list-windows`.

`make e2e-slice-6b` records zone scenes with `script/e2e/configs/zone-scenes.toml`. The setup phase stages separate triage and deep-work TextEdit documents, binds them to named workspaces, activates the `triage` scene, and captures `01-ready-slice-6b.png`. The recording then runs `winmux use-zone-scene deep-work`. The verifier checks before/action/after caption anchors, before/after active zone workspaces, layout width changes, visible TextEdit documents, the ready screenshot, and caption chips for `[[zone-scenes]]`, `use-zone-scene`, `list-zones`, and `list-windows --workspace visible`.

`make e2e-slice-8` records window-rule routing with `script/e2e/configs/zone-window-routing.toml`. The setup phase stages visible `Reference`, `Work`, and `Comms` anchor documents, focuses Work, confirms `route-comms.rtf` is absent, and captures `01-ready-slice-8.png`. The recording opens `route-comms.rtf`; the configured `[[on-window-detected]]` callback runs `move-node-to-zone Comms --fail-if-noop` against the detected window id. The verifier checks the config rule, before/action/after window logs, zone log, ready screenshot, success marker, no manual move command in the recorded proof action log, and caption chips for the strict config command, open action, `list-windows --workspace visible`, and `list-zones`.

`make e2e-slice-10` records runtime zone availability with `script/e2e/configs/zone-availability.toml`. The setup phase stages visible `Reference`, `Work`, and `Comms` documents with the sidebar enabled, then captures `01-ready-slice-10.png`. The proof runs `winmux disable-zone Comms`, captures the hidden state where Comms is absent and Work expands, then runs `winmux enable-zone Comms` and captures the restored state where the same Comms workspace returns. The verifier checks before/hidden/restored zone logs, visible window logs, sidebar-state logs, hidden/restored screenshots, command logs, success marker, and caption chips for the config, disable command, enable command, `list-zones`, and `list-windows --workspace visible`.

`make e2e-slice-11a` records runtime zone width controls with `script/e2e/configs/zone-width-controls.toml`. The setup phase stages visible `Reference`, `Work`, and `Comms` documents with numeric geometry labels and captures `01-ready-slice-11a.png`. The proof runs `winmux resize-zone Work width +10%`, captures Work expanding while side zones shrink, then runs `winmux balance-zones` and captures all enabled zones returning to equal widths. The verifier checks before/resized/balanced zone geometry, preserved window ids and workspaces, command logs, ready and action screenshots, success marker, key bindings, and caption chips with the exact commands and numeric width changes.

`make e2e-slice-11b` records runtime zone style controls with `script/e2e/configs/zone-style-controls.toml`. The setup phase stages visible `Reference`, `Work`, and `Comms` documents with the sidebar enabled and captures `01-ready-slice-11b.png`. The proof records `winmux set-zone-style Comms urgent`, captures the Comms zone row tinted urgent red, then records `winmux set-zone-style Comms calm` and captures the same row tinted calm blue. The verifier checks before/urgent/calm style fields, preserved window ids and workspaces, command logs, ready and action screenshots, success marker, key bindings, semantic sample labels, and caption chips with the exact commands and style ids.

`make e2e-slice-19` records ergonomic runtime zone style cycling with `script/e2e/configs/zone-style-cycle.toml`. The setup phase stages visible `Reference`, `Work`, and `Comms` documents with the sidebar enabled and captures `01-ready-slice-19.png`. The proof records three executions of `winmux cycle-zone-style Comms urgent calm`: no style to urgent red, urgent to calm blue, and calm back to urgent wraparound. The verifier rejects `set-zone-style` proof, missing wraparound, hidden command surface, style changes outside zone chrome/sidebar rows, and any layout, snap, gesture, or persistence claim.

`make e2e-slice-20` records runtime mouse snap policy switching with `script/e2e/configs/zone-snap-policy-switching.toml`. The setup phase stages visible Reference, Work, and Comms documents, focuses `snap-demo.rtf` in Work, and captures `01-ready-slice-20.png`. The proof starts from `policy = 'freeform'`, records a no-modifier drag with no snap overlay or zone move, runs `winmux set-zone-snap-policy snap-to-zone`, records a second no-modifier drag that shows the whole Comms-zone overlay and final movement into Comms/right, then runs `winmux cycle-zone-snap-policy freeform snap-to-zone` to return runtime policy to freeform. The verifier checks command logs, binding/config captions, semantic samples, overlay/no-overlay sentinel crops, unchanged window id, whole-zone target semantics, and rejects modifier-held or final-state-only proof.

`make e2e-slice-21` records ergonomic zone mode V2 with `script/e2e/configs/zone-mode-v2.toml` and `script/e2e/guest/slice-21-zone-mode-v2.sh`. The setup phase stages a live Work/main proof board plus Reference and Comms documents, then captures `01-ready-slice-21.png`. The proof records `Alt-Z, S` for `cycle-zone-snap-policy freeform snap-to-zone`, `Alt-Z, Tab` for `cycle-zone-layout balanced focus`, two `Alt-Z, A` beats for `cycle-zone-availability focus-only communications full-dashboard`, and `Alt-Z, Y` for `cycle-zone-style current urgent calm`. The verifier checks binding dispatch through `trigger-binding`, command output, mode return to main, semantic sample labels, mandatory event manifest ordering, Work/main widening, focus-only hiding side zones, communications restoring Comms/right, urgent current-zone styling, and rejects drag/persistence/relaunch claims.

`make e2e-slice-22` records float-unless-snap mouse behavior with `script/e2e/configs/float-unless-snap.toml` and the shared desktop mouse drag guest script. The proof first drags `snap-demo.rtf` with no modifier and must show no whole-zone overlay while the same window becomes `layout=floating` in Comms/right, then resets the same window to Work/main and drags with Alt held to show the whole Comms-zone overlay and final snapped placement. The verifier checks config-driven `policy = 'float-unless-snap'`, exact user-action captions, semantic samples, mandatory event manifest ordering, overlay/no-overlay sentinel crops, unchanged source id, floating post-state, Work/main reset, whole-zone target semantics, and rejects runtime-policy, final-state-only, snap-to-window, persistence, and visual-settings claims.

`make e2e-slice-23` records the product whole-zone snap overlay label with `script/e2e/configs/float-unless-snap.toml` and the shared desktop mouse drag guest script. It reuses the Slice 22 two-drag proof but requires the actual WinMux overlay during the Alt-held hover to read `Whole zone: Comms`, not only the harness crop label.

`make e2e-slice-24` records the one-handed secondary-button mouse snap gesture with `script/e2e/configs/float-unless-snap-secondary-button.toml`. The proof first drags `snap-demo.rtf` normally and must show no whole-zone overlay while the window becomes floating in Comms/right, then resets the same window to Work/main and drags with the secondary mouse button held to show the product whole-zone overlay and final snapped placement.

`make e2e-slice-25` records the mouse-demo artifact contract with the same secondary-button gesture configuration. It exists to prove the hardened artifact shape: visible input-state cue, command result chips, semantic summary contact sheet, zoomed whole-zone crop, event manifest, mouse event timings, and trimmed `.demo.mov` sidecar while preserving the full acceptance recording.

`make e2e-slice-26` records draggable zone dividers with `script/e2e/configs/zone-divider-drag.toml` and `script/e2e/guest/slice-26-zone-divider-drag.sh`. The proof stages Reference, Work, and Comms windows, hovers and drags the Work/Comms divider, then verifies Work grows, Comms shrinks, Reference stays unchanged, window/workspace assignments stay attached, and the config file is not rewritten. The verifier requires hover, pickup, drag-path, live-preview, release, and post-release inspection media plus event and proof manifests.

`make e2e-slice-28` records runtime layout export with the same three-zone layout fixture and `script/e2e/guest/slice-28-export-zone-layout.sh`. The proof resizes Work at runtime, runs `winmux export-zone-layout saved-ultrawide --monitor 1`, shows the emitted `[[zone-layouts]]` TOML in the guest recording, validates it with `winmux config --check`, and verifies the copied `config/winmux.toml` checksum is unchanged.

`make e2e-slice-29` records explicit runtime layout save with `script/e2e/configs/zone-save-layout.toml` and `script/e2e/guest/slice-29-save-zone-layout.sh`. The proof resizes Work at runtime, runs `winmux save-zone-layout --dry-run` without changing the config hash, runs `winmux save-zone-layout` with a visible backup path and width diff, shows the saved balanced layout in `winmux.toml`, and reloads/inspects `list-zones` to prove saved widths are now the configured baseline.

`make e2e-slice-31` records relaunch-safe saved layout behavior with `script/e2e/configs/zone-relaunch-saved-layout.toml` and `script/e2e/guest/slice-31-relaunch-saved-layout.sh`. The proof resizes Work at runtime, runs `winmux save-zone-layout`, quits and relaunches WinMux through the slice LaunchAgent service, then runs `winmux list-zones` to show the saved `20/60/20` layout is loaded as configured widths. The verifier checks the measurement TSV, proof manifest, startup trace, relaunch log, product-window physical positions, demo cut, caption chips, full-packet baseline citations, and the no-context review.

`make e2e-slice-32` records relaunch-safe saved layout behavior after a visible divider drag with `script/e2e/configs/zone-divider-drag.toml` and `script/e2e/guest/slice-32-divider-save-relaunch.sh`. The proof delegates the Slice 26 Work/Comms divider drag, keeps the dragged widths on screen, runs `winmux save-zone-layout`, quits and relaunches WinMux through the slice LaunchAgent service, then runs `winmux list-zones` to show the dragged widths are loaded as configured widths. The verifier checks the delegated divider media, measurement TSV, proof manifests, backup/hash evidence, startup trace, relaunch log, caption timing, demo cut, full-packet baseline citations, and the no-context review.

`make e2e-slice-33` records scene cycling with `script/e2e/configs/zone-scenes.toml` and the reusable zone-scene guest script. The proof starts in the `triage` scene, runs `winmux cycle-zone-scene triage deep-work` to show the `deep-work` scene, then runs the same command again to wrap back to `triage`. The verifier checks both command logs, before/after/wrap scene logs, visible TextEdit documents, caption chips, and the Slice 33 event manifest.

`make e2e-slice-34` records the same scene cycle through the user-facing binding path. The run uses `script/e2e/configs/zone-scenes.toml`, requires persisted clean pre-Tart reviewer reports under `reviews/pre-tart/`, and proves `alt-tab = 'cycle-zone-scene triage deep-work'` by running `winmux trigger-binding --mode main alt-tab` twice. The verifier checks the binding-specific command logs, `slice-34-trigger-binding-alt-tab-wrap.log`, timing offsets for both identical command captions, semantic sample rows, event manifest rows, and triage -> deep-work -> triage live TextEdit state.

`make e2e-slice-35` records the first-run ultrawide starter-template workflow. It uses `resources/default-config.toml` as the staged config, requires persisted clean pre-Tart reviewer reports, shows the `WINMUX ULTRAWIDE ZONES TEMPLATE` block while it is still commented, uncomments only that block into `logs/slice-35-starter-config-uncommented.toml`, launches WinMux with the uncommented config, runs `winmux config --check`, and records `winmux list-zones` showing Reference, Work, and Comms.

`make e2e-slice-37` records the starter-template onboarding companion. It uses
the same generated config path as Slice 35, requires persisted clean pre-Tart
reviewer reports, shows the commented template, uncomments it, launches WinMux,
validates the config, runs `winmux list-zones`, then runs
`winmux focus-zone Comms` as the first useful command after zones are enabled.
The artifact is a fresh Tart guest-captured companion video; it does not replace
the repo-root `demo-columnar-zones.mp4`.

`make e2e-slice-38` records normal-user readiness. It copies the starter config
to `~/.config/winmux/winmux.toml`, uncomments the ultrawide template there,
launches `WinMuxApp` without `--config-path`, proves the runtime config path
with `winmux config --config-path`, then runs `config --check`, `list-zones`,
`focus-zone Comms`, `move-node-to-zone --focus-follows-window Work`,
`resize-zone Work width +10%`, and `save-zone-layout --dry-run`. The verifier
requires the dry run to leave the normal config hash unchanged.

`make e2e-slice-39` records dogfood install and permission readiness. It stages
`/Applications/WinMux.app`, prepares Accessibility, Screen Recording,
Automation, and Input Monitoring before recording, launches the installed app
without `--config-path`, runs `winmux doctor`, proves the normal config path,
lists Reference/Work/Comms, relaunches the installed app, and runs
`winmux focus-zone Comms` after relaunch.

`make e2e-slice-11c` records named zone availability sets with `script/e2e/configs/zone-availability-sets.toml`. The setup phase stages visible `Reference`, `Work`, and `Comms` documents with the sidebar enabled and captures `01-ready-slice-11c.png`. The proof records `winmux set-zone-style Comms urgent`, `winmux use-zone-availability focus-only`, and `winmux use-zone-availability communications`. The verifier checks that focus-only hides Reference and Comms while Work expands, communications restores Comms/right while Reference stays hidden, the same Comms workspace/window returns, the urgent style persists across hide/restore, semantic sample labels cover each command boundary, and `logs/slice-11c-zone-availability-sets.color-sentinel.tsv` proves the Comms swatch before hide, during restore, and after restore.

`make e2e-slice-12` records desktop mouse zone snapping with `script/e2e/configs/zone-mouse-snap.toml`. The setup phase stages visible Reference, Work, and Comms documents, focuses `snap-demo.rtf` in Work, and captures `01-ready-slice-12.png`. The proof first drags the desktop window without Alt to demonstrate no whole-zone snap and no zone move, then resets the same window and drags with Alt held to show a whole Comms-zone overlay and final movement into Comms/right. The pre-Tart gate includes the mouse config parser tests and `WindowZoneSnapPolicyTest`. The verifier checks the `[mouse.zone-snap]` config, negative and positive drag logs, unchanged source window id, whole-zone target semantics, per-beat drag screenshots, semantic sample labels, and exact action/config caption chips.

`make e2e-slice-13` records portable keyboard zone mode with `script/e2e/configs/zone-mode-bindings.toml` and `script/e2e/guest/slice-13-zone-mode-bindings.sh`. The setup phase stages Reference, Work Alpha, Work Beta, and Comms documents plus a live state board, then captures `01-ready-slice-13.png`. The proof records `Alt-Z, L`, `Alt-Z, Shift-L`, `Alt-Z, Equal`, `Alt-Z, 0`, and two `Alt-Z, T` actions. The verifier checks exact caption chips and config bindings for `focus-zone next`, `move-node-to-zone --focus-follows-window next`, `resize-zone current width +10%`, `balance-zones`, and `toggle-zone current`; resolved target fields; live board freshness in semantic samples; tab-group movement into Comms/right; width resize/balance; and current-zone hide/restore.

`make e2e-slice-14` records workspace zone bindings with `script/e2e/configs/zone-bindings.toml` and `script/e2e/guest/slice-14-zone-bindings.sh`. The setup phase stages BEFORE documents in Reference/left, Work/main, and Comms/right, then records `winmux apply-zone-bindings`. The verifier checks that the command caption appears before the bound documents replace the BEFORE documents, that `[[zone-bindings]]` and `apply-zone-bindings` are exposed on screen, and that list commands prove the three bound workspaces are active in their zones.

`make e2e-slice-15` records runtime tab-group node binding with `script/e2e/configs/zone-node-bindings.toml` and `script/e2e/guest/slice-15-node-zone-binding.sh`. The setup phase stages Work Alpha and Work Beta as one TextEdit tab group in Work/main, captures `01-ready-slice-15.png`, and proves `list-zone-bindings --count` is zero. The proof records `winmux bind-node-to-zone Comms`, then shows the same tab-group titles in Comms/right and `winmux list-zone-bindings` exposing node-id, node-type, title, zone, workspace, and monitor. This slice proves runtime node binding, not workspace `[[zone-bindings]]` or relaunch persistence.

`make e2e-slice-16` records mouse snap affordance semantics with the same `script/e2e/configs/zone-mouse-snap.toml` policy as Slice 12, but with stricter proof artifacts. The recording shows a no-Option freeform drag with no zone move, then an Option-held drag whose caption says `snap to Comms zone` and whose overlay targets the whole Comms zone, not a window or slot. The harness writes `logs/slice-16-mouse-snap-affordance.overlay-sentinel.tsv`, which compares the target-zone crop in the no-Option hover frame with the Option-held hover frame so the verifier has a mechanical overlay/no-overlay affordance check in addition to the human review.

`make e2e-slice-17` records node-binding guardrails with `script/e2e/configs/zone-node-bindings.toml` and `script/e2e/guest/slice-17-node-binding-guardrails.sh`. The setup phase stages a visible proof board plus windows for escaped-title, rebind, disabled-zone, missing-unbind, and stale-tab-group cases. The proof records the real `winmux` commands, including `list-zone-bindings --count`, `bind-node-to-zone --window-id ...`, `disable-zone Comms`, `unbind-node-zone-binding --window-id ...`, and `close --window-id ...`. The verifier checks semantic sample labels, command timing windows, escaped separator output, stable rebind count, expected failure paths, stale tab-group pruning, final empty count, and the Slice 15 non-claim that runtime node bindings are not relaunch-persistent.

`make e2e-slice-18` records durable zone-affinity routing with `script/e2e/configs/zone-affinities.toml` and `script/e2e/guest/slice-18-zone-affinity-routing.sh`. The setup phase stages Reference, focused Work, and Comms anchor documents, confirms `affinity-comms.rtf` is absent, and captures `01-ready-slice-18.png` as a setup checkpoint. The recording opens `affinity-comms.rtf`; the configured `[[zone-affinities]]` matcher routes the detected window to Comms/right while `focused-work.rtf` remains in Work/main. The verifier rejects generic `[[on-window-detected]]` proof, final-state-only proof, manual `move-node-to-zone` in proof-phase action/run/CLI logs, focused-window movement, and any relaunch-persistence or durable tab-group-identity claim.

`make e2e-package-root-demo` packages an accepted strict Tart artifact into the
tracked repo-root `demo-columnar-zones.mp4`. By default it uses the accepted
Slice 6B recording. Pass `--source-recording` to package a newer accepted
recording or `.demo.mov` sidecar from another run. The packager fails unless
the source artifact has strict guest-capture proof and an accepted no-context
review, then writes a root-demo packet under
`artifacts/e2e/<slice-name>-<timestamp>/reviews/reviewer-packet.md`. Refresh
package evidence without re-encoding the root MP4 with `--refresh-existing`.

Override the source or output with:

```bash
make e2e-package-root-demo ARGS="--source-run-dir artifacts/e2e/<run> --source-recording recordings/<recording>.mov --slice-name slice-36-root-current-demo --output demo-columnar-zones.mp4"
```

Verify an existing root-demo package without generating files:

```bash
make e2e-verify-root-demo-check RUN_DIR=artifacts/e2e/slice-7-root-demo-<timestamp> ARGS=--require-review
```

Close out an accepted root-demo package and persist the transcript:

```bash
make e2e-root-demo-closeout-check RUN_DIR=artifacts/e2e/slice-36-root-current-demo-<timestamp>
```

The closeout gate runs `verify-root-demo --require-review`, checks that the
three no-context retrospective reports exist, verifies generated version files
are clean, runs `git diff --check`, and writes
`logs/root-demo-closeout.log` inside the artifact.

Product slices set a deterministic VM display with `tart set --display`. The default is `WINMUX_E2E_VM_DISPLAY=3440x1440px`; set it to an empty string only when debugging Tart display behavior. Before the first screenshot, the harness probes guest `screencapture` until it produces a non-empty image, then records the probe log in `logs/guest-capture-ready.log`.

Product slice targets run `make e2e-pre-tart-checks` first. That gate validates shell syntax, checks command metadata consistency across `CmdKind`, generated help, and CLI descriptions, runs `git diff --check` with an explicit PASS marker, runs `shellcheck` when installed, verifies generated version files are not dirty, renders every caption plan through the real annotation pipeline against a tiny local fixture, self-tests guest mouse-event log emission and guest transport warm-up/retry summary policy, self-tests the pre-Tart reviewer gate, and runs the focused parser/topology/listing Swift tests so Tart is not the first place cheap failures appear. Product slice targets allocate the run directory before the gate and save this output to `logs/pre-tart-checks.log`, so the accepted artifact includes the exact host-side validation transcript.

Slices that set `REQUIRE_PRE_TART_REVIEW=1` use a two-phase gate. The first run writes `reviews/pre-tart/freshness.env` after `make e2e-pre-tart-checks`, then stops unless the three reviewer reports already exist and cite the freshness lines. Run the no-context reviewers against that run directory and make each report cite `candidate_head=...`, `candidate_state_sha256=...`, `git_status_sha256=...`, and `pre_tart_log_sha256=...`. The second run validates that the repo candidate and pre-Tart log still match the freshness manifest before Tart starts.

After a run, use the mechanical verifier before spawning the no-context reviewer:

```bash
make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-N-<timestamp>
```

After the review file exists, rerun the non-mutating checker with `ARGS=--require-review`. The verifier checks required media, strict guest capture, duration, ultrawide resolution, clean-slate logs, capture logs, generated sample frames, the sample manifest, and the contact sheet. Reload scenarios also verify immutable config hashes when preflight recorded them. It is a tripwire; the no-context reviewer still inspects the media and product fit.

Use the cheap review lint before the full post-review verifier when a review is
freshly written:

```bash
make e2e-review-lint RUN_DIR=artifacts/e2e/slice-N-<timestamp>
```

This validates the review verdict, freshness, baseline citations,
post-recording retry citations, and every semantic sample citation listed in
`logs/<recording>.sample-manifest.tsv`.

For report-only checks, use the non-mutating verifier:

```bash
make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-N-<timestamp> ARGS=--require-review
```

This fails if generated samples or reviewer packets are missing, instead of creating them.
When preserving closeout evidence would help future audits, tee that command to
an artifact log such as `logs/post-review-verify.log`; do not replace the
rerunnable verifier with the saved transcript.

When annotation is enabled, the verifier also checks that the annotation log, caption plan, and raw preserved capture exist, and that every caption row has a command, action, config, or result chip. The no-context reviewer should inspect the annotated video as the primary artifact and use the raw capture only to debug capture or overlay problems.

Dense desktop proofs can use smaller caption cards so labels do not cover target windows, slot affordances, measured geometry, or visible command output. The annotator accepts `WINMUX_E2E_CAPTION_FOOTPRINT=standard|compact` and `WINMUX_E2E_CAPTION_ANCHOR=bottom-left|bottom-right|top-left|top-right`; Slice 26, Slice 27, and Slice 28 recordings default to `compact` through the harness.

Caption-boundary frames use the names `caption-NN-boundary-before.png`,
`caption-NN-boundary-start.png`, and `caption-NN-boundary-end.png`.
Transition-style recordings should point reviewers at those frames so
command-caption ordering is checked before the next slice proceeds. Annotation
plans may add a sixth TSV field for a compact result line. Use it for `Run:`
captions when the command output is not otherwise visible, for example
`Result: snap policy = snap-to-zone`.

Each annotated run also writes `logs/<recording>.sample-manifest.tsv`. It maps standard samples, caption-boundary samples, and slice-specific semantic proof beats to exact artifact-relative image paths. Ordered transition slices must add semantic rows such as `resize-command-start` or `after-balance`, and the verifier should require those labels for the slice.

When a sample manifest contains drag/snap semantic beats, the primary
`screenshots/<recording>.contact-sheet.jpg` is a labeled semantic summary rather
than a percentage-only timeline. The harness also writes
`logs/<recording>.contact-sheet-manifest.tsv`, which lists each panel. For
drag/snap proofs, the summary sheet must include the first target affordance,
release beat, and final placement so a reviewer can audit the user story before
opening logs. When overlay-sentinel output includes a labeled target crop, the
summary sheet includes that crop as a zoomed proof panel. Mouse gesture captions
should use the optional result line for visible input-state cues such as
`Input: Alt held` or `Input: secondary button held`.

Annotated product runs also write `logs/<recording>.edge-crops.tsv` and
`screenshots/<recording>.edge-crops/`. The manifest must include final
screenshot edge/corner crops and, when recording samples exist, near-end video
frame edge/corner crops. `make e2e-verify-slice-check` treats missing or stale
derived samples, contact sheets, review packets, and edge crops as failures
instead of regenerating them.

When an annotated recording keeps a long uncaptained verification tail,
`recordings/<recording>.demo.mov` is a trimmed product-facing sidecar and
`logs/<recording>.demo-cut.tsv` records its source and trim point. The full
recording remains the acceptance artifact; the demo cut is the shorter viewer
path. If the tail exceeds `WINMUX_E2E_CAPTION_TAIL_MAX_SECONDS` and trimming
would produce a meaningfully shorter demo, the verifier requires the demo-cut
sidecar and manifest.

Drag, divider, and snap reviews must answer whether the target semantics are
understandable from the video before reading logs. The answer must cite exact
media, such as the hover frame, release frame, labeled overlay crop, or semantic
contact-sheet panel. Review lint rejects accepted reviews that omit the
`target-semantics` value or its media path when an overlay sentinel declares one.

Slices that prove visible color or style preservation should also write `logs/<recording>.color-sentinel.tsv`. Each non-comment row is tab-separated:

```text
swatch<TAB>label<TAB>screenshot-path<TAB>x<TAB>y<TAB>w<TAB>h<TAB>#RRGGBB<TAB>min-percent<TAB>max-channel-distance<TAB>note
```

The screenshot path is run-relative. The verifier crops the region and requires at least `min-percent` of sampled pixels to match the expected color within the channel-distance threshold.

Caption plans use tab-separated fields:

```text
start_seconds	end_seconds	title	subtitle	command_or_action	result_line
```

The final field should be concrete and user-facing, for example `Run: winmux move-node-to-monitor Reference`, `Run: winmux reload-config`, `Config: [[zones]]`, `Action: drag sidebar item move-demo.rtf`, or `Action: hover over Comms zone target`. Avoid internal harness commands unless the slice is specifically proving the harness.
The optional sixth field is for compact result evidence such as
`Result: Work 1688 -> 1941; Comms 844 -> 591`.

Before guest capture, the harness prepares the disposable guest:

- writes TCC grants for SSH/session helpers, `osascript`, `screencapture`, the staged WinMux app/CLI, and the Slice 39 installed app identity;
- kills stale setup apps such as Terminal, System Settings, TextEdit, Photos, Preview, and Finder windows;
- hides desktop widgets and stops notification agents so banners do not appear in the recording;
- logs the privacy setup and clean-slate state under `logs/guest-privacy-setup.log` and `logs/guest-clean-slate.log`.

Slice scenarios stage `WinMuxApp` and `winmux` under `$HOME/winmux-e2e/bin` inside the guest. Most debug bare-executable launches pass `WINMUX_DEFAULT_CONFIG_PATH` so SwiftUI settings initialization can parse the staged config before the app reloads `--config-path`. Slice 38 proves normal startup from the staged debug app without `--config-path` or `WINMUX_DEFAULT_CONFIG_PATH`; Slice 39 installs `/Applications/WinMux.app` and proves the same normal startup path from the dogfood app identity. `WINMUX_E2E_STARTUP_TRACE` writes startup milestones to `logs/winmux-startup-trace.log`.

Guest action retry logs include `failure_count` and `final_result` so reviewers can distinguish transient transport or TCC setup retries from semantic proof failures. On final guest action failure, the harness writes `logs/run-abort-status.txt` with phase, exit code, primary log, whether recording had started, and whether setup had completed. Host-side generated-version failures use `logs/host-build-generated-clean.log` as their primary abort log. Guest script retry summaries also record `mutation_started` and `first_mutation_line`, so reviewers can tell whether a failed post-recording attempt touched product state before a retry or re-record. The harness warms guest transport before privacy setup and again before recording; the warm-up requires three successful probes with at least two consecutive successes, which filters transient SSH misses without failing a clean VM before the proof starts. Each run writes `logs/guest-transport-summary.tsv` with phase, log path, attempt count, failure count, final result, whether the phase happened before recording, compact per-attempt statuses, and compact first/last failure reasons. The summary links the raw phase log for the full failure detail.

If a run produces media but is later replaced before acceptance, mark it
superseded instead of leaving it as an ambiguous unreviewed artifact:

```bash
WINMUX_E2E_RUN_DIR=/path/to/artifact \
WINMUX_E2E_SUPERSEDED_REASON="stale proof-manifest caption chip" \
WINMUX_E2E_SUPERSEDED_BY=/path/to/replacement \
./script/e2e/tart-recording-harness mark-superseded
```

This writes `reviews/superseded.md` and `logs/run-abort-status.txt` with
`final_result=superseded`.

Scenario command proofs must distinguish setup from proof. Setup commands may create or place windows, but proof commands must use the exact behavior being tested, assert before and after state, and fail on no-op when movement is the claim. Prepared product slices should capture a clean before screenshot, stage the visible ready state, capture `01-ready-slice-N.png`, then start the proof recording. Do not use fallback commands that would hide a broken zone selector or command path.

Stateful scenario assertions should exit with `WINMUX_E2E_GUEST_ACTION_SEMANTIC_FAILURE_EXIT` (default `86`) so `guest_script_retry` stops immediately instead of replaying a half-mutated window-management state. Transport failures can retry; semantic proof failures should fail the run.

Live-board or semantic-screenshot proofs must write a freshness log for every board checkpoint before capturing the corresponding screenshot. The Slice 13 pattern writes `logs/slice-13-board-freshness.log`; future live-board slices should use the same `checkpoint=...|result=success` shape or document a waiver in the plan.

Drag proofs must include `logs/<recording>.proof-manifest.tsv`. If fixed JXA points remain, the manifest must name the source item, target zone/row, snap-target semantics, source and target points, coordinate policy, caption chip, required action frames, in-drag screenshots, and before/after state logs. The verifier requires manifest-listed screenshots to be full-frame PNGs matching the recording resolution and distinct from each other. The no-context reviewer must reject final-placement-only drag videos and must name the exact media file used for each drag beat.

Slice 0 and later slices should fail or be re-recorded if screenshots or video show permission prompts, `sshd` prompts, unrelated app windows, widgets, notification banners, boot screens, or setup screens after capture begins.

After each slice run, spawn a no-context artifact reviewer before starting the next slice. Give the reviewer `reviews/reviewer-packet.md` plus `script/e2e/prompts/no-context-artifact-review.md`; the packet supplies the slice goal placeholders, media, logs, local baseline media (`demo.mp4`, `demo2.mp4`, `demo3.mp4`, and `resources/screenshots/*.png`), product surfaces, and verifier command. The reviewer writes `reviews/no-ctx-artifact-review.md` inside the artifact directory. Its first nonblank line must start with `PASS:`, `PASS_WITH_NOTES:`, or `FAIL:`, and its final line must be exactly `next slice allowed: yes` or `next slice allowed: no`.

Only `PASS:` or `PASS_WITH_NOTES:` with final line `next slice allowed: yes` lets the next gate start. Hard failures such as unclean desktop state, permission prompts, sshd prompts, unrelated windows, host-only product recordings, missing live behavior, or uninspected video frames require a fix and re-recording.

After an accepted artifact review, run the three-agent retrospection gate in `script/e2e/prompts/no-context-retrospection.md`. Bake accepted blocking findings into the next slice's pre-slice cleanup checklist before running the next Tart scenario.

For local dry-run checks that should not use the external SSD, set:

```bash
WINMUX_E2E_ALLOW_INTERNAL_DISK=1 WINMUX_E2E_MIN_FREE_GB=0 TART_HOME=/tmp/winmux-tart make e2e-preflight
```

Use the override only for script validation. Real slice videos should use the external SSD-backed `TART_HOME`.
