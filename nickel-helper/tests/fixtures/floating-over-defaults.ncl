let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  filters.floating = fun w ctx => w.class == 'tiled,
}) | W.Config
