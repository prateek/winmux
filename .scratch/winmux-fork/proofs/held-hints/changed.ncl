let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  mode.main.binding | force = defaults.mode.main.binding & {
    cmd-tab = "lens recent",
    cmd-shift-tab = "lens recent",
    ctrl-alt-tab = "lens recent --presentation grid",
    ctrl-shift-tab = "lens recent --presentation strip --search 'saf'",
    alt-tab = "lens recent",
  },
  lenses.search.hints-key = 'ctrl,
  lenses.search.keys.cmd-w = [],
  lenses.search.keys.cmd-d = "close",
  columns.count = 'off,
  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
