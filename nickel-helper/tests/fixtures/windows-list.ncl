let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & { lenses.windows.presentation = 'list }) | W.Config
