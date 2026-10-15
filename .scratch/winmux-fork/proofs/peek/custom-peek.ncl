let W = import "winmux/winmux.ncl" in
let d = import "winmux/defaults.ncl" in
(d & {
  lenses.search.keys = { space = [], cmd-y = [], cmd-p = "peek" },
  lenses.overview.peek = 'follow,
}) | W.Config
