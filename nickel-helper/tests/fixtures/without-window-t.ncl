let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & { keymap.window.bindings | force = W.without-bindings ["t"] defaults.keymap.window.bindings }) | W.Config
