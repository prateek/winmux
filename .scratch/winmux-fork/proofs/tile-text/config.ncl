let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  arrive = fun w ctx columns => { float = true },
  lenses.windows.sections = 'none,
  lenses.windows.sort = ['created],
}) | W.Config
