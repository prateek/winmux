let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in

(defaults & {
  # cmd-tab used to belong to Apple. Things change.
  mode.main.binding.alt-r = "lens recent --presentation list",

  # Columns: off. I said off. A fresh install should not have opinions.
  columns.count = 'off,
  persistent-workspaces = ["1", "2", "3", "4"],


  # Except here. Reading gets three Columns, because I read like a newspaper.
  workspace."2".columns = {
    count = 3,
    widths = [0.28, 0.44, 0.28],
  },

  # Writing gets two: the thing, and the thing I look at instead of writing.
  workspace."3".columns = {
    count = 2,
    widths = [2.0 / 3, 1.0 / 3],
  },

  # 'floating'. Lovely word. It means unemployed.
  lenses.floating.sort = ['title],

  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
