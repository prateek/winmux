let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.grid = { presentation = 'grid, grid.tile-size = 'real, when.default.grid.tile-size = 'equal },
}) | W.Config
