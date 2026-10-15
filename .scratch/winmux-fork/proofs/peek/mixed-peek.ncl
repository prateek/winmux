let W = import "winmux/winmux.ncl" in
(import "winmux/defaults.ncl") & {
  lenses.search.keys.cmd-p = ["peek", "close"],
} | W.Config
