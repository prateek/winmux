let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  columns.count = 'off,
  persistent-workspaces = ["1", "2"],
  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
  enable-shake-to-toggle-tiling = false,
}) | W.Config
