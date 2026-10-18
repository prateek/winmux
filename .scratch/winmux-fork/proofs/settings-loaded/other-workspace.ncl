let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  persistent-workspaces = ["1", "2", "Other workspaces"],
  columns.place = fun w ctx cols => { column = 'focused, overflow = 'tab-group },
  workspace."Other workspaces".columns = {
    count = 2,
    place = fun w ctx cols => { column = 'nearest-empty, overflow = 'tab-group },
  },
}) | W.Config
