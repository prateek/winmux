let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  persistent-workspaces = ["1", "2", "3"],
  arrive = fun w ctx cols => {},
  columns.place = fun w ctx cols => { column = 'focused, overflow = 'tab-group },
  columns.move-boundary = fun w ctx cols edge => { action = 'stop },
  workspace."2".columns = { count = 3, widths = [0.28, 0.44, 0.28] },
  workspace."3".columns = {
    count = 2, widths = [2.0 / 3, 1.0 / 3],
    place = fun w ctx cols => { column = 'nearest-empty, overflow = 'tab-group },
  },
  lenses.untriggered = { enabled = false },
  mode.main.binding.alt-x = "lens missing --presentation list --tile text",
  mode.main.binding.esc-a = "lens search",
  mode.main.binding-tap.left-alt = "lens missing",
}) | W.Config
