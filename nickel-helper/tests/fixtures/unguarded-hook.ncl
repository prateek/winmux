let W = import "winmux/winmux.ncl" in
({} | W.Config)
& {
  arrive = fun w ctx => { float = ctx.focused.app.bundleId == w.app.bundleId },
}
