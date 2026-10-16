# Arrive cancellation live probe

Run only in the assigned guest, following the VM skill. Build the feature in `~/winmux`
and the `e73672c6` archive in `~/winmux-base`, initializing a Git repository in the latter.
Both builds use the unchanged helper from `~/winmux/nickel-helper/target/release`.

Copy this directory to `~/arrive-proof`. Compile the demo skill's `stage.swift`,
`keys.swift` and `desk/hero/snapshot-recorder.swift` there as `stage`, `keys` and
`snapshot-recorder`. Put `winmux.ncl` in a scratch XDG config directory. Start
`stage "Source anchor"`, then the chosen debug build with that config, a separate
scratch XDG state directory, and `WINMUX_DEBUG_POLICY_TIMING=1`.

`python3 ~/arrive-proof/trials.py ~/winmux feature` runs ten trials. For the base,
quit the feature process, start the base with separate state and run the same
script with `~/winmux-base base`. It saves window and Column JSON, all key events,
a screenshot per trial and a seven-second recording of the first trial under
`~/takes/<label>`. Use a new label for every attempt. Each trial resets Route to
three Columns; Arrive routes to Column 3 and its Run list changes the count to
four. A final identical float/move/retile probe records unchanged command behavior.
No Lens Search is used.

The first ordinary comparison routed ten of ten on both builds. To expose the
race, `prepare.py` generates a variant of the same owned stage whose Trial windows
answer AX title reads after 120 ms. Compile its output as `slow-stage` and use it
in place of `stage`; this changes the external app's argument-read latency, not
WinMux or the helper deadline. The retained slower-read comparison uses thirty
Option-H taps at 100 ms intervals; the original ordinary comparison used one
hundred taps at 20 ms intervals. Both builds use the same script in each pair.

The script issues `doctor` after the key storm to schedule a normal refresh before
readback. Read-only CLI polling itself cancels a refresh, so polling immediately
can leave a native window undetected. The first setup attempt exposed this and
is retained separately. The deterministic continuation tests are the exact proof
of cancellation while argument collection is suspended; live timing is a race.

At the end, stop the debug process before quitting the stage. Close all owned
windows and leave the assigned guest up. The driver films final-commit PR demos.
