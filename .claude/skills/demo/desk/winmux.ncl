let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in

(defaults & {
  # These desks opt in to filming the strip.
  mode.main.binding.cmd-tab = "lens recent",
  mode.main.binding.cmd-shift-tab = "lens recent",
  mode.main.binding.cmd-backtick = "lens app-windows",
  mode.main.binding.alt-r = "lens recent --presentation list",

  # Columns: off. I said off. A fresh install should not have opinions.
  columns.count = 'off,

  # 'floating'. Lovely word. It means unemployed.
  lenses.floating.sort = ['title],

  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
