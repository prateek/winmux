let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in

(defaults & {
  # These desks opt in to filming the strip.
  keymap.cmd-tab-opt-in = W.when "mode == main" {
    cmd-tab = "mode cmd-tab",
    cmd-shift-tab = "mode cmd-tab-back",
    cmd-backtick = "mode cmd-backtick",
    alt-r = ["lens recent --presentation list", "mode search"],
  },

  # Columns: off. I said off. A fresh install should not have opinions.
  columns.count = 'off,

  # 'floating'. Lovely word. It means unemployed.
  lenses.floating.sort = ['title],

  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
