let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  persistent-workspaces = ["Source", "Route"],
  on-focused-monitor-changed = [],
  columns.count = 3,
  mode.main.binding | force = {
    alt-h = "workspace Source",
  },
  arrive = fun w ctx cols =>
    if w.title == "Source anchor" then { workspace = "Source" }
    else { workspace = "Route", column = 3,
           run = ["column-count 4 --workspace Route"] },
}) | W.Config
