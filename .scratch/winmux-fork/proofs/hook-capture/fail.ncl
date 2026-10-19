let W = import "winmux/winmux.ncl" in
((import "winmux/defaults.ncl") & {
  reload-on-save = false,
  arrive = fun w ctx cols => {},
  columns = {
    count = 3,
    place = fun w ctx cols => if w.app.bundleId == "com.mitchellh.ghostty"
      then std.fail_with "capture live failure"
      else { column = 2, overflow = 'tab-group },
  },
}) | W.Config
