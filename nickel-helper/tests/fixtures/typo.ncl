let W = import "winmux/winmux.ncl" in
{
  filters.mail = fun w ctx => w.app.bundelId == "com.apple.mail",
} | W.Config
