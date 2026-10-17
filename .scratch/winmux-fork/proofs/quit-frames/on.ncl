let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  restore-windows-on-quit = true,
  persistent-workspaces = ["1", "2", "3"],
}) | W.Config
