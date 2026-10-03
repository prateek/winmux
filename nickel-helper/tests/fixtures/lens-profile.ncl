let W = import "winmux/winmux.ncl" in
{
  filters.floating = fun w ctx => w.class == 'floating,
  lenses.demo = {
    filter = fun w ctx => true,
    when.default.filter = filters.floating,
    when.travel.filter = fun w ctx => false,
  },
} | W.Config
