let W = import "winmux/winmux.ncl" in
({} | W.Config)
& {
  arrive = fun w ctx cols => { float = ctx.focused.app.bundleId == w.app.bundleId },
}
