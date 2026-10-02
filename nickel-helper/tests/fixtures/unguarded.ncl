let W = import "winmux/winmux.ncl" in
{
  filters.same-app = fun w ctx => ctx.focused.app.bundleId == w.app.bundleId,
} | W.Config
