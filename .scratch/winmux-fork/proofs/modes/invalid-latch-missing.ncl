let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  mode.bad = { unbound = 'latch, latch-to = "absent" },
}) | W.Config
