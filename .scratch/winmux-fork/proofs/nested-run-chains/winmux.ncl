let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  persistent-workspaces = ["1", "2", "3", "Source", "Ping", "Pong"],
  on-focused-monitor-changed = [],
  columns = { count = 3, widths = [0.3, 0.3, 0.4] },
  arrive = fun w ctx cols =>
    if w.title == "Chain" then {
      run = ["move-node-to-workspace 3", "focus-column 2 --workspace 3"],
    } else if w.title == "Three left" then { workspace = "3", column = 1 }
    else if w.title == "Three right" then { workspace = "3", column = 3 }
    else if w.title == "Ping anchor" then { workspace = "Ping", column = 1 }
    else if w.title == "Pong anchor" then { workspace = "Pong", column = 1 }
    else { workspace = "Source" },
  workspace."3".columns.place = fun w ctx cols => {
    column = 2, overflow = 'tab-group, run = ["column-width 0.5"],
  },
  workspace.Ping.columns.place = fun w ctx cols => {
    column = 2, overflow = 'tab-group,
    run = if w.title == "Loop" then ["move-node-to-workspace Pong"] else [],
  },
  workspace.Pong.columns.place = fun w ctx cols => {
    column = 3, overflow = 'tab-group,
    run = if w.title == "Loop" then ["move-node-to-workspace Ping"] else [],
  },
}) | W.Config
