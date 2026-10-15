let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.main.binding.cmd-tab = "lens recent",
  mode.main.binding.cmd-shift-tab = "lens recent",
  mode.main.binding.ctrl-alt-g = "lens recent --presentation grid",
  columns.count = 'off,
}) | W.Config
