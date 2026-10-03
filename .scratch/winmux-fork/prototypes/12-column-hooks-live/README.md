# Owned Column Policy demo windows

`demo.swift` is a neutral AppKit fixture for an isolated debug live run. Compile it into three scratch app bundles with bundle ids `com.example.winmux.ColumnsDemo`, `com.example.winmux.ColumnEvidence` and `com.example.winmux.ColumnAccessory`; the last declares `LSUIElement = true` for the bundle-based Accessory floating default. The fixture uses regular live activation policy so both signals can be tested separately. Each process reads JSON commands from `<scratch-root>/command`. Commands create, close, raise, hide, show or update a named window, set its frame, and quit. A changing clock distinguishes a live view from a still.

Run the debug build with scratch `XDG_CONFIG_HOME` and `XDG_STATE_HOME`. Keep top-level Columns off and enable them only on dedicated workspaces. Arrive must match these owned bundle ids and return `{}` otherwise. Remove `cmd-tab`, `cmd-shift-tab` and `cmd-backtick` bindings; inspect symbolic-hotkey ownership with `doctor` before recording.

Save original desktop window frames before launching. Hide Terminal and Orca throughout the run, leave unrelated dialogs untouched, quit owned apps and WinMux normally, restore frames, then unhide both. Mask unrelated dialogs in every frame, and retain clean crops of each visible result. Do not record the lock screen or attempt to unlock it.

The builder's private state directory retains the actual command transcript, capture scripts, original frame geometry, and a restoration script. The Column Policy report maps every numbered capture to its claim and identifies output replays and incomplete live checks. Those machine-specific artifacts are deliberately outside this public fixture.
