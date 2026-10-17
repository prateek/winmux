let W = import "winmux/winmux.ncl" in
let desk = import "../desk/rich/winmux.ncl" in
(desk & {
  lenses.apps = {
    entries = 'app,
    presentation = 'strip,
    tile = 'card,
    sort = ['app, 'created],
    sections = 'none,
  },
}) | W.Config
