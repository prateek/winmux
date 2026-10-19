# Group drag proofs

Run these tools only in an assigned guest through the VM wrapper. `winmux.ncl` keeps both normalizations on, Columns off between stages, and sidebar split rows visible. Compile the demo skill's `stage.swift` and the sidebar-tree proof's `ui.swift` in the guest, then run five stage windows named Red, Blue, Green, Yellow and Violet. Start the guest debug manager with isolated config/state and the matching Nickel helper.

`python3 live.py scenario <name> A` builds an outer tab group with a plain Red tab and a Blue/Green split. `B` first makes Blue/Green an inner group, joins Yellow into a split, enables three Columns and moves Red into that occupied Column before turning Columns off. Both stages focus Blue. `plain` uses A's shape and focuses Red.

Each scenario uses real pointer drags: the outer strip handle onto Violet, the outer sidebar header before Violet's row, then onto the Destination workspace. A one-second source hover lets the sidebar accept mouse input. The driver captures the held preview, waits five seconds after release, then reads the window list and agent tree once. The final assertions require every expected leaf in Destination with one outer group identity. Raw agent tab-group nodes serialize representative ids; inventory membership and the sidebar hierarchy corroborate the nested shapes.

Results go under `~/takes/group-drag`. Command and input JSON files record exact staging and pointer coordinates. The `*.summary.json` outputs from `scenario <name> plain` are directly comparable with `WINMUX_CLI` pointed at the baseline and feature trees. Start the matching manager and helper for each run. The archived baseline needs a `.git` directory and Sparkle beside its debug executable before launch.

No Search is used. Captures and the relay index stay outside the public repository; final-commit demos belong to the demo pass.
