let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.bad = { unbound = 'latch, latch-to = "recursive" },
  mode.recursive = { unbound = 'latch, latch-to = "browse" },
}) | W.Config
