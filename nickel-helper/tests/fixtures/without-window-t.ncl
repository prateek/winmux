let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & { mode.window.binding | force = W.without-bindings ["t"] defaults.mode.window.binding }) | W.Config
