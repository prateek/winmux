let W = import "winmux/winmux.ncl" in
{
  filters = {
    mail = fun w ctx => w.app.bundleId == "com.apple.mail",
    other-mail = fun w ctx => filters.mail ctx w && w.workspace != ctx.workspace.name,
  },
} | W.Config
