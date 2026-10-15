let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  lenses.windows.appearance = 'dark,
  lenses.search.appearance = 'dark,
  lenses.recent.appearance = 'dark,
  lenses.overview.appearance = 'dark,
}) | W.Config
