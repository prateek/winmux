let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.main.binding = {
    cmd-tab = "lens recent",
    cmd-shift-tab = "lens recent",
    cmd-backtick = "lens app-windows",
  },
}) | W.Config
