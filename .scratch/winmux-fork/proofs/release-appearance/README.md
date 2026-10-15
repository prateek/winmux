# Release and appearance probes

All debug runs belong in the driver's guest. Export `TART_HOME` before every shell and use the `vm` skill's wrappers for guest access. These scripts inherit that variable. They neither boot nor resize a guest and never grant permissions.

Stage this directory as `~/proof64`, and the existing `proofs/peek` directory as `~/peek-proof`, using `vm push`. In the guest, compile `Desk.swift` to `~/proof64/Desk` and `keys-check.swift` to `~/peek-proof/keys-check` with `swiftc`. The desk creates four owned windows: Garden plan, Reading notes, Travel list and Weekend projects.

Start the desk and the debug WinMux from the synced worktree, with scratch XDG config/state roots and that tree's `WINMUX_NICKEL_HELPER`. Put `live.ncl` at the scratch config's `winmux/winmux.ncl`. Control-Option-G opens the committing grid, Control-Option-S the staying strip, and Cmd-Tab opts into the ordinary recent strip. Neither Control-Option chord is shipped. Shift-G is a temporary boundary probe for a Shift-only committing Hold.

Run `live.zsh` through `vm ssh`. It saves screenshots, traces, focused-window/workspace/match readbacks and a quick-tap movie under `~/captures/final`. It asserts release/key/peek behavior and restores the system's starting appearance on exit. The first light-list/prototype comparison was captured before theming the other panel surfaces; those captures are builder evidence outside the repository.

`appearance.zsh` adds open-session system-appearance changes, a cross-workspace badge/legend capture and a full-size peek of the visible window. It restores the starting appearance too.

For the unchanged-behavior comparison, build the actual base tree in a second guest directory over `vm ssh`, including its helper, and initialize its `.git` directory. Use `unchanged.ncl` for both runs. Start one tree at a time, set `WINMUX_PROOF_ROOT` to it and run the same `unchanged.zsh <capture-prefix>`. It asserts held-strip release, grid release/toggle, slash, first-letter and Search/Enter behavior. It deliberately excludes CLI strips, whose no-held-chord behavior changes in this issue.

Use `python3` to run `assert-state.py`. After each run inspect the pictures and match counts, then quit WinMux and the owned desk. The builder leaves the guest up; final-commit PR media and releases belong to the driver.
