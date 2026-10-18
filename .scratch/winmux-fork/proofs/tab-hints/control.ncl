let defaults = import "winmux/defaults.ncl" in
let withoutDigits = std.array.fold_left (fun bindings key => std.record.remove key bindings) defaults.mode.main.binding ["alt-1", "alt-2", "alt-3", "alt-4", "alt-5", "alt-6", "alt-7", "alt-8", "alt-9", "ctrl-1", "ctrl-2", "ctrl-3", "ctrl-4", "ctrl-5", "ctrl-6", "ctrl-7", "ctrl-8", "ctrl-9"] in
defaults & {
  mode.main.binding | force = withoutDigits & {
    ctrl-1 = "focus --tab-index 1",
    ctrl-2 = "focus --tab-index 2",
    ctrl-3 = "focus --tab-index 3",
    ctrl-4 = "focus --tab-index 4",
    ctrl-5 = "focus --tab-index 5",
    ctrl-6 = "focus --tab-index 6",
    ctrl-7 = "focus --tab-index 7",
    ctrl-8 = "focus --tab-index 8",
    ctrl-9 = "focus --tab-index last",
    alt-q = "focus --tab-index 1",
  },
}
