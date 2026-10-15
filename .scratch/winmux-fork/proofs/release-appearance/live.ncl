let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  mode.main.binding = {
    cmd-tab = "lens recent",
    cmd-shift-tab = "lens recent",
    ctrl-alt-g = "lens committing-grid",
    shift-g = "lens committing-grid",
    ctrl-alt-s = "lens staying-strip",
  },
  lenses.committing-grid = { presentation = 'grid, on-release = 'commit, tile = 'picture },
  lenses.staying-strip = { presentation = 'strip, on-release = 'stay, tile = 'picture },
  lenses.dark-list = { presentation = 'list, appearance = 'dark },
  columns.count = 'off,
}) | W.Config
