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

  # Three places. No reservation required.
  workspace."1".columns = {
    count = 3,
    # Terminals to the right. Paperwork elsewhere.
    place = fun w ctx cols =>
      if w.app.name == "Ghostty" then { column = 3, overflow = 'tab-group }
      else { column = 'nearest-empty, overflow = 'tab-group },
  },
  mode.main.binding.alt-w = "column-width next",

  # 'floating'. Lovely word. It means unemployed.
  lenses.floating.sort = ['title],

  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
