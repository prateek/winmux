let W = import "winmux/winmux.ncl" in
let d = import "winmux/defaults.ncl" in
(d & {
  mode.main.binding.cmd-tab = "lens recent",
  mode.main.binding.cmd-shift-tab = "lens recent",
  lenses.search = { peek = 'follow, hints = 'always },
}) | W.Config
