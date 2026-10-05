let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.grid.grid.tile-size = 'huge,
}) | W.Config
