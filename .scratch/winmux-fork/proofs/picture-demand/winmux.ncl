let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & {
  columns.count = 'off,
  persistent-workspaces = ["1", "2"],
  arrive = fun w ctx cols => { float = true, workspace = "1" },
  lenses.windows.sections = 'none,
  lenses.windows.sort = ['title],
  mode.main.binding.alt-g = "lens windows",
}) | W.Config
