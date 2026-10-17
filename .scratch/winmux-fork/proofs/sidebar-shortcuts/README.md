# Sidebar shortcut regression probes

Run these scripts only in the driver's guest, through `vm ssh`. They operate the standing desk at 1280×720. Keep the guest's display size and permissions unchanged. The host must export the driver's `TART_HOME` before every shell command.

Use `.claude/skills/vm/vm` to push `.claude/skills/demo/desk/` to `desk/`, then push this directory to `desk/`. Also push the demo skill's `keys.swift` and `desk/hero/snapshot-recorder.swift` in a directory, and compile `keys.swift` to `~/desk/keys` over `vm ssh`.

Build the base archive in a separate guest directory (`git init`, `make helper`, `swift build`), and the current tree with `vm sync`, `vm check`, then `vm build`. The baseline is `3877046b`. The archive needs `.git` because an unbundled debug executable locates its source root from it. Keep both build directories intact.

Build each tree's `.build` independently: Swift build manifests retain absolute output paths.

Stage with `~/desk/stage-desk.sh`. It expects the executable and helper under `~/winmux`; for the base run, link those build directories to the separately built baseline, then remove the links before building the current tree. Restage between trees, so each starts with four windows and one Ghostty window. No installed build is started.

Run these guest commands through `vm ssh`, prefixing its command string with an export of the driver's `TART_HOME`; SSH does not forward that variable:

```sh
zsh ~/desk/probes.zsh base ~/winmux-base
zsh ~/desk/spaces.zsh base ~/winmux-base
zsh ~/desk/modes.zsh base ~/winmux-base
```

Repeat with label `head` and root `~/winmux`. Also run `selection.zsh <label> <root>` against both trees: it uses the physical-key helper for plain arrows, whose key-down events cliclick did not deliver in the builder's comparison. `spaces.zsh` films both input drivers. Run `rename.zsh ~/winmux` on head after the normal probes and before the mode probes. `modes.zsh` restarts the named build with the two config wrappers; it quits the debug build between modes to prevent an always-expanded search from consuming Escape intended for Mission Control.

Run `native-chords.zsh <label> <root>` against both trees for the definitive native overlay checks. It compiles `arrow-chord.swift`, which preserves the Function flag that the guest's runtime symbolic-hotkey table requires for Control-arrow chords (`8650752`, Control plus Function). The generic demo helper clears that flag. No system shortcut setting is changed. The original cliclick probes remain as recorded input-driver comparisons.

Each native-arrow case starts a fresh debug process after dismissing overlays with the previous process stopped. Close an opened overlay with the same arrow chord before leaving the sidebar; a bare Escape can still go to Search. Its `*-before`, `*-result` and `*-after` screenshots must show the expanded sidebar, the requested native overlay and the returned desktop respectively. On base, the over-sidebar result deliberately shows no overlay.

The base has no double-click rename handler. `rename.zsh` uses the existing **Rename Workspace** context-menu item, reads the committed action from WinMux's debug log, tests Ctrl-Up while the field is open, and restores the original workspace label.

`escape.zsh` runs both trees after a fresh four-window stage, cancelling a visible `gho` query and leaving the hover region before its final capture. A stationary pointer can otherwise expand the sidebar again after Escape, on both trees.

The probes save screenshots, key logs and readbacks under `~/takes/117/<label>/`. Pull the directory with `vm pull`. Record each Search's actual match count and workspace in the private captures index. Read the screenshots before claiming a system overlay opened; the CLI focus record alone cannot prove that.

The required `cliclick` Cmd-Space probe is retained. On the builder's image it did nothing even with WinMux stopped, while the demo skill's physical-key helper opened Spotlight. The script therefore captures that helper's whole Cmd-Space chord too. Dismiss Spotlight's informational first-run screen before the measured comparisons; this is an image-recipe follow-up, not a permission grant.

Wait for a fixed interval before the single final `list-windows` read after Cmd-N. Repeated read-only commands can cancel a pending refresh on the baseline. After inspection, quit the debug build and close the staged apps, leaving the guest running for the driver.

`always-away.zsh <label> <root>` restarts the named build under `always.ncl`, types into a focused Ghostty with the pointer away from the sidebar, and screenshots who got the keys. On base and head the sidebar search does; that is **With `always-expanded`, the sidebar's search takes every key typed anywhere**.
