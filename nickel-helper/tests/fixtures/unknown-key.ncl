let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & { gapz.inner.horizontal = 4 }) | W.Config
