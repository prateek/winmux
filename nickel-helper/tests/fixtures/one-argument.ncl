let W = import "winmux/winmux.ncl" in
{
  filters.everything = fun w => true,
} | W.Config
