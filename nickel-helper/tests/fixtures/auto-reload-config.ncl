let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  auto-reload-config = false,
}) | W.Config
