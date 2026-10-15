let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  lenses.app-windows.presentation = 'strip,
  lenses.app-windows.tile = 'picture,
  lenses.app-windows.grid.tile-size = 'same-height,
}) | W.Config
