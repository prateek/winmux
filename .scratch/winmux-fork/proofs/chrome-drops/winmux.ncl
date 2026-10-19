let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  columns.count = 'off,
  persistent-workspaces = ["1", "2", "3", "4", "5"],
  workspace-sidebar.always-expanded = true,
  workspace-sidebar.show-clock = true,
  workspace-sidebar.workspace-labels = {
    "1" = "Source",
    "2" = "Middle",
    "3" = "Visible",
    "4" = "Edge",
    "5" = "Last",
  },
}) | W.Config
