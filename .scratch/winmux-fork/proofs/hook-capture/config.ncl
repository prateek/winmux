let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  reload-on-save = false,
  arrive = fun w ctx cols => {},
  columns = {
    count = 3,
    place = fun w ctx cols => { column = 2, overflow = 'tab-group },
    move-boundary = fun w ctx cols edge => { action = if edge then 'stop else 'join, overflow = 'tab-group },
  },
}) | W.Config
