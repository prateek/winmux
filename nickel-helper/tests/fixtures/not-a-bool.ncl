let W = import "winmux/winmux.ncl" in
{
  filters.title = fun w ctx => w.title,
} | W.Config
