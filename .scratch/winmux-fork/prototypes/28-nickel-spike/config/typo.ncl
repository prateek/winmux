let W = import "winmux.ncl" in
{
  filters.comms = fun w ctx => w.app.bundelId == "com.apple.mail",
  lenses = {},
  columns.place = fun w ctx cols => { column = 'focussed },
  arrive = fun w ctx => {},
} | W.Config
