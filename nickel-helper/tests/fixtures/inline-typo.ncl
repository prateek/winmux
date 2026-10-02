let W = import "winmux/winmux.ncl" in
{
  lenses.mail = { filter = fun w ctx => w.app.bundelId == "com.apple.mail" },
} | W.Config
