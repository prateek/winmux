let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  mode.main.binding | force = defaults.mode.main.binding & {
    cmd-tab = "lens recent",
    cmd-shift-tab = "lens recent",
  },
  lenses.search.keys.space = [],
  lenses.recent.keys.space = [],
  columns.count = 'off,
  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
