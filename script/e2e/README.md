# WinMux Tart E2E Harness

The columnar zones plan requires a Tart video for every slice. This harness owns the VM preflight, screenshot capture, recording, and artifact layout.

Set `TART_HOME` to a directory on the external SSD before running VM actions:

```bash
export TART_HOME=/Volumes/<external-ssd>/tart
make e2e-preflight
make e2e-smoke
```

Artifacts are written under `artifacts/e2e/slice-N-<timestamp>/` with screenshots, recordings, logs, and the config used for the run.

Product recordings are post-produced by default. The final `recordings/<name>.mov` is the reviewed video and includes a restrained lower-third caption overlay that explains the visible action and shows the WinMux config, CLI command, or action a user would use to perform it. The untouched guest capture is kept under `recordings/raw/<name>.raw.mov`, with caption timing in `logs/<name>.annotations.tsv` and render proof in `logs/<name>.annotation.log`. The harness also writes standard timeline samples under `screenshots/<name>.samples/` and a six-up contact sheet at `screenshots/<name>.contact-sheet.jpg`. Set `WINMUX_E2E_ANNOTATE_RECORDING=0` only for local capture debugging.

Every finished recording also gets a filled no-context reviewer packet at `reviews/reviewer-packet.md`, with exact media paths, logs, baselines, product surfaces, and the verifier command. Give the packet to the reviewer instead of hand-copying paths from the run directory.

`make e2e-smoke` validates the capture pipeline and will still produce a host-visible recording if guest control is unavailable. Product slices must use strict guest control and guest display capture:

```bash
TART_HOME=/Volumes/<external-ssd>/tart make e2e-guest-smoke
```

The default control backend is SSH with the standard Tart image credentials, `admin` / `admin`. Override it with `WINMUX_E2E_CONTROL_MODE=tart-exec` only when the VM image has a working Tart Guest Agent.

`make e2e-guest-smoke` sets `WINMUX_E2E_CAPTURE_MODE=guest`, so screenshots and videos are produced by `screencapture` inside the VM and written through the shared artifact mount. For Slice 1 and later, a host-only recording is not enough. Set `WINMUX_E2E_SLICE=slice-N` and keep the artifact directory plus `recordings/*.mov` path in the slice notes before moving on.

`make e2e-slice-2` runs the config-backed column-zone scenario with `script/e2e/configs/column-zones.toml`. The recording opens three labeled TextEdit documents and places them into the configured `Reference`, `Work`, and `Comms` columns so the artifact shows live windows, not only CLI output.

`make e2e-slice-3` starts with the same config, stages `script/e2e/configs/column-zones-shifted.toml` as `config/winmux-shifted.toml`, copies the initial config to `config/winmux-active.toml` inside the guest, then runs `winmux reload-config` after replacing only the active config. `config/winmux.toml` and `config/winmux-shifted.toml` are immutable artifact evidence; reload scenarios mutate only `config/winmux-active.toml`. The proof logs compare `slice-3-monitors-before.log` and `slice-3-monitors-after.log` to show changed zone geometry, and compare the before/after window logs to show the labeled windows stayed in `left`, `main`, and `right`.

`make e2e-slice-4` records the command workflow. It uses `focus-zone Reference`, `focus-zone Work`, `move-node-to-zone Comms --fail-if-noop`, `focus-monitor 1`, and `list-zones`; the verifier requires the ready screenshot `01-ready-slice-4.png` plus the Slice 4 focus, move, compatibility, window, and zone logs.

`make e2e-slice-5` records the sidebar zone-target workflow with `script/e2e/configs/column-zones-sidebar.toml`. The setup phase opens the sidebar, stages `Reference`, `Work`, and `Comms`, captures `01-ready-slice-5.png`, then records a visible drag of `move-demo.rtf` from the Work sidebar item into the Comms zone target. The verifier checks the sidebar before/after logs, action log, window before/after logs, zone log, and caption chips.

`make e2e-slice-6` records named zone layout presets with `script/e2e/configs/zone-layout-presets.toml`. The setup phase stages live TextEdit windows in `Reference`, `Work`, and `Comms` under the `balanced` preset, captures `01-ready-slice-6.png`, then records `winmux use-zone-layout focus`. The verifier checks before/after layout ids and widths, the switch command log, window before/after logs, the ready screenshot, and caption chips for `[[zone-layouts]]`, `use-zone-layout`, `list-zones`, and `list-windows`.

Product slices set a deterministic VM display with `tart set --display`. The default is `WINMUX_E2E_VM_DISPLAY=3440x1440px`; set it to an empty string only when debugging Tart display behavior. Before the first screenshot, the harness probes guest `screencapture` until it produces a non-empty image, then records the probe log in `logs/guest-capture-ready.log`.

