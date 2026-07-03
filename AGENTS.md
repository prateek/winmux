# Agent Guide

WinMux fork adding columnar zones for ultrawide monitors. A zone is a
monitor-like workspace viewport (`ZoneMonitor`); the design, slice history,
and acceptance state live in `docs/plans/columnar-zones.md` — read its
status header and the current slice before doing anything.

## Read first

- `docs/plans/columnar-zones.md` — source of truth: design decisions, slice
  ladder, acceptance status, required gates.
- `HANDOFF.md` — the operative instructions for finishing Slice 51.
- `docs/dogfood-notes.md` — live findings from real-machine dogfooding,
  classified as dogfood blocker / beta blocker / known limitation / later
  enhancement. Append new findings there; Slice 51 acceptance cites it.
- `docs/perf-comparison.md` — for any performance work: nine-system
  architecture comparison backing Slices 53-55.

## Hard rules

- The plan's Decision section carries two review-blocking rules: the
  monitor-identity rule (viewport vs physical) and the input-path rule (no
  synchronous AX, `CGWindowListCopyWindowInfo`, layout, or refresh work in
  input event handlers — schedule only). Violations are blockers, not
  style notes.
- Never claim a slice accepted without its full gate chain: pre-Tart review
  gate (three clean no-context reviewers with current freshness), Tart
  recording, no-context artifact review, review lint, post-review verifier,
  closeout, and retrospectives. `make e2e-slice-<n>` drives it; checkers
  live in `script/e2e/`.
- `artifacts/e2e/` is deliberately untracked evidence, referenced from the
  plan by path. Do not commit it; do not delete accepted artifact dirs.
- Accessibility-only with SIP intact is a product constraint; do not add
  private-API dependencies without an explicit plan decision.
- Tart runs need the external SSD: `TART_HOME=/Volumes/RiftTartVMs/tart`.

## Dogfood distribution

Real installs run on the user's daily driver via Homebrew:

- `./script/dogfood-release <version>` is the only release path: builds
  `make beta-package` signed with the "WinMux Dogfood Signing" identity,
  publishes a GitHub prerelease on `prateek/winmux` (remote `fork`), and
  bumps the cask in `prateek/homebrew-tap`. Never bump the tap by hand.
- The signing identity lives in `~/Library/Keychains/winmux-signing.keychain-db`
  (created by `script/setup-signing`, password under
  `~/.config/winmux-signing/`). Its stable certificate is what keeps TCC
  permission grants across upgrades — never delete or regenerate it
  casually; a new certificate resets the user's permission grants once.
- `make beta-package` defaults to ad-hoc signing so e2e lanes are
  unaffected; only `dogfood-release` passes the identity.
- The Sparkle EdDSA private key lives at
  `~/.config/winmux-signing/sparkle-ed25519-key` (created by
  `script/setup-sparkle-keys`). Never delete or regenerate it: installed
  builds validate updates against their embedded `SUPublicEDKey`, so a new
  key silently orphans every existing install.
- Builds are not notarized: installs need a quarantine launder plus a
  per-version Gatekeeper "Open Anyway" (documented in the cask caveats).
  Slice 52 (Sparkle) removes this for upgrades.

## Environment gotchas

- Agent shells here may force-quarantine every file write; Gatekeeper and
  quarantine behavior CANNOT be validated from this environment — silent
  `_dyld_start` hangs seen here may be dialogs on a real machine. Validate
  install flows on real hardware only.
- Homebrew 6: no `--no-quarantine`; third-party taps need `brew trust`;
  cask hooks cannot strip quarantine (brew re-quarantines its own writes).
- `codesign -dv` hides `Authority=` for untrusted self-signed certificates;
  use `-dvvv`. Piping codesign into `grep -q` under pipefail fails
  spuriously (SIGPIPE) — capture output first.
