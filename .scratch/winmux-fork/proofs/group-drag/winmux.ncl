let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  columns.count = 'off,
  persistent-workspaces = ["1", "2", "3"],
  enable-normalization-flatten-containers = true,
  enable-normalization-opposite-orientation-for-nested-containers = true,
  workspace-sidebar = {
    enabled = true,
    always-expanded = true,
    width = 320,
    tree.splits = true,
    tree.columns = false,
    show-clock = false,
  },
  gaps.inner.horizontal = 8,
  gaps.inner.vertical = 8,
}) | W.Config
