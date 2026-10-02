let W = import "winmux/winmux.ncl" in
{
  filters.mail = "com.apple.mail",
} | W.Config
