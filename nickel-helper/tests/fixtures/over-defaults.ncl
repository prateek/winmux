let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & { gaps.inner.horizontal = 0, default-root-container-layout = 'tab-group }) | W.Config
