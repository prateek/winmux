# Handoff

Read `AGENTS.md` first, then `docs/plans/columnar-zones.md` (design and
slice history) and `docs/plans/slice-56-domain-model.md` (the active
redesign). This file is the durable orientation for continuing the work.

## What this is

A WinMux fork that makes ultrawide monitors ergonomic: one physical
display exposes several named workspace viewports. Slices 0-55 built the
zone feature set and shipped it as signed dogfood releases; Slice 56 is a
user-facing domain-model redesign in progress on top of that base.

## Current state

- Branch `codex-columns` on the `fork` remote (`prateek/winmux`, the
  default branch). Real installs reach the daily driver via the Homebrew
  cask and Sparkle self-update (`./script/dogfood-release <version>`; see
  AGENTS.md).
- Slices 0-50 are Tart-accepted. Slices 51-55 have shipped implementations
  but no accepted Tart artifact yet — their acceptance is deferred until
  after the Slice 56 vocabulary is final, so recordings capture the final
  command and config names.
- `docs/dogfood-notes.md` holds classified real-hardware findings.

## Remaining work

Slice 56 phases (see `docs/plans/slice-56-domain-model.md` for the model
and phase detail):

- **Phase E — vocabulary cut**: config version 3 with dead-key errors, the
  zone→column/card/scene command renames through the metadata chain,
  `column init`, runtime-overlay teardown, e2e preflight re-baseline, and
  the fork-internals rename.
- **Phase F — sidebar + settings**: column-sectioned sidebar, card-row
  drag, Columns/Scenes/Rules settings panes, and removal of the project
  feature.
- **Phase G — docs + template + proof**: rewrite the template, docs, and
  samples in the new vocabulary; write the slice-56 guest script and
  contract checker.

Then the Tart acceptance phase for Slices 51-56 as one batch, and the
beta-readiness decision after a multi-day dogfood soak on the ultrawide.

## Tart acceptance gate (applies to every product slice)

A slice is accepted only when all of these exist and pass:

- three clean no-context pre-Tart reviews (launched with `fork_context=false`)
  against current freshness;
- a Tart recording with playable annotated and raw video, contact sheet,
  sample and event manifests, expected command chips, and required
  screenshots — never logs-only proof;
- a no-context artifact review, review lint, and post-review verifier;
- closeout plus the three retrospectives.

Run the harness from the external SSD Tart home (`TART_HOME=/Volumes/TartVMs/tart`,
auto-exported when the drive is mounted). `make e2e-slice-<n>` drives the
gate; a first invocation stops after writing freshness until the three
pre-Tart reviews exist, then a rerun starts the recording.

Slice 51 additionally has open pre-slice items tracked in its section of
`docs/plans/columnar-zones.md` that must be resolved before its recording.

## Rules

- Never claim a slice accepted until its full gate chain above is complete.
- Do not commit `artifacts/e2e/`; do not delete accepted artifact dirs.
- Do not revert existing user or prior-agent changes; work with the current
  tree.
