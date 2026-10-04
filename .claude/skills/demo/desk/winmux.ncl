let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in

(defaults & {
  # cmd-tab used to belong to Apple. Things change.
  mode.main.binding.alt-r = "lens recent --presentation list",

  # Columns: off. I said off. A fresh install should not have opinions.
  columns.count = 'off,

  # 'floating'. Lovely word. It means unemployed.
  lenses.floating.sort = ['title],

  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
