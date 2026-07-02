# Dogfood Notes

Running log of issues found while dogfooding the beta package on real
machines, classified per Slice 51: dogfood blocker, beta blocker, known
limitation, or later enhancement. Slice 51 acceptance cites this file.

## 2026-07-02 — first daily-driver install (0.51.0-dogfood.2)

Machine: Apple silicon laptop, macOS 26, Homebrew 6, installed via
`brew install --cask prateek/tap/winmux`.

- **Beta blocker — Gatekeeper stalls first launch of brew-installed builds.**
  `open /Applications/WinMux.app` failed with LaunchServices error -1712; the
  app process stalled silently in `_dyld_start`. Cause: Homebrew 6 always
  quarantines cask downloads (no `--no-quarantine` escape), macOS records
  per-file download provenance at extraction, and the build is not notarized.
  A cask postflight cannot fix this because Homebrew re-quarantines files its
  own hooks write. Working recovery, now documented in the cask caveats:
  rewrite the payloads with `ditto --noqtn` from a user shell, then approve
  the per-version Gatekeeper block via System Settings > Privacy & Security >
  Open Anyway. Mitigations: Slice 52 (Sparkle) removes this for upgrades;
  only notarization removes it for first installs. External beta testers
  cannot be asked to launder binaries.
- **Resolved — TCC grants reset on every upgrade.** Ad-hoc signatures gave
  each build a new TCC identity. Fixed by signing app and CLI with the stable
  self-signed "WinMux Dogfood Signing" identity (`script/setup-signing`,
  `BETA_CODESIGN_IDENTITY`); the designated requirement is now constant
  across builds. First verified grant: Accessibility on 0.51.0-dogfood.2.
- **Known limitation — first launch after install shows the unnotarized-app
  dialog once per version.** Accepted for dogfood; folded into the beta
  blocker above for external testers.

Post-install doctor on the daily driver: config OK, accessibility granted,
screen recording not yet granted (tab previews degraded), single built-in
display. Zone workflows not yet exercised; ultrawide dogfood pending.

## 2026-07-02 — first live-usage feedback (0.51.0-dogfood.2)

- **Dogfood blocker — general input lag.** Interactions feel slow; the
  clearest repro is clicking the desktop wallpaper (macOS Show Desktop
  gesture), which responds noticeably late. Root cause traced (planned fix:
  Slice 53): every global left mouse up runs a full-refresh barrier that
  enumerates all windows of all apps over AX and can block on a slow app's
  AX thread; a desktop click additionally fires a second refresh via the
  Finder activation notification; divider-proximity clicks also run
  `CGWindowListCopyWindowInfo` synchronously on the main thread. All of it
  contends on the main actor with 60-120 Hz pointer monitors, so one blocked
  refresh stalls subsequent input. FlashSpace comparison confirmed the
  pattern to avoid: its hot paths never enumerate or write window frames,
  and it skips apps with hostile AX behavior.
- **Dogfood blocker — zone dividers are draggable in normal use.** Divider
  hover chrome and drag affordances appear during default interaction with
  the balanced layout. Expected: zone resizing is an explicit action (zone
  mode, a setting, or a command), not an always-on affordance near zone
  boundaries.
- **Later enhancement — Exposé-style overview gestures.** Requested
  bindings: Ctrl+Up for a whole-display overview (Mission Control analog)
  and Ctrl+Down for an overview of the focused zone's windows; three/four
  finger trackpad gestures are the user's habitual flow. FlashSpace's
  SpaceControl is the referenced prior art.
