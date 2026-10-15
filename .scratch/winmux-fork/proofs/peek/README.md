# Peek builder proofs

Run these tools only in the assigned guest, through the `vm` wrapper. Export
`TART_HOME` before every shell. Build the feature at `~/winmux`; `restart.zsh`
accepts another root for a baseline binary. Push this directory to `~/peek-proof`
and compile `keys-check.swift` there. Scripts save raw movies, screenshots, traces,
focus/workspace readbacks and match lists under `~/captures`.

- `live.ncl`: shipped config with Cmd-Tab opted in and additional probe Triggers.
- `search.zsh`: empty Space, typed `saf `, Cmd-Y and three Escapes.
- `hold.zsh`: Cmd-Y, Tab, toggles and Command release. Cmd-Space belongs to
  Spotlight, so the held-strip proof uses the issue's Cmd-Y-only fallback.
- `overview.zsh`, `follow.zsh`, `minimized.zsh`, `actions.zsh`, `close.zsh`:
  Presentation, picture, focus, Summon and close scenarios.
- `follow-list.zsh`: list follow stays below its separate legend panel.
- `pointer.zsh`, `mini-close.zsh`, `config-keys.zsh`: pointer behavior, external
  last-selection close, key removal, rebinding and config diagnostics.
- `unchanged.zsh <prefix>`: the same no-peek checks against the base and feature
  trees, with `unchanged.ncl`. Set `WINMUX_PROOF_ROOT` to the root under test.
- `no-thumbnail.zsh`: a window minimized before startup has no cached picture and
  shows its app icon on the plate. It cleans up its owned apps afterward.
- `reduce-motion.zsh`: verify the native preference is active, record a cross-fade,
  and restore the preference saved in `captures/reduce-motion-original.txt`.
- `cleanup.zsh`: stop the debug build, desk apps and local docs server.
- `capture-times.swift`: compile with the product `WindowScreenshot.swift` and
  `RefreshingSnapshot.swift`. Arguments are `Safari:<id>` or `Zed:<id>`. It takes
  five captures per output size after warming the content list. 1920×1080 output
  on the fixed 1280×720 virtual display is an output-size experiment, not a native
  1080p or Retina display measurement.

`take.zsh` keeps each Hold and its readbacks in one input process. `snapshot.zsh`
reads `peek` and focus while a key remains down. Movies are builder evidence;
the driver films and attaches the final-commit demos separately.
