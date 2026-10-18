let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & { settings-proof-unknown = true }) | W.Config
