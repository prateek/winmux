let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in

(defaults & {
  mode.main.binding.alt-r = "lens recent --presentation list",
  columns.count = 'off,
  persistent-workspaces = ["1", "2", "3", "4"],
  workspace."2".columns = {
    count = 3,
    widths = [0.28, 0.44, 0.28],
  },
  workspace."3".columns = {
    count = 2,
    widths = [2.0 / 3, 1.0 / 3],
  },
  lenses.floating.sort = ['title],
  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