Product slice targets run `make e2e-pre-tart-checks` first. That gate validates shell syntax, runs `shellcheck` when installed, renders every caption plan through the real annotation pipeline against a tiny local fixture, and runs the focused parser/topology/listing Swift tests so Tart is not the first place cheap failures appear.

After a run, use the mechanical verifier before spawning the no-context reviewer:

```bash
make e2e-verify-slice RUN_DIR=artifacts/e2e/slice-N-<timestamp>
```

After the review file exists, rerun it with `ARGS=--require-review`. The verifier checks required media, strict guest capture, duration, ultrawide resolution, clean-slate logs, capture logs, generated sample frames, and the contact sheet. Reload scenarios also verify immutable config hashes when preflight recorded them. It is a tripwire; the no-context reviewer still inspects the media and product fit.

For report-only checks, use the non-mutating verifier:

```bash
make e2e-verify-slice-check RUN_DIR=artifacts/e2e/slice-N-<timestamp> ARGS=--require-review
```

This fails if generated samples or reviewer packets are missing, instead of creating them.

When annotation is enabled, the verifier also checks that the annotation log, caption plan, and raw preserved capture exist, and that every caption row has a command/action chip. The no-context reviewer should inspect the annotated video as the primary artifact and use the raw capture only to debug capture or overlay problems.

Caption plans use tab-separated fields:

```text
start_seconds	end_seconds	title	subtitle	command_or_action
```

The final field should be concrete and user-facing, for example `Run: winmux move-node-to-monitor Reference`, `Run: winmux reload-config`, `Config: [[zones]]`, or `Action: drag sidebar item to Comms zone`. Avoid internal harness commands unless the slice is specifically proving the harness.

Before guest capture, the harness prepares the disposable guest:

- writes TCC grants for SSH/session helpers, `osascript`, `screencapture`, and the staged WinMux app/CLI;
- kills stale setup apps such as Terminal, System Settings, TextEdit, Photos, Preview, and Finder windows;
- hides desktop widgets and stops notification agents so banners do not appear in the recording;
- logs the privacy setup and clean-slate state under `logs/guest-privacy-setup.log` and `logs/guest-clean-slate.log`.

Slice scenarios stage `WinMuxApp` and `winmux` under `$HOME/winmux-e2e/bin` inside the guest. Debug bare-executable launches also pass `WINMUX_DEFAULT_CONFIG_PATH` so SwiftUI settings initialization can parse the staged config before the app reloads `--config-path`. `WINMUX_E2E_STARTUP_TRACE` writes startup milestones to `logs/winmux-startup-trace.log`.

Scenario command proofs must distinguish setup from proof. Setup commands may create or place windows, but proof commands must use the exact behavior being tested, assert before and after state, and fail on no-op when movement is the claim. Prepared product slices should capture a clean before screenshot, stage the visible ready state, capture `01-ready-slice-N.png`, then start the proof recording. Do not use fallback commands that would hide a broken zone selector or command path.

Drag proofs must include `logs/<recording>.proof-manifest.tsv`. If fixed JXA points remain, the manifest must name the source item, target zone/row, source and target points, coordinate policy, caption chip, required action frames, and before/after state logs. The verifier requires this manifest for new `*drag*` recordings, and the no-context reviewer must reject final-placement-only drag videos.

Slice 0 and later slices should fail or be re-recorded if screenshots or video show permission prompts, `sshd` prompts, unrelated app windows, widgets, notification banners, boot screens, or setup screens after capture begins.

After each slice run, spawn a no-context artifact reviewer before starting the next slice. Give the reviewer `reviews/reviewer-packet.md` plus `script/e2e/prompts/no-context-artifact-review.md`; the packet supplies the slice goal placeholders, media, logs, local baseline media (`demo.mp4`, `demo2.mp4`, `demo3.mp4`, and `resources/screenshots/*.png`), product surfaces, and verifier command. The reviewer writes `reviews/no-ctx-artifact-review.md` inside the artifact directory and must end with `PASS`, `PASS_WITH_NOTES`, or `FAIL`.

Only `PASS` or `PASS_WITH_NOTES` lets the next gate start. Hard failures such as unclean desktop state, permission prompts, sshd prompts, unrelated windows, host-only product recordings, missing live behavior, or uninspected video frames require a fix and re-recording.

After an accepted artifact review, run the three-agent retrospection gate in `script/e2e/prompts/no-context-retrospection.md`. Bake accepted blocking findings into the next slice's pre-slice cleanup checklist before running the next Tart scenario.

For local dry-run checks that should not use the external SSD, set:

```bash
WINMUX_E2E_ALLOW_INTERNAL_DISK=1 WINMUX_E2E_MIN_FREE_GB=0 TART_HOME=/tmp/winmux-tart make e2e-preflight
```

Use the override only for script validation. Real slice videos should use the external SSD-backed `TART_HOME`.
