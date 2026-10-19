let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  reload-on-save = false,
  arrive = fun w ctx cols => {},
  columns = {
    count = 3,
    place = fun w ctx cols => { column = 7, overflow = 'tab-group },
  },
}) | W.Config
